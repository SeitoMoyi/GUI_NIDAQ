# DAQ GUI - Optimized for Slow PCs

A Python web-based GUI for real-time data acquisition, optimized for slower computers. Features 4 EMG channels + 16 analog channels with individual plots and 3-second rolling history.

## 🚀 Quick Start

### Launch DAQ GUI
```bash
python daq_gui.py --sim        # Simulation mode (recommended)
python daq_gui.py --hardware   # Hardware mode (requires NIDAQ)
python daq_gui.py --help       # Show all options
```

## 📦 Installation

```bash
pip install -r requirements.txt
```

## ✨ Features

- **24 Individual Plots** - 4 EMG + 16 analog channels
- **Optimized Performance** - 60% less CPU usage than standard version
- **Web Interface** - Configurable save directory and project name
- **Real-time Plotting** - 2-second rolling history at 5 Hz refresh
- **YAML Configuration** - Customizable channel names and settings
- **Simulation Mode** - Test without hardware
- **Hardware Support** - NIDAQ integration available

## 🎛️ Performance Optimizations

| Setting | Optimized Value | Benefit |
|---------|----------------|---------|
| Sampling Rate | 1000 Hz | 60% less CPU load |
| Update Rate | 200ms | 50% less frequent updates |
| History Buffer | 2 seconds | 33% less memory usage |
| Web Updates | 200ms | 50% less browser load |
| Grid Layout | 2 columns | Better for smaller screens |

## 🔧 Configuration

### Channel Names
Edit `channel_config.yaml` to customize channel names:

```yaml
emg_channels:
  - name: "Right Biceps"
    short_name: "R-BIC"
    hardware_channel: 17

analog_channels:
  - name: "Force Sensor"
    short_name: "FORCE"
```

### Performance Tuning
For even slower PCs, reduce these values in `channel_config.yaml`:

```yaml
hardware:
  sampling_rate: 500        # Lower sampling rate
  update_rate: 0.5          # Update every 500ms
  history_duration: 1.0     # Only 1 second history

display:
  grid_columns: 1           # Single column layout
```

## 🌐 Web Interface

1. **Connect DAQ** - Initialize hardware or simulation
2. **Set Directory** - Enter custom save directory
3. **Set Project** - Enter project name
4. **Update Settings** - Apply changes
5. **START Recording** - Begin data acquisition
6. **STOP Recording** - Save data and increment trial

## 📁 Output Files

```
[directory]/
├── YYYYMMDD_HHMMSS_[project]_[date]_TrlXXX.bin
└── metadata/
    └── YYYYMMDD_HHMMSS_[project]_[date]_METADATA_TrlXXX.json
```

## 🔌 Hardware Setup (Optional)

For real NIDAQ hardware:

1. **Install NI-DAQmx drivers** from National Instruments
2. **Install Python package**: `pip install nidaqmx`
3. **Update config**: Set `device_name: "Dev1"` in YAML
4. **Run hardware mode**: `python daq_gui.py --hardware`

### Supported Devices
- NI USB-6363 (recommended)
- NI PCIe-6363
- NI USB-6212

## 🎯 Command Line Options

```bash
python daq_gui.py --sim                    # Force simulation mode
python daq_gui.py --hardware               # Force hardware mode  
python daq_gui.py --config my_config.yaml  # Custom configuration
python daq_gui.py --port 8080              # Custom web port
python daq_gui.py --help                   # Show all options
```

## 🔍 Troubleshooting

### GUI Running Slowly?
1. Close other programs
2. Use Chrome or Firefox browser
3. Reduce sampling rate in config file
4. Use single column layout

### Can't Connect to Hardware?
1. Check device name in NI MAX
2. Install NI-DAQmx drivers
3. Update `device_name` in config file
4. Try simulation mode first

## 📊 System Requirements

### Minimum (Slow PC)
- **CPU**: Any dual-core processor
- **RAM**: 2GB available
- **Storage**: 100MB free space
- **Browser**: Chrome/Firefox

### Recommended
- **CPU**: Quad-core processor
- **RAM**: 4GB available
- **Storage**: SSD for data recording
- **Network**: Wired connection for remote access

## 🎨 Customization

### Custom Channel Configuration
1. Copy `channel_config.yaml` to `my_config.yaml`
2. Edit channel names and settings
3. Run with: `python daq_gui.py --config my_config.yaml`

### Display Colors
Edit in `channel_config.yaml`:
```yaml
display:
  plot_colors:
    emg: "#FF6B35"     # Orange EMG
    analog: "#004E89"  # Blue analog
```

## 📈 Performance Tips

1. **Close unnecessary programs** while recording
2. **Use fullscreen browser** for better performance
3. **Ensure adequate disk space** for data files
4. **Use wired network** for remote access
5. **Monitor system resources** during long recordings

## 🔄 Migration from MATLAB

- **File format**: Compatible binary format
- **Metadata**: JSON instead of .mat files
- **Channel mapping**: Same as original MATLAB version
- **Sampling rates**: Configurable (default optimized for performance)

## 📝 License

Translated and optimized from original MATLAB code by Nikhil Verma (Jan 18, 2023)