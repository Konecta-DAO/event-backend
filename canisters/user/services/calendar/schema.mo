import Database "mo:alfangodb/AlfangoDB";
import Text "mo:base/Text";
import Map "mo:map/Map";

import CalendarTable "../../tables/calendarTable";
import Constants "../../utils/constants";

module {
  public func createCalendarTable(alfangoDB : Database.AlfangoDB) : Text {

    let item = Database.createTable({
      createTableInput = {
        databaseName = Constants.KonectA;
        name = Constants.CalendarTable;
        attributes = CalendarTable.CalendarTableAttributes;
        indexes = [];
      };
      alfangoDB = alfangoDB;
    });

    switch (item) {
      case (#err(_msg)) {
        return "Failed to create " # Constants.CalendarTable # " database";
      };
      case (#ok(_id)) {
        return Constants.CalendarTable # "table created successfully";
      };
    };

  };
};
