#!/usr/bin/env python3
"""
DAQ Data Streaming GUI - Individual Channel Plots Version
Features:
- 4 EMG channels + 16 analog channels displayed individually
- Real NIDAQ hardware support
- Simulation mode for testing
"""

import numpy as np
import time
import threading
import json
import yaml
import argparse
from datetime import datetime
from collections import deque
from pathlib import Path

# DAQ libraries (optional - for real hardware)
try:
    import nidaqmx
    from nidaqmx.constants import TerminalConfiguration, AcquisitionType
    NIDAQ_AVAILABLE = True
except ImportError:
    NIDAQ_AVAILABLE = False
    print("Warning: nidaqmx not available. Running in simulation mode only.")

from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO, emit

class DAQStreamer:
    def __init__(self, use_hardware=False, config_file="channel_config.yaml"):
        self.config = self.load_config(config_file)
        
        hw_config = self.config.get('hardware', {})
        self.fs = hw_config.get('sampling_rate', 2500)
        self.update_rate = hw_config.get('update_rate', 0.1)
        self.history_duration = hw_config.get('history_duration', 3.0)
        self.max_samples = int(self.fs * self.history_duration)
        
        self.analog_channels = len(self.config.get('analog_channels', []))
        self.emg_channels = len(self.config.get('emg_channels', []))
        self.total_channels = self.analog_channels + self.emg_channels
        
        # Set hardware or simulation mode
        self.use_hardware = use_hardware and NIDAQ_AVAILABLE
        self.simulation_mode = not self.use_hardware
        self.device_name = hw_config.get('device_name', "Dev1")
        
        # Map EMG channels to hardware pins
        self.emg_ch_map = [ch.get('hardware_channel', 17+i) for i, ch in enumerate(self.config.get('emg_channels', []))]
        
        # Get channel labels from config
        self.analog_labels = [ch.get('name', f'Analog {i}') for i, ch in enumerate(self.config.get('analog_channels', []))]
        self.analog_short_labels = [ch.get('short_name', f'AI-{i}') for i, ch in enumerate(self.config.get('analog_channels', []))]
        
        self.muscle_labels = [ch.get('name', f'EMG {i}') for i, ch in enumerate(self.config.get('emg_channels', []))]
        self.muscle_short_labels = [ch.get('short_name', f'EMG-{i}') for i, ch in enumerate(self.config.get('emg_channels', []))]
        
        # Set up file saving options
        file_config = self.config.get('file_settings', {})
        self.default_directory = file_config.get('default_directory', 'data')
        self.default_project = file_config.get('default_project', 'swallow_JET')
        self.output_directory = self.default_directory
        self.project_name = self.default_project
        
        # Performance settings for web interface
        perf_config = self.config.get('performance', {})
        self.web_update_interval = perf_config.get('web_update_interval', 100)
        self.status_update_interval = perf_config.get('status_update_interval', 2000)
        self.buffer_multiplier = perf_config.get('buffer_multiplier', 10)
        
        # Display layout settings
        display_config = self.config.get('display', {})
        self.grid_columns = display_config.get('grid_columns', 4)
        
        # Data storage buffers
        self.data_buffer = deque(maxlen=self.max_samples)
        self.timestamps = deque(maxlen=self.max_samples)
        
        # Current system state
        self.is_recording = False
        self.is_connected = False
        self.trial_number = 1
        
        # Threading for data acquisition
        self.data_thread = None
        self.stop_event = threading.Event()
        self.task = None
        
        print(f"DAQ initialized: {self.emg_channels} EMG + {self.analog_channels} analog channels")
        print(f"Hardware mode: {self.use_hardware}, Simulation mode: {self.simulation_mode}")
        print(f"Config loaded from: {config_file}")
    
    def load_config(self, config_file):
        """Load settings from YAML configuration file"""
        try:
            with open(config_file, 'r') as f:
                config = yaml.safe_load(f)
            print(f"Configuration loaded from {config_file}")
            return config
        except FileNotFoundError:
            print(f"Warning: Config file {config_file} not found. Using defaults.")
            return self.get_default_config()
        except yaml.YAMLError as e:
            print(f"Error parsing YAML config: {e}. Using defaults.")
            return self.get_default_config()
    
    def get_default_config(self):
        """Return default configuration when YAML file is missing"""
        return {
            'analog_channels': [{'name': f'Analog {i}', 'short_name': f'AI-{i}'} for i in range(16)],
            'emg_channels': [
                {'name': 'L_APB', 'short_name': 'L-APB', 'hardware_channel': 17},
                {'name': 'L-FLEX', 'short_name': 'L-FLEX', 'hardware_channel': 27},
                {'name': 'L_FDI', 'short_name': 'L-FDI', 'hardware_channel': 29},
                {'name': 'NC', 'short_name': 'NC', 'hardware_channel': 23}
            ],
            'hardware': {'device_name': 'Dev1', 'sampling_rate': 2500, 'update_rate': 0.1, 'history_duration': 3.0},
            'file_settings': {'default_directory': 'data', 'default_project': 'swallow_JET'}
        }
    
    def update_settings(self, directory=None, project=None):
        """Update save directory and project name"""
        if directory:
            self.output_directory = directory
        if project:
            self.project_name = project
        return True, "Settings updated successfully"
    
    def connect_daq(self):
        """Connect to DAQ hardware or start simulation mode"""
        if self.simulation_mode:
            self.is_connected = True
            return True, "Simulation mode enabled - DAQ ready"
        
        if not NIDAQ_AVAILABLE:
            return False, "NIDAQ library not available. Install nidaqmx package."
        
        try:
            # Test connection by creating a temporary task
            with nidaqmx.Task() as test_task:
                test_task.ai_channels.add_ai_voltage_chan(f"{self.device_name}/ai0")
            
            self.is_connected = True
            return True, f"Hardware DAQ connected - Device: {self.device_name}"
        
        except Exception as e:
            self.is_connected = False
            return False, f"DAQ connection failed: {str(e)}"
    
    def start_recording(self):
        """Start data acquisition and recording"""
        if self.is_recording:
            return False, "Already recording"
        
        if not self.is_connected:
            return False, "DAQ not connected - click Connect first"
        
        try:
            # Create output directory
            Path(self.output_directory).mkdir(exist_ok=True)
            Path(f"{self.output_directory}/metadata").mkdir(exist_ok=True)
            
            # Generate filename
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"{timestamp}_{self.project_name}_{datetime.now().strftime('%Y%m%d')}_Trl{self.trial_number:03d}.bin"
            self.output_file = Path(self.output_directory) / filename
            
            # Clear buffers
            self.data_buffer.clear()
            self.timestamps.clear()
            
            # Start data acquisition thread
            self.stop_event.clear()
            self.is_recording = True
            
            if self.simulation_mode:
                self.data_thread = threading.Thread(target=self._simulation_loop, daemon=True)
            else:
                self.data_thread = threading.Thread(target=self._hardware_loop, daemon=True)
            
            self.data_thread.start()
            
            mode = "Simulation" if self.simulation_mode else "Hardware"
            print(f"Recording started ({mode}): {filename}")
            return True, f"Recording started ({mode}) - Trial {self.trial_number}"
            
        except Exception as e:
            self.is_recording = False
            error_msg = f"Failed to start recording: {str(e)}"
            print(error_msg)
            return False, error_msg
    
    def stop_recording(self):
        """Stop data acquisition and save metadata"""
        if not self.is_recording:
            return False, "Not recording"
        
        try:
            self.is_recording = False
            self.stop_event.set()
            
            if self.data_thread and self.data_thread.is_alive():
                self.data_thread.join(timeout=2.0)
            
            # Close hardware task if exists
            if self.task:
                try:
                    self.task.stop()
                    self.task.close()
                    self.task = None
                except:
                    pass
            
            # Save metadata
            if hasattr(self, 'output_file') and self.output_file:
                metadata = {
                    'trial_number': self.trial_number,
                    'fs': self.fs,
                    'emg_channels': self.emg_channels,
                    'analog_channels': self.analog_channels,
                    'muscle_labels': self.muscle_labels,
                    'analog_labels': self.analog_labels,
                    'emg_ch_map': self.emg_ch_map,
                    'device_name': self.device_name,
                    'simulation_mode': self.simulation_mode,
                    'timestamp': datetime.now().isoformat()
                }
                
                metadata_file = Path(f"{self.output_directory}/metadata") / f"{self.output_file.stem}_metadata.json"
                with open(metadata_file, 'w') as f:
                    json.dump(metadata, f, indent=2)
            
            current_trial = self.trial_number
            self.trial_number += 1
            
            print(f"Recording stopped - Trial {current_trial} saved")
            return True, f"Recording stopped - Trial {current_trial} saved. Next: {self.trial_number}"
            
        except Exception as e:
            error_msg = f"Error stopping recording: {str(e)}"
            print(error_msg)
            return False, error_msg
    
    def _hardware_loop(self):
        """Hardware data acquisition loop"""
        try:
            self.task = nidaqmx.Task()
            
            for i in range(self.analog_channels):
                chan = self.task.ai_channels.add_ai_voltage_chan(f"{self.device_name}/ai{i}")
                chan.ai_term_cfg = TerminalConfiguration.SINGLE_ENDED_NON_REFERENCED
            
            for i, ch in enumerate(self.emg_ch_map):
                if ch < 80:
                    chan = self.task.ai_channels.add_ai_voltage_chan(f"{self.device_name}/ai{ch}")
                    chan.ai_term_cfg = TerminalConfiguration.SINGLE_ENDED
            
            # Configure timing
            samples_per_update = int(self.fs * self.update_rate)
            self.task.timing.cfg_samp_clk_timing(
                rate=self.fs, 
                sample_mode=AcquisitionType.CONTINUOUS,
                samps_per_chan=samples_per_update * self.buffer_multiplier  # Configurable buffer size
            )
            
            print(f"Hardware acquisition started: {samples_per_update} samples per update")
            
            with open(self.output_file, 'wb') as f:
                self.task.start()
                start_time = time.time()
                
                while not self.stop_event.is_set():
                    try:
                        # Read data
                        data = self.task.read(
                            number_of_samples_per_channel=samples_per_update,
                            timeout=self.update_rate + 1.0
                        )
                        
                        current_time = time.time() - start_time
                        timestamps = np.linspace(
                            current_time, 
                            current_time + self.update_rate, 
                            samples_per_update
                        )
                        
                        # Convert to numpy array if needed
                        if isinstance(data, list):
                            data = np.array(data).T
                        elif len(data.shape) == 1:
                            data = data.reshape(-1, 1)
                        
                        # Ensure we have the right number of channels
                        if data.shape[1] != self.total_channels:
                            print(f"Warning: Expected {self.total_channels} channels, got {data.shape[1]}")
                            # Pad with zeros if needed
                            if data.shape[1] < self.total_channels:
                                padding = np.zeros((data.shape[0], self.total_channels - data.shape[1]))
                                data = np.hstack([data, padding])
                            else:
                                data = data[:, :self.total_channels]
                        
                        # Store data
                        for ts, sample in zip(timestamps, data):
                            self.timestamps.append(ts)
                            self.data_buffer.append(sample)
                            
                            # Write to file: timestamp + data
                            file_data = np.concatenate([[ts], sample])
                            f.write(file_data.astype(np.float64).tobytes())
                        
                    except Exception as e:
                        print(f"Hardware read error: {e}")
                        break
                    
                    time.sleep(max(0, self.update_rate - 0.01))  # Small adjustment for timing
                
                self.task.stop()
        
        except Exception as e:
            print(f"Hardware acquisition error: {e}")
            self.is_recording = False
        finally:
            if self.task:
                try:
                    self.task.close()
                    self.task = None
                except:
                    pass
    
    def _simulation_loop(self):
        """Simulation data generation loop"""
        try:
            samples_per_update = int(self.fs * self.update_rate)
            print(f"Simulation started: {samples_per_update} samples per update")
            
            with open(self.output_file, 'wb') as f:
                start_time = time.time()
                
                while not self.stop_event.is_set():
                    current_time = time.time() - start_time
                    timestamps = np.linspace(current_time, current_time + self.update_rate, samples_per_update)
                    
                    data = np.zeros((samples_per_update, self.total_channels))
                    
                    for i in range(self.analog_channels):
                        if i < 4:  # HUMAC channels
                            data[:, i] = 0.5 * np.sin(2 * np.pi * (i + 1) * timestamps) + 0.1 * np.random.randn(samples_per_update)
                        elif i in [4, 5, 6, 7, 8]:  # Digital-like signals
                            data[:, i] = np.random.choice([0, 5], samples_per_update, p=[0.95, 0.05])
                        else:
                            data[:, i] = 0.2 * np.sin(2 * np.pi * 0.5 * timestamps) + 0.05 * np.random.randn(samples_per_update)
                    
                    for i in range(self.emg_channels):
                        emg_idx = self.analog_channels + i
                        base_emg = 0.1 * np.random.randn(samples_per_update)
                        if np.random.random() < 0.1:
                            burst = 0.8 * np.exp(-((timestamps - current_time - 0.05) / 0.02) ** 2)
                            base_emg += burst
                        data[:, emg_idx] = base_emg
                    
                    # Store data
                    for ts, sample in zip(timestamps, data):
                        self.timestamps.append(ts)
                        self.data_buffer.append(sample)
                        
                        # Write to file: timestamp + data
                        file_data = np.concatenate([[ts], sample])
                        f.write(file_data.astype(np.float64).tobytes())
                    
                    time.sleep(self.update_rate)
                    
        except Exception as e:
            print(f"Simulation error: {e}")
            self.is_recording = False
    
    def get_plot_data(self):
        """Get current data for plotting individual channels"""
        if len(self.timestamps) == 0:
            return None
        
        times = np.array(list(self.timestamps))
        data = np.array(list(self.data_buffer))
        
        # Show only recent data based on history duration
        current_time = times[-1] if len(times) > 0 else 0
        mask = times >= (current_time - self.history_duration)
        
        plot_times = times[mask]
        plot_data = data[mask]
        all_channels = []
        all_labels = []
        
        # Add analog channels
        for i in range(self.analog_channels):
            all_channels.append(plot_data[:, i].tolist())
            all_labels.append(f"AI-{i}: {self.analog_short_labels[i]}")
        
        # Add EMG channels
        for i in range(self.emg_channels):
            emg_idx = self.analog_channels + i
            all_channels.append(plot_data[:, emg_idx].tolist())
            all_labels.append(f"EMG-{i+1}: {self.muscle_short_labels[i]}")
        
        return {
            'times': plot_times.tolist(),
            'channels': all_channels,
            'labels': all_labels,
            'analog_count': self.analog_channels,
            'emg_count': self.emg_channels
        }

