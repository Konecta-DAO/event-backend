import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import SharedConstants "../../../shared/constants";
import SharedInterfaces "../../../shared/interfaces";
import SharedTypes "../../../shared/types";
import SharedServices "../../../shared/services";
import CommonService "../../services/common";
import KonectaEventReadService "../../services/event/read";
import UpdateAppliedRequestService "../../services/feed_requests/update";
import KonectaConstants "../../utils/constants";
import HelperService "../../../shared/common_utils/helper";

module {
  public func acceptUserApplication(userPrincipal : Principal, userIdOfApplicant : Text, eventId : Text, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<Text, Text> {

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
          return #err("User has not applied for this event");
        } else {
          for (request in appliedRequests.vals()) {
            let requestId = request.id;
            let requestItem = request.item;

            let requestObject = {
              event_id = HelperService.getTupleValueAsText(requestItem, "event_id");
              applied_user_id = Principal.fromText(HelperService.getTupleValueAsText(requestItem, "applied_user_id"));
              action = KonectaConstants.EventAttendeeStatusVariant.Accepted;
              timestamp = Int.abs(Time.now());
            };

            let _response = UpdateAppliedRequestService.updateAppliedRequestAction(requestId, requestObject, databases);
          };

          // Get the feed details for the event
          let eventData = await KonectaEventReadService.getFeedDetailsByEventId(eventId, databases);
          Debug.print("Event Data --->" # debug_show (eventData));
          canistergeekLogger.logMessage("Event Data --->" # debug_show (eventData));

          switch (eventData) {
            case (#ok(feedData)) {
              let response = await CommonService.addEventAttendee(userPrincipal, Principal.fromText(userIdOfApplicant), KonectaConstants.EventAttendeeStatusVariant.Accepted, feedData, canistergeekLogger);

              switch (response) {
                case (#ok(accepted)) {
                  if (accepted) {
                    let eventCanisterActor = actor (SharedConstants.EventCanister) : SharedInterfaces.EventActor;
                    let userCanisterId = await SharedServices.getUserCanisterId(Principal.toText(userPrincipal));

                    var eventStatus : SharedTypes.EventStatus = SharedTypes.EventStatusVariant.Created;
                    switch (feedData.status) {
                      case ("Created") eventStatus := SharedTypes.EventStatusVariant.Created;
                      case ("Canceled") eventStatus := SharedTypes.EventStatusVariant.Canceled;
                      case _ eventStatus := SharedTypes.EventStatusVariant.Created;
                    };

                    let eventObject = {
                      user_id = ?Principal.fromText(feedData.user_id);
                      coverphoto = feedData.coverphoto;
                      name = feedData.name;
                      description = feedData.description;
                      location = HelperService.getTupleValueAsText(appliedRequests[0].item, "location");
                      start_date = feedData.start_date;
                      end_date = feedData.end_date;
                      language = ?feedData.language;
                      status = eventStatus;
                      metadata = ?feedData.eventMetadata;
                    };

                    let updateEventResponse = await eventCanisterActor.updateEventUsingUserPrincipal(userPrincipal, userCanisterId, eventId, eventObject);

                    switch (updateEventResponse) {
                      case (#ok(response)) #ok("Application accepted successfully");
                      case (#err(_error)) #err("Error accepting application");
                    };

                  } else {
                    return #err("Error accepting application");
                  };

                };

                case (#err(error)) {
                  return #err(error);
                };
              };
            };

            case (#err(error)) {
              // If there was an error getting the feed details, set the response to the error message
              return #err(HelperService.textArrayToString(error));
            };
          };

        };

      };
      case (#err(error)) {
        return #err(HelperService.textArrayToString(error));
      };
    };

  };
};
