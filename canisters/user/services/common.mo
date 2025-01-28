import Database "mo:alfangodb/AlfangoDB";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";

import ArgumentTypes "../types/argumentTypes";
import Constants "../utils/constants";
import {
  getAttributeDataValue;
  getTupleArrayFromAttributeDataValueArray;
  getTupleValue;
  getTupleValueAsText;
  textToNat;
} "../utils/helper";

module {

  public let initialUserObject = {
    id = "";
    principal_id = "";
    canister_id = "";
    firstname = "";
    lastname = "";
    username = "";
    email = "";
    bio = "";
    categories = [];
    profilepic = "";
    coverphoto = "";
    country = "";
    timezone = "";
  };

  public func createProjectDatabase(databases : Map.Map<Text, Database.Database>) : async Text {
    let item = Database.createDatabase({
      createDatabaseInput = { name = Constants.KonectA };
      alfangoDB = { databases };
    });

    switch (item) {
      case (#err(msg)) {
        return "Failed to create " # Constants.KonectA # " database";
      };
      case (#ok({})) {
        return Constants.KonectA # "Database created successfully";
      };
    };
  };

  public func getEventStatus(action : ArgumentTypes.EventStatus, initialValue : Text) : Text {
    var status = initialValue;

    switch (action) {
      case (#Created) status := Constants.EventStatus.Created;
      case (#Canceled) status := Constants.EventStatus.Canceled;
    };

    return status;
  };

  public func getStringAttributeDataValueArray(array : [Text]) : [Database.StringAttributeDataValue] {
    let initialBuffer = Buffer.fromArray<(Database.StringAttributeDataValue)>([]);
    let valuesToBeAppended = Buffer.Buffer<(Database.StringAttributeDataValue)>(0);

    for (element in array.vals()) {
      valuesToBeAppended.add(#text(element));
    };

    initialBuffer.append(valuesToBeAppended);
    return Buffer.toArray(initialBuffer);
  };

  public func initializeTextArrayField(payload : ?[Text], initialValue : [Text]) : [Text] {
    switch (payload) {
      case (?fieldValue) fieldValue;
      case null initialValue;
    };
  };

  public func initializeTextField(payload : ?Text, initialValue : Text) : Text {
    switch (payload) {
      case (?fieldValue) fieldValue;
      case null initialValue;
    };
  };

  public func initializeNatField(payload : ?Nat, initialValue : Nat) : Nat {
    switch (payload) {
      case (?fieldValue) fieldValue;
      case null initialValue;
    };
  };

  public func initializePrincipalField(payload : ?Principal, initialValue : Principal) : Principal {
    switch (payload) {
      case (?fieldValue) fieldValue;
      case null initialValue;
    };
  };

  public func getTextArrayFromAttributeDataValueArray(attributeDataValue : Database.AttributeDataValue) : [Text] {
    var value : [Text] = [];
    let initialBuffer = Buffer.fromArray<Text>([]);
    let valuesToBeAppended = Buffer.Buffer<Text>(0);

    switch (attributeDataValue) {
      case (#list(array)) {
        for (element in array.vals()) {
          switch (element) {
            case (#text(value)) { valuesToBeAppended.add(value) };
            case (_) { value := [] };
          };
        };
      };
      case (_) { value := [] };
    };

    initialBuffer.append(valuesToBeAppended);
    value := Buffer.toArray(initialBuffer);

    return value;
  };

  public func getFile(fileId : Text, d3 : D3.D3) : D3.GetFileOutputType {
    D3.getFile({
      d3;
      getFileInput = {
        fileId = fileId;
      };
    });
  };

  public func transformGetAllEventMetadataResponse(eventResponse : Database.ScanOutputType) : Result.Result<[ArgumentTypes.EventMetadataResponsePayload], [Text]> {
    let eventMetadataBuffer = Buffer.Buffer<ArgumentTypes.EventMetadataResponsePayload>(0);
    var eventMetadataArray : [ArgumentTypes.EventMetadataResponsePayload] = [];
    switch (eventResponse) {
      case (#ok(eventData)) {
        for (itemObject in eventData.vals()) {
          let eventMetadataId = itemObject.id;
          let eventMetadataItem = itemObject.item;

          eventMetadataArray := Buffer.toArray(handleEventMetadataBuffer(eventMetadataId, eventMetadataItem, eventMetadataBuffer));
        };

        #ok(eventMetadataArray);
      };

      case (#err(error)) #err(error);

    };

  };

  public func transformGetEventMetadataResponse(eventResponse : Database.GetItemByIdOutputType) : Result.Result<ArgumentTypes.EventMetadataResponsePayload, [Text]> {
    let eventBuffer = Buffer.Buffer<ArgumentTypes.EventMetadataResponsePayload>(0);

    switch (eventResponse) {
      case (#ok(eventData)) {

        let eventMetadataId = eventData.id;
        let eventMetadataItem = eventData.item;

        let event = Buffer.toArray(handleEventMetadataBuffer(eventMetadataId, eventMetadataItem, eventBuffer))[0];

        #ok(event);
      };

      case (#err(error)) #err(error);

    };

  };

  private func handleEventMetadataBuffer(eventMetadataId : Text, eventMetadataItem : [(Text, Database.AttributeDataValue)], eventMetadataBuffer : Buffer.Buffer<ArgumentTypes.EventMetadataResponsePayload>) : Buffer.Buffer<ArgumentTypes.EventMetadataResponsePayload> {
    eventMetadataBuffer.add({
      event_metadata_id = eventMetadataId;
      calendar_id = getTupleValueAsText(eventMetadataItem, "calendar_id");
      event_id = getTupleValueAsText(eventMetadataItem, "event_id");
      name = getTupleValueAsText(eventMetadataItem, "name");
      categories = getTextArrayFromAttributeDataValueArray(getTupleValue(eventMetadataItem, "categories"));
      start_date = textToNat(getTupleValueAsText(eventMetadataItem, "start_date"));
      end_date = textToNat(getTupleValueAsText(eventMetadataItem, "end_date"));
      interests = getTextArrayFromAttributeDataValueArray(getTupleValue(eventMetadataItem, "interests"));
      status = getTupleValueAsText(eventMetadataItem, "status");
      created_by = getTupleValueAsText(eventMetadataItem, "created_by");
    });

    return eventMetadataBuffer;
  };
};
