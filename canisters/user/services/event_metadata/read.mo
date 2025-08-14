import Database "mo:alfangodb/AlfangoDB";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Map "mo:map/Map";

import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../utils/helper";
import CommonService "../common";

module {

  public func getEventMetadataById(eventMetadataId : Text, alfangoDB : Database.AlfangoDB) : Result.Result<ArgumentTypes.EventMetadataResponsePayload, [Text]> {
    let item = Database.getItemById({
      getItemByIdInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventMetadataTable;
        id = eventMetadataId;
      };
      alfangoDB = alfangoDB;
    });

    return CommonService.transformGetEventMetadataResponse(item);
  };

  public func getAllEventsMetadata(alfangoDB : Database.AlfangoDB) : Result.Result<[ArgumentTypes.EventMetadataResponsePayload], [Text]> {

    let filter : SearchTypes.QueryFilter = #expression({
      attributeNames = "status";
      filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
    });

    let items = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventMetadataTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    return CommonService.transformGetAllEventMetadataResponse(items);
  };

  public func checkIfMetadataExistsForEventForUser(eventId : Text, alfangoDB : Database.AlfangoDB) : Bool {
    var exists = false;

    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
      #expression({
        attributeNames = "status";
        filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
      }),
    ]);

    let eventResponse = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventMetadataTable;
        filter = filter;
        limit = 1;
        cursor = null;
      };
      alfangoDB = alfangoDB;
    });

    switch (eventResponse) {
      case (#ok(page)) {
        exists := page.items.size() > 0;
      };
      case (#err(_err)) {
        exists := false;
      };
    };

    return exists;
  };

  public func getEventMetaDataFromStartToEndDate(startDate : Nat, endDate : Nat, categories : [Text], alfangoDB : Database.AlfangoDB) : Result.Result<[ArgumentTypes.EventMetadataResponsePayload], [Text]> {
    let categoriesArray = HelperService.getStringAttributeDataValueArray(categories);

    var filterConditions : [SearchTypes.QueryFilter] = [
      #expression({
        attributeNames = "start_date";
        filterExpressionCondition = #GTE(#nat(startDate));
      }),
      #expression({
        attributeNames = "end_date";
        filterExpressionCondition = #LTE(#nat(endDate));
      }),
      #expression({
        attributeNames = "status";
        filterExpressionCondition = #EQ(#text(Constants.EventStatus.Created));
      }),
    ];

    if (Array.size(categoriesArray) > 0) {
      filterConditions := Array.append(
        filterConditions,
        [
          #expression({
            attributeNames = "categories";
            filterExpressionCondition = #IN(categoriesArray);
          })
        ],
      );
    };

    let filter : SearchTypes.QueryFilter = #AND(filterConditions);

    let items = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventMetadataTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    return CommonService.transformGetAllEventMetadataResponse(items);
  };

  public func getEventMetadataId(eventId : Text, calendarId : Text, alfangoDB : Database.AlfangoDB) : Text {
    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
      #expression({
        attributeNames = "calendar_id";
        filterExpressionCondition = #EQ(#text(calendarId));
      }),
      #expression({
        attributeNames = "status";
        filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
      }),
    ]);

    let result = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventMetadataTable;
        filter = filter;
        limit = 1;
        cursor = null;
      };
      alfangoDB = alfangoDB;
    });

    switch (result) {
      case (#ok(page)) {
        if (page.items.size() > 0) {
          return page.items[0].id;
        } else {
          return "Event metadata not found";
        };
      };
      case (#err(_error)) {
        return "Failed to find event metadata id";
      };
    };
  };
};
