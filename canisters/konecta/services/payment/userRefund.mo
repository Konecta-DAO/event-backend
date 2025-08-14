import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import Array "mo:base/Array";

import Ledger "../../candid/ledger";
import HttpTypes "../../library/emailLibrary/email/src/email_backend/http.types";
import LedgerService "../../services/shared/ledger";
import TransactionCreateService "../../services/transaction/create";
import TransactionReadService "../../services/transaction/read";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../utils/helper";
import ForwardExpertFeedbackService "../email/forward_expert_feedback/send";
import SharedService "../shared/shared";
import Account "../../services/icPCH/Account";

module {
  public func refundAmountForCancelEventByCreator(
    eventId : Text,
    canisterPrincipal : Principal,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, [ArgumentTypes.LedgerIcrc1TransferError]> {

    let transactionSuccessBuffer = Buffer.Buffer<Text>(0);
    let transactionErrorBuffer = Buffer.Buffer<ArgumentTypes.LedgerIcrc1TransferError>(0);

    let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;
    let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(eventId);
    canistergeekLogger.logMessage("Event Response --->" # debug_show (eventData));

    if (Text.size(eventData.event_id) == 0) {
      let err : [ArgumentTypes.LedgerIcrc1TransferError] = [#FetchEventDetailsError({ message = "Event not found for refund." })];
      return #err(err);
    };

    var canister_id = "";
    switch (eventData.price_token) {
      case ("ICP") canister_id := Constants.IcpLedgerCanister;
      case ("CKBTC") canister_id := Constants.CkbtcLedgerCanister;
      case _ canister_id := Constants.IcpLedgerCanister;
    };
    canistergeekLogger.logMessage("Canister Id --->" # debug_show (canister_id));

    if (eventData.price_token != Constants.TokenType.FREE) {
      let subaccountTransactionResponse = TransactionReadService.getAllTransactionsForEventByType(
        eventId,
        Constants.TransferredToType.EventSubaccount,
        alfangoDB,
      );
      canistergeekLogger.logMessage("Transaction Response --->" # debug_show (subaccountTransactionResponse));

      let typeOfTransfer : ArgumentTypes.TransferredToType = Constants.TransferredToTypeVariant.CancellationRefund;
      let ledgerCanisterActor : Ledger.Self = actor (canister_id);

      switch (subaccountTransactionResponse) {
        case (#ok(subaccountTransactionData)) {
          try {
            let subaccountTransactionFee = await ledgerCanisterActor.icrc1_fee();

            for (subaccountTransaction in subaccountTransactionData.vals()) {
              let eventSubAccountIdHex = subaccountTransaction.destination_account_id_hex;
              let subaccountTransactionAmountTotal = subaccountTransaction.amount;
              let subaccountTransactionMemo = subaccountTransaction.memo;
              let userIdOfBenificiary = Principal.fromText(subaccountTransaction.remitter_user_id);
              let source_account_id_hex = eventSubAccountIdHex;
              let destination_account_id_hex = subaccountTransaction.source_account_id_hex;
              let createdAtTime = Nat64.fromNat(Int.abs(Time.now()));
              let transactionAmount = Int.abs(subaccountTransactionAmountTotal - subaccountTransactionFee);

              let icrc1TransferObject = {
                to = {
                  owner = userIdOfBenificiary;
                  subaccount = null;
                };
                fee = ?subaccountTransactionFee;
                memo = ?subaccountTransactionMemo;
                from_subaccount = ?LedgerService.getSubAccountIdBlob(eventData.subaccount_id_index, Principal.toText(canisterPrincipal));
                created_at_time = ?createdAtTime;
                amount = transactionAmount;
              };
              canistergeekLogger.logMessage("Icrc1 transfer object --->" # debug_show (icrc1TransferObject));

              let transferResponse = await ledgerCanisterActor.icrc1_transfer(icrc1TransferObject);
              canistergeekLogger.logMessage("Transfer response --->" # debug_show (transferResponse));

              switch (transferResponse) {
                case (#Ok(blockIndex)) {
                  let transactionObject = {
                    event_id = eventId;
                    remitter_user_id = Principal.toText(canisterPrincipal);
                    transferred_to_type = typeOfTransfer;
                    beneficiary_user_id = Principal.toText(userIdOfBenificiary);
                    source_account_id_hex = source_account_id_hex;
                    destination_account_id_hex = destination_account_id_hex;
                    block_index = blockIndex;
                    amount = transactionAmount;
                    fee = subaccountTransactionFee;
                    narration = "Refunded " # Nat.toText(transactionAmount) # " " # eventData.price_token # " from " # source_account_id_hex # " to " # destination_account_id_hex;
                    memo = ?subaccountTransactionMemo;
                    created_at_time = createdAtTime;
                  };
                  canistergeekLogger.logMessage("Create Transaction object --->" # debug_show (transactionObject));

                  let transactionResponse = await TransactionCreateService.createTransaction(transactionObject, alfangoDB);
                  canistergeekLogger.logMessage("Create Transaction response --->" # debug_show (transactionResponse));

                  switch (transactionResponse) {
                    case (#ok(transactionResponse)) {
                      transactionSuccessBuffer.add(transactionResponse.id);
                    };
                    case (#err(error)) {
                      canistergeekLogger.logMessage("Create Transaction Error --->" # debug_show (error));
                      transactionErrorBuffer.add(#AddTxHistoryError({ message = HelperService.textArrayToString(error) }));
                      throw Error.reject("Add Refund Transaction Error for " # Principal.toText(userIdOfBenificiary) # " :" # HelperService.textArrayToString(error));
                    };
                  };
                };
                case (#Err(transferError)) {
                  canistergeekLogger.logMessage("Icrc1 Transfer Error --->" # debug_show (transferError));
                  transactionErrorBuffer.add(transferError);
                  throw Error.reject("Refund Transfer Error: " # debug_show (transferError));
                };
              };
            };
            #ok("Amount refunded successfully");
          } catch (e) {
            canistergeekLogger.logMessage("Catch block Error --->" # debug_show (Error.message(e)));
            #err(Buffer.toArray(transactionErrorBuffer));
          };
        };
        case (#err(error)) {
          canistergeekLogger.logMessage("Fetch Transaction History Error --->" # debug_show (error));
          transactionErrorBuffer.add(#FetchTxHistoryError({ message = error }));
          #err(Buffer.toArray(transactionErrorBuffer));
        };
      };
    } else {
      #err([#FreeEventError({ message = "Cannot Refund amount for free event" })]);
    };
  };

  public func refundAmountForCalendarEventRemoval(
    userPrincipalOfRefundee : Principal,
    eventId : Text,
    canisterPrincipal : Principal,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
    emailPayload : ArgumentTypes.UserMoneyTransferEmailPayload,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
  ) : async Result.Result<Text, [ArgumentTypes.LedgerIcrc1TransferError]> {

    let transactionErrorBuffer = Buffer.Buffer<ArgumentTypes.LedgerIcrc1TransferError>(0);

    let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;
    let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(eventId);
    canistergeekLogger.logMessage("Event Response --->" # debug_show (eventData));

    if (Text.size(eventData.event_id) == 0) {
      let err : [ArgumentTypes.LedgerIcrc1TransferError] = [#FetchEventDetailsError({ message = "Event not found for refund." })];
      return #err(err);
    };

    var canister_id = "";
    switch (eventData.price_token) {
      case ("ICP") canister_id := Constants.IcpLedgerCanister;
      case ("CKBTC") canister_id := Constants.CkbtcLedgerCanister;
      case _ canister_id := Constants.IcpLedgerCanister;
    };
    canistergeekLogger.logMessage("Canister Id --->" # debug_show (canister_id));

    if (eventData.price_token != Constants.TokenType.FREE) {
      let subaccountTransactionResponse = TransactionReadService.getRemitterTransactionsForUserForEvent(
        userPrincipalOfRefundee,
        eventId,
        alfangoDB,
      );
      canistergeekLogger.logMessage("Transaction Response --->" # debug_show (subaccountTransactionResponse));

      var typeOfTransfer : ArgumentTypes.TransferredToType = Constants.TransferredToTypeVariant.CancellationRefund;

      if (Text.size(emailPayload.expert_feedback_id) > 0) {
        typeOfTransfer := Constants.TransferredToTypeVariant.RefundByExpert;
      } else if ((Text.size(emailPayload.creator_feedback.id) > 0) or (Text.size(emailPayload.user_feedback.id) > 0)) {
        typeOfTransfer := Constants.TransferredToTypeVariant.AutomaticRefundByJob;
      };

      let ledgerCanisterActor : Ledger.Self = actor (canister_id);

      switch (subaccountTransactionResponse) {
        case (#ok(subaccountTransaction)) {
          try {
            let subaccountTransactionFee = await ledgerCanisterActor.icrc1_fee();
            let eventSubAccountIdHex = subaccountTransaction.destination_account_id_hex;
            let subaccountTransactionAmountTotal = subaccountTransaction.amount;
            let subaccountTransactionMemo = subaccountTransaction.memo;
            let userIdOfBenificiary = Principal.fromText(subaccountTransaction.remitter_user_id);
            let source_account_id_hex = eventSubAccountIdHex;
            let destination_account_id_hex = subaccountTransaction.source_account_id_hex;
            let createdAtTime = Nat64.fromNat(Int.abs(Time.now()));
            let transactionAmount = Int.abs(subaccountTransactionAmountTotal - subaccountTransactionFee);

            let icrc1TransferObject = {
              to = {
                owner = userIdOfBenificiary;
                subaccount = null;
              };
              fee = ?subaccountTransactionFee;
              memo = ?subaccountTransactionMemo;
              from_subaccount = ?LedgerService.getSubAccountIdBlob(eventData.subaccount_id_index, Principal.toText(canisterPrincipal));
              created_at_time = ?createdAtTime;
              amount = transactionAmount;
            };
            canistergeekLogger.logMessage("Icrc1 transfer object --->" # debug_show (icrc1TransferObject));

            let transferResponse = await ledgerCanisterActor.icrc1_transfer(icrc1TransferObject);
            canistergeekLogger.logMessage("Transfer response --->" # debug_show (transferResponse));

            switch (transferResponse) {
              case (#Ok(blockIndex)) {
                let transactionObject = {
                  event_id = eventId;
                  remitter_user_id = Principal.toText(canisterPrincipal);
                  transferred_to_type = typeOfTransfer;
                  beneficiary_user_id = Principal.toText(userIdOfBenificiary);
                  source_account_id_hex = source_account_id_hex;
                  destination_account_id_hex = destination_account_id_hex;
                  block_index = blockIndex;
                  amount = transactionAmount;
                  fee = subaccountTransactionFee;
                  narration = "Refunded " # Nat.toText(transactionAmount) # " " # eventData.price_token # " from " # source_account_id_hex # " to " # destination_account_id_hex;
                  memo = ?subaccountTransactionMemo;
                  created_at_time = createdAtTime;
                };
                canistergeekLogger.logMessage("Create Transaction object --->" # debug_show (transactionObject));

                let transactionResponse = await TransactionCreateService.createTransaction(transactionObject, alfangoDB);
                canistergeekLogger.logMessage("Create Transaction response --->" # debug_show (transactionResponse));

                switch (transactionResponse) {
                  case (#ok(transactionResponse)) {
                    let emailPayloadObject = {
                      event_id = eventId;
                      remitter_user_id_of_refundee = Principal.toText(userIdOfBenificiary);
                      user_feedback = emailPayload.user_feedback;
                      creator_feedback = emailPayload.creator_feedback;
                      expert_feedback_id = emailPayload.expert_feedback_id;
                      remitter_feedback_missing = emailPayload.remitter_feedback_missing;
                      transaction_id = ?transactionResponse.id;
                    };

                    canistergeekLogger.logMessage("Email Payload --->" # debug_show (emailPayloadObject));
                    let _forwardExpertFeedbackRes = await ForwardExpertFeedbackService.sendRefundEmailToRemitter(emailPayloadObject, alfangoDB, canistergeekLogger, transform);
                    #ok(transactionResponse.id);
                  };
                  case (#err(error)) {
                    canistergeekLogger.logMessage("Create Transaction Error --->" # debug_show (error));
                    transactionErrorBuffer.add(#AddTxHistoryError({ message = HelperService.textArrayToString(error) }));
                    throw Error.reject("Add Refund Transaction Error for " # Principal.toText(userIdOfBenificiary) # " :" # HelperService.textArrayToString(error));
                  };
                };
              };
              case (#Err(transferError)) {
                canistergeekLogger.logMessage("Icrc1 Transfer Error --->" # debug_show (transferError));
                transactionErrorBuffer.add(transferError);
                throw Error.reject("Refund Transfer Error: " # debug_show (transferError));
              };
            };
          } catch (e) {
            canistergeekLogger.logMessage("Catch block Error --->" # debug_show (Error.message(e)));
            #err(Buffer.toArray(transactionErrorBuffer));
          };
        };
        case (#err(error)) {
          canistergeekLogger.logMessage("Fetch Transaction History Error --->" # debug_show (error));
          transactionErrorBuffer.add(#FetchTxHistoryError({ message = error }));
          #err(Buffer.toArray(transactionErrorBuffer));
        };
      };
    } else {
      #err([#FreeEventError({ message = "Cannot Refund amount for free event" })]);
    };
  };
};
