---
title: "AWS Rest API Gateway - URL Shortener"
date: 2024-07-30
toc: true
toc_sticky: true
toc_label: Table of content
tags:
    - aws
    - terraform
---

AWS offers a managed service for API Gateway that comes in three flavours: http, rest and websocket. A common pattern of usage of these services are in combination with serverless services like Lambdas, DynamoDB tables, S3, etc. But the rest version of these service is more capable than most people think and using it just as a proxy to a lambda containing all the logic of execution is a waste of potential (and money).

For simple use cases where no logic will run in the API Gateway, the http type is better suited (and even using lambdas new http endpoint feature directly), but if you find yourself in a situation where logic to implement is not too complex, you should know some endpoints logic could be implemented directly with this service.

## What can be done with an AWS Rest API Gateway?

Let's first take a look at some definitions the service has, the interaction within the system is mainly done between a client, the service itself and a external service that will process the information (there are edge cases where the last party is not involved):

![main]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-main.svg)

In each of the 4 steps represented with the arrows the API Gateway can execute basic mapping logic (trough the usage of the VTL templating language). This feature combined with the native integrations that this service offers with other AWS services, we can essentially create some apps without the need of a single line of code. Let's take a closer look to each part of this flow.

### Method request

The first part of the flow represents the request sent by the client to the API:

![method_request]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-method_request.svg)

This can represent a http request like:

```
GET /users?page=1 HTTP/1.1
Host: apigatewayid.amazonaws.com
Accept: application/json
```

These parameters (method, path, query parameters, headers, etc.) are taken by the API and can be declared to be used later. In this stage we only declare things we would like to use in later mappings.

### Integration request

At this stage, we configure our API to make a request to the external service. The possible integration types are:

- `AWS`: Integrate with other AWS services, this is the type we are using throughout this guide.
- `AWS_PROXY`: Just use the API as a proxy to a lambda, no intervention is done to the request or response.
- `HTTP`: Integrate with an external generic http server.
- `HTTP_PROXY`: Integrate with an external generic http server as a proxy, no intervention is done to the request or response.
- `MOCK`: Mock the response a server would do, useful for testing without incurring costs.

![integration_request]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-integration_request.svg)

For non-proxy integration types, we will need to create the http request to be made to the external service, and we can use values we get from the original request done by the client. In proxy scenarios, the request is redirected as is to the server.

### Integration response

The third part of the process is called integration response, and it represents the API gateway receiving the response from the external server. This part of the process must map different responses given by the server to responses sent to the client, represented mainly by the status code and content type received from the server and sent to the client. Status codes usually gives us information about the processing the server did and its result, and the `Content-Type` header have information about the format the content of the response have.

![integration_response]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-integration_response.svg)
