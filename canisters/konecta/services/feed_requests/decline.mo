import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import CommonService "../../services/common";
import KonectaEventReadService "../../services/event/read";
import UpdateAppliedRequestService "../../services/feed_requests/update";
import KonectaConstants "../../utils/constants";
import HelperService "../../utils/helper";

module {
  public func declineUserApplication(userPrincipal : Principal, userIdOfApplicant : Text, eventId : Text, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<Text, Text> {

    let appliedRequestsResponse = Database.scan({
      scanInput = {
        databaseName = KonectaConstants.KonectA;
        tableName = KonectaConstants.RequestAppliedTable;
        filterExpressions = [
          {
            attributeName = "event_id";
            filterExpressionCondition = #EQ(#text(eventId));
          },
          {
            attributeName = "applied_user_id";
            filterExpressionCondition = #EQ(#principal(Principal.fromText(userIdOfApplicant)));
          },
          {
            attributeName = "action";
            filterExpressionCondition = #EQ(#text(KonectaConstants.EventAttendeeStatus.Applied));
          },
        ];
      };
      alfangoDB = { databases };
    });

    switch (appliedRequestsResponse) {
      case (#ok(appliedRequests)) {
        if (Array.size(appliedRequests) == 0) {
          return #err("User has not applied for this event");
        } else {

          for (request in appliedRequests.vals()) {
            let requestId = request.id;
            let requestItem = request.item;

            let requestObject = {
              event_id = HelperService.getTupleValueAsText(requestItem, "event_id");
              applied_user_id = Principal.fromText(HelperService.getTupleValueAsText(requestItem, "applied_user_id"));
              action = KonectaConstants.EventAttendeeStatusVariant.Declined;
              timestamp = Int.abs(Time.now());
            };

            let response = UpdateAppliedRequestService.updateAppliedRequestAction(requestId, requestObject, databases);

          };
          #ok("Application declined successfully");
        };
      };

      case (#err(error)) {
        return #err(HelperService.textArrayToString(error));
      };
    };

  };
};
