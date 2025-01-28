import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Bool "mo:base/Bool";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Canistergeek "mo:canistergeek/canistergeek";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";

import CommonService "../../services/common";
import { getAllAttendeesIds } "../../services/eventAttendee/getAttendee";
import EventTable "../../tables/eventTable";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import {
  getAttributeDataValue;
  getStringAttributeDataValueArray;
  getTupleValueAsText;
  initializePrincipalField;
  initializeTextArrayField;
  textArrayToString;
  textToNat;
} "../../utils/helper";
import { eventDataById } "./read";

module {
  public func updateEvent(
    userPrincipal : Principal,
    userCanisterId : Text,
    eventId : Text,
    payload : ArgumentTypes.EventRequestPayload,
    databases : Map.Map<Text, Database.Database>,
    d3 : D3.D3,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, Text> {

    let eventData = eventDataById(eventId, databases);
    var oldValues : ArgumentTypes.EventResponsePayload = CommonService.initialEventObjectWithUserData;
    switch (eventData) {
      case (#ok(event)) {
        oldValues := event;
      };
      case (#err(errorMessage)) ();
    };

    var coverPhotoUrl = oldValues.coverphoto;
    ignore do ? {

      let coverPhotoOutput = await D3.updateOperation({
        d3 = d3;
        updateOperationInput = #StoreFile({
          fileDataObject = payload.coverphoto!.fileDataObject;
          fileName = payload.coverphoto!.fileName;
          fileType = payload.coverphoto!.fileType;
        });
      });

      switch (coverPhotoOutput) {
        case (#StoreFileOutput(file)) {
          coverPhotoUrl := file.fileId;
        };
      };
    };

    var language = oldValues.language;
    ignore do ? {
      switch (payload.language) {
        case null null!;
        case (?lang) language := lang;
      };
    };

    var metadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)] = [];
    switch (payload.metadata) {
      case (?meta) metadata := meta;
      case null metadata := [];
    };

    let status = CommonService.getEventStatus(payload.status, oldValues.status);

    let userId = initializePrincipalField(payload.user_id, Principal.fromText(oldValues.user_id));

    let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
      ("user_id", #principal(userId)),
      ("name", #text(payload.name)),
      ("description", #text(payload.description)),
      ("location", #text(payload.location)),
      ("start_date", #nat(payload.start_date)),
      ("end_date", #nat(payload.end_date)),
      ("status", #text(status)),
      ("coverphoto", #text(coverPhotoUrl)),
      ("language", #text(language)),
      ("metadata", #map(metadata)),
    ];
    canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

    let item = Database.updateItem({
      updateItemInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
        id = eventId;
        attributeDataValues = attributeDataValues;
      };
      alfangoDB = { databases };
    });
    canistergeekLogger.logMessage("Event update response --->" # debug_show (item));

    var response = "";
    switch (item) {
      case (#err(msg)) {
        #err("Failed to update event");
      };
      case (#ok(result)) {

        let userCanister = actor (userCanisterId) : CommonService.UserCanisterType;

        let calendarId = await userCanister.getCalendarId(eventId);
        let eventMetadataId = await userCanister.getEventMetadataId(eventId, calendarId);

        let calendarObject = {
          name = getTupleValueAsText(attributeDataValues, "name");
          description = getTupleValueAsText(attributeDataValues, "description");
        };
        canistergeekLogger.logMessage("Calendar object --->" # debug_show (calendarObject));
        let updateCalendarResponse = await userCanister.upsertCalendarData(Principal.toText(userPrincipal), calendarId, calendarObject);
        canistergeekLogger.logMessage("Calendar id --->" # debug_show (updateCalendarResponse));

        let eventObject = {
          event_id = result.id;
          name = getTupleValueAsText(attributeDataValues, "name");
          start_date = textToNat(getTupleValueAsText(attributeDataValues, "start_date"));
          end_date = textToNat(getTupleValueAsText(attributeDataValues, "end_date"));
          status = payload.status;
          calendar_id = calendarId;
          created_by = userPrincipal;
        };
        canistergeekLogger.logMessage("Event object --->" # debug_show (eventObject));

        let eventMetadataResponse = await userCanister.updateEventMetaData(eventMetadataId, eventObject);
        canistergeekLogger.logMessage("Event metadata response --->" # debug_show (eventMetadataResponse));
        response := result.id;
        #ok(result.id);
      };

    };

  };

  public func cancelEvent(
    userPrincipal : Principal,
    eventId : Text,
    databases : Map.Map<Text, Database.Database>,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, Text> {
    let eventData = eventDataById(eventId, databases);
    Debug.print(debug_show (eventData));
    canistergeekLogger.logMessage("Event Data --->" # debug_show (eventData));

    switch (eventData) {
      case (#ok(eventData)) {
        let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
          ("user_id", #principal(Principal.fromText(eventData.user_id))),
          ("name", #text(eventData.name)),
          ("description", #text(eventData.description)),
          ("location", #text(eventData.location)),
          ("start_date", #nat(eventData.start_date)),
          ("end_date", #nat(eventData.end_date)),
          ("status", #text(Constants.EventStatus.Canceled)),
          ("coverphoto", #text(eventData.coverphoto)),
          ("language", #text(eventData.language)),
          ("metadata", #map(eventData.metadata)),
        ];
        canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

        let item = Database.updateItem({
          updateItemInput = {
            databaseName = Constants.KonectA;
            tableName = Constants.EventTable;
            id = eventId;
            attributeDataValues = attributeDataValues;
          };
          alfangoDB = { databases };
        });
        canistergeekLogger.logMessage("Cancel event response --->" # debug_show (item));

        let userIdBuffer = Buffer.Buffer<Text>(0);
        userIdBuffer.add(Principal.toText(userPrincipal));
        canistergeekLogger.logMessage("User Principal --->" # debug_show (Principal.toText(userPrincipal)));

        let attendeeIdsResponse = getAllAttendeesIds(eventId, databases);
        canistergeekLogger.logMessage("Attendee Ids response --->" # debug_show (attendeeIdsResponse));

        switch (attendeeIdsResponse) {
          case (#ok(attendeeIds)) {
            let attendeeIdsBuffer : Buffer.Buffer<Text> = Buffer.fromArray(attendeeIds);
            canistergeekLogger.logMessage("Attendee Ids --->" # debug_show (attendeeIds));

            userIdBuffer.append(attendeeIdsBuffer);

            let userIdArray = Buffer.toArray(userIdBuffer);
            canistergeekLogger.logMessage("User Id array --->" # debug_show (userIdArray));

            for (userId in userIdArray.vals()) {
              let userCanisterId = await CommonService.getUserCanisterId(userId);
              canistergeekLogger.logMessage("User Canister Id --->" # debug_show (userCanisterId));

              let userCanister = actor (userCanisterId) : CommonService.UserCanisterType;
              let calendarId = await userCanister.getCalendarId(eventId);
              canistergeekLogger.logMessage("Calendar Id --->" # debug_show (calendarId));

              let eventMetadataId = await userCanister.getEventMetadataId(eventId, calendarId);
              canistergeekLogger.logMessage("Event metadata id --->" # debug_show (eventMetadataId));

              let eventObject = {
                calendar_id = calendarId;
                created_by = Principal.fromText(userId);
                end_date = eventData.end_date;
                name = eventData.name;
                start_date = eventData.start_date;
                event_id = eventId;
                status = Constants.EventStatusVariant.Canceled;
              };
              canistergeekLogger.logMessage("Event object --->" # debug_show (eventObject));

              let eventMetadataResponse = await userCanister.updateEventMetaData(eventMetadataId, eventObject);
              canistergeekLogger.logMessage("Event metadata response --->" # debug_show (eventMetadataResponse));
            };

            #ok("Event canceled successfully");
          };
          case (#err(error)) {
            return #err(textArrayToString(error));
          };
        };

      };
      case (#err(error)) #err(textArrayToString(error));
    };

  };
};
