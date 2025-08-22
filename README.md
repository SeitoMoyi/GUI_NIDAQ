# MATLAB NIDAQ GUI for RNEL Lab

A MATLAB-based graphical user interface for real-time data acquisition and visualization using National Instruments Data Acquisition (NIDAQ) systems. This application is designed for electromyography (EMG) and analog signal recording in research environments.

**Author**: Peibin  
**Lab**: Rehab Neural Engineering Labs (RNEL)  
**Date**: August 2025  

## Overview

This system provides a comprehensive solution for real-time data acquisition from EMG electrodes and analog input channels using National Instruments DAQ hardware. The application features multi-tab visualization, real-time plotting, automatic trial numbering, and structured data storage with metadata tracking.

## System Requirements

### Hardware
- National Instruments DAQ device (tested with Dev1)
- Up to 80 analog input channels (16 general analog + 64 EMG channels)
- Windows operating system

### Software
- MATLAB R2020a or later
- Data Acquisition Toolbox
- National Instruments DAQmx drivers
- App Designer (for GUI modifications)

## Features

### Core Functionality
- Real-time data acquisition at 2500 Hz sampling rate
- Multi-channel EMG recording with configurable channel mapping
- Analog input channels for various sensors (HUMAC, KINARM, VICON, etc.)
- Live signal visualization with customizable Y-axis limits
- Automatic trial numbering and file management
- Binary data storage with comprehensive metadata

### User Interface
- Three-tab display system:
  - **EMG tab**: Up to 4 EMG channels simultaneously
  - **Analog tab**: Up to 2 analog channels simultaneously  
  - **Combined tab**: Up to 6 channels from any source
- Channel selection via dropdown lists
- Real-time plotting with 2-second circular buffer
- Status indicators and control buttons
- Path selection for data storage

### Data Management
- Binary file format (.bin) for efficient storage
- Metadata files (.mat) with acquisition parameters
- Automatic directory structure with metadata subfolder
- Trial summary plots generated after each recording
- Configurable channel mapping via JSON configuration

## File Structure

```
matlab/
├── DAQ_App.m              # Main application class
├── DAQ_App_Designer.mlapp # MATLAB App Designer file (same code as DAQ_App.m)
├── CH_config.json         # Channel configuration
└── get_nxt_trialnb.m      # Trial number management utility
```

## Channel Configuration

The system supports flexible channel mapping through `CH_config.json`:

### EMG Channels
- 16 EMG channels mapped to specific DAQ inputs
- Configurable muscle labels (e.g., "L_APB", "L-FLEX", "L_FDI")
- Default channel numbers: [17,27,29,23,41,43,37,47,57,51,61,63,65,75,77,71]

### Analog Input Channels
- 16 analog channels for various sensors:
  - HUMAC system (Direction, Velocity, Torque, Position)
  - KINARM system (Task, Recording, Repetition signals)
  - VICON motion capture triggers
  - Grip and pinch dynamometers
  - Arduino and TMS trigger signals

Example configuration:
```json
{
    "EMG_CH": [17, 27, 29, 23, 41, 43, 37, 47, 57, 51, 61, 63, 65, 75, 77, 71],
    "muscle_labels": ["L_APB", "NC_1", "L-FLEX", "L_FDI", "NC_2", "NC_3", ...],
    "analog_input_labels": ["HUMAC Dir", "HUMAC Vel", "HUMAC Torque", "HUMAC Pos", ...]
}
```

## Usage Instructions

### 1. Initial Setup
1. Connect your National Instruments DAQ device
2. Ensure all EMG electrodes and analog sensors are properly connected
3. Launch MATLAB and navigate to the project directory
4. Run `DAQ_App` or open `DAQ_App_Designer.mlapp`

### 2. Configuration
1. Modify `CH_config.json` if needed for your specific setup
2. Verify channel mappings match your hardware connections
3. Set muscle labels according to your experimental protocol

### 3. Data Acquisition Workflow
1. **Connect**: Click "Connect" button to initialize DAQ hardware
2. **Select Path**: Choose directory for data storage
3. **Session Info**: Enter Subject ID and session name
4. **Channel Selection**: Choose channels to display in each tab
5. **Start Recording**: Click "Start" to begin data acquisition
6. **Monitor**: View real-time signals in the selected tab
7. **Stop Recording**: Click "Stop" to end recording and save data

### 4. Data Output
Each recording session generates:
- **Binary data file**: `YYYYMMDD_HHMMSS_SubjectID_SessionName_TrlXXX.bin`
- **Metadata file**: `YYYYMMDD_HHMMSS_SubjectID_SessionName_METADATA_TrlXXX.mat`
- **Summary plot**: Automatically displayed after recording

## Data Format

