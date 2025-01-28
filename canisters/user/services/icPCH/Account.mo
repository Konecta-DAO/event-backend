import Array     "mo:base/Array";
import Blob      "mo:base/Blob";
import Nat8      "mo:base/Nat8";
import Nat32     "mo:base/Nat32";
import Principal "mo:base/Principal";
import Buffer    "mo:base/Buffer";
import Text      "mo:base/Text";
import CRC32     "./CRC32";
import SHA224    "./SHA224";
import NNSLedger "./NNSLedger";
import Types     "./Types";

module {
    // 32-byte array.
    public type AccountIdentifier = NNSLedger.AccountIdentifier;
    // 32-byte array.
    public type Subaccount = NNSLedger.Subaccount;

    public func beBytes(n: Nat32) : [Nat8] {
        func byte(n: Nat32) : Nat8 {
          Nat8.fromNat(Nat32.toNat(n & 0xff))
        };
        [byte(n >> 24), byte(n >> 16), byte(n >> 8), byte(n)]
    };

    public func defaultSubaccount() : Subaccount {
        Blob.fromArrayMut(Array.init(32, 0 : Nat8))
    };


    public func getAccountIdentifierFromAccountIndex(principal : Principal, subaccountIndex : Types.SubaccountIndex) : AccountIdentifier {
        accountIdentifier(principal, getSubAccountIdentifierFromAccountIndex(principal,subaccountIndex));
    };

    public func getSubaccountParticulars(ownerPrincipal : Principal, userPrincipal : Principal, subaccountIndex : Types.SubaccountIndex) : {
        subaccountId : AccountIdentifier;
        accountId : AccountIdentifier;
    } {
        let subaccountId = getSubAccountIdentifierFromAccountIndex(userPrincipal, subaccountIndex);
        let accountId = accountIdentifier(ownerPrincipal, subaccountId);
        return {
            subaccountId = subaccountId;
            accountId = accountId;
        };
    };

    public func accountIdentifier(principal : Principal, subaccount: Subaccount) : AccountIdentifier {
        let hash = SHA224.Digest();
        hash.write([0x0A]);
        hash.write(Blob.toArray(Text.encodeUtf8("account-id")));
        hash.write(Blob.toArray(Principal.toBlob(principal)));
        hash.write(Blob.toArray(subaccount));

        let hashSum = hash.sum();
        let crc32Bytes = beBytes(CRC32.ofArray(hashSum));
        let hashSumBuffer = Buffer.fromArray<Nat8>(hashSum);
        let crc32BytesBuffer = Buffer.fromArray<Nat8>(crc32Bytes);
        crc32BytesBuffer.append(hashSumBuffer);
        Blob.fromArray(Buffer.toArray<Nat8>(crc32BytesBuffer))
    };

    public func getSubAccountIdentifierFromAccountIndex(principal : Principal, subaccountIndex : Types.SubaccountIndex) : Blob {
        let idHash = SHA224.Digest();
        idHash.write([0x0D]);                                           // Length of domain separator
        idHash.write(Blob.toArray(Text.encodeUtf8("subaccount-id")));   // Domain separator
        let idBytes = beBytes(subaccountIndex);                         // Counter as Nonce
        idHash.write(idBytes);
        idHash.write(Blob.toArray(Principal.toBlob(principal)));        // Principal of caller

        let hashSum = idHash.sum();
        let crc32Bytes = beBytes(CRC32.ofArray(hashSum));
        let hashSumBuffer = Buffer.fromArray<Nat8>(hashSum);
        let crc32BytesBuffer = Buffer.fromArray<Nat8>(crc32Bytes);
        crc32BytesBuffer.append(hashSumBuffer);
        Blob.fromArray(Buffer.toArray<Nat8>(crc32BytesBuffer))
    };

    public func validateAccountIdentifier(accountIdentifier : AccountIdentifier) : Bool {
        if (accountIdentifier.size() != 32) {
          return false;
        };
        let accIdArray = Blob.toArray(accountIdentifier);
        let accIdPart    = Array.tabulate(28, func(i: Nat): Nat8 { accIdArray[i + 4] });
        let checksumPart = Array.tabulate(4,  func(i: Nat): Nat8 { accIdArray[i] });
        let crc32 = CRC32.ofArray(accIdPart);
        Array.equal(beBytes(crc32), checksumPart, Nat8.equal)
    };

}