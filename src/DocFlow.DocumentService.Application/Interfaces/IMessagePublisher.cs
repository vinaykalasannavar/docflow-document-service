namespace DocFlow.DocumentService.Application.Interfaces
{
    public interface IMessagePublisher
    {
        Task PublishAsync(string documentUploaded, object message);
    }
}
