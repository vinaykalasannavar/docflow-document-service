namespace DocFlow.DocumentService.Application.Events;

public class DocumentUploadedEvent
{
    public string DocumentId { get; set; }
    public string FileUrl { get; set; }
    public string FileName { get; set; }
}