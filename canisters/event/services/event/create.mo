import Database "mo:alfangodb/AlfangoDB";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Canistergeek "mo:canistergeek/canistergeek";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";

import CommonService "../../services/common";
import EventTable "../../tables/eventTable";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import { getTupleValueAsText; initializePrincipalField; textToNat } "../../utils/helper";

module {

  public func createEvent(
    userPrincipal : Principal,
    userCanisterId : Text,
    payload : ArgumentTypes.EventRequestPayload,
    databases : Map.Map<Text, Database.Database>,
    d3 : D3.D3,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Text {
    var response = "";

    var language = "";

    switch (payload.language) {
      case null language := Constants.DefaultLanguage;
      case (?lang) language := lang;
    };

    var coverPhotoUrl = "";
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

    let status = CommonService.getEventStatus(payload.status, Constants.EventStatus.Created);

    var metadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)] = [];
    switch (payload.metadata) {
      case (?meta) metadata := meta;
      case null metadata := [];
    };

    let userId = initializePrincipalField(payload.user_id, userPrincipal);

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

    let item = await Database.createItem({
      createItemInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
        attributeDataValues = attributeDataValues;
      };
      alfangoDB = { databases };
    });
    canistergeekLogger.logMessage("Event create response --->" # debug_show (item));

    switch (item) {
      case (#err(msg)) {
        response := "Failed to create event";
      };
      case (#ok(result)) {

        let userCanister = actor (userCanisterId) : CommonService.UserCanisterType;

        let calendarObject = {
          name = getTupleValueAsText(attributeDataValues, "name");
          description = getTupleValueAsText(attributeDataValues, "description");
        };
        canistergeekLogger.logMessage("Calendar object --->" # debug_show (calendarObject));

        let calendarId = await userCanister.upsertCalendarData(Principal.toText(userPrincipal), "", calendarObject);
        canistergeekLogger.logMessage("Calendar id --->" # debug_show (calendarId));

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

        let eventMetadataResponse = await userCanister.createEventMetaData(eventObject);
        canistergeekLogger.logMessage("Event metadata response --->" # debug_show (eventMetadataResponse));
        response := result.id;
      };

    };

    return response;
  };
};
