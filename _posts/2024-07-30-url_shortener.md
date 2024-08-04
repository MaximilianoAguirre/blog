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

Essentialy a URL shortener is a service that make aliases for long URLs into shorter ones. For example, if we want to share a link like **https://subdomain.example.com/path1/path2/?var1=value1&var2=value2#fragment**, a shortener would allow you to create a short alias url like **https://domain.com/url1** that will respond a *301* when queried and redirect to the original url.

An http server that exposes the following endpoints should be sufficient:

```bash
# Get the short URL and redirect to original URL
GET /:id

# Create new short URLs
POST /url

# List all URLs created
GET /url
```

### Get short URL

With this in mind, if we maintain the information of the different aliases and the url they should redirect to in a database, our server should only do a mapping of a GET request to a query to the database where that info is, and in the mapping back to the client, convert the response into a 301 response with the *Location* header set to the URL stored in the database. The following graph reflects how the API gateway could do this while requesting the information to a DynamoDB table:

![dynamodb_redirect]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-dynamodb_redirect.svg)

As you can see, the API is redirecting the client request 

### Create new alias

Ok, but how do we create entries in the DynamoDB table to begin with? Well, we can create a different interaction with our API Gateway that could be used for this purpose. To follow Rest APIs rules, we can have an endpoint that accepts a *POST* request with the required information in the body in order to create a new entity. The integration would look like:

![dynamodb_create]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-dynamodb_create.svg)

### List all aliases from the database

If we continue with this logic, we could also add a different endpoint that lists all aliases created using the same kind of integration we have been using. This time, we need to perform a `scan` in the DynamoDB table, and following the same structure, it could be mapped to a *GET* request to the `/url` endpoint.


![dynamodb_list]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-dynamodb_list.svg)

## Adding a frontend for user interaction

Even though our server is fully functional at this point, users must interact directly using HTTP requests with it. Let's create a very basic web interface for this purpose (just a couple of static html+css+js files using bootstrap), and serve it with the same API we have been usign, because why not.

There are many ways of hosting a static web page in AWS, and almost all of the involves using s3 to store the files. The main difference from there on, is who acts as the HTTP server that serves the static files. In our use case, we will add some endpoints to our API Gateway that can serve those files for us.

```bash
# Get the index.html file
GET /

# Get static web files
# We want the short URL to be the one that 
# uses /:id so we will add an extra path
POST /website/:file
```

### Get *index.html*

The main endpoint of our API Gateway (`/`) will return the main html page of our frontend. It will be mapped to do a get to that file in s3, and map back the content with a 200 and the `Content-Type` mapped to the same header returned by the request to s3.

![s3_index]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-s3_index.svg)

### Get all frontend files

To expose an endpoint for the rest of the files used in the frontend (`css` and `js` files referenced from the main `html`), we will use all path with the prefix *website* to leave the main `/:id` path free for shortened urls. The main difference with the path implemented for `/`, in this case we don't know beforehand which `Content-Type` the answer of s3 will have, it will depend on the file being requested. So we will need to map the `Content-Type` sent from s3 to the one sent back to the client:

![s3_website]({{ site.url }}{{ site.baseurl }}/assets/images/diagrams/url_shortener-s3_website.svg)

## OpenAPI spec

Now that we understand what is the role of the API Gateway, let's see how we can configure it. Of course the first option would be to go to the AWS console and create/configure the API Gateway there. But, if we want to use IaC to configure the resources, there are two options. Assuming we use Terraform, we can use the resources defined in the AWS provider to create the different path with their method/integration configurations (`api_gateway_resource`, `api_gateway_method`, `api_gateway_method_response`, etc.) or we can use the OpenAPI definition feature supported by the service.

