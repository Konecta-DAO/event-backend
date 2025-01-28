import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import CalendarTable "../../tables/calendarTable";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import { getTupleValueAsText } "../../utils/helper";

module {
  public func createCalendarTable(databases : Map.Map<Text, Database.Database>) : async Text {

    let item = Database.createTable({
      createTableInput = {
        databaseName = Constants.KonectA;
        name = Constants.CalendarTable;
        attributes = CalendarTable.CalendarTableAttributes;
        indexes = [];
      };
      alfangoDB = { databases };
    });

    switch (item) {
      case (#err(msg)) {
        return "Failed to create " # Constants.CalendarTable # " database";
      };
      case (#ok(id)) {
        return Constants.CalendarTable # "table created successfully";
      };
    };

  };
};
