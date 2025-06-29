#!/bin/bash

# Automated Version Management for Neonize
# This script handles version bumping, git tagging, and release preparation

set -e

# Configuration
VERSION_FILE="VERSION"
GIT_REPO="fabiosouzajr/neonize-mod"

# Function to get current version
get_current_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE" | xargs
    else
        echo "0.0.0"
    fi
}

# Function to parse version components
parse_version() {
    local version=$1
    IFS='.' read -r major minor patch build <<< "$version"
    echo "$major $minor $patch $build"
}

# Function to create new version
create_version() {
    local major=$1
    local minor=$2
    local patch=$3
    local build=$4
    
    if [ -z "$build" ]; then
        echo "${major}.${minor}.${patch}"
    else
        echo "${major}.${minor}.${patch}.${build}"
    fi
}

# Function to bump version
bump_version() {
    local bump_type=$1
    local current_version=$(get_current_version)
    read -r major minor patch build <<< "$(parse_version "$current_version")"
    
    case "$bump_type" in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            build=""
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            build=""
            ;;
        "patch")
            patch=$((patch + 1))
            build=""
            ;;
        "build")
            if [ -z "$build" ]; then
                build=1
            else
                build=$((build + 1))
            fi
            ;;
        "auto")
            # Auto-detect based on git commits since last tag
            local last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
            local commit_count=0
            
            if [ -n "$last_tag" ]; then
                commit_count=$(git rev-list --count "$last_tag"..HEAD 2>/dev/null || echo "0")
            else
                # No tags exist, use all commits
                commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
            fi
            
            if [ "$commit_count" -gt 0 ]; then
                # Check if there are breaking changes (commits with "BREAKING CHANGE" or "!:" in message)
                local breaking_changes=0
                local features=0
                
                if [ -n "$last_tag" ]; then
                    breaking_changes=$(git log --oneline "$last_tag"..HEAD 2>/dev/null | grep -c "BREAKING CHANGE\|!:" || echo "0")
                    features=$(git log --oneline "$last_tag"..HEAD 2>/dev/null | grep -c "feat:" || echo "0")
                else
                    breaking_changes=$(git log --oneline 2>/dev/null | grep -c "BREAKING CHANGE\|!:" || echo "0")
                    features=$(git log --oneline 2>/dev/null | grep -c "feat:" || echo "0")
                fi
                
                if [ "$breaking_changes" -gt 0 ]; then
                    major=$((major + 1))
                    minor=0
                    patch=0
                    build=""
                elif [ "$features" -gt 0 ]; then
                    minor=$((minor + 1))
                    patch=0
                    build=""
                else
                    patch=$((patch + 1))
                    build=""
                fi
            fi
            ;;
        *)
            echo "❌ Invalid bump type. Use: major, minor, patch, build, or auto"
            exit 1
            ;;
    esac
    
    local new_version=$(create_version "$major" "$minor" "$patch" "$build")
    echo "$new_version"
}

# Function to update version in all files
update_version_files() {
    local new_version=$1
    
    echo "Updating version to: $new_version"
    
    # Update VERSION file
    echo "$new_version" > "$VERSION_FILE"
    echo "✅ Updated $VERSION_FILE"
    
    # Update download.py version
    if [ -f "neonize/download.py" ]; then
        sed -i "s/__GONEONIZE_VERSION__ = \".*\"/__GONEONIZE_VERSION__ = \"$new_version\"/" neonize/download.py
        echo "✅ Updated neonize/download.py"
    fi
    
    # Update pyproject.toml if it exists
    if [ -f "pyproject.toml" ]; then
        sed -i "s/version = \".*\"/version = \"$new_version\"/" pyproject.toml
        echo "✅ Updated pyproject.toml"
    fi
    
    # Update package.json if it exists
    if [ -f "package.json" ]; then
        sed -i "s/\"version\": \".*\"/\"version\": \"$new_version\"/" package.json
        echo "✅ Updated package.json"
    fi
}

