using DocFlow.DocumentService.Application.Interfaces;
using Microsoft.Extensions.Configuration;
using RabbitMQ.Client;
using System.Text;
using System.Text.Json;
using System.Collections.Generic;

namespace DocFlow.DocumentService.Infrastructure.Messaging;

public class RabbitMqPublisher  : IMessagePublisher
{
    private readonly IConnection _connection;
    private readonly IConfiguration _configuration;

    public RabbitMqPublisher(IConfiguration configuration)
    {
        _configuration = configuration;

        var host = configuration["RabbitMQ:Host"];
        var port = configuration["RabbitMQ:Port"];

        var factory = new ConnectionFactory()
        {
            HostName = host,
            Port = Convert.ToInt32(port),
            UserName = configuration["RabbitMQ:Username"],
            Password = configuration["RabbitMQ:Password"]
        };


        _connection = factory.CreateConnection();
    }

    public Task PublishAsync(string queue, object message)
    {
        using var channel = _connection.CreateModel();

        // Ensure queue declaration matches arguments used by consumers (dead-letter routing)
        var deadLetterRoutingKey = _configuration["RabbitMQ:DeadLetterQueue"] ?? "document-dlq";
        var args = new Dictionary<string, object?>
        {
            { "x-dead-letter-exchange", "" },
            { "x-dead-letter-routing-key", deadLetterRoutingKey }
        };

        channel.QueueDeclare(queue, durable: true, exclusive: false, autoDelete: false, arguments: args);

        var json = JsonSerializer.Serialize(message);
        var body = Encoding.UTF8.GetBytes(json);

        channel.BasicPublish("", queue, null, body);

        return Task.CompletedTask;
    }
}