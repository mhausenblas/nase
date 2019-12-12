WEBHOOK_BUCKET?=nase-webhook

.PHONY: build up deploy destroy status

build:
	GOOS=linux GOARCH=amd64 go build -v -ldflags '-d -s -w' -a -tags netgo -installsuffix netgo -o bin/webhook ./webhook

up: 
	sam package --template-file template.yaml --output-template-file current-stack.yaml --s3-bucket ${WEBHOOK_BUCKET}
	sam deploy --template-file current-stack.yaml --stack-name nasewebhook --capabilities CAPABILITY_IAM

deploy: build up

destroy:
	aws cloudformation delete-stack --stack-name nasewebhook

status:
	aws cloudformation describe-stacks --stack-name nasewebhook