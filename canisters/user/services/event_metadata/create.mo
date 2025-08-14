import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";

import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import EventMetadataReadService "./read";
import CommonService "../common";
import HelperService "../../utils/helper";

module {
  public func createEventMetaData(
    eventMetadataPayload : ArgumentTypes.CreateEventMetadataPayload,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, Text> {

    if (not EventMetadataReadService.checkIfMetadataExistsForEventForUser(eventMetadataPayload.event_id, alfangoDB)) {

      let eventStatus = CommonService.getEventStatus(eventMetadataPayload.status, Constants.EventStatus.Created);

      let categoriesArray = HelperService.getStringAttributeDataValueArray(eventMetadataPayload.categories);
      let interestsArray = HelperService.getStringAttributeDataValueArray(eventMetadataPayload.interests);

      let dataValues : [(Text, Database.AttributeDataValue)] = [
        ("calendar_id", #text(eventMetadataPayload.calendar_id)),
        ("event_id", #text(eventMetadataPayload.event_id)),
        ("name", #text(eventMetadataPayload.name)),
        ("start_date", #nat(eventMetadataPayload.start_date)),
        ("end_date", #nat(eventMetadataPayload.end_date)),
        ("status", #text(eventStatus)),
        ("created_by", #principal(eventMetadataPayload.created_by)),
        ("categories", #list(categoriesArray)),
        ("interests", #list(interestsArray)),
      ];
      canistergeekLogger.logMessage("Attribute data values --->" # debug_show (dataValues));

      let item = await Database.createItem({
        createItemInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.EventMetadataTable;
          attributeDataValues = dataValues;
        };
        alfangoDB = alfangoDB;
      });
      canistergeekLogger.logMessage("Create Event metadata response item --->" # debug_show (item));

      switch (item) {
        case (#err(_msg)) #err("Failed to create event metadata");
        case (#ok(result)) #ok(result.id);
      };

    } else {
      #err("Event metadata already exists for the event");
    };
  };
};
