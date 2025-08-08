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

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed. Please install Go 1.21 or later."
    echo "   Visit: https://golang.org/dl/"
    exit 1
fi

# Check Go version
GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
echo "✅ Go version: $GO_VERSION"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 16 or later."
    echo "   Visit: https://nodejs.org/"
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node --version)
echo "✅ Node.js version: $NODE_VERSION"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm."
    exit 1
fi

NPM_VERSION=$(npm --version)
echo "✅ npm version: $NPM_VERSION"

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
echo "To start the development server:"
echo "  1. Backend:  go run main.go"
echo "  2. Frontend: cd web && npm start"
echo
echo "To build for production:"
echo "  ./build.sh"
echo
echo "The GUI will be available at: http://localhost:3000"
