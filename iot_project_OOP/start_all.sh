#!/bin/bash

# Start both Python backend and JavaFX UI simultaneously
# Usage: ./start_all.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Starting IoT Driver Monitoring System"
echo "=========================================="
echo ""

# Check if Python backend is already running
if pgrep -f "main.py" > /dev/null; then
    echo "⚠️  Python backend is already running!"
    read -p "Kill existing process and restart? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pkill -f "main.py"
        sleep 1
    else
        echo "Keeping existing backend process."
    fi
fi

# Check if JavaFX UI is already running
if pgrep -f "gradlew run" > /dev/null; then
    echo "⚠️  JavaFX UI is already running!"
    read -p "Kill existing process and restart? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pkill -f "gradlew run"
        sleep 1
    else
        echo "Keeping existing UI process."
    fi
fi

# Create data directory if it doesn't exist
mkdir -p data

# -------------------------------------------
# GPS availability check (for emergency report)
# -------------------------------------------
echo "📡 Checking GPS availability..."
GPS_AVAILABLE=false

if command -v python3 &> /dev/null; then
    GPS_RESULT_JSON=$(python3 - << 'EOF'
import json
import sys
import os

project_root = os.path.dirname(os.path.abspath(__file__))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

result = None
try:
    import check_system
    result = check_system.check_gps()
except Exception as e:
    result = {
        "status": "ERROR",
        "message": "GPS check failed",
        "details": str(e),
    }

print(json.dumps(result, ensure_ascii=False))
EOF
)

    # Save raw result for UI / debugging
    echo "$GPS_RESULT_JSON" > data/gps_status.json

    if echo "$GPS_RESULT_JSON" | grep -q '"status": "OK"'; then
        echo "   ✅ GPS module detected and real signal received."
        GPS_AVAILABLE=true
    elif echo "$GPS_RESULT_JSON" | grep -q '"status": "WARNING"'; then
        echo "   ⚠️ GPS is available but may be in simulation mode or weak signal."
        GPS_AVAILABLE=false
    else
        echo "   ❌ GPS not available or check failed."
        GPS_AVAILABLE=false
    fi

    # Reflect result into config.GPS_ENABLED so backend uses real GPS when possible
    if [ "$GPS_AVAILABLE" = true ]; then
        python3 update_config.py GPS_ENABLED true >/dev/null 2>&1 || true
    else
        python3 update_config.py GPS_ENABLED false >/dev/null 2>&1 || true
    fi
else
    echo "   ⚠️ python3 not found. Skipping GPS check."
fi

export GPS_AVAILABLE
echo ""

# Check USB webcam availability
echo "📹 Checking USB webcam availability..."
USB_CAM_FOUND=false

# Method 1: Check /dev/video* devices
if ls /dev/video* 1> /dev/null 2>&1; then
    VIDEO_DEVICES=$(ls /dev/video* 2>/dev/null | wc -l)
    echo "   Found $VIDEO_DEVICES video device(s):"
    ls -1 /dev/video* 2>/dev/null | while read device; do
        echo "     - $device"
    done
    USB_CAM_FOUND=true
fi

# Method 2: Check with v4l2-ctl if available
if command -v v4l2-ctl &> /dev/null; then
    if v4l2-ctl --list-devices &> /dev/null; then
        echo "   V4L2 devices:"
        v4l2-ctl --list-devices 2>/dev/null | grep -A 1 "video" | head -10
        USB_CAM_FOUND=true
    fi
fi

# Method 3: Check with lsusb for USB video devices
if command -v lsusb &> /dev/null; then
    USB_VIDEO_DEVICES=$(lsusb | grep -i "video\|camera\|webcam" | wc -l)
    if [ "$USB_VIDEO_DEVICES" -gt 0 ]; then
        echo "   USB video devices found:"
        lsusb | grep -i "video\|camera\|webcam"
        USB_CAM_FOUND=true
    fi
fi

