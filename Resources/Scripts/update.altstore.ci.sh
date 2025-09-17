#!/bin/zsh

set -euo pipefail

SRCROOT="$1"
IPA_PATH="$2"
ARTIFACT_URL="$3"

ALTSTORE_JSON="$SRCROOT/Resources/Repos/altstore.json"

if [ ! -f "$IPA_PATH" ]; then
    echo "[-] IPA file not found: $IPA_PATH"
    exit 1
fi

if [ ! -f "$ALTSTORE_JSON" ]; then
    echo "[-] AltStore JSON not found: $ALTSTORE_JSON"
    exit 1
fi

echo "[+] Updating AltStore repository..."
echo "[+] IPA Path: $IPA_PATH"
echo "[+] Artifact URL: $ARTIFACT_URL"
echo "[+] AltStore JSON: $ALTSTORE_JSON"

# Extract version from the IPA
echo "[+] Extracting version from IPA..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
unzip -q "$IPA_PATH" "Payload/*.app/Info.plist"
APP_PLIST=$(find Payload -name "Info.plist" | head -n 1)

if [ -z "$APP_PLIST" ]; then
    echo "[-] Could not find Info.plist in IPA"
    rm -rf "$TEMP_DIR"
    exit 1
fi

VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP_PLIST" 2>/dev/null || echo "")
BUILD=$(plutil -extract CFBundleVersion raw "$APP_PLIST" 2>/dev/null || echo "")

if [ -z "$VERSION" ]; then
    echo "[-] Could not extract version from Info.plist"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Combine version and build if both exist
if [ -n "$BUILD" ] && [ "$BUILD" != "$VERSION" ]; then
    FULL_VERSION="$VERSION.$BUILD"
else
    FULL_VERSION="$VERSION"
fi

echo "[+] Extracted version: $FULL_VERSION"

# Clean up temp directory
rm -rf "$TEMP_DIR"

# Get current timestamp in ISO 8601 format
CURRENT_DATE=$(date -u '+%Y-%m-%dT%H:%M:%S+00:00')
echo "[+] Current date: $CURRENT_DATE"

# Get file size
FILE_SIZE=$(stat -f%z "$IPA_PATH")
echo "[+] File size: $FILE_SIZE bytes"

# Update AltStore JSON using jq if available, otherwise use sed
if command -v jq >/dev/null 2>&1; then
    echo "[+] Using jq to update JSON..."
    jq --arg version "$FULL_VERSION" \
       --arg date "$CURRENT_DATE" \
       --arg url "$ARTIFACT_URL" \
       --argjson size "$FILE_SIZE" \
       '.apps[0].version = $version | .apps[0].versionDate = $date | .apps[0].downloadURL = $url | .apps[0].size = $size' \
       "$ALTSTORE_JSON" > "$ALTSTORE_JSON.tmp" && mv "$ALTSTORE_JSON.tmp" "$ALTSTORE_JSON"
else
    echo "[+] Using sed to update JSON..."
    # Use sed as fallback (less reliable but should work)
    sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$FULL_VERSION\"/" "$ALTSTORE_JSON"
    sed -i '' "s/\"versionDate\": \"[^\"]*\"/\"versionDate\": \"$CURRENT_DATE\"/" "$ALTSTORE_JSON"
    sed -i '' "s|\"downloadURL\": \"[^\"]*\"|\"downloadURL\": \"$ARTIFACT_URL\"|" "$ALTSTORE_JSON"
    sed -i '' "s/\"size\": [0-9]*/\"size\": $FILE_SIZE/" "$ALTSTORE_JSON"
fi

echo "[+] AltStore repository updated successfully!"
echo "[+] Version: $FULL_VERSION"
echo "[+] Date: $CURRENT_DATE"  
echo "[+] URL: $ARTIFACT_URL"
echo "[+] Size: $FILE_SIZE bytes"

# Verify the JSON is still valid
if command -v jq >/dev/null 2>&1; then
    if ! jq empty "$ALTSTORE_JSON" 2>/dev/null; then
        echo "[-] Warning: Generated JSON may be invalid"
        exit 1
    fi
    echo "[+] JSON validation passed"
fi

# Commit and push the changes
echo "[+] Committing changes to repository..."
cd "$SRCROOT"

# Configure git user (use GitHub Actions bot)
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# Add the changed file
git add "$ALTSTORE_JSON"

# Check if there are any changes to commit
if git diff --staged --quiet; then
    echo "[+] No changes to commit"
else
    # Commit the changes
    git commit -m "Update AltStore repository - v$FULL_VERSION

- Version: $FULL_VERSION
- Date: $CURRENT_DATE
- Size: $FILE_SIZE bytes
- Artifact URL: $ARTIFACT_URL

[skip ci]"
    
    # Push the changes
    echo "[+] Pushing changes to repository..."
    git push
    
    echo "[+] Successfully committed and pushed AltStore repository updates!"
fi

echo "[+] Done!"
