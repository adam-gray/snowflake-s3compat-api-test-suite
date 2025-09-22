#!/bin/sh

cd s3compatapi/
exec mvn test -Dlog4j.configuration=file:/root/snowflake-s3compat-api-test-suite/log4j.properties $TEST_ARGS
