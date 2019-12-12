package main

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/appscode/jsonpatch"
	admissionv1beta1 "k8s.io/api/admission/v1beta1"
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/serializer"
)

func serverError(err error) (events.APIGatewayProxyResponse, error) {
	fmt.Println(err.Error())
	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusInternalServerError,
		Headers: map[string]string{
			"Access-Control-Allow-Origin": "*",
		},
		Body: fmt.Sprintf("%v", err.Error()),
	}, nil
}

func responseString(payload string) (events.APIGatewayProxyResponse, error) {
	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Headers: map[string]string{
			"Access-Control-Allow-Origin": "*",
		},
		Body: payload,
	}, nil
}

func responseAdmissionReview(review *admissionv1beta1.AdmissionReview) (events.APIGatewayProxyResponse, error) {
	reviewjson, err := json.Marshal(review)
	if err != nil {
		return serverError(fmt.Errorf("Unexpected decoding error: %v", err))
	}
	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Headers: map[string]string{
			"Access-Control-Allow-Origin": "*",
			"Content-Type":                "application/json",
		},
		Body: string(reviewjson),
	}, nil
}

func mutate(body string) (events.APIGatewayProxyResponse, error) {
	scheme := runtime.NewScheme()
	codecs := serializer.NewCodecFactory(scheme)
	reviewGVK := admissionv1beta1.SchemeGroupVersion.WithKind("AdmissionReview")
	obj, gvk, err := codecs.UniversalDeserializer().Decode([]byte(body), &reviewGVK, &admissionv1beta1.AdmissionReview{})
	if err != nil {
		return serverError(fmt.Errorf("Can't decode body: %v", err))
	}
	review, ok := obj.(*admissionv1beta1.AdmissionReview)
	if !ok {
		serverError(fmt.Errorf("Unexpected GroupVersionKind: %s", gvk))
	}
	if review.Request == nil {
		return serverError(fmt.Errorf("Unexpected nil request"))
	}
	review.Response = &admissionv1beta1.AdmissionResponse{
		UID: review.Request.UID,
	}
	original := review.Request.Object.Raw
	var bs []byte
	switch secret := review.Request.Object.Object.(type) {
	case *v1.Secret:
		secret.Data["nase"] = []byte("***")
		bs, err = json.Marshal(secret)
		if err != nil {
			return serverError(fmt.Errorf("Unexpected encoding error: %v", err))
		}
	default:
		review.Response.Result = &metav1.Status{
			Message: fmt.Sprintf("Unexpected type %T", review.Request.Object.Object),
			Status:  metav1.StatusFailure,
		}
		return responseAdmissionReview(review)
	}
	ops, err := jsonpatch.CreatePatch(original, bs)
	if err != nil {
		return serverError(fmt.Errorf("unexpected diff error: %v", err))
	}
	review.Response.Patch, err = json.Marshal(ops)
	if err != nil {
		return serverError(fmt.Errorf("unexpected patch encoding error: %v", err))
	}
	typ := admissionv1beta1.PatchTypeJSONPatch
	review.Response.PatchType = &typ
	review.Response.Allowed = true
	return responseAdmissionReview(review)
}

func handler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	fmt.Printf("DEBUG:: native secrets webhook start\n")
	response, err := mutate(request.Body)
	if err != nil {
		return serverError(err)
	}
	fmt.Printf("DEBUG:: native secrets webhook done\n")
	return response, nil
}

func main() {
	lambda.Start(handler)
}
