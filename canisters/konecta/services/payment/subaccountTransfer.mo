import Database "mo:alfangodb/AlfangoDB";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import Blob "mo:base/Blob";

import Ledger "../../candid/ledger";
import Account "../../services/icPCH/Account";
import CommonService "../../services/shared/common";
import LedgerService "../../services/shared/ledger";
import SharedService "../../services/shared/shared";
import TransactionCreateService "../../services/transaction/create";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../utils/helper";

module {

  public func transferAmountFromUserToEventSubAccount(
    userIdOfRemitter : Principal,
    canisterPrincipal : Principal,
    payload : ArgumentTypes.TransferRequestPayload,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, ArgumentTypes.LedgerIcrc2TransferError> {

    let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;
    let konectaEventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(payload.eventId);
    canistergeekLogger.logMessage("Event response --->" # debug_show (konectaEventData));

    if (Text.size(konectaEventData.event_id) == 0) {
      return #err(#FetchEventDetailsError({ message = "Event not found" }));
    };

    var tokenObject : {
      token_type : Text;
      canister_id : Text;
    } = {
      token_type = "";
      canister_id = "";
    };

    switch (payload.priceToken) {
      case (#CKBTC) {
        tokenObject := {
          token_type = Constants.TokenType.CKBTC;
          canister_id = Constants.CkbtcLedgerCanister;
        };
      };
      case (#ICP) {
        tokenObject := {
          token_type = Constants.TokenType.ICP;
          canister_id = Constants.IcpLedgerCanister;
        };
      };
      case (#FREE) {
        return #err(#GenericError({ message = "Cannot process transfer for a FREE event"; error_code = 0 }));
      };
    };
    canistergeekLogger.logMessage("Token object --->" # debug_show (tokenObject));

    let ledgerCanisterActor : Ledger.Self = actor (tokenObject.canister_id);
    let source_account_id_hex = LedgerService.getLedgerAccountFromSubaccountBlob(Principal.toText(userIdOfRemitter), null);
    let konectaCanisterSubAccountBlob = LedgerService.getSubAccountIdBlob(konectaEventData.subaccount_id_index, Principal.toText(canisterPrincipal));
    let destination_account_id_hex = LedgerService.getLedgerAccountFromSubaccountBlob(Principal.toText(canisterPrincipal), ?konectaCanisterSubAccountBlob);
    let createdAtTime = Nat64.fromNat(Int.abs(Time.now()));

    let icrc2TransferFromObject = {
      to = {
        owner = canisterPrincipal;
        subaccount = ?konectaCanisterSubAccountBlob;
      };
      fee = payload.fee;
      spender_subaccount = null; // Spender is the canister itself, main account
      from = {
        owner = userIdOfRemitter;
        subaccount = null;
      };
      memo = payload.memo;
      created_at_time = ?createdAtTime;
      amount = payload.amount;
    };
    canistergeekLogger.logMessage("ICRC2 Transfer object --->" # debug_show (icrc2TransferFromObject));

    let transferResponse = await ledgerCanisterActor.icrc2_transfer_from(icrc2TransferFromObject);
    canistergeekLogger.logMessage("ICRC2 Transfer response --->" # debug_show (transferResponse));

    switch (transferResponse) {
      case (#Ok(blockIndex)) {
        let transactionObject = {
          event_id = payload.eventId;
          remitter_user_id = Principal.toText(userIdOfRemitter);
          transferred_to_type = Constants.TransferredToTypeVariant.EventSubaccount;
          beneficiary_user_id = Principal.toText(canisterPrincipal);
          source_account_id_hex = source_account_id_hex;
          destination_account_id_hex = destination_account_id_hex;
          block_index = blockIndex;
          amount = payload.amount;
          fee = HelperService.initializeNatField(payload.fee, 0);
          narration = "Transferred " # Nat.toText(payload.amount) # " " # tokenObject.token_type # " from " # source_account_id_hex # " to " # destination_account_id_hex;
          memo = payload.memo;
          created_at_time = createdAtTime;
        };
        canistergeekLogger.logMessage("Create transaction object --->" # debug_show (transactionObject));

        let transactionResponse = await TransactionCreateService.createTransaction(transactionObject, alfangoDB);
        canistergeekLogger.logMessage("Create transaction response --->" # debug_show (transactionResponse));

        switch (transactionResponse) {
          case (#ok(transactionResponse)) {
            #ok(transactionResponse.id);
          };
          case (#err(error)) {
            #err(#AddTxHistoryError({ message = HelperService.textArrayToString(error) }));
          };
        };
      };
      case (#Err(transferError)) {
        #err(transferError);
      };
    };
  };
};
