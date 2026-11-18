#!/usr/bin/env bash
# Creates the chipax-challenge member account inside the woku AWS Organization and gives
# Paula's existing IAM user (woku account) admin access to it through a role. No new keys.
#
# Run by whoever administers the woku organization (Diego), once:
#   bash core/infra/scripts/account-setup.sh <unique-root-email>
#   e.g. bash core/infra/scripts/account-setup.sh aws+chipax-challenge@woku.app
#
# Profiles (override with env vars if yours are named differently):
#   MGMT_PROFILE  organization management account   (default: default)
#   WOKU_PROFILE  account where IAM user "paula" lives (default: default)
# Idempotent: re-running skips what already exists.
set -euo pipefail

ACCOUNT_EMAIL="${1:?usage: account-setup.sh <unique-root-email>}"
ACCOUNT_NAME="chipax-challenge"
ROLE_NAME="ChipaxChallengeAdmin"
MGMT_PROFILE="${MGMT_PROFILE:-default}"
WOKU_PROFILE="${WOKU_PROFILE:-default}"
WOKU_ACCOUNT_ID="893061506665"
PAULA_ARN="arn:aws:iam::${WOKU_ACCOUNT_ID}:user/paula"
DIEGO_ARN="arn:aws:iam::${WOKU_ACCOUNT_ID}:user/diego"
REGION="us-east-1"

# The repo's Claude Code settings export AWS_PROFILE=chipax-challenge; ignore it here.
unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
export AWS_PAGER=""

echo "0/4 Preflight: ${MGMT_PROFILE} must be the organization management account"
CALLER_ACCOUNT=$(aws sts get-caller-identity --profile "$MGMT_PROFILE" --query Account --output text)
MASTER_ACCOUNT=$(aws organizations describe-organization --profile "$MGMT_PROFILE" \
  --query Organization.MasterAccountId --output text)
if [ "$CALLER_ACCOUNT" != "$MASTER_ACCOUNT" ]; then
  echo "Profile '${MGMT_PROFILE}' is account ${CALLER_ACCOUNT}, but the management account is ${MASTER_ACCOUNT}." >&2
  echo "Re-run with MGMT_PROFILE=<profile of ${MASTER_ACCOUNT}>. Nothing was created." >&2
  exit 1
fi
echo "   ok: ${CALLER_ACCOUNT} is the management account"

echo "1/4 Organization account '${ACCOUNT_NAME}'"
ACCOUNT_ID=$(aws organizations list-accounts --profile "$MGMT_PROFILE" \
  --query "Accounts[?Name=='${ACCOUNT_NAME}' && Status=='ACTIVE'].Id | [0]" --output text)
if [ "$ACCOUNT_ID" = "None" ] || [ -z "$ACCOUNT_ID" ]; then
  REQUEST_ID=$(aws organizations create-account --profile "$MGMT_PROFILE" \
    --email "$ACCOUNT_EMAIL" --account-name "$ACCOUNT_NAME" \
    --tags Key=project,Value=chipax-challenge \
    --query CreateAccountStatus.Id --output text)
  while :; do
    read -r STATE ACCOUNT_ID REASON < <(aws organizations describe-create-account-status \
      --profile "$MGMT_PROFILE" --create-account-request-id "$REQUEST_ID" \
      --query 'CreateAccountStatus.[State,AccountId,FailureReason]' --output text)
    case "$STATE" in
      SUCCEEDED) break ;;
      FAILED) echo "Account creation failed: $REASON" >&2; exit 1 ;;
      *) echo "   ...$STATE"; sleep 10 ;;
    esac
  done
fi
echo "   account id: $ACCOUNT_ID"

echo "2/4 Admin role '${ROLE_NAME}' in the new account (trusts paula and diego)"
CREDS=$(aws sts assume-role --profile "$MGMT_PROFILE" \
  --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
  --role-session-name chipax-challenge-setup --query Credentials --output json)
AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r .AccessKeyId)
AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r .SecretAccessKey)
AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r .SessionToken)
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

TRUST=$(jq -n --arg p "$PAULA_ARN" --arg d "$DIEGO_ARN" '{
  Version: "2012-10-17",
  Statement: [{ Effect: "Allow", Principal: { AWS: [$p, $d] }, Action: "sts:AssumeRole" }]
}')
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "$TRUST"
else
  aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document "$TRUST" \
    --max-session-duration 43200 --description "Admin for the Chipax challenge (Paula + agent)" \
    --tags Key=project,Value=chipax-challenge >/dev/null
fi
aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
aws iam create-account-alias --account-alias chipax-challenge-woku 2>/dev/null || true
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

echo "3/4 Allow user paula (woku account) to assume only that role"
# Managed policy, not inline: a user's inline policies share a 2048-byte quota and paula's is full.
POLICY=$(jq -n --arg r "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}" '{
  Version: "2012-10-17",
  Statement: [{ Sid: "AssumeChipaxChallengeAdmin", Effect: "Allow", Action: "sts:AssumeRole", Resource: $r }]
}')
POLICY_ARN="arn:aws:iam::${WOKU_ACCOUNT_ID}:policy/assume-chipax-challenge-admin"
if ! aws iam get-policy --profile "$WOKU_PROFILE" --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
  aws iam create-policy --profile "$WOKU_PROFILE" --policy-name assume-chipax-challenge-admin \
    --description "Paula: assume ChipaxChallengeAdmin in the chipax-challenge account" \
    --policy-document "$POLICY" >/dev/null
fi
aws iam attach-user-policy --profile "$WOKU_PROFILE" --user-name paula --policy-arn "$POLICY_ARN"

echo "4/4 Done. Paula adds this to ~/.aws/config (source_profile = her current profile):"
cat <<EOF

[profile chipax-challenge]
source_profile = woku-cdn
role_arn = arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}
role_session_name = paula-chipax-challenge
duration_seconds = 43200
region = ${REGION}

Check:  aws sts get-caller-identity --profile chipax-challenge
Then set AWS_ACCOUNT_ID=${ACCOUNT_ID} in core/infra/.env
EOF
