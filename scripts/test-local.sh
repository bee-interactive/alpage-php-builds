#!/bin/bash
# Local test script - mirrors the GitHub Actions workflow exactly
# Usage: ./scripts/test-local.sh [php_version]
# Example: ./scripts/test-local.sh 8.3

set -e

PHP_VERSION="${1:-8.3}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPC_DIR="$REPO_ROOT/static-php-cli"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

step() { echo -e "\n${BLUE}===> $1${NC}"; }
ok()   { echo -e "${GREEN}✅  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️   $1${NC}"; }
fail() { echo -e "${RED}❌  $1${NC}"; exit 1; }

cd "$REPO_ROOT"

echo -e "${BLUE}╔══════════════════════════════════════════╗"
echo -e "║  Local build test — PHP $PHP_VERSION         ║"
echo -e "╚══════════════════════════════════════════╝${NC}"

# ── Step 1: static-php-cli ──────────────────────────────────────────────────
step "Clone / update static-php-cli"
if [ ! -d "$SPC_DIR" ]; then
    git clone --depth=1 https://github.com/crazywhalecc/static-php-cli.git "$SPC_DIR"
else
    warn "static-php-cli already present — skipping clone"
fi

cd "$SPC_DIR"
composer install --no-dev --optimize-autoloader --quiet
ok "Composer dependencies installed"

# ── Step 2: spc doctor ─────────────────────────────────────────────────────
step "spc doctor --auto-fix"
./bin/spc doctor --auto-fix
ok "Doctor passed"

# ── Step 3: Download sources ────────────────────────────────────────────────
step "Download PHP $PHP_VERSION sources"
./bin/spc download \
    --with-php="$PHP_VERSION" \
    --for-extensions=bcmath,bz2,calendar,ctype,curl,dom,exif,fileinfo,filter,ftp,gd,gmp,hash,iconv,intl,json,libxml,mbstring,mbregex,mysqlnd,mysqli,openssl,pcntl,pdo,pdo_mysql,pdo_pgsql,pdo_sqlite,pgsql,phar,posix,session,simplexml,soap,sockets,sodium,sqlite3,tokenizer,xml,xmlreader,xmlwriter,zip,zlib,redis \
    --for-libs=onig,libjpeg,libwebp \
    --retry=3
ok "Sources downloaded"

# ── Step 4: Build ───────────────────────────────────────────────────────────
step "Build PHP $PHP_VERSION (cli + fpm + embed)"
./bin/spc build \
    bcmath,bz2,calendar,ctype,curl,dom,exif,fileinfo,filter,ftp,gd,gmp,hash,iconv,intl,json,libxml,mbstring,mbregex,mysqlnd,mysqli,openssl,pcntl,pdo,pdo_mysql,pdo_pgsql,pdo_sqlite,pgsql,phar,posix,session,simplexml,soap,sockets,sodium,sqlite3,tokenizer,xml,xmlreader,xmlwriter,zip,zlib,redis \
    --with-libs=onig,libjpeg,libwebp \
    --build-cli \
    --build-fpm \
    --build-embed
ok "Build complete"

# ── Step 5: Detect phpize (absolute paths) ──────────────────────────────────
step "Check phpize availability"
PHPIZE=$(find "$SPC_DIR/buildroot/bin" -name "phpize" -type f 2>/dev/null | head -1)
PHP_CONFIG=$(find "$SPC_DIR/buildroot/bin" -name "php-config" -type f 2>/dev/null | head -1)

PHPIZE_AVAILABLE=false
if [ -n "$PHPIZE" ] && [ -x "$PHPIZE" ] && [ -n "$PHP_CONFIG" ] && [ -x "$PHP_CONFIG" ]; then
    PHPIZE_AVAILABLE=true
    ok "phpize found: $PHPIZE"
    ok "php-config found: $PHP_CONFIG"
else
    warn "phpize not found — pcov build will be skipped"
    echo "  buildroot/bin contents:"
    ls -la "$SPC_DIR/buildroot/bin/" | sed 's/^/    /'
fi

# ── Step 6: Install autoconf (if needed) ────────────────────────────────────
if [ "$PHPIZE_AVAILABLE" = "true" ]; then
    step "Ensure autoconf is installed"
    if brew list autoconf >/dev/null 2>&1; then
        ok "autoconf already installed ($(brew list --versions autoconf))"
    else
        brew install autoconf
        ok "autoconf installed"
    fi
fi

