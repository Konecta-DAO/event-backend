/**
 * @desc This file contains the implementation of the IndexCanister actor class.
 * The IndexCanister is responsible for managing user canisters and providing various functions related to user management.
 */

import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Buffer "mo:base/Buffer";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import CommonService "services/common";
import ReadService "services/read";
import RegisterService "services/register";
import UpdateService "services/update";
import UpgradeService "services/upgrade";
import ArgumentTypes "types/argumentTypes";
import SharedConstants "../shared/constants";
import SharedTypes "../shared/types";
import SharedInterfaces "../shared/interfaces";

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
    return SharedConstants.whiteListedCanisters;
  };

  /**
   * @desc Retrieves the user canister ID associated with the caller.
   * @param msg The message containing the caller's information.
   * @returns The user canister ID as Text.
   */
  public query (msg) func getUserCanister() : async Text {
    if (Principal.isAnonymous(msg.caller)) {
      throw Error.reject("Anonymous callers are not allowed to perform this action.");
    };
    ReadService.getUserCanisterId(msg.caller, userCanisterMap);
  };

  public query func getUserCanisterByUserPrincipal(userPrincipal : Text) : async Text {
    var principal = Principal.fromText(SharedConstants.AnonymousPrincipal);
    try {
      principal := Principal.fromText(userPrincipal);
    } catch (_error) {
      principal := Principal.fromText(SharedConstants.AnonymousPrincipal);
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
    if (Principal.isAnonymous(msg.caller)) {
      throw Error.reject("Anonymous callers are not allowed to perform this action.");
    };
    await RegisterService.signUp(username, msg.caller, userCanisterMap, userDataMap);
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
    await UpgradeService.upgradeUserCanisters(userCanisterMap);
  };

  public func reinstallUserCanisters() : async Text {
    await UpgradeService.reinstallUserCanisters(userCanisterMap);
  };

  public composite query func getUsersDataByPrincipal(userIds : [Text]) : async [(Text, ?SharedTypes.UserResponsePayload)] {

    var resultsBuffer = Buffer.Buffer<(Text, ?SharedTypes.UserResponsePayload)>(userIds.size());

    for (userId in userIds.vals()) {
      let userCanisterId = await getUserCanisterByUserPrincipal(userId);
      if (userCanisterId != "") {
        let userCanisterActor = actor (userCanisterId) : SharedInterfaces.UserActor;
        let userData = await userCanisterActor.getUserForEventCanister(userId);
        resultsBuffer.add((userId, ?userData));
      } else {
        resultsBuffer.add((userId, null));
      };
    };

    return Buffer.toArray(resultsBuffer);
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

  public shared (msg) func updateUserRecord(principal : Text, values : ArgumentTypes.UpdateUserRequestPayload) : async Text {
    if (Principal.isAnonymous(msg.caller)) {
      throw Error.reject("Anonymous callers are not allowed to perform this action.");
    };
    return await UpdateService.updateUserRecord(Principal.fromText(principal), values, userDataMap, userCanisterMap);
  };

  public shared (msg) func bulkInsertUsers() : async Result.Result<Text, Text> {
    if (Principal.isAnonymous(msg.caller)) {
      throw Error.reject("Anonymous callers are not allowed to perform this action.");
    };
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
};
