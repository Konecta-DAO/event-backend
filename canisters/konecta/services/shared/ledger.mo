import Blob "mo:base/Blob";
import Nat32 "mo:base/Nat32";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

import Account "../../services/icPCH/Account";
import DecodeW8Service "../../services/shared/decodeW8";
import EncodeW8Service "../../services/shared/encodeW8";

module {

  public func getSubAccountIdBlob(subAccountIndex : Nat, canisterPrincipalId : Text) : Blob {
    let subaccountIndexNat = subAccountIndex;
    let subaccountIndexNat32 = Nat32.fromNat(subaccountIndexNat);
    let subaccountId = Account.getSubAccountIdentifierFromAccountIndex(Principal.fromText(canisterPrincipalId), subaccountIndexNat32);
    return subaccountId;
  };

  public func getLedgerAccountFromSubaccountBlob(pid : Text, subAccount : ?Blob) : Text {
    let principal = Principal.fromText(pid);

    let account = Principal.toLedgerAccount(principal, subAccount);
    return EncodeW8Service.encode(Blob.toArray(account));
  };

};