daq = None

def get_daq_instance():
    """Get or create DAQ instance (defaults to simulation mode)"""
    global daq
    if daq is None:
        print("Initializing DAQ in simulation mode (default)")
        daq = DAQStreamer(use_hardware=False, config_file="channel_config.yaml")
    return daq

# Flask app
app = Flask(__name__)
app.config['SECRET_KEY'] = 'daq_individual_plots'
socketio = SocketIO(app, cors_allowed_origins="*")

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/connect', methods=['POST'])
def connect():
    print("API: Connect requested")
    try:
        daq_instance = get_daq_instance()
        success, message = daq_instance.connect_daq()
        result = {'success': success, 'message': message, 'trial_number': daq_instance.trial_number}
        print(f"API: Connect result: {result}")
        return jsonify(result)
    except Exception as e:
        daq_instance = get_daq_instance()
        error_result = {'success': False, 'message': f'Connect error: {str(e)}', 'trial_number': daq_instance.trial_number}
        print(f"API: Connect error: {error_result}")
        return jsonify(error_result)

@app.route('/api/start', methods=['POST'])
def start_recording():
    print("API: Start recording requested")
    try:
        daq_instance = get_daq_instance()
        success, message = daq_instance.start_recording()
        result = {'success': success, 'message': message}
        print(f"API: Start result: {result}")
        return jsonify(result)
    except Exception as e:
        error_result = {'success': False, 'message': f'Start error: {str(e)}'}
        print(f"API: Start error: {error_result}")
        return jsonify(error_result)

