import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import UpdateAppliedRequestService "../../services/feed_requests/update";
import KonectaConstants "../../utils/constants";
import HelperService "../../../shared/common_utils/helper";
import SharedConstants "../../../shared/constants";
import SharedTypes "../../../shared/types";

module {
  public func declineUserApplication(
    _userPrincipal : Principal,
    userIdOfApplicant : Text,
    eventId : Text,
    databases : Map.Map<Text, Database.Database>,
    _canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, Text> {
    let appliedRequestsResponse = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
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
            filterExpressionCondition = #EQ(#text(SharedTypes.EventAttendeeStatus.Applied));
          },
        ];
      };
      alfangoDB = { databases };
    });

    switch (appliedRequestsResponse) {
      case (#ok(appliedRequests)) {
        if (Array.size(appliedRequests) == 0) {
          return #err("User has not applied for this event or the application has already been actioned.");
        };

        let requestToUpdate = appliedRequests[0];
        let requestId = requestToUpdate.id;
        let requestItem = requestToUpdate.item;

        let requestObject = {
          event_id = HelperService.getTupleValueAsText(requestItem, "event_id");
          applied_user_id = Principal.fromText(HelperService.getTupleValueAsText(requestItem, "applied_user_id"));
          action = KonectaConstants.EventAttendeeStatusVariant.Declined;
          timestamp = Int.abs(Time.now());
        };

        let updateResult = UpdateAppliedRequestService.updateAppliedRequestAction(requestId, requestObject, databases);

        switch (updateResult) {
          case (#ok(_)) {
            return #ok("Application declined successfully");
          };
          case (#err(error)) {
            return #err("Failed to update application status: " # HelperService.textArrayToString([error]));
          };
        };
      };

      case (#err(error)) {
        return #err(HelperService.textArrayToString(error));
      };
    };
  };
};
