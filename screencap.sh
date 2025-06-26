#!/usr/bin/env bash
# ---------------------------------------------------------------------
#  screencap.sh  —  resilient, hardware-accelerated screen recorder
# ---------------------------------------------------------------------

set -euo pipefail

# ---------- dependency checking --------------------------------------
check_dependency() {
  local cmd=$1
  local package=$2
  
  if ! command -v "$cmd" &> /dev/null; then
    echo "❌ Error: '$cmd' is not installed."
    echo ""
    
    # Detect package manager and provide installation instructions
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS
      if command -v brew &> /dev/null; then
        echo "📦 To install with Homebrew:"
        echo "   brew install $package"
      elif command -v port &> /dev/null; then
        echo "📦 To install with MacPorts:"
        echo "   sudo port install $package"
      else
        echo "📦 Please install Homebrew first:"
        echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo ""
        echo "Then run:"
        echo "   brew install $package"
      fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      # Linux
      if command -v apt-get &> /dev/null; then
        echo "📦 To install on Debian/Ubuntu:"
        echo "   sudo apt-get update && sudo apt-get install $package"
      elif command -v dnf &> /dev/null; then
        echo "📦 To install on Fedora:"
        echo "   sudo dnf install $package"
      elif command -v yum &> /dev/null; then
        echo "📦 To install on RHEL/CentOS:"
        echo "   sudo yum install $package"
      elif command -v pacman &> /dev/null; then
        echo "📦 To install on Arch Linux:"
        echo "   sudo pacman -S $package"
      elif command -v zypper &> /dev/null; then
        echo "📦 To install on openSUSE:"
        echo "   sudo zypper install $package"
      else
        echo "📦 Please install $package using your distribution's package manager."
      fi
    else
      echo "📦 Please install $package for your operating system."
    fi
    
    echo ""
    return 1
  fi
  return 0
}

# Check required dependencies
check_dependencies() {
  local missing=0
  
  echo "🔍 Checking dependencies..."
  
  if ! check_dependency "ffmpeg" "ffmpeg"; then
    missing=1
  fi
  
  # On macOS, check for specific codecs
  if [[ "$OSTYPE" == "darwin"* ]] && command -v ffmpeg &> /dev/null; then
    if ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "hevc_videotoolbox"; then
      echo "⚠️  Warning: Hardware-accelerated HEVC codec not available."
      echo "   Your ffmpeg may need to be compiled with VideoToolbox support."
      echo "   Consider reinstalling ffmpeg with: brew reinstall ffmpeg"
    fi
  fi
  
  if [[ $missing -eq 1 ]]; then
    echo ""
    echo "❌ Missing dependencies detected. Please install them and try again."
    exit 1
  fi
  
  echo "✅ All dependencies satisfied."
  echo ""
}

# ---------- defaults -------------------------------------------------
SKIP_DEPS_CHECK=${SKIP_DEPS_CHECK:-0}

# Run dependency check unless explicitly skipped
if [[ $SKIP_DEPS_CHECK -eq 0 ]]; then
  check_dependencies
fi

# ---------- defaults -------------------------------------------------
OUT="capture_$(date +%Y%m%d_%H%M%S).mp4"
VID_DEV=4
AUD_DEV="none"
RES="auto"
FPS="auto"
QUAL=""                 # <-- empty for x264 (uses CRF instead)
CRF=23                  # <-- Constant Rate Factor for x264 (0-51, lower=better quality)
PRESET="medium"         # <-- x264 preset (ultrafast to veryslow)
CODEC="libx264"         # <-- x264 for better compatibility
TAG="avc1"
USE_SCK=0
SCK_FLAGS=()            # <-- always defined, avoids "unbound variable"
DURATION=""            # <-- always defined, avoids “unbound variable”
# ---------------------------------------------------------------------

usage() {
  echo "Usage: $0 [-o file] [-d vidDev] [-a audDev|none] [-r WxH|auto]"
  echo "          [-f N|auto] [-q quality] [-c codec] [-s] [--duration Ns]"
  echo ""
  echo "Options:"
  echo "  -o file          Output filename (default: capture_YYYYMMDD_HHMMSS.mp4)"
  echo "  -d vidDev        Video device index (default: 4 for screen capture)"
  echo "  -a audDev        Audio device index or 'none' (default: none)"
  echo "  -r WxH           Resolution or 'auto' (default: auto)"
  echo "  -f N             Framerate or 'auto' (default: auto)"
  echo "  -q crf           Video quality CRF 0-51 for x264 (default: 23)"
  echo "  -c codec         Video codec (default: libx264)"
  echo "  -p preset        x264 preset: ultrafast/fast/medium/slow (default: medium)"
  echo "  -s               Use ScreenCaptureKit (experimental)"
  echo "  --duration Ns    Record for N seconds (e.g. --duration 5s)"
  echo ""
  echo "Environment:"
  echo "  SKIP_DEPS_CHECK=1   Skip dependency checking for faster startup"
  echo ""
  echo "Examples:"
  echo "  $0 --duration 10s -o demo.mp4"
  echo "  $0 -r 1920x1080 -f 30 -q 80"
  echo "  SKIP_DEPS_CHECK=1 $0 --duration 5s"
  exit 1
}

# Parse long options first
for arg in "$@"; do
  shift
  case "$arg" in
    --duration) DURATION="$1"; shift ;;
    --duration=*) DURATION="${arg#*=}" ;;
    *) set -- "$@" "$arg" ;;
  esac
done

