#/bin/sh

NAME=$1 
IMAGE=$2
ENV_PATH=$3
LOG4J_PATH=$4

echo "Running snowflake s3compat-api-test $NAME"
echo "Logs available via: podman cp $name:/root/snowflake-s3compat-api-test-suite/test.log ."
exec podman run --name $NAME -v $LOG4J_PATH:/log4j.properties --env-file=$ENV_PATH $IMAGE 