#!/bin/bash

# Run script for Snowflake S3Compat API Test Suite with Podman
# This script runs tests in a container with environment variables from .env file

set -e  # Exit on error

# Default values
IMAGE_NAME="s3compat-test-suite"
IMAGE_TAG="latest"
ENV_FILE=".env"
CONTAINER_NAME="s3compat-tests-$(date +%s)"
MAVEN_CACHE_VOLUME="maven-cache"
TEST_SPEC=""
INTERACTIVE=false
REMOVE_CONTAINER=true

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

print_debug() {
    echo "[DEBUG] $1"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run the S3Compat API Test Suite in a Podman container.

OPTIONS:
    -e, --env-file FILE     Path to .env file (default: .env)
    -n, --name NAME         Image name (default: s3compat-test-suite)
    -t, --tag TAG           Image tag (default: latest)
    -c, --container NAME    Container name (default: auto-generated)
    -T, --test SPEC         Maven test specification (see examples below)
    -i, --interactive       Run in interactive mode (keep container running)
    --no-remove             Don't remove container after tests complete
    -h, --help              Display this help message

TEST SPECIFICATION (-T, --test):
    Run all tests (default):
        (no -T option)
    
    Run specific test class:
        -T S3CompatApiTest
    
    Run specific test method:
        -T S3CompatApiTest#getObject
    
    Run multiple specific methods:
        -T S3CompatApiTest#getObject+S3CompatApiTest#putObject
    
    Run tests matching pattern:
        -T "*ApiTest"

EXAMPLES:
    # Run all tests with default .env file
    $0

    # Run specific test method
    $0 -T S3CompatApiTest#getObject

    # Run multiple specific tests
    $0 -T S3CompatApiTest#getObject+S3CompatApiTest#putObject

    # Run with custom env file
    $0 -e /path/to/custom.env

    # Run in interactive mode (for debugging)
    $0 -i

    # Keep container after tests (for inspection)
    $0 --no-remove

PREREQUISITES:
    1. Image must be built first (run build-podman.sh)
    2. .env file must exist with test credentials
    3. Podman must be installed

ENVIRONMENT VARIABLES:
    The following variables must be set in your .env file:
    - BUCKET_NAME_1
    - REGION_1
    - REGION_2
    - S3COMPAT_ACCESS_KEY
    - S3COMPAT_SECRET_KEY
    - END_POINT
    - NOT_ACCESSIBLE_BUCKET
    - PREFIX_FOR_PAGE_LISTING
    - PAGE_LISTING_TOTAL_SIZE

EOF
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env-file)
            ENV_FILE="$2"
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
        -c|--container)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -T|--test)
            TEST_SPEC="$2"
            shift 2
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        --no-remove)
            REMOVE_CONTAINER=false
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

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    print_error "Environment file not found: $ENV_FILE"
    print_info "Please create .env from .env.example and fill in your test credentials."
    print_info "See README.md for detailed instructions."
    exit 1
fi

# Validate .env file has required variables
REQUIRED_VARS=("BUCKET_NAME_1" "REGION_1" "REGION_2" "S3COMPAT_ACCESS_KEY" "S3COMPAT_SECRET_KEY" "END_POINT" "NOT_ACCESSIBLE_BUCKET" "PREFIX_FOR_PAGE_LISTING" "PAGE_LISTING_TOTAL_SIZE")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if ! grep -q "^${var}=" "$ENV_FILE" || grep -q "^${var}=$" "$ENV_FILE"; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    print_error "Missing or empty required environment variables in $ENV_FILE:"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    print_info "Please fill in all required variables in your .env file."
    exit 1
fi

# Check if image exists
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
if ! podman image exists "$FULL_IMAGE_NAME"; then
    print_error "Image not found: $FULL_IMAGE_NAME"
    print_info "Please build the image first using: ./build-podman.sh"
    exit 1
fi

