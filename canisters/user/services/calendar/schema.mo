import Database "mo:alfangodb/AlfangoDB";
import Text "mo:base/Text";
import Map "mo:map/Map";
import SharedConstants "../../../shared/constants";
import CalendarTable "../../tables/calendarTable";
import Constants "../../utils/constants";

module {
  public func createCalendarTable(databases : Map.Map<Text, Database.Database>) : async Text {

    let item = Database.createTable({
      createTableInput = {
        databaseName = SharedConstants.KonectA;
        name = Constants.CalendarTable;
        attributes = CalendarTable.CalendarTableAttributes;
        indexes = [];
      };
      alfangoDB = { databases };
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
