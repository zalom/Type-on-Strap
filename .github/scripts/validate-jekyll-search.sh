#!/bin/bash
# Validate Simple-Jekyll-Search (sylhare fork)
# Fetches latest release from GitHub and compares with local vendor file
# Validates both version AND file content integrity

set -e

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# GitHub repository info
GITHUB_REPO="sylhare/Simple-Jekyll-Search"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
LOCAL_FILE="assets/js/vendor/simple-jekyll-search.min.js"

echo "=================================================="
echo "Simple-Jekyll-Search Validation"
echo "=================================================="
echo ""
echo "Repository: https://github.com/${GITHUB_REPO}"
echo ""

# Check if local file exists
if [ ! -f "$LOCAL_FILE" ]; then
    echo -e "${RED}❌ Local file not found: ${LOCAL_FILE}${NC}"
    exit 1
fi

# Extract local version from file header
echo -n "Local version:  "
LOCAL_VERSION=$(head -3 "$LOCAL_FILE" | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | head -1) || true

if [ -n "$LOCAL_VERSION" ]; then
    echo "$LOCAL_VERSION"
else
    echo "Unable to detect"
    echo -e "${YELLOW}⚠️  Cannot extract version from file header${NC}"
fi

# Fetch latest release info from GitHub API
echo -n "Latest release: "
LATEST_VERSION=""
DOWNLOAD_URL=""
if command -v curl &> /dev/null; then
    API_RESPONSE=$(curl -s "$GITHUB_API" 2>/dev/null) || true
    LATEST_VERSION=$(echo "$API_RESPONSE" | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/') || true
    # Get the tarball/zipball URL or construct the raw file URL
    if [ -n "$LATEST_VERSION" ]; then
        DOWNLOAD_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${LATEST_VERSION}/dest/simple-jekyll-search.min.js"
    fi
fi

VALIDATION_FAILED=false

if [ -n "$LATEST_VERSION" ]; then
    echo "$LATEST_VERSION"
    
    # Compare versions
    if [ "$LOCAL_VERSION" = "$LATEST_VERSION" ]; then
        echo -e "${GREEN}✓ Version matches${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠️  Version mismatch detected${NC}"
        echo "   Local:  $LOCAL_VERSION"
        echo "   Latest: $LATEST_VERSION"
        VALIDATION_FAILED=true
    fi
    
    # Download and compare file content
    echo ""
    echo -n "Content check:  "
    if [ -n "$DOWNLOAD_URL" ]; then
        TEMP_FILE=$(mktemp)
        if curl -s "$DOWNLOAD_URL" -o "$TEMP_FILE" 2>/dev/null && [ -s "$TEMP_FILE" ]; then
            LOCAL_HASH=$(shasum -a 256 "$LOCAL_FILE" | cut -d' ' -f1)
            REMOTE_HASH=$(shasum -a 256 "$TEMP_FILE" | cut -d' ' -f1)
            
            if [ "$LOCAL_HASH" = "$REMOTE_HASH" ]; then
                echo -e "${GREEN}✓ Content matches official release${NC}"
            else
                echo -e "${RED}✗ Content differs from official release${NC}"
                echo "   Local hash:  ${LOCAL_HASH:0:16}..."
                echo "   Remote hash: ${REMOTE_HASH:0:16}..."
                VALIDATION_FAILED=true
            fi
        else
            echo -e "${YELLOW}Unable to download for comparison${NC}"
        fi
        rm -f "$TEMP_FILE"
    else
        echo -e "${YELLOW}Skipped (no download URL)${NC}"
    fi
else
    echo "Unable to fetch (network unavailable or rate limited)"
    echo -e "${YELLOW}⚠️  Could not verify against latest release${NC}"
    echo "   Check manually: https://github.com/${GITHUB_REPO}/releases"
fi

echo ""
if [ "$VALIDATION_FAILED" = true ]; then
    echo -e "${RED}❌ Validation failed${NC}"
    echo "   Update from: https://github.com/${GITHUB_REPO}/releases/latest"
    exit 1
else
    echo -e "${GREEN}✅ Simple-Jekyll-Search validation passed${NC}"
    exit 0
fi