print_info "Prerequisites validated successfully."

# Create Maven cache volume if it doesn't exist
if ! podman volume exists "$MAVEN_CACHE_VOLUME" 2>/dev/null; then
    print_info "Creating Maven cache volume: $MAVEN_CACHE_VOLUME"
    podman volume create "$MAVEN_CACHE_VOLUME"
fi

# Prepare run command
print_info "Preparing to run tests..."
print_info "Image: $FULL_IMAGE_NAME"
print_info "Container: $CONTAINER_NAME"
print_info "Environment file: $ENV_FILE"

RUN_CMD="podman run"

# Add container name
RUN_CMD="$RUN_CMD --name $CONTAINER_NAME"

# Add remove flag if specified
if [ "$REMOVE_CONTAINER" = true ] && [ "$INTERACTIVE" = false ]; then
    RUN_CMD="$RUN_CMD --rm"
fi

# Add environment file
RUN_CMD="$RUN_CMD --env-file $ENV_FILE"

# Add Maven cache volume
RUN_CMD="$RUN_CMD -v $MAVEN_CACHE_VOLUME:/root/.m2/repository"

# Add test results volume (mount current directory for output)
RUN_CMD="$RUN_CMD -v $(pwd)/test-results:/app/s3compatapi/target/surefire-reports:Z"

# Add logs volume (mount for log file output)
RUN_CMD="$RUN_CMD -v $(pwd)/logs:/app/logs:Z"
print_info "Mounting logs directory for log file output"

# Add log4j.properties volume (mount for runtime configuration)
if [ -f "log4j.properties" ]; then
    RUN_CMD="$RUN_CMD -v $(pwd)/log4j.properties:/app/s3compatapi/src/main/resources/log4j.properties:Z"
    print_info "Mounting log4j.properties for runtime logging configuration"
fi

# Add interactive mode if specified
if [ "$INTERACTIVE" = true ]; then
    RUN_CMD="$RUN_CMD -it"
    RUN_CMD="$RUN_CMD --entrypoint /bin/bash"
    print_info "Running in interactive mode. Type 'exit' to quit."
else
    # Add test specification if provided
    if [ -n "$TEST_SPEC" ]; then
        print_info "Test specification: $TEST_SPEC"
        RUN_CMD="$RUN_CMD $FULL_IMAGE_NAME mvn test -Dtest=$TEST_SPEC"
    else
        print_info "Running all tests"
        RUN_CMD="$RUN_CMD $FULL_IMAGE_NAME"
    fi
fi

# Add image name for interactive mode
if [ "$INTERACTIVE" = true ]; then
    RUN_CMD="$RUN_CMD $FULL_IMAGE_NAME"
fi

print_debug "Command: $RUN_CMD"
echo ""

# Create test-results directory if it doesn't exist
mkdir -p test-results

# Execute tests
print_info "Starting tests..."
echo ""
echo "========================================================================"

if eval $RUN_CMD; then
    EXIT_CODE=0
    echo "========================================================================"
    echo ""
    print_info "✓ Tests completed successfully!"
    
    if [ "$INTERACTIVE" = false ]; then
        print_info "Test results saved to: $(pwd)/test-results"
    fi
else
    EXIT_CODE=$?
    echo "========================================================================"
    echo ""
    print_error "✗ Tests failed with exit code: $EXIT_CODE"
    
    if [ "$INTERACTIVE" = false ]; then
        print_info "Test results saved to: $(pwd)/test-results"
        print_info "Check the logs above for error details."
    fi
fi

# Cleanup information
if [ "$REMOVE_CONTAINER" = false ] && [ "$INTERACTIVE" = false ]; then
    echo ""
    print_info "Container preserved: $CONTAINER_NAME"
    print_info "To inspect: podman logs $CONTAINER_NAME"
    print_info "To remove: podman rm $CONTAINER_NAME"
fi

echo ""
exit $EXIT_CODE