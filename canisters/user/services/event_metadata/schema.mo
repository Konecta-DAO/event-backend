import Database "mo:alfangodb/AlfangoDB";
import Text "mo:base/Text";
import Map "mo:map/Map";

import EventMetadataTable "../../tables/eventMetadataTable";
import Constants "../../utils/constants";

module {
  public func createEventMetadataTable(databases : Map.Map<Text, Database.Database>) : async Text {

    let item = Database.createTable({
      createTableInput = {
        databaseName = Constants.KonectA;
        name = Constants.EventMetadataTable;
        attributes = EventMetadataTable.EventMetadataTableAttributes;
        indexes = [];
      };
      alfangoDB = { databases };
    });

    switch (item) {
      case (#err(msg)) {
        return "Failed to create " # Constants.EventMetadataTable # " database";
      };
      case (#ok(id)) {
        return Constants.EventMetadataTable # "table created successfully";
      };
    };

  };

  public func addStatusToEventMetadata(databases : Map.Map<Text, Database.Database>) : async Text {

    let item = Database.addAttribute({
      addAttributeInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventMetadataTable;
        attribute = {
          name = "status";
          dataType = #text;
          unique = false;
          required = true;
          defaultValue = #default;
        };
      };
      alfangoDB = { databases };
    });

    switch (item) {
      case (#err(msg)) {
        return "Failed to update schema";
      };
      case (#ok(id)) {
        return "Schema updated successfully";
      };
    };

  };
};
