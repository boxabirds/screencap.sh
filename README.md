# screencap.sh

A resilient, hardware-accelerated screen recorder for macOS and Linux.

## Features

- 🚀 Hardware-accelerated encoding using VideoToolbox (macOS) or VAAPI/NVENC (Linux)
- 🎯 Simple command-line interface
- ⏱️ Timed recordings with `--duration` option
- 🔍 Automatic dependency checking with installation instructions
- 📹 Configurable quality, resolution, and framerate
- 🎤 Optional audio recording support

## Installation

```bash
# Clone the repository
git clone https://github.com/boxabirds/screencap.sh.git
cd screencap.sh

# Make the script executable
chmod +x screencap.sh
```

### Dependencies

The script will automatically check for required dependencies and provide installation instructions if anything is missing.

**macOS:**
```bash
brew install ffmpeg
```

**Ubuntu/Debian:**
```bash
sudo apt-get update && sudo apt-get install ffmpeg
```

## Usage

### Basic screen recording (press Ctrl+C to stop):
```bash
./screencap.sh
```

### Record for a specific duration:
```bash
./screencap.sh --duration 10s
```

### Custom output filename:
```bash
./screencap.sh -o demo.mp4
```

### Specify resolution and framerate:
```bash
./screencap.sh -r 1920x1080 -f 30
```

### Skip dependency checking (faster startup):
```bash
SKIP_DEPS_CHECK=1 ./screencap.sh --duration 5s
```

## Options

- `-o file` - Output filename (default: `capture_YYYYMMDD_HHMMSS.mp4`)
- `-d vidDev` - Video device index (default: 4 for screen capture on macOS)
- `-a audDev` - Audio device index or 'none' (default: none)
- `-r WxH` - Resolution or 'auto' (default: auto)
- `-f N` - Framerate or 'auto' (default: auto)
- `-q quality` - Video quality 0-100 (default: 65)
- `-c codec` - Video codec (default: hevc_videotoolbox on macOS)
- `-s` - Use ScreenCaptureKit (experimental)
- `--duration Ns` - Record for N seconds (e.g. --duration 5s)

## Environment Variables

- `SKIP_DEPS_CHECK=1` - Skip dependency checking for faster startup

## Requirements

- macOS 10.15+ or Linux
- ffmpeg with hardware acceleration support
- Screen recording permissions (macOS)

## License

MIT License - see LICENSE file for details