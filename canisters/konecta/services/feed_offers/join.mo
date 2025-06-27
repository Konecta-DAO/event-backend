import Database "mo:alfangodb/AlfangoDB";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import CommonService "../../services/common";
import KonectaEventReadService "../../services/event/read";
import KonectaConstants "../../utils/constants";
import { textArrayToString } "../../../shared/common_utils/helper";

module {
  // Function to join a public event
  public func joinPublicEvent(userIdOfJoinee : Principal, eventId : Text, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<Text, Text> {

    var response = "";

    // Get the feed details for the event
    let eventData = await KonectaEventReadService.getFeedDetailsByEventId(eventId, databases);
    Debug.print("Event Data --->" # debug_show (eventData));
    canistergeekLogger.logMessage("Event Data --->" # debug_show (eventData));

    switch (eventData) {
      case (#ok(feedData)) {
        let response = await CommonService.addEventAttendee(Principal.fromText(feedData.user_id), userIdOfJoinee, KonectaConstants.EventAttendeeStatusVariant.Joined, feedData, canistergeekLogger);

        switch (response) {
          case (#ok(joined)) {
            if (joined) {
              return #ok("User joined the event successfully");
            } else {
              return #err("Error joining the event");
            };

          };

          case (#err(error)) {
            return #err(error);
          };
        };

      };

      case (#err(error)) {
        // If there was an error getting the feed details, set the response to the error message
        response := textArrayToString(error);
        return #err(response);
      };
    };
  };
};
