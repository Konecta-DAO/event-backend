import Blob "mo:base/Blob";
import Error "mo:base/Error";
import Cycles "mo:base/ExperimentalCycles";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";

import HttpTypes "../http.types";

module {

  private func escape(t : Text) : Text {
    let t1 = Text.replace(t, #text "\\", "\\\\");
    let t2 = Text.replace(t1, #text "\"", "\\\"");
    t2;
  };

  public func sendNotification(data : HttpTypes.SendNotificationArgs, transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload) : async HttpTypes.EmailResponse {

    var idempotencyKey : Text = "";

    try {

      if (Text.size(data.email) == 0) {
        return {
          message_id = "Please enter an email to send notification.";
          idempotency_key = idempotencyKey;
        };
      };

      // Managment canister
      let ic : HttpTypes.IC = actor ("aaaaa-aa");

      let now : Time.Time = Time.now();
      let timestamp : Nat64 = Nat64.fromIntWrap(now);

      idempotencyKey := Text.concat(data.email, Nat64.toText(timestamp));

      let body = Buffer.Buffer<Text>(20);

      body.add("{");
      body.add("\"idempotency_key\":\"" # escape(idempotencyKey) # "\",");
      body.add("\"email\":\"" # escape(data.email) # "\",");
      body.add("\"template_name\":\"" # escape(data.templateName) # "\",");
      body.add("\"subject\":\"" # escape(data.subject) # "\",");
      body.add("\"sender\":\"" # escape(data.sender) # "\",");
      body.add("\"variables\":{");

      let variables : [HttpTypes.varType] = data.variables;
      var firstVar = true;
      for (variable in variables.vals()) {
        if (not firstVar) { body.add(",") };
        firstVar := false;

        switch (variable) {
          case (#Single(key, value)) {
            body.add("\"" # escape(key) # "\":\"" # escape(value) # "\"");
          };
          case (#Nested(key, nestedVars)) {
            body.add("\"" # escape(key) # "\":[");
            var firstNested = true;
            for (nestedObj in nestedVars.vals()) {
              if (not firstNested) { body.add(",") };
              firstNested := false;
              body.add("{");
              var firstProp = true;
              for (prop in nestedObj.vals()) {
                if (not firstProp) { body.add(",") };
                firstProp := false;
                body.add("\"" # escape(prop.0) # "\":\"" # escape(prop.1) # "\"");
              };
              body.add("}");
            };
            body.add("]");
          };
        };
      };

      body.add("}"); // Close variables object
      body.add("}"); // Close main body object

      let requestBodyJson = Text.join("", body.vals());

      let requestBodyAsBlob : Blob = Text.encodeUtf8(requestBodyJson);
      let requestBodyAsNat8 : [Nat8] = Blob.toArray(requestBodyAsBlob);

      // Setup transform context for the HTTP call
      let transform_context : HttpTypes.TransformContext = {
        function = transform;
        context = Blob.fromArray([]);
      };

      // Setup request
      let httpRequest : HttpTypes.HttpRequestArgs = {
        url = "https://ubetyvsts7xkmg4pda6vroit2u0eqxfs.lambda-url.us-east-1.on.aws/storeemail";
        max_response_bytes = null;
        headers = [
          { name = "Content-Type"; value = "application/json" },
          { name = "Idempotency-Key"; value = idempotencyKey },
        ];
        body = ?requestBodyAsNat8;
        method = #post;
        transform = ?transform_context;
      };

      Cycles.add<system>(21_850_258_000);

      // Send the request
      let httpResponse : HttpTypes.HttpResponsePayload = await ic.http_request(httpRequest);

      // Check the response
      if (httpResponse.status > 299) {
        let response_body : Blob = Blob.fromArray(httpResponse.body);
        let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {
          case (null) { "No value returned" };
          case (?y) { y };
        };
        let error_message = "Error sending notification " # decoded_text;
        return {
          message_id = error_message;
          idempotency_key = idempotencyKey;
        };
      };

      let response_body : Blob = Blob.fromArray(httpResponse.body);
      let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {
        case (null) { "No value returned" };
        case (?y) { y };
      };

      return {
        message_id = decoded_text;
        idempotency_key = idempotencyKey;
      };

    } catch (e) {
      return {
        message_id = Error.message(e);
        idempotency_key = idempotencyKey;
      };
    };
  };
};
