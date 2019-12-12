# Native Secrets 

This repo is a proof-of-concept (PoC) showing how native Kubernetes secrets can be support via AWS Secrets Manager. The basic idea of the PoC is to use an extension point of the Kubernetes API server called [dynamic admission control](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/): when a user creates a secret, a mutating Webhook (implemented as an AWS Lambda function) intercepts the process of persisting the payload into `etcd` and replaces it with the ARN of a secret managed by the [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/).

## Installation

In order to build and deploy the service, clone this repo and make sure you've got the following available, locally:

- The [aws](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) CLI
- The [SAM CLI](https://github.com/awslabs/aws-sam-cli)
- Go 1.12 or above
- A Kubernetes 1.14 cluster or above with `kubectl` configured, locally

Additionally, I recommend that you have [jq](https://stedolan.github.io/jq/download/) installed.

First, prepare the S3 bucket for the Lambda function that provides the webhook (make sure that you pick different name for the `WEBHOOK_BUCKET` bucket env variable since buckets need to be globally unique):

```sh
export WEBHOOK_BUCKET=nase-webhook

aws s3api create-bucket \
          --bucket $WEBHOOK_BUCKET \
          --create-bucket-configuration LocationConstraint=$(aws configure get region) \
          --region $(aws configure get region)
```

Now, to install the webhook, execute:

```sh
make deploy
``` 

To verify if all went well, compare the output of the following command with your own output:

```sh
$ kubectl describe mutatingwebhookconfigurations/nase
Name:         nase
Namespace:
Labels:       <none>
Annotations:  kubectl.kubernetes.io/last-applied-configuration:
                {"apiVersion":"admissionregistration.k8s.io/v1beta1","kind":"MutatingWebhookConfiguration","metadata":{"annotations":{},"name":"nase"},"we...
API Version:  admissionregistration.k8s.io/v1beta1
Kind:         MutatingWebhookConfiguration
Metadata:
  Creation Timestamp:  2019-12-12T10:36:57Z
  Generation:          1
  Resource Version:    2394053
  Self Link:           /apis/admissionregistration.k8s.io/v1beta1/mutatingwebhookconfigurations/nase
  UID:                 5277a118-1ccb-11ea-98a5-0a084944784a
Webhooks:
  Admission Review Versions:
    v1beta1
  Client Config:
    Ca Bundle:     ***
    URL:           https://******.execute-api.us-west-2.amazonaws.com/Prod/webhook
  Failure Policy:  Fail
  Name:            nase.mhausenblas.info
  Namespace Selector:
  Rules:
    API Groups:

    API Versions:
      v1
    Operations:
      CREATE
      UPDATE
    Resources:
      secrets
    Scope:          *
  Side Effects:     Unknown
  Timeout Seconds:  30
Events:             <none>
```

You're now ready to use the demo. 

Notes:

- The CA bundle used in the [webhook config](webhook-config-template.yaml) comes from [Amazon Trust Services](https://www.amazontrust.com/repository/).
- This is a PoC, not a production-ready setup. In order to lock down the webhook, that is, make sure that it can only be called from your Kubernetes cluster, you'd need to [restrict the API Gateway](https://aws.amazon.com/blogs/compute/introducing-amazon-api-gateway-private-endpoints/) access to its VPC.

## Usage

``sh
$ kubectl create secret generic somesecret --from-literal=nase=supersecret
secret/somesecret created

$ kubectl get secret/somesecret -o "jsonpath={.data['nase']}" | base64 -D
arn:aws:secretsmanager:us-west-2:123456789012:secret:.nase-dzWHWN
``