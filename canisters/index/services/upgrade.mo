import Text "mo:base/Text";
import Error "mo:base/Error";
import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Canistergeek "mo:canistergeek/canistergeek";

import UserCanisterActor "../../user/main";
import ReadService "../services/read";
import ArgumentTypes "../types/argumentTypes";

module {
  /**
   * Upgrades all registered user canisters to the latest wasm version.
   * It fetches the list of users from the database via the ReadService.
   * @param alfangoDB The instance of the AlfangoDB database.
   * @param _canistergeekLogger A logger for recording events.
   * @returns A Text message indicating how many canisters were upgraded.
   */
  public func upgradeUserCanisters(
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Text {
    // 1. Get the list of all users from the database.
    let userList = ReadService.getListOfUsers(alfangoDB);
    let userCount = userList.size();
    if (userCount == 0) {
      return "No user canisters to upgrade.";
    };

    let futures = Buffer.Buffer<async UserCanisterActor.UserCanister>(userCount);

    // 2. FAN-OUT: Start all upgrade calls.
    for (userData in userList.vals()) {
      let childActor : UserCanisterActor.UserCanister = actor (Principal.toText(userData.canister_id));
      futures.add((system UserCanisterActor.UserCanister)(#upgrade childActor)());
    };

    // 3. FAN-IN: Await results and handle errors.
    var successCount : Nat = 0;
    var errorMessages = Buffer.Buffer<Text>(0);

    for (i in userList.keys()) {
      try {
        let upgradedChild = await futures.get(i);
        let _schemaResponse = await upgradedChild.generateSchema();
        successCount += 1;
      } catch (e) {
        let canisterIdText = Principal.toText(userList[i].canister_id);
        let errorMessage = "Failed to upgrade canister " # canisterIdText # ": " # Error.message(e);
        canistergeekLogger.logMessage(errorMessage);
        errorMessages.add(errorMessage);
      };
    };

    // 4. Return a summary.
    let summary = "Upgrade summary: "
    # Nat.toText(successCount) # " canisters upgraded successfully. "
    # Nat.toText(errorMessages.size()) # " failed.";

    if (errorMessages.size() > 0) {
      return summary # " Errors: [" # Text.join("; ", errorMessages.vals()) # "]";
    } else {
      return summary;
    };
  };

  /**
   * Reinstalls all registered user canisters.
   * This is a destructive operation that will wipe the stable memory of the child canisters.
   * It fetches the list of users from the database via the ReadService.
   * @param alfangoDB The instance of the AlfangoDB database.
   * @returns A Text message indicating how many canisters were reinstalled.
   */
  public func reinstallUserCanisters(alfangoDB : Database.AlfangoDB) : async Text {
    // 1. Get the list of all users from the database.
    let userList = ReadService.getListOfUsers(alfangoDB);
    let userCount = userList.size();
    if (userCount == 0) {
      return "No user canisters to reinstall.";
    };

    let futures = Buffer.Buffer<async UserCanisterActor.UserCanister>(userCount);

    // 2. FAN-OUT: Start all reinstall calls.
    for (userData in userList.vals()) {
      let childActor : UserCanisterActor.UserCanister = actor (Principal.toText(userData.canister_id));
      futures.add((system UserCanisterActor.UserCanister)(#reinstall childActor)());
    };

    // 3. FAN-IN: Await results and handle errors.
    var successCount : Nat = 0;
    var errorMessages = Buffer.Buffer<Text>(0);

    for (i in userList.keys()) {
      try {
        let reinstalledChild = await futures.get(i);
        let _schemaResponse = await reinstalledChild.generateSchema();
        successCount += 1;
      } catch (e) {
        let canisterIdText = Principal.toText(userList[i].canister_id);
        errorMessages.add("Failed to reinstall " # canisterIdText # ": " # Error.message(e));
      };
    };

    // 4. Return a summary.
    let summary = "Reinstall summary: "
    # Nat.toText(successCount) # " canisters reinstalled successfully. "
    # Nat.toText(errorMessages.size()) # " failed.";

    if (errorMessages.size() > 0) {
      return summary # " Errors: [" # Text.join("; ", errorMessages.vals()) # "]";
    } else {
      return summary;
    };
  };
};
