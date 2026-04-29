#!/bin/bash

# Build script for Snowflake S3Compat API Test Suite with Podman
# This script builds a multi-stage Docker image with Maven cache support

set -e  # Exit on error

# Default values
IMAGE_NAME="s3compat-test-suite"
IMAGE_TAG="latest"
SETTINGS_FILE="settings.xml"
USE_CACHE=true

# Function to print messages
print_info() {
    echo "[INFO] $1"
}

print_warn() {
    echo "[WARN] $1"
}

print_error() {
    echo "[ERROR] $1"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build the S3Compat API Test Suite container image with Podman.

OPTIONS:
    -s, --settings FILE     Path to Maven settings.xml file (default: settings.xml)
    -n, --name NAME         Image name (default: s3compat-test-suite)
    -t, --tag TAG           Image tag (default: latest)
    --no-cache              Build without using cache
    -h, --help              Display this help message

EXAMPLES:
    # Build with default settings.xml
    $0

    # Build with custom settings file
    $0 -s /path/to/custom-settings.xml

    # Build with custom image name and tag
    $0 -n my-test-suite -t v1.0

    # Build without cache
    $0 --no-cache

PREREQUISITES:
    1. Podman must be installed
    2. settings.xml must exist with GitHub credentials
    3. Run from the project root directory

EOF
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--settings)
            SETTINGS_FILE="$2"
            shift 2
            ;;
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --no-cache)
            USE_CACHE=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate prerequisites
print_info "Validating prerequisites..."

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    print_error "Podman is not installed. Please install Podman first."
    exit 1
fi

# Check if Dockerfile exists
if [ ! -f "Dockerfile" ]; then
    print_error "Dockerfile not found. Please run this script from the project root directory."
    exit 1
fi

# Check if settings.xml exists
if [ ! -f "$SETTINGS_FILE" ]; then
    print_error "Settings file not found: $SETTINGS_FILE"
    print_info "Please create settings.xml from settings.xml.template and add your GitHub credentials."
    print_info "See README.md for detailed instructions."
    exit 1
fi

# Validate settings.xml contains required information
if grep -q "YOUR_GITHUB_USERNAME\|YOUR_GITHUB_PAT" "$SETTINGS_FILE"; then
    print_error "Settings file contains placeholder values."
    print_info "Please replace YOUR_GITHUB_USERNAME and YOUR_GITHUB_PAT with actual values."
    exit 1
fi

print_info "Prerequisites validated successfully."

# Build the image
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
print_info "Building image: $FULL_IMAGE_NAME"
print_info "Using settings file: $SETTINGS_FILE"

# Prepare build command
BUILD_CMD="podman build"

if [ "$USE_CACHE" = false ]; then
    BUILD_CMD="$BUILD_CMD --no-cache"
fi

# Add secret for settings.xml
BUILD_CMD="$BUILD_CMD --secret id=maven_settings,src=$SETTINGS_FILE"

# Add image name and tag
BUILD_CMD="$BUILD_CMD -t $FULL_IMAGE_NAME"

# Add current directory as build context
BUILD_CMD="$BUILD_CMD ."

print_info "Executing: $BUILD_CMD"
echo ""

# Execute build
if eval $BUILD_CMD; then
    echo ""
    print_info "✓ Build completed successfully!"
    print_info "Image: $FULL_IMAGE_NAME"
    echo ""
    print_info "Next steps:"
    print_info "  1. Create .env file from .env.example with your test credentials"
    print_info "  2. Run tests using: ./run-tests-podman.sh"
    print_info "  3. Or use podman-compose up"
    echo ""
else
    echo ""
    print_error "✗ Build failed!"
    print_info "Check the error messages above for details."
    exit 1
fi

# Display image information
print_info "Image details:"
podman images "$FULL_IMAGE_NAME" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.Created}}"