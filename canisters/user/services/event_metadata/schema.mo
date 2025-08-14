import Database "mo:alfangodb/AlfangoDB";
import Text "mo:base/Text";
import Map "mo:map/Map";

import EventMetadataTable "../../tables/eventMetadataTable";
import Constants "../../utils/constants";

module {
  public func createEventMetadataTable(alfangoDB : Database.AlfangoDB) : Text {

    let item = Database.createTable({
      createTableInput = {
        databaseName = Constants.KonectA;
        name = Constants.EventMetadataTable;
        attributes = EventMetadataTable.EventMetadataTableAttributes;
        indexes = EventMetadataTable.EventMetadataTableIndexes;
      };
      alfangoDB = alfangoDB;
    });

    switch (item) {
      case (#err(_msg)) {
        return "Failed to create " # Constants.EventMetadataTable # " database";
      };
      case (#ok(_id)) {
        return Constants.EventMetadataTable # "table created successfully";
      };
    };

  };
};
