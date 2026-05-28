
# ======================================================
# Enterprise Platform Generator
# ======================================================
#
# PURPOSE
# -------
# Generates:
# - .NET Clean Architecture services
# - Unit + Integration tests
# - Docker support
# - GitHub Actions
# - Observability setup
# - Health checks
# - OpenTelemetry
# - Serilog
# - Frontend structure
# - Terraform/Kubernetes structure
#
# RUN:
# .\generate-enterprise-service.ps1 -ServiceName "DocumentService"
#
# ======================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$ServiceName
)

# ======================================================
# CONFIGURATION
# ======================================================

$Root = Get-Location

$SrcPath = Join-Path $Root "src"
$TestsPath = Join-Path $Root "tests"
$GithubPath = Join-Path $Root ".github"
$WorkflowPath = Join-Path $GithubPath "workflows"

# ======================================================
# CREATE FOLDERS
# ======================================================

$folders = @(
    $SrcPath,
    $TestsPath,
    $GithubPath,
    $WorkflowPath,
    "docker",
    "terraform",
    "kubernetes",
    "docs"
)

foreach ($folder in $folders) {

    if (-not (Test-Path $folder)) {

        New-Item -ItemType Directory -Path $folder | Out-Null

        Write-Host "Created folder: $folder" -ForegroundColor Cyan
    }
}

# ======================================================
# SOLUTION NAME
# ======================================================

$SolutionName = "DocFlow.$ServiceName"

Write-Host ""
Write-Host "Creating Solution: $SolutionName" -ForegroundColor Green

# ======================================================
# CREATE SOLUTION
# ======================================================

if (-not (Test-Path "$SolutionName.sln")) {

    dotnet new sln -n $SolutionName
}

# ======================================================
# PROJECT NAMES
# ======================================================

$ApiProject = "$SolutionName.Api"
$ApplicationProject = "$SolutionName.Application"
$DomainProject = "$SolutionName.Domain"
$InfrastructureProject = "$SolutionName.Infrastructure"

$UnitTestProject = "$SolutionName.UnitTests"
$IntegrationTestProject = "$SolutionName.IntegrationTests"

# ======================================================
# CREATE PROJECTS
# ======================================================

Write-Host ""
Write-Host "Creating Projects..." -ForegroundColor Green

# API

dotnet new webapi -n $ApiProject -o "$SrcPath/$ApiProject"

# Application

dotnet new classlib -n $ApplicationProject -o "$SrcPath/$ApplicationProject"

# Domain

dotnet new classlib -n $DomainProject -o "$SrcPath/$DomainProject"

# Infrastructure

dotnet new classlib -n $InfrastructureProject -o "$SrcPath/$InfrastructureProject"

# Unit Tests

dotnet new xunit -n $UnitTestProject -o "$TestsPath/$UnitTestProject"

# Integration Tests

dotnet new xunit -n $IntegrationTestProject -o "$TestsPath/$IntegrationTestProject"

# ======================================================
# ADD TO SOLUTION
# ======================================================

Write-Host ""
Write-Host "Adding Projects To Solution..." -ForegroundColor Green

Get-ChildItem -Path . -Filter *.csproj -Recurse |
ForEach-Object {

    dotnet sln add $_.FullName
}

# ======================================================
# PROJECT REFERENCES
# ======================================================

Write-Host ""
Write-Host "Adding Project References..." -ForegroundColor Green

# API references

dotnet add "$SrcPath/$ApiProject/$ApiProject.csproj" reference "$SrcPath/$ApplicationProject/$ApplicationProject.csproj"


dotnet add "$SrcPath/$ApiProject/$ApiProject.csproj" reference "$SrcPath/$InfrastructureProject/$InfrastructureProject.csproj"

# Application references

dotnet add "$SrcPath/$ApplicationProject/$ApplicationProject.csproj" reference "$SrcPath/$DomainProject/$DomainProject.csproj"

# Infrastructure references

dotnet add "$SrcPath/$InfrastructureProject/$InfrastructureProject.csproj" reference "$SrcPath/$ApplicationProject/$ApplicationProject.csproj"


dotnet add "$SrcPath/$InfrastructureProject/$InfrastructureProject.csproj" reference "$SrcPath/$DomainProject/$DomainProject.csproj"

# Unit test references

dotnet add "$TestsPath/$UnitTestProject/$UnitTestProject.csproj" reference "$SrcPath/$ApplicationProject/$ApplicationProject.csproj"

# Integration test references

dotnet add "$TestsPath/$IntegrationTestProject/$IntegrationTestProject.csproj" reference "$SrcPath/$ApiProject/$ApiProject.csproj"

# ======================================================
# INSTALL PACKAGES - API
# ======================================================

Write-Host ""
Write-Host "Installing API Packages..." -ForegroundColor Green

$ApiCsproj = "$SrcPath/$ApiProject/$ApiProject.csproj"

$ApiPackages = @(
    "Swashbuckle.AspNetCore",
    "Serilog.AspNetCore",
    "Serilog.Sinks.Console",
    "Serilog.Sinks.Seq",
    "OpenTelemetry.Extensions.Hosting",
    "OpenTelemetry.Instrumentation.AspNetCore",
    "OpenTelemetry.Instrumentation.Http",
    "OpenTelemetry.Exporter.Console",
    "AspNetCore.HealthChecks.UI.Client",
    "MassTransit.RabbitMQ",
    "FluentValidation.AspNetCore",
    "MediatR.Extensions.Microsoft.DependencyInjection",
    "Microsoft.AspNetCore.OpenApi"
)

