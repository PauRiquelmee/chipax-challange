#!/usr/bin/env bash
# Creates or updates the CNAME DOMAIN -> CloudFront in Cloudflare (DNS only, no proxy).
# Only touches the record named exactly $DOMAIN. Never prints the token.
set -euo pipefail
cd "$(dirname "$0")/../../.."
set -a; . core/infra/.env; set +a
export AWS_PAGER=""
# Token lookup order: core/infra/.env, repo-root .env, SSM backup.
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ] && [ -f .env ]; then set -a; . ./.env; set +a; fi
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  CLOUDFLARE_API_TOKEN=$(aws ssm get-parameter --name "$SSM_PREFIX/CLOUDFLARE_API_TOKEN" \
    --with-decryption --query Parameter.Value --output text)
fi
CF_DOMAIN=$(aws cloudformation describe-stacks --stack-name ChipaxChallengeApp \
  --query "Stacks[0].Outputs[?OutputKey=='CloudFrontDomain'].OutputValue" --output text)
API="https://api.cloudflare.com/client/v4"
H="Authorization: Bearer $CLOUDFLARE_API_TOKEN"
ZONE=$(curl -s -H "$H" "$API/zones?name=$CLOUDFLARE_ZONE_NAME" | jq -r '.result[0].id')
EXISTING=$(curl -s -H "$H" "$API/zones/$ZONE/dns_records?name=$DOMAIN" | jq -r '.result[0] | "\(.id) \(.type)"')
BODY=$(jq -n --arg n "$DOMAIN" --arg c "$CF_DOMAIN" \
  '{type:"CNAME",name:$n,content:$c,ttl:300,proxied:false,comment:"chipax-challenge"}')
case "$EXISTING" in
  "null null") curl -s -X POST -H "$H" -H "Content-Type: application/json" "$API/zones/$ZONE/dns_records" --data "$BODY" | jq '{success,errors}' ;;
  *" CNAME") curl -s -X PUT -H "$H" -H "Content-Type: application/json" "$API/zones/$ZONE/dns_records/${EXISTING% *}" --data "$BODY" | jq '{success,errors}' ;;
  *) echo "Record $DOMAIN exists with a different type ($EXISTING); not touching it." >&2; exit 1 ;;
esac
