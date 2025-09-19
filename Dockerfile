FROM maven:3-eclipse-temurin-21-jammy as test
RUN useradd --create-home s3tester
USER s3tester
RUN mkdir /home/s3tester/snowflake-s3compat-api-test-suite
WORKDIR /home/s3tester/snowflake-s3compat-api-test-suite
COPY . .

ENV TEST_ARGS=""

ENTRYPOINT ["/home/s3tester/snowflake-s3compat-api-test-suite/entrypoint.sh"]