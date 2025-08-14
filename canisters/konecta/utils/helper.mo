import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
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
import Prelude "mo:base/Prelude";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import DateTime "mo:datetime/DateTime";
import IanaTimeZone "mo:datetime/IanaTimeZone";
import LocalDateTime "mo:datetime/LocalDateTime";
import HashMap "mo:base/HashMap";
import EN "../../konecta/library/Timezone/iana/locales/EN";
import TimeZoneFinder "../../konecta/library/Timezone/iana/TimeZoneFinder";

module {
  type AttributeDataType = Database.AttributeDataType;
  type AttributeDataValue = Database.AttributeDataValue;

  private func getAttributeDataValue({
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

  private func arrayTupleToString(arr : [(Text, Text)]) : Text {
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

  public func textToNat(txt : Text) : Nat {
    if (txt.size() > 0) {
      let chars = txt.chars();

      var num : Nat = 0;
      for (v in chars) {
        let charToNum = Nat32.toNat(Char.toNat32(v) -48);
        assert (charToNum >= 0 and charToNum <= 9);
        num := num * 10 + charToNum;
      };

      num;
    } else {
      0;
    };
  };

  public func textToFloat(t : Text) : Result.Result<Float, Error> {

    var i : Float = 1;
    var f : Float = 0;
    var isDecimal : Bool = false;

    for (c in t.chars()) {
      if (Char.isDigit(c)) {
        let charToNat : Nat64 = Nat64.fromNat(Nat32.toNat(Char.toNat32(c) -48));
        let natToFloat : Float = Float.fromInt64(Int64.fromNat64(charToNat));
        if (isDecimal) {
          let n : Float = natToFloat / Float.pow(10, i);
          f := f + n;
        } else {
          f := f * 10 + natToFloat;
        };
        i := i + 1;
      } else {
        if (Char.equal(c, '.') or Char.equal(c, ',')) {
          f := f / Float.pow(10, i); // Force decimal
          f := f * Float.pow(10, i); // Correction
          isDecimal := true;
          i := 1;
        } else {
          return #err(Error.reject("NaN"));
        };
      };
    };

    return #ok(f);
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

  public func getTupleValue(array : [(Text, Database.AttributeDataValue)], searchKey : Text) : ?Database.AttributeDataValue {
    let tuple = Array.find<(Text, Database.AttributeDataValue)>(
      array,
      func(tuple) : Bool {
        return tuple.0 == searchKey;
      },
    );

    switch (tuple) {
      case (?result) {
        let (_, attributeDataValue) = result;
        return ?attributeDataValue;
      };

      case null {
        return null;
      };
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

  public func initializeBlobField(payload : ?Blob, initialValue : Blob) : Blob {
    switch (payload) {
      case (?fieldValue) fieldValue;
      case null initialValue;
    };
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

  public func getTupleArrayFromAttributeDataValueArray(attributeDataValue : ?Database.AttributeDataValue) : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)] {
    switch (attributeDataValue) {
      case (null) {
        return [];
      };
      case (?attrValue) {
        switch (attrValue) {
          case (#map(array)) {
            let valuesToBeAppended = Buffer.Buffer<(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)>(0);
            for ((key, value) in array.vals()) {
              valuesToBeAppended.add((key, value));
            };
            return Buffer.toArray(valuesToBeAppended);
          };
          case (_) {
            return [];
          };
        };
      };
    };
  };

  public func getNextDateInNanoseconds() : Nat {
    let nextDayComponents = DateTime.now().add(#days(1)).toComponents();
    let components = {
      year = nextDayComponents.year;
      month = nextDayComponents.month;
      day = nextDayComponents.day;
      hour = 0;
      minute = 0;
      nanosecond = 0;
    };
    let date = DateTime.fromComponents(components);

    return Int.abs(date.toTime());

  };

  public func getDateFromNanoseconds(date : Nat, format : Text) : Text {
    DateTime.toTextAdvanced(
      DateTime.fromTime(date),
      #custom({
        format;
        locale = null;
      }),
    );
  };

  public func getLocalDateFromNanoseconds(date : Nat, timezone : Text, format : Text) : Text {
    let datetime = DateTime.fromTime(date);
    let locale = EN.locale;
    let region = TimeZoneFinder.find(timezone);

    var formattedDate = "";

    switch (region) {
      case (?region) {
        let timeZone = #dynamic(IanaTimeZone.IanaTimeZone(region));

        let localDateTime = LocalDateTime.fromDateTime(datetime, timeZone);

        formattedDate := LocalDateTime.toTextFormatted(localDateTime, #custom({ format; locale = ?locale }));

      };
      case null formattedDate := getDateFromNanoseconds(date, format);

    };

    return formattedDate;
  };

  public func getCurrentCanisterPrincipal(canisterId : Text) : Principal {
    return Principal.fromActor(actor (canisterId));
  };
};
