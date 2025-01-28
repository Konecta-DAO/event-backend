import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Float "mo:base/Float";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Int64 "mo:base/Int64";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

import Account "./Account";
import CRC32 "./CRC32";
import SHA224 "./SHA224";
import Types "./Types";

module {

    private func charToHex(char : Nat) : Text {
        let hexCharMapping = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"];
        hexCharMapping[char];
    };

    public func blobToHex(blob : Blob) : Text {
        Text.join(
            "",
            Iter.map<Nat8, Text>(
                Iter.fromArray(Blob.toArray(blob)),
                func(x : Nat8) : Text {
                    let a = Nat8.toNat(x / 16);
                    let b = Nat8.toNat(x % 16);
                    charToHex(a) # charToHex(b);
                },
            ),
        );
    };

    public func nat64ToFloat(nat64 : Nat64) : Float {
        Float.fromInt64(Int64.fromNat64(nat64));
    };

    public func hexToNat8Array(t : Text) : [Nat8] {
        var map = HashMap.HashMap<Nat, Nat8>(1, Nat.equal, Hash.hash);
        // '0': 48 -> 0; '9': 57 -> 9
        for (num in Iter.range(48, 57)) {
            map.put(num, Nat8.fromNat(num -48));
        };
        // 'a': 97 -> 10; 'f': 102 -> 15
        for (lowcase in Iter.range(97, 102)) {
            map.put(lowcase, Nat8.fromNat(lowcase -97 +10));
        };
        // 'A': 65 -> 10; 'F': 70 -> 15
        for (uppercase in Iter.range(65, 70)) {
            map.put(uppercase, Nat8.fromNat(uppercase -65 +10));
        };
        let p = Iter.toArray(Iter.map(Text.toIter(t), func(x : Char) : Nat { Nat32.toNat(Char.toNat32(x)) }));
        var res : [var Nat8] = [var];
        for (i in Iter.range(4, 31)) {
            let a = Option.get<Nat8>(map.get(p[i * 2]), 0);
            let b = Option.get<Nat8>(map.get(p[i * 2 + 1]), 0);
            let c = 16 * a + b;
            res := Array.thaw(Array.append(Array.freeze(res), Array.make(c)));
        };
        return Array.freeze(res);
    };

    public func hexToBlob(hex : Text) : Blob {
        Blob.fromArray(hexToNat8Array(hex));
    };

    public func hexToNat8(hex : Text) : [Nat8] {
        hexToNat8Array(hex);
    };

};
