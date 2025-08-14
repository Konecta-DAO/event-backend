import Database "mo:alfangodb/AlfangoDB";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import { JSON } "mo:serde";
import { HOUR } "mo:time-consts";
import Nat "mo:base/Nat";
import EmailService "../../library/emailLibrary/email/src/email_backend";
import HttpTypes "../../library/emailLibrary/email/src/email_backend/http.types";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../utils/helper";
import SharedService "../shared/shared";
import TransformService "../shared/transform";

module {
  public func sendEventCompletionEmail(
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
  ) : async Result.Result<Text, Text> {
    let currentTime = Int.abs(Time.now());
    let oneDayBefore = currentTime - (24 * HOUR);

    let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;

    let errorBuffer = Buffer.Buffer<Text>(0);
    var successResponse = "";

    let eventsResponse = await eventCanisterActor.getCompletedEventsForCron(oneDayBefore, currentTime);
    canistergeekLogger.logMessage("Completed events from Event Canister ---> " # debug_show (eventsResponse));

    switch (eventsResponse) {
      case (#ok(eventsArr)) {
        if (Array.size(eventsArr) == 0) {
          successResponse := "No events ended within the last 24 hours to process.";
        } else {
          for (eventData in eventsArr.vals()) {
            let eventType = eventData.event_type;

            switch (eventType) {
              case ("Request") {
                let startDate = HelperService.getLocalDateFromNanoseconds(eventData.start_date, eventData.userData.timezone, "DD-MM-YYYY hh:mm A");
                let endDate = HelperService.getLocalDateFromNanoseconds(eventData.end_date, eventData.userData.timezone, "DD-MM-YYYY hh:mm A");
                let eventLocation = if (Text.size(eventData.location) > 0) eventData.location else "Location information not available";

                let emailResponse = await EmailService.sendNotification(
                  {
                    email = eventData.userData.email;
                    templateName = Constants.EmailTemplates.EventCompletionTemplate;
                    sender = Constants.KonectAEmail;
                    subject = eventData.name # " Event Experience Survey";
                    variables = [
                      #Single(("firstname", eventData.userData.firstname)),
                      #Single(("lastname", eventData.userData.lastname)),
                      #Single(("eventId", eventData.event_id)),
                      #Single(("eventName", eventData.name)),
                      #Single(("eventDate", startDate # " - " # endDate)),
                      #Single(("eventLocation", eventLocation)),
                      #Single(("userId", eventData.user_id)),
                    ];
                  },
                  transform,
                );

                var messageId = emailResponse.message_id;
                if (Text.startsWith(messageId, #char '<') and Text.endsWith(messageId, #char '>')) {
                  messageId := Text.trimStart(messageId, #char '<');
                  messageId := Text.trimEnd(messageId, #char '>');
                };

                let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
                  ("event_id", #text(eventData.event_id)),
                  ("user_id", #text(eventData.user_id)),
                  ("user_type", #text(Constants.EventCompletionEmailUserType.RequestCreator)),
                  ("recipient_type", #text(Constants.PaymentUserType.Remitter)),
                  ("notification_type", #text(Constants.NotificationType.Email)),
                  ("template_name", #text(Constants.EmailTemplates.EventCompletionTemplate)),
                  ("from", #text(Constants.KonectAEmail)),
                  ("to", #text(eventData.userData.email)),
                  ("message_id", #text(messageId)),
                  ("idempotency_key", #text(emailResponse.idempotency_key)),
                ];
                let item = await Database.createItem({
                  createItemInput = {
                    databaseName = Constants.KonectA;
                    tableName = Constants.EventCompletionNotificationTable;
                    attributeDataValues = attributeDataValues;
                  };
                  alfangoDB = alfangoDB;
                });
                canistergeekLogger.logMessage("Add send email to request creator entry --->" # debug_show (item));
                successResponse := "Email sent successfully to event creator";
              };

              case ("Offer") {
                let attendeesArr = await eventCanisterActor.getAttendeesByActionWithUserDetailsAsync(eventData.event_id, Constants.EventAttendeeStatusVariant.Joined);

                switch (attendeesArr) {
                  case (#ok(attendees)) {
                    for (attendee in attendees.vals()) {
                      let startDate = HelperService.getLocalDateFromNanoseconds(eventData.start_date, attendee.timezone, "DD-MM-YYYY hh:mm A");
                      let endDate = HelperService.getLocalDateFromNanoseconds(eventData.end_date, attendee.timezone, "DD-MM-YYYY hh:mm A");

                      let emailResponse = await EmailService.sendNotification(
                        {
                          email = attendee.email;
                          templateName = Constants.EmailTemplates.EventCompletionTemplate;
                          sender = Constants.KonectAEmail;
                          subject = eventData.name # " Event Experience Survey";
                          variables = [
                            #Single(("firstname", attendee.firstname)),
                            #Single(("lastname", attendee.lastname)),
                            #Single(("eventId", eventData.event_id)),
                            #Single(("eventName", eventData.name)),
                            #Single(("eventDate", startDate # " - " # endDate)),
                            #Single(("eventLocation", eventData.location)),
                            #Single(("userId", attendee.principal_id)),
                          ];
                        },
                        transform,
                      );

                      var messageId = emailResponse.message_id;
                      if (Text.startsWith(messageId, #char '<') and Text.endsWith(messageId, #char '>')) {
                        messageId := Text.trimStart(messageId, #char '<');
                        messageId := Text.trimEnd(messageId, #char '>');
                      };

                      let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
                        ("event_id", #text(eventData.event_id)),
                        ("user_id", #text(attendee.principal_id)),
                        ("user_type", #text(Constants.EventCompletionEmailUserType.Attendee)),
                        ("recipient_type", #text(Constants.PaymentUserType.Remitter)),
                        ("notification_type", #text(Constants.NotificationType.Email)),
                        ("template_name", #text(Constants.EmailTemplates.EventCompletionTemplate)),
                        ("from", #text(Constants.KonectAEmail)),
                        ("to", #text(attendee.email)),
                        ("message_id", #text(messageId)),
                        ("idempotency_key", #text(emailResponse.idempotency_key)),
                      ];
                      canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

                      let item = await Database.createItem({
                        createItemInput = {
                          databaseName = Constants.KonectA;
                          tableName = Constants.EventCompletionNotificationTable;
                          attributeDataValues = attributeDataValues;
                        };
                        alfangoDB = alfangoDB;
                      });
                      canistergeekLogger.logMessage("Add send email to attendee entry --->" # debug_show (item));
                    };
                    successResponse := "Email sent successfully to all attendees";
                  };
                  case (#err(error)) {
                    errorBuffer.add(HelperService.textArrayToString(error));
                  };
                };
              };

              case _ {
                errorBuffer.add("Failed to send event completion email: Invalid event type.");
              };
            };
          };
        };
      };
      case (#err(error)) {
        errorBuffer.add(HelperService.textArrayToString(error));
      };
    };

    let errorArray = Buffer.toArray(errorBuffer);
    if (Array.size(errorArray) > 0) {
      #err(HelperService.textArrayToString(errorArray));
    } else {
      #ok(successResponse);
    };
  };
};
