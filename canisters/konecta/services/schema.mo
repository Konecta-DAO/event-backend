import Database "mo:alfangodb/AlfangoDB";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import SharedConstants "../../shared/constants";
import KonectaEventTable "../tables/konectaEventTable";
import RequestAppliedTable "../tables/requestAppliedTable";
import Constants "../utils/constants";

module {
  public func createProjectDatabase(databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Text {
    let item = Database.createDatabase({
      createDatabaseInput = { name = SharedConstants.KonectA };
      alfangoDB = { databases };
    });

    switch (item) {
      case (#err(msg)) {
        canistergeekLogger.logMessage("Create Konecta database error --->" # debug_show (msg));
        return "Failed to create " # SharedConstants.KonectA # " database";
      };
      case (#ok({})) {
        return SharedConstants.KonectA # "Database created successfully";
      };
    };
  };

  public func createKonectaEventTable(databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Text {

    let item = Database.createTable({
      createTableInput = {
        databaseName = SharedConstants.KonectA;
        name = Constants.KonectAEventTable;
        attributes = KonectaEventTable.KonectaEventTableAttributes;
        indexes = KonectaEventTable.KonectaEventTableIndexes;
      };
      alfangoDB = { databases };
    });

    switch (item) {
      case (#err(msg)) {
        canistergeekLogger.logMessage("Create Konecta table error --->" # debug_show (msg));
        return "Failed to create " # Constants.KonectAEventTable # " database";
      };
      case (#ok(_id)) {
        return Constants.KonectAEventTable # "table created successfully";
      };
    };

  };

  public func createRequestAppliedTable(databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Text {

    let item = Database.createTable({
      createTableInput = {
        databaseName = SharedConstants.KonectA;
        name = Constants.RequestAppliedTable;
        attributes = RequestAppliedTable.RequestAppliedTableAttributes;
        indexes = RequestAppliedTable.RequestAppliedTableIndexes;
      };
      alfangoDB = { databases };
    });

    switch (item) {
      case (#err(msg)) {
        canistergeekLogger.logMessage("Create Request Applied table error --->" # debug_show (msg));
        return "Failed to create " # Constants.RequestAppliedTable # " database";
      };
      case (#ok(_id)) {
        return Constants.RequestAppliedTable # "table created successfully";
      };
    };

  };

  public func addStatusToKonecta(databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Text {

    let item = Database.addAttribute({
      addAttributeInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.KonectAEventTable;
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
        canistergeekLogger.logMessage("Add status to Konecta table error --->" # debug_show (msg));
        return "Failed to update schema";
      };
      case (#ok(_id)) {
        return "Schema updated successfully";
      };
    };

  };

  public func addLocationToRequestAppliedTable(databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Text {

    let item = Database.addAttribute({
      addAttributeInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.RequestAppliedTable;
        attribute = {
          name = "location";
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
        canistergeekLogger.logMessage("Add location to request applied table error --->" # debug_show (msg));
        return "Failed to update schema";
      };
      case (#ok(_id)) {
        return "Schema updated successfully";
      };
    };

  };

};
