# screencap.sh

A powerful, single-file screen recording script for macOS with advanced selection and encoding options.

## Features

- 🎯 **Area Selection** - Click and drag to record specific screen regions
- 🖥️ **Multi-Monitor Support** - Interactive monitor selection with thumbnails and bitrate estimates
- 🪟 **Window Recording** - Select and record individual windows
- 🚀 **Hardware Acceleration** - Uses VideoToolbox for efficient encoding
- 🎨 **Codec Control** - H.264/x264, HEVC, AV1 with customizable quality settings
- ⏱️ **Timed Recordings** - Set duration with `--duration` option
- 🔍 **Auto Dependency Checking** - Provides installation help if tools are missing
- 📊 **Bitrate Estimation** - Shows file size estimates before recording
- 🖼️ **Preview Thumbnails** - Optional ASCII art previews of monitors (with chafa/viu)

## Installation

```bash
# Clone the repository
git clone https://github.com/boxabirds/screencap.sh.git
cd screencap.sh

# Make the script executable
chmod +x screencap.sh
```

### Dependencies

The script automatically checks for required dependencies and offers to install them.

**Required:**
```bash
# macOS (via Homebrew)
brew install ffmpeg
```

**Optional (for thumbnail previews):**
```bash
# The script will offer to install these when using --select-monitor
brew install chafa   # ASCII art image viewer
brew install viu     # Alternative image viewer
```

## Usage

### Basic Usage

```bash
# Record full screen (press Ctrl+C to stop)
./screencap.sh

# Record for 30 seconds
./screencap.sh --duration 30s

# Record with custom filename
./screencap.sh -o demo.mp4
```

### Advanced Selection Modes

```bash
# Select which monitor to record (interactive)
./screencap.sh --select-monitor

# Select a specific area to record
./screencap.sh --select-area

# Select a specific window to record
./screencap.sh --select-window

# Combine selection with other options
./screencap.sh --select-area --duration 60s -o area_demo.mp4
```

### Quality and Encoding Options

```bash
# High quality recording (lower CRF = higher quality)
./screencap.sh -q 18 -p slow

# Specific resolution and framerate
./screencap.sh -r 1920x1080 -f 60

# Use H.264 instead of default H.265/HEVC
./screencap.sh -c libx264

# Fast encoding (for live streaming or quick captures)
./screencap.sh -p ultrafast -q 28
```

### Performance Tips

```bash
# Skip dependency checking for faster startup
SKIP_DEPS_CHECK=1 ./screencap.sh

# Skip thumbnail previews in monitor selection
NO_PREVIEW=1 ./screencap.sh --select-monitor
```

## Options

### Selection Options
- `--select-monitor` - Interactive monitor selection with thumbnails and stats
- `--select-area` - Click and drag to select a screen region to record
- `--select-window` - Click on a window to record just that window

### Recording Options
- `-o file` - Output filename (default: `capture_YYYYMMDD_HHMMSS.mp4`)
- `-d vidDev` - Video device index (default: auto-detected)
- `-a audDev` - Audio device index or 'none' (default: none)
- `-r WxH` - Resolution or 'auto' (default: auto)
- `-f N` - Framerate or 'auto' (default: 30 for screen recording)
- `--duration Ns` - Record for N seconds (e.g., `--duration 30s`)

### Encoding Options
- `-c codec` - Video codec: `libx264`, `hevc_videotoolbox`, `av1` (default: `libx264`)
- `-q crf` - Quality (CRF): 0-51 for x264/x265, lower = better (default: 23)
- `-p preset` - Encoding preset: `ultrafast`, `fast`, `medium`, `slow` (default: `medium`)
- `-s` - Use ScreenCaptureKit (experimental macOS 12.3+ feature)

## Environment Variables

- `SKIP_DEPS_CHECK=1` - Skip dependency checking for faster startup
- `NO_PREVIEW=1` - Disable thumbnail previews in monitor selection

## How It Works

### Monitor Selection (`--select-monitor`)
1. Detects all connected monitors using FFmpeg's AVFoundation
2. Creates thumbnail screenshots of each monitor
3. Shows resolution, estimated bitrate, and file size for each
4. Optionally displays ASCII art previews (if chafa/viu installed)

### Area Selection (`--select-area`)
1. Uses macOS's built-in `screencapture` tool for visual selection
2. Captures the selected area dimensions
3. Records full screen with FFmpeg, then crops to selected region
4. Requires screen recording permissions in System Preferences

### Encoding
- Uses FFmpeg with AVFoundation input on macOS
- Supports hardware acceleration via VideoToolbox
- Records full screen, then applies filters/crops as needed
- Outputs to MP4 container with H.264/H.265/AV1 video

## Permissions Required

On macOS, you may need to grant permissions:
1. **Screen Recording**: System Preferences → Security & Privacy → Privacy → Screen Recording
2. **Accessibility** (for window selection): System Preferences → Security & Privacy → Privacy → Accessibility

Add your terminal application (Terminal.app, iTerm2, etc.) to these lists.

## Limitations

- Area/window selection records full screen then crops (uses more CPU than ideal)
- Window recording requires window to stay in same position
- Position detection for area selection is approximate
- No audio recording with area/window selection (full screen only)

## Requirements

- macOS 10.15+ (Catalina or newer)
- FFmpeg with AVFoundation support
- Bash 4.0+
- Optional: chafa or viu for thumbnail previews

## License

MIT License - see LICENSE file for details