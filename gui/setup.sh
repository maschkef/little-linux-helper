#!/bin/bash
#
# gui/setup.sh
# Setup script for Little Linux Helper GUI
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This project is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# This script sets up the development environment for the GUI

set -e

echo "=== Little Linux Helper GUI Setup ==="
echo

# Ensure dependencies via shared helper (attempts install via project library)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/ensure_deps.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/ensure_deps.sh"
    if ! lh_gui_ensure_deps "setup"; then
        echo "Setup aborted due to missing dependencies."
        exit 1
    fi
fi

echo
echo "=== Installing Dependencies ==="
echo

# Install Go dependencies
echo "📦 Installing Go dependencies..."
go mod tidy
go mod download

# Install Node.js dependencies
echo "📦 Installing React dependencies..."
cd web
npm install
cd ..

echo
echo "=== Building Frontend ==="
echo

# Build React app
cd web
npm run build
cd ..

echo
echo "✅ Setup completed successfully!"
echo
echo "To start the development servers:"
echo "  1. Backend (API on http://localhost:3000):  go run main.go"
echo "  2. Frontend (Dev on http://localhost:3001): cd web && npm run dev"
echo
echo "To build for production:"
echo "  ./build.sh"
echo
echo "The production GUI will be available at: http://localhost:3000"
