#!/bin/bash
#
# gui_launcher.sh
# Simple launcher script for the Little Linux Helper GUI
#
# Add this to the main help_master.sh menu or use as standalone launcher

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUI_DIR="$SCRIPT_DIR/gui"

# Check if GUI directory exists
if [ ! -d "$GUI_DIR" ]; then
    echo "❌ GUI directory not found: $GUI_DIR"
    echo "Please ensure the GUI is properly installed."
    exit 1
fi

# Check if GUI is built
if [ ! -f "$GUI_DIR/little-linux-helper-gui" ]; then
    echo "🔨 GUI not built. Building now..."
    cd "$GUI_DIR"
    
    if [ ! -f "setup.sh" ]; then
        echo "❌ Setup script not found. Please check GUI installation."
        exit 1
    fi
    
    ./setup.sh
    ./build.sh
    
    if [ $? -ne 0 ]; then
        echo "❌ Build failed. Please check the error messages above."
        exit 1
    fi
    
    echo "✅ Build completed successfully!"
fi

# Start the GUI
echo "🚀 Starting Little Linux Helper GUI..."
echo "The GUI will be available at: http://localhost:3000"
echo "Press Ctrl+C to stop the GUI server."
echo

cd "$GUI_DIR"
exec ./little-linux-helper-gui
