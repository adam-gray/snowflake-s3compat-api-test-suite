# Multi-stage Dockerfile for Snowflake S3Compat API Test Suite
# Stage 1: Build stage with Maven
FROM maven:3.8-openjdk-11 AS builder

# Set working directory
WORKDIR /build

# Copy Maven settings.xml if provided via build secret
# This will be mounted during build time only
RUN mkdir -p /root/.m2

# Copy project files
COPY pom.xml .
COPY s3compatapi/ ./s3compatapi/
COPY spf4jui/ ./spf4jui/

# Build argument to control whether to use custom settings
ARG USE_CUSTOM_SETTINGS=false

# Download dependencies and build (skip tests during build)
# The settings.xml will be mounted as a secret during build
RUN --mount=type=secret,id=maven_settings,target=/root/.m2/settings.xml \
    if [ -f /root/.m2/settings.xml ]; then \
        echo "Using custom Maven settings.xml"; \
        mvn clean install -DskipTests; \
    else \
        echo "Using default Maven settings"; \
        mvn clean install -DskipTests; \
    fi

# Stage 2: Runtime stage with JDK (needed for Maven compilation during tests)
# Using Eclipse Temurin (successor to AdoptOpenJDK) - actively maintained
# Supports multiple architectures including ARM64 (Apple Silicon) and AMD64
# Note: Using JDK instead of JRE because Maven needs to compile test classes at runtime
FROM eclipse-temurin:11-jdk

# Install Maven in runtime stage (needed for running tests)
RUN apt-get update && \
    apt-get install -y maven && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy built artifacts from builder stage
COPY --from=builder /build/s3compatapi/target ./s3compatapi/target
COPY --from=builder /build/spf4jui/target ./spf4jui/target
COPY --from=builder /build/s3compatapi/pom.xml ./s3compatapi/
COPY --from=builder /build/spf4jui/pom.xml ./spf4jui/
COPY --from=builder /build/pom.xml .

# Copy source files needed for tests
COPY --from=builder /build/s3compatapi/src ./s3compatapi/src

# Copy Maven repository from builder (contains all dependencies)
COPY --from=builder /root/.m2/repository /root/.m2/repository

# Set environment variables for Maven
ENV MAVEN_OPTS="-Xmx1024m"

# Default working directory for test execution
WORKDIR /app/s3compatapi

# Default command runs all tests
# Can be overridden at runtime to run specific tests
CMD ["mvn", "test", "-Dtest=S3CompatApiTest"]

# Labels for metadata
LABEL maintainer="Snowflake S3Compat API Test Suite"
LABEL description="Container for running Snowflake S3Compat API tests"
LABEL version="1.0"