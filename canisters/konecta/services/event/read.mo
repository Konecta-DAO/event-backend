import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Map "mo:map/Map";
import CommonService "../../services/common";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import SharedConstants "../../../shared/constants";
import SharedTypes "../../../shared/types";

module {
  public func getEventData(eventId : Text, databases : Map.Map<Text, Database.Database>) : Result.Result<ArgumentTypes.EventResponsePayload, [Text]> {
    let items = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.KonectAEventTable;
        filterExpressions = [{
          attributeName = "event_id";
          filterExpressionCondition = #EQ(#text(eventId));
        }];
      };
      alfangoDB = { databases };
    });

    switch (items) {
      case (#ok(_eventData)) {
        return CommonService.transformArrayOfLengthOne(items);
      };
      case (#err(error)) #err(error);
    };
  };

  public func getFeedDetailsByEventId(eventId : Text, databases : Map.Map<Text, Database.Database>) : async Result.Result<ArgumentTypes.FeedResponsePayload, [Text]> {
    let items = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.KonectAEventTable;
        filterExpressions = [{
          attributeName = "event_id";
          filterExpressionCondition = #EQ(#text(eventId));
        }];
      };
      alfangoDB = { databases };
    });

    switch (items) {
      case (#ok(_eventData)) {
        return await CommonService.transformFeedArrayOfLengthOne(items);
      };
      case (#err(error)) #err(error);
    };
  };

  public func checkIfEventExists(eventId : Text, databases : Map.Map<Text, Database.Database>) : Bool {
    var exists = false;
    let items = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.KonectAEventTable;
        filterExpressions = [
          {
            attributeName = "event_id";
            filterExpressionCondition = #EQ(#text(eventId));
          },
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(SharedTypes.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    switch (CommonService.transformGetAllEventsResponse(items)) {
      case (#ok(data)) {
        exists := Array.size(data) > 0;
      };
      case (#err(_)) { exists := false };
    };

    return exists;
  };

  public func getEventType(eventId : Text, databases : Map.Map<Text, Database.Database>) : Text {

    var eventType = "";
    let eventDataResponse = getEventData(eventId, databases);

    switch (eventDataResponse) {
      case (#ok(eventData)) {
        eventType := eventData.event_type;
        return eventType;
      };
      case (#err(_error)) {
        return eventType;
      };
    };
  };

  public func eventTableMetadata(databases : Map.Map<Text, Database.Database>) : Database.GetTableMetadataOutputType {
    Database.getTableMetadata({
      getTableMetadataInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.KonectAEventTable;
      };
      alfangoDB = { databases };
    });
  };

};
