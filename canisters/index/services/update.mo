import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Map "mo:map/Map";

import UserCanisterActor "../../user/main";
import CommonService "../services/common";
import ArgumentTypes "../types/argumentTypes";

module {
  public func updateUserRecord(principal : Principal, values : ArgumentTypes.UpdateUserRequestPayload, userDataMap : Map.Map<Principal, ArgumentTypes.UserMapPayload>, userCanisterMap : Map.Map<Principal, Principal>) : async Text {
    if (Map.has(userDataMap, Map.phash, principal)) {
      Map.delete(userDataMap, Map.phash, principal);
      let userObject = {
        principal_id = Principal.fromText(values.principal_id);
        canister_id = Principal.fromText(values.canister_id);
        username = values.username;
      };
      Map.set(userDataMap, Map.phash, Principal.fromText(values.principal_id), userObject);

      Map.delete(userCanisterMap, Map.phash, principal);
      Map.set(userCanisterMap, Map.phash, Principal.fromText(values.principal_id), Principal.fromText(values.canister_id));

      ignore do ? {
        let _childActor : UserCanisterActor.UserCanister = actor (values.canister_id);
        var childActor = _childActor;

        childActor := await (system UserCanisterActor.UserCanister)(#upgrade childActor)();
        let schemaResponse = childActor.generateSchema();

      };
      return "User record updated";
    } else {
      return "User record not found";
    };
  };

  public func bulkInsertUsers(userDataMap : Map.Map<Principal, ArgumentTypes.UserMapPayload>) : async Result.Result<Text, Text> {

    let principalArray = [
      "mzoyo-3xbrz-q3zkp-mqy3a-nga2h-dmawl-7fp24-nizfu-4mj6n-5jtsu-2ae", // Nisarg
      "5av6q-ts6cg-7u7q5-3u5hs-cbqar-2kt4p-hqfoo-jiqei-fakum-hwr3e-nae", // Nisarg
      "wwejy-fbis7-dhyf4-xvlpe-kpwsi-5yjiw-rvzrv-djpcz-rcx6i-tssla-4ae", // Sagar
      "eqh7z-3lmfz-ct3au-a7a4w-kua3d-5zbfx-t3vm6-ny4ur-nxpoi-qc7tb-cqe", // Sagar
      "slwzu-ovd34-xwi2n-6el4t-zo7la-xef2l-rkq4k-ol6ij-4td6c-wwssg-bqe", // Sagar
      "uun3d-rgatz-tmyit-3ta3w-5pegc-ee4gt-fcokz-x3ryj-dcpv5-v3cvb-fqe", // Daivik
      "kdf4u-va2wh-ilo3a-p3otu-2s3tm-aspof-6ylaa-vwobw-6ybng-wrkfs-nae", // Daivik
      "2o2yp-qgdon-4jio3-56vi7-dhqox-zpibh-qna35-dirx7-vhfiw-clzoi-cqe", // Yash
      "7zhpg-lcjnw-7scdo-dl2o2-2amxb-hrf4x-ktrik-e7bso-ad7om-4spmx-tqe", // Yash
    ];

    try {
      let userDataArray = Iter.toArray(Map.entries(userDataMap));
      let userCanisterBuffer = Buffer.Buffer<Principal>(0);

      for ((userPrincipal, userData) in userDataArray.vals()) {

        let userNotExists = Array.indexOf<Text>(Principal.toText(userPrincipal), principalArray, Text.equal) == null;
        if (userNotExists) {

          let userCanisterActor = actor (Principal.toText(userData.canister_id)) : CommonService.UserCanisterType;
          let userObject = {
            firstname = userData.username;
            lastname = "";
            username = userData.username;
            email = userData.username # "@test.com";
            bio = "Timepass";
            categories = [
              "Entertainment",
              "Health",
            ];
            profilepic = "";
            coverphoto = "";
            country = "United States";
            timezone = "America/Aruba";
          };

          let _upsertUserResponse = await userCanisterActor.upsertUserPublic(Principal.toText(userPrincipal), userObject);
          userCanisterBuffer.add(userData.canister_id);
        };

      };
      let userCanisterArray = Buffer.toArray(userCanisterBuffer);
      #ok("Inserted " # Nat.toText(Array.size(userCanisterArray)) # " users data");
    } catch (e) {
      #err("Failed to insert user data for all or some users");
    };
  };
};
