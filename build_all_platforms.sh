#!/bin/bash

# Build neonize for all supported platforms
# This script compiles neonize for different OS/arch combinations with automatic versioning

set -e

# Function to check if a compiler is available
check_compiler() {
    local compiler=$1
    local description=$2
    
    if command -v "$compiler" >/dev/null 2>&1; then
        echo "✅ $description ($compiler) - Found"
        return 0
    else
        echo "❌ $description ($compiler) - Not found"
        return 1
    fi
}

# Function to provide installation instructions
get_installation_instructions() {
    local compiler=$1
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "$compiler" in
        "gcc")
            case "$os" in
                "linux")
                    echo "Install GCC: sudo apt-get install build-essential (Ubuntu/Debian) or sudo yum install gcc (RHEL/CentOS)"
                    ;;
                "darwin")
                    echo "Install GCC: Install Xcode Command Line Tools: xcode-select --install"
                    ;;
                *)
                    echo "Install GCC for your operating system"
                    ;;
            esac
            ;;
        "aarch64-linux-gnu-gcc")
            echo "Install ARM64 cross-compiler: sudo apt-get install gcc-aarch64-linux-gnu (Ubuntu/Debian) or sudo yum install gcc-aarch64-linux-gnu (RHEL/CentOS)"
            ;;
        "arm-linux-gnueabihf-gcc")
            echo "Install ARM cross-compiler: sudo apt-get install gcc-arm-linux-gnueabihf (Ubuntu/Debian) or sudo yum install gcc-arm-linux-gnueabihf (RHEL/CentOS)"
            ;;
        "x86_64-w64-mingw32-gcc")
            echo "Install MinGW-w64: sudo apt-get install mingw-w64 (Ubuntu/Debian) or sudo yum install mingw-w64-gcc (RHEL/CentOS)"
            ;;
        "i686-w64-mingw32-gcc")
            echo "Install MinGW-w64 32-bit: sudo apt-get install mingw-w64 (Ubuntu/Debian) or sudo yum install mingw-w64-gcc (RHEL/CentOS)"
            ;;
        *)
            echo "Install $compiler for your operating system"
            ;;
    esac
}

