import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import UserCanisterActor "../../user/main";
import CygnusCanitser "../client/cygnus";
import IndexReadService "../services/read";
import ArgumentTypes "../types/argumentTypes";

module {
  public func upgradeUserCanisters(userCanisterMap : Map.Map<Principal, Principal>, userDataMap : Map.Map<Principal, ArgumentTypes.UserMapPayload>, canistergeekLogger : Canistergeek.Logger) : async Text {
    let canisterIdArray = Iter.toArray(Map.entries(userCanisterMap));
    let upgradedCanisterBuffer = Buffer.Buffer<Principal>(0);

    for ((userPrincipal, canister) in canisterIdArray.vals()) {
      ignore do ? {
        let _childActor : UserCanisterActor.UserCanister = actor (Principal.toText(canister));

        var childActor = _childActor;
        childActor := await (system UserCanisterActor.UserCanister)(#upgrade childActor)();

        let schemaResponse = childActor.generateSchema();
        upgradedCanisterBuffer.add(canister);

        // let userObject = await childActor.getUserByPrincipalId(Principal.toText(userPrincipal));
        // canistergeekLogger.logMessage("User Object --->" # debug_show (userObject));

        // switch (userObject) {
        //   case (?userObject) {
        //     let cygnusCanitserActor = actor ("dowzh-nyaaa-aaaai-qnowq-cai") : CygnusCanitser.Self;

        //     let registerCanister = await cygnusCanitserActor.registerProjectCanister({
        //       projectId = "upr_0PG5GJMG12G6RGWJHPT3DW1B3X";
        //       canisterIdToBeRegistered = Principal.toText(canister);
        //       canisterName = userObject.username;
        //       implementationType = #CygnusLibrary;
        //       topUpAmountInTrillon = ?3.0;
        //       thresholdAmountInTrillon = ?1.0;
        //     });
        //   };
        //   case (null) {
        //     null!;
        //   };
        // };

      };
    };

    let upgradedCanisterArray = Buffer.toArray(upgradedCanisterBuffer);
    return "Upgraded " # Nat.toText(Array.size(upgradedCanisterArray)) # " canisters";
  };

  public func reinstallUserCanisters(userCanisterMap : Map.Map<Principal, Principal>) : async Text {
    let canisterIdArray = Iter.toArray(Map.entries(userCanisterMap));
    let upgradedCanisterBuffer = Buffer.Buffer<Principal>(0);

    for ((userPrincipal, canister) in canisterIdArray.vals()) {
      ignore do ? {
        let _childActor : UserCanisterActor.UserCanister = actor (Principal.toText(canister));
        var childActor = _childActor;
        childActor := await (system UserCanisterActor.UserCanister)(#reinstall childActor)();
        let schemaResponse = childActor.generateSchema();
        upgradedCanisterBuffer.add(canister);
      };
    };

    let upgradedCanisterArray = Buffer.toArray(upgradedCanisterBuffer);
    return "Reinstalled " # Nat.toText(Array.size(upgradedCanisterArray)) # " canisters";
  };
};
