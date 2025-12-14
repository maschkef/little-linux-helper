#!/bin/bash
#
# gui/dev.sh  
# Development script for Little Linux Helper GUI
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# This project is part of the 'little-linux-helper' collection.
# Licensed under the Apache License 2.0. See the LICENSE file in the project root for more information.
#
# This script starts both backend and frontend in development mode

set -e

echo "=== Starting Little Linux Helper GUI Development Server ==="
echo

# Ensure dependencies (Go, Node.js/npm)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$SCRIPT_DIR/ensure_deps.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/ensure_deps.sh"
    if ! lh_gui_ensure_deps "development"; then
        echo "Development startup aborted due to missing dependencies."
        exit 1
    fi
fi

# Sync translations from CLI to GUI
echo "🌍 Synchronizing translations..."
if [ -f "$PROJECT_ROOT/scripts/sync_gui_translations.sh" ]; then
    if ! "$PROJECT_ROOT/scripts/sync_gui_translations.sh"; then
        echo "❌ Translation sync failed!"
        exit 1
    fi
    echo "✅ Translations synchronized"
else
    echo "⚠️  Warning: Translation sync script not found at $PROJECT_ROOT/scripts/sync_gui_translations.sh"
    echo "   Continuing with existing translations..."
fi
echo

# Function to kill background processes on exit
cleanup() {
    echo
    echo "🛑 Stopping development servers..."
    if [ ! -z "$BACKEND_PID" ]; then
        kill $BACKEND_PID 2>/dev/null || true
    fi
    if [ ! -z "$FRONTEND_PID" ]; then
        kill $FRONTEND_PID 2>/dev/null || true
    fi
    exit
}

# Set up cleanup on script exit
trap cleanup EXIT INT TERM

# Start backend
echo "🚀 Starting Go backend on :3000..."
go run main.go &
BACKEND_PID=$!

# Give backend time to start
sleep 2

# Start frontend development server
echo "🚀 Starting React frontend on :3001..."
cd web
PORT=3001 npm run dev &
FRONTEND_PID=$!
cd ..

echo
echo "✅ Development servers started!"
echo "  - Backend:  http://localhost:3000 (API)"
echo "  - Frontend: http://localhost:3001 (Development)"
echo
echo "The frontend will proxy API requests to the backend."
echo "Press Ctrl+C to stop both servers."
echo

# Wait for either process to exit
wait
