import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";
import { JSON } "mo:serde";

import EmailService "../../../library/emailLibrary/email/src/email_backend";
import HttpTypes "../../../library/emailLibrary/email/src/email_backend/http.types";
import SharedService "../../shared/shared";
import ArgumentTypes "../../../types/argumentTypes";
import Constants "../../../utils/constants";
import HelperService "../../../utils/helper";
import Database "mo:alfangodb/AlfangoDB";

module {
  /**
   * Fetches necessary data and sends an email notification to the event creator
   * about a new application for their service request.
   */
  public func sendNewApplicationEmail(
    applicantPrincipal : Principal,
    eventData : ArgumentTypes.EventProtocolCanisterPayload,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : async () {

    // The event creator's data is already in the event payload
    let creatorData = eventData.userData;

    // We need to fetch the applicant's data
    let applicantData = await SharedService.getUserDetails(Principal.toText(applicantPrincipal));

    if (Text.size(creatorData.email) == 0) {
      canistergeekLogger.logMessage("Could not send application email: Creator email is missing for event " # eventData.event_id);
      return;
    };

    let eventDate = HelperService.getLocalDateFromNanoseconds(eventData.start_date, creatorData.timezone, "DD-MM-YYYY hh:mm A");

    // Construct the email payload
    let emailResponse = await EmailService.sendNotification(
      {
        email = creatorData.email;
        templateName = Constants.EmailTemplates.NewApplicationForServiceRequest;
        sender = Constants.KonectAEmail;
        subject = "You have a new applicant for: " # eventData.name;
        variables = [
          #Single(("creatorFirstname", creatorData.firstname)),
          #Single(("eventName", eventData.name)),
          #Single(("eventDate", eventDate)),
          #Single(("applicantName", applicantData.firstname # " " # applicantData.lastname)),
          #Single(("eventId", eventData.event_id)), // Used for creating a link in the email
        ];
      },
      transform,
    );

    // Record the email action for auditing purposes
    var messageId = emailResponse.message_id;

    let jsonResult = JSON.fromText(messageId, null);
    switch (jsonResult) {
      case (#ok(blob)) {
        let mailgunResponse : ?ArgumentTypes.MailgunResponse = from_candid (blob);

        // Use a switch statement to safely unwrap the optionals
        switch (mailgunResponse) {
          case (?response) {
            // Now that we have a non-null `response`, we can check its `id` field
            switch (response.id) {
              case (?id) {
                messageId := id;
              };
              case (null) {};
            };
          };
          case (null) {};
        };
      };
      case (#err(_)) {
        // JSON parsing failed, do nothing and use the original messageId
      };
    };

    let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
      ("event_id", #text(eventData.event_id)),
      ("from_user_id", #text(Principal.toText(applicantPrincipal))),
      ("to_user_id", #text(creatorData.principal_id)),
      ("action", #text(Constants.EventAttendeeStatus.Applied)),
      ("from", #text(applicantData.email)),
      ("to", #text(creatorData.email)),
      ("template_name", #text(Constants.EmailTemplates.NewApplicationForServiceRequest)),
      ("message_id", #text(messageId)),
      ("idempotency_key", #text(emailResponse.idempotency_key)),
      ("timestamp", #nat(Int.abs(Time.now()))),
    ];

    let itemResponse = await Database.createItem({
      createItemInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.UserActionEmailTable;
        attributeDataValues = attributeDataValues;
      };
      alfangoDB = alfangoDB;
    });

    canistergeekLogger.logMessage("New application email record created: " # debug_show (itemResponse));
  };
};
