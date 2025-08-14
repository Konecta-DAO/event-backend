import Database "mo:alfangodb/AlfangoDB";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import SharedService "../../services/shared/shared";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../utils/helper";

module {

  private let initialEventCanisterObject : ArgumentTypes.EventCanisterResponseWithoutUser = {
    coverphoto = "";
    description = "";
    end_date = 0;
    language = "";
    location = "";
    metadata = [];
    name = "";
    start_date = 0;
    status = "";
    user_id = "";
    event_id = "";
  };

  public let initialKonectaEventObject : ArgumentTypes.EventResponsePayload = {
    konecta_event_id = "";
    user_id = "";
    event_id = "";
    event_name = "";
    event_description = "";
    subaccount_id_hex = "";
    event_type = "";
    status = "";
    start_date = 0;
    end_date = 0;
    categories = [];
    consultations = [];
    expertise = "";
    price_token = "";
    token_amount = 0.0;
    interests = [];
    showcase_link = "";
    participation_type = "";
    recording_visibility = "";
    is_recording_available = false;
    subaccount_id_index = 0;
    metadata = [];
  };

  public let initialFeedbackObject : ArgumentTypes.UserFeedbackResponsePayload = {
    id = "";
    event_id = "";
    user_id = "";
    firstname = "";
    lastname = "";
    email = "";
    timezone = "";
    username = "";
    user_type = "";
    successful = "";
    reason = "";
    rating = 0;
    recording_link = "";
  };

  public func handleEventCanisterResponseWithoutUserData(eventResponse : Result.Result<ArgumentTypes.EventCanisterResponseWithoutUser, [Text]>) : ArgumentTypes.EventCanisterResponseWithoutUser {
    switch (eventResponse) {
      case (#ok(eventData)) eventData;
      case (#err(_error)) initialEventCanisterObject;
    };
  };

  // Function to transform the response of getting all events
  public func transformGetAllEventsResponse(eventResponse : Database.ScanOutputType) : Result.Result<[ArgumentTypes.EventResponsePayload], [Text]> {
    switch (eventResponse) {
      case (#ok(eventData)) {
        let eventBuffer = Buffer.Buffer<ArgumentTypes.EventResponsePayload>(eventData.size());
        for (itemObject in eventData.vals()) {
          let konectaEventId = itemObject.id;
          let eventItem = itemObject.item;

          handleEventBuffer(konectaEventId, eventItem, eventBuffer);
        };
        #ok(Buffer.toArray(eventBuffer));
      };
      case (#err(error)) #err(error);
    };
  };

  // Helper function to handle the event buffer
  private func handleEventBuffer(konectaEventId : Text, eventItem : [(Text, Database.AttributeDataValue)], eventBuffer : Buffer.Buffer<ArgumentTypes.EventResponsePayload>) : () {
    let amountText = HelperService.getTupleValueAsText(eventItem, "token_amount");
    let amountResult = HelperService.textToFloat(amountText);
    let amount : Float = switch (amountResult) {
      case (#ok(f)) f;
      case (#err(_err)) {
        Debug.print("failed to parse token_amount");
        0.0;
      };
    };

    eventBuffer.add({
      konecta_event_id = konectaEventId;
      user_id = HelperService.getTupleValueAsText(eventItem, "user_id");
      event_id = HelperService.getTupleValueAsText(eventItem, "event_id");
      event_name = HelperService.getTupleValueAsText(eventItem, "event_name");
      event_description = HelperService.getTupleValueAsText(eventItem, "event_description");
      subaccount_id_hex = HelperService.getTupleValueAsText(eventItem, "subaccount_id_hex");
      event_type = HelperService.getTupleValueAsText(eventItem, "event_type");
      status = HelperService.getTupleValueAsText(eventItem, "status");
      start_date = HelperService.textToNat(HelperService.getTupleValueAsText(eventItem, "start_date"));
      end_date = HelperService.textToNat(HelperService.getTupleValueAsText(eventItem, "end_date"));
      expertise = HelperService.getTupleValueAsText(eventItem, "expertise");
      price_token = HelperService.getTupleValueAsText(eventItem, "price_token");
      token_amount = amount;
      categories = switch (HelperService.getTupleValue(eventItem, "categories")) {
        case (null) [];
        case (?attrValue) HelperService.getTextArrayFromAttributeDataValueArray(attrValue);
      };
      consultations = switch (HelperService.getTupleValue(eventItem, "consultations")) {
        case (null) [];
        case (?attrValue) HelperService.getTextArrayFromAttributeDataValueArray(attrValue);
      };
      interests = switch (HelperService.getTupleValue(eventItem, "interests")) {
        case (null) [];
        case (?attrValue) HelperService.getTextArrayFromAttributeDataValueArray(attrValue);
      };
      showcase_link = HelperService.getTupleValueAsText(eventItem, "showcase_link");
      participation_type = HelperService.getTupleValueAsText(eventItem, "participation_type");
      recording_visibility = HelperService.getTupleValueAsText(eventItem, "recording_visibility");
      is_recording_available = HelperService.getTupleValueAsText(eventItem, "is_recording_available") == "true";
      subaccount_id_index = HelperService.textToNat(HelperService.getTupleValueAsText(eventItem, "subaccount_id_index"));
      metadata = HelperService.getTupleArrayFromAttributeDataValueArray(HelperService.getTupleValue(eventItem, "metadata"));
    });
  };

  public func transformPaginatedTransactionResponse(totalRecords : Nat, transactionResponse : Database.PaginatedScanOutputType) : Result.Result<ArgumentTypes.PaginatedTransactionResponsePayload, Text> {
    switch (transactionResponse) {
      case (#ok(transactionData)) {
        let transactionBuffer = Buffer.Buffer<ArgumentTypes.TransactionResponsePayload>(transactionData.items.size());
        for (itemObject in transactionData.items.vals()) {
          transactionBuffer.add(generateTransactionObject(itemObject.id, itemObject.item));
        };
        #ok({
          items = Buffer.toArray(transactionBuffer);
          offset = 0;
          limit = transactionData.limit;
          scannedItemCount = Array.size(transactionData.items);
          nonScannedItemCount = 0;
          totalRecords = totalRecords;
        });
      };
      case (#err(error)) #err(HelperService.textArrayToString(error));
    };
  };

  public func transformTransactionResponse(transactionResponse : Database.ScanOutputType) : Result.Result<[ArgumentTypes.TransactionResponsePayload], Text> {
    switch (transactionResponse) {
      case (#ok(transactionData)) {
        let transactionBuffer = Buffer.Buffer<ArgumentTypes.TransactionResponsePayload>(transactionData.size());
        for (itemObject in transactionData.vals()) {
          transactionBuffer.add(generateTransactionObject(itemObject.id, itemObject.item));
        };
        #ok(Buffer.toArray(transactionBuffer));
      };
      case (#err(error)) #err(HelperService.textArrayToString(error));
    };
  };

  public func transformGetTransactionResponse(transactionResponse : Database.GetItemByIdOutputType) : Result.Result<ArgumentTypes.TransactionResponsePayload, Text> {
    switch (transactionResponse) {
      case (#ok(transactionData)) {
        let transactionObject = generateTransactionObject(transactionData.id, transactionData.item);
        return #ok(transactionObject);
      };
      case (#err(error)) #err(HelperService.textArrayToString(error));
    };
  };

  private func generateTransactionObject(id : Text, itemObject : [(Text, Database.AttributeDataValue)]) : ArgumentTypes.TransactionResponsePayload {
    let transactionItem = itemObject;
    return {
      transaction_id = id;
      event_id = HelperService.getTupleValueAsText(transactionItem, "event_id");
      transferred_to_type = HelperService.getTupleValueAsText(transactionItem, "transferred_to_type");
      remitter_user_id = HelperService.getTupleValueAsText(transactionItem, "remitter_user_id");
      beneficiary_user_id = HelperService.getTupleValueAsText(transactionItem, "beneficiary_user_id");
      source_account_id_hex = HelperService.getTupleValueAsText(transactionItem, "source_account_id_hex");
      destination_account_id_hex = HelperService.getTupleValueAsText(transactionItem, "destination_account_id_hex");
      block_index = HelperService.textToNat(HelperService.getTupleValueAsText(transactionItem, "block_index"));
      amount = HelperService.textToNat(HelperService.getTupleValueAsText(transactionItem, "amount"));
      fee = HelperService.textToNat(HelperService.getTupleValueAsText(transactionItem, "fee"));
      narration = HelperService.getTupleValueAsText(transactionItem, "narration");
      memo = Text.encodeUtf8(HelperService.getTupleValueAsText(transactionItem, "memo"));
      created_at_time = Nat64.fromNat(HelperService.textToNat(HelperService.getTupleValueAsText(transactionItem, "created_at_time")));
    };
  };

  public func transformGetFeedbackResponse(feedbackResponse : Database.GetItemByIdOutputType) : Result.Result<ArgumentTypes.UserFeedbackResponsePayload, [Text]> {
    switch (feedbackResponse) {
      case (#ok(feedbackData)) {
        let feedbackBuffer = Buffer.Buffer<ArgumentTypes.UserFeedbackResponsePayload>(1);
        handleFeedbackBuffer(feedbackData.id, feedbackData.item, feedbackBuffer);
        let event = Buffer.toArray(feedbackBuffer)[0];
        #ok(event);
      };
      case (#err(error)) #err(error);
    };
  };

  public func transformGetAllFeedbacksResponse(feedbackResponse : Database.ScanOutputType) : Result.Result<[ArgumentTypes.UserFeedbackResponsePayload], [Text]> {
    switch (feedbackResponse) {
      case (#ok(feedbackData)) {
        let feedbackBuffer = Buffer.Buffer<ArgumentTypes.UserFeedbackResponsePayload>(feedbackData.size());
        for (itemObject in feedbackData.vals()) {
          handleFeedbackBuffer(itemObject.id, itemObject.item, feedbackBuffer);
        };
        #ok(Buffer.toArray(feedbackBuffer));
      };
      case (#err(error)) #err(error);
    };
  };

  private func handleFeedbackBuffer(feedbackId : Text, feedbackItem : [(Text, Database.AttributeDataValue)], feedbackBuffer : Buffer.Buffer<ArgumentTypes.UserFeedbackResponsePayload>) : () {
    feedbackBuffer.add({
      id = feedbackId;
      event_id = HelperService.getTupleValueAsText(feedbackItem, "event_id");
      user_id = HelperService.getTupleValueAsText(feedbackItem, "user_id");
      firstname = HelperService.getTupleValueAsText(feedbackItem, "firstname");
      lastname = HelperService.getTupleValueAsText(feedbackItem, "lastname");
      email = HelperService.getTupleValueAsText(feedbackItem, "email");
      username = HelperService.getTupleValueAsText(feedbackItem, "username");
      timezone = HelperService.getTupleValueAsText(feedbackItem, "timezone");
      user_type = HelperService.getTupleValueAsText(feedbackItem, "user_type");
      successful = HelperService.getTupleValueAsText(feedbackItem, "successful");
      reason = HelperService.getTupleValueAsText(feedbackItem, "reason");
      rating = HelperService.textToNat(HelperService.getTupleValueAsText(feedbackItem, "rating"));
      recording_link = HelperService.getTupleValueAsText(feedbackItem, "recording_link");
    });
  };

  public func transformGetAllEventCompletionMailResponse(eventCompletionMailResponse : Database.ScanOutputType) : Result.Result<[ArgumentTypes.EventCompletionResponsePayload], [Text]> {
    switch (eventCompletionMailResponse) {
      case (#ok(eventCompletionMails)) {
        let mailBuffer = Buffer.Buffer<ArgumentTypes.EventCompletionResponsePayload>(eventCompletionMails.size());
        for (mail in eventCompletionMails.vals()) {
          let mailItem = mail.item;
          mailBuffer.add({
            id = mail.id;
            event_id = HelperService.getTupleValueAsText(mailItem, "event_id");
            user_id = HelperService.getTupleValueAsText(mailItem, "user_id");
            user_type = HelperService.getTupleValueAsText(mailItem, "user_type");
            recipient_type = HelperService.getTupleValueAsText(mailItem, "recipient_type");
            notification_type = HelperService.getTupleValueAsText(mailItem, "notification_type");
            template_name = HelperService.getTupleValueAsText(mailItem, "template_name");
            from = HelperService.getTupleValueAsText(mailItem, "from");
            to = HelperService.getTupleValueAsText(mailItem, "to");
            message_id = HelperService.getTupleValueAsText(mailItem, "message_id");
            idempotency_key = HelperService.getTupleValueAsText(mailItem, "idempotency_key");
          });
        };
        #ok(Buffer.toArray(mailBuffer));
      };
      case (#err(error)) #err(error);
    };
  };

  public func transformGetAllExpertForwardedMailResponse(expertMailResponse : Database.ScanOutputType) : Result.Result<[ArgumentTypes.ForwardToExpertResponsePayload], [Text]> {
    switch (expertMailResponse) {
      case (#ok(expertMails)) {
        let mailBuffer = Buffer.Buffer<ArgumentTypes.ForwardToExpertResponsePayload>(expertMails.size());
        for (mail in expertMails.vals()) {
          let mailItem = mail.item;
          mailBuffer.add({
            id = mail.id;
            event_id = HelperService.getTupleValueAsText(mailItem, "event_id");
            user_feedback_id = HelperService.getTupleValueAsText(mailItem, "user_feedback_id");
            template_name = HelperService.getTupleValueAsText(mailItem, "template_name");
            from = HelperService.getTupleValueAsText(mailItem, "from");
            to = HelperService.getTupleValueAsText(mailItem, "to");
            message_id = HelperService.getTupleValueAsText(mailItem, "message_id");
            idempotency_key = HelperService.getTupleValueAsText(mailItem, "idempotency_key");
          });
        };
        #ok(Buffer.toArray(mailBuffer));
      };
      case (#err(error)) #err(error);
    };
  };

  public func getTotalRecords(
    tableName : Text,
    filterExpressions : [SearchTypes.FilterExpressionType],
    alfangoDB : Database.AlfangoDB,
  ) : Nat {
    let queryFilters = Array.map<SearchTypes.FilterExpressionType, SearchTypes.QueryFilter>(
      filterExpressions,
      func(expr) { #expression(expr) },
    );
    let filter : SearchTypes.QueryFilter = #AND(queryFilters);

    let idsResponse = Database.scanAndGetIds({
      scanAndGetIdsInput = {
        databaseName = Constants.KonectA;
        tableName = tableName;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    Debug.print("IdsResponse --> " # debug_show (idsResponse));

    switch (idsResponse) {
      case (#ok(response)) return Array.size(response.ids);
      case (#err(_error)) return 0;
    };
  };

  public func scanTableData(
    tableName : Text,
    filterExpressions : [SearchTypes.FilterExpressionType],
    alfangoDB : Database.AlfangoDB,
  ) : Database.ScanOutputType {
    let queryFilters = Array.map<SearchTypes.FilterExpressionType, SearchTypes.QueryFilter>(
      filterExpressions,
      func(expr) { #expression(expr) },
    );
    let filter : SearchTypes.QueryFilter = #AND(queryFilters);

    let responseData = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = tableName;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    Debug.print("Response --> " # debug_show (responseData));
    return responseData;
  };

  public func transformGetAllUserActionEmails(actionEmailResponse : Database.ScanOutputType) : Result.Result<[ArgumentTypes.UserActionEmailResponse], [Text]> {
    switch (actionEmailResponse) {
      case (#ok(emailDataArr)) {
        let emailBuffer = Buffer.Buffer<ArgumentTypes.UserActionEmailResponse>(emailDataArr.size());
        for (emailData in emailDataArr.vals()) {
          let emailItem = emailData.item;
          emailBuffer.add({
            event_id = HelperService.getTupleValueAsText(emailItem, "event_id");
            from_user_id = HelperService.getTupleValueAsText(emailItem, "from_user_id");
            to_user_id = HelperService.getTupleValueAsText(emailItem, "to_user_id");
            action = HelperService.getTupleValueAsText(emailItem, "action");
            from = HelperService.getTupleValueAsText(emailItem, "from");
            to = HelperService.getTupleValueAsText(emailItem, "to");
            template_name = HelperService.getTupleValueAsText(emailItem, "template_name");
            message_id = HelperService.getTupleValueAsText(emailItem, "message_id");
            idempotency_key = HelperService.getTupleValueAsText(emailItem, "idempotency_key");
            timestamp = HelperService.textToNat(HelperService.getTupleValueAsText(emailItem, "timestamp"));
          });
        };
        #ok(Buffer.toArray(emailBuffer));
      };
      case (#err(error)) #err(error);
    };
  };

  public func transformGetAllExpertFeedbacksResponse(
    feedbackResponse : Database.ScanOutputType,
    getUserFeedback : (
      userFeedbackId : Text,
      alfangoDB : Database.AlfangoDB,
      canistergeekLogger : Canistergeek.Logger,
    ) -> Result.Result<ArgumentTypes.UserFeedbackResponsePayload, [Text]>,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : Result.Result<[ArgumentTypes.ExpertFeedbackResponsePayload], [Text]> {
    switch (feedbackResponse) {
      case (#ok(feedbackData)) {
        let feedbackBuffer = Buffer.Buffer<ArgumentTypes.ExpertFeedbackResponsePayload>(feedbackData.size());
        for (itemObject in feedbackData.vals()) {
          let feedbackItem = itemObject.item;
          let userFeedbackId = HelperService.getTupleValueAsText(feedbackItem, "user_feedback_id");
          let userFeedbackResponse = getUserFeedback(userFeedbackId, alfangoDB, canistergeekLogger);
          let userFeedback : ?ArgumentTypes.UserFeedbackResponsePayload = switch (userFeedbackResponse) {
            case (#ok(data)) ?data;
            case (#err(_)) null;
          };

          feedbackBuffer.add({
            event_id = HelperService.getTupleValueAsText(feedbackItem, "event_id");
            remitter_feedback_missing = HelperService.getTupleValueAsText(feedbackItem, "remitter_feedback_missing") == "true";
            user_feedback_id = userFeedbackId;
            user_feedback = userFeedback;
            agreeWithUserFeedback = HelperService.getTupleValueAsText(feedbackItem, "agreeWithUserFeedback");
            user_id = HelperService.getTupleValueAsText(feedbackItem, "user_id");
            transfer_or_refund = HelperService.getTupleValueAsText(feedbackItem, "transfer_or_refund");
            event_recording_link = HelperService.getTupleValueAsText(feedbackItem, "event_recording_link");
            reason = HelperService.getTupleValueAsText(feedbackItem, "reason");
          });
        };
        #ok(Buffer.toArray(feedbackBuffer));
      };
      case (#err(error)) #err(error);
    };
  };
};