# ── Step 7: Build pcov ──────────────────────────────────────────────────────
if [ "$PHPIZE_AVAILABLE" = "true" ]; then
    step "Build pcov extension"
    PCOV_VERSION="1.0.11"
    PCOV_BUILD_DIR="$REPO_ROOT/pcov-build-$$"
    mkdir -p "$PCOV_BUILD_DIR"
    trap "rm -rf '$PCOV_BUILD_DIR'" EXIT

    curl -fSL "https://github.com/krakjoe/pcov/archive/refs/tags/v${PCOV_VERSION}.tar.gz" -o "$PCOV_BUILD_DIR/pcov.tar.gz"
    tar -xzf "$PCOV_BUILD_DIR/pcov.tar.gz" -C "$PCOV_BUILD_DIR"
    cd "$PCOV_BUILD_DIR/pcov-${PCOV_VERSION}"

    PHP_VER_NUM=$("$PHP_CONFIG" --version | awk -F. '{printf "%d%02d%02d", $1, $2, $3}')
    if [ "$PHP_VER_NUM" -ge 80200 ]; then
        sed -i '' 's/0, 0, 0, 0);/0, 0, 0);/' pcov.c
        ok "Applied pcov PHP 8.2+ compatibility patch (php_pcre_match_impl signature)"
    fi

    "$PHPIZE"
    ./configure --with-php-config="$PHP_CONFIG" --enable-pcov
    make -j"$(sysctl -n hw.ncpu)"

    PCOV_SO=$(find . -name "pcov.so" | head -1)
    if [ -n "$PCOV_SO" ]; then
        mkdir -p "$SPC_DIR/buildroot/modules"
        cp "$PCOV_SO" "$SPC_DIR/buildroot/modules/pcov.so"
        ok "pcov.so built and installed"
    else
        fail "pcov.so not found after build"
    fi
    cd "$REPO_ROOT"
else
    warn "Skipping pcov build (phpize unavailable)"
fi

# ── Step 8: Test binaries ────────────────────────────────────────────────────
step "Test built binaries"
PHP_BIN="$SPC_DIR/buildroot/bin/php"
"$PHP_BIN" -v
echo ""
"$PHP_BIN" -r "echo 'intl:      ' . (extension_loaded('intl')     ? '✅' : '❌') . PHP_EOL;"
"$PHP_BIN" -r "echo 'redis:     ' . (extension_loaded('redis')    ? '✅' : '❌') . PHP_EOL;"
"$PHP_BIN" -r "echo 'mbstring:  ' . (extension_loaded('mbstring') ? '✅' : '❌') . PHP_EOL;"
"$PHP_BIN" -r "echo 'gd:        ' . (extension_loaded('gd')       ? '✅' : '❌') . PHP_EOL;"
echo ""
echo "  buildroot/bin:"
ls -la "$SPC_DIR/buildroot/bin/" | sed 's/^/    /'
ls -la "$SPC_DIR/buildroot/modules/" 2>/dev/null | sed 's/^/    /' || echo "    (no modules)"

# ── Step 9: Package ─────────────────────────────────────────────────────────
step "Package binaries"
DIST_DIR="$REPO_ROOT/dist-local"
mkdir -p "$DIST_DIR"

tar -czf "$DIST_DIR/php-$PHP_VERSION-cli-macos-aarch64.tar.gz" -C "$SPC_DIR/buildroot/bin" php
ok "CLI packaged"

FPM_PATH=$(find "$SPC_DIR/buildroot" -name "php-fpm" -type f | head -1)
if [ -n "$FPM_PATH" ]; then
    tar -czf "$DIST_DIR/php-$PHP_VERSION-fpm-macos-aarch64.tar.gz" -C "$(dirname "$FPM_PATH")" php-fpm
    ok "FPM packaged"
else
    warn "php-fpm not found — skipping FPM package"
fi

if [ -f "$SPC_DIR/buildroot/modules/pcov.so" ]; then
    tar -czf "$DIST_DIR/php-$PHP_VERSION-pcov-macos-aarch64.tar.gz" -C "$SPC_DIR/buildroot/modules" pcov.so
    ok "pcov.so packaged"
fi

cd "$DIST_DIR" && shasum -a 256 *.tar.gz > SHA256SUMS && cat SHA256SUMS

echo -e "\n${GREEN}🎉  Local build complete for PHP $PHP_VERSION${NC}"
echo "   Artifacts in: $DIST_DIR"
