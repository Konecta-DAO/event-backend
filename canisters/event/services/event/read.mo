import Database "mo:alfangodb/AlfangoDB";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import D3 "mo:d3storage/D3";
import HashMap "mo:base/HashMap";
import CommonService "../../services/common";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../utils/helper";
import OutputTypes "mo:alfangodb/AlfangoDB/types/output";
import Order "mo:base/Order";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";

module {

  public func eventDataById(eventId : Text, alfangoDB : Database.AlfangoDB) : Result.Result<ArgumentTypes.EventResponsePayload, [Text]> {
    let eventResponse = Database.getItemById({
      getItemByIdInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
        id = eventId;
      };
      alfangoDB = alfangoDB;
    });
    return CommonService.transformGetEventResponse(eventResponse);
  };
  public func eventDetailsWithUserData(
    eventId : Text,
    alfangoDB : Database.AlfangoDB,
  ) : async ArgumentTypes.EventWithUserDataPayload {
    let eventResponse = Database.getItemById({
      getItemByIdInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
        id = eventId;
      };
      alfangoDB = alfangoDB;
    });
    let eventData = await CommonService.transformGetEventResponseAsync(
      eventResponse
    );
    switch (eventData) {
      case (#ok(eventData)) {
        return eventData;
      };
      case (#err(_err)) {
        return CommonService.initialEventObjectWithUserData;
      };
    };
  };
  public func getBatchEventsByCompositeQuery(eventIds : [Text], alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) : [ArgumentTypes.EventResponsePayload] {
    let eventsResponse = Database.batchGetItemById({
      batchGetItemByIdInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
        ids = eventIds;
      };
      alfangoDB = alfangoDB;
    });
    canistergeekLogger.logMessage("Failed to get batch events response --> " # debug_show (eventsResponse));
    switch (eventsResponse) {
      case (#ok(multipleEventItems)) {
        let eventItems = multipleEventItems.items;
        let eventBuffer = Buffer.Buffer<ArgumentTypes.EventResponsePayload>(eventItems.size());
        for (itemObject in eventItems.vals()) {
          let eventId = itemObject.id;
          let eventItem = itemObject.item;
          CommonService.handleEventBuffer(eventId, eventItem, eventBuffer);
        };
        return Buffer.toArray(eventBuffer);
      };
      case (#err(_error)) {
        return [];
      };
    };
  };
  public func eventTableMetadata(alfangoDB : Database.AlfangoDB) : Database.GetTableMetadataOutputType {
    Database.getTableMetadata({
      getTableMetadataInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
      };
      alfangoDB = alfangoDB;
    });
  };
  public func getFile(fileId : Text, d3 : D3.D3) : D3.GetFileOutputType {
    CommonService.getFile(fileId, d3);
  };

  private func dataTypeToText(dataType : Database.AttributeDataType) : Text {
    switch (dataType) {
      case (#text) "Text";
      case (#principal) "Principal";
      case (#nat) "Nat";
      case (#nat8) "Nat8";
      case (#nat16) "Nat16";
      case (#nat32) "Nat32";
      case (#nat64) "Nat64";
      case (#int) "Int";
      case (#int8) "Int8";
      case (#int16) "Int16";
      case (#int32) "Int32";
      case (#int64) "Int64";
      case (#float) "Float";
      case (#bool) "Bool";
      case (#char) "Char";
      case (#blob) "Blob";
      case (#list) "List";
      case (#map) "Map";
    };
  };
};
