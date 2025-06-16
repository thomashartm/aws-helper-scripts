#!/bin/bash
set -euo pipefail

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
# you get all this info from your task definition
REGION="eu-central-1"
CLUSTER_NAME=$1 # Your ECS cluster e.g. my-cluster-name
TASK_FAMILY=$2 # Task Definition family (no “:revision”)
RULE_NAME=$3 # EventBridge rule that normally fires this task
# ────────────────────────────────────────────────────────────────────────────────

# fail if any of the params are not provided
if [[ -z "$CLUSTER_NAME" || -z "$TASK_FAMILY" || -z "$RULE_NAME" ]]; then
  echo "Usage: $0 <cluster_name> <task_family> <rule_name>" >&2
  exit 1
fi

# 1) fetch the first (and only) target with EcsParameters from the rule
TARGET_JSON=$(aws events list-targets-by-rule \
  --region "$REGION" \
  --rule "$RULE_NAME" \
  --output json)

if [[ $TARGET_JSON == "null" ]]; then
  echo "No ECS target found on rule $RULE_NAME" >&2
  exit 1
fi
# 2) extract the target ARN
TARGET=$(jq -r '.Targets[0]' <<<"$TARGET_JSON")

# 2) extract subnets, securityGroups, assignPublicIp
DATA_JSON=$(jq -c '.EcsParameters.NetworkConfiguration' <<<"$TARGET")
SUBNETS_JSON=$(jq -c '.EcsParameters.NetworkConfiguration.awsvpcConfiguration.Subnets' <<<"$TARGET")
SGS_JSON=$(jq -c '.EcsParameters.NetworkConfiguration.awsvpcConfiguration.SecurityGroups' <<<"$TARGET")
ASSIGN_IP=$(jq -r '.EcsParameters.NetworkConfiguration.awsvpcConfiguration.AssignPublicIp' <<<"$TARGET")

echo "Target DATA JSON: $DATA_JSON"
echo "Subnets: $SUBNETS_JSON"
echo "Security Groups: $SGS_JSON"
echo "Assign Public IP: $ASSIGN_IP"

# 3) build the --network-configuration payload
NETWORK_CONFIG=$(jq -n \
  --argjson subnets "$SUBNETS_JSON" \
  --argjson sgs    "$SGS_JSON" \
  --arg publicip   "$ASSIGN_IP" \
  '{ awsvpcConfiguration: {
       subnets: $subnets,
       securityGroups: $sgs,
       assignPublicIp: $publicip
  }}'
)

echo "Network Configuration: $NETWORK_CONFIG"

# 4) run the ECS task with the extracted parameters
aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --launch-type FARGATE \
  --task-definition $TASK_FAMILY \
  --network-configuration "$NETWORK_CONFIG"
