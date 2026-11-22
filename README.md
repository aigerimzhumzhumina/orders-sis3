# Orders - SIS 3 (Infrastructure as Code)

Flask API on ECS Fargate (behind an ALB) publishes `OrderCreated` events to SNS.
SNS fans out to an SQS queue (with a dead-letter queue, maxReceiveCount 5).
A Lambda consumer writes orders to DynamoDB; a conditional write on `orderId`
makes the consumer idempotent. Everything is in CloudFormation (`base.yaml`, `app.yaml`).

## Prerequisites (manual, one time)
AWS CLI configured for us-east-1, Docker running, `pip install cfn-lint`.
IAM permissions to create IAM roles, VPC, ALB, ECS, ECR, SNS, SQS, Lambda, DynamoDB.

## Deploy (one command)
    ./deploy.sh dev

The argument is a suffix for stack names (`orders-base-dev`, `orders-app-dev`).
Use another suffix for a second copy, e.g. `./deploy.sh defence`.

## Test
    URL=<AlbUrl printed at the end>
    curl $URL/health
    curl -X POST $URL/orders -H "Content-Type: application/json" -d '{"orderId":"1","item":"book","qty":1}'

## Delete (app stack first, then base)
    aws cloudformation delete-stack --stack-name orders-app-dev --region us-east-1
    aws cloudformation wait stack-delete-complete --stack-name orders-app-dev --region us-east-1
    aws cloudformation delete-stack --stack-name orders-base-dev --region us-east-1
    aws cloudformation wait stack-delete-complete --stack-name orders-base-dev --region us-east-1

## Design notes
- No resource has a fixed name, so several copies can coexist.
- Image tag = git commit hash; ECR tags are immutable, never `latest`.
- Tasks run in public subnets without NAT (cost); port 8080 is open only to the ALB security group.
- Two roles: execution role (pull image, write logs) and task role (sns:Publish only).
- No secrets in the repository; the app has no passwords.
