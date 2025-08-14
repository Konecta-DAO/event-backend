import Database "mo:alfangodb/AlfangoDB";

import Error "mo:base/Error";

import Principal "mo:base/Principal";

import Text "mo:base/Text";

import Canistergeek "mo:canistergeek/canistergeek";
import Result "mo:base/Result";
import Map "mo:map/Map";

import LedgerCandid "candid/ledger";

import CommonService "services/common";

import ReadService "services/read";

import RegisterService "services/register";

import SchemaService "services/schema";

import LedgerService "services/shared/ledger";

import UpdateService "services/update";

import UpgradeService "services/upgrade";

import ArgumentTypes "types/argumentTypes";

import IndexConstants "utils/constants";

shared ({ caller = initializer }) actor class IndexCanister() = this {

  stable var alfangoDB : Database.AlfangoDB = {

    databases = Map.new<Text, Database.Database>();

    STABLE_MEMORY_LIMIT = 3_221_225_472; // 3 GiB

    var totalStableBytes = 0;

  };

  stable var subAccountIndex = 1;

  private let canistergeekMonitor = Canistergeek.Monitor();

  private let canistergeekLogger = Canistergeek.Logger();

  stable var _canistergeekMonitorUD : ?Canistergeek.UpgradeData = null;

  stable var _canistergeekLoggerUD : ?Canistergeek.LoggerUpgradeData = null;

  /**

   * @desc Initializes the database and its tables.

   * Should be called after the first deployment or an upgrade.

   */

  public func generateSchema() : async Text {

    SchemaService.generateIndexSchema(alfangoDB, canistergeekLogger);

    return "Schema generation process initiated.";

  };

  /**

   * @desc Returns the list of whitelisted origins that are allowed to access this IndexCanister.

   * @returns An array of Text containing the whitelisted origins.

   */

  public func get_trusted_origins() : async [Text] {

    return IndexConstants.whiteListedCanisters;

  };

  public shared query func icrc28_trusted_origins() : async {

    trusted_origins : [Text];

  } {

    let trusted_origins = IndexConstants.whiteListedCanisters;

    return { trusted_origins };

  };

  /**

   * @desc Retrieves the user canister ID associated with the caller.

   * @param msg The message containing the caller's information.

   * @returns The user canister ID as Text.

   */

  public query (msg) func getUserCanister() : async Text {

    ReadService.getUserCanisterId(msg.caller, alfangoDB);

  };

  private func getCurrentCanisterPrincipal() : Principal {

    return Principal.fromActor(this);

  };

  public shared (msg) func getUserAccountInfo() : async ArgumentTypes.UserAccountInfoPayload {

    canistergeekMonitor.collectMetrics();

    let response = await ReadService.getUserAccountInfo(msg.caller, alfangoDB, subAccountIndex, Principal.toText(getCurrentCanisterPrincipal()), canistergeekLogger);

    // If a new subaccount was created, increment the index for the next user.

    if (Text.size(response.canister_id) == 0) {

      subAccountIndex := subAccountIndex + 1;

    };

    return response;

  };

  public query func getListofTransactions() : async [ArgumentTypes.TransactionResponsePayload] {

    ReadService.getListofTransactions(alfangoDB);

  };

  public shared (msg) func verifyPayment() : async Bool {

    canistergeekMonitor.collectMetrics();

    let userSubAccountObject = await UpdateService.verifyPayment({

      userPrincipal = msg.caller;

      alfangoDB;

      canistergeekLogger;

    });

    switch (userSubAccountObject) {

      case null { return false };

      case (?userSubAccount) {

        let subaccountIdHex = userSubAccount.subaccount_id_hex;

        if (Text.size(subaccountIdHex) > 0) {

          canistergeekLogger.logMessage("Verifying payment for subaccount: " # subaccountIdHex);

          let ledgerCanisterActor : LedgerCandid.Self = actor (IndexConstants.IcpLedgerCanister);

          let subaccount = LedgerService.convertHexToBlob(subaccountIdHex);

          try {

            let balance = await ledgerCanisterActor.icrc1_balance_of({

              owner = getCurrentCanisterPrincipal();

              subaccount = ?subaccount;

            });

            if (balance >= IndexConstants.VerifyIcpAmount) {

              let _block_index = await UpdateService.transferAmount({

                userSubAccountObject = userSubAccount;

                userPrincipal = msg.caller;

                canisterPrincipal = getCurrentCanisterPrincipal();

                canistergeekLogger;

                alfangoDB;

              });

              canistergeekLogger.logMessage("Block index for icrc1 transfer --> " # debug_show (_block_index));

              return true;

            } else {

              return false;

            };

          } catch (e) {

            canistergeekLogger.logMessage("Error during payment verification: " # debug_show (Error.message(e)));

            throw e;

          };

        } else {

          return false;

        };

      };

    };

  };

  public query func getUserCanisterByUserPrincipal(userPrincipal : Text) : async Text {

    var principal = Principal.fromText(IndexConstants.AnonymousPrincipal);

    try {

      principal := Principal.fromText(userPrincipal);

    } catch (_error) {

      principal := Principal.fromText(IndexConstants.AnonymousPrincipal);

    };

    ReadService.getUserCanisterId(principal, alfangoDB);

  };

  public shared (msg) func signUp(username : Text) : async Result.Result<Text, Text> {
    let canisterPrincipalId = Principal.toText(getCurrentCanisterPrincipal());

    let result = await RegisterService.signUp(username, msg.caller, alfangoDB, subAccountIndex, canisterPrincipalId);

    // Only increment the index on a successful registration
    switch (result) {
      case (#ok(_)) {
        subAccountIndex += 1;
      };
      case (#err(_)) {};
    };

    return result;
  };

  public query (msg) func userExistsOrNot() : async Bool {

    ReadService.userExistsOrNot(msg.caller, alfangoDB);

  };

  public query func usernameExistsOrNot(username : Text) : async ?ArgumentTypes.UserMapPayload {

    ReadService.usernameExistsOrNot(username, alfangoDB);

  };

  public func upgradeUserCanisters() : async Text {

    await UpgradeService.upgradeUserCanisters(alfangoDB, canistergeekLogger);

  };

  public func reinstallUserCanisters() : async Text {

    await UpgradeService.reinstallUserCanisters(alfangoDB);

  };

  public query func getListOfUsers() : async [ArgumentTypes.UserMapPayload] {

    return ReadService.getListOfUsers(alfangoDB);

  };

  public query func getListOfCanister() : async [ArgumentTypes.CanisterMapPayload] {

    return ReadService.getListOfCanisters(alfangoDB);

  };

  public query func getListOfUserSubaccounts() : async [ArgumentTypes.SubaccountMapPayload] {

    return ReadService.getListOfUserSubaccounts(alfangoDB);

  };

  public query func findUser(principal : Text) : async ?ArgumentTypes.UserMapPayload {
    return ReadService.findUser(principal, alfangoDB);
  };

  /**
   * @desc Composite query to verify if a user is fully and correctly registered.
   * Checks for a user record in the index canister and for data consistency with the user's own canister.
   * @param userPrincipal The principal of the user to check.
   * @returns A Result indicating success (#ok with a confirmation message) or failure (#err with an error description).
   */
  public composite query func isUserRegistered(userPrincipal : Principal) : async ArgumentTypes.RegistrationCheckResult {
    // 1. Check for user and subaccount records in the index canister.
    let indexRecord = ReadService.findUser(Principal.toText(userPrincipal), alfangoDB);
    let subaccountRecord = ReadService.getSubaccountForUser(userPrincipal, alfangoDB);

    // Prepare subaccount details for the response payload.
    var subIdHex : ?Text = null;
    var subLedgerId : ?Text = null;

    // Correctly and safely unwrap the optional subaccountRecord
    switch (subaccountRecord) {
      case (?record) {
        subIdHex := ?record.subaccount_id_hex;
        subLedgerId := ?record.subaccount_ledger_identifier;
      };
      case (null) {
        // subIdHex and subLedgerId remain null
      };
    };

    switch (indexRecord) {
      case (null) {
        return #err({
          message = "User not found in the index canister.";
          canister_id = null;
          subaccount_id_hex = subIdHex;
          subaccount_ledger_identifier = subLedgerId;
        });
      };

      case (?userMap) {
        // User found in the index. Now, check their personal canister.
        let indexedUsername = userMap.username;
        let userCanisterId = userMap.canister_id;

        // 2. Call the getUser function on the user's canister.
        try {
          let userCanisterActor : CommonService.UserCanisterType = actor (Principal.toText(userCanisterId));
          let userCanisterProfile = await userCanisterActor.getUser();

          switch (userCanisterProfile) {
            case (null) {
              return #err({
                message = "User canister returned no profile data. The user has not completed their profile setup.";
                canister_id = ?userCanisterId;
                subaccount_id_hex = subIdHex;
                subaccount_ledger_identifier = subLedgerId;
              });
            };
            case (?userProfile) {
              // 3. Compare the username from the index with the one from the user's canister.
              if (userProfile.username == indexedUsername) {
                return #ok({
                  message = "User is correctly registered and data is consistent.";
                  canister_id = userCanisterId;
                  subaccount_id_hex = subIdHex;
                  subaccount_ledger_identifier = subLedgerId;
                });
              } else {
                let errorMessage = "Data inconsistency: Index username is '"
                # indexedUsername
                # "', but user canister username is '"
                # userProfile.username
                # "'.";
                return #err({
                  message = errorMessage;
                  canister_id = ?userCanisterId;
                  subaccount_id_hex = subIdHex;
                  subaccount_ledger_identifier = subLedgerId;
                });
              };
            };
          };
        } catch (e) {
          let errorMessage = "Failed to communicate with the user canister ("
          # Principal.toText(userCanisterId)
          # "): " # debug_show (Error.message(e));
          return #err({
            message = errorMessage;
            canister_id = ?userCanisterId;
            subaccount_id_hex = subIdHex;
            subaccount_ledger_identifier = subLedgerId;
          });
        };
      };
    };
  };

  public composite query func getUserByUsername(username : Text) : async ?ArgumentTypes.UserPayload {

    let userMapResponse = ReadService.usernameExistsOrNot(username, alfangoDB);

    switch (userMapResponse) {

      case (?userMapResponse) {

        let userCanisterActor = actor (Principal.toText(userMapResponse.canister_id)) : CommonService.UserCanisterType;

        return await userCanisterActor.getUser();

      };

      case null null;

    };

  };

  public shared func updateUserRecord(principal : Text, values : ArgumentTypes.UpdateUserRequestPayload) : async Text {

    // Note: This service function requires a complex DB implementation (delete and create)

    // to handle principal ID changes, which is beyond this scope.

    return await UpdateService.updateUserRecord(Principal.fromText(principal), values, alfangoDB);

  };

  public query func getUserCanistersByPrincipal(userPrincipalArr : [Text]) : async [ArgumentTypes.CanisterMapPayload] {

    ReadService.getUserCanistersByPrincipal(userPrincipalArr, alfangoDB);

  };

  system func preupgrade() {

    _canistergeekMonitorUD := ?canistergeekMonitor.preupgrade();

    _canistergeekLoggerUD := ?canistergeekLogger.preupgrade();

  };

  system func postupgrade() {

    canistergeekMonitor.postupgrade(_canistergeekMonitorUD);

    _canistergeekMonitorUD := null;

    canistergeekLogger.postupgrade(_canistergeekLoggerUD);

    _canistergeekLoggerUD := null;

    SchemaService.generateIndexSchema(alfangoDB, canistergeekLogger);

    canistergeekLogger.setMaxMessagesCount(3000);

  };

  public query func getCanistergeekInformation(request : Canistergeek.GetInformationRequest) : async Canistergeek.GetInformationResponse {

    Canistergeek.getInformation(?canistergeekMonitor, ?canistergeekLogger, request);

  };

  public shared func updateCanistergeekInformation(request : Canistergeek.UpdateInformationRequest) : async () {

    canistergeekMonitor.updateInformation(request);

  };

  /* Validate and reject anonymous calls*/

  // system func inspect({ caller : Principal }) : Bool {

  //   not (Principal.isAnonymous(caller));

  // };

};
