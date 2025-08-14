import Database "mo:alfangodb/AlfangoDB";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import EventCompletionNotificationTable "../tables/eventCompletionNotificationTable";
import ExpertEmailTable "../tables/expertEmailTable";
import ExpertFeedbackTable "../tables/expertFeedbackTable";
import MissingFeedbackEmailTable "../tables/missingFeedbackEmailTable";
import ResolutionResponseEmailTable "../tables/resolutionResponseEmailTable";
import TransactionTable "../tables/transactionTable";
import UserActionEmailTable "../tables/userActionEmailTable";
import UserFeedbackTable "../tables/userFeedbackTable";
import Constants "../utils/constants";

module {

  public func generateSchema(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) : Text {

    let _database = createProjectDatabase(alfangoDB, canistergeekLogger);
    canistergeekLogger.logMessage("Create Project Database --->" # debug_show (_database));

    let _transactionTableResponse = createTransactionTable(alfangoDB, canistergeekLogger);
    canistergeekLogger.logMessage("Transaction table --->" # debug_show (_transactionTableResponse));

    createTables(alfangoDB, canistergeekLogger);

    let _addAttributesUserFeedbackTable = addAttributesUserFeedbackTable(alfangoDB, canistergeekLogger);

    let _addAttributesExpertFeedbackTable = addAttributesExpertFeedbackTable(alfangoDB, canistergeekLogger);

    let _addAttributesResolutionResponseEmailTable = addAttributesResolutionResponseEmailTable(alfangoDB, canistergeekLogger);

    let _addAttributesUserActionEmailTable = addAttributesUserActionEmailTable(alfangoDB, canistergeekLogger);

    return "Schema created successfully";
  };

  private func createProjectDatabase(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) : Text {
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

  private func createTransactionTable(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) : Text {

    let item = Database.createTable({
      createTableInput = {
        databaseName = Constants.KonectA;
        name = Constants.TransactionTable;
        attributes = TransactionTable.TransactionTableAttributes;
        indexes = TransactionTable.TransactionTableIndexes;
      };
      alfangoDB = alfangoDB;
    });

    switch (item) {
      case (#err(msg)) {
        canistergeekLogger.logMessage("Create Transaction table error --->" # debug_show (msg));
        return "Failed to create " # Constants.TransactionTable # " database";
      };
      case (#ok(_id)) {
        return Constants.TransactionTable # "table created successfully";
      };
    };

  };

  private func createTables(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) {

    let tablesArr = [
      {
        name = Constants.EventCompletionNotificationTable;
        attributes = EventCompletionNotificationTable.EventCompletionNotificationTableAttributes;
        indexes = EventCompletionNotificationTable.EventCompletionNotificationTableIndexes;
      },
      {
        name = Constants.UserFeedbackTable;
        attributes = UserFeedbackTable.UserFeedbackTableAttributes;
        indexes = UserFeedbackTable.UserFeedbackTableIndexes;
      },
      {
        name = Constants.ExpertEmailTable;
        attributes = ExpertEmailTable.ExpertEmailTableAttributes;
        indexes = ExpertEmailTable.ExpertEmailTableIndexes;
      },
      {
        name = Constants.ExpertFeedbackTable;
        attributes = ExpertFeedbackTable.ExpertFeedbackTableAttributes;
        indexes = ExpertFeedbackTable.ExpertFeedbackTableIndexes;
      },
      {
        name = Constants.ResolutionResponseEmailTable;
        attributes = ResolutionResponseEmailTable.ResolutionResponseEmailTableAttributes;
        indexes = ResolutionResponseEmailTable.ResolutionResponseEmailTableIndexes;
      },
      {
        name = Constants.UserActionEmailTable;
        attributes = UserActionEmailTable.UserActionEmailAttributes;
        indexes = UserActionEmailTable.UserActionEmailTableIndexes;
      },
      {
        name = Constants.MissingFeedbackEmailTable;
        attributes = MissingFeedbackEmailTable.MissingFeedbackEmailTableAttributes;
        indexes = MissingFeedbackEmailTable.MissingFeedbackEmailTableIndexes;
      },
    ];

    for (table in tablesArr.vals()) {
      let item = Database.createTable({
        createTableInput = {
          databaseName = Constants.KonectA;
          name = table.name;
          attributes = table.attributes;
          indexes = table.indexes;
        };
        alfangoDB = alfangoDB;
      });

      switch (item) {
        case (#err(msg)) {
          canistergeekLogger.logMessage("Create Transaction table error --->" # debug_show (msg));

        };
        case (#ok(_id)) {

        };
      };
    };

  };

  private func addAttributesUserFeedbackTable(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) {

    let attributes = [
      {
        name = "successful";
        datatype = #text;
        unique = false;
        required = true;
      },
      {
        name = "recording_link";
        datatype = #text;
        unique = false;
        required = false;
      },
      {
        name = "firstname";
        datatype = #text;
        unique = false;
        required = true;
      },
      {
        name = "lastname";
        datatype = #text;
        unique = false;
        required = true;
      },
      {
        name = "email";
        datatype = #text;
        unique = false;
        required = true;
      },
      {
        name = "username";
        datatype = #text;
        unique = false;
        required = true;
      },
      {
        name = "timezone";
        datatype = #text;
        unique = false;
        required = true;
      },
    ];

    for (attribute in attributes.vals()) {
      let item = Database.addAttribute({
        addAttributeInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.UserFeedbackTable;
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
          canistergeekLogger.logMessage("Add attribute for user feedback table error --->" # debug_show (msg));

        };
        case (#ok(id)) {
          canistergeekLogger.logMessage("Add attribute for user feedback table success --->" # debug_show (id));

        };
      };
    };

  };

  private func addAttributesExpertFeedbackTable(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) {

    let attributes = [
      {
        name = "agreeWithUserFeedback";
        datatype = #text;
        unique = false;
        required = false;
      },
      {
        name = "user_feedback_id";
        datatype = #text;
        unique = false;
        required = false;
      },
      {
        name = "user_id";
        datatype = #text;
        unique = false;
        required = false;
      },
      {
        name = "transfer_or_refund"; // #TransferToBeneficiary; #RefundToRemitter;
        datatype = #text;
        unique = false;
        required = false;
      },
      {
        name = "remitter_feedback_missing";
        datatype = #bool;
        unique = false;
        required = true;
      },
      {
        name = "event_recording_link";
        datatype = #text;
        unique = false;
        required = false;
      },
    ];

    for (attribute in attributes.vals()) {
      let item = Database.addAttribute({
        addAttributeInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.ExpertFeedbackTable;
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
          canistergeekLogger.logMessage("Add attribute for expert feedback table error --->" # debug_show (msg));

        };
        case (#ok(id)) {
          canistergeekLogger.logMessage("Add attribute for expert feedback table success --->" # debug_show (id));

        };
      };
    };

  };

  private func addAttributesResolutionResponseEmailTable(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) {

    let attributes = [{
      name = "transaction_id";
      datatype = #text;
      unique = false;
      required = false;
    }];

    for (attribute in attributes.vals()) {
      let item = Database.addAttribute({
        addAttributeInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.ResolutionResponseEmailTable;
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
          canistergeekLogger.logMessage("Add attribute for resolution response email table error --->" # debug_show (msg));

        };
        case (#ok(id)) {
          canistergeekLogger.logMessage("Add attribute for resolution response email table success --->" # debug_show (id));

        };
      };
    };

  };

  private func addAttributesUserActionEmailTable(alfangoDB : Database.AlfangoDB, _canistergeekLogger : Canistergeek.Logger) {

    let attributes = [{
      name = "idempotency_key";
      datatype = #text;
      unique = true;
      required = true;
    }];

    let tables = [
      Constants.UserActionEmailTable,
      Constants.ExpertEmailTable,
      Constants.EventCompletionNotificationTable,
      Constants.ResolutionResponseEmailTable,
    ];
    for (attribute in attributes.vals()) {
      for (table in tables.vals()) {

        let _item = Database.addAttribute({
          addAttributeInput = {
            databaseName = Constants.KonectA;
            tableName = table;
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
      };

    };

  };

};
