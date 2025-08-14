import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import { HOUR } "mo:time-consts";

import HttpTypes "../../library/emailLibrary/email/src/email_backend/http.types";
import ForwardFeedbackToExpertService "../../services/email/forward_user_feedback/send";
import UserFeedbackReadService "../../services/email/user_feedback/read";
import SharedService "../../services/shared/shared";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../utils/helper";
import ForwardExpertFeedbackService "../email/forward_expert_feedback/send";
import UserRefundService "../payment/userRefund";
import UserTransferService "../payment/userTransfer";

module {

  public func moneyTransfer(
    canisterPrincipal : Principal,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
  ) : async Result.Result<Text, Text> {
    let errorBuffer = Buffer.Buffer<Text>(0);

    let currentTime = Int.abs(Time.now());
    Debug.print(debug_show (currentTime));

    let fortyEightHoursBefore = currentTime - (48 * HOUR);
    Debug.print(debug_show (fortyEightHoursBefore));

    let seventyTwoHoursBefore = currentTime - (72 * HOUR);
    Debug.print(debug_show (seventyTwoHoursBefore));

    let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;
    let eventsResponse = await eventCanisterActor.getCompletedEventsForCron(seventyTwoHoursBefore, fortyEightHoursBefore);

    canistergeekLogger.logMessage("Fetched completed events from Event Canister --->" # debug_show (eventsResponse));

    switch (eventsResponse) {
      case (#ok(eventsArr)) {
        if (Array.size(eventsArr) == 0) {
          return #ok("No events ended within the last 48-72 hours to process.");
        };

        for (event in eventsArr.vals()) {
          let eventType = event.event_type;

          switch (eventType) {
            case ("Request") {
              let creatorFeedback = UserFeedbackReadService.getUserFeedbackForUserByEvent(event.user_id, event.event_id, Constants.EventCompletionEmailUserType.RequestCreator, alfangoDB, canistergeekLogger);
              let accepteeResponse = await eventCanisterActor.getAttendeesByActionWithUserDetailsAsync(event.event_id, #Accepted);

              switch (accepteeResponse) {
                case (#ok(accepteeList)) {
                  if (Array.size(accepteeList) > 0) {
                    let accepteeFeedback = UserFeedbackReadService.getUserFeedbackForUserByEvent(accepteeList[0].principal_id, event.event_id, Constants.EventCompletionEmailUserType.Acceptee, alfangoDB, canistergeekLogger);
                    let missingFeedbackBuffer = Buffer.Buffer<ArgumentTypes.MissingFeedbackEmail>(0);
                    let missingFeedbackEmailBuffer = Buffer.Buffer<[(Text, Text)]>(0);

                    switch (accepteeFeedback.successful) {
                      case ("Yes") {
                        if (creatorFeedback.successful == Constants.FeedbackStatus.Yes) {
                          if (event.price_token != Constants.TokenType.FREE) {
                            let emailPayload = {
                              user_feedback = creatorFeedback;
                              creator_feedback = accepteeFeedback;
                              expert_feedback_id = "";
                              remitter_feedback_missing = false;
                            };
                            let _transferResponse = await UserTransferService.transferAmountToBeneficiary(event.user_id, event.event_id, canisterPrincipal, alfangoDB, canistergeekLogger, emailPayload, transform);
                          } else {
                            let emailPayloadObject = {
                              event_id = event.event_id;
                              remitter_user_id_of_refundee = event.user_id;
                              user_feedback = creatorFeedback;
                              creator_feedback = accepteeFeedback;
                              expert_feedback_id = "";
                              remitter_feedback_missing = false;
                              transaction_id = null;
                            };
                            canistergeekLogger.logMessage("Email Payload --->" # debug_show (emailPayloadObject));
                            if (Text.size(emailPayloadObject.creator_feedback.recording_link) > 0) {
                              let _forwardExpertFeedbackRes = ForwardExpertFeedbackService.sendEventRecordingLinkToRemitter(emailPayloadObject, alfangoDB, canistergeekLogger, transform);
                            };
                          };
                        } else if (creatorFeedback.successful == Constants.FeedbackStatus.No) {
                          if (event.price_token != Constants.TokenType.FREE) {
                            let payload = {
                              event_id = event.event_id;
                              user_feedback_id = creatorFeedback.id;
                            };
                            let _forwardResponse = await ForwardFeedbackToExpertService.forwardIssueToExpert(payload, alfangoDB, canistergeekLogger, transform);
                          };
                        } else {
                          let creatorUserData = await SharedService.getUserDetails(event.user_id);
                          missingFeedbackBuffer.add({
                            user_id = creatorUserData.principal_id;
                            firstname = creatorUserData.firstname;
                            lastname = creatorUserData.lastname;
                            username = creatorUserData.username;
                            email = creatorUserData.email;
                          });
                          missingFeedbackEmailBuffer.add([
                            ("user_id", creatorUserData.principal_id),
                            ("firstname", creatorUserData.firstname),
                            ("lastname", creatorUserData.lastname),
                            ("username", creatorUserData.username),
                            ("email", creatorUserData.email),
                          ]);
                        };

                        let missingFeedbackArray = Buffer.toArray(missingFeedbackBuffer);
                        let missingFeedbackEmailArray = Buffer.toArray(missingFeedbackEmailBuffer);

                        if (Array.size(missingFeedbackArray) > 0) {
                          let payload = {
                            event_id = event.event_id;
                            missingFeedbackUserArr = missingFeedbackArray;
                            missingFeedbackUserEmailArr = missingFeedbackEmailArray;
                          };
                          let _forwardResponse = await ForwardFeedbackToExpertService.forwardMissingFeedbackUsersToExpert(payload, alfangoDB, canistergeekLogger, transform);
                        };
                      };
                      case ("No") {
                        if (event.price_token != Constants.TokenType.FREE) {
                          let emailPayload = {
                            user_feedback = creatorFeedback;
                            creator_feedback = accepteeFeedback;
                            expert_feedback_id = "";
                            remitter_feedback_missing = false;
                          };
                          let _icrc1TransferResponse = await UserRefundService.refundAmountForCalendarEventRemoval(Principal.fromText(event.user_id), event.event_id, canisterPrincipal, alfangoDB, canistergeekLogger, emailPayload, transform);
                        };
                      };
                      case _ {
                        if (event.price_token != Constants.TokenType.FREE) {
                          let conflictFeedbackBuffer = Buffer.Buffer<ArgumentTypes.FeedbackEmail>(0);
                          let conflictFeedbackEmailBuffer = Buffer.Buffer<[(Text, Text)]>(0);

                          if (creatorFeedback.successful == Constants.FeedbackStatus.Yes) {
                            conflictFeedbackBuffer.add({
                              user_feedback_id = creatorFeedback.id;
                              username = creatorFeedback.username;
                              rating = null;
                              reason = null;
                            });
                            conflictFeedbackEmailBuffer.add([
                              ("user_feedback_id", creatorFeedback.id),
                              ("username", creatorFeedback.username),
                              ("rating", ""),
                              ("reason", ""),
                            ]);
                            let conflictFeedbackArray = Buffer.toArray(conflictFeedbackBuffer);
                            let conflictFeedbackEmailArray = Buffer.toArray(conflictFeedbackEmailBuffer);

                            if (Array.size(conflictFeedbackArray) > 0) {
                              let payload = {
                                event_id = event.event_id;
                                beneficiary_feedback_id = accepteeFeedback.id;
                                userFeedbackArr = conflictFeedbackArray;
                                userFeedbackEmailArr = conflictFeedbackEmailArray;
                              };
                              let _forwardResponse = await ForwardFeedbackToExpertService.forwardConflictFeedbacksToExpert(payload, alfangoDB, canistergeekLogger, transform);
                            };
                          } else {
                            let emailPayload = {
                              user_feedback = creatorFeedback;
                              creator_feedback = accepteeFeedback;
                              expert_feedback_id = "";
                              remitter_feedback_missing = false;
                            };
                            let _icrc1TransferResponse = await UserRefundService.refundAmountForCalendarEventRemoval(Principal.fromText(event.user_id), event.event_id, canisterPrincipal, alfangoDB, canistergeekLogger, emailPayload, transform);
                          };
                        };
                      };
                    };
                  } else {
                    errorBuffer.add("No acceptee found for service request of event: " # event.event_id);
                  };
                };
                case (#err(error)) {
                  errorBuffer.add("Failed to get acceptee for service request: " # HelperService.textArrayToString(error));
                };
              };
            };
            case ("Offer") {
              let creatorFeedback = UserFeedbackReadService.getUserFeedbackForUserByEvent(event.user_id, event.event_id, Constants.EventCompletionEmailUserType.OfferCreator, alfangoDB, canistergeekLogger);
              let attendeesArrResponse = await eventCanisterActor.getAttendeesByActionWithUserDetailsAsync(event.event_id, Constants.EventAttendeeStatusVariant.Joined);

              switch (attendeesArrResponse) {
                case (#ok(attendeesArr)) {
                  switch (creatorFeedback.successful) {
                    case ("Yes") {
                      let positiveFeedbackBuffer = Buffer.Buffer<ArgumentTypes.FeedbackEmail>(0);
                      let positiveFeedbackEmailBuffer = Buffer.Buffer<[(Text, Text)]>(0);
                      let negativeFeedbackBuffer = Buffer.Buffer<ArgumentTypes.FeedbackEmail>(0);
                      let negativeFeedbackEmailBuffer = Buffer.Buffer<[(Text, Text)]>(0);
                      let missingFeedbackBuffer = Buffer.Buffer<ArgumentTypes.MissingFeedbackEmail>(0);
                      let missingFeedbackEmailBuffer = Buffer.Buffer<[(Text, Text)]>(0);

                      for (attendee in attendeesArr.vals()) {
                        let attendeeFeedbackResponse = UserFeedbackReadService.getUserFeedbackForUserByEvent(attendee.principal_id, event.event_id, Constants.EventCompletionEmailUserType.Attendee, alfangoDB, canistergeekLogger);

                        if (attendeeFeedbackResponse.successful == Constants.FeedbackStatus.Yes) {
                          if (event.price_token != Constants.TokenType.FREE) {
                            let emailPayload = {
                              user_feedback = attendeeFeedbackResponse;
                              creator_feedback = creatorFeedback;
                              expert_feedback_id = "";
                              remitter_feedback_missing = false;
                            };
                            let _transferResponse = await UserTransferService.transferAmountToBeneficiary(attendee.principal_id, event.event_id, canisterPrincipal, alfangoDB, canistergeekLogger, emailPayload, transform);
                            positiveFeedbackBuffer.add({
                              user_feedback_id = attendeeFeedbackResponse.id;
                              username = attendeeFeedbackResponse.username;
                              rating = ?attendeeFeedbackResponse.rating;
                              reason = null;
                            });
                            positiveFeedbackEmailBuffer.add([
                              ("user_feedback_id", attendeeFeedbackResponse.id),
                              ("username", attendeeFeedbackResponse.username),
                              ("rating", Nat.toText(attendeeFeedbackResponse.rating)),
                              ("reason", ""),
                            ]);
                          } else {
                            let emailPayloadObject = {
                              event_id = event.event_id;
                              remitter_user_id_of_refundee = attendee.principal_id;
                              user_feedback = attendeeFeedbackResponse;
                              creator_feedback = creatorFeedback;
                              expert_feedback_id = "";
                              remitter_feedback_missing = false;
                              transaction_id = null;
                            };
                            canistergeekLogger.logMessage("Email Payload --->" # debug_show (emailPayloadObject));
                            if (Text.size(emailPayloadObject.creator_feedback.recording_link) > 0) {
                              let _forwardExpertFeedbackRes = ForwardExpertFeedbackService.sendEventRecordingLinkToRemitter(emailPayloadObject, alfangoDB, canistergeekLogger, transform);
                            };
                          };
                        } else if (attendeeFeedbackResponse.successful == Constants.FeedbackStatus.No) {
                          if (event.price_token != Constants.TokenType.FREE) {
                            negativeFeedbackBuffer.add({
                              user_feedback_id = attendeeFeedbackResponse.id;
                              username = attendeeFeedbackResponse.username;
                              rating = null;
                              reason = ?attendeeFeedbackResponse.reason;
                            });
                            negativeFeedbackEmailBuffer.add([
                              ("user_feedback_id", attendeeFeedbackResponse.id),
                              ("username", attendeeFeedbackResponse.username),
                              ("rating", ""),
                              ("reason", attendeeFeedbackResponse.reason),
                            ]);
                          };
                        } else {
                          missingFeedbackBuffer.add({
                            user_id = attendee.principal_id;
                            firstname = attendee.firstname;
                            lastname = attendee.lastname;
                            username = attendee.username;
                            email = attendee.email;
                          });
                          missingFeedbackEmailBuffer.add([
                            ("user_id", attendee.principal_id),
                            ("firstname", attendee.firstname),
                            ("lastname", attendee.lastname),
                            ("username", attendee.username),
                            ("email", attendee.email),
                          ]);
                        };
                      };

                      let positiveFeedbackArray = Buffer.toArray(positiveFeedbackBuffer);
                      let positiveFeedbackEmailArray = Buffer.toArray(positiveFeedbackEmailBuffer);
                      let negativeFeedbackArray = Buffer.toArray(negativeFeedbackBuffer);
                      let negativeFeedbackEmailArray = Buffer.toArray(negativeFeedbackEmailBuffer);
                      let missingFeedbackArray = Buffer.toArray(missingFeedbackBuffer);
                      let missingFeedbackEmailArray = Buffer.toArray(missingFeedbackEmailBuffer);

                      if (Array.size(positiveFeedbackArray) > 0) {
                        let payload = {
                          event_id = event.event_id;
                          beneficiary_feedback_id = creatorFeedback.id;
                          userFeedbackArr = positiveFeedbackArray;
                          userFeedbackEmailArr = positiveFeedbackEmailArray;
                        };
                        let _forwardResponse = await ForwardFeedbackToExpertService.forwardMultipleRatingsToExpert(payload, alfangoDB, canistergeekLogger, transform);
                      };
                      if (Array.size(negativeFeedbackArray) > 0) {
                        let payload = {
                          event_id = event.event_id;
                          beneficiary_feedback_id = creatorFeedback.id;
                          userFeedbackArr = negativeFeedbackArray;
                          userFeedbackEmailArr = negativeFeedbackEmailArray;
                        };
                        let _forwardResponse = await ForwardFeedbackToExpertService.forwardMultipleIssueToExpert(payload, alfangoDB, canistergeekLogger, transform);
                      };
                      if (Array.size(missingFeedbackArray) > 0) {
                        let payload = {
                          event_id = event.event_id;
                          missingFeedbackUserArr = missingFeedbackArray;
                          missingFeedbackUserEmailArr = missingFeedbackEmailArray;
                        };
                        let _forwardResponse = await ForwardFeedbackToExpertService.forwardMissingFeedbackUsersToExpert(payload, alfangoDB, canistergeekLogger, transform);
                      };
                    };
                    case ("No") {
                      if (event.price_token != Constants.TokenType.FREE) {
                        for (attendee in attendeesArr.vals()) {
                          let attendeeFeedbackResponse = UserFeedbackReadService.getUserFeedbackForUserByEvent(attendee.principal_id, event.event_id, Constants.EventCompletionEmailUserType.Attendee, alfangoDB, canistergeekLogger);
                          let emailPayload = {
                            user_feedback = attendeeFeedbackResponse;
                            creator_feedback = creatorFeedback;
                            expert_feedback_id = "";
                            remitter_feedback_missing = false;
                          };
                          let _icrc1TransferResponse = await UserRefundService.refundAmountForCalendarEventRemoval(Principal.fromText(attendee.principal_id), event.event_id, canisterPrincipal, alfangoDB, canistergeekLogger, emailPayload, transform);
                        };
                      };
                    };
                    case _ {
                      if (event.price_token != Constants.TokenType.FREE) {
                        let conflictFeedbackBuffer = Buffer.Buffer<ArgumentTypes.FeedbackEmail>(0);
                        let conflictFeedbackEmailBuffer = Buffer.Buffer<[(Text, Text)]>(0);
                        let successfulAsPerAttendeeBuffer = Buffer.Buffer<Text>(0);

                        for (attendee in attendeesArr.vals()) {
                          let attendeeFeedbackResponse = UserFeedbackReadService.getUserFeedbackForUserByEvent(attendee.principal_id, event.event_id, Constants.EventCompletionEmailUserType.Attendee, alfangoDB, canistergeekLogger);
                          conflictFeedbackBuffer.add({
                            user_feedback_id = attendeeFeedbackResponse.id;
                            username = attendeeFeedbackResponse.username;
                            rating = null;
                            reason = null;
                          });
                          conflictFeedbackEmailBuffer.add([
                            ("user_feedback_id", attendeeFeedbackResponse.id),
                            ("username", attendeeFeedbackResponse.username),
                            ("rating", ""),
                            ("reason", ""),
                          ]);
                          if (attendeeFeedbackResponse.successful == Constants.FeedbackStatus.Yes) {
                            successfulAsPerAttendeeBuffer.add(attendeeFeedbackResponse.successful);
                          };
                        };

                        let successfulAsPerAttendeeArray = Buffer.toArray(successfulAsPerAttendeeBuffer);
                        if (Array.size(successfulAsPerAttendeeArray) > 0) {
                          let conflictFeedbackArray = Buffer.toArray(conflictFeedbackBuffer);
                          let conflictFeedbackEmailArray = Buffer.toArray(conflictFeedbackEmailBuffer);

                          if (Array.size(conflictFeedbackArray) > 0) {
                            let payload = {
                              event_id = event.event_id;
                              beneficiary_feedback_id = creatorFeedback.id;
                              userFeedbackArr = conflictFeedbackArray;
                              userFeedbackEmailArr = conflictFeedbackEmailArray;
                            };
                            let _forwardResponse = await ForwardFeedbackToExpertService.forwardConflictFeedbacksToExpert(payload, alfangoDB, canistergeekLogger, transform);
                          };
                        } else {
                          for (attendee in attendeesArr.vals()) {
                            let attendeeFeedbackResponse = UserFeedbackReadService.getUserFeedbackForUserByEvent(attendee.principal_id, event.event_id, Constants.EventCompletionEmailUserType.Attendee, alfangoDB, canistergeekLogger);
                            let emailPayload = {
                              user_feedback = attendeeFeedbackResponse;
                              creator_feedback = creatorFeedback;
                              expert_feedback_id = "";
                              remitter_feedback_missing = false;
                            };
                            let _icrc1TransferResponse = await UserRefundService.refundAmountForCalendarEventRemoval(Principal.fromText(attendee.principal_id), event.event_id, canisterPrincipal, alfangoDB, canistergeekLogger, emailPayload, transform);
                          };
                        };
                      };
                    };
                  };
                };
                case (#err(error)) {
                  errorBuffer.add("Failed to get attendees for service offer: " # HelperService.textArrayToString(error));
                };
              };
            };
            case _ {
              errorBuffer.add("Event data seems to be incorrect");
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
      #ok("Job completed successfully");
    };
  };
};