while getopts "o:d:a:r:f:q:c:p:sh" opt; do
  case $opt in
    o) OUT=$OPTARG ;;
    d) VID_DEV=$OPTARG ;;
    a) AUD_DEV=$OPTARG ;;
    r) RES=$OPTARG ;;
    f) FPS=$OPTARG ;;
    q) CRF=$OPTARG ;;    # Now sets CRF for x264
    c) CODEC=$OPTARG ;;
    p) PRESET=$OPTARG ;;
    s) USE_SCK=1 ;;
    h|*) usage ;;
  esac
done

case $CODEC in
  av1*)      TAG="av01" ;;
  *h264*|*x264*) TAG="avc1" ;;
  *hevc*|*h265*) TAG="hvc1" ;;
  *)         TAG="avc1" ;;  # Default to h264 tag
esac

# -------- probe helper ----------------------------------------------
get_modes() {
  # For screen capture devices, we can't list modes the same way
  # Just return some common resolutions and the actual screen resolution
  if [[ $VID_DEV =~ ^[0-9]+$ ]] && (( VID_DEV >= 4 )); then
    echo "3420x2224 60"
    echo "3420x2224 30"
    echo "1920x1080 60"
    echo "1920x1080 30"
    echo "1280x720 60"
    echo "1280x720 30"
  else
    ffmpeg -hide_banner -f avfoundation -list_options true \
           -video_device_index "$VID_DEV" -i "" 2>&1 |
    grep -Eo '[0-9]+x[0-9]+[[:space:]]+[0-9]+(\.[0-9]+)?[[:space:]]*fps' |
    awk '{gsub(/[[:space:]]+fps/,"",$0); printf "%sx%s %s\n",$1,$2,$3}'
  fi
}

MODES=$(get_modes || true)
if [[ -z $MODES ]]; then
  echo "⚠️  FFmpeg didn’t list modes for device $VID_DEV."
  MODES="1920x1080 30"
fi

# -------- pick resolution -------------------------------------------
if [[ $RES == auto ]]; then
  RES=$(echo "$MODES" | sort -nr -k1,1 -k2,2 | head -1 | awk '{print $1}')
elif ! echo "$MODES" | awk '{print $1}' | grep -qx "$RES"; then
  echo "⚠️  $RES not offered – falling back."
  RES=$(echo "$MODES" | sort -nr -k1,1 -k2,2 | head -1 | awk '{print $1}')
fi

# -------- pick frame-rate -------------------------------------------
available_fps=$(echo "$MODES" | grep "^$RES" | awk '{print $2}' | cut -d'.' -f1)
if [[ $FPS == auto ]]; then
  FPS=$(echo "$available_fps" | sort -nr | head -1)
elif ! echo "$available_fps" | grep -qx "$FPS"; then
  echo "⚠️  Requested fps not available – using $(echo "$available_fps" | head -1)."
  FPS=$(echo "$available_fps" | head -1)
fi

# -------- ScreenCaptureKit switch -----------------------------------
if (( USE_SCK )); then
  SCK_FLAGS=(-capture_screen "$VID_DEV" -pix_fmt 0rgb)
  NOTE=" (SCK)"
else
  NOTE=""
fi

echo "▶︎ Recording screen $VID_DEV → $OUT"
if [[ $CODEC == "libx264" ]]; then
  echo "   ${RES}@${FPS}fps | codec $CODEC crf=$CRF preset=$PRESET$NOTE"
else
  echo "   ${RES}@${FPS}fps | codec $CODEC q=$QUAL$NOTE"
fi
[[ -n $DURATION ]] && echo "   Duration: $DURATION"

# Warn about file sizes for high resolutions
if [[ $RES =~ ^[0-9]+x[0-9]+$ ]]; then
  WIDTH=${RES%x*}
  if (( WIDTH > 2560 )); then
    echo "   ⚠️  High resolution may result in large files (~1MB/s)"
    echo "   💡 For smaller files, use: -r 1920x1080 or -r 1280x720"
  fi
fi

# Build ffmpeg command with optional duration
FFMPEG_CMD=(
  ffmpeg -hide_banner
  -thread_queue_size 4096
  -f avfoundation -framerate "$FPS" -video_size "$RES"
)

# Add SCK flags if present
if [[ ${#SCK_FLAGS[@]} -gt 0 ]]; then
  FFMPEG_CMD+=("${SCK_FLAGS[@]}")
fi

# Add capture options and input
FFMPEG_CMD+=(
  -capture_cursor 1 -capture_mouse_clicks 1
  -i "${VID_DEV}:${AUD_DEV}"
)

# Add duration if specified
if [[ -n $DURATION ]]; then
  FFMPEG_CMD+=(-t "$DURATION")
fi

# Add output options
if [[ $CODEC == "libx264" ]]; then
  # x264 uses CRF and preset for quality control
  FFMPEG_CMD+=(
    -c:v "$CODEC" -crf "$CRF" -preset "$PRESET"
    -pix_fmt yuv420p  # Ensure compatibility
    -tag:v "$TAG"
  )
elif [[ -n $QUAL ]]; then
  # Other codecs use quality value
  FFMPEG_CMD+=(-c:v "$CODEC" -q:v "$QUAL" -tag:v "$TAG")
else
  # Default codec settings
  FFMPEG_CMD+=(-c:v "$CODEC" -tag:v "$TAG")
fi

# Add audio and format options
FFMPEG_CMD+=(
  -c:a aac -b:a 128k
  -movflags +faststart
  "$OUT"
)

# Execute the command
"${FFMPEG_CMD[@]}"
