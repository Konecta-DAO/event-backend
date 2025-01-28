import Database "mo:alfangodb/AlfangoDB";
import Map "mo:map/Map";

import EventAttendeeTable "../tables/eventAttendeeTable";
import EventTable "../tables/eventTable";
import Constants "../utils/constants";

module {

  public func generateEventSchema(databases : Map.Map<Text, Database.Database>) : async () {
    let _database = await createProjectDatabase(databases);
    let _table = await createEventTable(databases);
    let _eventAttendeeTableResponse = await createEventAttendeeTable(databases);
  };

  public func createProjectDatabase(databases : Map.Map<Text, Database.Database>) : async Text {
    let item = Database.createDatabase({
      createDatabaseInput = { name = Constants.KonectA };
      alfangoDB = { databases };
    });

    switch (item) {
      case (#err(msg)) {
        return "Failed to create " # Constants.KonectA # " database";
      };
      case (#ok({})) {
        return Constants.KonectA # "Database created successfully";
      };
    };
  };

  public func createEventTable(databases : Map.Map<Text, Database.Database>) : async Text {

    let item = Database.createTable({
      createTableInput = {
        databaseName = Constants.KonectA;
        name = Constants.EventTable;
        attributes = EventTable.EventTableAttributes;
        indexes = EventTable.EventTableIndexes;
      };
      alfangoDB = { databases };
    });

    switch (item) {
      case (#err(msg)) {
        return "Failed to create " # Constants.EventTable # " database";
      };
      case (#ok(id)) {
        return Constants.EventTable # "table created successfully";
      };
    };

  };

  public func createEventAttendeeTable(databases : Map.Map<Text, Database.Database>) : async Text {

    let item = Database.createTable({
      createTableInput = {
        databaseName = Constants.KonectA;
        name = Constants.EventAttendeeTable;
        attributes = EventAttendeeTable.EventAttendeeTableAttributes;
        indexes = EventAttendeeTable.EventAttendeeTableIndexes;
      };
      alfangoDB = { databases };
    });

    switch (item) {
      case (#err(msg)) {
        return "Failed to create " # Constants.EventAttendeeTable # " database";
      };
      case (#ok(id)) {
        return Constants.EventAttendeeTable # "table created successfully";
      };
    };

  };

};
