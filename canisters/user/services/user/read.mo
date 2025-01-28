import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";

import ArgumentTypes "../../types/argumentTypes";
import CommonService "../common";

module {
  public func getUserDataByPrincipalId(userPrincipal : Principal, userDataMap : Map.Map<Principal, ArgumentTypes.UserPayload>) : ?ArgumentTypes.UserPayload {
    return Map.get(userDataMap, Map.phash, userPrincipal);
  };

  public func getUserByUserId(userPrincipal : Text, userDataMap : Map.Map<Principal, ArgumentTypes.UserPayload>) : ?ArgumentTypes.UserPayload {
    return Map.get(userDataMap, Map.phash, Principal.fromText(userPrincipal));
  };

  public func getUserByUsername(username : Text, userDataMap : Map.Map<Principal, ArgumentTypes.UserPayload>) : ?ArgumentTypes.UserPayload {
    let userDataArray = Iter.toArray(Map.vals(userDataMap));

    let userData = Array.find<ArgumentTypes.UserPayload>(
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

  public func isUsernamePresent(username : Text, userDataMap : Map.Map<Principal, ArgumentTypes.UserPayload>) : Bool {

    var exists = false;
    let userDataArray = Iter.toArray(Map.vals(userDataMap));

    let userData = Array.find<ArgumentTypes.UserPayload>(
      userDataArray,
      func(x) : Bool {
        return x.username == username;
      },
    );

    switch (userData) {
      case (null) {
        exists := false;
      };
      case (user) {
        exists := true;
      };
    };

    return exists;
  };

  public func getUserForEventCanister(userPrincipal : Text, userDataMap : Map.Map<Principal, ArgumentTypes.UserPayload>) : ArgumentTypes.EventUserResponsePayload {
    var data : ArgumentTypes.EventUserResponsePayload = CommonService.initialUserObject;

    ignore do ? {
      let userResponse = Map.get(userDataMap, Map.phash, Principal.fromText(userPrincipal))!;

      switch (userResponse) {

        case (userData) {

          var userProfilePicUrl = "";

          if (Text.size(userData.profilepic) > 0) {
            userProfilePicUrl := "https://" # Principal.toText(userData.canister_id) # ".raw.icp0.io/d3?file_id=" # userData.profilepic;
          };

          var userCoverPicUrl = "";

          if (Text.size(userData.coverphoto) > 0) {
            userCoverPicUrl := "https://" # Principal.toText(userData.canister_id) # ".raw.icp0.io/d3?file_id=" # userData.coverphoto;
          };

          data := {
            id = userData.id;
            principal_id = Principal.toText(userData.principal_id);
            canister_id = Principal.toText(userData.canister_id);
            firstname = userData.firstname;
            lastname = userData.lastname;
            username = userData.username;
            email = userData.email;
            bio = userData.bio;
            categories = userData.categories;
            profilepic = userProfilePicUrl;
            coverphoto = userCoverPicUrl;
            country = userData.country;
            timezone = userData.timezone;
          };
        };
      };

    };

    return data;

  };

  public func getFile(fileId : Text, d3 : D3.D3) : D3.GetFileOutputType {
    CommonService.getFile(fileId, d3);
  };
};
