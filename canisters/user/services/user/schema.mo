import Database "mo:alfangodb/AlfangoDB";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import CalendarSchemaService "../../services/calendar/schema";
import EventMetadataSchemaService "../../services/event_metadata/schema";
import Constants "../../utils/constants";

module {
  public func generateSchema(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) : Text {

    let _database = createProjectDatabase(alfangoDB, canistergeekLogger);
    canistergeekLogger.logMessage("Create Project Database --->" # debug_show (_database));

    let _calendarTableResponse = CalendarSchemaService.createCalendarTable(alfangoDB);
    canistergeekLogger.logMessage("Calendar table response --->" # debug_show (_calendarTableResponse));

    let _eventMetadataTableResponse = EventMetadataSchemaService.createEventMetadataTable(alfangoDB);
    canistergeekLogger.logMessage("Event Metadata table response --->" # debug_show (_eventMetadataTableResponse));

    return "Schema created successfully";
  };

  public func createProjectDatabase(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) : Text {
    let item = Database.createDatabase({
      createDatabaseInput = { name = Constants.KonectA };
      alfangoDB = alfangoDB;
    });

    switch (item) {
      case (#err(msg)) {
        canistergeekLogger.logMessage("Create Konecta database error --->" # debug_show (msg));
        return "Failed to create " # Constants.KonectA # " database";
      };
      case (#ok({})) {
        return Constants.KonectA # "Database created successfully";
      };
    };
  };
};