### Binary Files
- **Format**: Double precision (8 bytes per sample)
- **Structure**: [timestamp, channel_1, channel_2, ..., channel_80]
- **Sampling Rate**: 2500 Hz
- **Total Channels**: 80 (16 analog + 64 EMG potential channels)

### Metadata Structure
```matlab
meta_data.sub_id              % Subject identifier
meta_data.date                % Recording date
meta_data.timestamp           % Recording time
meta_data.exp_name            % Experiment/session name
meta_data.trl_num             % Trial number
meta_data.fs                  % Sampling frequency (2500 Hz)
meta_data.emg_ch_number       % EMG channel mapping
meta_data.musc_labels         % Muscle labels
meta_data.analog_input_labels % Analog channel labels
meta_data.total_analog_in_ch  % Total number of channels (80)
```

## Key Functions

### Main Application (`DAQ_App.m`)
- `startupFcn`: Loads configuration and initializes UI
- `InitializeButtonPushed`: Connects to DAQ hardware
- `StartButtonPushed`: Begins data acquisition
- `StopButtonPushed`: Stops recording and saves data
- `logBroadcastAndPlotData`: Main data callback function
- `updatePlots`: Handles real-time visualization
- `generateSummaryPlot`: Creates post-recording summary

### Utility Functions
- `get_nxt_trialnb.m`: Automatically determines next trial number based on existing files

## Real-time Visualization

The application provides three visualization modes:

1. **EMG Tab**: Displays up to 4 EMG channels with DC offset removal
2. **Analog Tab**: Shows up to 2 analog channels with raw signals
3. **Combined Tab**: Allows viewing up to 6 channels from any source

Features:
- Customizable Y-axis limits for each tab
- 2-second circular buffer for smooth real-time display
- Channel selection via dropdown menus
- Automatic scaling and labeling

## Technical Specifications

### Performance Characteristics
- **Sampling Rate**: 2500 Hz
- **Channel Count**: 80 total (16 analog + up to 64 EMG)
- **Data Type**: 64-bit double precision
- **Display Update Rate**: 10 Hz (every 0.1 seconds)
- **Buffer Duration**: 2 seconds for real-time display
- **File Size**: Approximately 5.5 MB per minute (80 channels)

### Hardware Configuration
- **Terminal Configuration**: 
  - Analog channels (0-15): Single-ended non-referenced
  - EMG channels (16-79): Single-ended
- **Voltage Range**: ±10V (default)
- **Input Impedance**: High impedance suitable for EMG signals

## Troubleshooting

### Common Issues

1. **"No NI DAQ devices found"**
   - Verify DAQ device is connected and powered
   - Check NI-DAQmx drivers are installed
   - Run `daqlist("ni")` in MATLAB to verify detection

2. **"Path not selected" error**
   - Click "Select Path" button before starting recording
   - Ensure write permissions to the selected directory

3. **Poor signal quality**
   - Check electrode connections and impedances
   - Verify channel mapping in `CH_config.json`
   - Adjust Y-axis limits for better visualization

4. **File writing errors**
   - Check disk space availability
   - Verify folder permissions
   - Ensure path doesn't contain invalid characters

### Performance Tips
- Use SSD storage for better I/O performance
- Close unnecessary applications during recording
- Monitor system resources during long recordings
- Regular cleanup of old data files

## Data Analysis

To read and analyze recorded data, you can use standard MATLAB file I/O:

```matlab
% Open binary file
fid = fopen('your_data_file.bin', 'r');

% Read data (80 channels + 1 timestamp column = 81 total)
data = fread(fid, [81, inf], 'double');
fclose(fid);

% Separate timestamp and channels
timestamps = data(1, :);
channel_data = data(2:end, :);

% Load metadata for channel information
load('corresponding_metadata_file.mat');
```

## System Integration

This GUI is designed to work with various laboratory systems:
- **HUMAC dynamometers** for strength testing
- **KINARM robotic systems** for motor assessment
- **VICON motion capture** for movement analysis
- **Custom Arduino triggers** for experiment synchronization
- **TMS systems** for neural stimulation studies

## Maintenance and Support

### Regular Maintenance
- Update NI-DAQmx drivers periodically
- Clean temporary files and old data regularly
- Backup configuration files
- Test system functionality before critical experiments

### Code Modifications
- Channel configurations: Edit `CH_config.json`
- UI modifications: Use MATLAB App Designer with `DAQ_App_Designer.mlapp`
- Core functionality: Modify `DAQ_App.m`

## License and Acknowledgments

Developed for research use in the Rehab Neural Engineering Labs (RNEL). This software is designed to integrate with laboratory equipment and research protocols specific to the RNEL environment.

**Note**: This documentation corresponds to the final version prepared by Peibin before lab transition. For ongoing support, refer to laboratory documentation and MATLAB/NI resources.
