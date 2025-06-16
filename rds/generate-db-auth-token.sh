#!/usr/bin/env bash
set -e
#set -x

case $1 in
    dev)
        # Set variables for the first case
        secret_id="my-dev-secret-name"
        db_param_id="my-dev-settings-param"
        ;;
    test)
        # Set variables for the second case
        secret_id="my-test-secret-name"
        db_param_id="my-test-settings-param"
        ;;
    *)
        # Default case if the argument doesn't match any of the above
        echo "Invalid argument"
        exit 1
        ;;
esac


get_secrets_json() {
  local parameter_name=$1

  # retrieve the database config from secrets manager and transform the output so that it can be read as a json
  json=$(aws secretsmanager get-secret-value --secret-id $parameter_name | jq -r '.["SecretString"]')
  json=$(echo "$json" | tr -d "'")
  echo $json
}

get_db_connection_json() {
  local parameter_name=$1

  json=$(aws ssm get-parameter --name "$parameter_name" --with-decryption --query 'Parameter.Value' --output text)
  json=$(echo "$json" | tr -d "'")
  echo $json
}

secrets_json=$(get_secrets_json $secret_id)
db_connection_json=$(get_db_connection_json $db_param_id)

DB_USER=$(echo $secrets_json | jq -r '.username')
DB_HOST=$(echo $db_connection_json | jq -r '.proxy_endpoint')
credentials=$(aws rds generate-db-auth-token --hostname $DB_HOST --port 5432 --region eu-central-1 --username $DB_USER)
echo $DB_HOST
echo $credentials
