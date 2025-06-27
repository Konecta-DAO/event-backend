import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Map "mo:map/Map";

import UserCanisterActor "../../user/main";

module {
  public func upgradeUserCanisters(userCanisterMap : Map.Map<Principal, Principal>) : async Text {
    let canisterIdArray = Iter.toArray(Map.entries(userCanisterMap));
    let upgradedCanisterBuffer = Buffer.Buffer<Principal>(0);

    for ((userPrincipal, canister) in canisterIdArray.vals()) {
      ignore do ? {
        let _childActor : UserCanisterActor.UserCanister = actor (Principal.toText(canister));

        var childActor = _childActor;
        childActor := await (system UserCanisterActor.UserCanister)(#upgrade childActor)();

        let schemaResponse = childActor.generateSchema();
        upgradedCanisterBuffer.add(canister);
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
