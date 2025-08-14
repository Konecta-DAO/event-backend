import Database "mo:alfangodb/AlfangoDB";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import UserCanisterActor "../../user/main";
import Ledger "../candid/ledger";
import CommonService "../services/common";
import LedgerService "../services/shared/ledger";
import ReadService "../services/read";
import ArgumentTypes "../types/argumentTypes";
import Constants "../utils/constants";
import Helper "../utils/helper";
import Account "icPCH/Account";
import HashMap "mo:base/HashMap";

module {
  /**
   * Updates a user record. Since a principal ID cannot be changed in place,
   * this involves deleting the old records and creating new ones.
   * This is a complex operation and should be used with caution.
   */
  public func updateUserRecord(
    principal : Principal,
    values : ArgumentTypes.UpdateUserRequestPayload,
    alfangoDB : Database.AlfangoDB,
  ) : async Text {
    func findAndDelete(tableName : Text, principalToDelete : Principal) : async Bool {
      let filter : SearchTypes.QueryFilter = #expression({
        attributeNames = "principal_id";
        filterExpressionCondition = #EQ(#principal(principalToDelete));
      });
      let scanResult = Database.scanAndGetIds({
        scanAndGetIdsInput = {
          databaseName = Constants.IndexDBName;
          tableName = tableName;
          filter = filter;
        };
        alfangoDB = alfangoDB;
      });
      switch (scanResult) {
        case (#ok(res)) {
          if (res.ids.size() > 0) {
            let deleteResult = Database.deleteItem({
              deleteItemInput = {
                databaseName = Constants.IndexDBName;
                tableName = tableName;
                id = res.ids[0];
              };
              alfangoDB = alfangoDB;
            });
            switch (deleteResult) {
              case (#ok(_)) { return true };
              case (#err(_)) { return false };
            };
            return false;
          };
        };
        case (#err(_)) {};
      };
      return false;
    };

    // 1. Delete existing records for the old principal
    let deletedUserData = await findAndDelete(Constants.UserDataTable, principal);

    if (not deletedUserData) {
      return "User record not found to update.";
    };

    // 2. Create new records with the new principal and data
    let newPrincipal = Principal.fromText(values.principal_id);
    let newCanisterPrincipal = Principal.fromText(values.canister_id);

    let userDataValues : [(Text, Database.AttributeDataValue)] = [
      ("principal_id", #principal(newPrincipal)),
      ("canister_id", #principal(newCanisterPrincipal)),
      ("username", #text(values.username)),
    ];
    let userCanisterValues : [(Text, Database.AttributeDataValue)] = [
      ("principal_id", #principal(newPrincipal)),
      ("canister_id", #principal(newCanisterPrincipal)),
    ];

    ignore await Database.createItem({
      createItemInput = {
        databaseName = Constants.IndexDBName;
        tableName = Constants.UserDataTable;
        attributeDataValues = userDataValues;
      };
      alfangoDB = alfangoDB;
    });

    // 3. Upgrade the child canister
    ignore do ? {
      let childActor : UserCanisterActor.UserCanister = actor (values.canister_id);
      let upgradedChild = await (system UserCanisterActor.UserCanister)(#upgrade childActor)();
      let _ = upgradedChild.generateSchema();
    };

    return "User record updated";
  };

  /**
   * Retrieves the subaccount details for a given user from the database.
   */
  public func verifyPayment({
    userPrincipal : Principal;
    alfangoDB : Database.AlfangoDB;
    canistergeekLogger : Canistergeek.Logger;
  }) : async ?ArgumentTypes.SubaccountMapPayload {
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
          canistergeekLogger.logMessage("User sub account object --> " # debug_show (payload));
          return ?payload;
        };
      };
      case (#err(e)) {
        canistergeekLogger.logMessage("Error in verifyPayment scan: " # debug_show (e));
      };
    };
    return null;
  };

  /**
   * Performs an ICRC-1 transfer and records the transaction in the database.
   */
  public func transferAmount({
    userSubAccountObject : ArgumentTypes.SubaccountMapPayload;
    userPrincipal : Principal;
    canisterPrincipal : Principal;
    canistergeekLogger : Canistergeek.Logger;
    alfangoDB : Database.AlfangoDB;
  }) : async Nat {
    let created_at_time = Nat64.fromNat(Int.abs(Time.now()));
    var block_index = 0;

    let icrc1TransferObject = {
      to = { owner = canisterPrincipal; subaccount = null };
      fee = null;
      memo = null;
      from_subaccount = ?LedgerService.getSubAccountIdBlob(userSubAccountObject.subaccount_index, Principal.toText(canisterPrincipal));
      created_at_time = ?created_at_time;
      amount = Constants.VerifyIcpAmount;
    };
    canistergeekLogger.logMessage("Icrc1 transfer object --->" # debug_show (icrc1TransferObject));

    let ledgerCanisterActor : Ledger.Self = actor (Constants.IcpLedgerCanister);
    let transferResponse = await ledgerCanisterActor.icrc1_transfer(icrc1TransferObject);
    canistergeekLogger.logMessage("Transfer response --->" # debug_show (transferResponse));

    switch (transferResponse) {
      case (#Ok(blockIndex)) {
        block_index := blockIndex;
        let source_account_id_hex = LedgerService.getLedgerAccountFromSubaccountHex(Principal.toText(canisterPrincipal), ?userSubAccountObject.subaccount_id_hex);
        let destination_account_id_hex = LedgerService.getLedgerAccountFromSubaccountBlob(Principal.toText(canisterPrincipal), ?Account.defaultSubaccount());
        let fee = await ledgerCanisterActor.icrc1_fee();

        var attributeDataValues : [(Text, Database.AttributeDataValue)] = [
          ("principal_id", #principal(userPrincipal)),
          ("subaccount_index", #nat(userSubAccountObject.subaccount_index)),
          ("source_account_id_hex", #text(source_account_id_hex)),
          ("destination_account_id_hex", #text(destination_account_id_hex)),
          ("block_index", #nat(blockIndex)),
          ("amount", #nat(Constants.VerifyIcpAmount)),
          ("fee", #nat(fee)),
          ("narration", #text("Transferred " # Nat.toText(Constants.VerifyIcpAmount) # " ICP " # "from " # source_account_id_hex # " to " # destination_account_id_hex)),
          ("created_at_time", #nat64(created_at_time)),
        ];

        canistergeekLogger.logMessage("Create Transaction object --->" # debug_show (attributeDataValues));

        let createRes = await Database.createItem({
          createItemInput = {
            databaseName = Constants.IndexDBName;
            tableName = Constants.TransactionTable;
            attributeDataValues = attributeDataValues;
          };
          alfangoDB = alfangoDB;
        });
        canistergeekLogger.logMessage("Create Transaction response --->" # debug_show (createRes));
      };
      case (#Err(transferError)) {
        canistergeekLogger.logMessage("Icrc1 Transfer Error --->" # debug_show (transferError));
        throw Error.reject("Transfer Error: " # debug_show (transferError));
      };
    };
    return block_index;
  };
};
