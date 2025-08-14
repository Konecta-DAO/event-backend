import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import { JSON } "mo:serde";

import EmailService "../../../library/emailLibrary/email/src/email_backend";
import HttpTypes "../../../library/emailLibrary/email/src/email_backend/http.types";
import ArgumentTypes "../../../types/argumentTypes";
import Constants "../../../utils/constants";
import HelperService "../../../utils/helper";
import UserFeedbackReadService "../../email/user_feedback/read";
import SharedService "../../shared/shared";

module {
  public func forwardIssueToExpert(payload : ArgumentTypes.ForwardToExpertRequestPayload, alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger, transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload) : async Result.Result<Text, Text> {
    let userFeedbackResponse = UserFeedbackReadService.getUserFeedback(payload.user_feedback_id, alfangoDB, canistergeekLogger);
    switch (userFeedbackResponse) {
      case (#ok(userFeedback)) {
        let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;
        let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(payload.event_id);

        let startDate = HelperService.getLocalDateFromNanoseconds(eventData.start_date, eventData.userData.timezone, "DD-MM-YYYY hh:mm A");
        let endDate = HelperService.getLocalDateFromNanoseconds(eventData.end_date, eventData.userData.timezone, "DD-MM-YYYY hh:mm A");

        let emailResponse = await EmailService.sendNotification(
          {
            email = Constants.ExpertEmail;
            templateName = Constants.EmailTemplates.ForwardIssueToExpertTemplate;
            sender = Constants.KonectAEmail;
            subject = eventData.name # " Event Issue Forwarded";
            variables = [
              #Single(("eventId", eventData.event_id)),
              #Single(("eventLocation", eventData.location)),
              #Single(("username", userFeedback.username)),
              #Single(("eventDate", startDate # " - " # endDate)),
              #Single(("eventName", eventData.name)),
              #Single(("reason", userFeedback.reason)),
              #Single(("feedbackid", payload.user_feedback_id)),
            ];
          },
          transform,
        );

        var messageId = "";

        let emailResponseJson = JSON.fromText(emailResponse.message_id, null);
        switch (emailResponseJson) {
          case (#ok(blob)) {
            let mailgunResponse : ?ArgumentTypes.MailgunResponse = from_candid (blob);

            switch (mailgunResponse) {
              case (?response) {
                ignore do ? {
                  messageId := response.id!;
                  messageId := Text.trimStart(messageId, #char '<');
                  messageId := Text.trimEnd(messageId, #char '>');
                };
              };
              case (null) messageId := emailResponse.message_id;
            };
          };
          case (#err(error)) {
            canistergeekLogger.logMessage("Send issue email error to expert --->" # debug_show (error));
            messageId := emailResponse.message_id;
          };
        };

        let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
          ("event_id", #text(payload.event_id)),
          ("from", #text(Constants.KonectAEmail)),
          ("to", #text(Constants.ExpertEmail)),
          ("user_feedback_id", #text(payload.user_feedback_id)),
          ("template_name", #text(Constants.EmailTemplates.ForwardIssueToExpertTemplate)),
          ("message_id", #text(messageId)),
          ("idempotency_key", #text(emailResponse.idempotency_key)),
        ];
        canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

        let itemResponse = await Database.createItem({
          createItemInput = {
            databaseName = Constants.KonectA;
            tableName = Constants.ExpertEmailTable;
            attributeDataValues = attributeDataValues;
          };
          alfangoDB = alfangoDB;
        });
        canistergeekLogger.logMessage("Add entry for issue email forwarded to expert --->" # debug_show (itemResponse));

        switch (itemResponse) {
          case (#ok(item)) #ok(item.id);
          case (#err(error)) #err(HelperService.textArrayToString(error));
        };

      };
      case (#err(error)) {
        canistergeekLogger.logMessage("Get feedback error --->" # debug_show (error));
        #err(HelperService.textArrayToString(error));
      };
    };

  };

  public func forwardMultipleIssueToExpert(payload : ArgumentTypes.ForwardMultipleToExpert, alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger, transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload) : async Result.Result<Text, Text> {

    let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;
    let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(payload.event_id);

    let startDate = HelperService.getLocalDateFromNanoseconds(eventData.start_date, eventData.userData.timezone, "DD-MM-YYYY hh:mm A");
    let endDate = HelperService.getLocalDateFromNanoseconds(eventData.end_date, eventData.userData.timezone, "DD-MM-YYYY hh:mm A");

    let emailResponse = await EmailService.sendNotification(
      {
        email = Constants.ExpertEmail;
        templateName = Constants.EmailTemplates.ForwardMultipleIssueToExpertTemplate;
        sender = Constants.KonectAEmail;
        subject = eventData.name # " Event Issues Forwarded";
        variables = [
          #Single(("eventId", eventData.event_id)),
          #Single((
            "eventDate",
            startDate # " - " # endDate,
          )),
          #Single(("eventName", eventData.name)),
          #Single(("eventLocation", eventData.location)),
          #Nested(("users", payload.userFeedbackEmailArr)),
        ];
      },
      transform,
    );

    var messageId = "";

    let emailResponseJson = JSON.fromText(emailResponse.message_id, null);
    switch (emailResponseJson) {
      case (#ok(blob)) {
        let mailgunResponse : ?ArgumentTypes.MailgunResponse = from_candid (blob);

        switch (mailgunResponse) {
          case (?response) {
            ignore do ? {
              messageId := response.id!;
              messageId := Text.trimStart(messageId, #char '<');
              messageId := Text.trimEnd(messageId, #char '>');
            };
          };
          case (null) messageId := emailResponse.message_id;
        };
      };
      case (#err(error)) {
        canistergeekLogger.logMessage("Send issue email error to expert --->" # debug_show (error));
        messageId := emailResponse.message_id;
      };
    };

    let feedbackIdBuffer = Buffer.Buffer<Text>(0);
    let errorBuffer = Buffer.Buffer<Text>(0);

    for (feedback in payload.userFeedbackArr.vals()) {
      feedbackIdBuffer.add(feedback.user_feedback_id);

      let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
        ("event_id", #text(payload.event_id)),
        ("from", #text(Constants.KonectAEmail)),
        ("to", #text(Constants.ExpertEmail)),
        ("user_feedback_id", #text(feedback.user_feedback_id)),
        ("template_name", #text(Constants.EmailTemplates.ForwardMultipleIssueToExpertTemplate)),
        ("message_id", #text(messageId)),
        ("idempotency_key", #text(emailResponse.idempotency_key)),
      ];
      canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

      let itemResponse = await Database.createItem({
        createItemInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.ExpertEmailTable;
          attributeDataValues = attributeDataValues;
        };
        alfangoDB = alfangoDB;
      });
      canistergeekLogger.logMessage("Add entry for issue email forwarded to expert --->" # debug_show (itemResponse));

      switch (itemResponse) {
        case (#ok(_item)) ();
        case (#err(error)) errorBuffer.add(HelperService.textArrayToString(error));
      };
    };

    if (Array.size(Buffer.toArray(errorBuffer)) > 0) {
      let errorArray = Buffer.toArray(errorBuffer);
      #err(HelperService.textArrayToString(errorArray));
    } else {
      #ok("All issues forwarded to expert for event " # eventData.name);
    };
  };

  public func forwardMultipleRatingsToExpert(payload : ArgumentTypes.ForwardMultipleToExpert, alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger, transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload) : async Result.Result<Text, Text> {

    let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;
    let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(payload.event_id);

    let startDate = HelperService.getLocalDateFromNanoseconds(eventData.start_date, eventData.userData.timezone, "DD-MM-YYYY hh:mm A");
    let endDate = HelperService.getLocalDateFromNanoseconds(eventData.end_date, eventData.userData.timezone, "DD-MM-YYYY hh:mm A");

    let emailResponse = await EmailService.sendNotification(
      {
        email = Constants.ExpertEmail;
        templateName = Constants.EmailTemplates.ForwardMultipleRatingToExpertTemplate;
        sender = Constants.KonectAEmail;
        subject = eventData.name # " Event Ratings Forwarded";
        variables = [
          #Single(("eventId", eventData.event_id)),
          #Single((
            "eventDate",
            startDate # " - " # endDate,
          )),
          #Single(("eventName", eventData.name)),
          #Single(("eventLocation", eventData.location)),
          #Nested(("users", payload.userFeedbackEmailArr)),
        ];
      },
      transform,
    );

    var messageId = "";

    let emailResponseJson = JSON.fromText(emailResponse.message_id, null);

    switch (emailResponseJson) {
      case (#ok(blob)) {
        let mailgunResponse : ?ArgumentTypes.MailgunResponse = from_candid (blob);

        switch (mailgunResponse) {
          case (?response) {
            ignore do ? {
              messageId := response.id!;
              messageId := Text.trimStart(messageId, #char '<');
              messageId := Text.trimEnd(messageId, #char '>');
            };
          };
          case (null) messageId := emailResponse.message_id;
        };
      };
      case (#err(error)) {
        canistergeekLogger.logMessage("Send issue email error to expert --->" # debug_show (error));
        messageId := emailResponse.message_id;
      };
    };

    let feedbackIdBuffer = Buffer.Buffer<Text>(0);
    let errorBuffer = Buffer.Buffer<Text>(0);

    for (feedback in payload.userFeedbackArr.vals()) {
      feedbackIdBuffer.add(feedback.user_feedback_id);

      let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
        ("event_id", #text(payload.event_id)),
        ("from", #text(Constants.KonectAEmail)),
        ("to", #text(Constants.ExpertEmail)),
        ("user_feedback_id", #text(feedback.user_feedback_id)),
        ("template_name", #text(Constants.EmailTemplates.ForwardMultipleRatingToExpertTemplate)),
        ("message_id", #text(messageId)),
        ("idempotency_key", #text(emailResponse.idempotency_key)),
      ];
      canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

      let itemResponse = await Database.createItem({
        createItemInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.ExpertEmailTable;
          attributeDataValues = attributeDataValues;
        };
        alfangoDB = alfangoDB;
      });
      canistergeekLogger.logMessage("Add entry for issue email forwarded to expert --->" # debug_show (itemResponse));

      switch (itemResponse) {
        case (#ok(_item)) ();
        case (#err(error)) errorBuffer.add(HelperService.textArrayToString(error));
      };
    };

    if (Array.size(Buffer.toArray(errorBuffer)) > 0) {
      let errorArray = Buffer.toArray(errorBuffer);
      #err(HelperService.textArrayToString(errorArray));
    } else {
      #ok("All ratings forwarded to expert for event " # eventData.name);
    };
  };

  public func forwardConflictFeedbacksToExpert(payload : ArgumentTypes.ForwardMultipleToExpert, alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger, transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload) : async Result.Result<Text, Text> {

    let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;
    let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(payload.event_id);

    let startDate = HelperService.getLocalDateFromNanoseconds(eventData.start_date, eventData.userData.timezone, "DD-MM-YYYY hh:mm A");
    let endDate = HelperService.getLocalDateFromNanoseconds(eventData.end_date, eventData.userData.timezone, "DD-MM-YYYY hh:mm A");

    var isRequest = "";
    if (eventData.event_type == Constants.EventType.Request) {
      isRequest := "true";
    } else {
      isRequest := "false";
    };

    let emailResponse = await EmailService.sendNotification(
      {
        email = Constants.ExpertEmail;
        templateName = Constants.EmailTemplates.ForwardFeedbackConflictToExpertTemplate;
        sender = Constants.KonectAEmail;
        subject = eventData.name # " Event Feedbacks Forwarded";
        variables = [
          #Single(("eventId", payload.event_id)),
          #Single((
            "eventDate",
            startDate # " - " # endDate,
          )),
          #Single(("eventName", eventData.name)),
          #Single(("eventLocation", eventData.location)),
          #Single(("isRequest", isRequest)),
          #Single(("beneficiary_feedback_id", payload.beneficiary_feedback_id)),
          #Nested(("users", payload.userFeedbackEmailArr)),
        ];
      },
      transform,
    );

    var messageId = "";

    let emailResponseJson = JSON.fromText(emailResponse.message_id, null);
    switch (emailResponseJson) {
      case (#ok(blob)) {
        let mailgunResponse : ?ArgumentTypes.MailgunResponse = from_candid (blob);

        switch (mailgunResponse) {
          case (?response) {
            ignore do ? {
              messageId := response.id!;
              messageId := Text.trimStart(messageId, #char '<');
              messageId := Text.trimEnd(messageId, #char '>');
            };
          };
          case (null) messageId := emailResponse.message_id;
        };
      };
      case (#err(error)) {
        canistergeekLogger.logMessage("Send issue email error to expert --->" # debug_show (error));
        messageId := emailResponse.message_id;
      };
    };

    let feedbackIdBuffer = Buffer.Buffer<Text>(0);
    let errorBuffer = Buffer.Buffer<Text>(0);

    for (feedback in payload.userFeedbackArr.vals()) {
      feedbackIdBuffer.add(feedback.user_feedback_id);

      let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
        ("event_id", #text(payload.event_id)),
        ("from", #text(Constants.KonectAEmail)),
        ("to", #text(Constants.ExpertEmail)),
        ("user_feedback_id", #text(feedback.user_feedback_id)),
        ("template_name", #text(Constants.EmailTemplates.ForwardFeedbackConflictToExpertTemplate)),
        ("message_id", #text(messageId)),
        ("idempotency_key", #text(emailResponse.idempotency_key)),
      ];
      canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

      let itemResponse = await Database.createItem({
        createItemInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.ExpertEmailTable;
          attributeDataValues = attributeDataValues;
        };
        alfangoDB = alfangoDB;
      });
      canistergeekLogger.logMessage("Add entry for issue email forwarded to expert --->" # debug_show (itemResponse));

      switch (itemResponse) {
        case (#ok(_item)) ();
        case (#err(error)) errorBuffer.add(HelperService.textArrayToString(error));
      };
    };
    if (Array.size(Buffer.toArray(errorBuffer)) > 0) {
      let errorArray = Buffer.toArray(errorBuffer);
      #err(HelperService.textArrayToString(errorArray));
    } else {
      #ok("All feedbacks forwarded to expert for event " # eventData.name);
    };

  };

  public func forwardMissingFeedbackUsersToExpert(payload : ArgumentTypes.ForwardMissingFeedbackToExpert, alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger, transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload) : async Result.Result<Text, Text> {

    let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;
    let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(payload.event_id);

    let startDate = HelperService.getLocalDateFromNanoseconds(eventData.start_date, eventData.userData.timezone, "DD-MM-YYYY hh:mm A");
    let endDate = HelperService.getLocalDateFromNanoseconds(eventData.end_date, eventData.userData.timezone, "DD-MM-YYYY hh:mm A");

    let emailResponse = await EmailService.sendNotification(
      {
        email = Constants.ExpertEmail;
        templateName = Constants.EmailTemplates.ForwardMissingFeedbackUserlistToExpert;
        sender = Constants.KonectAEmail;
        subject = eventData.name # " Event Missing User Feedback Forwarded";
        variables = [
          #Single(("eventId", eventData.event_id)),
          #Single((
            "eventDate",
            startDate # " - " # endDate,
          )),
          #Single(("eventName", eventData.name)),
          #Single(("eventLocation", eventData.location)),
          #Nested(("users", payload.missingFeedbackUserEmailArr)),
        ];
      },
      transform,
    );

    var messageId = "";

    let emailResponseJson = JSON.fromText(emailResponse.message_id, null);
    switch (emailResponseJson) {
      case (#ok(blob)) {
        let mailgunResponse : ?ArgumentTypes.MailgunResponse = from_candid (blob);

        switch (mailgunResponse) {
          case (?response) {
            ignore do ? {
              messageId := response.id!;
              messageId := Text.trimStart(messageId, #char '<');
              messageId := Text.trimEnd(messageId, #char '>');
            };
          };
          case (null) messageId := emailResponse.message_id;
        };
      };
      case (#err(error)) {
        canistergeekLogger.logMessage("Send missing feedback user list to expert --->" # debug_show (error));
        messageId := emailResponse.message_id;
      };
    };

    let feedbackIdBuffer = Buffer.Buffer<Text>(0);
    let errorBuffer = Buffer.Buffer<Text>(0);

    for (feedback in payload.missingFeedbackUserArr.vals()) {
      feedbackIdBuffer.add(feedback.user_id);

      let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
        ("event_id", #text(payload.event_id)),
        ("from", #text(Constants.KonectAEmail)),
        ("to", #text(Constants.ExpertEmail)),
        ("user_id", #text(feedback.user_id)),
        ("template_name", #text(Constants.EmailTemplates.ForwardMissingFeedbackUserlistToExpert)),
        ("message_id", #text(messageId)),
        ("idempotency_key", #text(emailResponse.idempotency_key)),
      ];
      canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

      let itemResponse = await Database.createItem({
        createItemInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.MissingFeedbackEmailTable;
          attributeDataValues = attributeDataValues;
        };
        alfangoDB = alfangoDB;
      });
      canistergeekLogger.logMessage("Add entry for missing user feedback email forwarded to expert --->" # debug_show (itemResponse));

      switch (itemResponse) {
        case (#ok(_item)) ();
        case (#err(error)) errorBuffer.add(HelperService.textArrayToString(error));
      };
    };

    if (Array.size(Buffer.toArray(errorBuffer)) > 0) {
      let errorArray = Buffer.toArray(errorBuffer);
      #err(HelperService.textArrayToString(errorArray));
    } else {
      #ok("Missing feedback user list forwarded to expert for event " # eventData.name);
    };
  };
};
