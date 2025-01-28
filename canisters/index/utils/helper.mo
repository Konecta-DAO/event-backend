import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Bool "mo:base/Bool";
import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Int16 "mo:base/Int16";
import Int32 "mo:base/Int32";
import Int64 "mo:base/Int64";
import Int8 "mo:base/Int8";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Prelude "mo:base/Prelude";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

module {
  type AttributeDataType = Database.AttributeDataType;
  type AttributeDataValue = Database.AttributeDataValue;

  public func getAttributeDataValue({
    attributeDataValue : AttributeDataValue;
  }) : Text {

    switch (attributeDataValue) {
      case (#int(intValue)) { Int.toText(intValue) };
      case (#int8(int8Value)) { Int8.toText(int8Value) };
      case (#int16(int16Value)) { Int16.toText(int16Value) };
      case (#int32(int32Value)) { Int32.toText(int32Value) };
      case (#int64(int64Value)) { Int64.toText(int64Value) };
      case (#nat(natValue)) { Nat.toText(natValue) };
      case (#nat8(nat8Value)) { Nat8.toText(nat8Value) };
      case (#nat16(nat16Value)) { Nat16.toText(nat16Value) };
      case (#nat32(nat32Value)) { Nat32.toText(nat32Value) };
      case (#nat64(nat64Value)) { Nat64.toText(nat64Value) };
      case (#float(floatValue)) { Float.toText(floatValue) };
      case (#text(textValue)) { textValue };
      case (#char(charValue)) { Char.toText(charValue) };
      case (#bool(boolValue)) { Bool.toText(boolValue) };
      case (#principal(principalValue)) { Principal.toText(principalValue) };
      case (#blob(blobValue)) {
        switch (Text.decodeUtf8(blobValue)) {
          case null "";
          case (?blobText) { blobText };
        };
      };
      case (#list(listValue)) {
        let buffer = Buffer.Buffer<Text>(0);
        for (value in listValue.vals()) {
          switch (value) {
            case (#text(textValue)) { buffer.add(textValue) };
            case (#int(intValue)) { buffer.add(Int.toText(intValue)) };
            case (#int8(int8Value)) { buffer.add(Int8.toText(int8Value)) };
            case (#int16(int16Value)) { buffer.add(Int16.toText(int16Value)) };
            case (#int32(int32Value)) { buffer.add(Int32.toText(int32Value)) };
            case (#int64(int64Value)) { buffer.add(Int64.toText(int64Value)) };
            case (#nat(natValue)) { buffer.add(Nat.toText(natValue)) };
            case (#nat8(nat8Value)) { buffer.add(Nat8.toText(nat8Value)) };
            case (#nat16(nat16Value)) { buffer.add(Nat16.toText(nat16Value)) };
            case (#nat32(nat32Value)) { buffer.add(Nat32.toText(nat32Value)) };
            case (#nat64(nat64Value)) { buffer.add(Nat64.toText(nat64Value)) };
            case (#float(floatValue)) { buffer.add(Float.toText(floatValue)) };
            case (#char(charValue)) { buffer.add(Char.toText(charValue)) };
          };
        };
        return textArrayToString(Buffer.toArray(buffer));
      };
      case (#map(mapValue)) {
        let buffer = Buffer.Buffer<(Text, Text)>(0);
        for ((key, value) in mapValue.vals()) {
          switch (value) {
            case (#text(textValue)) { buffer.add((key, textValue)) };
            case (#int(intValue)) { buffer.add((key, Int.toText(intValue))) };
            case (#int8(int8Value)) {
              buffer.add((key, Int8.toText(int8Value)));
            };
            case (#int16(int16Value)) {
              buffer.add((key, Int16.toText(int16Value)));
            };
            case (#int32(int32Value)) {
              buffer.add((key, Int32.toText(int32Value)));
            };
            case (#int64(int64Value)) {
              buffer.add((key, Int64.toText(int64Value)));
            };
            case (#nat(natValue)) { buffer.add((key, Nat.toText(natValue))) };
            case (#nat8(nat8Value)) {
              buffer.add((key, Nat8.toText(nat8Value)));
            };
            case (#nat16(nat16Value)) {
              buffer.add((key, Nat16.toText(nat16Value)));
            };
            case (#nat32(nat32Value)) {
              buffer.add((key, Nat32.toText(nat32Value)));
            };
            case (#nat64(nat64Value)) {
              buffer.add((key, Nat64.toText(nat64Value)));
            };
            case (#float(floatValue)) {
              buffer.add((key, Float.toText(floatValue)));
            };
            case (#char(charValue)) {
              buffer.add((key, Char.toText(charValue)));
            };
            case (#list(listValue)) {
              let buffer = Buffer.Buffer<Text>(0);
              for (value in listValue.vals()) {
                switch (value) {
                  case (#text(textValue)) { buffer.add(textValue) };
                  case (#int(intValue)) { buffer.add(Int.toText(intValue)) };
                  case (#int8(int8Value)) { buffer.add(Int8.toText(int8Value)) };
                  case (#int16(int16Value)) {
                    buffer.add(Int16.toText(int16Value));
                  };
                  case (#int32(int32Value)) {
                    buffer.add(Int32.toText(int32Value));
                  };
                  case (#int64(int64Value)) {
                    buffer.add(Int64.toText(int64Value));
                  };
                  case (#nat(natValue)) { buffer.add(Nat.toText(natValue)) };
                  case (#nat8(nat8Value)) { buffer.add(Nat8.toText(nat8Value)) };
                  case (#nat16(nat16Value)) {
                    buffer.add(Nat16.toText(nat16Value));
                  };
                  case (#nat32(nat32Value)) {
                    buffer.add(Nat32.toText(nat32Value));
                  };
                  case (#nat64(nat64Value)) {
                    buffer.add(Nat64.toText(nat64Value));
                  };
                  case (#float(floatValue)) {
                    buffer.add(Float.toText(floatValue));
                  };
                  case (#char(charValue)) { buffer.add(Char.toText(charValue)) };
                };
              };
              return textArrayToString(Buffer.toArray(buffer));
            };
          };
        };
        return arrayTupleToString(Buffer.toArray(buffer));
      };
      case (#default) "";
    };

  };

  public func textArrayToString(arr : [Text]) : Text {
    var res : Text = "";

    for (i in arr.keys()) {
      let val = arr[i];

      if (i > 0) {
        res := res # "," # val;
      } else {
        res := val;
      };

    };
    return res;
  };

  public func arrayTupleToString(arr : [(Text, Text)]) : Text {
    var res : Text = "";

    for (i in arr.keys()) {
      let val = arr[i];

      let (keyPart, valuePart) = val;
      if (i > 0) {
        res := res # "," # "(" # keyPart # "," # valuePart # ")";
      } else {
        res := "(" # keyPart # "," # valuePart # ")";
      };

    };
    return res;
  };

  public func getTupleValueAsText(array : [(Text, Database.AttributeDataValue)], searchKey : Text) : Text {
    let tuple = Array.find<(Text, Database.AttributeDataValue)>(
      array,
      func(tuple) : Bool {
        return tuple.0 == searchKey;
      },
    );

    switch (tuple) {
      case null "";

      case (?result) {
        do {
          let (_, attributeDataValue) = result;
          let value = getAttributeDataValue({ attributeDataValue });
          return value;
        };
      };
    };
  };
};
