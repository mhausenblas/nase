WEBHOOK_BUCKET?=nase-webhook
APIGATEWAY_ENDPOINT:=$(shell aws cloudformation describe-stacks --stack-name nasewebhook --query "Stacks[0].Outputs[?OutputKey=='WebhookEndpoint'].OutputValue" --output text)
SECRETS_WEBHOOK_ENDPOINT:=${APIGATEWAY_ENDPOINT}/secrets
PODS_WEBHOOK_ENDPOINT:=${APIGATEWAY_ENDPOINT}/pods

.PHONY: build buildsecrets buildpods up installwebhooks deploy destroy status

build: buildsecrets buildpods

buildsecrets:
	GOOS=linux GOARCH=amd64 go build -v -ldflags '-d -s -w' -a -tags netgo -installsuffix netgo -o bin/secrets ./secrets/webhook

buildpods:
	GOOS=linux GOARCH=amd64 go build -v -ldflags '-d -s -w' -a -tags netgo -installsuffix netgo -o bin/pods ./pods/webhook

up: 
	sam package --template-file template.yaml --output-template-file current-stack.yaml --s3-bucket ${WEBHOOK_BUCKET}
	sam deploy --template-file current-stack.yaml --stack-name nasewebhook --capabilities CAPABILITY_IAM

installwebhooks:
	@printf "Using %s as the base URL\n" ${WEBHOOK_ENDPOINT}
	@sed 's|API_GATEWAY_WEBHOOK_URL|${SECRETS_WEBHOOK_ENDPOINT}|g' secrets/webhook-config-template.yaml > secrets/webhook-config.yaml
	@sed 's|API_GATEWAY_WEBHOOK_URL|${PODS_WEBHOOK_ENDPOINT}|g' pods/webhook-config-template.yaml > pods/webhook-config.yaml
	@echo Registering webhooks
	kubectl apply -f secrets/webhook-config.yaml
	kubectl apply -f pods/webhook-config.yaml

deploy: build up installwebhooks

destroy:
	aws cloudformation delete-stack --stack-name nasewebhook

status:
	aws cloudformation describe-stacks --stack-name nasewebhook