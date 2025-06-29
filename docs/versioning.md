# Versioning Guide for Neonize

This document explains how versioning works in the Neonize project, including manual and automated workflows.

---

## Table of Contents
- [Versioning Philosophy](#versioning-philosophy)
- [Where the Version is Stored](#where-the-version-is-stored)
- [Manual Version Bumping](#manual-version-bumping)
- [Automatic Version Bumping](#automatic-version-bumping)
- [GitHub Actions Integration](#github-actions-integration)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Versioning Philosophy

Neonize follows [Semantic Versioning](https://semver.org/):
- **MAJOR** version when you make incompatible API changes
- **MINOR** version when you add functionality in a backwards compatible manner
- **PATCH** version when you make backwards compatible bug fixes
- **BUILD** (optional) for internal or CI builds (e.g., 1.2.3.4)

---

## Where the Version is Stored

- The current version is stored in the `VERSION` file at the project root.
- The version is also updated in:
  - `neonize/download.py` (for binary downloads)
  - `pyproject.toml` (if present)
  - `package.json` (if present)

---

## Manual Version Bumping

Use the `bump_version.sh` script to update the version:

### Show Current Version
```bash
./bump_version.sh show
```

### Bump Version
```bash
./bump_version.sh bump patch   # Bump patch version (e.g., 1.2.3 → 1.2.4)
./bump_version.sh bump minor   # Bump minor version (e.g., 1.2.3 → 1.3.0)
./bump_version.sh bump major   # Bump major version (e.g., 1.2.3 → 2.0.0)
./bump_version.sh bump build   # Bump build number (e.g., 1.2.3 → 1.2.3.1)
```

### Tag and Release
```bash
./bump_version.sh release patch   # Bump patch, update files, create tag, and prep for release
```

---

## Automatic Version Bumping

You can use the `auto` mode to automatically determine the version bump based on commit messages:

```bash
./bump_version.sh auto
```
- **Major**: If any commit since the last tag contains `BREAKING CHANGE` or `!:`
- **Minor**: If any commit contains `feat:`
- **Patch**: Otherwise

This will update all relevant files and print the new version.

---

## GitHub Actions Integration

The workflow `.github/workflows/auto-version.yml` automates versioning and releases:
- On every push to `main` or `master`, or via manual dispatch, it:
  1. Detects the required version bump (auto or specified)
  2. Updates the `VERSION` file and other relevant files
  3. Commits and tags the new version
  4. Builds binaries for all platforms
  5. Publishes a GitHub release with the binaries attached

### Manual Trigger
You can trigger the workflow manually from the GitHub Actions tab and select the bump type (auto, major, minor, patch, build).

---

## Best Practices
- Always bump the version before releasing new features or fixes.
- Use clear commit messages (`feat:`, `fix:`, `BREAKING CHANGE`, etc.) to enable auto-versioning.
- Tag releases with `vX.Y.Z` (e.g., `v1.2.3`).
- Keep the `VERSION` file in sync with your latest release.
- Test the release process in a test branch before using in production.

---

## Troubleshooting
- **Version not updating?**
  - Make sure you run `./bump_version.sh` from the project root.
  - Check for errors in the script output.
- **GitHub Actions not triggering?**
  - Ensure you push to `main` or `master` or use the manual dispatch.
  - Check the Actions tab for logs and errors.
- **Binary not found after release?**
  - Make sure you run `./build_all_platforms.sh` before creating a release.
  - Ensure the correct version is set in the `VERSION` file.

---

## Further Reading
- [Semantic Versioning](https://semver.org/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Neonize Release Process](../RELEASE_PROCESS.md) 