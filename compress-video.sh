#!/usr/bin/env bash
# ---------------------------------------------------------------------
#  compress-video.sh  —  compress videos using x264 codec
# ---------------------------------------------------------------------

set -euo pipefail

# ---------- defaults -------------------------------------------------
CRF=23                  # Constant Rate Factor (0-51, lower=better quality)
PRESET="medium"         # x264 preset (ultrafast to veryslow)
OUTPUT=""              # Output filename (auto-generated if not specified)
INPUT=""               # Input video file

# ---------------------------------------------------------------------

usage() {
  echo "Usage: $0 [-i input] [-o output] [-q crf] [-p preset]"
  echo ""
  echo "Options:"
  echo "  -i file          Input video file (required)"
  echo "  -o file          Output filename (default: input_compressed.mp4)"
  echo "  -q crf           Video quality CRF 0-51 for x264 (default: 23)"
  echo "  -p preset        x264 preset: ultrafast/fast/medium/slow/veryslow (default: medium)"
  echo ""
  echo "Examples:"
  echo "  $0 -i video.mp4"
  echo "  $0 -i video.mp4 -o compressed.mp4 -q 28"
  echo "  $0 -i video.mp4 -q 18 -p slow"
  echo ""
  echo "Quality guide:"
  echo "  CRF 18: High quality, larger file"
  echo "  CRF 23: Default, good quality/size balance"
  echo "  CRF 28: Lower quality, smaller file"
  echo ""
  echo "Preset guide:"
  echo "  ultrafast: Very fast encoding, larger file"
  echo "  fast:      Fast encoding, reasonable file size"
  echo "  medium:    Default, balanced speed/compression"
  echo "  slow:      Slow encoding, better compression"
  echo "  veryslow:  Very slow encoding, best compression"
  exit 1
}

# Parse arguments
while getopts "i:o:q:p:h" opt; do
  case $opt in
    i) INPUT=$OPTARG ;;
    o) OUTPUT=$OPTARG ;;
    q) CRF=$OPTARG ;;
    p) PRESET=$OPTARG ;;
    h|*) usage ;;
  esac
done

# Check if input file is provided
if [[ -z "$INPUT" ]]; then
  echo "❌ Error: Input file is required"
  echo ""
  usage
fi

# Check if input file exists
if [[ ! -f "$INPUT" ]]; then
  echo "❌ Error: Input file '$INPUT' not found"
  exit 1
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
  echo "❌ Error: ffmpeg is not installed"
  echo ""
  echo "To install with Homebrew:"
  echo "   brew install ffmpeg"
  exit 1
fi

# Generate output filename if not provided
if [[ -z "$OUTPUT" ]]; then
  # Get the base name without extension
  base_name="${INPUT%.*}"
  OUTPUT="${base_name}_compressed.mp4"
fi

# Validate CRF value
if ! [[ "$CRF" =~ ^[0-9]+$ ]] || (( CRF < 0 || CRF > 51 )); then
  echo "❌ Error: CRF must be a number between 0 and 51"
  exit 1
fi

# Validate preset
valid_presets=("ultrafast" "superfast" "veryfast" "faster" "fast" "medium" "slow" "slower" "veryslow")
if [[ ! " ${valid_presets[@]} " =~ " ${PRESET} " ]]; then
  echo "❌ Error: Invalid preset '$PRESET'"
  echo "Valid presets: ${valid_presets[*]}"
  exit 1
fi

# Get input file info
echo "🔍 Analyzing input file..."
input_info=$(ffprobe -v error -show_entries format=duration,size -of default=noprint_wrappers=1:nokey=1 "$INPUT" 2>/dev/null || echo "0 0")
input_duration=$(echo "$input_info" | head -1)
input_size=$(echo "$input_info" | tail -1)
input_size_mb=$((input_size / 1048576))

echo "📹 Input: $INPUT"
echo "   Size: ${input_size_mb} MB"
echo "   Duration: ${input_duration%.*} seconds"
echo ""
echo "🎬 Compressing with x264..."
echo "   CRF: $CRF (lower = better quality)"
echo "   Preset: $PRESET"
echo "   Output: $OUTPUT"
echo ""

# Run ffmpeg compression
ffmpeg -hide_banner \
  -i "$INPUT" \
  -c:v libx264 \
  -crf "$CRF" \
  -preset "$PRESET" \
  -pix_fmt yuv420p \
  -c:a aac \
  -b:a 128k \
  -movflags +faststart \
  -y \
  "$OUTPUT"

# Get output file info
if [[ -f "$OUTPUT" ]]; then
  output_size=$(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT" 2>/dev/null)
  output_size_mb=$((output_size / 1048576))
  compression_ratio=$((100 - (output_size * 100 / input_size)))
  
  echo ""
  echo "✅ Compression complete!"
  echo "   Output: $OUTPUT"
  echo "   Size: ${output_size_mb} MB (${compression_ratio}% reduction)"
else
  echo ""
  echo "❌ Error: Compression failed"
  exit 1
fi