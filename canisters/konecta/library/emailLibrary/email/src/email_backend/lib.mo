import EmailModule "./Email/email";
import HttpTypes "http.types";

module {

  public type HttpRequestArgs = HttpTypes.HttpRequestArgs;

  public type HttpHeader = HttpTypes.HttpHeader;

  public type HttpMethod = HttpTypes.HttpMethod;

  public type SendNotificationArgs = HttpTypes.SendNotificationArgs;

  public type TransformArgs = HttpTypes.TransformArgs;

  public type HttpResponsePayload = HttpTypes.HttpResponsePayload;

  public let { sendNotification } = EmailModule;
};
