#!/bin/bash
#
# gui_launcher.sh
# Simple launcher script for the Little Linux Helper GUI
#
# Usage: ./gui_launcher.sh [-b|--build] [-n|--network] [-p|--port PORT] [-h|--help]
# Options:
#   -b, --build      Rebuild the GUI before launching
#   -n, --network    Allow network access (bind to 0.0.0.0, use with caution)
#   -p, --port PORT  Set custom port (overrides config file)
#   -h, --help       Show help message
#
# Add this to the main help_master.sh menu or use as standalone launcher

# Parse command line arguments
BUILD_FLAG=false
GUI_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--build)
            BUILD_FLAG=true
            shift
            ;;
        -n|--network)
            GUI_ARGS+=("-network")
            shift
            ;;
        -p|--port)
            GUI_ARGS+=("-port" "$2")
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-b|--build] [-n|--network] [-p|--port PORT] [-h|--help]"
            echo ""
            echo "Options:"
            echo "  -b, --build      Rebuild the GUI before launching"
            echo "  -n, --network    Allow network access (bind to 0.0.0.0, use with caution)"
            echo "  -p, --port PORT  Set custom port (default: 3000 or from config)"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "Configuration:"
            echo "  Settings can be configured in config/general.conf:"
            echo "  - CFG_LH_GUI_PORT=\"3000\"          # Set default port"
            echo "  - CFG_LH_GUI_HOST=\"localhost\"     # Set default binding"
            echo ""
            echo "Security:"
            echo "  - Default: GUI accessible only from localhost (secure)"
            echo "  - Network mode: GUI accessible from other machines (use with caution)"
            echo ""
            echo "Examples:"
            echo "  $0                    # Default: localhost:3000"
            echo "  $0 -p 8080           # Custom port: localhost:8080"
            echo "  $0 --port 8080       # Custom port: localhost:8080"
            echo "  $0 -n                # Network access: 0.0.0.0:3000"
            echo "  $0 -n -p 80          # Network access: 0.0.0.0:80"
            echo "  $0 -b -n             # Build and run with network access"
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
    # Ensure build dependencies (Go, Node.js/npm)
    if [ -f "$GUI_DIR/ensure_deps.sh" ]; then
        # shellcheck source=/dev/null
        source "$GUI_DIR/ensure_deps.sh"
        if ! lh_gui_ensure_deps "launcher"; then
            echo "❌ Missing dependencies required for building the GUI."
            exit 1
        fi
    fi
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

# Determine the access message based on network flag
if [[ " ${GUI_ARGS[*]} " =~ " -network " ]]; then
    echo "⚠️  WARNING: Network mode enabled - GUI will be accessible from other machines"
    echo "⚠️  WARNING: Ensure your firewall is properly configured"
    echo "The GUI will be accessible from the network (check console output for actual port)"
else
    echo "The GUI will be accessible locally (check console output for actual port)"
fi

echo "Press Ctrl+C to stop the GUI server."
echo

cd "$GUI_DIR"

# Execute with or without arguments
if [ ${#GUI_ARGS[@]} -eq 0 ]; then
    exec ./little-linux-helper-gui
else
    exec ./little-linux-helper-gui "${GUI_ARGS[@]}"
fi
