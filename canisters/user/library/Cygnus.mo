import Option "mo:base/Option";
import Prelude "mo:base/Prelude";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

module {

  /*
    Add your principal-ids to be whitelisted in order to invoke Cgynus functions
     */
  let whitelistedPrincipalIds : [Text] = ["xnp5v-5aaaa-aaaap-qccda-cai"];

  public type CanisterStatus = {
    cycles : Nat;
    idle_cycles_burned_per_day : Nat;
    memory_size : Nat;
    module_hash : ?[Nat8];
    settings : {
      freezing_threshold : Nat;
      controllers : [Principal];
      memory_allocation : Nat;
      compute_allocation : Nat;

    };
    status : { #running; #stopped; #stopping };
  };

  public type definite_canister_settings = {
    freezing_threshold : Nat;
    controllers : [Principal];
    memory_allocation : Nat;
    compute_allocation : Nat;
  };

  public type ManagementCanister = actor {
    canister_status : shared { canister_id : Principal } -> async {
      status : { #stopped; #stopping; #running };
      memory_size : Nat;
      cycles : Nat;
      settings : definite_canister_settings;
      idle_cycles_burned_per_day : Nat;
      module_hash : ?[Nat8];
    };
  };

  public type CygnusCanister = actor {
    acceptWithdrwalCyclesFromOtherCanisters : () -> async ();
  };

  public class Cygnus() {
    public let CYGNUS_CANISTER_ID = "dowzh-nyaaa-aaaai-qnowq-cai";
    public let ManagementCanister = actor ("aaaaa-aa") : ManagementCanister;
    public let CygnusCanister = actor (CYGNUS_CANISTER_ID) : CygnusCanister;

    public func validateUser(callerPrincipalId : Principal, auxiliaryPrincipalIdOpt : ?Principal) : () {

      if (Principal.isAnonymous(callerPrincipalId)) {
        Prelude.unreachable();
      };

      var isAuxiliaryPrincipalWhitelistedPrincipalId = false;
      var isCallerCygnusPrincipalId = false;

      // check if caller principal is one of the whitelisted principal
      for (whitelistedPrincipalIdText in whitelistedPrincipalIds.vals()) {
        let whitelistedPrincipalId = Principal.fromText(whitelistedPrincipalIdText);
        if (callerPrincipalId == whitelistedPrincipalId) {
          return;
        };
        ignore do ? {
          if (auxiliaryPrincipalIdOpt! == whitelistedPrincipalId) {
            isAuxiliaryPrincipalWhitelistedPrincipalId := true;
          };
        };
      };

      // check if caller principal is a Cygnus principal
      if (callerPrincipalId == Principal.fromText(CYGNUS_CANISTER_ID)) {
        isCallerCygnusPrincipalId := true;
      };

      // either auxillary-principal-id is null or a whitelisted principal
      if (isCallerCygnusPrincipalId and (Option.isNull(auxiliaryPrincipalIdOpt) or isAuxiliaryPrincipalWhitelistedPrincipalId)) {
        return;
      };

      Prelude.unreachable();
    };

    public func getStatus(principalId : Principal) : async CanisterStatus {
      await ManagementCanister.canister_status({
        canister_id = principalId;
      });
    };
  };
};
