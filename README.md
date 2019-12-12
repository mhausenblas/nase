# Native Secrets 

This repo is a proof-of-concept (PoC) showing how native Kubernetes secrets can be support via AWS Secrets Manager. The basic idea of the PoC is to use an extension point of the Kubernetes API server called [dynamic admission control](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/): when a user creates a secret, a mutating Webhook (implemented as an AWS Lambda function) intercepts the process of persisting the payload into `etcd` and replaces it with the ARN of a secret managed by the [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/).

## Installation

In order to build and deploy the service, clone this repo and make sure you've got the following available, locally:

- The [aws](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) CLI
- The [SAM CLI](https://github.com/awslabs/aws-sam-cli)
- Go 1.12 or above

Additionally, I recommend that you have [jq](https://stedolan.github.io/jq/download/) installed.

To install the webhook, execute:

```sh
make deploy
``` 

You're now ready to use the demo. Note: this is a PoC, not a production-ready setup. In order to lock down the webhook, that is, make sure that it can only be called from your Kubernetes cluster, you'd need to [restrict the API Gateway](https://aws.amazon.com/blogs/compute/introducing-amazon-api-gateway-private-endpoints/) access to its VPC.

