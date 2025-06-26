#!/bin/bash

# Build neonize for all supported platforms
# This script compiles neonize for different OS/arch combinations

set -e

echo "Building neonize for all platforms..."
echo "====================================="

# Create releases directory if it doesn't exist
mkdir -p releases/download

# Function to build for a specific platform
build_platform() {
    local os=$1
    local arch=$2
    local cc=$3
    local env_vars=$4
    
    echo "Building for $os-$arch..."
    
    # Set environment variables
    export GOOS=$os
    export GOARCH=$arch
    export CC=$cc
    export CGO_ENABLED=1
    
    # Additional environment variables if provided
    if [ ! -z "$env_vars" ]; then
        eval $env_vars
    fi
    
    # Build
    python tools/goneonize.py goneonize
    
    # Get the generated filename
    filename=$(python -c "
import platform
import sys
sys.path.insert(0, 'tools')
from goneonize import generated_name
print(generated_name('$os', '$arch'))
")
    
    # Move to releases directory
    if [ -f "neonize/$filename" ]; then
        mv "neonize/$filename" "releases/download/"
        echo "✅ Successfully built: $filename"
    else
        echo "❌ Failed to build: $filename"
        return 1
    fi
}

# Build for different platforms
echo "1. Building for Linux AMD64..."
build_platform "linux" "amd64" "gcc"

echo "2. Building for Linux ARM64..."
build_platform "linux" "arm64" "aarch64-linux-gnu-gcc"

echo "3. Building for Linux ARM..."
build_platform "linux" "arm" "arm-linux-gnueabihf-gcc"

echo "4. Building for Windows AMD64..."
build_platform "windows" "amd64" "x86_64-w64-mingw32-gcc"

echo "5. Building for Windows ARM64..."
build_platform "windows" "arm64" "x86_64-w64-mingw32-gcc"

echo "6. Building for Windows 386..."
build_platform "windows" "386" "i686-w64-mingw32-gcc"

echo ""
echo "Build completed! Files in releases/download/:"
ls -la releases/download/

echo ""
echo "Summary:"
echo "========="
echo "✅ Linux AMD64: neonize-linux-amd64.so"
echo "✅ Linux ARM64: neonize-linux-arm64.so"
echo "✅ Linux ARM: neonize-linux-arm.so"
echo "✅ Windows AMD64: neonize-windows-amd64.dll"
echo "✅ Windows ARM64: neonize-windows-arm64.dll"
echo "✅ Windows 386: neonize-windows-386.dll"
echo ""
echo "Note: macOS builds require a macOS environment or specialized cross-compilation tools." 