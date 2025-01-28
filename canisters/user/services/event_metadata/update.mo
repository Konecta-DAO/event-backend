import Database "mo:alfangodb/AlfangoDB";
import { generateULIDAsync } "mo:alfangodb/AlfangoDB/utils";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import Common "../../../event/services/common";
import EventMetadataTable "../../tables/eventMetadataTable";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import { getTupleValue; getTupleValueAsText; textToNat } "../../utils/helper";
import CommonService "../common";
import { getEventMetadataById } "./read";

module {
  public func updateEventMetaData(
    userPrincipal : Principal,
    eventMetadataId : Text,
    eventMetadataPayload : ArgumentTypes.EventMetadataRequestPayload,
    databases : Map.Map<Text, Database.Database>,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Text {
    var response = "";

    let initialDataValues = Buffer.fromArray<(Text, Database.AttributeDataValue)>([]);
    let dataValuesToBeAppended = Buffer.Buffer<(Text, Database.AttributeDataValue)>(0);

    let eventMetadataData = getEventMetadataById(eventMetadataId, databases);

    var oldValues : ArgumentTypes.EventMetadataResponsePayload = {
      calendar_id = "";
      event_id = "";
      name = "";
      categories = [];
      interests = [];
      start_date = 0;
      end_date = 0;
      status = "";
      created_by = "";
    };
    switch (eventMetadataData) {
      case (#ok(eventMetadata)) {
        oldValues := eventMetadata;
      };
      case (#err(errorMessage)) ();
    };

    let calendar_id : Text = CommonService.initializeTextField(eventMetadataPayload.calendar_id, oldValues.calendar_id);
    let eventName : Text = CommonService.initializeTextField(eventMetadataPayload.name, oldValues.name);
    let startDate : Nat = CommonService.initializeNatField(eventMetadataPayload.start_date, oldValues.start_date);
    let endDate : Nat = CommonService.initializeNatField(eventMetadataPayload.end_date, oldValues.end_date);
    let createdBy : Principal = Principal.fromText(oldValues.created_by);

    let oldInterestsArray : [Text] = oldValues.interests;
    let interests : [Text] = CommonService.initializeTextArrayField(eventMetadataPayload.interests, oldInterestsArray);
    let interestArray = CommonService.getStringAttributeDataValueArray(interests);

    let oldCategoriesArray : [Text] = oldValues.categories;
    let categories : [Text] = CommonService.initializeTextArrayField(eventMetadataPayload.categories, oldCategoriesArray);
    let categoriesArray = CommonService.getStringAttributeDataValueArray(categories);

    let eventStatus = CommonService.getEventStatus(eventMetadataPayload.status, oldValues.status);

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
    canistergeekLogger.logMessage("Attribute data values --->" # debug_show (dataValuesArray));

    let item = Database.updateItem({
      updateItemInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventMetadataTable;
        id = eventMetadataId;
        attributeDataValues = dataValuesArray;
      };
      alfangoDB = { databases };
    });
    canistergeekLogger.logMessage("Update Event metadata response --->" # debug_show (item));

    switch (item) {
      case (#err(msg)) {
        response := "Failed to update event metadata";
      };
      case (#ok(result)) {
        response := "Updated event metadata with id: " # result.id;
      };

    };

    return response;
  };
};
