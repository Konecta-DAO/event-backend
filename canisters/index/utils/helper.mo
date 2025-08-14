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
import Nat "mo:base/Nat";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";

module {
  type AttributeDataValue = Database.AttributeDataValue;

  /**
  * @desc Converts an AlfangoDB AttributeDataValue to a simple Text representation.
  * @param attributeDataValue - The value to convert.
  * @returns The text representation of the value.
  */
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

  /**
  * @desc Joins an array of Text into a single comma-separated string.
  */
  public func textArrayToString(arr : [Text]) : Text {
    Text.join(",", arr.vals());
  };

  /**
  * @desc Converts an array of (Text, Text) tuples into a string representation.
  */
  public func arrayTupleToString(arr : [(Text, Text)]) : Text {
    var res : Text = "";
    for (i in arr.keys()) {
      let (keyPart, valuePart) = arr[i];
      let part = "(" # keyPart # "," # valuePart # ")";
      if (i > 0) {
        res := res # "," # part;
      } else {
        res := part;
      };
    };
    return res;
  };

  /**
  * @desc Converts a numeric Text value to a Nat. Asserts that text is a valid number.
  */
  public func textToNat(txt : Text) : Nat {
    switch (Nat.fromText(txt)) {
      case (?n) n;
      case (null) {
        return 0;
      };
    };
  };

  /**
  * @desc Converts a numeric Text value to a Nat64.
  */
  public func textToNat64(txt : Text) : Nat64 {
    if (txt.size() == 0) { return 0 };

    switch (Nat.fromText(txt)) {
      case (?n) {
        let v : Nat64 = Nat64.fromNat(n);
        return v;
      };
      case (null) {
        assert false;
        return 0;
      };
    };
  };

  /**
  * @desc Finds an attribute in an array by key and returns its value as Text.
  * @returns The value as Text, or "" if not found.
  */
  public func getTupleValueAsText(array : [(Text, AttributeDataValue)], searchKey : Text) : Text {
    let tuple = Array.find<(Text, AttributeDataValue)>(
      array,
      func(tuple) : Bool {
        return tuple.0 == searchKey;
      },
    );

    switch (tuple) {
      case null "";
      case (?result) {
        let (_, attributeDataValue) = result;
        return getAttributeDataValue({ attributeDataValue });
      };
    };
  };

  /**
  * @desc Converts an item's attribute array into a HashMap for efficient O(1) lookups.
  * @param attrs The array of (Text, AttributeDataValue) tuples.
  * @returns A HashMap mapping attribute names to their values.
  */
  public func attributeArrayToHashMap(attrs : [(Text, AttributeDataValue)]) : HashMap.HashMap<Text, AttributeDataValue> {
    let map = HashMap.HashMap<Text, AttributeDataValue>(attrs.size(), Text.equal, Text.hash);
    for ((key, value) in attrs.vals()) {
      map.put(key, value);
    };
    return map;
  };

  /**
  * @desc Gets an attribute as Text from a pre-converted HashMap.
  * @param map The HashMap of attributes.
  * @param key The name of the attribute to find.
  * @returns The attribute value as Text, or "" if not found.
  */
  public func getAttributeFromMapAsText(map : HashMap.HashMap<Text, AttributeDataValue>, key : Text) : Text {
    switch (map.get(key)) {
      case (null) { return "" };
      case (?attrValue) {
        return getAttributeDataValue({ attributeDataValue = attrValue });
      };
    };
  };
};
