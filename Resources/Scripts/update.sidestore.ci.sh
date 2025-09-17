#!/bin/zsh

set -euo pipefail

# Configure git user (use GitHub Actions bot)
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# Get the current branch name from environment or detect it
CURRENT_BRANCH=""
IS_PULL_REQUEST=false

if [ -n "$GITHUB_HEAD_REF" ]; then
    # This is a pull request - use the source branch
    CURRENT_BRANCH="$GITHUB_HEAD_REF"
    IS_PULL_REQUEST=true
    echo "[+] Detected pull request, using source branch: $CURRENT_BRANCH"
elif [ -n "$GITHUB_REF_NAME" ]; then
    # This is a push to a branch
    CURRENT_BRANCH="$GITHUB_REF_NAME"
    echo "[+] Detected push to branch: $CURRENT_BRANCH"
else
    # Fallback: try to detect from git
    CURRENT_BRANCH=$(git branch --show-current)
    if [ -z "$CURRENT_BRANCH" ]; then
        echo "[-] Could not determine current branch"
        exit 1
    fi
    echo "[+] Detected current branch from git: $CURRENT_BRANCH"
fi

echo "[+] Working on branch: $CURRENT_BRANCH"

# For pull requests, we need to properly checkout the source branch
if [ "$IS_PULL_REQUEST" = true ]; then
    echo "[+] Setting up pull request branch..."
    # Fetch the latest state of the source branch
    git fetch origin "$CURRENT_BRANCH"
    # Check out the actual branch (not the merge commit)
    git checkout "$CURRENT_BRANCH"
else
    # Ensure we're on the correct branch (not detached HEAD) for direct pushes
    if git symbolic-ref -q HEAD >/dev/null 2>&1; then
        echo "[+] Already on a branch"
    else
        echo "[+] Creating and switching to branch: $CURRENT_BRANCH"
        git checkout -b "$CURRENT_BRANCH" || git checkout "$CURRENT_BRANCH"
    fi
fi

SRCROOT="$1"
IPA_PATH="$2"
ARTIFACT_URL="$3"

SIDESTORE_JSON="$SRCROOT/Resources/Repos/sidestore.json"

if [ ! -f "$IPA_PATH" ]; then
    echo "[-] IPA file not found: $IPA_PATH"
    exit 1
fi

if [ ! -f "$SIDESTORE_JSON" ]; then
    echo "[-] SideStore JSON not found: $SIDESTORE_JSON"
    exit 1
fi

echo "[+] Updating SideStore repository..."
echo "[+] IPA Path: $IPA_PATH"
echo "[+] Artifact URL: $ARTIFACT_URL"
echo "[+] SideStore JSON: $SIDESTORE_JSON"

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

# Update SideStore JSON using jq if available, otherwise use sed
if command -v jq >/dev/null 2>&1; then
    echo "[+] Using jq to update JSON..."
    jq --arg version "$FULL_VERSION" \
       --arg date "$CURRENT_DATE" \
       --arg url "$ARTIFACT_URL" \
       --argjson size "$FILE_SIZE" \
       '.apps[0].version = $version | .apps[0].versionDate = $date | .apps[0].downloadURL = $url | .apps[0].size = $size' \
       "$SIDESTORE_JSON" > "$SIDESTORE_JSON.tmp" && mv "$SIDESTORE_JSON.tmp" "$SIDESTORE_JSON"
else
    echo "[+] Using sed to update JSON..."
    # Use sed as fallback (less reliable but should work)
    sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$FULL_VERSION\"/" "$SIDESTORE_JSON"
    sed -i '' "s/\"versionDate\": \"[^\"]*\"/\"versionDate\": \"$CURRENT_DATE\"/" "$SIDESTORE_JSON"
    sed -i '' "s|\"downloadURL\": \"[^\"]*\"|\"downloadURL\": \"$ARTIFACT_URL\"|" "$SIDESTORE_JSON"
    sed -i '' "s/\"size\": [0-9]*/\"size\": $FILE_SIZE/" "$SIDESTORE_JSON"
fi

echo "[+] SideStore repository updated successfully!"
echo "[+] Version: $FULL_VERSION"
echo "[+] Date: $CURRENT_DATE"  
echo "[+] URL: $ARTIFACT_URL"
echo "[+] Size: $FILE_SIZE bytes"

# Verify the JSON is still valid
if command -v jq >/dev/null 2>&1; then
    if ! jq empty "$SIDESTORE_JSON" 2>/dev/null; then
        echo "[-] Warning: Generated JSON may be invalid"
        exit 1
    fi
    echo "[+] JSON validation passed"
fi

# Commit and push the changes
echo "[+] Committing changes to repository..."
cd "$SRCROOT"


# Add the changed file
git add "$SIDESTORE_JSON"

# Check if there are any changes to commit
if git diff --staged --quiet; then
    echo "[+] No changes to commit"
else
    # Commit the changes
    git commit -m "Update SideStore repository - v$FULL_VERSION

- Version: $FULL_VERSION
- Date: $CURRENT_DATE
- Size: $FILE_SIZE bytes
- Artifact URL: $ARTIFACT_URL

[skip ci]"
    
    # Push the changes
    echo "[+] Pushing changes to repository..."
    git push origin "$CURRENT_BRANCH"
    
    echo "[+] Successfully committed and pushed SideStore repository updates!"
fi

echo "[+] Done!"
