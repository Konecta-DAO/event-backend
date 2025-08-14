import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
module {

    public func toTextPaddedSign(value : Int, length : Nat, includePositiveSign : Bool) : Text {
        let isNegative = value < 0;
        let natValue = Int.abs(value);
        let text = toTextPadded(natValue, length);
        if (isNegative) {
            "-" # text;
        } else {
            if (includePositiveSign) {
                "+" # text;
            } else {
                text;
            };
        };
    };

    public func toTextPadded(value : Nat, length : Nat) : Text {
        toTextPaddedSymb(value, length, "0");
    };

    public func toTextPaddedSymb(value : Nat, length : Nat, padChar : Text) : Text {
        var text = Nat.toText(value);
        if (text.size() < length) {
            // Pad with leading zeros
            for (a in Iter.range(0, length - text.size() - 1)) {
                text := padChar # text;
            };
        };
        text;
    };
};
