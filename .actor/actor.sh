#!/bin/bash

trap 'echo "Error on line $LINENO"; exit 1' ERR

echo "Environment:"
echo "DISPLAY=$DISPLAY"
echo "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
echo "LIBGL_ALWAYS_SOFTWARE=$LIBGL_ALWAYS_SOFTWARE"

set -e

# ---

echo "Parsing actor input..."

INPUT=$(apify actor:get-input || { echo "Failed to get input."; exit 1; })
PDF_ONE_URL=$(echo "$INPUT" | jq -r '.pdfOneUrl')
PDF_TWO_URL=$(echo "$INPUT" | jq -r '.pdfTwoUrl')
OUTPUT_NAME=$(echo "$INPUT" | jq -r '.outputName')
USE_GRAYSCALE=$(echo "$INPUT" | jq -r '.useGrayscale')
MARK_DIFF=$(echo "$INPUT" | jq -r '.markDifferences')
SKIP_IDENTICAL=$(echo "$INPUT" | jq -r '.skipIdentical')
CHANNEL_TOLERANCE=$(echo "$INPUT" | jq -r '.channelTolerance')
PER_PAGE_PIXEL_TOLERANCE=$(echo "$INPUT" | jq -r '.perPagePixelTolerance')
DPI=$(echo "$INPUT" | jq -r '.dpi')

if [ -z "$PDF_ONE_URL" ] || [ -z "$PDF_TWO_URL" ]; then
    echo "Error: Missing PDF URLs. Please provide both pdfOneUrl and pdfTwoUrl."
    exit 1
fi

# ---

echo "Downloading PDFs..."

wget -q -O one.pdf "$PDF_ONE_URL" || { echo "Failed to download file: $PDF_ONE_URL"; exit 1; }
wget -q -O two.pdf "$PDF_TWO_URL" || { echo "Failed to download file: $PDF_TWO_URL"; exit 1; }

if [ ! -s one.pdf ]; then
    echo "Downloaded first PDF is empty or not valid."
    exit 1
fi

if [ ! -s two.pdf ]; then
    echo "Downloaded second PDF is empty or not valid."
    exit 1
fi

echo "PDF One size: $(stat -f %z one.pdf)"
echo "PDF Two size: $(stat -f %z two.pdf)"
file one.pdf
file two.pdf

# ---

ARGS="--output-diff=$OUTPUT_NAME"

if [ "$USE_GRAYSCALE" = "true" ]; then
    ARGS="$ARGS --grayscale"
fi

if [ "$MARK_DIFF" = "true" ]; then
    ARGS="$ARGS --mark-differences"
fi

if [ "$SKIP_IDENTICAL" = "true" ]; then
    ARGS="$ARGS --skip-identical"
fi

if [ "$CHANNEL_TOLERANCE" -gt 0 ]; then
    ARGS="$ARGS --channel-tolerance=$CHANNEL_TOLERANCE"
fi

if [ "$PER_PAGE_PIXEL_TOLERANCE" -gt 0 ]; then
    ARGS="$ARGS --per-page-pixel-tolerance=$PER_PAGE_PIXEL_TOLERANCE"
fi

# Force numeric checks for DPI, fallback to default
if ! [[ "$DPI" =~ ^[0-9]+$ ]]; then
    echo "Warning: '$DPI' is not a valid integer. Falling back to 300."
    DPI=300
fi

ARGS="$ARGS --dpi=$DPI --verbose"

# ---

# Initialize virtual framebuffer
Xvfb :99 -screen 0 1024x768x24 &
sleep 1  # Give Xvfb time to start

# Ensure environment
export XDG_RUNTIME_DIR=/tmp/runtime-root
export DISPLAY=:99
mkdir -p $XDG_RUNTIME_DIR
chmod 0700 $XDG_RUNTIME_DIR

xdpyinfo || echo "X server not running properly"
glxinfo || echo "OpenGL not configured properly"

# ---

free -m
df -h

echo "Running: diff-pdf $ARGS one.pdf two.pdf"

set +e
LIBGL_ALWAYS_SOFTWARE=1 diff-pdf "$ARGS" one.pdf two.pdf || {
    echo "diff-pdf failed with exit code $?"
    echo "Command attempted: diff-pdf $ARGS one.pdf two.pdf"
    ls -l one.pdf two.pdf
    exit 1
}
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -gt 1 ]; then
    echo "Error: diff-pdf failed with exit code $EXIT_CODE."
    exit 1
elif [ $EXIT_CODE -eq 1 ]; then
    echo "Differences were found. EXIT_CODE=1."
else
    echo "No differences found. EXIT_CODE=0."
fi

# ---

# If diff was generated, store it in the default key-value store.

if [ -f "$OUTPUT_NAME" ]; then
    if [ -s "$OUTPUT_NAME" ]; then
        echo "Pushing resulting diff PDF to Key-Value Store (record key: DIFF_RESULT)..."
        apify actor:set-value "DIFF_RESULT" --contentType application/pdf < "$OUTPUT_NAME"
    else
        echo "Output PDF is empty; skipping upload."
    fi
else
    echo "Output PDF ($OUTPUT_NAME) was not generated."
fi

# ---

echo "Done!"
