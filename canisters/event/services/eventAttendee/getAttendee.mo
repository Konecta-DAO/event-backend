import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Map "mo:map/Map";
import SharedTypes "../../../shared/types";
import SharedConstants "../../../shared/constants";
import SharedServices "../../../shared/services";
import EventConstants "../../utils/constants";
import { getTupleValueAsText } "../../../shared/common_utils/helper";
import CommonService "../common";

module {
  public func checkIfAttendeeExistsForEvent(userPrincipal : Principal, eventId : Text, databases : Map.Map<Text, Database.Database>) : Bool {
    Debug.print(debug_show (userPrincipal));
    Debug.print(debug_show (eventId));
    var exists = false;

    let eventResponse = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filterExpressions = [
          {
            attributeName = "event_id";
            filterExpressionCondition = #EQ(#text(eventId));
          },
          {
            attributeName = "invitee_user_id";
            filterExpressionCondition = #EQ(#principal(userPrincipal));
          },
        ];
      };
      alfangoDB = { databases };
    });

    Debug.print(debug_show (eventResponse));
    switch (eventResponse) {
      case (#ok(attendees)) {
        if (Array.size(attendees) > 0) {
          exists := true;
        } else {
          exists := false;
        };
      };
      case (#err(_err)) exists := false;
    };

    return exists;
  };

  public func getAttendeesByActionWithUserDetails(eventId : Text, action : SharedTypes.EventAttendeeActions, databases : Map.Map<Text, Database.Database>) : async Result.Result<[SharedTypes.UserResponsePayload], [Text]> {

    let actionType = CommonService.getActionType(action);

    let attendees = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filterExpressions = [
          {
            attributeName = "event_id";
            filterExpressionCondition = #EQ(#text(eventId));
          },
          {
            attributeName = "action";
            filterExpressionCondition = #EQ(#text(actionType));
          },
        ];
      };
      alfangoDB = { databases };
    });

    switch (attendees) {
      case (#ok(attendeeData)) {
        let userDataBuffer = Buffer.Buffer<SharedTypes.UserResponsePayload>(0);

        for (attendee in attendeeData.vals()) {
          let itemData = attendee.item;

          let user = await SharedServices.getUserDetails(getTupleValueAsText(itemData, "invitee_user_id"));
          userDataBuffer.add(user);
        };

        let userDataArray = Buffer.toArray(userDataBuffer);
        #ok(userDataArray);
      };
      case (#err(err)) {
        #err(err);
      };
    };
  };

  public func getAttendeesIdsByAction(eventId : Text, action : SharedTypes.EventAttendeeActions, databases : Map.Map<Text, Database.Database>) : Result.Result<[Text], [Text]> {

    let actionType = CommonService.getActionType(action);

    let attendees = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filterExpressions = [
          {
            attributeName = "event_id";
            filterExpressionCondition = #EQ(#text(eventId));
          },
          {
            attributeName = "action";
            filterExpressionCondition = #EQ(#text(actionType));
          },
        ];
      };
      alfangoDB = { databases };
    });

    switch (attendees) {
      case (#ok(attendeeData)) {
        let userIdBuffer = Buffer.Buffer<Text>(0);

        for (attendee in attendeeData.vals()) {
          let itemData = attendee.item;

          let user = getTupleValueAsText(itemData, "invitee_user_id");
          userIdBuffer.add(user);
        };

        Buffer.removeDuplicates<Text>(userIdBuffer, Text.compare);
        let userIdArray = Buffer.toArray(userIdBuffer);
        #ok(userIdArray);
      };
      case (#err(err)) {
        #err(err);
      };
    };

  };

  public func getAllAttendeesIds(eventId : Text, databases : Map.Map<Text, Database.Database>) : Result.Result<[Text], [Text]> {

    let attendees = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filterExpressions = [{
          attributeName = "event_id";
          filterExpressionCondition = #EQ(#text(eventId));
        }];
      };
      alfangoDB = { databases };
    });

    switch (attendees) {
      case (#ok(attendeeData)) {
        let userIdBuffer = Buffer.Buffer<Text>(0);

        for (attendee in attendeeData.vals()) {
          let itemData = attendee.item;

          let user = getTupleValueAsText(itemData, "invitee_user_id");
          userIdBuffer.add(user);
        };

        Buffer.removeDuplicates<Text>(userIdBuffer, Text.compare);
        let userIdArray = Buffer.toArray(userIdBuffer);
        #ok(userIdArray);
      };
      case (#err(err)) {
        #err(err);
      };
    };

  };

  public func getEventsForAttendee(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>) : Result.Result<[Text], [Text]> {

    let events = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filterExpressions = [
          {
            attributeName = "invitee_user_id";
            filterExpressionCondition = #EQ(#principal(userPrincipal));
          },
          {
            attributeName = "action";
            filterExpressionCondition = #EQ(#text(SharedTypes.EventAttendeeStatus.Joined));
          },
        ];
      };
      alfangoDB = { databases };
    });

    switch (events) {
      case (#ok(eventAttendeesData)) {
        let eventIdBuffer = Buffer.Buffer<Text>(0);

        for (eventAttendee in eventAttendeesData.vals()) {
          let itemData = eventAttendee.item;

          let eventId = getTupleValueAsText(itemData, "event_id");
          eventIdBuffer.add(eventId);
        };

        Buffer.removeDuplicates<Text>(eventIdBuffer, Text.compare);
        let eventIdArray = Buffer.toArray(eventIdBuffer);
        #ok(eventIdArray);
      };
      case (#err(err)) {
        #err(err);
      };
    };

  };
};
