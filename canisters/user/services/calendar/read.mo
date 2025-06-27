import Database "mo:alfangodb/AlfangoDB";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Map "mo:map/Map";
import Constants "../../utils/constants";
import SharedConstants "../../../shared/constants";
import { getTupleValueAsText } "../../../shared/common_utils/helper";

module {
  public func getCalendarId(eventId : Text, databases : Map.Map<Text, Database.Database>) : Text {
    let result = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.EventMetadataTable;
        filterExpressions = [{
          attributeName = "event_id";
          filterExpressionCondition = #EQ(#text(eventId));
        }];
      };
      alfangoDB = { databases };
    });

    switch (result) {
      case (#ok(calendarData)) {
        let calendarId = getTupleValueAsText(calendarData[0].item, "calendar_id");
        return calendarId;
      };

      case (#err(_error)) {
        return "Failed to find calendar id";
      };
    };
  };

  public func checkIfCalendarExistsForEventForUser(_userPrincipal : Principal, eventId : Text, databases : Map.Map<Text, Database.Database>) : Bool {
    var exists = false;

    let calendarResponse = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.EventMetadataTable;
        filterExpressions = [{
          attributeName = "event_id";
          filterExpressionCondition = #EQ(#text(eventId));
        }];
      };
      alfangoDB = { databases };
    });

    switch (calendarResponse) {
      case (#ok(calendarData)) {
        let calendarId = getTupleValueAsText(calendarData[0].item, "calendar_id");

        if (Text.size(calendarId) > 0) {
          exists := true;
        } else {
          exists := false;
        };
        return exists;
      };

      case (#err(_err)) exists := false;
    };

    return exists;
  };

  public func getCalendarTableMetadata(databases : Map.Map<Text, Database.Database>) : Database.GetTableMetadataOutputType {
    Database.getTableMetadata({
      getTableMetadataInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.CalendarTable;
      };
      alfangoDB = { databases };
    });
  };

};
