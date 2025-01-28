import { generateULIDAsync } "mo:alfangodb/AlfangoDB/utils";
import Principal "mo:base/Principal";
import Map "mo:map/Map";

import UserReadService "../../services/user/read";
import ArgumentTypes "../../types/argumentTypes";
import { initializeTextArrayField; initializeTextField } "../../utils/helper";
module {

  public func upsertUser(
    userPrincipal : Principal,
    userDataMap : Map.Map<Principal, ArgumentTypes.UserPayload>,
    payload : ArgumentTypes.UserRequestPayload,
    canisterId : Principal,
  ) : async Text {
    let isUsernamePresent = UserReadService.isUsernamePresent(payload.username, userDataMap);

    let userExists = Map.has(userDataMap, Map.phash, userPrincipal);
    var ulid = "";
    var profilePicUrl = "";
    var coverPhotoUrl = "";
    var bio = "";
    var categories : [Text] = [];

    if (userExists) {
      ignore do ? {
        let user = Map.get(userDataMap, Map.phash, userPrincipal)!;
        ulid := initializeTextField(payload.id, user.id);
        profilePicUrl := initializeTextField(payload.profilepic, user.profilepic);
        coverPhotoUrl := initializeTextField(payload.coverphoto, user.coverphoto);
        bio := initializeTextField(payload.bio, user.bio);
        categories := initializeTextArrayField(payload.categories, user.categories);
      };
    } else {
      if (not isUsernamePresent) {
        ulid := await generateULIDAsync();
        bio := initializeTextField(payload.bio, "");
        categories := initializeTextArrayField(payload.categories, []);
        profilePicUrl := initializeTextField(payload.profilepic, "");
        coverPhotoUrl := initializeTextField(payload.coverphoto, "");
      };

    };

    if (userExists or (not userExists and not isUsernamePresent)) {
      let userObject = {
        id = ulid;
        principal_id = userPrincipal;
        canister_id = canisterId;
        firstname = payload.firstname;
        lastname = payload.lastname;
        username = payload.username;
        email = payload.email;
        bio = bio;
        categories = categories;
        profilepic = profilePicUrl;
        coverphoto = coverPhotoUrl;
        country = payload.country;
        timezone = payload.timezone;
      };

      Map.set(userDataMap, Map.phash, userPrincipal, userObject);
    };

    if (userExists) {
      return "User updated successfully";
    } else {
      if (not isUsernamePresent) {
        return "User created successfully";
      } else {
        return "Username already exists. Please try with a different username";
      };
    };

  };

  public func updateUserRecord(principal : Principal, values : ArgumentTypes.UpdateUserRecordPayload, userDataMap : Map.Map<Principal, ArgumentTypes.UserPayload>) : async Text {
    if (Map.has(userDataMap, Map.phash, principal)) {

      ignore do ? {

        let userData = Map.remove(userDataMap, Map.phash, principal)!;
        let userObject = {
          id = initializeTextField(values.id, userData.id);
          principal_id = Principal.fromText(values.principal_id);
          canister_id = Principal.fromText(values.canister_id);
          firstname = values.firstname;
          lastname = values.lastname;
          username = values.username;
          email = values.email;
          bio = initializeTextField(values.bio, userData.bio);
          categories = initializeTextArrayField(values.categories, userData.categories);
          profilepic = initializeTextField(values.profilepic, userData.profilepic);
          coverphoto = initializeTextField(values.coverphoto, userData.coverphoto);
          country = values.country;
          timezone = values.timezone;
        };
        Map.set(userDataMap, Map.phash, Principal.fromText(values.principal_id), userObject);
      };

      return "User record updated";
    } else {
      return "User record not found";
    };
  };

};
