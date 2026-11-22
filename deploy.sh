#!/usr/bin/env bash
# Usage: ./deploy.sh <stack-suffix> [Env]     e.g.  ./deploy.sh dev     ./deploy.sh defence
set -euo pipefail

SUFFIX="${1:?usage: ./deploy.sh <stack-suffix> [dev|prod]}"
ENVIRONMENT="${2:-dev}"
REGION=us-east-1
BASE="orders-base-$SUFFIX"
APP="orders-app-$SUFFIX"
TAG=$(git rev-parse --short HEAD)

out() {
  aws cloudformation describe-stacks --stack-name "$1" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue" --output text
}

echo "== 1/4 lint"
cfn-lint base.yaml app.yaml

echo "== 2/4 base stack: $BASE"
aws cloudformation deploy --stack-name "$BASE" --template-file base.yaml \
  --capabilities CAPABILITY_IAM --region "$REGION" \
  --parameter-overrides Env="$ENVIRONMENT"

echo "== 3/4 image $TAG"
REPO=$(out "$BASE" RepoUri)
if aws ecr describe-images --repository-name "${REPO#*/}" --image-ids imageTag="$TAG" \
     --region "$REGION" >/dev/null 2>&1; then
  echo "image $TAG already in ECR, skipping push"
else
  aws ecr get-login-password --region "$REGION" | \
    docker login --username AWS --password-stdin "${REPO%%/*}"
  docker build --platform linux/amd64 -t "$REPO:$TAG" app/
  docker push "$REPO:$TAG"
fi

echo "== 4/4 app stack: $APP"
aws cloudformation deploy --stack-name "$APP" --template-file app.yaml \
  --capabilities CAPABILITY_IAM --region "$REGION" \
  --parameter-overrides Env="$ENVIRONMENT" TopicArn="$(out "$BASE" TopicArn)" ImageUri="$REPO:$TAG"

echo
echo "Done. URL: $(out "$APP" AlbUrl)"
