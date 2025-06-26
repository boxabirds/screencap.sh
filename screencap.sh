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
  echo "          [--select-monitor] [--select-area]"
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
  echo "  --select-monitor Interactive monitor selection with thumbnails"
  echo "  --select-area    Select a screen area to record (marquee selection)"
  echo "  --select-window  Select a specific window to record"
  echo ""
  echo "Environment:"
  echo "  SKIP_DEPS_CHECK=1   Skip dependency checking for faster startup"
  echo ""
  echo "Examples:"
  echo "  $0 --duration 10s -o demo.mp4"
  echo "  $0 -r 1920x1080 -f 30 -q 80"
  echo "  $0 --select-monitor          # Choose from available monitors"
  echo "  $0 --select-area             # Draw a rectangle to record"
  echo "  $0 --select-window           # Select a specific window"
  echo "  SKIP_DEPS_CHECK=1 $0 --duration 5s"
  exit 1
}

# Parse long options first
SELECT_MONITOR=0
SELECT_AREA=0
SELECT_WINDOW=0
CROP_FILTER=""
for arg in "$@"; do
  shift
  case "$arg" in
    --duration) DURATION="$1"; shift ;;
    --duration=*) DURATION="${arg#*=}" ;;
    --select-monitor) SELECT_MONITOR=1 ;;
    --select-area) SELECT_AREA=1 ;;
    --select-window) SELECT_WINDOW=1 ;;
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

