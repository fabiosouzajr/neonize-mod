# Release Process for Neonize

This document explains how to create GitHub releases for neonize-mod with proper binary distribution.

## Overview

The release process involves:
1. Building binaries for all supported platforms
2. Creating a GitHub release with the binaries attached
3. Updating the download script to use GitHub releases

## Prerequisites

### Option 1: GitHub CLI (Recommended)
```bash
# Install GitHub CLI
# macOS
brew install gh

# Ubuntu/Debian
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Authenticate
gh auth login
```

### Option 2: Manual Release Creation
If you don't have GitHub CLI, you can create releases manually through the GitHub web interface.

## Release Process

### Step 1: Build Binaries
```bash
# Build for all available platforms
./build_all_platforms.sh
```

This will create binaries in `releases/v{version}/download/` directory.

### Step 2: Create GitHub Release

#### Using the Automated Script
```bash
# Run the release creation script
./create_github_release.sh
```

This script will:
- Detect the current version
- Create a GitHub release with proper release notes
- Upload all binaries to the release
- Update the download.py script

#### Manual Process
If you prefer to create releases manually:

1. Go to [GitHub Releases](https://github.com/fabiosouzajr/neonize-mod/releases/new)
2. Create a new release with tag `v{version}` (e.g., `v0.3.10.4`)
3. Upload all binaries from `releases/v{version}/download/`
4. Add release notes
5. Publish the release

### Step 3: Update Version (Optional)
```bash
# Edit the VERSION file
echo "0.3.10.5" > VERSION

# Or use the bump script
./bump_version.sh
```

## GitHub Actions Workflow

The repository includes a GitHub Actions workflow (`.github/workflows/release.yml`) that automatically:
- Triggers on tag pushes (e.g., `v0.3.10.4`)
- Builds binaries for all platforms
- Creates a GitHub release with the binaries

To use this:
```bash
# Create and push a tag
git tag v0.3.10.4
git push origin v0.3.10.4
```

## URL Structure

After creating a release, the download URLs will be:
```
https://github.com/fabiosouzajr/neonize-mod/releases/download/v0.3.10.4/neonize-linux-amd64.so
https://github.com/fabiosouzajr/neonize-mod/releases/download/v0.3.10.4/neonize-windows-amd64.dll
https://github.com/fabiosouzajr/neonize-mod/releases/download/v0.3.10.4/neonize-linux-arm64.so
# etc.
```

## Installation

Users can now install the package with:
```bash
# Install specific version
pip install git+https://github.com/fabiosouzajr/neonize-mod.git@v0.3.10.4

# Install latest
pip install git+https://github.com/fabiosouzajr/neonize-mod.git
```

## Troubleshooting

### Common Issues

1. **"UnsupportedPlatform" Error**
   - Ensure the release exists and binaries are uploaded
   - Check that the version in VERSION file matches the release tag

2. **Missing Binaries**
   - Run the build script first: `./build_all_platforms.sh`
   - Ensure all required compilers are installed

3. **GitHub CLI Authentication**
   - Run `gh auth login` to authenticate
   - Ensure you have write access to the repository

### Verification

After creating a release, test the installation:
```bash
# Create a test environment
python -m venv test_env
source test_env/bin/activate  # or test_env\Scripts\activate on Windows

# Install the package
pip install git+https://github.com/fabiosouzajr/neonize-mod.git@v0.3.10.4

# Test import
python -c "from neonize import NewClient; print('Installation successful!')"
```

## Best Practices

1. **Version Consistency**: Always update the VERSION file before creating a release
2. **Release Notes**: Include meaningful release notes with changes and supported platforms
3. **Testing**: Test the installation process after creating a release
4. **Documentation**: Update documentation to reflect new versions and features
5. **Backup**: The release script creates backups of modified files

## Support

If you encounter issues with the release process:
1. Check the GitHub Actions logs for automated releases
2. Verify all binaries are properly uploaded
3. Test the download URLs manually
4. Check the VERSION file matches the release tag 