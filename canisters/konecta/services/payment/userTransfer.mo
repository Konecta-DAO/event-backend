import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
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

import Ledger "../../candid/ledger";
import HttpTypes "../../library/emailLibrary/email/src/email_backend/http.types";
import Account "../../services/icPCH/Account";
import CommonService "../../services/shared/common";
import LedgerService "../../services/shared/ledger";
import TransactionCreateService "../../services/transaction/create";
import TransactionReadService "../../services/transaction/read";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../utils/helper";
import ForwardExpertFeedbackService "../email/forward_expert_feedback/send";
import SharedService "../shared/shared";

module {
  public func transferAmountFromSubAccountToUserForEvent(
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
      let err : [ArgumentTypes.LedgerIcrc1TransferError] = [#FetchEventDetailsError({ message = "Event not found for transfer." })];
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

      var userIdOfBenificiary = Principal.fromText(eventData.user_id);
      var typeOfTransfer : ArgumentTypes.TransferredToType = Constants.TransferredToTypeVariant.CreatorUser;

      if (eventData.event_type == Constants.EventType.Request) {
        let acceptedUserResponse = await eventCanisterActor.getAttendeesByActionWithUserDetailsAsync(eventId, #Accepted);
        canistergeekLogger.logMessage("Accepted User Response from Event Canister --->" # debug_show (acceptedUserResponse));

        switch (acceptedUserResponse) {
          case (#ok(acceptedUsers)) {
            if (Array.size(acceptedUsers) > 0) {
              userIdOfBenificiary := Principal.fromText(acceptedUsers[0].principal_id);
              typeOfTransfer := Constants.TransferredToTypeVariant.AcceptedUser;
            } else {
              canistergeekLogger.logMessage("CRITICAL: Transfer initiated for a request event with no accepted user. Event ID: " # eventId);
              throw Error.reject("Failed to get accepted user for service request");
            };
          };
          case (#err(error)) {
            canistergeekLogger.logMessage("Applied User Response Error --->" # debug_show (error));
            transactionErrorBuffer.add(#GetAcceptedUserError({ message = HelperService.textArrayToString(error) }));
            throw Error.reject("Failed to get accepted user for service request: " # HelperService.textArrayToString(error));
          };
        };
      };

      let ledgerCanisterActor : Ledger.Self = actor (canister_id);

      switch (subaccountTransactionResponse) {
        case (#ok(subaccountTransactionData)) {
          try {
            var eventSubAccountIdHex = "";
            var subaccountTransactionAmountTotal = 0;
            var subaccountTransactionMemo = Text.encodeUtf8("");
            let noOfTransactionsPerEvent = 2;
            let transferFeePerTransaction = await ledgerCanisterActor.icrc1_fee();
            let totalTransferFee = transferFeePerTransaction * noOfTransactionsPerEvent;
            canistergeekLogger.logMessage("Total transfer fee amount --->" # debug_show (totalTransferFee));

            for (subaccountTransaction in subaccountTransactionData.vals()) {
              eventSubAccountIdHex := subaccountTransaction.destination_account_id_hex;
              subaccountTransactionAmountTotal := subaccountTransactionAmountTotal + subaccountTransaction.amount;
              subaccountTransactionMemo := subaccountTransaction.memo;
            };

            canistergeekLogger.logMessage("Subaccount transaction total amount --->" # debug_show (subaccountTransactionAmountTotal));
            canistergeekLogger.logMessage("Transfer fee per transaction --->" # debug_show (transferFeePerTransaction));

            let totalTransactionAmount = Int.abs(subaccountTransactionAmountTotal - totalTransferFee);
            canistergeekLogger.logMessage("Total transaction amount --->" # debug_show (totalTransactionAmount));

            let amountTransferArray = [
              {
                owner = userIdOfBenificiary;
                amount = CommonService.calculateTransferAmount(0.8, totalTransactionAmount);
                transferToType = typeOfTransfer;
                fee = transferFeePerTransaction;
              },
              {
                owner = canisterPrincipal;
                amount = CommonService.calculateTransferAmount(0.2, totalTransactionAmount);
                transferToType = Constants.TransferredToTypeVariant.KonectaAccount;
                fee = transferFeePerTransaction;
              },
            ];
            canistergeekLogger.logMessage("Amount transfer array --->" # debug_show (amountTransferArray));

            for (amountTransferItem in amountTransferArray.vals()) {
              let source_account_id_hex = eventSubAccountIdHex;
              let destination_account_id_hex = LedgerService.getLedgerAccountFromSubaccountBlob(Principal.toText(amountTransferItem.owner), ?Account.defaultSubaccount());
              let createdAtTime = Nat64.fromNat(Int.abs(Time.now()));

              let icrc1TransferObject = {
                to = { owner = amountTransferItem.owner; subaccount = null };
                fee = ?amountTransferItem.fee;
                memo = ?subaccountTransactionMemo;
                from_subaccount = ?LedgerService.getSubAccountIdBlob(eventData.subaccount_id_index, Principal.toText(canisterPrincipal));
                created_at_time = ?createdAtTime;
                amount = amountTransferItem.amount;
              };
              canistergeekLogger.logMessage("Icrc1 transfer object --->" # debug_show (icrc1TransferObject));

              let transferResponse = await ledgerCanisterActor.icrc1_transfer(icrc1TransferObject);
              canistergeekLogger.logMessage("Transfer response --->" # debug_show (transferResponse));

              switch (transferResponse) {
                case (#Ok(blockIndex)) {
                  let transactionObject = {
                    event_id = eventId;
                    remitter_user_id = Principal.toText(canisterPrincipal);
                    transferred_to_type = amountTransferItem.transferToType;
                    beneficiary_user_id = Principal.toText(amountTransferItem.owner);
                    source_account_id_hex = source_account_id_hex;
                    destination_account_id_hex = destination_account_id_hex;
                    block_index = blockIndex;
                    amount = amountTransferItem.amount;
                    fee = amountTransferItem.fee;
                    narration = "Transferred " # Nat.toText(amountTransferItem.amount) # " " # eventData.price_token # " from " # source_account_id_hex # " to " # destination_account_id_hex;
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
                      throw Error.reject("Add Transaction Error for " # Principal.toText(amountTransferItem.owner) # " :" # HelperService.textArrayToString(error));
                    };
                  };
                };
                case (#Err(transferError)) {
                  canistergeekLogger.logMessage("Icrc1 Transfer Error --->" # debug_show (transferError));
                  transactionErrorBuffer.add(transferError);
                  throw Error.reject("Transfer Error: " # debug_show (transferError));
                };
              };
            };
            #ok("Amount transferred successfully");
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
      #err([#FreeEventError({ message = "Cannot transfer amount for free event" })]);
    };
  };

  public func transferAmountToBeneficiary(
    userIdOfRemitter : Text,
    eventId : Text,
    canisterPrincipal : Principal,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
    emailPayload : ArgumentTypes.UserMoneyTransferEmailPayload,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
  ) : async Result.Result<Text, [ArgumentTypes.LedgerIcrc1TransferError]> {
    let transactionSuccessBuffer = Buffer.Buffer<Text>(0);
    var transactionIdOfUser = "";
    let transactionErrorBuffer = Buffer.Buffer<ArgumentTypes.LedgerIcrc1TransferError>(0);

    let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;
    let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(eventId);
    canistergeekLogger.logMessage("Event Response --->" # debug_show (eventData));

    if (Text.size(eventData.event_id) == 0) {
      let err : [ArgumentTypes.LedgerIcrc1TransferError] = [#FetchEventDetailsError({ message = "Event not found for transfer." })];
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
        Principal.fromText(userIdOfRemitter),
        eventId,
        alfangoDB,
      );
      canistergeekLogger.logMessage("Transaction Response --->" # debug_show (subaccountTransactionResponse));

      var userIdOfBenificiary = Principal.fromText(eventData.user_id);
      var typeOfTransfer : ArgumentTypes.TransferredToType = Constants.TransferredToTypeVariant.CreatorUser;

      if (eventData.event_type == Constants.EventType.Request) {
        let acceptedUserResponse = await eventCanisterActor.getAttendeesByActionWithUserDetailsAsync(eventId, #Accepted);
        canistergeekLogger.logMessage("Accepted User Response from Event Canister --->" # debug_show (acceptedUserResponse));

        switch (acceptedUserResponse) {
          case (#ok(acceptedUsers)) {
            if (Array.size(acceptedUsers) > 0) {
              userIdOfBenificiary := Principal.fromText(acceptedUsers[0].principal_id);
              typeOfTransfer := Constants.TransferredToTypeVariant.AcceptedUser;
            } else {
              canistergeekLogger.logMessage("CRITICAL: Beneficiary transfer initiated for a request event with no accepted user. Event ID: " # eventId);
              throw Error.reject("Failed to get accepted user for service request");
            };
          };
          case (#err(error)) {
            canistergeekLogger.logMessage("Error fetching accepted user from Event Canister --->" # debug_show (error));
            transactionErrorBuffer.add(#GetAcceptedUserError({ message = HelperService.textArrayToString(error) }));
            throw Error.reject("Failed to get accepted user for service request: " # HelperService.textArrayToString(error));
          };
        };
      };

      let ledgerCanisterActor : Ledger.Self = actor (canister_id);

      switch (subaccountTransactionResponse) {
        case (#ok(subaccountTransaction)) {
          try {
            let noOfTransactionsPerEvent = 2; // User and Konecta
            let transferFeePerTransaction = await ledgerCanisterActor.icrc1_fee();
            let totalTransferFee = transferFeePerTransaction * noOfTransactionsPerEvent;
            canistergeekLogger.logMessage("Total transfer fee amount --->" # debug_show (totalTransferFee));
            canistergeekLogger.logMessage("Transfer fee per transaction --->" # debug_show (transferFeePerTransaction));

            let totalTransactionAmount = Int.abs(subaccountTransaction.amount - totalTransferFee);
            canistergeekLogger.logMessage("Total transaction amount --->" # debug_show (totalTransactionAmount));

            let amountTransferArray = [
              {
                owner = userIdOfBenificiary;
                amount = CommonService.calculateTransferAmount(0.8, totalTransactionAmount);
                transferToType = typeOfTransfer;
                fee = transferFeePerTransaction;
              },
              {
                owner = canisterPrincipal;
                amount = CommonService.calculateTransferAmount(0.2, totalTransactionAmount);
                transferToType = Constants.TransferredToTypeVariant.KonectaAccount;
                fee = transferFeePerTransaction;
              },
            ];
            canistergeekLogger.logMessage("Amount transfer array --->" # debug_show (amountTransferArray));

            for (amountTransferItem in amountTransferArray.vals()) {
              let source_account_id_hex = subaccountTransaction.destination_account_id_hex;
              let destination_account_id_hex = LedgerService.getLedgerAccountFromSubaccountBlob(Principal.toText(amountTransferItem.owner), ?Account.defaultSubaccount());
              let createdAtTime = Nat64.fromNat(Int.abs(Time.now()));

              let icrc1TransferObject = {
                to = { owner = amountTransferItem.owner; subaccount = null };
                fee = ?amountTransferItem.fee;
                memo = ?subaccountTransaction.memo;
                from_subaccount = ?LedgerService.getSubAccountIdBlob(eventData.subaccount_id_index, Principal.toText(canisterPrincipal));
                created_at_time = ?createdAtTime;
                amount = amountTransferItem.amount;
              };
              canistergeekLogger.logMessage("Icrc1 transfer object --->" # debug_show (icrc1TransferObject));

              let transferResponse = await ledgerCanisterActor.icrc1_transfer(icrc1TransferObject);
              canistergeekLogger.logMessage("Transfer response --->" # debug_show (transferResponse));

              switch (transferResponse) {
                case (#Ok(blockIndex)) {
                  let transactionObject = {
                    event_id = eventId;
                    remitter_user_id = Principal.toText(canisterPrincipal);
                    transferred_to_type = amountTransferItem.transferToType;
                    beneficiary_user_id = Principal.toText(amountTransferItem.owner);
                    source_account_id_hex = source_account_id_hex;
                    destination_account_id_hex = destination_account_id_hex;
                    block_index = blockIndex;
                    amount = amountTransferItem.amount;
                    fee = amountTransferItem.fee;
                    narration = "Transferred " # Nat.toText(amountTransferItem.amount) # " " # eventData.price_token # " from " # source_account_id_hex # " to " # destination_account_id_hex;
                    memo = ?subaccountTransaction.memo;
                    created_at_time = createdAtTime;
                  };
                  canistergeekLogger.logMessage("Create Transaction object --->" # debug_show (transactionObject));

                  let transactionResponse = await TransactionCreateService.createTransaction(transactionObject, alfangoDB);
                  canistergeekLogger.logMessage("Create Transaction response --->" # debug_show (transactionResponse));

                  switch (transactionResponse) {
                    case (#ok(transactionResponse)) {
                      transactionSuccessBuffer.add(transactionResponse.id);
                      if (amountTransferItem.transferToType != Constants.TransferredToTypeVariant.KonectaAccount) {
                        transactionIdOfUser := transactionResponse.id;
                        let emailPayloadObject = {
                          event_id = eventId;
                          remitter_user_id_of_refundee = "";
                          user_feedback = emailPayload.user_feedback;
                          creator_feedback = emailPayload.creator_feedback;
                          expert_feedback_id = emailPayload.expert_feedback_id;
                          remitter_feedback_missing = emailPayload.remitter_feedback_missing;
                          transaction_id = ?transactionResponse.id;
                        };
                        canistergeekLogger.logMessage("Email Payload --->" # debug_show (emailPayloadObject));
                        if (Text.size(emailPayload.creator_feedback.recording_link) > 0) {
                          let _forwardExpertFeedbackRes = ForwardExpertFeedbackService.sendEventRecordingLinkToRemitter(emailPayloadObject, alfangoDB, canistergeekLogger, transform);
                        };
                      };
                    };
                    case (#err(error)) {
                      canistergeekLogger.logMessage("Create Transaction Error --->" # debug_show (error));
                      transactionErrorBuffer.add(#AddTxHistoryError({ message = HelperService.textArrayToString(error) }));
                      throw Error.reject("Add Transaction Error for " # Principal.toText(amountTransferItem.owner) # " :" # HelperService.textArrayToString(error));
                    };
                  };
                };
                case (#Err(transferError)) {
                  canistergeekLogger.logMessage("Icrc1 Transfer Error --->" # debug_show (transferError));
                  transactionErrorBuffer.add(transferError);
                  throw Error.reject("Transfer Error: " # debug_show (transferError));
                };
              };
            };
            #ok(transactionIdOfUser);
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
      #err([#FreeEventError({ message = "Cannot Transfer amount for free event" })]);
    };
  };
};
