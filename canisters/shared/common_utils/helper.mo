import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Bool "mo:base/Bool";
import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Error "mo:base/Error";
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
import Result "mo:base/Result";
import Text "mo:base/Text";
import Prelude "mo:base/Prelude";

module {
  type AttributeDataType = Database.AttributeDataType;
  type AttributeDataValue = Database.AttributeDataValue;

  /**
   * Converts any AlfangoDB AttributeDataValue to a Text representation.
   * Handles all primitive types, lists, and maps.
   */
  public func getAttributeDataValue(attributeDataValue : AttributeDataValue) : Text {
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
          // This part could be recursive, but for now it handles known primitives
          switch (value) {
            case (#text(v)) { buffer.add(v) };
            case (#int(v)) { buffer.add(Int.toText(v)) };
            case (#nat(v)) { buffer.add(Nat.toText(v)) };
            // Add other primitive types as needed
            case _ {};
          };
        };
        return textArrayToString(Buffer.toArray(buffer));
      };
      case (#map(mapValue)) {
        // Note: This provides a basic string representation of a map.
        // It's not designed to be parsed back.
        return "Map(" # Nat.toText(mapValue.size()) # " items)";
      };
      case (#default) "";
    };
  };

  /**
   * Joins an array of Text into a single comma-separated string.
   */
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

  /**
   * Converts a Text string of digits into a Nat.
   */
  public func textToNat(txt : Text) : Nat {
    if (txt.size() == 0) return 0;
    let chars = txt.chars();
    var num : Nat = 0;
    for (v in chars) {
      if (Char.isDigit(v)) {
        let charToNum = Nat32.toNat(Char.toNat32(v) - 48);
        num := num * 10 + charToNum;
      } else {
        // Or handle error appropriately
        return 0;
      };
    };
    return num;
  };

  /**
   * Converts a Text string into a Float. Handles decimal points.
   */
  public func textToFloat(t : Text) : Result.Result<Float, Error.Error> {
    var i : Float = 1.0;
    var f : Float = 0.0;
    var isDecimal : Bool = false;

    for (c in t.chars()) {
      if (Char.isDigit(c)) {
        let charToNat : Nat64 = Nat64.fromNat(Nat32.toNat(Char.toNat32(c) - 48));
        let natToFloat : Float = Float.fromInt64(Int64.fromNat64(charToNat));
        if (isDecimal) {
          let n : Float = natToFloat / Float.pow(10.0, i);
          f := f + n;
          i := i + 1.0;
        } else {
          f := f * 10.0 + natToFloat;
        };
      } else if (c == '.' or c == ',') {
        if (isDecimal) {
          return #err(Error.reject("Invalid float format: multiple decimal points"));
        };
        isDecimal := true;
      } else {
        return #err(Error.reject("NaN: Invalid character in float string"));
      };
    };
    return #ok(f);
  };

  /**
   * Finds a value in an array of (Text, AttributeDataValue) tuples by key
   * and returns it as Text.
   */
  public func getTupleValueAsText(array : [(Text, AttributeDataValue)], searchKey : Text) : Text {
    let tuple = Array.find<(Text, AttributeDataValue)>(
      array,
      func(tuple) : Bool { tuple.0 == searchKey },
    );

    switch (tuple) {
      case null "";
      case (?(_, attributeDataValue)) {
        getAttributeDataValue(attributeDataValue);
      };
    };
  };

  /**
   * Finds a value in an array of (Text, AttributeDataValue) tuples by key
   * and returns the raw AttributeDataValue.
   */
  public func getTupleValue(array : [(Text, AttributeDataValue)], searchKey : Text) : Database.AttributeDataValue {
    let tuple = Array.find<(Text, AttributeDataValue)>(
      array,
      func(tuple) : Bool {
        return tuple.0 == searchKey;
      },
    );

    switch (tuple) {
      case (?result) {
        do {
          let (_, attributeDataValue) = result;
          return attributeDataValue;
        };
      };
      case null Prelude.xxx();
    };
  };

  public func getFloatFromAttributeDataValueArray(attributeDataValue : Database.AttributeDataValue) : Float {
    var value : Float = 0.00;

    switch (attributeDataValue) {
      case (#float(floatValue)) { value := floatValue };
      case (_) { value := 0.00 };
    };
    return value;
  };

  public func getTextArrayFromAttributeDataValueArray(attributeDataValue : Database.AttributeDataValue) : [Text] {
    var value : [Text] = [];
    let initialBuffer = Buffer.fromArray<Text>([]);
    let valuesToBeAppended = Buffer.Buffer<Text>(0);

    switch (attributeDataValue) {
      case (#list(array)) {
        for (element in array.vals()) {
          switch (element) {
            case (#text(value)) { valuesToBeAppended.add(value) };
            case (_) { value := [] };
          };
        };
      };
      case (_) { value := [] };
    };

    initialBuffer.append(valuesToBeAppended);
    value := Buffer.toArray(initialBuffer);

    return value;
  };

  /**
   * Extracts a [Text] from a #list AttributeDataValue.
   */
  public func getTextArrayFromAttributeDataValue(attributeDataValue : AttributeDataValue) : [Text] {
    let buffer = Buffer.Buffer<Text>(0);
    switch (attributeDataValue) {
      case (#list(array)) {
        for (element in array.vals()) {
          switch (element) {
            case (#text(value)) { buffer.add(value) };
            case _ {}; // Ignore non-text values in the list
          };
        };
      };
      case _ {};
    };
    return Buffer.toArray(buffer);
  };

  /**
   * Extracts a Float from a #float AttributeDataValue.
   */
  public func getFloatFromAttributeDataValue(attributeDataValue : AttributeDataValue) : Float {
    switch (attributeDataValue) {
      case (#float(floatValue)) floatValue;
      case _ 0.0;
    };
  };

  /**
   * Extracts a metadata map from a #map AttributeDataValue.
   */
  public func getTupleArrayFromAttributeDataValue(attributeDataValue : AttributeDataValue) : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)] {
    let buffer = Buffer.Buffer<(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)>(0);
    switch (attributeDataValue) {
      case (#map(array)) {
        for ((key, value) in array.vals()) {
          buffer.add((key, value));
        };
      };
      case _ {};
    };
    return Buffer.toArray(buffer);
  };

  public func getTupleArrayFromAttributeDataValueArray(attributeDataValue : Database.AttributeDataValue) : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)] {
    var tupleArray : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)] = [];
    let initialBuffer = Buffer.fromArray<(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)>([]);
    let valuesToBeAppended = Buffer.Buffer<(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)>(0);

    switch (attributeDataValue) {
      case (#map(array)) {
        for ((key, value) in array.vals()) {
          valuesToBeAppended.add((key, value));
        };
      };

      case (_) { tupleArray := [] };
    };

    initialBuffer.append(valuesToBeAppended);
    tupleArray := Buffer.toArray(initialBuffer);

    return tupleArray;
  };

  /**
   * Converts an array of Text to an array of AlfangoDB #text values.
   */
  public func getStringAttributeDataValueArray(array : [Text]) : [Database.StringAttributeDataValue] {
    let buffer = Buffer.Buffer<Database.StringAttributeDataValue>(array.size());
    for (element in array.vals()) {
      buffer.add(#text(element));
    };
    return Buffer.toArray(buffer);
  };

  /**
   * Converts an array of Principal to an array of AlfangoDB #principal values.
   */
  public func getMiscAttributeDataValueArray(array : [Principal]) : [Database.MiscAttributeDataValue] {
    let buffer = Buffer.Buffer<Database.MiscAttributeDataValue>(array.size());
    for (element in array.vals()) {
      buffer.add(#principal(element));
    };
    return Buffer.toArray(buffer);
  };

  // --- Initializer Functions for handling optional payload fields ---

  public func initializeTextArrayField(payload : ?[Text], initialValue : [Text]) : [Text] {
    switch (payload) {
      case (?fieldValue) fieldValue;
      case null initialValue;
    };
  };

  public func initializeTextField(payload : ?Text, initialValue : Text) : Text {
    switch (payload) {
      case (?fieldValue) fieldValue;
      case null initialValue;
    };
  };

  public func initializeNatField(payload : ?Nat, initialValue : Nat) : Nat {
    switch (payload) {
      case (?fieldValue) fieldValue;
      case null initialValue;
    };
  };

  public func initializePrincipalField(payload : ?Principal, initialValue : Principal) : Principal {
    switch (payload) {
      case (?fieldValue) fieldValue;
      case null initialValue;
    };
  };

  public func initializePrincipalArrayField(payload : ?[Principal], initialValue : [Principal]) : [Principal] {
    switch (payload) {
      case (?fieldValue) fieldValue;
      case null initialValue;
    };
  };

  public func initializeFloatField(payload : ?Float, initialValue : Float) : Float {
    switch (payload) {
      case (?fieldValue) fieldValue;
      case null initialValue;
    };
  };
};
