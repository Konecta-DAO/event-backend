import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import EventMetadataReadService "../../services/event_metadata/read";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import CommonService "../common";

module {
  public func createEventMetaData(
    eventMetadataPayload : ArgumentTypes.EventMetadataRequestPayload,
    databases : Map.Map<Text, Database.Database>,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, Text> {

    if (not EventMetadataReadService.checkIfMetadataExistsForEventForUser(eventMetadataPayload.event_id, databases)) {

      let initialDataValues = Buffer.fromArray<(Text, Database.AttributeDataValue)>([]);
      let dataValuesToBeAppended = Buffer.Buffer<(Text, Database.AttributeDataValue)>(0);

      Debug.print("eventMetadataPayload --->" # debug_show (eventMetadataPayload));

      let categories : [Text] = CommonService.initializeTextArrayField(eventMetadataPayload.categories, []);
      let interests : [Text] = CommonService.initializeTextArrayField(eventMetadataPayload.interests, []);
      let calendar_id : Text = CommonService.initializeTextField(eventMetadataPayload.calendar_id, "");
      let eventName : Text = CommonService.initializeTextField(eventMetadataPayload.name, "");
      let startDate : Nat = CommonService.initializeNatField(eventMetadataPayload.start_date, 0);
      let endDate : Nat = CommonService.initializeNatField(eventMetadataPayload.end_date, 0);
      let createdBy : Principal = CommonService.initializePrincipalField(eventMetadataPayload.created_by, Principal.fromText(Constants.AnonymousPrincipal));

      let categoriesArray = CommonService.getStringAttributeDataValueArray(categories);
      let interestArray = CommonService.getStringAttributeDataValueArray(interests);

      let eventStatus = CommonService.getEventStatus(eventMetadataPayload.status, Constants.EventStatus.Created);

      dataValuesToBeAppended.add("calendar_id", #text(calendar_id));
      dataValuesToBeAppended.add("event_id", #text(eventMetadataPayload.event_id));
      dataValuesToBeAppended.add("name", #text(eventName));
      dataValuesToBeAppended.add("categories", #list(categoriesArray));
      dataValuesToBeAppended.add("interests", #list(interestArray));
      dataValuesToBeAppended.add("start_date", #nat(startDate));
      dataValuesToBeAppended.add("end_date", #nat(endDate));
      dataValuesToBeAppended.add("status", #text(eventStatus));
      dataValuesToBeAppended.add("created_by", #principal(createdBy));

      initialDataValues.append(dataValuesToBeAppended);
      let dataValuesArray = Buffer.toArray(initialDataValues);
      Debug.print("Attribute data values --->" # debug_show (dataValuesArray));
      canistergeekLogger.logMessage("Attribute data values --->" # debug_show (dataValuesArray));

      let item = await Database.createItem({
        createItemInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.EventMetadataTable;
          attributeDataValues = dataValuesArray;
        };
        alfangoDB = { databases };
      });
      Debug.print("Create Event metadata response --->" # debug_show (item));
      canistergeekLogger.logMessage("Create Event metadata response item --->" # debug_show (item));

      switch (item) {
        case (#err(msg)) {
          #err("Failed to create event metadata");
        };
        case (#ok(result)) {
          #ok(result.id);
        };

      };

    } else {
      #err("Event metadata already exists for the event");
    };

  };
};