@app.route('/api/stop', methods=['POST'])
def stop_recording():
    print("API: Stop recording requested")
    try:
        daq_instance = get_daq_instance()
        success, message = daq_instance.stop_recording()
        result = {'success': success, 'message': message, 'trial_number': daq_instance.trial_number}
        print(f"API: Stop result: {result}")
        return jsonify(result)
    except Exception as e:
        daq_instance = get_daq_instance()
        error_result = {'success': False, 'message': f'Stop error: {str(e)}', 'trial_number': daq_instance.trial_number}
        print(f"API: Stop error: {error_result}")
        return jsonify(error_result)

@app.route('/api/status')
def get_status():
    daq_instance = get_daq_instance()
    return jsonify({
        'connected': daq_instance.is_connected,
        'recording': daq_instance.is_recording,
        'simulation': daq_instance.simulation_mode,
        'hardware': daq_instance.use_hardware,
        'trial_number': daq_instance.trial_number,
        'device_name': daq_instance.device_name,
        'output_directory': daq_instance.output_directory,
        'project_name': daq_instance.project_name,
        'default_directory': daq_instance.default_directory,
        'default_project': daq_instance.default_project,
        'web_update_interval': daq_instance.web_update_interval,
        'status_update_interval': daq_instance.status_update_interval,
        'grid_columns': daq_instance.grid_columns,
        'history_duration': daq_instance.history_duration
    })

