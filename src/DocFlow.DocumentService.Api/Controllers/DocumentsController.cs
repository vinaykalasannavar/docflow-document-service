using DocFlow.DocumentService.Application.Events;
using DocFlow.DocumentService.Application.Interfaces;
using Microsoft.AspNetCore.Mvc;

// For more information on enabling Web API for empty projects, visit https://go.microsoft.com/fwlink/?LinkID=397860

namespace DocFlow.DocumentService.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentsController(IBlobService blobService, IMessagePublisher publisher, ILogger<DocumentsController> logger, IConfiguration configuration) : ControllerBase
    {
        private readonly string _queueName = configuration["RabbitMQ:QueueName"] ?? "documents-uploaded-queue";

        [HttpPost("upload")]
        public async Task<IActionResult> Upload(IFormFile file)
        {
            if (file == null || file.Length == 0)
                return BadRequest("Invalid file");

            var fileName = $"{Guid.NewGuid()}_{file.FileName}";

            await using var stream = file.OpenReadStream();

            logger.LogInformation("Attempting to upload file, FileName: {FileName} to blob storage", fileName);
            var blobUrl = await blobService.UploadAsync(fileName, stream);
            logger.LogInformation("Successfully uploaded file, FileName: {FileName} uploaded to blob storage, BlobUrl: {BlobUrl}", fileName, blobUrl);

            var message = new DocumentUploadedEvent
            {
                DocumentId = Guid.NewGuid().ToString(),
                FileUrl = blobUrl,
                FileName = file.FileName
            };

            logger.LogInformation("Attempting to publish document uploaded event to Rabbit MQ  for documentId: {DocumentId}, fileName: {FileName}", message.DocumentId, fileName);
            await publisher.PublishAsync(_queueName, message);
            logger.LogInformation("Successfully published event, documentId: {DocumentId}, fileName: {FileName}, URL: {BlobUrl}, and", message.DocumentId, fileName, blobUrl);

            return Ok(new { message = "Uploaded successfully", blobUrl });
        }
    }
}
