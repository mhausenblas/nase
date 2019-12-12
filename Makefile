WEBHOOK_BUCKET?=nase-webhook
WEBHOOK_ENDPOINT:=$(shell aws cloudformation describe-stacks --stack-name nasewebhook --query "Stacks[0].Outputs[?OutputKey=='WebhookEndpoint'].OutputValue" --output text)/webhook

.PHONY: build up installwebhook deploy destroy status

build:
	GOOS=linux GOARCH=amd64 go build -v -ldflags '-d -s -w' -a -tags netgo -installsuffix netgo -o bin/webhook ./webhook

up: 
	sam package --template-file template.yaml --output-template-file current-stack.yaml --s3-bucket ${WEBHOOK_BUCKET}
	sam deploy --template-file current-stack.yaml --stack-name nasewebhook --capabilities CAPABILITY_IAM

installwebhook:
	@printf "Using %s with CA %s\n" ${WEBHOOK_ENDPOINT}
	@sed 's|API_GATEWAY_WEBHOOK_URL|${WEBHOOK_ENDPOINT}|g' webhook-config-template.yaml > webhook-config.yaml
	@echo Registering Webhook
	kubectl apply -f webhook-config.yaml

deploy: build up installwebhook

destroy:
	aws cloudformation delete-stack --stack-name nasewebhook

status:
	aws cloudformation describe-stacks --stack-name nasewebhook