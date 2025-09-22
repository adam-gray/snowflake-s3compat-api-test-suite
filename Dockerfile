FROM maven:3-eclipse-temurin-21-jammy as test
RUN mkdir -p /root/snowflake-s3compat-api-test-suite
WORKDIR /root/snowflake-s3compat-api-test-suite
COPY . .
RUN mvn -s /root/snowflake-s3compat-api-test-suite/settings.xml -f /root/snowflake-s3compat-api-test-suite/pom.xml dependency:go-offline
ENV TEST_ARGS=""

ENTRYPOINT ["/root/snowflake-s3compat-api-test-suite/entrypoint.sh"]