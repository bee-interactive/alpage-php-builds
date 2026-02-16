# Contributing to Alpage PHP Builds

## Building Locally

### Prerequisites

1. macOS with Apple Silicon (ARM64)
2. Homebrew installed
3. Required dependencies:
   ```bash
   brew install icu4c libsodium openssl@3 freetype jpeg webp libpng oniguruma zlib bzip2 libzip composer
   ```

### Build a Single Version

```bash
./scripts/build-php.sh 8.4
```

### Build All Versions

```bash
for version in 8.1 8.2 8.3 8.4 8.5; do
    ./scripts/build-php.sh $version
done
```

## Testing Builds

After building, test the binaries:

```bash
# Test CLI
./static-php-cli/buildroot/bin/php -v
./static-php-cli/buildroot/bin/php -m

# Check critical extensions
./static-php-cli/buildroot/bin/php -r "var_dump(extension_loaded('sodium'));"
./static-php-cli/buildroot/bin/php -r "var_dump(extension_loaded('intl'));"
```

## Adding New Extensions

1. Add extension name to `build-config/extensions.txt`
2. Update `build-config/build.json` if special flags needed
3. Update `scripts/build-php.sh` extension list
4. Update `.github/workflows/build-php.yml`
5. Test build locally
6. Create PR

## Creating a Release

Releases are automatically created when you push a tag:

```bash
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0
```

GitHub Actions will:
1. Build all PHP versions
2. Create release
3. Upload binaries

## Troubleshooting

### Build fails with missing library

Add the library to Homebrew dependencies in:
- `README.md`
- `.github/workflows/build-php.yml`
- `build-config/build.json`

### Extension not loading

Check if extension requires special configure flags:
```bash
cd static-php-cli
./bin/spc build --help
```

Add flags to `build-config/build.json` under `configure_flags`.
