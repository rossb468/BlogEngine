#!/bin/bash
set -euo pipefail

if [ -n "${SRCROOT:-}" ] && [ -n "${CONFIGURATION:-}" ]; then
    # Running from Xcode as a build phase script
    if [ "$CONFIGURATION" != "Release" ]; then
        echo "Skipping publish (not a Release build)"
        exit 0
    fi

    PROJECT_DIR="$SRCROOT"
    RELEASE_DIR="$PROJECT_DIR/BlogEngine-Release"
    TEMPLATES_SRC="$PROJECT_DIR/BlogEngineGUI/Templates"
    BINARY_SRC="$BUILT_PRODUCTS_DIR/BlogEngineCLI"
else
    # Running standalone from the command line
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
    RELEASE_DIR="$PROJECT_DIR/BlogEngine-Release"
    PROJECT="$PROJECT_DIR/BlogEngine-New.xcodeproj"
    TEMPLATES_SRC="$PROJECT_DIR/BlogEngineGUI/Templates"

    echo "Building release..."
    xcodebuild -project "$PROJECT" \
        -scheme BlogEngineCLI \
        -configuration Release \
        CONFIGURATION_BUILD_DIR="$RELEASE_DIR" \
        -quiet

    # Remove build artifacts, keep only the binary
    rm -rf "$RELEASE_DIR/BlogEngineCLI.dSYM" "$RELEASE_DIR/BlogEngineCLI.swiftmodule"
    BINARY_SRC="$RELEASE_DIR/BlogEngineCLI"
fi

# Set up release directory
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR/Templates"
mkdir -p "$RELEASE_DIR/input"

cp "$BINARY_SRC" "$RELEASE_DIR/BlogEngineCLI"

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

"$RELEASE_DIR/BlogEngineCLI" "$SCRIPT_DIR" "$OUTPUT_DIR" "$RELEASE_DIR/Templates"
GENERATE_SCRIPT

chmod +x "$RELEASE_DIR/input/generate.sh"

# Create a default site.json if one doesn't exist
if [ ! -f "$RELEASE_DIR/input/site.json" ]; then
    cat > "$RELEASE_DIR/input/site.json" << 'SITECONF'
{
  "author" : "Author",
  "email" : "email@example.com",
  "github" : "username",
  "site_title" : "My Blog"
}
SITECONF
fi

echo "Published to $RELEASE_DIR"
echo "  - Place markdown files in $RELEASE_DIR/input/"
echo "  - Run input/generate.sh to build the site"
