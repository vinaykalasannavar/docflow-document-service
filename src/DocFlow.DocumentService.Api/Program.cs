using DocFlow.DocumentService.Application.Interfaces;
using DocFlow.DocumentService.Infrastructure.Messaging;
using DocFlow.DocumentService.Infrastructure.Storage;
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

builder.Services.AddScoped<IBlobService, BlobService>();
builder.Services.AddScoped<IMessagePublisher, RabbitMqPublisher>();

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();

app.MapControllers();
app.MapHealthChecks("/health");

app.Run();
