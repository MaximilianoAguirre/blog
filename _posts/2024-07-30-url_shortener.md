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

![main]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-main.svg)

Let's first take a look at some definitions the service has, the interaction within the system is mainly done between a client, the service itself and a external service that will process the information (there are edge cases where the last party is not involved):

In each of the 4 steps represented with the arrows the API Gateway can execute basic mapping logic (trough the usage of the VTL templating language). This feature combined with the native integrations that this service offers with other AWS services, we can essentially create some apps without the need of a single line of code. Let's take a closer look to each part of this flow.

### Method request

![method_request]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-method_request.svg)

The first part of the flow represents the request sent by the client to the API:

This can represent a http request like:

```
GET /users?page=1 HTTP/1.1
Host: apigatewayid.amazonaws.com
Accept: application/json
```

These parameters (method, path, query parameters, headers, etc.) are taken by the API and can be declared to be used later. In this stage we only declare things we would like to use in later mappings.

### Integration request

![integration_request]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-integration_request.svg)

At this stage, we configure our API to make a request to the external service. The possible integration types are:

- `AWS`: Integrate with other AWS services, this is the type we are using throughout this guide.
- `AWS_PROXY`: Just use the API as a proxy to a lambda, no intervention is done to the request or response.
- `HTTP`: Integrate with an external generic http server.
- `HTTP_PROXY`: Integrate with an external generic http server as a proxy, no intervention is done to the request or response.
- `MOCK`: Mock the response a server would do, useful for testing without incurring costs.

For non-proxy integration types, we will need to create the http request to be made to the external service, and we can use values we get from the original request done by the client. In proxy scenarios, the request is redirected as is to the server.

### Integration response

![integration_response]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-integration_response.svg)


The third part of the process is called integration response, and it represents the API gateway receiving the response from the external server. This part of the process must map different responses given by the server to responses sent to the client, represented mainly by the status code and content type received from the server and sent to the client. Status codes usually gives us information about the processing the server did and its result, and the `Content-Type` header have information about the format the content of the response have.

### Method response

![method_response]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-method_response.svg)

The last step of the process is actually returning the response to the client that started the request.

## So, what is a URL shortener?

Essentialy a URL shortener is a service that make aliases for long URLs into shorter ones. For example, if we want to share a link like `https://subdomain.example.com/path1/path2/path3/path4?var1=value1&var2=value2#fragment`, a shortener would allow you to create a short alias url like `https://domain.com/url1` that will respond a *301* when queried and redirect to the original url.

### Get short URL

With this in mind, if we maintain the information of the different aliases and the url they should redirect to, our server should only do a mapping of a GET request to a query to the database where that info is, and in the mapping back to the client, convert the response into a 301 response with the *Location* header set to the URL stored in the database. The following graph reflects how the API gateway could do this while requesting the information to a DynamoDB table:

![dynamodb_redirect]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-dynamodb_redirect.svg)

### Create new alias

Ok, but how do we create entries in the DynamoDB table to begin with? Well, we can create a different interaction with our API Gateway that could be used for this purpose. To follow Rest APIs rules, we can have an endpoint that accepts a *POST* request with the required information in the body in order to create a new entity. The integration would look like:

![dynamodb_create]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-dynamodb_create.svg)

### List all aliases from the database

If we continue with this logic, we could also add a different endpoint that lists all aliases created using the same kind of integration we have been using. This time, we need to perform a `scan` in the DynamoDB table, and following the same structure, it could be mapped to a *GET* request to the `/url` endpoint.


![dynamodb_list]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-dynamodb_list.svg)











<!-- References -->

*[VTL]: Velocity Template Language
