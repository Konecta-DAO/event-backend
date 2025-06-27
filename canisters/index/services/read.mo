import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Map "mo:map/Map";

import ArgumentTypes "../types/argumentTypes";

module {
  public func getUserCanisterId(userPrincipal : Principal, userCanisterMap : Map.Map<Principal, Principal>) : Text {
    var canisterId = "";

    ignore do ? {
      canisterId := Principal.toText(Map.get(userCanisterMap, Map.phash, userPrincipal)!);
    };

    return canisterId;
  };

  public func userExistsOrNot(userPrincipal : Principal, userCanisterMap : Map.Map<Principal, Principal>) : Bool {
    return Map.has(userCanisterMap, Map.phash, userPrincipal);
  };

  public func usernameExistsOrNot(username : Text, userDataMap : Map.Map<Principal, ArgumentTypes.UserMapPayload>) : ?ArgumentTypes.UserMapPayload {

    let userDataArray = Iter.toArray(Map.vals(userDataMap));

    let userData = Array.find<ArgumentTypes.UserMapPayload>(
      userDataArray,
      func(x) : Bool {
        return x.username == username;
      },
    );

    switch (userData) {
      case (null) {
        return null;
      };
      case (user) {
        return user;
      };
    };

  };

  public func isUsernamePresent(username : Text, userDataMap : Map.Map<Principal, ArgumentTypes.UserMapPayload>) : Bool {

    var exists = false;
    let userDataArray = Iter.toArray(Map.vals(userDataMap));

    let userData = Array.find<ArgumentTypes.UserMapPayload>(
      userDataArray,
      func(x) : Bool {
        return x.username == username;
      },
    );

    switch (userData) {
      case (null) {
        exists := false;
      };
      case (_user) {
        exists := true;
      };
    };

    return exists;
  };

  public func getListOfUsers(userDataMap : Map.Map<Principal, ArgumentTypes.UserMapPayload>) : [ArgumentTypes.UserMapPayload] {
    let usersBuffer = Buffer.Buffer<ArgumentTypes.UserMapPayload>(0);

    for ((key, value) in Map.toArray(userDataMap).vals()) {
      usersBuffer.add({
        canister_id = value.canister_id;
        principal_id = value.principal_id;
        username = value.username;
      });
    };

    return Buffer.toArray(usersBuffer);
  };
};
