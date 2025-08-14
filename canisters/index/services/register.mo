import Database "mo:alfangodb/AlfangoDB";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import LedgerService "../services/shared/ledger";
import UserCanisterActor "../../user/main";
import Constants "../utils/constants";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import UserWasm "./userWasm";

module {
  // --- Local Management Canister Type Definitions ---
  public type CanisterSettings = {
    controllers : ?[Principal];
    compute_allocation : ?Nat;
    memory_allocation : ?Nat;
    freezing_threshold : ?Nat;
  };

  public type InstallCodeArgument = {
    mode : { #install; #reinstall; #upgrade };
    canister_id : Principal;
    wasm_module : Blob;
    arg : Blob;
  };

  public type ManagementCanister = actor {
    create_canister : ({ settings : ?CanisterSettings }) -> async ({
      canister_id : Principal;
    });
    install_code : (InstallCodeArgument) -> async ();
  };

  /**
   * @desc Private helper function to create and provision a new child canister.
   * @param userPrincipal The principal of the user for whom the canister is being created.
   * @param indexCanisterPrincipal The principal of this index canister, to be set as a co-controller.
   * @returns A Result containing the new canister's principal on success, or a detailed error Text on failure.
   */
  private func registerUserCanister(userPrincipal : Principal, indexCanisterPrincipal : Principal) : async Result.Result<Principal, Text> {
    Cycles.add<system>(Constants.DefaultCycles);

    let canister_settings = {
      controllers = ?[userPrincipal, indexCanisterPrincipal];
      compute_allocation = null;
      memory_allocation = null;
      freezing_threshold = null;
    };

    let create_args : { settings : ?CanisterSettings } = {
      settings = ?canister_settings;
    };

    try {
      let managementCanister : ManagementCanister = actor ("aaaaa-aa");

      // 1. Create the new, empty canister shell
      let result = await managementCanister.create_canister(create_args);
      let newCanisterId = result.canister_id;

      // 2. Install the Wasm code into the new canister
      await managementCanister.install_code({
        mode = #install;
        canister_id = newCanisterId;
        wasm_module = UserWasm.wasm; // Use the imported wasm blob
        arg = Blob.fromArray([]); // Empty initialization arguments
      });

      // 3. Call the initialization function on the now-installed canister
      let childActor : UserCanisterActor.UserCanister = actor (Principal.toText(newCanisterId));
      let _schemaResponse = await childActor.generateSchema();

      // On success, return the new principal wrapped in #ok
      return #ok(newCanisterId);

    } catch (e) {
      // On failure, capture the specific error, convert it to Text, and return it in #err
      let errorMessage = "Error during user canister registration: " # debug_show (Error.message(e));
      return #err(errorMessage);
    };
  };

  /**
   * @desc Signs up a new user by creating a user canister and saving their data to the database.
   * @param username The desired username for the new user. Must be unique.
   * @param userPrincipal The principal of the user signing up. Must be unique.
   * @param alfangoDB The instance of the AlfangoDB database.
   * @returns A Result containing the new user's canister ID on success, or a detailed error Text on failure.
   */
  public func signUp(
    username : Text,
    userPrincipal : Principal,
    alfangoDB : Database.AlfangoDB,
    currentSubAccountIndex : Nat,
    canisterPrincipalId : Text,
  ) : async Result.Result<Text, Text> {
    // 1. Check if the username already exists.
    let usernameFilter : SearchTypes.QueryFilter = #expression({
      attributeNames = "username";
      filterExpressionCondition = #EQ(#text(username));
    });

    let existingUsernameResponse = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = Constants.IndexDBName;
        tableName = Constants.UserDataTable;
        filter = usernameFilter;
        limit = 1;
        cursor = null;
      };
      alfangoDB = alfangoDB;
    });

    switch (existingUsernameResponse) {
      case (#ok(page)) {
        if (page.items.size() > 0) {
          return #err("This username is already taken. Please choose another one.");
        };
      };
      case (#err(e)) {
        return #err("Database error checking for existing username: " # debug_show (e));
      };
    };

    // 2. Check if the principal already exists.
    let principalFilter : SearchTypes.QueryFilter = #expression({
      attributeNames = "principal_id";
      filterExpressionCondition = #EQ(#principal(userPrincipal));
    });

    let existingPrincipalResponse = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = Constants.IndexDBName;
        tableName = Constants.UserDataTable;
        filter = principalFilter;
        limit = 1;
        cursor = null;
      };
      alfangoDB = alfangoDB;
    });

    switch (existingPrincipalResponse) {
      case (#ok(page)) {
        if (page.items.size() > 0) {
          return #err("This user principal already has an account.");
        };
      };
      case (#err(e)) {
        return #err("Database error checking for existing principal: " # debug_show (e));
      };
    };

    // Proceed with canister registration.
    let userCanisterResult = await registerUserCanister(userPrincipal, Principal.fromText(canisterPrincipalId));

    switch (userCanisterResult) {
      case (#err(errorMessage)) {
        return #err(errorMessage);
      };
      case (#ok(canisterPrincipal)) {
        let canisterId = Principal.toText(canisterPrincipal);

        // 3. Create a record in the UserDataTable.
        let userAttrValues : [(Text, Database.AttributeDataValue)] = [
          ("principal_id", #principal(userPrincipal)),
          ("canister_id", #principal(canisterPrincipal)),
          ("username", #text(username)),
        ];

        let userCreateRes = await Database.createItem({
          createItemInput = {
            databaseName = Constants.IndexDBName;
            tableName = Constants.UserDataTable;
            attributeDataValues = userAttrValues;
          };
          alfangoDB = alfangoDB;
        });

        // Handle failure to create the main user record.
        switch (userCreateRes) {
          case (#err(dbError)) {
            // It's important to stop here if the main record fails.
            return #err("Failed to save user record: " # debug_show (dbError));
          };
          case (#ok(_)) {
            // Continue to the subaccount logic.
          };
        };

        // 4. Conditionally create the subaccount record. First, check if one already exists.
        let subaccountFilter : SearchTypes.QueryFilter = #expression({
          attributeNames = "principal_id";
          filterExpressionCondition = #EQ(#principal(userPrincipal));
        });

        let existingSubaccountResponse = Database.paginatedScan({
          paginatedScanInput = {
            databaseName = Constants.IndexDBName;
            tableName = Constants.UserSubaccountTable;
            filter = subaccountFilter;
            limit = 1;
            cursor = null;
          };
          alfangoDB = alfangoDB;
        });

        var subaccountExists = false;
        switch (existingSubaccountResponse) {
          case (#ok(page)) {
            if (page.items.size() > 0) {
              subaccountExists := true;
            };
          };
          case (#err(_)) {
            // Log the error but proceed assuming it doesn't exist.
          };
        };

        // Only create the subaccount record if it wasn't pre-created by getUserAccountInfo.
        if (not subaccountExists) {
          let subaccountIdHex = LedgerService.getSubAccountIdHex(currentSubAccountIndex, canisterPrincipalId);
          let subaccountLedgerIdentifier = LedgerService.getLedgerAccountFromSubaccountHex(Principal.toText(userPrincipal), ?subaccountIdHex);

          let subaccountAttrValues : [(Text, Database.AttributeDataValue)] = [
            ("principal_id", #principal(userPrincipal)),
            ("subaccount_id_hex", #text(subaccountIdHex)),
            ("subaccount_index", #nat(currentSubAccountIndex)),
            ("subaccount_ledger_identifier", #text(subaccountLedgerIdentifier)),
          ];

          let subaccountCreateRes = await Database.createItem({
            createItemInput = {
              databaseName = Constants.IndexDBName;
              tableName = Constants.UserSubaccountTable;
              attributeDataValues = subaccountAttrValues;
            };
            alfangoDB = alfangoDB;
          });

          switch (subaccountCreateRes) {
            case (#err(dbError)) {
              // This is a partial failure state. The user record exists but the subaccount record failed.
              // For a robust system, you would implement rollback logic here to delete the UserDataTable entry.
              return #err("Failed to save user subaccount record: " # debug_show (dbError));
            };
            case (#ok(_)) {
              // Successfully created.
            };
          };
        };

        // 5. If we reach here, the sign-up is successful.
        return #ok(canisterId);
      };
    };
  };
};
