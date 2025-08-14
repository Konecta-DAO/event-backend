import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import { getCalendarId } "../../services/calendar/read";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../utils/helper";
import CommonService "../common";
import { getEventMetadataById; getEventMetadataId } "./read";

module {
  public func updateEventMetaData(
    eventMetadataId : Text,
    eventMetadataPayload : ArgumentTypes.UpdateEventMetadataPayload,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : Result.Result<Text, Text> {

    let dataValuesToBeAppended = Buffer.Buffer<(Text, Database.AttributeDataValue)>(0);

    let eventMetadataData = getEventMetadataById(eventMetadataId, alfangoDB);

    var oldValues : ArgumentTypes.EventMetadataResponsePayload = {
      event_metadata_id = "";
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
      case (#ok(eventMetadata)) oldValues := eventMetadata;
      case (#err(_)) ();
    };

    let calendar_id : Text = HelperService.initializeTextField(eventMetadataPayload.calendar_id, oldValues.calendar_id);
    let eventName : Text = HelperService.initializeTextField(eventMetadataPayload.name, oldValues.name);
    let startDate : Nat = HelperService.initializeNatField(eventMetadataPayload.start_date, oldValues.start_date);
    let endDate : Nat = HelperService.initializeNatField(eventMetadataPayload.end_date, oldValues.end_date);
    let createdBy : Principal = HelperService.initializePrincipalField(eventMetadataPayload.created_by, Principal.fromText(oldValues.created_by));

    let eventStatus = CommonService.getEventStatus(eventMetadataPayload.status, oldValues.status);

    dataValuesToBeAppended.add(("calendar_id", #text(calendar_id)));
    dataValuesToBeAppended.add(("event_id", #text(eventMetadataPayload.event_id)));
    dataValuesToBeAppended.add(("name", #text(eventName)));
    dataValuesToBeAppended.add(("start_date", #nat(startDate)));
    dataValuesToBeAppended.add(("end_date", #nat(endDate)));
    dataValuesToBeAppended.add(("status", #text(eventStatus)));
    dataValuesToBeAppended.add(("created_by", #principal(createdBy)));

    let dataValuesArray = Buffer.toArray(dataValuesToBeAppended);
    canistergeekLogger.logMessage("Attribute data values --->" # debug_show (dataValuesArray));

    let item = Database.updateItem({
      updateItemInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventMetadataTable;
        id = eventMetadataId;
        attributeDataValues = dataValuesArray;
      };
      alfangoDB = alfangoDB;
    });
    canistergeekLogger.logMessage("Update Event metadata response --->" # debug_show (item));

    switch (item) {
      case (#err(_msg)) #err("Failed to update event metadata");
      case (#ok(result)) #ok(result.id);
    };
  };

  public func removeCalendarEvent(
    eventMetadataId : Text,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : Result.Result<Text, Text> {
    let eventMetadataData = getEventMetadataById(eventMetadataId, alfangoDB);
    let initialDataValues = Buffer.fromArray<(Text, Database.AttributeDataValue)>([]);
    let dataValuesToBeAppended = Buffer.Buffer<(Text, Database.AttributeDataValue)>(0);

    var oldValues : ArgumentTypes.EventMetadataResponsePayload = {
      event_metadata_id = "";
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
      case (#err(_errorMessage)) ();
    };

    let calendar_id : Text = oldValues.calendar_id;
    let eventName : Text = oldValues.name;
    let startDate : Nat = oldValues.start_date;
    let endDate : Nat = oldValues.end_date;
    let createdBy : Principal = Principal.fromText(oldValues.created_by);

    let interests : [Text] = oldValues.interests;
    let interestArray = HelperService.getStringAttributeDataValueArray(interests);

    let categories : [Text] = oldValues.categories;
    let categoriesArray = HelperService.getStringAttributeDataValueArray(categories);

    let eventStatus = Constants.EventStatus.Canceled;

    dataValuesToBeAppended.add("calendar_id", #text(calendar_id));
    dataValuesToBeAppended.add("event_id", #text(oldValues.event_id));
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
      alfangoDB = alfangoDB;
    });
    canistergeekLogger.logMessage("Update Event metadata response --->" # debug_show (item));

    switch (item) {
      case (#err(_msg)) {
        #err("Failed to update event metadata");
      };
      case (#ok(result)) {
        #ok(result.id);
      };

    };
  };

  public func updateEventMetadataForAttendee({
    eventId : Text;
    eventMetadataPayload : ArgumentTypes.AttendeeEventMetadataRequestPayload;
    alfangoDB : Database.AlfangoDB;
    canistergeekLogger : Canistergeek.Logger;
  }) : Result.Result<Text, Text> {
    let calendarId = getCalendarId(alfangoDB);
    let eventMetadataId = getEventMetadataId(eventId, calendarId, alfangoDB);

    let updatePayload : ArgumentTypes.UpdateEventMetadataPayload = {
      calendar_id = eventMetadataPayload.calendar_id;
      event_id = eventMetadataPayload.event_id;
      name = eventMetadataPayload.name;
      start_date = eventMetadataPayload.start_date;
      end_date = eventMetadataPayload.end_date;
      status = eventMetadataPayload.status;
      created_by = eventMetadataPayload.created_by;
    };

    updateEventMetaData(eventMetadataId, updatePayload, alfangoDB, canistergeekLogger);
  };
};
