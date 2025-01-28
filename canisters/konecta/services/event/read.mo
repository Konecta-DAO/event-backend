import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import CommonService "../../services/common";
import KonectaEventTable "../../tables/konectaEventTable";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../utils/helper";

module {
  public func getEventData(eventId : Text, databases : Map.Map<Text, Database.Database>) : Result.Result<ArgumentTypes.EventResponsePayload, [Text]> {
    let items = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.KonectAEventTable;
        filterExpressions = [{
          attributeName = "event_id";
          filterExpressionCondition = #EQ(#text(eventId));
        }];
      };
      alfangoDB = { databases };
    });

    switch (items) {
      case (#ok(eventData)) {
        return CommonService.transformArrayOfLengthOne(items);
      };
      case (#err(error)) #err(error);
    };
  };

  public func getFeedDetailsByEventId(eventId : Text, databases : Map.Map<Text, Database.Database>) : async Result.Result<ArgumentTypes.FeedResponsePayload, [Text]> {
    let items = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.KonectAEventTable;
        filterExpressions = [{
          attributeName = "event_id";
          filterExpressionCondition = #EQ(#text(eventId));
        }];
      };
      alfangoDB = { databases };
    });

    switch (items) {
      case (#ok(eventData)) {
        return await CommonService.transformFeedArrayOfLengthOne(items);
      };
      case (#err(error)) #err(error);
    };
  };

  public func getAllEvents(databases : Map.Map<Text, Database.Database>) : Result.Result<[ArgumentTypes.EventResponsePayload], [Text]> {
    let items = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.KonectAEventTable;
        filterExpressions = [
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    switch (items) {
      case (#ok(eventData)) {
        return CommonService.transformGetAllEventsResponse(items);
      };
      case (#err(error)) #err(error);
    };

  };

  public func checkIfEventExists(eventId : Text, databases : Map.Map<Text, Database.Database>) : Bool {
    var exists = false;
    let items = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.KonectAEventTable;
        filterExpressions = [
          {
            attributeName = "event_id";
            filterExpressionCondition = #EQ(#text(eventId));
          },
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
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
      case (#err(error)) {
        return eventType;
      };
    };
  };

  public func eventTableMetadata(databases : Map.Map<Text, Database.Database>) : Database.GetTableMetadataOutputType {
    Database.getTableMetadata({
      getTableMetadataInput = {
        databaseName = Constants.KonectA;
        metadata = {
          databaseName = Constants.KonectA;
          tableName = Constants.KonectAEventTable;
        };
        tableName = Constants.KonectAEventTable;
      };
      alfangoDB = { databases };
    });
  };

  public func checkIfEventIsCanceled(eventId : Text, databases : Map.Map<Text, Database.Database>) : Result.Result<Bool, Text> {

    var isCanceled = false;
    let items = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.KonectAEventTable;
        filterExpressions = [{
          attributeName = "event_id";
          filterExpressionCondition = #EQ(#text(eventId));
        }];
      };
      alfangoDB = { databases };
    });

    switch (items) {
      case (#ok(eventData)) {
        let eventData = CommonService.transformArrayOfLengthOne(items);

        switch (eventData) {
          case (#ok(data)) {
            let status = data.status;
            if (status == Constants.EventStatus.Canceled) {
              isCanceled := true;
            };

            #ok(isCanceled);
          };
          case (#err(error)) { #err(HelperService.textArrayToString(error)) };
        };

      };
      case (#err(error)) #err(HelperService.textArrayToString(error));
    };
  };
};
