# Snowflake S3Compat API Test Suite

This test suite tests necessary S3-compatible APIs and measures simple performance stats.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running Tests](#running-tests)
- [Using Podman Containers](#using-podman-containers)
- [Logging Configuration](#logging-configuration)
- [Performance Stats](#performance-stats)
- [API List](#api-list)
- [Troubleshooting](#troubleshooting)
- [Support](#support)

## Prerequisites

- **Java 1.8 or higher**
- **Maven** (for building from source)
- **Podman** (optional, for containerized testing): https://podman.io/getting-started/installation

## Installation

### Build from Source Code

1. Checkout source code from Github:
```bash
git clone git@github.com:snowflakedb/snowflake-s3compat-api-test-suite.git
cd snowflake-s3compat-api-test-suite
```

2. Configure GitHub Package Access

   The dependency `spf4j-ui` used in this repo has a fork build that requires authorized access from GitHub Packages. See [GitHub Maven registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-apache-maven-registry).

   Add the following block to your `~/.m2/settings.xml` file. A scoped "read:packages" token is sufficient:

```xml
<server>
  <id>github</id>
  <username>your github username</username>
  <password>your github access token</password>
</server>
```

3. Build the test suite:
```bash
mvn clean install -DskipTests
```

## Configuration

### Environment Variables

The following environment variables are required for running tests:

| Variable | Description |
|----------|-------------|
| `BUCKET_NAME_1` | The bucket name for testing, located at REGION_1, expect versioning enabled |
| `REGION_1` | Region for the above bucket, like us-east-1 |
| `REGION_2` | Region that is different than REGION_1, like us-west-2 |
| `S3COMPAT_ACCESS_KEY` | Access key used to access the above bucket |
| `S3COMPAT_SECRET_KEY` | Secret key used to access the above bucket |
| `END_POINT` | Endpoint that can route operations to the provided bucket |
| `NOT_ACCESSIBLE_BUCKET` | A bucket that is not accessible by the provided keys, at REGION_1 |
| `PREFIX_FOR_PAGE_LISTING` | The prefix for testing listing large num of objects, at BUCKET_NAME_1, needs over 1000 objects |
| `PAGE_LISTING_TOTAL_SIZE` | The total size of objects on the above prefix: PREFIX_FOR_PAGE_LISTING |

Example to set environment variables:
```bash
export REGION_1=<region_1_for_bucket_1>
export BUCKET_NAME_1=<your_bucket_name>
# ... set other variables
```

The test suite accepts environment variables or CLI arguments.

## Running Tests

Navigate to the target folder:
```bash
cd s3compatapi
```

### Test Specific APIs

Test a specific API, e.g., test getBucketLocation:
```bash
mvn test -Dtest=S3CompatApiTest#getBucketLocation
```

### Test All APIs

Test all APIs using already setup environment variables:
```bash
mvn test -Dtest=S3CompatApiTest
```

**Note:** Running all tests may take more than 2 minutes as one putObject test uploads files up to 5GB.

### Test Using CLI Variables

If environment variables are not set up yet:
```bash
mvn test -Dtest=S3CompatApiTest -DREGION_1=us-east-1 -DREGION_2=us-west-2 -D...
mvn test -Dtest=S3CompatApiTest#getObject -DREGION_1=us-east-1 -DREGION_2=us-west-2 -D...
```

## Using Podman Containers

Podman provides an isolated, reproducible environment for running tests.

### Quick Start with Podman

#### 1. Create GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Name: `Maven GitHub Packages`
4. Select scope: `read:packages`
5. Click "Generate token"
6. Copy the token immediately

#### 2. Configure Maven Settings

```bash
# Copy the template
cp settings.xml.template settings.xml

# Edit settings.xml and replace placeholders
# YOUR_GITHUB_USERNAME → your GitHub username
# YOUR_GITHUB_PAT → the token you just created
```

#### 3. Configure Test Environment

```bash
# Copy the example file
cp .env.example .env

# Edit .env and fill in all required values
```

**Important Requirements:**
- `BUCKET_NAME_1` must have versioning enabled
- `PREFIX_FOR_PAGE_LISTING` must contain over 1000 objects
- `PAGE_LISTING_TOTAL_SIZE` must match the actual count

**Security Note:** Never commit `.env` or `settings.xml` to version control. They're already in `.gitignore`.

#### 4. Build the Container Image

```bash
# Make scripts executable
chmod +x build-podman.sh run-tests-podman.sh

# Build the image
./build-podman.sh
```

Build script options:
```bash
# Build with custom settings file
./build-podman.sh -s /path/to/custom-settings.xml

# Build with custom image name and tag
./build-podman.sh -n my-test-suite -t v1.0

# Build without cache (clean build)
./build-podman.sh --no-cache
```

#### 5. Run Tests in Container

```bash
# Run all tests
./run-tests-podman.sh

# Run specific test method
./run-tests-podman.sh -T S3CompatApiTest#getObject

# Run multiple specific tests
./run-tests-podman.sh -T "S3CompatApiTest#getObject+S3CompatApiTest#putObject"

# Run tests matching pattern
./run-tests-podman.sh -T "*ApiTest"

# Interactive mode (for debugging)
./run-tests-podman.sh -i

# Keep container after tests
./run-tests-podman.sh --no-remove
```

### Using Podman Directly

```bash
# Run all tests
podman run --rm \
  --env-file .env \
  -v maven-cache:/root/.m2/repository \
  -v $(pwd)/test-results:/app/s3compatapi/target/surefire-reports:z \
  s3compat-test-suite:latest

# Run specific test
podman run --rm \
  --env-file .env \
  -v maven-cache:/root/.m2/repository \
  s3compat-test-suite:latest \
  mvn test -Dtest=S3CompatApiTest#getObject
```

### Using Podman Compose

Podman Compose provides a simpler way to manage the build and run process.

```bash
# Build
podman-compose build

# Run all tests
podman-compose up

# Run specific tests
podman-compose run --rm tests mvn test -Dtest=S3CompatApiTest#getObject

# Interactive shell
podman-compose run --rm tests /bin/bash

# Clean up
podman-compose down -v
```

### Test Results

Test results are automatically saved to the `test-results/` directory:

```bash
# View test results
ls -la test-results/

# View specific test report
cat test-results/TEST-com.snowflake.s3compatapitestsuite.compatapi.S3CompatApiTest.xml
```

### Maven Cache Volume

The setup uses a persistent Maven cache volume to speed up subsequent builds and test runs.

```bash
# List volumes
podman volume ls

# Inspect Maven cache volume
podman volume inspect maven-cache

# Clear cache (if needed)
podman volume rm maven-cache
```

## Logging Configuration

The test suite uses Log4j for logging via the SLF4J bridge. Logs are written to both console (stdout) and log files.

### Log File Location

- **On Host**: `./logs/s3compat-tests.log` (in project root)
- **In Container**: `/app/logs/s3compat-tests.log`

### Log File Rotation

- **Max File Size**: 10MB per file
- **Max Backup Files**: 5 files
- **Total Storage**: Up to 50MB of logs (current + 5 backups)
- **Naming**: `s3compat-tests.log`, `s3compat-tests.log.1`, `s3compat-tests.log.2`, etc.

### Viewing Logs

```bash
# Real-time monitoring
tail -f logs/s3compat-tests.log

# View current log file
cat logs/s3compat-tests.log

# Search for errors
grep ERROR logs/s3compat-tests.log

# View older rotated logs
cat logs/s3compat-tests.log.1
```

### Customizing Log Levels

Edit `log4j.properties` to change logging behavior:

```properties
# Set root logger to DEBUG for more verbose output
log4j.rootLogger=DEBUG, stdout, file

# Set AWS SDK to DEBUG to see all AWS API calls
log4j.logger.com.amazonaws=DEBUG

# Set test suite to DEBUG for detailed test information
log4j.logger.com.snowflake.s3compatapitestsuite=DEBUG
```

Available log levels (most to least verbose):
- `DEBUG` - Detailed debugging information
- `INFO` - Informational messages (default)
- `WARN` - Warning messages
- `ERROR` - Error messages only
- `FATAL` - Fatal errors only

### Common Logging Scenarios

**Minimal Output (Errors Only)**:
```properties
log4j.rootLogger=ERROR, stdout, file
log4j.logger.com.amazonaws=ERROR
log4j.logger.com.snowflake.s3compatapitestsuite=ERROR
```

**Verbose AWS Debugging**:
```properties
log4j.rootLogger=INFO, stdout, file
log4j.logger.com.amazonaws=DEBUG
log4j.logger.org.apache.http.wire=DEBUG
```

**Test Suite Debugging**:
```properties
log4j.rootLogger=INFO, stdout, file
log4j.logger.com.amazonaws=WARN
log4j.logger.com.snowflake.s3compatapitestsuite=DEBUG
```

Changes to `log4j.properties` take effect immediately on the next container run—no rebuild required!

## Performance Stats

### Collect Performance Stats

Collect perf stats by default (all APIs run 20 times):
```bash
java -jar target/snowflake-s3compat-api-tests-1.0-SNAPSHOT.jar
```

Collect perf stats by passing arguments:
```bash
# -a: list of APIs separated by comma; -t: how many times to run the APIs
java -jar target/snowflake-s3compat-api-tests-1.0-SNAPSHOT.jar -a getObject,putObject -t 10
```

### Visualize Performance Stats

Use the UI to open the generated `.tsdb2` file:
```bash
java -jar ../spf4jui/target/dependency-jars/spf4j-ui-8.9.5.jar
```

Open the `.tsdb2` file, choose one of the API data generated, click Plot to see the charts.

Perf data is generated and stored in `.tsdb2` as binary and also in `.txt` file for other processing if necessary.

## API List

Below is the list of S3-compatible APIs tested in this repo:

- `getBucketLocation`
- `getObject` (includes read with content range)
- `getObjectMetadata`
- `putObject`
- `listObjectsV2`
- `deleteObject`
- `deleteObjects`
- `copyObject`
- `generatePresignedUrl`

## Troubleshooting

### Common Test Failures

#### 1. getBucketLocation Tests Fail

We call `getObjectMetadata()` for header "x-amz-bucket-region" to retrieve the region for a bucket, because the region is required for SigV4. If you confirm that your service ignores the bucket location (region) in the SigV4 from the request, then you can ignore the test failures for getBucketLocation. If your service requires SigV4, then your service should support `getObjectMetadata()` responded with "x-amz-bucket-region" header OR support `getBucketLocation()`.

#### 2. Negative Tests Fail

For some negative test cases, AWS S3 returns 404 or 403, while your APIs return 400 or other error codes, so your test fails as the error code is different from what the test case expects. This should be fine as long as your APIs return reasonable error codes and messages for those negative cases.

#### 3. Content Range Response Header

If a file size is 100, and we read the file with range between 10 and 19 (inclusive), an S3 expected get object with range response should have Content-Range header, and the format should be like "bytes 10-19/100". The last part should be 100 (the full file size) instead of part of the file size. If your service does not support this header, the test will fail. Please make sure your service supports this header with correct format.

#### 4. SSL Certificate Validation

After you finish the tests, please verify your endpoint has a valid SSL certificate. Construct a host style URL in this format: `https://<your_bucket>.<your_endpoint>`, and then paste it in your browser, click the padlock icon in the address bar (left side), then click Connection or Certificate.

If you have a valid SSL certificate, you should see something indicating "Certificate is valid".

![Valid SSL](s3compatapi/src/main/resources/validSSL.png)

If you do not have a valid SSL certificate, you will see something like "This site can't be reached" or "Your connection to this site is not secure".

![Invalid SSL](s3compatapi/src/main/resources/invalidSSL.png)

Please make sure you have a valid SSL cert for your endpoint before you run any queries on Snowflake platform.

### Podman/Container Issues

#### Build Fails with "Settings file contains placeholder values"

Edit `settings.xml` and replace `YOUR_GITHUB_USERNAME` and `YOUR_GITHUB_PAT` with your actual credentials.

#### Build Fails with GitHub Authentication Error

Verify your PAT has `read:packages` scope:
```bash
curl -H "Authorization: token YOUR_PAT" https://api.github.com/user
```

If that fails, regenerate your PAT with the correct scope.

#### "Missing or empty required environment variables"

Check which variables are empty:
```bash
grep "^[A-Z_]*=$" .env
```

Fill in all empty variables in the `.env` file.

#### Permission Denied on test-results Directory

```bash
# Fix permissions
chmod 777 test-results

# Or create it first
mkdir -p test-results
chmod 755 test-results
```

#### Maven Cache Not Persisting

```bash
# Verify volume exists
podman volume ls | grep maven-cache

# If not, create it
podman volume create maven-cache
```

### Logging Issues

#### Logs Not Being Written to File

Check that:
1. The `logs/` directory exists on the host
2. The directory has write permissions: `chmod 755 logs/`
3. The file appender is included in the root logger in `log4j.properties`

#### Too Much Output

Reduce verbosity by increasing log levels in `log4j.properties`:
```properties
log4j.rootLogger=WARN, stdout, file
log4j.logger.com.amazonaws=ERROR
```

## Public Documentation

If all of your APIs pass the tests in this repo, please refer to our public documentation about using this feature on Snowflake deployments:

- [Working With Amazon S3-compatible Storage](https://docs.snowflake.com/en/user-guide/data-load-s3-compatible-storage)
- [Using On-Premises Data in Place with Snowflake](https://www.snowflake.com/blog/external-tables-on-prem/)

## Support

Feel free to file an issue or submit a PR here for general cases. For official support, contact Snowflake support at: https://community.snowflake.com/s/article/How-To-Submit-a-Support-Case-in-Snowflake-Lodge
