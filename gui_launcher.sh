#!/bin/bash
#
# gui_launcher.sh
# Simple launcher script for the Little Linux Helper GUI
#
# Usage: ./gui_launcher.sh [-b|--build]
# Options:
#   -b, --build    Rebuild the GUI before launching
#
# Add this to the main help_master.sh menu or use as standalone launcher

# Parse command line arguments
BUILD_FLAG=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--build)
            BUILD_FLAG=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-b|--build] [-h|--help]"
            echo ""
            echo "Options:"
            echo "  -b, --build    Rebuild the GUI before launching"
            echo "  -h, --help     Show this help message"
            echo ""
            echo "The GUI will be available at: http://localhost:3000"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information."
            exit 1
            ;;
    esac
done

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUI_DIR="$SCRIPT_DIR/gui"

# Check if GUI directory exists
if [ ! -d "$GUI_DIR" ]; then
    echo "❌ GUI directory not found: $GUI_DIR"
    echo "Please ensure the GUI is properly installed."
    exit 1
fi

# Handle build requests
if [ "$BUILD_FLAG" = true ] || [ ! -f "$GUI_DIR/little-linux-helper-gui" ]; then
    if [ "$BUILD_FLAG" = true ]; then
        echo "🔨 Rebuilding GUI as requested..."
    else
        echo "❓ GUI is not built yet."
        echo "The GUI needs to be built before it can be launched."
        echo ""
        read -p "Do you want to build it now? [y/N]: " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Build cancelled. Cannot launch GUI without building it first."
            exit 1
        fi
        echo "🔨 Building GUI..."
    fi
    
    cd "$GUI_DIR"
    
    if [ ! -f "build.sh" ]; then
        echo "❌ Build script not found: $GUI_DIR/build.sh"
        echo "Please ensure the GUI build script is available."
        exit 1
    fi
    
    # Run setup first if it exists and GUI is not built
    if [ ! -f "little-linux-helper-gui" ] && [ -f "setup.sh" ]; then
        echo "🔧 Running initial setup..."
        ./setup.sh
        if [ $? -ne 0 ]; then
            echo "❌ Setup failed. Please check the error messages above."
            exit 1
        fi
    fi
    
    # Run the build script
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
