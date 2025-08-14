import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Canistergeek "mo:canistergeek/canistergeek";
import HashMap "mo:base/HashMap";
import CommonService "../../services/common";
import EventReadService "../../services/event/read";
import ArgumentTypes "../../types/argumentTypes";
import EventConstants "../../utils/constants";
import HelperService "../../utils/helper";
import GetAttendeeService "../eventAttendee/getAttendee";

module {
  public func addEventAttendee(payload : ArgumentTypes.EventAttendeeRequestPayload, alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) : async Result.Result<Text, Text> {

    let attendeeCount = GetAttendeeService.getEventAttendeeCount(payload.event_id, alfangoDB);

    if (GetAttendeeService.checkIfAttendeeExistsForEvent(payload.invitee_user_id, payload.event_id, alfangoDB)) {
      #err("User already exists in the event attendee list.");
    } else if (payload.event_type == EventConstants.EventType.Offer and payload.participation_type == EventConstants.ParticipationType.PersonToPerson and attendeeCount > 1) {
      #err("Only one person can join this event");
    } else {
      let actionType = CommonService.getActionType(payload.action);

      let metadata_for_map : [(Text, Database.StringAttributeDataValue)] = switch (payload.metadata) {
        case (?meta) meta;
        case (null) [];
      };

      let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
        ("event_id", #text(payload.event_id)),
        ("invitee_user_id", #principal(payload.invitee_user_id)),
        ("action", #text(actionType)),
        ("timestamp", #nat(payload.timestamp)),
        ("event_status", #text(payload.event_status)),
        ("metadata", #map(metadata_for_map)),
      ];
      canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

      let item = await Database.createItem({
        createItemInput = {
          databaseName = EventConstants.KonectA;
          tableName = EventConstants.EventAttendeeTable;
          attributeDataValues = attributeDataValues;
        };
        alfangoDB = alfangoDB;
      });

      switch (item) {
        case (#err(msg)) {
          #err(HelperService.textArrayToString(msg));
        };
        case (#ok(result)) {
          #ok(result.id);
        };
      };

    };
  };

  public func withdrawEventAttendee(
    payload : ArgumentTypes.WithdrawAttendeeRequestPayload,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<ArgumentTypes.EventWithUserDataPayload, Text> {

    let actionType = CommonService.getActionType(payload.action);

    let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
      ("event_id", #text(payload.event_id)),
      ("invitee_user_id", #principal(payload.invitee_user_id)),
      ("action", #text(actionType)),
      ("timestamp", #nat(payload.timestamp)),
      ("event_status", #text(payload.event_status)),
    ];
    canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

    var requestIdResponse : Result.Result<Text, Text> = #err("Something went wrong");

    if (payload.event_type == EventConstants.EventType.Offer) {
      requestIdResponse := GetAttendeeService.getRequestIdForJoinedAttendee(Principal.toText(payload.invitee_user_id), payload.event_id, EventConstants.EventAttendeeStatus.Joined, alfangoDB);

      canistergeekLogger.logMessage("Request Id Response --->" # debug_show (requestIdResponse));
    } else {
      requestIdResponse := GetAttendeeService.getRequestIdForJoinedAttendee(Principal.toText(payload.invitee_user_id), payload.event_id, EventConstants.EventAttendeeStatus.Accepted, alfangoDB);

      canistergeekLogger.logMessage("Request Id Response --->" # debug_show (requestIdResponse));
    };

    switch (requestIdResponse) {
      case (#ok(requestId)) {

        let item = Database.updateItem({
          updateItemInput = {
            databaseName = EventConstants.KonectA;
            tableName = EventConstants.EventAttendeeTable;
            attributeDataValues = attributeDataValues;
            id = requestId;

          };
          alfangoDB = alfangoDB;
        });
        canistergeekLogger.logMessage("Update Withdraw in Event Attendee table Response --->" # debug_show (item));

        switch (item) {
          case (#err(msg)) {
            #err(HelperService.textArrayToString(msg));
          };
          case (#ok(_result)) {
            let eventData = await EventReadService.eventDetailsWithUserData(payload.event_id, alfangoDB);
            return #ok(eventData);
          };
        };
      };
      case (#err(error)) #err(error);
    };

  };

  public func updateEventAttendee(payload : ArgumentTypes.EventAttendeeResponsePayload, alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) : Result.Result<Text, Text> {

    let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
      ("event_id", #text(payload.event_id)),
      ("invitee_user_id", #principal(Principal.fromText(payload.invitee_user_id))),
      ("action", #text(payload.action)),
      ("timestamp", #nat(payload.timestamp)),
      ("event_status", #text(payload.event_status)),
    ];
    canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

    let item = Database.updateItem({
      updateItemInput = {
        databaseName = EventConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        attributeDataValues = attributeDataValues;
        id = payload.id;
      };
      alfangoDB = alfangoDB;
    });
    canistergeekLogger.logMessage("Update Withdraw in Event Attendee table Response --->" # debug_show (item));

    switch (item) {
      case (#err(msg)) {
        #err(HelperService.textArrayToString(msg));
      };
      case (#ok(result)) {
        #ok(result.id);
      };
    };

  };

};
