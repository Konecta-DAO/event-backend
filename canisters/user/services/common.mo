import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";
import SharedTypes "../../shared/types";
import SharedConstants "../../shared/constants";
import ArgumentTypes "../types/argumentTypes";
import {
  getTupleValue;
  getTupleValueAsText;
  textToNat;
  getTextArrayFromAttributeDataValueArray;
} "../../shared/common_utils/helper";

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
      createDatabaseInput = { name = SharedConstants.KonectA };
      alfangoDB = { databases };
    });

    switch (item) {
      case (#err(_msg)) {
        return "Failed to create " # SharedConstants.KonectA # " database";
      };
      case (#ok({})) {
        return SharedConstants.KonectA # "Database created successfully";
      };
    };
  };

  public func getEventStatus(action : SharedTypes.EventStatus, initialValue : Text) : Text {
    var status = initialValue;

    switch (action) {
      case (#Created) status := SharedTypes.EventStatus.Created;
      case (#Canceled) status := SharedTypes.EventStatus.Canceled;
    };

    return status;
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

  private func handleEventMetadataBuffer(_eventMetadataId : Text, eventMetadataItem : [(Text, Database.AttributeDataValue)], eventMetadataBuffer : Buffer.Buffer<ArgumentTypes.EventMetadataResponsePayload>) : Buffer.Buffer<ArgumentTypes.EventMetadataResponsePayload> {
    eventMetadataBuffer.add({
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
