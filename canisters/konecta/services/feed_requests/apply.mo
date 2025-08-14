import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";

import SharedService "../../services/shared/shared";
import ArgumentTypes "../../types/argumentTypes";
import KonectaConstants "../../utils/constants";
import UserActionEmailService "../../services/email/user_action/send";
import HttpTypes "../../library/emailLibrary/email/src/email_backend/http.types";
import Database "mo:alfangodb/AlfangoDB";

module {
  /**
   * Orchestrates the process of a user applying to a service request.
   * It calls the Event canister to record the application and triggers a notification.
   */
  public func applyToServiceRequest(
    applicantPrincipal : Principal,
    payload : ArgumentTypes.ApplyToServiceRequestPayload,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, Text> {

    let eventCanister = actor (KonectaConstants.EventCanister) : SharedService.EventCanisterType;

    // 1. Fetch the event details. We need this for validation and for the notification.
    let eventData = await eventCanister.getEventDetailsWithUserDataAsync(payload.event_id);
    if (Text.size(eventData.event_id) == 0) {
      return #err("The event you are trying to apply for does not exist.");
    };
    if (eventData.event_type != KonectaConstants.EventType.Request) {
      return #err("You can only apply to events of type 'Request'.");
    };

    // 2. Construct the payload for the Event canister.
    let attendeePayload : ArgumentTypes.EventAttendeeRequestPayload = {
      event_id = payload.event_id;
      invitee_user_id = applicantPrincipal;
      action = #Applied;
      timestamp = Int.abs(Time.now());
      event_status = eventData.status;
      event_type = eventData.event_type;
      participation_type = eventData.participation_type;
    };

    canistergeekLogger.logMessage("Applying to service request with payload: " # debug_show (attendeePayload));

    // 3. Call the Event canister to add the attendee record. This is the critical part.
    let result = await eventCanister.addEventAttendee(attendeePayload);

    switch (result) {
      case (#ok(attendeeId)) {
        // 4. Fire-and-forget the notification.
        ignore UserActionEmailService.sendNewApplicationEmail(
          applicantPrincipal,
          eventData,
          transform,
          alfangoDB,
          canistergeekLogger,
        );

        return #ok(attendeeId);
      };
      case (#err(errorMessage)) {
        return #err("Failed to apply: " # errorMessage);
      };
    };
  };
};