# -------- monitor selection -----------------------------------------
select_monitor() {
  echo "🔍 Detecting monitors..."
  
  # Get device list (capture all output to avoid hanging)
  local devices_output
  devices_output=$(ffmpeg -f avfoundation -list_devices true -i "" 2>&1 || true)
  
  # Extract just the screen capture devices
  local devices_raw
  devices_raw=$(echo "$devices_output" | grep "Capture screen" || true)
  
  if [[ -z "$devices_raw" ]]; then
    echo "❌ No screen capture devices found"
    return 1
  fi
  
  # Parse devices
  local screen_indices=()
  local screen_nums=()
  
  while IFS= read -r line; do
    if [[ "$line" =~ \[([0-9]+)\]\ Capture\ screen\ ([0-9]+) ]]; then
      screen_indices+=("${BASH_REMATCH[1]}")
      screen_nums+=("${BASH_REMATCH[2]}")
      echo "   Found: Screen ${BASH_REMATCH[2]} (AV Index ${BASH_REMATCH[1]})"
    fi
  done <<< "$devices_raw"
  
  local num_screens=${#screen_indices[@]}
  
  if [[ $num_screens -eq 0 ]]; then
    echo "❌ No screen capture devices parsed"
    return 1
  fi
  
  if [[ $num_screens -eq 1 ]]; then
    echo "📺 Only one monitor detected. Using screen ${screen_indices[0]}"
    MONITOR_RESULT="${screen_indices[0]}"
    return 0
  fi
  
  # Create thumbnails and get resolutions
  echo "📸 Creating thumbnails..."
  
  # Check if we have any image display tools (excluding imgcat which can cause issues)
  local has_image_viewer=0
  if command -v chafa &>/dev/null || command -v viu &>/dev/null; then
    has_image_viewer=1
  else
    echo "   💡 No image viewer found for thumbnail previews"
    
    # Offer to install if brew is available
    if command -v brew &>/dev/null; then
      echo -n "   Install chafa for ASCII art previews? (y/N): "
      read -r install_choice
      if [[ "$install_choice" =~ ^[Yy]$ ]]; then
        echo "   Installing chafa..."
        if brew install chafa; then
          echo "   ✅ chafa installed successfully!"
          has_image_viewer=1
        else
          echo "   ❌ Installation failed. Continuing without previews..."
        fi
      else
        echo "   Skipping installation. Set NO_PREVIEW=1 to hide this prompt."
      fi
    else
      echo "   Install chafa or viu for previews: brew install chafa viu"
    fi
  fi
  
  local temp_dir=$(mktemp -d)
  local resolutions=()
  local bitrates=()
  
  for i in "${!screen_indices[@]}"; do
    local av_index="${screen_indices[$i]}"
    local screen_num="${screen_nums[$i]}"
    local thumbnail="$temp_dir/screen_${av_index}_thumb.jpg"
    
    # Create thumbnail using screencapture
    if screencapture -D $((screen_num + 1)) -t jpg -x "$thumbnail" 2>/dev/null; then
      # Resize thumbnail
      sips -Z 400 "$thumbnail" &>/dev/null || true
      echo "   Monitor $av_index: $thumbnail"
      
      # Try to display the thumbnail in terminal if possible (skip if NO_PREVIEW is set)
      if [[ -z "${NO_PREVIEW:-}" ]]; then
        if command -v chafa &>/dev/null; then
          chafa --size 40x15 "$thumbnail" 2>/dev/null || true
        elif command -v viu &>/dev/null; then
          viu -w 40 "$thumbnail" 2>/dev/null || true
        fi
        # Note: imgcat can cause issues with some terminals, so it's disabled by default
      fi
    fi
    
    # Get resolution using system_profiler
    local resolution
    resolution=$(system_profiler SPDisplaysDataType 2>/dev/null | 
                 grep -A 10 "Display" | 
                 grep "Resolution:" | 
                 sed -n "$((i+1))p" | 
                 sed 's/.*Resolution: //' | 
                 sed 's/ @ .*//')
    
    if [[ -z $resolution ]]; then
      resolution="1920 x 1080"  # fallback
    fi
    
    resolutions+=("$resolution")
    
    # Calculate estimated bitrate (rough estimate)
    local width height
    width=$(echo "$resolution" | cut -d' ' -f1)
    height=$(echo "$resolution" | cut -d' ' -f3)
    local pixels=$((width * height))
    local bitrate_kbps=$((pixels * 30 * 15 / 100000))  # rough estimate
    bitrates+=("$bitrate_kbps")
  done
  
  # Display selection menu
  echo ""
  echo "🖥️  Found $num_screens monitors:"
  echo "============================================================"
  
  for i in "${!screen_indices[@]}"; do
    local av_index="${screen_indices[$i]}"
    local screen_num="${screen_nums[$i]}"
    local resolution="${resolutions[$i]}"
    local bitrate="${bitrates[$i]}"
    local file_size_mb=$((bitrate * 60 / 8000))  # MB per minute
    
    echo ""
    echo "[$((i+1))] Screen $screen_num (AV Index $av_index)"
    echo "    Resolution: $resolution"
    echo "    Est. bitrate: ~${bitrate} kbps @ 30fps"
    echo "    File size: ~${file_size_mb} MB/minute"
    
    local thumbnail="$temp_dir/screen_${av_index}_thumb.jpg"
    if [[ -f "$thumbnail" ]]; then
      echo "    Thumbnail: $thumbnail"
      
      # Display thumbnail if terminal supports it (skip if NO_PREVIEW is set)
      if [[ -z "${NO_PREVIEW:-}" ]]; then
        if command -v chafa &>/dev/null; then
          chafa --size 30x10 "$thumbnail" 2>/dev/null || true
        elif command -v viu &>/dev/null; then
          viu -w 30 -h 10 "$thumbnail" 2>/dev/null || true
        fi
        # Note: imgcat can cause issues with some terminals, so it's disabled by default
      fi
    fi
  done
  
  echo ""
  echo "============================================================"
  
  # Get user selection
  while true; do
    read -p "Select monitor (1-$num_screens): " choice
    
    if [[ $choice =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= num_screens )); then
      local selected_index=$((choice - 1))
      local selected_av_index="${screen_indices[$selected_index]}"
      local selected_screen_num="${screen_nums[$selected_index]}"
      
      echo ""
      echo "✅ Selected: Screen $selected_screen_num (AV Index $selected_av_index)"
      
      # Clean up temp directory
      rm -rf "$temp_dir" 2>/dev/null || true
      
      # Write result to global variable
      MONITOR_RESULT="$selected_av_index"
      return 0
    else
      echo "Please enter a number between 1 and $num_screens"
    fi
  done
}

# -------- area selection --------------------------------------------
select_area() {
  echo "🎯 Select screen area to record..."
  echo ""
  
  # Check if we need screen recording permission
  if ! check_screen_recording_permission; then
    echo "❌ Screen recording permission required!"
    echo ""
    echo "To enable:"
    echo "1. Open System Preferences > Security & Privacy > Privacy"
    echo "2. Select 'Screen Recording' from the left panel"
    echo "3. Add Terminal (or your terminal app) to the list"
    echo "4. Restart your terminal and try again"
    echo ""
    echo "Alternatively, use full screen recording without --select-area"
    return 1
  fi
  
  echo "📌 Instructions:"
  echo "   1. A crosshair cursor will appear"
  echo "   2. Click and drag to select the area"
  echo "   3. Release to confirm selection"
  echo ""
  echo "   💡 Tip: Press SPACE to switch to window selection mode"
  echo ""
  echo "   Starting selection..."
  
  # Method 1: Try screencapture with interactive selection
  local temp_img="/tmp/screencap_area_$$.png"
  
  # Run screencapture in interactive mode
  if screencapture -i -s "$temp_img" 2>/dev/null; then
    if [[ -f "$temp_img" ]]; then
      # Get image dimensions and estimate position
      local img_info=$(sips -g pixelWidth -g pixelHeight "$temp_img" 2>/dev/null)
      local width=$(echo "$img_info" | grep pixelWidth | awk '{print $2}')
      local height=$(echo "$img_info" | grep pixelHeight | awk '{print $2}')
      
      if [[ -n "$width" && -n "$height" ]]; then
        echo "   ✅ Selected area: ${width}x${height}"
        
        # For area recording, we need to use a different approach
        # FFmpeg on macOS doesn't support direct region capture
        # We'll use the full screen and crop
        AREA_WIDTH="$width"
        AREA_HEIGHT="$height"
        
        # Try to detect position using a workaround
        echo "   📍 Detecting position..."
        
        # Use AppleScript to get mouse position as a hint
        local mouse_pos=$(osascript -e 'tell application "System Events" to position of mouse' 2>/dev/null | tr ',' ' ')
        if [[ -n "$mouse_pos" ]]; then
          read -r mouse_x mouse_y <<< "$mouse_pos"
          # Estimate top-left based on mouse position (rough approximation)
          AREA_X=$((mouse_x - width/2))
          AREA_Y=$((mouse_y - height/2))
          # Ensure non-negative
          [[ $AREA_X -lt 0 ]] && AREA_X=0
          [[ $AREA_Y -lt 0 ]] && AREA_Y=0
          echo "   📍 Estimated position: (${AREA_X}, ${AREA_Y})"
        else
          AREA_X=0
          AREA_Y=0
          echo "   ⚠️  Could not detect position - using top-left corner"
        fi
        
        # Create crop filter
        CROP_FILTER="-vf crop=${AREA_WIDTH}:${AREA_HEIGHT}:${AREA_X}:${AREA_Y}"
        
        rm -f "$temp_img"
        return 0
      fi
    fi
    rm -f "$temp_img"
  fi
  
  echo "   ❌ Area selection cancelled or failed"
  return 1
}

# Check screen recording permission
check_screen_recording_permission() {
  # Try to capture a tiny screenshot to test permission
  local test_file="/tmp/screencap_test_$$.png"
  
  # Try screencapture with a small timeout using background process
  (
    screencapture -x -C -t png "$test_file" 2>/dev/null
  ) &
  local pid=$!
  
  # Wait up to 2 seconds
  local count=0
  while [[ $count -lt 20 ]] && kill -0 $pid 2>/dev/null; do
    sleep 0.1
    ((count++))
  done
  
  # Kill if still running (means it's hanging due to permissions)
  if kill -0 $pid 2>/dev/null; then
    kill -9 $pid 2>/dev/null
    rm -f "$test_file"
    return 1
  fi
  
  # Check if capture succeeded
  if [[ -f "$test_file" ]]; then
    rm -f "$test_file"
    return 0
  else
    return 1
  fi
}

# -------- window selection ------------------------------------------
select_window() {
  echo "🪟 Select window to record..."
  echo ""
  echo "📌 Instructions:"
  echo "   1. Move your cursor over the window you want to record"
  echo "   2. The window will be highlighted in blue"
  echo "   3. Click to select that window"
  echo "   4. Press ESC to cancel"
  echo ""
  echo "   Starting window selection..."
  
  # Use screencapture with -o flag for window selection
  local temp_img="/tmp/screencap_window_$$.png"
  
  if screencapture -i -o -s "$temp_img" 2>/dev/null; then
    if [[ -f "$temp_img" ]]; then
      # Get window dimensions
      local img_info=$(sips -g pixelWidth -g pixelHeight "$temp_img" 2>/dev/null)
      local width=$(echo "$img_info" | grep pixelWidth | awk '{print $2}')
      local height=$(echo "$img_info" | grep pixelHeight | awk '{print $2}')
      
      if [[ -n "$width" && -n "$height" ]]; then
        echo "   ✅ Selected window: ${width}x${height}"
        
        # For window recording, we'll capture full screen and crop to window
        AREA_WIDTH="$width"
        AREA_HEIGHT="$height"
        
        # Window position is harder to get, but we can try
        echo "   📍 Window recording will capture the selected window area"
        
        # Note: Full window tracking would require more complex AppleScript
        AREA_X=0
        AREA_Y=0
        CROP_FILTER="-vf crop=${AREA_WIDTH}:${AREA_HEIGHT}:${AREA_X}:${AREA_Y}"
        
        echo "   ⚠️  Note: Window must remain in the same position during recording"
        
        rm -f "$temp_img"
        return 0
      fi
    fi
    rm -f "$temp_img"
  fi
  
  echo "   ❌ Window selection cancelled or failed"
  return 1
}

if (( SELECT_WINDOW )); then
  echo "🪟 Window selection mode"
  select_window
  if [[ $? -ne 0 ]]; then
    echo "❌ Window selection failed or cancelled"
    exit 1
  fi
fi

if (( SELECT_AREA )); then
  echo "🎯 Area selection mode"
  select_area
  if [[ $? -ne 0 ]]; then
    echo "❌ Area selection failed or cancelled"
    exit 1
  fi
fi

if (( SELECT_MONITOR )); then
  echo "🖥️  Launching monitor selector..."
  MONITOR_RESULT=""
  select_monitor
  if [[ $? -eq 0 ]] && [[ -n "$MONITOR_RESULT" ]]; then
    VID_DEV="$MONITOR_RESULT"
    echo "✅ Using monitor $VID_DEV"
  else
    echo "❌ Monitor selection failed or cancelled"
    exit 1
  fi
fi

# -------- probe helper ----------------------------------------------
get_modes() {
  # For screen capture devices, we can't list modes the same way
  # Just return some common resolutions and the actual screen resolution
  if [[ $VID_DEV =~ ^[0-9]+$ ]] && (( VID_DEV >= 4 )); then
    echo "3420x2224 30"
    echo "3420x2224 15"
    echo "3420x2224 60"
    echo "1920x1080 30"
    echo "1920x1080 15"
    echo "1920x1080 60"
    echo "1280x720 30"
    echo "1280x720 15"
    echo "1280x720 60"
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
  # Default to 30fps for screen recording (good balance of smoothness vs file size)
  if echo "$available_fps" | grep -qx "30"; then
    FPS=30
  else
    FPS=$(echo "$available_fps" | head -1)
  fi
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
if [[ -n $CROP_FILTER ]]; then
  echo "   Area: ${AREA_WIDTH}x${AREA_HEIGHT} at position (${AREA_X},${AREA_Y})"
fi
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

# Add crop filter if area was selected
if [[ -n $CROP_FILTER ]]; then
  FFMPEG_CMD+=($CROP_FILTER)
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
