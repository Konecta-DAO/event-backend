import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Map "mo:map/Map";
import SharedConstants "../../shared/constants";
import UserCanisterActor "../../user/main";
import CygnusCanister "../client/cygnus";
import ArgumentTypes "../types/argumentTypes";
import { getUserCanisterId; isUsernamePresent; userExistsOrNot } "./read";

module {
  public func signUp(
    username : Text,
    userPrincipal : Principal,
    userCanisterMap : Map.Map<Principal, Principal>,
    userDataMap : Map.Map<Principal, ArgumentTypes.UserMapPayload>,
  ) : async Text {
    var response = "";

    let userExists = userExistsOrNot(userPrincipal, userCanisterMap);
    if (userExists) {
      let canisterId = getUserCanisterId(userPrincipal, userCanisterMap);
      response := canisterId;
    } else {
      if (isUsernamePresent(username, userDataMap)) {
        let userCanisterPrincipal = await registerUserCanister();

        ignore do ? {
          let canisterId = Principal.toText(userCanisterPrincipal!);
          let canisterPrincipal = userCanisterPrincipal!;
          Map.set(userCanisterMap, Map.phash, userPrincipal, canisterPrincipal);
          Map.set(
            userDataMap,
            Map.phash,
            userPrincipal,
            {
              principal_id = userPrincipal;
              canister_id = canisterPrincipal;
              username = username;
            },
          );
          response := canisterId;
        };

        let cygnusCanisterActor = actor ("dowzh-nyaaa-aaaai-qnowq-cai") : CygnusCanister.Self;
        let _registerCanister = await cygnusCanisterActor.registerProjectCanister({
          projectId = "upr_0PG5GJMG12G6RGWJHPT3DW1B3X";
          canisterIdToBeRegistered = response;
          canisterName = username;
          implementationType = #CygnusLibrary;
          topUpAmountInTrillon = ?3.0;
          thresholdAmountInTrillon = ?1.0;
        });
      } else {
        return "Username already exists. Please try with a different username";
      };
    };

    return response;
  };

  private func registerUserCanister() : async ?Principal {

    // 3T cycles required to create a child actor
    Cycles.add<system>(SharedConstants.DefaultCycles);
    let default_settings = { settings = null };
    let childActor = await (system UserCanisterActor.UserCanister)(#new default_settings)();
    let _schemaResponse = childActor.generateSchema();
    return ?Principal.fromActor(childActor);
  };
};
