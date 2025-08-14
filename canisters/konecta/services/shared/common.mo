import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import Array "mo:base/Array";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";

module {

  public func getEventType(action : ArgumentTypes.EventType, initialValue : Text) : Text {
    var eventType = initialValue;

    switch (action) {
      case (#Request) eventType := Constants.EventType.Request;
      case (#Offer) eventType := Constants.EventType.Offer;
    };

    return eventType;
  };

  public func getEventTypeVariant(action : Text, initialValue : ArgumentTypes.EventType) : ArgumentTypes.EventType {
    switch (action) {
      case ("Request") Constants.EventTypeVariant.Request;
      case ("Offer") Constants.EventTypeVariant.Offer;
      case _ initialValue;
    };
  };

  public func getParticipationTypeVariant(action : Text, initialValue : ArgumentTypes.ParticipationType) : ArgumentTypes.ParticipationType {
    switch (action) {
      case ("PersonToPerson") Constants.ParticipationTypeVariant.PersonToPerson;
      case ("PersonToMultiplePersons") Constants.ParticipationTypeVariant.PersonToMultiplePersons;
      case _ initialValue;
    };
  };

  public func getRecordingVisibiltyVariant(action : Text, initialValue : ArgumentTypes.RecordingVisibility) : ArgumentTypes.RecordingVisibility {
    switch (action) {
      case ("Public") Constants.RecordingVisibilityVariant.Public;
      case ("Private") Constants.RecordingVisibilityVariant.Private;
      case _ initialValue;
    };
  };

  public func getTransferType(transferType : ArgumentTypes.TransferredToType, initialValue : Text) : Text {
    var typeOfTransfer = initialValue;

    switch (transferType) {
      case (#EventSubaccount) typeOfTransfer := Constants.TransferredToType.EventSubaccount;
      case (#CreatorUser) typeOfTransfer := Constants.TransferredToType.CreatorUser;
      case (#AcceptedUser) typeOfTransfer := Constants.TransferredToType.AcceptedUser;
      case (#KonectaAccount) typeOfTransfer := Constants.TransferredToType.KonectaAccount;
      case (#CancellationRefund) typeOfTransfer := Constants.TransferredToType.CancellationRefund;
      case (#AutomaticRefundByJob) typeOfTransfer := Constants.TransferredToType.AutomaticRefundByJob;
      case (#RefundByExpert) typeOfTransfer := Constants.TransferredToType.RefundByExpert;
    };

    return typeOfTransfer;
  };

  public func getActionType(action : ArgumentTypes.EventAttendeeActions) : Text {
    var actionType = "";

    switch (action) {
      case (#Applied) actionType := Constants.EventAttendeeStatus.Applied;
      case (#Joined) actionType := Constants.EventAttendeeStatus.Joined;
      case (#Invited) actionType := Constants.EventAttendeeStatus.Invited;
      case (#Accepted) actionType := Constants.EventAttendeeStatus.Accepted;
      case (#Declined) actionType := Constants.EventAttendeeStatus.Declined;
      case (#Withdrawn) actionType := Constants.EventAttendeeStatus.Withdrawn;
    };

    return actionType;
  };

  public func getPriceToken(token : ?ArgumentTypes.Token, initialValue : Text) : Text {
    var priceToken = Constants.TokenType.ICP;

    switch (token) {
      case (?#CKBTC) priceToken := Constants.TokenType.CKBTC;
      case (?#ICP) priceToken := Constants.TokenType.ICP;
      case (?#FREE) priceToken := Constants.TokenType.FREE;
      case null priceToken := initialValue;
    };

    return priceToken;
  };

  public func getPriceTokenVariant(token : Text, initialValue : ArgumentTypes.Token) : ArgumentTypes.Token {
    switch (token) {
      case ("CKBTC") { return #CKBTC };
      case ("ICP") { return #ICP };
      case ("FREE") { return #FREE };
      case _ { return initialValue };
    };
  };

  public func getFeedbackStatusType(action : ?ArgumentTypes.FeedbackActions) : Text {
    var feedbackStatusType = "";

    switch (action) {
      case (?#Yes) feedbackStatusType := Constants.FeedbackStatus.Yes;
      case (?#No) feedbackStatusType := Constants.FeedbackStatus.No;
      case null feedbackStatusType := "";
    };

    return feedbackStatusType;
  };

  public func getTransferOrRefundType(action : ?ArgumentTypes.MoneyTransferActions) : Text {
    var actionType = "";

    switch (action) {
      case (?#TransferToBeneficiary) actionType := Constants.MoneyTransferActions.TransferToBeneficiary;
      case (?#RefundToRemitter) actionType := Constants.MoneyTransferActions.RefundToRemitter;
      case null actionType := "";
    };

    return actionType;
  };

  public func getUserType(eventData : ArgumentTypes.EventProtocolCanisterPayload, userId : Text) : Text {
    var userType = "";
    switch (eventData.event_type) {
      case ("Request") {
        if (eventData.user_id == userId) {
          userType := Constants.EventCompletionEmailUserType.RequestCreator;
        } else {
          userType := Constants.EventCompletionEmailUserType.Acceptee;
        };
      };
      case ("Offer") {
        if (eventData.user_id == userId) {
          userType := Constants.EventCompletionEmailUserType.OfferCreator;
        } else {
          userType := Constants.EventCompletionEmailUserType.Attendee;
        };
      };
      case _ ();
    };

    return userType;
  };

  public func createProposalArray(proposalBuffer : Buffer.Buffer<ArgumentTypes.ProposalResponsePayload>, myProposals : ArgumentTypes.PaginatedProposalCompositeQueryPayload, eventResponseArray : ArgumentTypes.EventWithUserDataTupleArray) : ArgumentTypes.PaginatedProposalResponsePayload {
    let eventResponseIter = Iter.fromArray(eventResponseArray);
    let eventResponseMap = Map.fromIter<Text, ArgumentTypes.EventProtocolCanisterPayload>(eventResponseIter, Map.thash);

    for (proposal in myProposals.items.vals()) {
      switch (Map.get(eventResponseMap, Map.thash, proposal.event_id)) {
        case (?eventProtocolData) {
          proposalBuffer.add({
            event_id = proposal.event_id;
            event_name = eventProtocolData.name;
            event_description = eventProtocolData.description;
            userData = eventProtocolData.userData;
            note = proposal.note;
            location = proposal.location;
            action = proposal.action;
            updated_at = proposal.updated_at;
          });
        };
        case (null) { /* Silently ignore if no matching event is found */ };
      };
    };

    return {
      items = Buffer.toArray(proposalBuffer);
      offset = myProposals.offset;
      limit = myProposals.limit;
      scannedItemCount = myProposals.scannedItemCount;
      nonScannedItemCount = myProposals.nonScannedItemCount;
      totalRecords = myProposals.totalRecords;
    };
  };

  public func createFeedObjectFromKonectaObject(konectaEventId : Text, eventId : Text, konectaEventData : ArgumentTypes.EventResponsePayload, eventData : ArgumentTypes.EventProtocolCanisterPayload) : ArgumentTypes.FeedResponsePayload {
    return {
      konecta_event_id = konectaEventId;
      user_id = konectaEventData.user_id;
      event_id = eventId;
      subaccount_id_hex = konectaEventData.subaccount_id_hex;
      coverphoto = eventData.coverphoto;
      name = eventData.name;
      description = eventData.description;
      location = eventData.location;
      start_date = eventData.start_date;
      end_date = eventData.end_date;
      language = eventData.language;
      status = eventData.status;
      userData = eventData.userData;
      event_type = konectaEventData.event_type;
      expertise = konectaEventData.expertise;
      price_token = konectaEventData.price_token;
      token_amount = konectaEventData.token_amount;
      categories = konectaEventData.categories;
      consultations = konectaEventData.consultations;
      interests = konectaEventData.interests;
      showcase_link = konectaEventData.showcase_link;
      participation_type = konectaEventData.participation_type;
      subaccount_id_index = konectaEventData.subaccount_id_index;
      recording_visibility = konectaEventData.recording_visibility;
      is_recording_available = konectaEventData.is_recording_available;
      eventMetadata = eventData.metadata;
      konectaMetadata = konectaEventData.metadata;
    };
  };

  public func createFeedObjectWithoutUserDataFromKonectaObject(konectaEventId : Text, eventId : Text, konectaEventData : ArgumentTypes.EventResponsePayload, eventData : ArgumentTypes.EventCanisterResponseWithoutUser) : ArgumentTypes.FeedResponsePayloadWithoutUser {
    return {
      konecta_event_id = konectaEventId;
      user_id = konectaEventData.user_id;
      event_id = eventId;
      subaccount_id_hex = konectaEventData.subaccount_id_hex;
      coverphoto = eventData.coverphoto;
      name = eventData.name;
      description = eventData.description;
      location = eventData.location;
      start_date = eventData.start_date;
      end_date = eventData.end_date;
      language = eventData.language;
      status = eventData.status;
      event_type = konectaEventData.event_type;
      expertise = konectaEventData.expertise;
      price_token = konectaEventData.price_token;
      token_amount = konectaEventData.token_amount;
      categories = konectaEventData.categories;
      consultations = konectaEventData.consultations;
      interests = konectaEventData.interests;
      showcase_link = konectaEventData.showcase_link;
      participation_type = konectaEventData.participation_type;
      recording_visibility = konectaEventData.recording_visibility;
      is_recording_available = konectaEventData.is_recording_available;
      subaccount_id_index = konectaEventData.subaccount_id_index;
      eventMetadata = eventData.metadata;
      konectaMetadata = konectaEventData.metadata;
    };
  };

  public func createMissingFeedbackEventArray(feedBuffer : Buffer.Buffer<ArgumentTypes.MissingFeedbackEvent>, eventResponseArray : [ArgumentTypes.EventCanisterResponseWithoutUser], canistergeekLogger : Canistergeek.Logger) : [ArgumentTypes.MissingFeedbackEvent] {
    for (event in eventResponseArray.vals()) {
      let feedData = createMissingFeedbackEventObject(event.event_id, event);
      feedBuffer.add(feedData);
    };
    return Buffer.toArray(feedBuffer);
  };

  private func createMissingFeedbackEventObject(eventId : Text, eventData : ArgumentTypes.EventCanisterResponseWithoutUser) : ArgumentTypes.MissingFeedbackEvent {
    return {
      event_id = eventId;
      name = eventData.name;
      start_date = eventData.start_date;
      end_date = eventData.end_date;
    };
  };

  public func createTransactionObject(
    transactionData : ArgumentTypes.TransactionResponsePayload,
    eventData : ArgumentTypes.FeedResponsePayloadWithoutUser,
    benificaryUserData : ?ArgumentTypes.TransactionUser,
  ) : ArgumentTypes.TransactionWithUserDataResponse {
    return {
      transaction_id = transactionData.transaction_id;
      event_id = eventData.event_id;
      transferred_to_type = transactionData.transferred_to_type;
      remitter_user_id = transactionData.remitter_user_id;
      beneficiary_user_id = transactionData.beneficiary_user_id;
      source_account_id_hex = transactionData.source_account_id_hex;
      destination_account_id_hex = transactionData.destination_account_id_hex;
      block_index = transactionData.block_index;
      amount = transactionData.amount;
      fee = transactionData.fee;
      narration = transactionData.narration;
      memo = transactionData.memo;
      created_at_time = transactionData.created_at_time;
      eventData = eventData;
      beneficiary_user_data = benificaryUserData;
      url = Constants.ICDashboard # Nat.toText(transactionData.block_index);
    };
  };

  public func calculateTransferAmount(percent : Float, amount : Nat) : Nat {
    return Int.abs(Float.toInt(percent * Float.fromInt(amount)));
  };
};
