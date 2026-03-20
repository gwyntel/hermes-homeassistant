#!/bin/bash

# Home Assistant Configuration Management - Linux Setup Script
# This script sets up everything you need to get started

set -e  # Exit on any error

echo "🏠 Home Assistant Configuration Management - Linux Setup"
echo "==================================================="
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "🔍 Checking prerequisites..."

# Check if Python 3.12+ is available
if command_exists python3.12; then
    PYTHON_CMD="python3.12"
elif command_exists python3; then
    PYTHON_CMD="python3"
else
    echo "❌ Python 3 is not installed."
    echo ""
    echo "Install Python 3.12+ (e.g., sudo apt install python3.12 python3.12-venv)"
    echo ""
    echo "Then run this script again."
    exit 1
fi

# Check Python version
PYTHON_VERSION=$($PYTHON_CMD -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')

if ! $PYTHON_CMD -c "import sys; exit(0 if sys.version_info >= (3, 12) else 1)"; then
    echo "❌ Python $PYTHON_VERSION found, but Python 3.12+ is required."
    echo ""
    echo "Home Assistant 2024.x requires Python 3.12 or newer."
    echo ""
    exit 1
fi

echo "✅ Python $PYTHON_VERSION found (using $PYTHON_CMD)"

# Check if git is available
if ! command_exists git; then
    echo "❌ Git is not installed."
    echo "Install git with: sudo apt install git"
    exit 1
fi

echo "✅ Git found"

# Check if make is available
if ! command_exists make; then
    echo "❌ Make is not installed."
    echo "Install make with: sudo apt install make"
    exit 1
fi

echo "✅ Make found"

# Check for rsync
if command_exists rsync; then
    echo "✅ Rsync found"
else
    echo "❌ Rsync is not installed."
    echo "Install rsync with: sudo apt install rsync"
    exit 1
fi

echo ""
echo "🐍 Setting up Python environment..."

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    $PYTHON_CMD -m venv venv
else
    echo "Virtual environment already exists"
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "Installing Python dependencies..."
pip install homeassistant voluptuous pyyaml jsonschema requests

echo ""
echo "🔍 Verifying Python environment..."

# Verify critical dependencies are importable
VERIFY_FAILED=false

python -c "import yaml" 2>/dev/null || { echo "❌ PyYAML not installed correctly"; VERIFY_FAILED=true; }
python -c "import voluptuous" 2>/dev/null || { echo "❌ Voluptuous not installed correctly"; VERIFY_FAILED=true; }
python -c "import jsonschema" 2>/dev/null || { echo "❌ jsonschema not installed correctly"; VERIFY_FAILED=true; }
python -c "import requests" 2>/dev/null || { echo "❌ requests not installed correctly"; VERIFY_FAILED=true; }

if [ "$VERIFY_FAILED" = true ]; then
    echo ""
    echo "⚠️  Some dependencies failed to install. Try running:"
    echo "   source venv/bin/activate"
    echo "   pip install --force-reinstall homeassistant voluptuous pyyaml jsonschema requests"
    echo ""
else
    echo "✅ All Python dependencies verified"
fi

echo ""
echo "⚙️  Home Assistant Configuration"
echo "==============================="
echo ""
echo "Let's configure your Home Assistant connection!"
echo ""

# Get Home Assistant host
read -p "Enter your Home Assistant hostname or IP address (e.g., homeassistant.local): " HA_HOST
while [ -z "$HA_HOST" ]; do
    echo "❌ Hostname/IP cannot be empty"
    read -p "Enter your Home Assistant hostname or IP address: " HA_HOST
done

# Update Makefile with the provided host
echo ""
echo "📝 Updating Makefile configuration..."
if [ -f "Makefile" ]; then
    # Create backup
    cp Makefile Makefile.backup

    # Update HA_HOST in Makefile
    sed -i "s/^HA_HOST = .*/HA_HOST = $HA_HOST/" Makefile
    echo "✅ Makefile updated with HA_HOST = $HA_HOST"
else
    echo "❌ Makefile not found - you may need to configure manually"
fi

echo ""
echo "🎉 Linux Setup Complete!"
echo "======================"
echo ""
echo "Configuration Summary:"
echo "- Home Assistant Host: $HA_HOST"
echo ""
echo "Next steps:"
echo "1. Configure your .env file (copy .env.example)"
echo "2. Setup SSH keys for HA access"
echo "3. Pull your actual configuration: make pull"
echo ""
echo "For Hermes-specific setup, see HERMES.md"
echo ""
