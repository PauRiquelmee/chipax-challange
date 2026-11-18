#!/usr/bin/env bash
# Builds the console, syncs it to the front bucket and invalidates CloudFront.
# Usage: bash core/infra/scripts/deploy-front.sh   (reads stack outputs, no secrets involved)
set -euo pipefail
cd "$(dirname "$0")/../../.."
set -a; . core/infra/.env; set +a
export AWS_PAGER=""
out() { aws cloudformation describe-stacks --stack-name ChipaxChallengeApp \
  --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }
npm --prefix console run build
aws s3 sync console/dist "s3://$(out FrontBucketName)" --delete
aws cloudfront create-invalidation --distribution-id "$(out DistributionId)" --paths '/*' \
  --query Invalidation.Status --output text
