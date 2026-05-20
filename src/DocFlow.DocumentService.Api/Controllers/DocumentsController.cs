using DocFlow.DocumentService.Application.Events;
using DocFlow.DocumentService.Application.Interfaces;
using Microsoft.AspNetCore.Mvc;

// For more information on enabling Web API for empty projects, visit https://go.microsoft.com/fwlink/?LinkID=397860

namespace DocFlow.DocumentService.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentsController(IBlobService blobService, IMessagePublisher publisher, ILogger<DocumentsController> logger) : ControllerBase
    {
        private readonly ILogger<DocumentsController> _logger = logger;

        [HttpPost("upload")]
        public async Task<IActionResult> Upload(IFormFile file)
        {
            if (file == null || file.Length == 0)
                return BadRequest("Invalid file");

            var fileName = $"{Guid.NewGuid()}_{file.FileName}";

            using var stream = file.OpenReadStream();

            _logger.LogInformation("Uploading file {FileName} to blob storage", fileName);
            var blobUrl = await blobService.UploadAsync(fileName, stream);
            _logger.LogInformation("File {FileName} uploaded to blob storage at {BlobUrl}", fileName, blobUrl);

            var message = new DocumentUploadedEvent
            {
                DocumentId = Guid.NewGuid().ToString(),
                FileUrl = blobUrl,
                FileName = file.FileName
            };

            await publisher.PublishAsync("document-uploaded", message);

            return Ok(new { message = "Uploaded successfully", blobUrl });
        }
    }
}
