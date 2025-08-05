#!/usr/bin/env bash

# Fix TTY encoding for Cyrillic characters in NixOS Live environment
# Run this before using Russian scripts

echo "Fixing TTY encoding for Cyrillic characters..."

# Set UTF-8 locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Load Cyrillic console font if available
if command -v setfont >/dev/null 2>&1; then
    # Try different Cyrillic fonts
    for font in ter-132n ter-116n ter-120n ter-124n Lat15-Terminus16 Lat2-Terminus16; do
        if setfont "$font" 2>/dev/null; then
            echo "Successfully loaded font: $font"
            break
        fi
    done
fi

# Set keyboard layout for Russian
if command -v loadkeys >/dev/null 2>&1; then
    loadkeys ru 2>/dev/null || loadkeys us 2>/dev/null
fi

# Test Cyrillic output
echo "Testing Cyrillic: Тест кириллицы"
echo "If you see squares above, use English scripts instead"
echo

echo "Available installation options:"
echo "1. automated-install.sh (Russian interface)"
echo "2. automated-install-en.sh (English interface)"  
echo "3. semi-automated-install.sh (Russian interface)"
echo "4. semi-automated-install-en.sh (English interface)"
echo

echo "Recommendation:"
echo "- If Cyrillic works: use Russian scripts"
echo "- If you see squares: use English scripts (*-en.sh)"