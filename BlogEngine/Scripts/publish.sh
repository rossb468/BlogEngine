#!/bin/bash
set -euo pipefail

if [ -n "${SRCROOT:-}" ] && [ -n "${CONFIGURATION:-}" ]; then
    # Running from Xcode
    if [ "$CONFIGURATION" != "Release" ]; then
        echo "Skipping publish (not a Release build)"
        exit 0
    fi

    PROJECT_DIR="$SRCROOT"
    RELEASE_DIR="$PROJECT_DIR/BlogEngine-Release"
    TEMPLATES_SRC="$PROJECT_DIR/BlogEngine/Templates"
    BINARY_SRC="$BUILT_PRODUCTS_DIR/BlogEngine"
else
    # Running standalone from the command line
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    PROJECT_DIR="$SCRIPT_DIR"
    RELEASE_DIR="$PROJECT_DIR/BlogEngine-Release"
    PROJECT="$PROJECT_DIR/BlogEngine.xcodeproj"
    TEMPLATES_SRC="$PROJECT_DIR/BlogEngine/Templates"

    echo "Building release..."
    xcodebuild -project "$PROJECT" \
        -scheme BlogEngine \
        -configuration Release \
        CONFIGURATION_BUILD_DIR="$RELEASE_DIR" \
        -quiet

    # Remove build artifacts, keep only the binary
    rm -rf "$RELEASE_DIR/BlogEngine.dSYM" "$RELEASE_DIR/BlogEngine.swiftmodule"
    BINARY_SRC="$RELEASE_DIR/BlogEngine"
fi

# Clean and recreate release directory (preserve binary if already there from xcodebuild)
if [ -n "${SRCROOT:-}" ]; then
    rm -rf "$RELEASE_DIR"
    mkdir -p "$RELEASE_DIR/Templates"
    mkdir -p "$RELEASE_DIR/input"
    cp "$BINARY_SRC" "$RELEASE_DIR/BlogEngine"
else
    # Standalone: binary is already in RELEASE_DIR from the build step
    mkdir -p "$RELEASE_DIR/Templates"
    mkdir -p "$RELEASE_DIR/input"
fi

echo "Copying templates..."
cp "$TEMPLATES_SRC"/* "$RELEASE_DIR/Templates/"

# Create the generate script inside input/
cat > "$RELEASE_DIR/input/generate.sh" << 'GENERATE_SCRIPT'
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"

# Clean and recreate output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

"$RELEASE_DIR/BlogEngine" "$SCRIPT_DIR" "$OUTPUT_DIR" "$RELEASE_DIR/Templates"
GENERATE_SCRIPT

chmod +x "$RELEASE_DIR/input/generate.sh"

echo "Published to $RELEASE_DIR"
echo "  - Place markdown files in $RELEASE_DIR/input/"
echo "  - Run input/generate.sh to build the site"
