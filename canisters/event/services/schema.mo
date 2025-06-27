import Database "mo:alfangodb/AlfangoDB";
import Map "mo:map/Map";
import SharedConstants "../../shared/constants";
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
      createDatabaseInput = { name = SharedConstants.KonectA };
      alfangoDB = { databases };
    });

    switch (item) {
      case (#err(_msg)) {
        return "Failed to create " # SharedConstants.KonectA # " database";
      };
      case (#ok({})) {
        return SharedConstants.KonectA # "Database created successfully";
      };
    };
  };

  public func createEventTable(databases : Map.Map<Text, Database.Database>) : async Text {

    let item = Database.createTable({
      createTableInput = {
        databaseName = SharedConstants.KonectA;
        name = Constants.EventTable;
        attributes = EventTable.EventTableAttributes;
        indexes = EventTable.EventTableIndexes;
      };
      alfangoDB = { databases };
    });

    switch (item) {
      case (#err(_msg)) {
        return "Failed to create " # Constants.EventTable # " database";
      };
      case (#ok(_id)) {
        return Constants.EventTable # "table created successfully";
      };
    };

  };

  public func createEventAttendeeTable(databases : Map.Map<Text, Database.Database>) : async Text {

    let item = Database.createTable({
      createTableInput = {
        databaseName = SharedConstants.KonectA;
        name = Constants.EventAttendeeTable;
        attributes = EventAttendeeTable.EventAttendeeTableAttributes;
        indexes = EventAttendeeTable.EventAttendeeTableIndexes;
      };
      alfangoDB = { databases };
    });

    switch (item) {
      case (#err(_msg)) {
        return "Failed to create " # Constants.EventAttendeeTable # " database";
      };
      case (#ok(_id)) {
        return Constants.EventAttendeeTable # "table created successfully";
      };
    };

  };

};
