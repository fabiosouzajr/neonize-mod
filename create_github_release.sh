#!/bin/bash

# Script to create GitHub releases with binaries
# This script prepares and creates GitHub releases for neonize-mod

set -e

# Configuration
REPO="fabiosouzajr/neonize-mod"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Function to check if GitHub CLI is available
check_gh_cli() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "❌ GitHub CLI (gh) is not installed."
        echo "Please install it from: https://cli.github.com/"
        echo "Or set GITHUB_TOKEN environment variable for API access"
        exit 1
    fi
}

# Function to get version from various sources
get_version() {
    # Try to get version from git tag first
    local git_version=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    
    if [ ! -z "$git_version" ]; then
        # Remove 'v' prefix if present and trim whitespace
        echo "${git_version#v}" | xargs
    else
        # Try to get version from version file or default to timestamp
        if [ -f "VERSION" ]; then
            cat VERSION | xargs
        elif [ -f "version.txt" ]; then
            cat version.txt | xargs
        else
            # Default to timestamp-based version
            date +"%Y.%m.%d-%H%M%S"
        fi
    fi
}

# Function to create GitHub release
create_github_release() {
    local version=$1
    local version_dir="releases/v${version}"
    local download_dir="${version_dir}/download"
    
    echo "Creating GitHub release for version: ${version}"
    echo "================================================"
    
    # Check if version directory exists
    if [ ! -d "$version_dir" ]; then
        echo "❌ Version directory not found: ${version_dir}"
        echo "Please run the build script first: ./build_all_platforms.sh"
        exit 1
    fi
    
    # Check if binaries exist
    if [ ! -d "$download_dir" ]; then
        echo "❌ Download directory not found: ${download_dir}"
        exit 1
    fi
    
    local binary_count=$(ls -1 "$download_dir"/*.so "$download_dir"/*.dll 2>/dev/null | wc -l)
    if [ "$binary_count" -eq 0 ]; then
        echo "❌ No binaries found in ${download_dir}"
        exit 1
    fi
    
    echo "✅ Found ${binary_count} binaries in ${download_dir}"
    
    # Create release notes
    local release_notes_file="/tmp/release_notes_${version}.md"
    cat > "$release_notes_file" << EOF
# Neonize v${version}

## What's New
- Compiled binaries for multiple platforms
- Automatic versioning and release management

## Supported Platforms
$(ls -1 "$download_dir"/*.so "$download_dir"/*.dll 2>/dev/null | sed 's/.*\///' | sed 's/^/- /')

## Installation
\`\`\`bash
pip install git+https://github.com/fabiosouzajr/neonize-mod.git@v${version}
\`\`\`

## Build Information
$(cat "${version_dir}/version.info" 2>/dev/null || echo "Build information not available")

## Changes
- Multi-platform binary support
- Improved build system
- Automatic dependency management
EOF
    
    # Create GitHub release using GitHub CLI
    if command -v gh >/dev/null 2>&1; then
        echo "Creating GitHub release using GitHub CLI..."
        
        # Check if release already exists
        if gh release view "v${version}" --repo "$REPO" >/dev/null 2>&1; then
            echo "⚠️  Release v${version} already exists. Updating..."
            gh release edit "v${version}" --repo "$REPO" --notes-file "$release_notes_file"
        else
            echo "Creating new release v${version}..."
            gh release create "v${version}" --repo "$REPO" --notes-file "$release_notes_file" --draft
        fi
        
        # Upload binaries
        echo "Uploading binaries..."
        for binary in "$download_dir"/*.so "$download_dir"/*.dll; do
            if [ -f "$binary" ]; then
                echo "Uploading: $(basename "$binary")"
                gh release upload "v${version}" "$binary" --repo "$REPO" --clobber
            fi
        done
        
        # Publish the release
        echo "Publishing release..."
        gh release edit "v${version}" --repo "$REPO" --draft=false
        
    else
        echo "GitHub CLI not available. Manual release creation required."
        echo ""
        echo "Please create a release manually:"
        echo "1. Go to: https://github.com/${REPO}/releases/new"
        echo "2. Tag version: v${version}"
        echo "3. Title: Neonize v${version}"
        echo "4. Description:"
        cat "$release_notes_file"
        echo ""
        echo "5. Upload these binaries:"
        ls -1 "$download_dir"/*.so "$download_dir"/*.dll 2>/dev/null
        echo ""
        echo "6. Publish the release"
    fi
    
    # Cleanup
    rm -f "$release_notes_file"
    
    echo ""
    echo "✅ Release process completed!"
    echo "Release URL: https://github.com/${REPO}/releases/tag/v${version}"
}

# Function to update download.py for GitHub releases
update_download_script() {
    local version=$1
    
    echo "Updating download.py for GitHub releases..."
    
    # Create a backup
    cp neonize/download.py neonize/download.py.backup
    
    # Update the download script
    cat > neonize/download.py << EOF
import os
from .utils.platform import generated_name
import requests
from pathlib import Path
from tqdm import tqdm

__GONEONIZE_VERSION__ = "${version}"
__GIT_RELEASE_URL__ = "https://github.com/fabiosouzajr/neonize-mod"


class UnsupportedPlatform(Exception):
    pass


def __download(url: str, fname: str, chunk_size=1024):
    resp = requests.get(url, stream=True)
    if resp.status_code != 200:
        resp.close()
        raise UnsupportedPlatform(generated_name())
    total = int(resp.headers.get("content-length", 0))
    with (
        open(fname, "wb") as file,
        tqdm(
            desc=Path(fname).name, total=total, unit="iB", unit_scale=True, unit_divisor=1024
        ) as bar,
    ):
        for data in resp.iter_content(chunk_size=chunk_size):
            size = file.write(data)
            bar.update(size)
        bar.n = total
    bar.close()


def download():
    # Download from GitHub releases
    __download(
        f"{__GIT_RELEASE_URL__}/releases/download/v{__GONEONIZE_VERSION__}/{generated_name()}",
        f"{os.path.dirname(__file__)}/{generated_name()}",
    )


if __name__ == "__main__":
    download()
EOF
    
    echo "✅ download.py updated for GitHub releases"
    echo "Backup saved as: neonize/download.py.backup"
}

# Main execution
echo "GitHub Release Creator for Neonize"
echo "=================================="

# Check prerequisites
check_gh_cli

# Get version
VERSION=$(get_version)
echo "Version: ${VERSION}"

# Create GitHub release
create_github_release "$VERSION"

# Update download script
update_download_script "$VERSION"

echo ""
echo "🎉 GitHub release setup completed!"
echo ""
echo "Next steps:"
echo "1. Verify the release at: https://github.com/${REPO}/releases"
echo "2. Test installation: pip install git+https://github.com/fabiosouzajr/neonize-mod.git@v${VERSION}"
echo "3. Update your documentation with the new release URL" 