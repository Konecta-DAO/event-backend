import Database "mo:alfangodb/AlfangoDB";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Result "mo:base/Result";
import ArgumentTypes "../types/argumentTypes";
import Constants "../utils/constants";
import Helper "../utils/helper";
import LedgerService "shared/ledger";

module {
  public func getUserCanisterId(userPrincipal : Principal, alfangoDB : Database.AlfangoDB) : Text {
    let filter : SearchTypes.QueryFilter = #expression({
      attributeNames = "principal_id";
      filterExpressionCondition = #EQ(#principal(userPrincipal));
    });

    let scanResponse = Database.scan({
      scanInput = {
        databaseName = Constants.IndexDBName;
        tableName = Constants.UserDataTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (scanResponse) {
      case (#ok(items)) {
        if (items.size() > 0) {
          return Helper.getTupleValueAsText(items[0].item, "canister_id");
        };
      };
      case (#err(_)) {};
    };
    return "";
  };

  public func getUserAccountInfo(
    userPrincipal : Principal,
    alfangoDB : Database.AlfangoDB,
    subAccountIndex : Nat,
    canisterPrincipalId : Text,
    canistergeekLogger : Canistergeek.Logger,
  ) : async ArgumentTypes.UserAccountInfoPayload {
    var canisterId = getUserCanisterId(userPrincipal, alfangoDB);
    var subaccountIdHex = "";
    var subaccountLedgerIdentifier = "";

    let filter : SearchTypes.QueryFilter = #expression({
      attributeNames = "principal_id";
      filterExpressionCondition = #EQ(#principal(userPrincipal));
    });

    let scanResponse = Database.scan({
      scanInput = {
        databaseName = Constants.IndexDBName;
        tableName = Constants.UserSubaccountTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    var userAccountItem : ?{
      id : Text;
      item : [(Text, Database.AttributeDataValue)];
    } = null;
    switch (scanResponse) {
      case (#ok(items)) {
        if (items.size() > 0) {
          userAccountItem := ?items[0];
        };
      };
      case (#err(_)) {};
    };

    switch (userAccountItem) {
      case (?userAccount) {
        let accountAttributes = userAccount.item;
        subaccountIdHex := Helper.getTupleValueAsText(accountAttributes, "subaccount_id_hex");
        subaccountLedgerIdentifier := Helper.getTupleValueAsText(accountAttributes, "subaccount_ledger_identifier");
        canistergeekLogger.logMessage("Subaccount found --> " # subaccountIdHex);
      };
      case (null) {
        subaccountIdHex := LedgerService.getSubAccountIdHex(subAccountIndex, canisterPrincipalId);
        subaccountLedgerIdentifier := LedgerService.getLedgerAccountFromSubaccountHex(Principal.toText(userPrincipal), ?subaccountIdHex);
        canistergeekLogger.logMessage("New subaccount created --> " # subaccountIdHex);

        let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
          ("principal_id", #principal(userPrincipal)),
          ("subaccount_id_hex", #text(subaccountIdHex)),
          ("subaccount_index", #nat(subAccountIndex)),
          ("subaccount_ledger_identifier", #text(subaccountLedgerIdentifier)),
        ];

        ignore await Database.createItem({
          createItemInput = {
            databaseName = Constants.IndexDBName;
            tableName = Constants.UserSubaccountTable;
            attributeDataValues = attributeDataValues;
          };
          alfangoDB = alfangoDB;
        });
        canistergeekLogger.logMessage("User subaccount map updated");
      };
    };

    return {
      canister_id = canisterId;
      subaccount_id_hex = subaccountIdHex;
      subaccount_ledger_identifier = subaccountLedgerIdentifier;
    };
  };

  private func scanToUserMapPayload(item : { id : Text; item : [(Text, Database.AttributeDataValue)] }) : ArgumentTypes.UserMapPayload {
    let itemMap = Helper.attributeArrayToHashMap(item.item);
    return {
      principal_id = Principal.fromText(Helper.getAttributeFromMapAsText(itemMap, "principal_id"));
      canister_id = Principal.fromText(Helper.getAttributeFromMapAsText(itemMap, "canister_id"));
      username = Helper.getAttributeFromMapAsText(itemMap, "username");
    };
  };

  public func findUser(userPrincipal : Text, alfangoDB : Database.AlfangoDB) : ?ArgumentTypes.UserMapPayload {
    let filter : SearchTypes.QueryFilter = #expression({
      attributeNames = "principal_id";
      filterExpressionCondition = #EQ(#principal(Principal.fromText(userPrincipal)));
    });

    let scanResponse = Database.scan({
      scanInput = {
        databaseName = Constants.IndexDBName;
        tableName = Constants.UserDataTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (scanResponse) {
      case (#ok(items)) {
        if (items.size() > 0) {
          return ?scanToUserMapPayload(items[0]);
        };
      };
      case (#err(_)) {};
    };
    return null;
  };

  public func userExistsOrNot(userPrincipal : Principal, alfangoDB : Database.AlfangoDB) : Bool {
    let filter : SearchTypes.QueryFilter = #expression({
      attributeNames = "principal_id";
      filterExpressionCondition = #EQ(#principal(userPrincipal));
    });

    let response = Database.scanAndGetIds({
      scanAndGetIdsInput = {
        databaseName = Constants.IndexDBName;
        tableName = Constants.UserDataTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (response) {
      case (#ok(res)) { return res.ids.size() > 0 };
      case (#err(_)) { return false };
    };
  };

  public func usernameExistsOrNot(username : Text, alfangoDB : Database.AlfangoDB) : ?ArgumentTypes.UserMapPayload {
    let filter : SearchTypes.QueryFilter = #expression({
      attributeNames = "username";
      filterExpressionCondition = #EQ(#text(username));
    });

    let scanResponse = Database.scan({
      scanInput = {
        databaseName = Constants.IndexDBName;
        tableName = Constants.UserDataTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (scanResponse) {
      case (#ok(items)) {
        if (items.size() > 0) {
          return ?scanToUserMapPayload(items[0]);
        };
      };
      case (#err(_)) {};
    };
    return null;
  };

  public func getListOfUsers(alfangoDB : Database.AlfangoDB) : [ArgumentTypes.UserMapPayload] {
    let BATCH_SIZE : Nat = 100;
    let resultsBuffer = Buffer.Buffer<ArgumentTypes.UserMapPayload>(0);
    var cursor : ?SearchTypes.PaginatedScanCursor = null;

    label paginatedLoop loop {
      let pageResult = Database.paginatedScan({
        paginatedScanInput = {
          databaseName = Constants.IndexDBName;
          tableName = Constants.UserDataTable;
          filter = #AND([]);
          limit = BATCH_SIZE;
          cursor = cursor;
        };
        alfangoDB = alfangoDB;
      });

      switch (pageResult) {
        case (#ok(page)) {
          for (item in page.items.vals()) {
            resultsBuffer.add(scanToUserMapPayload(item));
          };
          if (page.hasMore) {
            cursor := page.nextCursor;
            continue paginatedLoop;
          } else {
            break paginatedLoop;
          };
        };
        case (#err(_)) {
          break paginatedLoop;
        };
      };
    };
    return Buffer.toArray(resultsBuffer);
  };

  public func getListOfUserSubaccounts(alfangoDB : Database.AlfangoDB) : [ArgumentTypes.SubaccountMapPayload] {
    let BATCH_SIZE : Nat = 100;
    let resultsBuffer = Buffer.Buffer<ArgumentTypes.SubaccountMapPayload>(0);
    var cursor : ?SearchTypes.PaginatedScanCursor = null;

    label paginatedLoop loop {
      let scanResponse = Database.paginatedScan({
        paginatedScanInput = {
          databaseName = Constants.IndexDBName;
          tableName = Constants.UserSubaccountTable;
          filter = #AND([]);
          limit = BATCH_SIZE;
          cursor = cursor;
        };
        alfangoDB = alfangoDB;
      });

      switch (scanResponse) {
        case (#ok(page)) {
          for (item in page.items.vals()) {
            let itemMap = Helper.attributeArrayToHashMap(item.item);
            let principalText = Helper.getAttributeFromMapAsText(itemMap, "principal_id");
            let indexText = Helper.getAttributeFromMapAsText(itemMap, "subaccount_index");
            resultsBuffer.add({
              principal_id = Principal.fromText(principalText);
              subaccount_id_hex = Helper.getAttributeFromMapAsText(itemMap, "subaccount_id_hex");
              subaccount_index = Helper.textToNat(indexText);
              subaccount_ledger_identifier = Helper.getAttributeFromMapAsText(itemMap, "subaccount_ledger_identifier");
            });
          };
          if (page.hasMore) {
            cursor := page.nextCursor;
            continue paginatedLoop;
          } else {
            break paginatedLoop;
          };
        };
        case (#err(_)) {
          break paginatedLoop;
        };
      };
    };
    return Buffer.toArray(resultsBuffer);
  };

  public func getSubaccountForUser(userPrincipal : Principal, alfangoDB : Database.AlfangoDB) : ?ArgumentTypes.SubaccountMapPayload {
    let filter : SearchTypes.QueryFilter = #expression({
      attributeNames = "principal_id";
      filterExpressionCondition = #EQ(#principal(userPrincipal));
    });
    let scanResponse = Database.scan({
      scanInput = {
        databaseName = Constants.IndexDBName;
        tableName = Constants.UserSubaccountTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (scanResponse) {
      case (#ok(items)) {
        if (items.size() > 0) {
          let itemMap = Helper.attributeArrayToHashMap(items[0].item);
          let payload : ArgumentTypes.SubaccountMapPayload = {
            principal_id = userPrincipal;
            subaccount_id_hex = Helper.getAttributeFromMapAsText(itemMap, "subaccount_id_hex");
            subaccount_index = Helper.textToNat(Helper.getAttributeFromMapAsText(itemMap, "subaccount_index"));
            subaccount_ledger_identifier = Helper.getAttributeFromMapAsText(itemMap, "subaccount_ledger_identifier");
          };
          return ?payload;
        };
      };
      case (#err(_)) {};
    };
    return null;
  };

  public func getListOfCanisters(alfangoDB : Database.AlfangoDB) : [ArgumentTypes.CanisterMapPayload] {
    let BATCH_SIZE : Nat = 100;
    let resultsBuffer = Buffer.Buffer<ArgumentTypes.CanisterMapPayload>(0);
    var cursor : ?SearchTypes.PaginatedScanCursor = null;

    label paginatedLoop loop {
      let scanResponse = Database.paginatedScan({
        paginatedScanInput = {
          databaseName = Constants.IndexDBName;
          tableName = Constants.UserDataTable;
          filter = #AND([]);
          limit = BATCH_SIZE;
          cursor = cursor;
        };
        alfangoDB = alfangoDB;
      });
      switch (scanResponse) {
        case (#ok(page)) {
          for (item in page.items.vals()) {
            let itemMap = Helper.attributeArrayToHashMap(item.item);
            resultsBuffer.add({
              principal_id = Helper.getAttributeFromMapAsText(itemMap, "principal_id");
              canister_id = Helper.getAttributeFromMapAsText(itemMap, "canister_id");
            });
          };
          if (page.hasMore) {
            cursor := page.nextCursor;
            continue paginatedLoop;
          } else {
            break paginatedLoop;
          };
        };
        case (#err(_)) {
          break paginatedLoop;
        };
      };
    };
    return Buffer.toArray(resultsBuffer);
  };

  public func getUserCanistersByPrincipal(userPrincipalArr : [Text], alfangoDB : Database.AlfangoDB) : [ArgumentTypes.CanisterMapPayload] {

    let principalFilterValues = Buffer.Buffer<Database.RelationalExpressionAttributeDataValue>(userPrincipalArr.size());
    for (principalText in userPrincipalArr.vals()) {
      principalFilterValues.add(#principal(Principal.fromText(principalText)));
    };

    let filter : SearchTypes.QueryFilter = #expression({
      attributeNames = "principal_id";
      filterExpressionCondition = #IN(Buffer.toArray(principalFilterValues));
    });

    let scanResponse = Database.scan({
      scanInput = {
        databaseName = Constants.IndexDBName;
        tableName = Constants.UserDataTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });
    switch (scanResponse) {
      case (#ok(items)) {
        let buffer = Buffer.Buffer<ArgumentTypes.CanisterMapPayload>(items.size());
        for (item in items.vals()) {
          let itemMap = Helper.attributeArrayToHashMap(item.item);
          buffer.add({
            principal_id = Helper.getAttributeFromMapAsText(itemMap, "principal_id");
            canister_id = Helper.getAttributeFromMapAsText(itemMap, "canister_id");
          });
        };
        return Buffer.toArray(buffer);
      };
      case (#err(_)) { return [] };
    };
  };

  public func getListofTransactions(alfangoDB : Database.AlfangoDB) : [ArgumentTypes.TransactionResponsePayload] {
    let BATCH_SIZE : Nat = 100;
    let resultsBuffer = Buffer.Buffer<ArgumentTypes.TransactionResponsePayload>(0);
    var cursor : ?SearchTypes.PaginatedScanCursor = null;

    label paginatedLoop loop {
      let scanResponse = Database.paginatedScan({
        paginatedScanInput = {
          databaseName = Constants.IndexDBName;
          tableName = Constants.TransactionTable;
          filter = #AND([]);
          limit = BATCH_SIZE;
          cursor = cursor;
        };
        alfangoDB = alfangoDB;
      });
      switch (scanResponse) {
        case (#ok(page)) {
          for (item in page.items.vals()) {
            let itemMap = Helper.attributeArrayToHashMap(item.item);
            resultsBuffer.add({
              principal_id = Principal.fromText(Helper.getAttributeFromMapAsText(itemMap, "principal_id"));
              subaccount_index = Helper.textToNat(Helper.getAttributeFromMapAsText(itemMap, "subaccount_index"));
              source_account_id_hex = Helper.getAttributeFromMapAsText(itemMap, "source_account_id_hex");
              destination_account_id_hex = Helper.getAttributeFromMapAsText(itemMap, "destination_account_id_hex");
              block_index = Helper.textToNat(Helper.getAttributeFromMapAsText(itemMap, "block_index"));
              amount = Helper.textToNat(Helper.getAttributeFromMapAsText(itemMap, "amount"));
              fee = Helper.textToNat(Helper.getAttributeFromMapAsText(itemMap, "fee"));
              narration = Helper.getAttributeFromMapAsText(itemMap, "narration");
              memo = null;
              created_at_time = Helper.textToNat64(Helper.getAttributeFromMapAsText(itemMap, "created_at_time"));
            });
          };
          if (page.hasMore) {
            cursor := page.nextCursor;
            continue paginatedLoop;
          } else {
            break paginatedLoop;
          };
        };
        case (#err(_)) {
          break paginatedLoop;
        };
      };
    };
    return Buffer.toArray(resultsBuffer);
  };
};
