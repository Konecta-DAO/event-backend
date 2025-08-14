import Database "mo:alfangodb/AlfangoDB";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";

import SharedService "../../services/shared/shared";
import KonectaConstants "../../utils/constants";
import { textArrayToString } "../../utils/helper";

module {
  // Function to join a public event
  public func joinPublicEvent(
    userIdOfJoinee : Principal,
    eventId : Text,
    _alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, Text> {

    // 1. Get the event details from the single source of truth: the Event canister
    let eventCanisterActor = actor (KonectaConstants.EventCanister) : SharedService.EventCanisterType;
    let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(eventId);

    canistergeekLogger.logMessage("Event Data for join --->" # debug_show (eventData));

    // 2. Check if the event exists
    if (Text.size(eventData.event_id) == 0) {
      return #err("Event not found.");
    };

    // 3. Use the orchestration helper to add attendee to Event canister and update their calendar
    let response = await SharedService.addEventAttendee(
      Principal.fromText(eventData.user_id),
      userIdOfJoinee,
      KonectaConstants.EventAttendeeStatusVariant.Joined,
      eventData,
      canistergeekLogger,
    );

    switch (response) {
      case (#ok(true)) {
        #ok("User joined the event successfully");
      };
      case (#ok(false)) {
        #err("A false boolean was returned from the helper, something is wrong.");
      };
      case (#err(error)) {
        #err(error);
      };
    };
  };
};
