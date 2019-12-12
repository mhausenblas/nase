WEBHOOK_BUCKET?=nase-webhook
WEBHOOK_ENDPOINT:=$(shell aws cloudformation describe-stacks --stack-name nasewebhook --query "Stacks[0].Outputs[?OutputKey=='WebhookEndpoint'].OutputValue" --output text)/webhook
CA_BUNDLE:=$(shell kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}')

.PHONY: build up installwebhook deploy destroy status

build:
	GOOS=linux GOARCH=amd64 go build -v -ldflags '-d -s -w' -a -tags netgo -installsuffix netgo -o bin/webhook ./webhook

up: 
	sam package --template-file template.yaml --output-template-file current-stack.yaml --s3-bucket ${WEBHOOK_BUCKET}
	sam deploy --template-file current-stack.yaml --stack-name nasewebhook --capabilities CAPABILITY_IAM

installwebhook:
	@printf "Using %s with CA %s" ${WEBHOOK_ENDPOINT} ${CA_BUNDLE}
	@sed 's|API_GATEWAY_WEBHOOK_URL|${WEBHOOK_ENDPOINT}|g; s|CA_BUNDLE|${CA_BUNDLE}|g' webhook-config-template.yaml > webhook-config.yaml

deploy: build up

destroy:
	aws cloudformation delete-stack --stack-name nasewebhook

status:
	aws cloudformation describe-stacks --stack-name nasewebhook