# Setup Guide for Alpage PHP Builds

This guide explains how to set up the build infrastructure for Alpage's custom PHP binaries.

## Quick Start

### 1. Create GitHub Repository

```bash
cd /Users/home/Developements/alpage-php-builds
git remote add origin git@github.com:YOUR_USERNAME/alpage-php-builds.git
git add .
git commit -m "Initial commit: Alpage PHP builds infrastructure"
git push -u origin main
```

### 2. Configure Alpage to Use Custom Builds

Update `PhpDownloadService.swift` in the Alpage repo:

```swift
private static let alpageBuildsUrl = "https://github.com/YOUR_USERNAME/alpage-php-builds/releases/latest/download"
```

Replace `YOUR_USERNAME` with your actual GitHub username.

### 3. Create First Release

```bash
# Tag and push
git tag -a v1.0.0 -m "First release with PHP 8.1-8.5"
git push origin v1.0.0
```

GitHub Actions will automatically:
1. Build PHP 8.1, 8.2, 8.3, 8.4, 8.5
2. Package CLI and FPM binaries
3. Create GitHub Release with all binaries

⏱️ **Build time:** ~45-60 minutes for all versions

### 4. Verify Builds

Once the GitHub Action completes:

1. Go to https://github.com/YOUR_USERNAME/alpage-php-builds/releases
2. Download a binary to test:
   ```bash
   wget https://github.com/YOUR_USERNAME/alpage-php-builds/releases/download/v1.0.0/php-8.4-cli-macos-aarch64.tar.gz
   tar -xzf php-8.4-cli-macos-aarch64.tar.gz
   ./php -v
   ./php -m | grep -E "(sodium|intl|redis)"
   ```

You should see:
```
sodium
intl
redis
```

## Optional: Code Signing

To avoid security warnings, you can sign the binaries with an Apple Developer certificate.

### Prerequisites
- Apple Developer account ($99/year)
- Developer ID Application certificate

### Add Secrets to GitHub

1. Go to Repository Settings → Secrets and variables → Actions
2. Add these secrets:
   - `MACOS_CERTIFICATE`: Base64-encoded .p12 certificate
   - `MACOS_CERTIFICATE_PWD`: Certificate password
   - `MACOS_NOTARIZATION_APPLE_ID`: Your Apple ID
   - `MACOS_NOTARIZATION_TEAM_ID`: Your Team ID
   - `MACOS_NOTARIZATION_PWD`: App-specific password

### Update Workflow

Add this step after "Package binaries" in `.github/workflows/build-php.yml`:

```yaml
- name: Sign binaries
  if: ${{ secrets.MACOS_CERTIFICATE != '' }}
  run: |
    # Import certificate
    echo ${{ secrets.MACOS_CERTIFICATE }} | base64 --decode > certificate.p12
    security create-keychain -p actions build.keychain
    security default-keychain -s build.keychain
    security unlock-keychain -p actions build.keychain
    security import certificate.p12 -k build.keychain -P ${{ secrets.MACOS_CERTIFICATE_PWD }} -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k actions build.keychain

    # Sign binaries
    codesign --force --sign "Developer ID Application" --timestamp \
      static-php-cli/buildroot/bin/php
    codesign --force --sign "Developer ID Application" --timestamp \
      static-php-cli/buildroot/sbin/php-fpm

    # Verify signatures
    codesign -v static-php-cli/buildroot/bin/php
    codesign -v static-php-cli/buildroot/sbin/php-fpm

- name: Notarize binaries
  if: ${{ secrets.MACOS_CERTIFICATE != '' }}
  run: |
    # Create ZIP for notarization
    ditto -c -k --keepParent static-php-cli/buildroot/bin/php php-cli.zip

    # Submit for notarization
    xcrun notarytool submit php-cli.zip \
      --apple-id "${{ secrets.MACOS_NOTARIZATION_APPLE_ID }}" \
      --team-id "${{ secrets.MACOS_NOTARIZATION_TEAM_ID }}" \
      --password "${{ secrets.MACOS_NOTARIZATION_PWD }}" \
      --wait

    # Repeat for FPM
    ditto -c -k --keepParent static-php-cli/buildroot/sbin/php-fpm php-fpm.zip
    xcrun notarytool submit php-fpm.zip \
      --apple-id "${{ secrets.MACOS_NOTARIZATION_APPLE_ID }}" \
      --team-id "${{ secrets.MACOS_NOTARIZATION_TEAM_ID }}" \
      --password "${{ secrets.MACOS_NOTARIZATION_PWD }}" \
      --wait
```

## Automated Updates

To automatically build new PHP versions when released:

### Option 1: Scheduled Builds

Add to `.github/workflows/build-php.yml`:

```yaml
on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday at midnight
```

### Option 2: Manual Trigger

Use the `workflow_dispatch` trigger (already configured):

1. Go to Actions tab on GitHub
2. Select "Build PHP Binaries" workflow
3. Click "Run workflow"
4. Optionally specify PHP versions to build

## Troubleshooting

### Build fails on GitHub Actions

Check the logs for:
1. Missing Homebrew dependencies
2. Network errors downloading PHP sources
3. Compilation errors

### Binaries work locally but not on GitHub

Ensure all dependencies are installed:
```bash
brew list | grep -E "(icu4c|libsodium|openssl|freetype|libjpeg|libwebp|libpng|oniguruma|libzip)"
```

### Extension not loading

Test locally first:
```bash
./scripts/build-php.sh 8.4
./static-php-cli/buildroot/bin/php -m
```

Check if extension is in the build command in `build-php.sh`.

## Maintenance

### Adding a New Extension

1. Edit `build-config/extensions.txt`
2. Update `scripts/build-php.sh` extension list
3. Update `.github/workflows/build-php.yml`
4. Test locally
5. Create new release

### Updating to New PHP Version

When PHP 8.6 is released:

1. Add `"8.6"` to `build-config/build.json`
2. Update README and workflow files
3. Create new release tag

GitHub Actions will automatically build it.
