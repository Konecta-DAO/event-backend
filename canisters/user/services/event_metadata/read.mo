import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import CommonService "../common";

module {

  public func getEventMetadataById(eventMetadataId : Text, databases : Map.Map<Text, Database.Database>) : Result.Result<ArgumentTypes.EventMetadataResponsePayload, [Text]> {

    let item = Database.getItemById({
      getItemByIdInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventMetadataTable;
        id = eventMetadataId;
      };
      alfangoDB = { databases };
    });

    return CommonService.transformGetEventMetadataResponse(item);
  };

  public func getAllEventsMetadata(databases : Map.Map<Text, Database.Database>) : Result.Result<[ArgumentTypes.EventMetadataResponsePayload], [Text]> {
    let items = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventMetadataTable;
        filterExpressions = [
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    return CommonService.transformGetAllEventMetadataResponse(items);
  };

  public func getAllEventsMetadataForUser(databases : Map.Map<Text, Database.Database>) : Result.Result<[ArgumentTypes.EventMetadataResponsePayload], [Text]> {
    let items = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventMetadataTable;
        filterExpressions = [
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    return CommonService.transformGetAllEventMetadataResponse(items);
  };

  public func checkIfMetadataExistsForEventForUser(eventId : Text, databases : Map.Map<Text, Database.Database>) : Bool {
    var exists = false;

    let eventResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventMetadataTable;
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

    switch (eventResponse) {
      case (#ok(events)) {
        if (Array.size(events) > 0) {
          exists := true;
        } else {
          exists := false;
        };
      };
      case (#err(err)) exists := false;
    };

    return exists;
  };

  public func getEventMetaDataFromStartToEndDate(startDate : Nat, endDate : Nat, categories : [Text], databases : Map.Map<Text, Database.Database>) : Result.Result<[ArgumentTypes.EventMetadataResponsePayload], [Text]> {
    let categoriesArray = CommonService.getStringAttributeDataValueArray(categories);

    if (Array.size(categoriesArray) == 0) {
      let items = Database.scan({
        scanInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.EventMetadataTable;
          filterExpressions = [
            {
              attributeName = "start_date";
              filterExpressionCondition = #GTE(#nat(startDate));
            },
            {
              attributeName = "end_date";
              filterExpressionCondition = #LTE(#nat(endDate));
            },
            {
              attributeName = "status";
              filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
            },
          ];
        };
        alfangoDB = { databases };
      });

      return CommonService.transformGetAllEventMetadataResponse(items);
    } else {
      let items = Database.scan({
        scanInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.EventMetadataTable;
          filterExpressions = [
            {
              attributeName = "start_date";
              filterExpressionCondition = #GTE(#nat(startDate));
            },
            {
              attributeName = "end_date";
              filterExpressionCondition = #LTE(#nat(endDate));
            },
            {
              attributeName = "categories";
              filterExpressionCondition = #IN(categoriesArray);
            },
            {
              attributeName = "status";
              filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
            },
          ];
        };
        alfangoDB = { databases };
      });

      return CommonService.transformGetAllEventMetadataResponse(items);
    };

  };

  public func getEventMetadataId(eventId : Text, calendarId : Text, databases : Map.Map<Text, Database.Database>) : Text {
    let result = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventMetadataTable;
        filterExpressions = [
          {
            attributeName = "event_id";
            filterExpressionCondition = #EQ(#text(eventId));
          },
          {
            attributeName = "calendar_id";
            filterExpressionCondition = #EQ(#text(calendarId));
          },
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    switch (result) {
      case (#ok(eventMetadata)) {
        let eventMetadataId = eventMetadata[0].id;
        return eventMetadataId;
      };

      case (#err(error)) {
        return "Failed to find event metadata id";
      };
    };
  };

  public func getUserEventMetadataTableMetadata(databases : Map.Map<Text, Database.Database>) : Database.GetTableMetadataOutputType {
    Database.getTableMetadata({
      getTableMetadataInput = {
        databaseName = Constants.KonectA;
        metadata = {
          databaseName = Constants.KonectA;
          tableName = Constants.EventMetadataTable;
        };
        tableName = Constants.EventMetadataTable;
      };
      alfangoDB = { databases };
    });
  };

};