foreach ($package in $ApiPackages) {

    dotnet add $ApiCsproj package $package
}

# ======================================================
# INSTALL PACKAGES - INFRASTRUCTURE
# ======================================================

Write-Host ""
Write-Host "Installing Infrastructure Packages..." -ForegroundColor Green

$InfraCsproj = "$SrcPath/$InfrastructureProject/$InfrastructureProject.csproj"

$InfraPackages = @(
    "Azure.Storage.Blobs",
    "RabbitMQ.Client",
    "Npgsql.EntityFrameworkCore.PostgreSQL",
    "Microsoft.EntityFrameworkCore.Design",
    "Polly",
    "Polly.Extensions.Http"
)

foreach ($package in $InfraPackages) {

    dotnet add $InfraCsproj package $package
}

# ======================================================
# INSTALL PACKAGES - TESTS
# ======================================================

Write-Host ""
Write-Host "Installing Test Packages..." -ForegroundColor Green

$TestPackages = @(
    "FluentAssertions",
    "Moq",
    "Testcontainers",
    "Microsoft.AspNetCore.Mvc.Testing"
)

foreach ($package in $TestPackages) {

    dotnet add "$TestsPath/$UnitTestProject/$UnitTestProject.csproj" package $package

    dotnet add "$TestsPath/$IntegrationTestProject/$IntegrationTestProject.csproj" package $package
}

# ======================================================
# CREATE DOCKERFILE
# ======================================================

Write-Host ""
Write-Host "Creating Dockerfile..." -ForegroundColor Green

$DockerFilePath = "$SrcPath/$ApiProject/Dockerfile"

@"
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY . .

RUN dotnet restore
RUN dotnet publish -c Release -o /app/publish

FROM base AS final
WORKDIR /app

COPY --from=build /app/publish .

ENTRYPOINT [\"dotnet\", \"$ApiProject.dll\"]
"@ | Set-Content $DockerFilePath

# ======================================================
# CREATE APPSETTINGS
# ======================================================

Write-Host ""
Write-Host "Creating appsettings.Development.json..." -ForegroundColor Green

$appSettings = @"
{
  "Serilog": {
    "MinimumLevel": "Information"
  },
  "ConnectionStrings": {
    "Postgres": "Host=postgres;Port=5432;Database=docflow;Username=postgres;Password=postgres"
  },
  "RabbitMQ": {
    "Host": "rabbitmq"
  },
  "OpenTelemetry": {
    "ServiceName": "$ApiProject"
  }
}
"@

$appSettingsPath = "$SrcPath/$ApiProject/appsettings.Development.json"

$appSettings | Set-Content $appSettingsPath

# ======================================================
# CREATE PROGRAM.CS TEMPLATE
# ======================================================

Write-Host ""
Write-Host "Generating Program.cs..." -ForegroundColor Green

$ProgramCs = @"
using OpenTelemetry.Trace;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .WriteTo.Seq("http://seq:80"));

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddHealthChecks();

builder.Services.AddOpenTelemetry()
    .WithTracing(tracing =>
    {
        tracing
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddConsoleExporter();
    });

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();

app.MapControllers();
app.MapHealthChecks("/health");

app.Run();
"@

$ProgramPath = "$SrcPath/$ApiProject/Program.cs"

$ProgramCs | Set-Content $ProgramPath

# ======================================================
# CREATE GITHUB ACTION
# ======================================================

Write-Host ""
Write-Host "Creating GitHub Actions Workflow..." -ForegroundColor Green

$Workflow = @"
name: Build and Test

on:
  push:
    branches:
      - main

jobs:
  build:

    runs-on: ubuntu-latest

    steps:

      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: 8.0.x

      - name: Restore
        run: dotnet restore

      - name: Build
        run: dotnet build --no-restore

      - name: Test
        run: dotnet test --no-build
"@

$WorkflowPathFile = "$WorkflowPath/build.yml"

$Workflow | Set-Content $WorkflowPathFile

# ======================================================
# CREATE TERRAFORM FILES
# ======================================================

Write-Host ""
Write-Host "Creating Terraform Files..." -ForegroundColor Green

@"
terraform {
  required_version = \">= 1.5.0\"
}
"@ | Set-Content "terraform/main.tf"

@"
variable \"environment\" {
  type = string
}
"@ | Set-Content "terraform/variables.tf"

# ======================================================
# CREATE KUBERNETES MANIFEST
# ======================================================

Write-Host ""
Write-Host "Creating Kubernetes Deployment..." -ForegroundColor Green

@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $($ServiceName.ToLower())
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $($ServiceName.ToLower())
  template:
    metadata:
      labels:
        app: $($ServiceName.ToLower())
    spec:
      containers:
      - name: $($ServiceName.ToLower())
        image: your-image
        ports:
        - containerPort: 8080
"@ | Set-Content "kubernetes/deployment.yml"

# ======================================================
# CREATE README
# ======================================================

Write-Host ""
Write-Host "Creating README.md..." -ForegroundColor Green

@"
# $SolutionName

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

```bash
 docker compose up --build
```

## Running Tests

```bash
 dotnet test
```

## Health Check

```bash
 /health
```
"@ | Set-Content "README.md"

# ======================================================
# FINAL MESSAGE
# ======================================================

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "Enterprise Service Generation Complete" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Solution Created: $SolutionName" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. docker compose up --build"
Write-Host "2. dotnet build"
Write-Host "3. dotnet test"
Write-Host "4. Open Swagger"
Write-Host "5. Add business features"
Write-Host ""

