# Alpage PHP Builds

Custom PHP builds for [Alpage](https://github.com/nicoverbruggen/alpage) with all commonly needed extensions included.

## Why Custom Builds?

The official static-php-cli binaries are compiled with `--disable-all` and only re-enable a minimal set of extensions. This means critical extensions like `sodium` and `intl` are missing, causing Composer errors and compilation headaches.

Our custom builds include:

### Builtin Extensions (Always Included)
- **sodium** - Modern cryptography (required by Laravel Firebase, JWT, etc.)
- **intl** - Internationalization functions
- **openssl** - SSL/TLS support
- **curl** - HTTP client
- **mbstring** - Multi-byte string handling
- **pdo_mysql**, **pdo_pgsql**, **pdo_sqlite** - Database drivers
- **gd** - Image manipulation
- **zip** - Archive handling
- **xml**, **dom**, **simplexml** - XML processing
- **bcmath** - Arbitrary precision math
- **opcache** - Opcode caching
- And 30+ more standard extensions

### PECL Extensions (Optional, Pre-compiled)
- **redis** - Redis client
- **imagick** - ImageMagick bindings
- **xdebug** - Debugging (debug builds only)

## PHP Versions Supported

- PHP 8.1 (Security fixes until Nov 2024)
- PHP 8.2 (Active support until Dec 2024)
- PHP 8.3 (Active support until Nov 2025)
- PHP 8.4 (Active support until Nov 2026)
- PHP 8.5 (In development)

## Build Process

Builds are created using [static-php-cli](https://github.com/crazywhalecc/static-php-cli) with custom configuration:

1. Download latest PHP source for each version
2. Compile with all extensions enabled
3. Codesign and notarize for macOS (when certificates are available)
4. Publish as GitHub Releases

## Architecture Support

- **macOS ARM64** (Apple Silicon) - Primary target
- **macOS x86_64** (Intel) - Coming soon

## Usage in Alpage

Alpage automatically downloads these builds instead of the official static-php-cli binaries. No user action required!

## Building Locally

```bash
# Install dependencies
brew install icu4c libsodium openssl@3 freetype jpeg webp libpng oniguruma zlib bzip2 libzip

# Install static-php-cli
git clone https://github.com/crazywhalecc/static-php-cli.git
cd static-php-cli

# Build PHP 8.4 with all extensions
./bin/spc download --with-php=8.4 --for-extensions=sodium,intl,redis
./bin/spc build sodium,intl,redis --build-cli --build-fpm \
  --with-libs=icu4c,libsodium,openssl,freetype,jpeg,webp,png,oniguruma,zlib,bzip2,libzip
```

See `build-config/` for our full configurations.

## License

MIT License - Same as Alpage
