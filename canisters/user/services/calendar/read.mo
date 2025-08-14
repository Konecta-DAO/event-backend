import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Map "mo:map/Map";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import Constants "../../utils/constants";
import { getTupleValueAsText } "../../utils/helper";

module {
  public func getCalendarId(alfangoDB : Database.AlfangoDB) : Text {
    let result = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.CalendarTable;
        filter = #AND([]);
      };
      alfangoDB = alfangoDB;
    });

    switch (result) {
      case (#ok(calendarData)) {
        var calendarId = "";
        if (Array.size(calendarData) > 0) {
          calendarId := calendarData[0].id;
        };
        return calendarId;
      };

      case (#err(_error)) {
        return "Failed to find calendar id";
      };
    };
  };

};