@app.route('/api/settings', methods=['POST'])
def update_settings():
    print("API: Update settings requested")
    try:
        daq_instance = get_daq_instance()
        data = request.get_json()
        directory = data.get('directory', '').strip()
        project = data.get('project', '').strip()
        
        # Validate inputs
        if directory and not directory.replace('_', '').replace('-', '').replace('/', '').replace('\\', '').replace('.', '').isalnum():
            return jsonify({'success': False, 'message': 'Invalid directory name'})
        
        if project and not project.replace('_', '').replace('-', '').isalnum():
            return jsonify({'success': False, 'message': 'Invalid project name'})
        
        success, message = daq_instance.update_settings(directory, project)
        result = {'success': success, 'message': message}
        print(f"API: Settings result: {result}")
        return jsonify(result)
    except Exception as e:
        error_result = {'success': False, 'message': f'Settings error: {str(e)}'}
        print(f"API: Settings error: {error_result}")
        return jsonify(error_result)

@socketio.on('request_data')
def handle_data_request():
    """Send current data to web interface"""
    daq_instance = get_daq_instance()
    plot_data = daq_instance.get_plot_data()
    if plot_data:
        emit('data_update', plot_data)

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='DAQ GUI with Individual Channel Plots')
    parser.add_argument('--sim', '--simulation', action='store_true', 
                       help='Force simulation mode (default: auto-detect hardware)')
    parser.add_argument('--hardware', action='store_true',
                       help='Force hardware mode')
    parser.add_argument('--config', default='channel_config.yaml',
                       help='Path to YAML configuration file (default: channel_config.yaml)')
    parser.add_argument('--port', type=int, default=5000,
                       help='Web server port (default: 5000)')
    
    args = parser.parse_args()
    
    # Determine hardware mode
    if args.sim:
        use_hardware = False
        mode_reason = "forced by --sim argument"
    elif args.hardware:
        use_hardware = True
        mode_reason = "forced by --hardware argument"
    else:
        use_hardware = NIDAQ_AVAILABLE
        mode_reason = "auto-detected" if NIDAQ_AVAILABLE else "NIDAQ not available"
    
    # Create global DAQ instance
    global daq
    daq = DAQStreamer(use_hardware=use_hardware, config_file=args.config)
    
    print("=" * 60)
    print("DAQ GUI Server - Individual Channel Plots")
    print("=" * 60)
    print(f"Hardware mode: {daq.use_hardware} ({mode_reason})")
    print(f"Simulation mode: {daq.simulation_mode}")
    print(f"Device: {daq.device_name}")
    print(f"Config file: {args.config}")
    print(f"Web interface: http://localhost:{args.port}")
    print("=" * 60)
    print()
    print("Command line options:")
    print("  --sim          Force simulation mode")
    print("  --hardware     Force hardware mode")
    print("  --config FILE  Use custom config file")
    print("  --port PORT    Use custom port")
    print()
    print("Press Ctrl+C to stop")
    print("=" * 60)
    
    try:
        socketio.run(app, host='127.0.0.1', port=args.port, debug=False)
    except Exception as e:
        print(f"Server error: {e}")
        if daq and daq.is_recording:
            daq.stop_recording()

if __name__ == '__main__':
    main()