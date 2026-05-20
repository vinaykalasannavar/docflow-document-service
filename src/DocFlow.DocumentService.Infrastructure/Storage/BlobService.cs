using Azure.Storage.Blobs;
using DocFlow.DocumentService.Application.Interfaces;
using Microsoft.Extensions.Configuration;

namespace DocFlow.DocumentService.Infrastructure.Storage;

public class BlobService : IBlobService
{
    private readonly BlobContainerClient _container;

    public BlobService(IConfiguration config)
    {
        var conn = config["AzureBlob:ConnectionString"];
        var containerName = config["AzureBlob:ContainerName"];

        _container = new BlobContainerClient(conn, containerName);
        _container.CreateIfNotExists();
    }

    public async Task<string> UploadAsync(string fileName, Stream content)
    {
        var blob = _container.GetBlobClient(fileName);
        await blob.UploadAsync(content, true);
        return blob.Uri.ToString();
    }
}