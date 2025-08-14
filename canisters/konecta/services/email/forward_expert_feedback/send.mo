import Database "mo:alfangodb/AlfangoDB";
import Bool "mo:base/Bool";
import Error "mo:base/Error";
import Float "mo:base/Float";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import { JSON } "mo:serde";

import EmailService "../../../library/emailLibrary/email/src/email_backend";
import HttpTypes "../../../library/emailLibrary/email/src/email_backend/http.types";
import TransactionService "../../../services/transaction/read";
import ArgumentTypes "../../../types/argumentTypes";
import Constants "../../../utils/constants";
import HelperService "../../../utils/helper";
import SharedService "../../shared/shared";

module {
  public func sendRefundEmailToRemitter(
    payload : ArgumentTypes.ExpertResolutionEmailRequest,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
  ) : async Result.Result<Text, Text> {
    let userFeedback = payload.user_feedback;

    let transactionId = HelperService.initializeTextField(payload.transaction_id, "");

    let transactionResponse = TransactionService.getTransactionById(transactionId, alfangoDB);

    var firstname = "";
    var lastname = "";
    var email = "";
    var timezone = "";

    if (Text.size(userFeedback.id) > 0) {
      firstname := userFeedback.firstname;
      lastname := userFeedback.lastname;
      email := userFeedback.email;
      timezone := userFeedback.timezone;
    } else {
      let userDetails = await SharedService.getUserDetails(payload.remitter_user_id_of_refundee);
      firstname := userDetails.firstname;
      lastname := userDetails.lastname;
      email := userDetails.email;
      timezone := userDetails.timezone;
    };

    switch (transactionResponse) {
      case (#ok(transaction)) {

        let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;
        let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(payload.event_id);

        let emailResponse = await EmailService.sendNotification(
          {
            email = email;
            templateName = Constants.EmailTemplates.ResolutionRefundTemplate;
            sender = Constants.KonectAEmail;
            subject = "Confirmation: Refund for " # eventData.name;
            variables = [
              #Single(("firstname", firstname)),
              #Single(("lastname", lastname)),
              #Single(("amount", Float.toText(Float.fromInt(transaction.amount) / 100_000_000))),
              #Single(("eventName", eventData.name)),
              #Single(("priceToken", eventData.price_token)),
              #Single(("remitterFeedbackMissing", Bool.toText(payload.remitter_feedback_missing))),
              #Single(("refundDate", HelperService.getLocalDateFromNanoseconds(Nat64.toNat(transaction.created_at_time), timezone, "DD-MM-YYYY hh:mm A"))),
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
          ("user_feedback_id", #text(userFeedback.id)),
          ("expert_feedback_id", #text(payload.expert_feedback_id)),
          ("from", #text(Constants.KonectAEmail)),
          ("to", #text(email)),
          ("transaction_id", #text(transactionId)),
          ("template_name", #text(Constants.EmailTemplates.ResolutionRefundTemplate)),
          ("message_id", #text(messageId)),
          ("idempotency_key", #text(emailResponse.idempotency_key)),
        ];
        canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

        let itemResponse = await Database.createItem({
          createItemInput = {
            databaseName = Constants.KonectA;
            tableName = Constants.ResolutionResponseEmailTable;
            attributeDataValues = attributeDataValues;
          };
          alfangoDB = alfangoDB;
        });
        canistergeekLogger.logMessage("Add entry for sending refund email to remitter --->" # debug_show (itemResponse));

        switch (itemResponse) {
          case (#ok(item)) #ok(item.id);
          case (#err(error)) #err(HelperService.textArrayToString(error));
        };
      };
      case (#err(error)) {
        throw Error.reject(error);
      };
    };

  };

  public func sendEventRecordingLinkToRemitter(
    payload : ArgumentTypes.ExpertResolutionEmailRequest,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
  ) : async Result.Result<Text, Text> {
    let userFeedback = payload.user_feedback;
    let creatorFeedback = payload.creator_feedback;

    let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;
    let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(payload.event_id);

    let emailResponse = await EmailService.sendNotification(
      {
        email = userFeedback.email;
        templateName = Constants.EmailTemplates.EventRecordingTemplate;
        sender = Constants.KonectAEmail;
        subject = "Recording Available: " # eventData.name;
        variables = [
          #Single(("firstname", userFeedback.firstname)),
          #Single(("lastname", userFeedback.lastname)),
          #Single(("eventName", eventData.name)),
          #Single(("recordingLink", creatorFeedback.recording_link)),
          #Single(("startDate", HelperService.getLocalDateFromNanoseconds(eventData.start_date, userFeedback.timezone, "DD-MM-YYYY hh:mm A"))),
          #Single(("endDate", HelperService.getLocalDateFromNanoseconds(eventData.end_date, userFeedback.timezone, "DD-MM-YYYY hh:mm A"))),
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
        canistergeekLogger.logMessage("Send event recording link email to remitter error --->" # debug_show (error));
        messageId := emailResponse.message_id;
      };
    };

    let transactionId = HelperService.initializeTextField(payload.transaction_id, "");

    let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
      ("event_id", #text(payload.event_id)),
      ("user_feedback_id", #text(userFeedback.id)),
      ("expert_feedback_id", #text(payload.expert_feedback_id)),
      ("from", #text(Constants.KonectAEmail)),
      ("to", #text(userFeedback.email)),
      ("transaction_id", #text(transactionId)),
      ("template_name", #text(Constants.EmailTemplates.EventRecordingTemplate)),
      ("message_id", #text(messageId)),
      ("idempotency_key", #text(emailResponse.idempotency_key)),
    ];
    canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

    let itemResponse = await Database.createItem({
      createItemInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.ResolutionResponseEmailTable;
        attributeDataValues = attributeDataValues;
      };
      alfangoDB = alfangoDB;
    });
    canistergeekLogger.logMessage("Add entry for event recording link forwarded to user --->" # debug_show (itemResponse));

    switch (itemResponse) {
      case (#ok(item)) #ok(item.id);
      case (#err(error)) #err(HelperService.textArrayToString(error));
    };
  };

  public func resolutionResponseTableMetadata(alfangoDB : Database.AlfangoDB) : Database.GetTableMetadataOutputType {
    Database.getTableMetadata({
      getTableMetadataInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.ResolutionResponseEmailTable;
      };
      alfangoDB = alfangoDB;
    });
  };
};