[OpenAPI specifications](https://spec.openapis.org/oas/latest.html) is a standard way of defining APIs with great adoption and widely used to document them. Many tools and utilities are built around this specification. What AWS Api Gateway allows you to create an API by providing the OpenAPI definition of the required configuration. Given this kind of server have some AWS specific integrations that are not part of this standard, an [extension of the standard](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-swagger-extensions.html) is provided by AWS to include custom integrations into this specification.

Let's break the different parts we need to implement into how they look in OpenAPI standards (using the extension provided by AWS):

```yaml
paths:
    # index.html endpoint
    "/":
        get:
            # Define integration with s3 using AWS extension
            x-amazon-apigateway-integration:
                type: aws
                passthroughBehavior: when_no_templates
                uri: arn:aws:apigateway:us-east-1:s3:path/bucket-name/index.html
                # Method expected by s3 api
                httpMethod: GET
                # Credentials used by API Gateway to query s3 object
                credentials: <iam-role>

                # Declare Content-Type mapping
                # In this case we could override the var cause we know the file type will be html
                responses:
                    default:
                        statusCode: "200"
                        responseParameters:
                            "method.response.header.Content-Type": "integration.response.header.Content-Type"

            # Map 200 response and use Content-Type returned by s3
            responses:
                default:
                    "200":
                        headers: { "Content-Type" = { schema = { type = "string" } } }

    # Website endpoint
    "/web/{object}":
        get:

            # Define integration with s3 using AWS extension
            x-amazon-apigateway-integration:
                type: aws
                passthroughBehavior: when_no_templates
                uri: arn:aws:apigateway:us-east-1:s3:path/bucket-name/{object}
                # Method expected by s3 api
                httpMethod: GET 
                # Credentials used by API Gateway to query s3 object
                credentials: <iam-role>
                # Map input parameter to object defined in the integration path
                requestParameters: { "integration.request.path.object" = "method.request.path.object" } 

            parameters:
                - name: object
                  in: path
                  required: true
                  schema: { type: "string" }

            # Map 200 response and use Content-Type returned by s3
            responses:
                default:
                    "200":
                        headers: { "Content-Type" = { schema = { type = "string" } } }

    # Endpoints to manage URLs in DynamoDB
    # This actually accepts two methods: GET to list and POST to create
    "/url":

        get:
            # Define integration with dynamodb using AWS extension
            x-amazon-apigateway-integration:
                type: aws
                passthroughBehavior: when_no_templates
                uri: arn:aws:apigateway:us-east-1:dynamodb:action/Scan
                # Method expected by dynamodb api
                httpMethod: POST
                # Credentials used by API Gateway to query dynamodb table
                credentials: <iam-role>
                # Create body to send in the request to dynamodb
                requestTemplates: { "application/json": { TableName: "<table-name>" } }

                # Map responses received from dynamodb
                responses:
                    "200":
                        statusCode: "200"
                        # Parse response from dynamodb
                        # https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Scan.html#API_Scan_ResponseSyntax
                        responseTemplates: { "application/json" = "$input.path('$').Items" }

            # Mappings of the method response must be declared
            responses:
                "200":
                    description: 200 response

        post:
            # Define integration with dynamodb using AWS extension
            x-amazon-apigateway-integration:
                type: aws
                passthroughBehavior: when_no_templates
                uri: arn:aws:apigateway:us-east-1:dynamodb:action/UpdateItem
                # Method expected by dynamodb api
                httpMethod: POST
                # Credentials used by API Gateway to query dynamodb table
                credentials: <iam-role>

                # Create body to send in the request to dynamodb
                requestTemplates:
                    "application/json":
                        TableName: <table-name>
                        Key:
                            id: { "S": "$input.json('$.id').replaceAll('\"', '')" }
                        UpdateExpression: "SET #u = :u"
                        ExpressionAttributeNames: { "#u": "url" }
                        ExpressionAttributeValues: { ":u": { "S": "$input.json('$.url').replaceAll('\"', '')" }}

                # Map dynamodb response
                responseTemplates:
                    "application/json": |
                        #set($inputRoot = $input.path('$'))
                        {
                          "id": "$inputRoot.Attributes.id.S",
                          "url": "$inputRoot.Attributes.id.S",
                        }

            # Mappings of the method response must be declared
            responses:
                "200":
                    description: 200 response

    # Endpoint to use shortened URLs
    "/{id}":
        get:
            # Define integration with dynamodb using AWS extension
            x-amazon-apigateway-integration:
                type: aws
                passthroughBehavior: when_no_templates
                uri: arn:aws:apigateway:us-east-1:dynamodb:action/GetItem
                # Method expected by dynamodb api
                httpMethod: POST
                # Credentials used by API Gateway to query dynamodb table
                credentials: <iam-role>

                # Create body to send in the request to dynamodb
                requestTemplates:
                    "application/json":
                        TableName: <table-name>
                        Key:
                            id: { "S": "$util.escapeJavaScript($input.params().path.id)" }

                # Map the response from dynamodb to the 301 response we need
                responses:
                    "200":
                        statusCode: "301"
                        responseTemplates:
                            "application/json": |
                                #set($inputRoot = $input.path('$'))
                                #if ($inputRoot.toString().contains("Item"))
                                    #set($context.responseOverride.header.Location = $inputRoot.Item.url.S)
                                #end
```

Yes, I know, this seems more complex than necessary, but remember we are replacing all the code that would be running in a lambda serving static files and interacting with dynamodb.

## Terraform code

The article was focused in the API Gateway configuration, but in a real scenario we will need to create and configure other resources as part of the solution, like the DynamoDB table, the S3 bucket and some IAM resources. For a complete functional example of this concept you can check a terraform module where I implement everything. The source code can be found here: https://github.com/MaximilianoAguirre/terraform-aws-url-shortener, but you can use it like:

```hcl
module "url_shortener" {
  source = "git@github.com:MaximilianoAguirre/terraform-aws-url-shortener"
  name   = "url-shortener"
}
```

<!-- References -->

*[VTL]: Velocity Template Language