# Function to create git tag
create_git_tag() {
    local version=$1
    local tag_name="v$version"
    
    echo "Creating git tag: $tag_name"
    
    # Check if tag already exists
    if git tag -l | grep -q "^$tag_name$"; then
        echo "⚠️  Tag $tag_name already exists"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git tag -d "$tag_name"
            git push origin ":refs/tags/$tag_name" 2>/dev/null || true
        else
            echo "❌ Tag creation cancelled"
            return 1
        fi
    fi
    
    # Create and push tag
    git add .
    git commit -m "chore: bump version to $version" || true
    git tag "$tag_name"
    git push origin "$tag_name"
    
    echo "✅ Created and pushed tag: $tag_name"
}

# Function to show version info
show_version_info() {
    local current_version=$(get_current_version)
    local last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "none")
    local commit_count=$(git rev-list --count HEAD)
    local last_commit=$(git rev-parse --short HEAD)
    
    echo "Version Information:"
    echo "==================="
    echo "Current Version: $current_version"
    echo "Last Tag: $last_tag"
    echo "Total Commits: $commit_count"
    echo "Last Commit: $last_commit"
    echo ""
    
    if [ "$last_tag" != "none" ]; then
        local commits_since_tag=$(git rev-list --count "$last_tag"..HEAD)
        echo "Commits since last tag: $commits_since_tag"
        
        if [ "$commits_since_tag" -gt 0 ]; then
            echo ""
            echo "Recent commits:"
            git log --oneline -5 "$last_tag"..HEAD
        fi
    fi
}

# Function to show help
show_help() {
    echo "Neonize Version Manager"
    echo "======================"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  show                    Show current version information"
    echo "  bump [TYPE]             Bump version and update files"
    echo "  tag [VERSION]           Create git tag for version"
    echo "  release [TYPE]          Bump version, create tag, and prepare release"
    echo "  auto                    Auto-detect and bump version based on commits"
    echo ""
    echo "Bump Types:"
    echo "  major                   Increment major version (1.0.0 -> 2.0.0)"
    echo "  minor                   Increment minor version (1.1.0 -> 1.2.0)"
    echo "  patch                   Increment patch version (1.1.1 -> 1.1.2)"
    echo "  build                   Increment build number (1.1.1 -> 1.1.1.1)"
    echo "  auto                    Auto-detect based on commit messages"
    echo ""
    echo "Examples:"
    echo "  $0 show                 # Show current version info"
    echo "  $0 bump patch           # Bump patch version"
    echo "  $0 release minor        # Bump minor version and create tag"
    echo "  $0 auto                 # Auto-detect and bump version"
    echo ""
}

# Main execution
case "${1:-help}" in
    "show")
        show_version_info
        ;;
    "bump")
        if [ -z "$2" ]; then
            echo "❌ Please specify bump type: major, minor, patch, build, or auto"
            exit 1
        fi
        
        new_version=$(bump_version "$2")
        update_version_files "$new_version"
        echo "✅ Version bumped to: $new_version"
        ;;
    "tag")
        version=${2:-$(get_current_version)}
        create_git_tag "$version"
        ;;
    "release")
        if [ -z "$2" ]; then
            echo "❌ Please specify bump type: major, minor, patch, build, or auto"
            exit 1
        fi
        
        echo "🚀 Creating release..."
        new_version=$(bump_version "$2")
        update_version_files "$new_version"
        create_git_tag "$new_version"
        
        echo ""
        echo "🎉 Release preparation completed!"
        echo "Version: $new_version"
        echo "Tag: v$new_version"
        echo ""
        echo "Next steps:"
        echo "1. Build binaries: ./build_all_platforms.sh"
        echo "2. Create GitHub release: ./create_github_release.sh"
        echo "3. Or push the tag to trigger automatic release: git push origin v$new_version"
        ;;
    "auto")
        echo "🤖 Auto-detecting version bump..."
        new_version=$(bump_version "auto")
        update_version_files "$new_version"
        echo "✅ Auto-bumped version to: $new_version"
        ;;
    "help"|*)
        show_help
        ;;
esac