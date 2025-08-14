# NIDAQ Hardware Setup Guide

## Quick Hardware Setup

### Prerequisites

1. **Install NI-DAQmx Drivers**
   - Download from: https://www.ni.com/en-us/support/downloads/drivers/download.ni-daqmx.html
   - Install the full NI-DAQmx runtime and drivers
   - Restart your computer after installation

2. **Install Python Package**
   ```bash
   pip install nidaqmx
   ```

3. **Verify Hardware Connection**
   - Use NI MAX (Measurement & Automation Explorer) to detect your device
   - Note your device name (e.g., "Dev1", "Dev2", etc.)

### Enabling Hardware Mode

**Command Line (Recommended):**
```bash
python daq_gui.py --hardware
```

**Edit Configuration:**
```yaml
# In channel_config.yaml:
hardware:
  device_name: "Dev1"  # Change to match your device name from NI MAX
```

### Channel Configuration

#### Analog Input Channels (16 channels)
- **Hardware channels**: Dev1/ai0 to Dev1/ai15
- **Terminal configuration**: Single-ended non-referenced
- **Voltage range**: ±10V (default)
- **Labels**: HUMAC, KINARM, VICON, Arduino, TMS signals

#### EMG Channels (4 channels)
- **Hardware channels**: Dev1/ai17, Dev1/ai27, Dev1/ai29, Dev1/ai23
- **Terminal configuration**: Single-ended
- **Voltage range**: ±10V (default)
- **Labels**: L_APB, L-FLEX, L_FDI, NC

### Hardware Wiring

#### Analog Input Connections
```
AI0  - HUMAC 1 Direction
AI1  - HUMAC 2 Velocity  
AI2  - HUMAC 3 Torque
AI3  - HUMAC 4 Position
AI4  - KINARM Task Start
AI5  - KINARM Recording Start
AI6  - KINARM Repetition Start
AI7  - VICON Recording start/stop
AI8  - VICON frame capture
AI9  - Grip Trigger
AI10 - Grip Dynomometer
AI11 - Pinch Dynomometer
AI12 - Arduino Trigger
AI13 - Arduino Amplitude
AI14 - Arduino Stim Active
AI15 - TMS Trig OUT
```

#### EMG Input Connections
```
AI17 - L_APB (EMG Channel 1)
AI27 - L-FLEX (EMG Channel 2)  
AI29 - L_FDI (EMG Channel 3)
AI23 - NC (EMG Channel 4)
```

### DAQ Device Settings

#### Recommended Hardware
- **NI USB-6363** (USB, 32 AI channels, 2.0 MS/s)
- **NI PCIe-6363** (PCIe, 32 AI channels, 2.0 MS/s)
- **NI USB-6212** (USB, 16 AI channels, 400 kS/s) - Budget option

#### Sampling Configuration
- **Sampling rate**: 2500 Hz per channel
- **Buffer size**: 2500 samples (1 second buffer)
- **Update rate**: 10 Hz (every 0.1 seconds)
- **Acquisition mode**: Continuous

### Running with Hardware

1. **Connect your DAQ device**
2. **Verify in NI MAX**
3. **Update the Python configuration**:
   ```python
   # In daq_gui_individual_plots.py
   daq = DAQStreamer(use_hardware=True)
   ```
4. **Run the application**:
   ```bash
   python daq_gui_individual_plots.py
   ```

### Troubleshooting

#### Common Issues

1. **"DAQ connection failed: Device not found"**
   - Check device name in NI MAX
   - Update `self.device_name` in the code
   - Ensure drivers are installed

2. **"Channel not available"**
   - Verify channel numbers in `self.emg_ch_map`
   - Check if your device has enough channels
   - Some devices may not have channels 17, 27, 29, 23

3. **"Sampling rate too high"**
   - Reduce `self.fs` from 2500 to 1000 Hz
   - Check your device's maximum sampling rate

4. **"Buffer overrun"**
   - Increase buffer size in hardware loop
   - Reduce update rate (increase `self.update_rate`)

#### Device-Specific Adjustments

**For USB-6212 (16 AI channels only):**
```python
# Modify EMG channel mapping to use available channels
self.emg_ch_map = [12, 13, 14, 15]  # Use last 4 analog channels for EMG
```

**For different voltage ranges:**
```python
# In _hardware_loop method, add voltage range setting:
chan.ai_min = -5.0  # Minimum voltage
chan.ai_max = 5.0   # Maximum voltage
```

### Testing Hardware Connection

Use this simple test script to verify your hardware:

```python
import nidaqmx

# Test basic connection
with nidaqmx.Task() as task:
    task.ai_channels.add_ai_voltage_chan("Dev1/ai0")
    task.timing.cfg_samp_clk_timing(1000)  # 1kHz
    data = task.read(number_of_samples_per_channel=100)
    print(f"Successfully read {len(data)} samples")
    print(f"Sample data: {data[:5]}")  # First 5 samples
```

### NI MAX Configuration

1. **Open NI MAX**
2. **Expand "Devices and Interfaces"**
3. **Find your DAQ device**
4. **Right-click → "Test Panels"**
5. **Test analog input channels**
6. **Verify channel numbers and ranges**

### Expected Performance

- **Latency**: ~100ms display update
- **Throughput**: 2500 samples/sec × 20 channels = 50,000 samples/sec
- **File size**: ~400 KB/second (binary format)
- **Memory usage**: ~3 seconds × 50,000 samples × 8 bytes = ~1.2 MB buffer

### Switching Between Modes

**Simulation Mode** (default):
```python
daq = DAQStreamer(use_hardware=False)
```

**Hardware Mode**:
```python
daq = DAQStreamer(use_hardware=True)
```

The application automatically detects if hardware is available and falls back to simulation mode if needed.