# Method 4: Try to open camera with Python (most reliable)
if command -v python3 &> /dev/null; then
    CAM_TEST=$(python3 -c "
import sys
try:
    import cv2
    # Try to open camera at index 0
    cap = cv2.VideoCapture(0)
    if cap.isOpened():
        ret, frame = cap.read()
        if ret and frame is not None:
            print('OK')
        else:
            print('FAIL')
        cap.release()
    else:
        print('FAIL')
        # Try index 1
        cap = cv2.VideoCapture(1)
        if cap.isOpened():
            ret, frame = cap.read()
            if ret and frame is not None:
                print('OK')
            else:
                print('FAIL')
            cap.release()
        else:
            print('FAIL')
except Exception as e:
    print('FAIL')
" 2>/dev/null)
    
    if [ "$CAM_TEST" = "OK" ]; then
        echo "   ✅ USB webcam is accessible and working"
        USB_CAM_FOUND=true
    else
        echo "   ⚠️  USB webcam may not be accessible (will try PiCamera2 on Raspberry Pi)"
    fi
fi

if [ "$USB_CAM_FOUND" = false ]; then
    echo "   ⚠️  Warning: No USB webcam detected"
    echo "   On Raspberry Pi, the system will try to use PiCamera2 as fallback"
    echo "   On Linux, please connect a USB webcam or check camera permissions"
    echo ""
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 1
    fi
else
    echo "   ✅ USB webcam check completed"
fi
echo ""

# Start Python backend in background
echo "🚀 Starting Python backend..."
python3 main.py start > backend.log 2>&1 &
BACKEND_PID=$!
echo "   Backend PID: $BACKEND_PID"
echo "   Log file: backend.log"
echo ""

# Wait a bit for backend to initialize
sleep 2

# Check if backend started successfully
sleep 1
if ! ps -p $BACKEND_PID > /dev/null; then
    echo "❌ Backend failed to start. Checking logs..."
    if [ -f "backend.log" ]; then
        echo "=== Backend Log (last 20 lines) ==="
        tail -20 backend.log
        echo "==================================="
    fi
    echo ""
    echo "Troubleshooting:"
    echo "1. Check Python dependencies: pip3 install -r requirements.txt"
    echo "2. Check camera access: lsusb or v4l2-ctl --list-devices"
    echo "3. Try running backend manually: python3 main.py start"
    exit 1
fi

echo "✅ Backend started successfully!"
echo ""

# Start JavaFX UI in foreground
echo "🚀 Starting JavaFX UI..."
echo "   (Press Ctrl+C to stop both backend and UI)"
echo ""

cd ui

# Check if gradlew exists, if not, generate it
if [ ! -f "./gradlew" ]; then
    echo "⚠️  gradlew not found. Generating Gradle wrapper..."
    if command -v gradle &> /dev/null; then
        gradle wrapper
    else
        echo "❌ Error: gradlew not found and 'gradle' command is not available."
        echo "   Please install Gradle or ensure the ui submodule is properly initialized."
        echo "   To fix this, run:"
        echo "   cd ui && gradle wrapper"
        echo ""
        echo "🛑 Stopping backend..."
        kill $BACKEND_PID 2>/dev/null
        pkill -f "main.py" 2>/dev/null
        exit 1
    fi
fi

# Ensure gradlew is executable
chmod +x ./gradlew

# Force Gradle wrapper update to 8.10.2 if needed
if [ -f "gradle/wrapper/gradle-wrapper.properties" ]; then
    CURRENT_VERSION=$(grep "distributionUrl" gradle/wrapper/gradle-wrapper.properties | grep -o "gradle-[0-9.]*" | cut -d- -f2)
    if [ "$CURRENT_VERSION" != "8.10.2" ]; then
        echo "⚠️  Gradle wrapper version mismatch. Updating to 8.10.2..."
        if command -v gradle &> /dev/null; then
            gradle wrapper --gradle-version 8.10.2
        else
            echo "   Installing Gradle to update wrapper..."
            sudo apt update && sudo apt install -y gradle
            gradle wrapper --gradle-version 8.10.2
        fi
        chmod +x ./gradlew
    fi
fi

# Ensure gradle-wrapper.jar exists
if [ ! -f "gradle/wrapper/gradle-wrapper.jar" ]; then
    echo "⚠️  gradle-wrapper.jar not found. Attempting to fix..."
    if command -v gradle &> /dev/null; then
        gradle wrapper --gradle-version 8.10.2
        chmod +x ./gradlew
    else
        echo "❌ Error: gradle-wrapper.jar missing and Gradle not installed."
        echo "   Please run: ./fix_gradle_wrapper.sh"
        echo "   Or install Gradle: sudo apt install gradle"
        echo ""
        echo "🛑 Stopping backend..."
        kill $BACKEND_PID 2>/dev/null
        pkill -f "main.py" 2>/dev/null
        exit 1
    fi
fi

# Set JAVA_HOME if not set (for Raspberry Pi compatibility)
if [ -z "$JAVA_HOME" ]; then
    # Try to find Java installation
    JAVA_PATH=$(which java 2>/dev/null)
    if [ -n "$JAVA_PATH" ]; then
        JAVA_PATH=$(readlink -f "$JAVA_PATH" 2>/dev/null || echo "$JAVA_PATH")
        if [ -n "$JAVA_PATH" ]; then
            export JAVA_HOME=$(dirname "$(dirname "$JAVA_PATH")")
        fi
    fi
    
    # Fallback: try common Java paths on Raspberry Pi (including user home)
    if [ -z "$JAVA_HOME" ] || [ ! -d "$JAVA_HOME" ]; then
        for path in \
            "$HOME/jvm/jdk-21.0.9" \
            "$HOME/jvm/jdk-21" \
            /usr/lib/jvm/java-21-openjdk-arm64 \
            /usr/lib/jvm/java-21-openjdk-aarch64 \
            /usr/lib/jvm/java-21-openjdk \
            /opt/java/jdk-21.0.9; do
            if [ -d "$path" ]; then
                export JAVA_HOME="$path"
                break
            fi
        done
    fi
fi

if [ -n "$JAVA_HOME" ]; then
    echo "Using JAVA_HOME: $JAVA_HOME"
fi

./gradlew run

# When UI is closed, stop backend
echo ""
echo "🛑 Stopping backend..."
kill $BACKEND_PID 2>/dev/null
pkill -f "main.py" 2>/dev/null
echo "✅ All processes stopped."

