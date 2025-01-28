/**
 * @desc This file contains the implementation of the IndexCanister actor class.
 * The IndexCanister is responsible for managing user canisters and providing various functions related to user management.
 */

import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import CommonService "services/common";
import ReadService "services/read";
import RegisterService "services/register";
import UpdateService "services/update";
import UpgradeService "services/upgrade";
import ArgumentTypes "types/argumentTypes";
import IndexConstants "utils/constants";
shared ({ caller = initializer }) actor class IndexCanister() = this {

  stable var userCanisterMap = Map.new<Principal, Principal>();
  stable var userDataMap = Map.new<Principal, ArgumentTypes.UserMapPayload>();

  private let canistergeekMonitor = Canistergeek.Monitor();
  private let canistergeekLogger = Canistergeek.Logger();
  stable var _canistergeekMonitorUD : ?Canistergeek.UpgradeData = null;
  stable var _canistergeekLoggerUD : ?Canistergeek.LoggerUpgradeData = null;

  /**
   * @desc Returns the list of whitelisted origins that are allowed to access this IndexCanister.
   * @returns An array of Text containing the whitelisted origins.
   */
  public func get_trusted_origins() : async [Text] {
    return IndexConstants.whiteListedCanisters;
  };

  /**
   * @desc Retrieves the user canister ID associated with the caller.
   * @param msg The message containing the caller's information.
   * @returns The user canister ID as Text.
   */
  public query (msg) func getUserCanister() : async Text {
    ReadService.getUserCanisterId(msg.caller, userCanisterMap);
  };

  public query func getUserCanisterByUserPrincipal(userPrincipal : Text) : async Text {
    var principal = Principal.fromText(IndexConstants.AnonymousPrincipal);
    try {
      principal := Principal.fromText(userPrincipal);
    } catch (error) {
      principal := Principal.fromText(IndexConstants.AnonymousPrincipal);
    };
    ReadService.getUserCanisterId(principal, userCanisterMap);
  };

  /**
   * @desc Signs up a new user with the given username.
   * @param username The username of the new user.
   * @param msg The message containing the caller's information.
   * @returns A Text indicating the success or failure of the signup process.
   */
  public shared (msg) func signUp(username : Text) : async Text {
    await RegisterService.signUp(username, msg.caller, userCanisterMap, userDataMap);
  };

  /**
   * @desc Checks if the caller's user canister exists or not.
   * @param msg The message containing the caller's information.
   * @returns A Bool indicating whether the user canister exists or not.
   */
  public query (msg) func userExistsOrNot() : async Bool {
    ReadService.userExistsOrNot(msg.caller, userCanisterMap);
  };

  /**
   * @desc Checks if the given username exists or not.
   * @param username The username to check.
   * @param msg The message containing the caller's information.
   * @returns A Bool indicating whether the username exists or not.
   */
  public query func usernameExistsOrNot(username : Text) : async ?ArgumentTypes.UserMapPayload {
    ReadService.usernameExistsOrNot(username, userDataMap);
  };

  /**
   * @desc Upgrades the user canisters associated with the IndexCanister.
   * @returns A Text indicating the success or failure of the upgrade process.
   */
  public func upgradeUserCanisters() : async Text {
    await UpgradeService.upgradeUserCanisters(userCanisterMap, userDataMap, canistergeekLogger);
  };

  public func reinstallUserCanisters() : async Text {
    await UpgradeService.reinstallUserCanisters(userCanisterMap);
  };

  public query func getListOfUsers() : async [ArgumentTypes.UserMapPayload] {
    return ReadService.getListOfUsers(userDataMap);
  };

  public query func findUser(principal : Text) : async ?ArgumentTypes.UserMapPayload {
    return ReadService.findUser(principal, userDataMap);
  };

  public composite query func getUserByUsername(username : Text) : async ?ArgumentTypes.UserPayload {
    let userMapResponse = ReadService.usernameExistsOrNot(username, userDataMap);

    switch (userMapResponse) {
      case (?userMapResponse) {
        let userCanisterActor = actor (Principal.toText(userMapResponse.canister_id)) : CommonService.UserCanisterType;
        return await userCanisterActor.getUserDetailsByUsername(username);
      };
      case null null;
    };

  };

  public shared func updateUserRecord(principal : Text, values : ArgumentTypes.UpdateUserRequestPayload) : async Text {
    return await UpdateService.updateUserRecord(Principal.fromText(principal), values, userDataMap, userCanisterMap);
  };

  public shared func bulkInsertUsers() : async Result.Result<Text, Text> {
    return await UpdateService.bulkInsertUsers(userDataMap);
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

    //Optional: override default number of log messages to your value
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
