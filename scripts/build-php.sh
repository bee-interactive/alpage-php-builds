#!/bin/bash
set -e

# Alpage PHP Build Script
# Builds PHP with all extensions using static-php-cli

PHP_VERSION=${1:-"8.4"}
ARCH=${2:-"aarch64-darwin"}
OUTPUT_DIR=${3:-"./dist"}

echo "🚀 Building PHP $PHP_VERSION for $ARCH"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if static-php-cli is available
if [ ! -d "static-php-cli" ]; then
    echo -e "${YELLOW}📦 Downloading static-php-cli...${NC}"
    git clone --depth=1 https://github.com/crazywhalecc/static-php-cli.git
fi

cd static-php-cli

# Install dependencies
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
composer install --no-dev --optimize-autoloader 2>/dev/null || composer install

# Extensions to build
EXTENSIONS="bcmath,bz2,calendar,ctype,curl,dom,exif,fileinfo,filter,ftp,gd,hash,iconv,intl,json,libxml,mbstring,mysqlnd,mysqli,openssl,pcntl,pdo,pdo_mysql,pdo_pgsql,pdo_sqlite,pgsql,phar,posix,session,simplexml,soap,sockets,sodium,sqlite3,tokenizer,xml,xmlreader,xmlwriter,zip,zlib,redis"

# Extract major.minor version
PHP_MAJOR_MINOR=$(echo $PHP_VERSION | grep -oE '^[0-9]+\.[0-9]+')

echo -e "${YELLOW}📥 Downloading PHP $PHP_VERSION sources...${NC}"
./bin/spc download --with-php=$PHP_MAJOR_MINOR --for-extensions=$EXTENSIONS --retry=3

echo -e "${YELLOW}🔨 Building PHP $PHP_VERSION CLI...${NC}"
./bin/spc build $EXTENSIONS \
    --build-cli \
    --with-libs=icu4c,libsodium,openssl,freetype,jpeg,webp,png,oniguruma,zlib,bzip2,libzip

echo -e "${YELLOW}🔨 Building PHP $PHP_VERSION FPM...${NC}"
./bin/spc build $EXTENSIONS \
    --build-fpm \
    --with-libs=icu4c,libsodium,openssl,freetype,jpeg,webp,png,oniguruma,zlib,bzip2,libzip

# Create output directory
mkdir -p ../$OUTPUT_DIR

# Package CLI
echo -e "${YELLOW}📦 Packaging PHP $PHP_VERSION CLI...${NC}"
if [ -f "buildroot/bin/php" ]; then
    tar -czf ../$OUTPUT_DIR/php-$PHP_VERSION-cli-$ARCH.tar.gz -C buildroot/bin php
    echo -e "${GREEN}✅ CLI built successfully${NC}"
else
    echo -e "${RED}❌ CLI build failed${NC}"
    exit 1
fi

# Package FPM
echo -e "${YELLOW}📦 Packaging PHP $PHP_VERSION FPM...${NC}"
if [ -f "buildroot/sbin/php-fpm" ]; then
    tar -czf ../$OUTPUT_DIR/php-$PHP_VERSION-fpm-$ARCH.tar.gz -C buildroot/sbin php-fpm
    echo -e "${GREEN}✅ FPM built successfully${NC}"
else
    echo -e "${RED}❌ FPM build failed${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 PHP $PHP_VERSION build complete!${NC}"
echo "Output files:"
ls -lh ../$OUTPUT_DIR/php-$PHP_VERSION-*

# Test the built PHP
echo -e "${YELLOW}🧪 Testing built PHP...${NC}"
./buildroot/bin/php -v
echo ""
echo "Extensions loaded:"
./buildroot/bin/php -m | grep -E "(sodium|intl|redis)" || echo -e "${RED}⚠️  Some critical extensions missing${NC}"
