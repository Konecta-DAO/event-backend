import Database "mo:alfangodb/AlfangoDB";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import EventAttendeeTable "../tables/eventAttendeeTable";
import EventTable "../tables/eventTable";
import Constants "../utils/constants";

module {

  public func addAttributesEventTable(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) {
    let attributesToAdd = [
      // Konecta-specific fields
      { name = "event_type"; datatype = #text; unique = false; required = true },
      {
        name = "participation_type";
        datatype = #text;
        unique = false;
        required = true;
      },
      { name = "categories"; datatype = #list; unique = false; required = true },
      {
        name = "consultations";
        datatype = #list;
        unique = false;
        required = false;
      },
      { name = "expertise"; datatype = #text; unique = false; required = false },
      {
        name = "price_token";
        datatype = #text;
        unique = false;
        required = false;
      },
      {
        name = "token_amount";
        datatype = #float;
        unique = false;
        required = false;
      },
      { name = "interests"; datatype = #list; unique = false; required = false },
      {
        name = "showcase_link";
        datatype = #text;
        unique = false;
        required = false;
      },
      {
        name = "recording_visibility";
        datatype = #text;
        unique = false;
        required = false;
      },
      {
        name = "is_recording_available";
        datatype = #bool;
        unique = false;
        required = false;
      },

      // Subaccount and Metadata fields (metadata is likely already there)
      {
        name = "subaccount_id_hex";
        datatype = #text;
        unique = false;
        required = true;
      },
      {
        name = "subaccount_id_index";
        datatype = #nat;
        unique = false;
        required = true;
      },
    ];

    for (attribute in attributesToAdd.vals()) {
      let item = Database.addAttribute({
        addAttributeInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.EventTable;
          attribute = {
            name = attribute.name;
            dataType = attribute.datatype;
            unique = attribute.unique;
            required = attribute.required;
            defaultValue = #default;
          };
        };
        alfangoDB = alfangoDB;
      });

      switch (item) {
        case (#err(msg)) {
          canistergeekLogger.logMessage("Add attribute to Event table error for '" # attribute.name # "': " # debug_show (msg));
        };
        case (#ok(id)) {
          canistergeekLogger.logMessage("Add attribute to Event table success for '" # attribute.name # "': " # debug_show (id));
        };
      };
    };
  };

  public func generateEventSchema(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) : () {
    let _database = createProjectDatabase(alfangoDB);
    let _table = createEventTable(alfangoDB);
    let _eventAttendeeTableResponse = createEventAttendeeTable(alfangoDB);
    addAttributesEventTable(alfangoDB, canistergeekLogger);
    addAttributesEventAttendeeTable(alfangoDB, canistergeekLogger);
  };

  public func createProjectDatabase(alfangoDB : Database.AlfangoDB) : Text {
    let item = Database.createDatabase({
      createDatabaseInput = { name = Constants.KonectA };
      alfangoDB = alfangoDB;
    });

    switch (item) {
      case (#err(_msg)) {
        return "Failed to create " # Constants.KonectA # " database";
      };
      case (#ok({})) {
        return Constants.KonectA # "Database created successfully";
      };
    };
  };

  public func createEventTable(alfangoDB : Database.AlfangoDB) : Text {

    let item = Database.createTable({
      createTableInput = {
        databaseName = Constants.KonectA;
        name = Constants.EventTable;
        attributes = EventTable.EventTableAttributes;
        indexes = EventTable.EventTableIndexes;
      };
      alfangoDB = alfangoDB;
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

  public func createEventAttendeeTable(alfangoDB : Database.AlfangoDB) : Text {

    let item = Database.createTable({
      createTableInput = {
        databaseName = Constants.KonectA;
        name = Constants.EventAttendeeTable;
        attributes = EventAttendeeTable.EventAttendeeTableAttributes;
        indexes = EventAttendeeTable.EventAttendeeTableIndexes;
      };
      alfangoDB = alfangoDB;
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

  public func addAttributesEventAttendeeTable(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) {

    let attributes = [
      {
        name = "event_status";
        datatype = #text;
        unique = false;
        required = true;
      },
    ];

    for (attribute in attributes.vals()) {
      let item = Database.addAttribute({
        addAttributeInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.EventAttendeeTable;
          attribute = {
            name = attribute.name;
            dataType = attribute.datatype;
            unique = attribute.unique;
            required = attribute.required;
            defaultValue = #default;
          };
        };
        alfangoDB = alfangoDB;
      });

      switch (item) {
        case (#err(msg)) {
          canistergeekLogger.logMessage("Add attribute for request applied table error --->" # debug_show (msg));

        };
        case (#ok(id)) {
          canistergeekLogger.logMessage("Add attribute for request applied table success --->" # debug_show (id));

        };
      };
    };

  };
};
