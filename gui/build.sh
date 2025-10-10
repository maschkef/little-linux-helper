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

# Ensure dependencies (Go, Node.js/npm)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/ensure_deps.sh" ]; then
	# shellcheck source=/dev/null
	source "$SCRIPT_DIR/ensure_deps.sh"
	if ! lh_gui_ensure_deps "build"; then
		echo "Build aborted due to missing dependencies."
		exit 1
	fi
fi

# Build frontend
echo "🔨 Building React frontend..."
cd web
npm run build
cd ..

# Build Go backend
echo "🔨 Building Go backend..."
go build -o little-linux-helper-gui main.go

# Fix ownership if running with sudo
if [[ $EUID -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]]; then
	echo "🔧 Fixing file ownership for user $SUDO_USER..."
	chown -R "$SUDO_USER:$(id -gn "$SUDO_USER")" web/build 2>/dev/null || true
	chown "$SUDO_USER:$(id -gn "$SUDO_USER")" little-linux-helper-gui 2>/dev/null || true
fi

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
