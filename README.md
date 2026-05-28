# DocFlow.DocumentService

Enterprise-grade microservice generated using the Enterprise Platform Template.

## Features

- Clean Architecture
- OpenTelemetry
- Health Checks
- Serilog + Seq
- RabbitMQ
- Docker
- GitHub Actions
- Terraform
- Kubernetes
- Integration Tests

## Running Locally

`bash
 docker compose up --build
`

### Running the api steps for :

| Upload flow on Swagger |
|-----|
|`POST /api/Documents/upload`|
| ↓ |
|`API receives file`|
| ↓ |
|`BlobService uploads to Azurite`|
| ↓ |
|`RabbitMQ publisher publishes event`|
| ↓ |
|`Response:`|
```JSON
{
  "message": "Uploaded successfully",
  "blobUrl": "http://azurite:10000/devstoreaccount1/documents/..."
}
```


## Running Tests

`bash
 dotnet test
`

## Health Check

`bash
 /health
`