# Function to detect available compilers
detect_compilers() {
    echo "Detecting available compilers..."
    echo "================================="
    
    local missing_compilers=()
    local available_compilers=()
    
    # Check each required compiler
    if check_compiler "gcc" "GCC (Linux AMD64)"; then
        available_compilers+=("linux:amd64:gcc")
    else
        missing_compilers+=("gcc")
    fi
    
    if check_compiler "aarch64-linux-gnu-gcc" "ARM64 Cross-compiler (Linux ARM64)"; then
        available_compilers+=("linux:arm64:aarch64-linux-gnu-gcc")
    else
        missing_compilers+=("aarch64-linux-gnu-gcc")
    fi
    
    if check_compiler "arm-linux-gnueabihf-gcc" "ARM Cross-compiler (Linux ARM)"; then
        available_compilers+=("linux:arm:arm-linux-gnueabihf-gcc")
    else
        missing_compilers+=("arm-linux-gnueabihf-gcc")
    fi
    
    if check_compiler "x86_64-w64-mingw32-gcc" "MinGW-w64 (Windows AMD64)"; then
        available_compilers+=("windows:amd64:x86_64-w64-mingw32-gcc")
        # Note: Windows ARM64 requires special handling and may not work with standard MinGW
        # available_compilers+=("windows:arm64:x86_64-w64-mingw32-gcc")
    else
        missing_compilers+=("x86_64-w64-mingw32-gcc")
    fi
    
    if check_compiler "i686-w64-mingw32-gcc" "MinGW-w64 32-bit (Windows 386)"; then
        available_compilers+=("windows:386:i686-w64-mingw32-gcc")
    else
        missing_compilers+=("i686-w64-mingw32-gcc")
    fi
    
    echo ""
    
    # Report results
    if [ ${#missing_compilers[@]} -gt 0 ]; then
        echo "⚠️  Missing compilers detected:"
        echo "================================"
        for compiler in "${missing_compilers[@]}"; do
            echo "• $compiler"
            echo "  $(get_installation_instructions "$compiler")"
            echo ""
        done
        
        echo "You can:"
        echo "1. Install missing compilers and run the script again"
        echo "2. Continue with available compilers only (press Enter)"
        echo "3. Exit (Ctrl+C)"
        echo ""
        read -p "Press Enter to continue with available compilers, or Ctrl+C to exit: "
        echo ""
    fi
    
    # Return available compilers as space-separated string
    echo "${available_compilers[@]}"
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

# Function to create versioned directory structure
create_versioned_structure() {
    local version=$1
    local version_dir="releases/v${version}"
    local download_dir="${version_dir}/download"
    
    echo "Creating versioned directory structure..." >&2
    mkdir -p "$download_dir"
    
    # Create a version info file
    cat > "${version_dir}/version.info" << EOF
Version: ${version}
Build Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Build Host: $(hostname)
Git Commit: $(git rev-parse HEAD 2>/dev/null || echo "unknown")
EOF
    
    echo "✅ Created directory structure: ${version_dir}/" >&2
    echo "$version_dir"
}

# Function to build for a specific platform
build_platform() {
    local os=$1
    local arch=$2
    local cc=$3
    local env_vars=$4
    local version_dir=$5
    
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
    if ! python tools/goneonize.py goneonize; then
        echo "❌ Build command failed for $os-$arch"
        return 1
    fi
    
    # Get the generated filename
    filename=$(python -c "
import platform
import sys
sys.path.insert(0, 'tools')
from goneonize import generated_name
print(generated_name('$os', '$arch'))
")
    
    # Check if the file was actually created
    if [ ! -f "neonize/$filename" ]; then
        echo "❌ Expected file not found: neonize/$filename"
        echo "   Build may have failed silently or file was created elsewhere"
        return 1
    fi
    
    # Move to versioned releases directory
    if [ -f "neonize/$filename" ]; then
        mv "neonize/$filename" "${version_dir}/download/"
        echo "✅ Successfully built: $filename"
    else
        echo "❌ Failed to build: $filename"
        return 1
    fi
}

# Main execution starts here
echo "Building neonize for all platforms..."
echo "====================================="

# Detect available compilers
available_compilers=($(detect_compilers))

if [ ${#available_compilers[@]} -eq 0 ]; then
    echo "❌ No compilers available. Please install at least one compiler and try again."
    exit 1
fi

# Get version and create directory structure
VERSION=$(get_version)
echo "Version: ${VERSION}"
echo ""

# Create versioned directory structure
VERSION_DIR=$(create_versioned_structure "$VERSION")

# Build for available platforms
build_count=0
successful_builds=()
failed_builds=()

for compiler_info in "${available_compilers[@]}"; do
    IFS=':' read -r os arch cc <<< "$compiler_info"
    
    case "$os:$arch" in
        "linux:amd64")
            echo "$((++build_count)). Building for Linux AMD64..."
            if build_platform "linux" "amd64" "$cc" "" "$VERSION_DIR"; then
                successful_builds+=("Linux AMD64")
            else
                failed_builds+=("Linux AMD64")
            fi
            ;;
        "linux:arm64")
            echo "$((++build_count)). Building for Linux ARM64..."
            if build_platform "linux" "arm64" "$cc" "" "$VERSION_DIR"; then
                successful_builds+=("Linux ARM64")
            else
                failed_builds+=("Linux ARM64")
            fi
            ;;
        "linux:arm")
            echo "$((++build_count)). Building for Linux ARM..."
            if build_platform "linux" "arm" "$cc" "" "$VERSION_DIR"; then
                successful_builds+=("Linux ARM")
            else
                failed_builds+=("Linux ARM")
            fi
            ;;
        "windows:amd64")
            echo "$((++build_count)). Building for Windows AMD64..."
            if build_platform "windows" "amd64" "$cc" "" "$VERSION_DIR"; then
                successful_builds+=("Windows AMD64")
            else
                failed_builds+=("Windows AMD64")
            fi
            ;;
        "windows:arm64")
            echo "$((++build_count)). Building for Windows ARM64..."
            if build_platform "windows" "arm64" "$cc" "" "$VERSION_DIR"; then
                successful_builds+=("Windows ARM64")
            else
                failed_builds+=("Windows ARM64")
            fi
            ;;
        "windows:386")
            echo "$((++build_count)). Building for Windows 386..."
            if build_platform "windows" "386" "$cc" "" "$VERSION_DIR"; then
                successful_builds+=("Windows 386")
            else
                failed_builds+=("Windows 386")
            fi
            ;;
    esac
done

echo ""
echo "Build completed! Files in ${VERSION_DIR}/download/:"
ls -la "${VERSION_DIR}/download/"

echo ""
echo "Summary:"
echo "========="
echo "Version: ${VERSION}"
echo "Build Directory: ${VERSION_DIR}"
echo ""

if [ ${#successful_builds[@]} -gt 0 ]; then
    echo "✅ Successful builds:"
    for build in "${successful_builds[@]}"; do
        echo "   • $build"
    done
    echo ""
fi

if [ ${#failed_builds[@]} -gt 0 ]; then
    echo "❌ Failed builds:"
    for build in "${failed_builds[@]}"; do
        echo "   • $build"
    done
    echo ""
fi

echo "Version info saved to: ${VERSION_DIR}/version.info"
echo ""
echo "Note: macOS builds require a macOS environment or specialized cross-compilation tools." 