using System.Text;
using DocFlow.DocumentService.Application.Events;
using DocFlow.DocumentService.Api.Controllers;
using DocFlow.DocumentService.Application.Interfaces;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;

namespace DocFlow.DocumentService.UnitTests;

public class DocumentsControllerTests
{
    [Fact]
    public async Task Upload_ReturnsBadRequest_WhenFileIsNull()
    {
        var blobService = new Mock<IBlobService>();
        var publisher = new Mock<IMessagePublisher>();
        var logger = new Mock<ILogger<DocumentsController>>();
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>()).Build();

        var controller = new DocumentsController(blobService.Object, publisher.Object, logger.Object, configuration);

        var result = await controller.Upload(null!);

        result.Should().BeOfType<BadRequestObjectResult>();
        ((BadRequestObjectResult)result).Value.Should().Be("Invalid file");
    }

    [Fact]
    public async Task Upload_ReturnsBadRequest_WhenFileIsEmpty()
    {
        var blobService = new Mock<IBlobService>();
        var publisher = new Mock<IMessagePublisher>();
        var logger = new Mock<ILogger<DocumentsController>>();
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>()).Build();

        var emptyFile = new FormFile(new MemoryStream(), 0, 0, "file", "empty.pdf");
        var controller = new DocumentsController(blobService.Object, publisher.Object, logger.Object, configuration);

        var result = await controller.Upload(emptyFile);

        result.Should().BeOfType<BadRequestObjectResult>();
        ((BadRequestObjectResult)result).Value.Should().Be("Invalid file");
    }

    [Fact]
    public async Task Upload_UploadsFileAndPublishesMessage()
    {
        var blobUrl = "https://storage.example.com/test/test.pdf";
        var capturedFileName = string.Empty;

        var blobService = new Mock<IBlobService>(MockBehavior.Strict);
        blobService
            .Setup(x => x.UploadAsync(It.IsAny<string>(), It.IsAny<Stream>()))
            .ReturnsAsync(blobUrl)
            .Callback<string, Stream>((name, stream) => capturedFileName = name);

        var publisher = new Mock<IMessagePublisher>(MockBehavior.Strict);
        publisher
            .Setup(x => x.PublishAsync(It.IsAny<string>(), It.IsAny<object>()))
            .Returns(Task.CompletedTask)
            .Callback<string, object>((queue, message) =>
            {
                queue.Should().Be("documents-uploaded-queue");
                message.Should().BeOfType<DocumentUploadedEvent>();
                var documentEvent = (DocumentUploadedEvent)message;
                documentEvent.FileUrl.Should().Be(blobUrl);
                documentEvent.FileName.Should().Be("test.pdf");
                Guid.TryParse(documentEvent.DocumentId, out _).Should().BeTrue();
            });

        var logger = new Mock<ILogger<DocumentsController>>();
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>()).Build();

        var fileContents = Encoding.UTF8.GetBytes("hello world");
        using var fileStream = new MemoryStream(fileContents);
        var formFile = new FormFile(fileStream, 0, fileContents.Length, "file", "test.pdf")
        {
            Headers = new HeaderDictionary()
        };

        var controller = new DocumentsController(blobService.Object, publisher.Object, logger.Object, configuration);

        var result = await controller.Upload(formFile);

        result.Should().BeOfType<OkObjectResult>();
        capturedFileName.Should().EndWith("_test.pdf");
        var okResult = (OkObjectResult)result;
        okResult.Value.Should().BeEquivalentTo(new { message = "Uploaded successfully", blobUrl });

        blobService.Verify(x => x.UploadAsync(It.IsAny<string>(), It.IsAny<Stream>()), Times.Once);
        publisher.Verify(x => x.PublishAsync(It.IsAny<string>(), It.IsAny<object>()), Times.Once);
    }
}
