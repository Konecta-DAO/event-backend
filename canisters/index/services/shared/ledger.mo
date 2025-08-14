import Blob "mo:base/Blob";
import Nat32 "mo:base/Nat32";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

import Account "../../services/icPCH/Account";
import DecodeW8Service "../../services/shared/decodeW8";
import EncodeW8Service "../../services/shared/encodeW8";

module {

  public func getSubAccountIdHex(subAccountIndex : Nat, canisterPrincipalId : Text) : Text {
    let subaccountIndexNat = subAccountIndex;
    let subaccountIndexNat32 = Nat32.fromNat(subaccountIndexNat);
    let subaccountId = Account.getSubAccountIdentifierFromAccountIndex(Principal.fromText(canisterPrincipalId), subaccountIndexNat32);
    let subAccountIdHex = EncodeW8Service.encode(Blob.toArray(subaccountId));
    return subAccountIdHex;
  };

  public func getSubAccountIdBlob(subAccountIndex : Nat, canisterPrincipalId : Text) : Blob {
    let subaccountIndexNat = subAccountIndex;
    let subaccountIndexNat32 = Nat32.fromNat(subaccountIndexNat);
    let subaccountId = Account.getSubAccountIdentifierFromAccountIndex(Principal.fromText(canisterPrincipalId), subaccountIndexNat32);
    return subaccountId;
  };

  public func getLedgerAccountFromSubaccountHex(pid : Text, subAccountHex : ?Text) : Text {
    let principal = Principal.fromText(pid);

    var subAccount : ?Blob = null;
    ignore do ? {
      if (Text.size(subAccountHex!) > 0) {
        let decodedSubAccount = DecodeW8Service.decode(subAccountHex!);
        switch (decodedSubAccount) {
          case (#ok(decodedSubAccount)) {
            subAccount := ?Blob.fromArray(decodedSubAccount);
          };
          case (#err(_error)) subAccount := null;
        };
      };
    };
    let account = Principal.toLedgerAccount(principal, subAccount);
    return EncodeW8Service.encode(Blob.toArray(account));

  };

  public func getLedgerAccountFromSubaccountBlob(pid : Text, subAccount : ?Blob) : Text {
    let principal = Principal.fromText(pid);

    let account = Principal.toLedgerAccount(principal, subAccount);
    return EncodeW8Service.encode(Blob.toArray(account));
  };

  public func convertHexToBlob(hex : Text) : Blob {
    var subAccount : Blob = Text.encodeUtf8("");

    let decodedSubAccount = DecodeW8Service.decode(hex);
    switch (decodedSubAccount) {
      case (#ok(decodedSubAccount)) {
        subAccount := Blob.fromArray(decodedSubAccount);
      };
      case (#err(_error)) subAccount := Text.encodeUtf8("");
    };
    return subAccount;
  };
};
