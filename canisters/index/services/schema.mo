import Database "mo:alfangodb/AlfangoDB";
import Canistergeek "mo:canistergeek/canistergeek";

import TransactionTable "../tables/transactionTable";
import UserDataTable "../tables/userDataTable";
import UserSubaccountTable "../tables/userSubaccountTable";
import Constants "../utils/constants";

module {

  public func generateIndexSchema(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) : () {
    let _database = createProjectDatabase(alfangoDB, canistergeekLogger);
    let _userDataTable = createUserDataTable(alfangoDB, canistergeekLogger);
    let _userSubaccountTable = createUserSubaccountTable(alfangoDB, canistergeekLogger);
    let _transactionTable = createTransactionTable(alfangoDB, canistergeekLogger);
  };

  private func createProjectDatabase(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) {
    let item = Database.createDatabase({
      createDatabaseInput = { name = Constants.IndexDBName };
      alfangoDB = alfangoDB;
    });
    canistergeekLogger.logMessage("Create Database response ---> " # debug_show (item));
  };

  private func createUserDataTable(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) {
    let item = Database.createTable({
      createTableInput = {
        databaseName = Constants.IndexDBName;
        name = Constants.UserDataTable;
        attributes = UserDataTable.UserDataTableAttributes;
        indexes = UserDataTable.UserDataTableIndexes;
      };
      alfangoDB = alfangoDB;
    });
    canistergeekLogger.logMessage("Create UserDataTable response ---> " # debug_show (item));
  };

  private func createUserSubaccountTable(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) {
    let item = Database.createTable({
      createTableInput = {
        databaseName = Constants.IndexDBName;
        name = Constants.UserSubaccountTable;
        attributes = UserSubaccountTable.UserSubaccountTableAttributes;
        indexes = UserSubaccountTable.UserSubaccountTableIndexes;
      };
      alfangoDB = alfangoDB;
    });
    canistergeekLogger.logMessage("Create UserSubaccountTable response ---> " # debug_show (item));
  };

  private func createTransactionTable(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger) {
    let item = Database.createTable({
      createTableInput = {
        databaseName = Constants.IndexDBName;
        name = Constants.TransactionTable;
        attributes = TransactionTable.TransactionTableAttributes;
        indexes = TransactionTable.TransactionTableIndexes;
      };
      alfangoDB = alfangoDB;
    });
    canistergeekLogger.logMessage("Create TransactionTable response ---> " # debug_show (item));
  };

};
