namespace DocFlow.DocumentService.Application.Interfaces;

public interface IBlobService
{
    Task<string> UploadAsync(string fileName, Stream stream);
}