#!/bin/bash
#
# gui/build.sh
# Build script for Little Linux Helper GUI
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This project is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# This script builds the complete GUI application for production

set -e

echo "=== Building Little Linux Helper GUI ==="
echo

# Build frontend
echo "🔨 Building React frontend..."
cd web
npm run build
cd ..

# Build Go backend
echo "🔨 Building Go backend..."
go build -o little-linux-helper-gui main.go

echo
echo "✅ Build completed successfully!"
echo
echo "Generated files:"
echo "  - little-linux-helper-gui (executable)"
echo "  - web/build/ (React frontend)"
echo
echo "To run the production build:"
echo "  ./little-linux-helper-gui"
echo
echo "The GUI will be available at: http://localhost:3000"
