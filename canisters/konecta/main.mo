import Database "mo:alfangodb/AlfangoDB";
import Bool "mo:base/Bool";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import { recurringTimer; setTimer } "mo:base/Timer";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import Array "mo:base/Array";
import { HOUR } "mo:time-consts";
import SchemaService "services/schema";
import HttpTypes "library/emailLibrary/email/src/email_backend/http.types";
import EventCompletionJob "services/cron_job/event_completion_job";
import MoneyTransferJob "services/cron_job/money_transfer_job";
import RunJobsService "services/cron_job/run_jobs";
import EventCompletionReadService "services/email/event_completion/read";
import ExpertFeedbackService "services/email/expert_feedback/create";
import ExpertFeedbackReadService "services/email/expert_feedback/read";
import ForwardExpertFeedbackService "services/email/forward_expert_feedback/send";
import ForwardUserFeedbackReadService "services/email/forward_user_feedback/read";
import UserActionEmailService "services/email/user_action/read";
import UserFeedbackCreateService "services/email/user_feedback/create";
import UserFeedbackReadService "services/email/user_feedback/read";
import ApplyRequestService "services/feed_requests/apply";
import EventJoinService "services/feed_offers/join";
import AcceptRequestService "services/feed_requests/accept";
import UserRefundService "services/payment/userRefund";
import DeclineRequestService "services/feed_requests/decline";
import Account "services/icPCH/Account";
import SubaccountTransferService "services/payment/subaccountTransfer";
import UserTransferService "services/payment/userTransfer";
import EventCommonService "services/shared/common";
import Httptransform "services/shared/httptransform";
import LedgerService "services/shared/ledger";
import SharedService "services/shared/shared";
import TransformService "services/shared/transform";
import TransactionReadService "services/transaction/read";
import ArgumentTypes "types/argumentTypes";
import KonectaConstants "utils/constants";
import HelperService "utils/helper";
import HashMap "mo:base/HashMap";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";

shared ({ caller = initializer }) actor class KonectaCanister() = this {

  stable var alfangoDB : Database.AlfangoDB = {
    databases = Map.new<Text, Database.Database>();
    STABLE_MEMORY_LIMIT = 3_221_225_472; // 3 GiB
    var totalStableBytes = 0;
  };

  private let canistergeekMonitor = Canistergeek.Monitor();
  private let canistergeekLogger = Canistergeek.Logger();
  stable var _canistergeekMonitorUD : ?Canistergeek.UpgradeData = null;
  stable var _canistergeekLoggerUD : ?Canistergeek.LoggerUpgradeData = null;

  let oneDayInNanoseconds : Nat = Int.abs(24) * HOUR;
  let nextDateInNanoseconds : Nat = HelperService.getNextDateInNanoseconds();

  /**
   * Generates the schema for the Konecta Canister.
   * This function creates the project database and the Konecta event table.
   * @returns A text indicating the success or failure of schema generation.
   */
  public shared func generateSchema() : async Text {
    canistergeekMonitor.collectMetrics();
    SchemaService.generateSchema(alfangoDB, canistergeekLogger);
  };

  private func getCurrentCanisterPrincipal() : Principal {
    return Principal.fromActor(this);
  };

  /**
   * Retrieves the list of trusted origins (white-listed canisters).
   * @returns An array of text containing the trusted origins.
   */
  public query func get_trusted_origins() : async [Text] {
    return KonectaConstants.whiteListedCanisters;
  };

  public shared query func icrc28_trusted_origins() : async {
    trusted_origins : [Text];
  } {
    let trusted_origins = KonectaConstants.whiteListedCanisters;
    return { trusted_origins };
  };

  public query func transform(raw : HttpTypes.TransformArgs) : async HttpTypes.HttpResponsePayload {
    Httptransform.transform(raw);
  };

  public query (msg) func getDefaultAccountIdentifier() : async Text {
    LedgerService.getLedgerAccountFromSubaccountBlob(Principal.toText(msg.caller), ?Account.defaultSubaccount());
  };

  public shared (msg) func cancelKonectaEvent(eventId : Text) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();

    // 1. Get all necessary data in one call from the single source of truth
    let eventCanisterActor = actor (KonectaConstants.EventCanister) : SharedService.EventCanisterType;
    let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(eventId);

    if (Text.size(eventData.event_id) == 0) {
      return #err("Event not found");
    };

    // 2. Delegate the cancellation logic to the Event canister
    let cancelResponse = await eventCanisterActor.cancelEvent(msg.caller, eventId, eventData.event_type);

    switch (cancelResponse) {
      case (#ok(_)) {
        // 3. Handle local Konecta logic (refunds) if the event was not free
        if (eventData.price_token != KonectaConstants.TokenType.FREE) {
          let refundResponse = await UserRefundService.refundAmountForCancelEventByCreator(
            eventId,
            getCurrentCanisterPrincipal(),
            alfangoDB,
            canistergeekLogger,
          );
          switch (refundResponse) {
            case (#ok(_)) return #ok("Event canceled and refunds processed.");
            case (#err(_)) return #err("Event canceled, but refund processing failed.");
          };
        } else {
          return #ok("Event canceled successfully.");
        };
      };
      case (#err(errorMsg)) {
        return #err(errorMsg);
      };
    };
  };

  public shared (msg) func withdrawFromEvent(eventId : Text) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    let eventCanisterActor = actor (KonectaConstants.EventCanister) : SharedService.EventCanisterType;

    // 1. Get Event Details to check if it's a paid event
    let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(eventId);
    if (Text.size(eventData.event_id) == 0) {
      return #err("Event not found.");
    };

    // 2. Delegate the core withdrawal logic to the Event canister
    // The payload for withdrawEventAttendee is { event_id, invitee_user_id, action, ... }
    let withdrawPayload : ArgumentTypes.WithdrawAttendeeRequestPayload = {
      event_id = eventId;
      invitee_user_id = msg.caller;
      action = #Withdrawn;
      timestamp = Int.abs(Time.now());
      event_type = eventData.event_type;
      event_status = eventData.status; // Pass the current status
    };

    let withdrawResult = await eventCanisterActor.withdrawEventAttendee(withdrawPayload);

    switch (withdrawResult) {
      case (#err(e)) {
        return #err("Failed to withdraw from event: " # e);
      };
      case (#ok(updatedEventData)) {
        // Withdrawal was successful in the Event canister.
        // Now, handle Konecta-specific business logic.

        // 3. Process refund if it was a paid event
        if (updatedEventData.price_token != KonectaConstants.TokenType.FREE) {

          // Get the details of the user who is withdrawing (the refundee)
          let refundeeDetails = await SharedService.getUserDetails(Principal.toText(msg.caller));

          // The creator's details are already in eventData.userData
          let creatorDetails = eventData.userData;

          // Create placeholder feedback objects, as this isn't a feedback-driven refund.
          // The refund function needs these to know who to email.
          let userFeedbackPayload : ArgumentTypes.UserFeedbackResponsePayload = {
            id = "";
            event_id = eventId;
            user_id = refundeeDetails.principal_id;
            firstname = refundeeDetails.firstname;
            lastname = refundeeDetails.lastname;
            email = refundeeDetails.email;
            timezone = refundeeDetails.timezone;
            username = refundeeDetails.username;
            user_type = "";
            successful = "";
            reason = "User withdrew from event.";
            rating = 0;
            recording_link = "";
          };

          let creatorFeedbackPayload : ArgumentTypes.UserFeedbackResponsePayload = {
            id = "";
            event_id = eventId;
            user_id = creatorDetails.principal_id;
            firstname = creatorDetails.firstname;
            lastname = creatorDetails.lastname;
            email = creatorDetails.email;
            timezone = creatorDetails.timezone;
            username = creatorDetails.username;
            user_type = "";
            successful = "";
            reason = "";
            rating = 0;
            recording_link = "";
          };

          let emailPayload : ArgumentTypes.UserMoneyTransferEmailPayload = {
            user_feedback = userFeedbackPayload;
            creator_feedback = creatorFeedbackPayload;
            expert_feedback_id = "";
            remitter_feedback_missing = false;
          };

          let refundResponse = await UserRefundService.refundAmountForCalendarEventRemoval(
            msg.caller,
            eventId,
            getCurrentCanisterPrincipal(),
            alfangoDB,
            canistergeekLogger,
            emailPayload,
            transform,
          );

          if (Result.isErr(refundResponse)) {
            // Log the error but inform the user the withdrawal was successful.
            canistergeekLogger.logMessage("Withdrawal successful, but refund failed for event " # eventId);
            return #err("Successfully withdrew from event, but the automated refund failed. Please contact support.");
          };
        };

        return #ok("Successfully withdrew from the event.");
      };
    };
  };

  public shared (msg) func joinPublicEvent(eventId : Text) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await EventJoinService.joinPublicEvent(msg.caller, eventId, alfangoDB, canistergeekLogger);
  };

  public shared (msg) func acceptUserApplication(userIdOfApplicant : Text, eventId : Text) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await AcceptRequestService.acceptUserApplication(msg.caller, userIdOfApplicant, eventId, alfangoDB, canistergeekLogger);
  };

  public shared (msg) func declineServiceRequestApplication(userIdOfApplicant : Text, eventId : Text) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await DeclineRequestService.declineUserApplication(msg.caller, userIdOfApplicant, eventId, canistergeekLogger);
  };

  public composite query (msg) func getApplicationStatusOfMyCreatedEvents(
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
  ) : async Result.Result<ArgumentTypes.PaginatedApplicationStatusOfMyCreatedEvents, [Text]> {
    canistergeekMonitor.collectMetrics();

    let eventCanisterActor = actor (KonectaConstants.EventCanister) : SharedService.EventCanisterType;

    let myRequestsResult = await eventCanisterActor.getPaginatedFilteredEvents({
      currentTimestamp = Int.abs(Time.now());
      isFuture = true;
      eventType = ?KonectaConstants.EventType.Request;
      status = null;
      userId = ?msg.caller;
      categories = null;
      recordingType = null;
      limit = limit;
      cursor = cursor;
    });

    let myRequests = switch (myRequestsResult) {
      case (#err(e)) { return #err(e) };
      case (#ok(reqs)) { reqs };
    };

    if (myRequests.items.size() == 0) {
      return #ok({
        items = [];
        totalRecords = myRequests.totalRecords;
        hasMore = false;
        nextCursor = null;
      });
    };

    // --- BATCH DATA FETCHING ---
    let attendeeFutures = Buffer.Buffer<async Result.Result<[ArgumentTypes.EventAttendeeResponsePayload], [Text]>>(myRequests.items.size());
    for (event in myRequests.items.vals()) {
      attendeeFutures.add(eventCanisterActor.getAllAttendeesIds(event.event_id));
    };
    let allAttendeesMap = HashMap.HashMap<Text, [ArgumentTypes.EventAttendeeResponsePayload]>(0, Text.equal, Text.hash);
    let allApplicantPrincipals = HashMap.HashMap<Text, ()>(0, Text.equal, Text.hash);
    for (i in Iter.range(0, myRequests.items.size() - 1)) {
      let eventId = myRequests.items[i].event_id;
      let result = await attendeeFutures.get(i);
      switch (result) {
        case (#ok(attendees)) {
          allAttendeesMap.put(eventId, attendees);
          for (attendee in attendees.vals()) {
            allApplicantPrincipals.put(attendee.invitee_user_id, ());
          };
        };
        case (#err(e)) {
          canistergeekLogger.logMessage("Failed to get attendees for event " # eventId # ": " # debug_show (e));
        };
      };
    };
    let applicantUserIds = Iter.toArray(allApplicantPrincipals.keys());
    let applicantDataMap = HashMap.HashMap<Text, ArgumentTypes.UserResponsePayload>(0, Text.equal, Text.hash);
    if (applicantUserIds.size() > 0) {
      let indexActor = actor (KonectaConstants.IndexCanister) : SharedService.IndexActor;
      let canisterMappings = await indexActor.getUserCanistersByPrincipal(applicantUserIds);
      let userDetailFutures = Buffer.Buffer<async ArgumentTypes.UserResponsePayload>(canisterMappings.size());
      for (mapping in canisterMappings.vals()) {
        let userCanister = actor (mapping.canister_id) : SharedService.UserCanisterType;
        userDetailFutures.add(userCanister.getUserForEventCanister(mapping.principal_id));
      };
      for (future in userDetailFutures.vals()) {
        let userDetails = await future;
        if (Text.size(userDetails.principal_id) > 0) {
          applicantDataMap.put(userDetails.principal_id, userDetails);
        };
      };
    };

    // --- ASSEMBLE RESPONSE ---
    let finalItems = Buffer.Buffer<ArgumentTypes.ApplicationStatusOfMyCreatedEvents>(myRequests.items.size());
    for (event in myRequests.items.vals()) {
      let applicantsDetailsBuffer = Buffer.Buffer<ArgumentTypes.ApplicantDetailsPayload>(0);
      let eventAttendees = switch (allAttendeesMap.get(event.event_id)) {
        case (?atts) atts;
        case null [];
      };
      for (attendeeRecord in eventAttendees.vals()) {
        switch (applicantDataMap.get(attendeeRecord.invitee_user_id)) {
          case (?userData) {
            applicantsDetailsBuffer.add({
              userData = userData;
              applicationMetadata = attendeeRecord.metadata;
              applicationStatus = attendeeRecord.action;
              applicationTimestamp = attendeeRecord.timestamp;
            });
          };
          case (null) {};
        };
      };
      finalItems.add({
        event_id = event.event_id;
        event_name = event.name;
        event_description = event.description;
        applied_users_details = Buffer.toArray(applicantsDetailsBuffer);
      });
    };

    return #ok({
      items = Buffer.toArray(finalItems);
      totalRecords = myRequests.totalRecords;
      hasMore = myRequests.hasMore;
      nextCursor = myRequests.nextCursor;
    });
  };

  public composite query func getUserStatusForServiceOffers(userPrincipal : Principal, eventId : Text) : async Text {
    Debug.print(debug_show (userPrincipal));
    let eventCanisterActor = actor (KonectaConstants.EventCanister) : SharedService.EventCanisterType;
    await eventCanisterActor.getAttendeeStatusForEvent(userPrincipal, eventId);
  };

  public composite query (msg) func getPaginatedServiceOffersForMyProfile(
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
  ) : async Result.Result<ArgumentTypes.PaginatedFeedResponsePayload, [Text]> {

    let payload = {
      currentTimestamp = Int.abs(Time.now());
      isFuture = true;
      eventType = ?KonectaConstants.EventType.Offer;
      status = ?KonectaConstants.EventStatus.Created;
      userId = ?msg.caller;
      categories = null;
      recordingType = null;
      limit = limit;
      cursor = cursor;
    };

    return await getPaginatedFeed(payload);
  };

  public composite query (msg) func getPaginatedJoinedRequestsForMyProfile(
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
  ) : async Result.Result<ArgumentTypes.PaginatedFeedResponsePayload, [Text]> {
    canistergeekMonitor.collectMetrics();

    let eventCanisterActor = actor (KonectaConstants.EventCanister) : SharedService.EventCanisterType;

    let myJoinedEventsResult = await eventCanisterActor.getPaginatedEventsForAttendee(
      Principal.toText(msg.caller),
      limit,
      cursor,
    );

    switch (myJoinedEventsResult) {
      case (#ok(paginatedEventData)) {
        let feedBuffer = Buffer.Buffer<ArgumentTypes.FeedResponsePayload>(paginatedEventData.items.size());

        for (eventData in paginatedEventData.items.vals()) {
          let feed : ArgumentTypes.FeedResponsePayload = {
            konecta_event_id = "";
            event_id = eventData.event_id;
            user_id = eventData.user_id;
            subaccount_id_hex = eventData.subaccount_id_hex;
            coverphoto = eventData.coverphoto;
            name = eventData.name;
            description = eventData.description;
            location = eventData.location;
            start_date = eventData.start_date;
            end_date = eventData.end_date;
            language = eventData.language;
            status = eventData.status;
            userData = eventData.userData;
            event_type = eventData.event_type;
            expertise = eventData.expertise;
            price_token = eventData.price_token;
            token_amount = eventData.token_amount;
            categories = eventData.categories;
            consultations = eventData.consultations;
            interests = eventData.interests;
            showcase_link = eventData.showcase_link;
            participation_type = eventData.participation_type;
            recording_visibility = eventData.recording_visibility;
            is_recording_available = eventData.is_recording_available;
            subaccount_id_index = eventData.subaccount_id_index;
            eventMetadata = eventData.metadata;
            konectaMetadata = [];
          };
          feedBuffer.add(feed);
        };

        return #ok({
          items = Buffer.toArray(feedBuffer);
          totalRecords = paginatedEventData.totalRecords;
          hasMore = paginatedEventData.hasMore;
          nextCursor = paginatedEventData.nextCursor;
        });
      };
      case (#err(e)) {
        return #err(e);
      };
    };
  };

  public composite query (msg) func getPaginatedJoinedOffersForMyProfile(
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
  ) : async Result.Result<ArgumentTypes.PaginatedFeedResponsePayload, [Text]> {
    canistergeekMonitor.collectMetrics();

    // 1. Call the primary "joined events" function, which is now fully paginated and scalable.
    let allJoinedEventsResult = await getPaginatedJoinedRequestsForMyProfile(
      limit,
      cursor,
    );

    switch (allJoinedEventsResult) {
      case (#err(e)) {
        // If the underlying call fails, propagate the error.
        return #err(e);
      };
      case (#ok(paginatedEventData)) {

        // 2. Filter the results in memory to only include events of type "Offer".
        let offerBuffer = Buffer.Buffer<ArgumentTypes.FeedResponsePayload>(paginatedEventData.items.size());
        for (event in paginatedEventData.items.vals()) {
          if (event.event_type == KonectaConstants.EventType.Offer) {
            offerBuffer.add(event);
          };
        };

        // 3. Return the filtered list within the same paginated structure.
        return #ok({
          items = Buffer.toArray(offerBuffer);
          totalRecords = paginatedEventData.totalRecords;
          hasMore = paginatedEventData.hasMore;
          nextCursor = paginatedEventData.nextCursor;
        });
      };
    };
  };

  public composite query (msg) func getMyServiceOffers(
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor // MODIFIED: Use cursor
  ) : async Result.Result<ArgumentTypes.PaginatedFeedResponsePayload, [Text]> {
    canistergeekMonitor.collectMetrics();

    // 1. Construct the payload for the primary getPaginatedFeed function.
    // This payload specifies all the filtering criteria needed for this specific query:
    // - eventType is "Offer"
    // - status is "Created"
    // - userId is the caller
    let payload = {
      currentTimestamp = Int.abs(Time.now());
      isFuture = true;
      eventType = ?KonectaConstants.EventType.Offer;
      status = ?KonectaConstants.EventStatus.Created;
      userId = ?msg.caller;
      categories = null;
      recordingType = null;
      limit = limit;
      cursor = cursor;
    };

    // 2. Delegate the entire operation to getPaginatedFeed and return its result.
    // It handles the cross-canister call, data transformation, and pagination.
    return await getPaginatedFeed(payload);
  };

  public composite query func getUserDetailsByCompositeQuery(userId : Text) : async ArgumentTypes.UserResponsePayload {
    let indexActor = actor (KonectaConstants.IndexCanister) : SharedService.IndexActor;
    let userCanisterId = await indexActor.getUserCanisterByUserPrincipal(userId);

    let userCanisterActor = actor (userCanisterId) : SharedService.UserCanisterType;
    await userCanisterActor.getUserForEventCanister(userId);
  };

  public composite query (msg) func checkIfUserFeedbackExistsForEvent(eventId : Text) : async Result.Result<Bool, Text> {
    canistergeekMonitor.collectMetrics();

    // 1. Fetch event details from the Event canister (the SSoT for events)
    let eventCanisterActor = actor (KonectaConstants.EventCanister) : SharedService.EventCanisterType;
    let eventData = await eventCanisterActor.getEventDetailsWithUserData(eventId);

    if (Text.size(eventData.event_id) == 0) {
      return #err("Event not found");
    };

    // 2. Determine the user's role in this event to find the correct feedback record
    let userPrincipal = msg.caller;
    var userType = "";

    switch (eventData.event_type) {
      case ("Request") {
        if (eventData.user_id == Principal.toText(userPrincipal)) {
          userType := KonectaConstants.EventCompletionEmailUserType.RequestCreator;
        } else {
          userType := KonectaConstants.EventCompletionEmailUserType.Acceptee;
        };
      };
      case ("Offer") {
        if (eventData.user_id == Principal.toText(userPrincipal)) {
          userType := KonectaConstants.EventCompletionEmailUserType.OfferCreator;
        } else {
          userType := KonectaConstants.EventCompletionEmailUserType.Attendee;
        };
      };
      case (_) {
        // Should not happen with valid data
        return #err("Unknown event type.");
      };
    };

    // 3. Query the local Konecta database for the feedback record.
    // This is a synchronous call to the service layer.
    let userTypeArr = [#text(userType)];
    let result = UserFeedbackReadService.checkFeedbackByUserForEvent(
      Principal.toText(userPrincipal),
      eventId,
      userTypeArr,
      alfangoDB,
      canistergeekLogger,
    );

    return #ok(result);
  };

  public query func checkFeedbackByUserForEvent(
    userId : Text,
    eventId : Text,
    userType : [Database.RelationalExpressionAttributeDataValue],
  ) : async Bool {
    UserFeedbackReadService.checkFeedbackByUserForEvent(userId, eventId, userType, alfangoDB, canistergeekLogger);
  };

  public composite query (msg) func getListOfMissingFeedbackEvents() : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
    canistergeekMonitor.collectMetrics();
    let userPrincipal = msg.caller;
    let userPrincipalText = Principal.toText(userPrincipal);

    let eventCanisterActor = actor (KonectaConstants.EventCanister) : SharedService.EventCanisterType;
    let allRelevantEventIds = HashMap.HashMap<Text, ()>(0, Text.equal, Text.hash);

    // 1. Get all events the user has joined or was accepted to from the Event canister using the correct paginated function.
    var cursor : ?SearchTypes.PaginatedScanCursor = null;
    var hasMore = true;

    // CORRECTED: Wrap the while loop in a label
    label paginationLoop {
      while (hasMore) {
        let joinedEventsResult = await eventCanisterActor.getPaginatedEventsForAttendee(
          userPrincipalText,
          50, // A reasonable batch size, can be adjusted
          cursor,
        );

        switch (joinedEventsResult) {
          case (#ok(page)) {
            for (event in page.items.vals()) {
              allRelevantEventIds.put(event.event_id, ());
            };
            hasMore := page.hasMore;
            cursor := page.nextCursor;
            // If there are no more pages, exit the loop
            if (not hasMore) {
              // CORRECTED: Break the specific label
              break paginationLoop;
            };
          };
          case (#err(e)) {
            // If any page fetch fails, return the error
            return #err(e);
          };
        };
      };
    };

    // 2. Get all events the user created from the Event canister. (This part was already correct)
    let createdEventsResult = await eventCanisterActor.getServiceRequestsForUser(userPrincipal);
    switch (createdEventsResult) {
      case (#ok(events)) {
        for (event in events.vals()) {
          allRelevantEventIds.put(event.event_id, ());
        };
      };
      case (#err(e)) { return #err(e) };
    };

    // 3. Get event IDs for which feedback was already submitted from the local DB via the service module. (Correct)
    let feedbackResult = UserFeedbackReadService.getFeedbackSubmittedEventIds(userPrincipal, alfangoDB);
    let feedbackSubmittedEventIds = switch (feedbackResult) {
      case (#ok(map)) map;
      case (#err(e)) { return #err(e) };
    };

    // 4. Determine which events are missing feedback. (Correct)
    let missingFeedbackEventIds = Buffer.Buffer<Text>(0);
    for (eventId in allRelevantEventIds.keys()) {
      if (feedbackSubmittedEventIds.get(eventId) == null) {
        missingFeedbackEventIds.add(eventId);
      };
    };

    if (missingFeedbackEventIds.size() == 0) {
      return #ok([]);
    };

    // 5. Fetch full details for the missing events in a single batch call. (Correct)
    let eventDetailsArray = await eventCanisterActor.getEventArrayFromEventIdArray(Buffer.toArray(missingFeedbackEventIds));

    let finalPayload = Buffer.Buffer<ArgumentTypes.FeedResponsePayload>(eventDetailsArray.size());
    for ((_id, eventData) in eventDetailsArray.vals()) {
      let feedPayload : ArgumentTypes.FeedResponsePayload = {
        konecta_event_id = ""; // Obsolete field
        event_id = eventData.event_id;
        user_id = eventData.user_id;
        subaccount_id_hex = eventData.subaccount_id_hex;
        coverphoto = eventData.coverphoto;
        name = eventData.name;
        description = eventData.description;
        location = eventData.location;
        start_date = eventData.start_date;
        end_date = eventData.end_date;
        language = eventData.language;
        status = eventData.status;
        userData = eventData.userData;
        event_type = eventData.event_type;
        categories = eventData.categories;
        consultations = eventData.consultations;
        expertise = eventData.expertise;
        price_token = eventData.price_token;
        token_amount = eventData.token_amount;
        interests = eventData.interests;
        showcase_link = eventData.showcase_link;
        participation_type = eventData.participation_type;
        recording_visibility = eventData.recording_visibility;
        is_recording_available = eventData.is_recording_available;
        subaccount_id_index = eventData.subaccount_id_index;
        eventMetadata = eventData.metadata;
        konectaMetadata = []; // Obsolete field
      };
      finalPayload.add(feedPayload);
    };

    return #ok(Buffer.toArray(finalPayload));
  };

  public composite query func getMissingFeedbackEventArray(eventIds : [Text]) : async [ArgumentTypes.MissingFeedbackEvent] {
    canistergeekMonitor.collectMetrics();
    let feedBuffer = Buffer.Buffer<ArgumentTypes.MissingFeedbackEvent>(0);

    let eventCanisterActor = actor (KonectaConstants.EventCanister) : SharedService.EventCanisterType;
    let eventResponseArray = await eventCanisterActor.getBatchEventsByCompositeQuery(eventIds);
    Debug.print(debug_show (eventResponseArray));

    EventCommonService.createMissingFeedbackEventArray(feedBuffer, eventResponseArray, canistergeekLogger);

  };

  public query func getTransactionTableMetadata() : async Database.GetTableMetadataOutputType {
    TransactionReadService.transactionTableMetadata(alfangoDB);
  };

  public composite query (msg) func getTransactionsForUser(
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor // MODIFIED: Use cursor
  ) : async Result.Result<ArgumentTypes.PaginatedTransactionWithUserDataResponse, [Text]> {

    // 1. Call the newly refactored service function with the cursor
    let transactionsResponse = TransactionReadService.getTransactionsForUser(
      msg.caller,
      limit,
      cursor,
      alfangoDB,
    );

    // 2. The rest of the logic remains the same, as generateTransactionResponse
    // is designed to handle the paginated result.
    await generateTransactionResponse(transactionsResponse);
  };

  public composite query (msg) func getTransactionsForUserByType(
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
    transferType : Text,
  ) : async Result.Result<ArgumentTypes.PaginatedTransactionWithUserDataResponse, [Text]> {

    let transactionsResponse = TransactionReadService.getTransactionsForUserByType(
      msg.caller,
      transferType,
      limit,
      cursor,
      alfangoDB,
    );

    await generateTransactionResponse(transactionsResponse);
  };

  public composite query func getTransactionsForEventByType(
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
    eventId : Text,
    transferType : Text,
  ) : async Result.Result<ArgumentTypes.PaginatedTransactionWithUserDataResponse, [Text]> {

    let transactionsResponse = TransactionReadService.getTransactionsForEventByType(
      eventId,
      transferType,
      limit,
      cursor,
      alfangoDB,
    );

    await generateTransactionResponse(transactionsResponse);
  };

  public query func getAllTransactions() : async Result.Result<[ArgumentTypes.TransactionResponsePayload], Text> {
    TransactionReadService.getAllTransactions(alfangoDB);
  };

  public composite query func getAllPaginatedTransactions(
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
  ) : async Result.Result<ArgumentTypes.PaginatedTransactionWithUserDataResponse, [Text]> {

    let transactionsResponse = TransactionReadService.getAllPaginatedTransactions(
      limit,
      cursor,
      alfangoDB,
    );

    await generateTransactionResponse(transactionsResponse);
  };

  public composite query func generateTransactionResponse(transactionResponseData : Result.Result<ArgumentTypes.PaginatedTransactionResponsePayload, Text>) : async Result.Result<ArgumentTypes.PaginatedTransactionWithUserDataResponse, [Text]> {
    canistergeekMonitor.collectMetrics();

    switch (transactionResponseData) {
      case (#err(error)) { return #err([error]) };
      case (#ok(paginatedTransactions)) {
        if (paginatedTransactions.items.size() == 0) {
          // THIS IS THE FIX: The returned object now matches the expected type.
          return #ok({
            items = [];
            totalRecords = paginatedTransactions.totalRecords;
            hasMore = false;
            nextCursor = null;
          });
        };

        // --- Step 1: Collect unique IDs ---
        let eventIdMap = HashMap.HashMap<Text, ()>(0, Text.equal, Text.hash);
        let beneficiaryIdMap = HashMap.HashMap<Text, ()>(0, Text.equal, Text.hash);

        for (transaction in paginatedTransactions.items.vals()) {
          eventIdMap.put(transaction.event_id, ());
          // Only fetch user data if the beneficiary is not the Konecta canister itself
          if (transaction.beneficiary_user_id != Principal.toText(getCurrentCanisterPrincipal())) {
            beneficiaryIdMap.put(transaction.beneficiary_user_id, ());
          };
        };
        let eventIds = Iter.toArray(eventIdMap.keys());
        let beneficiaryIds = Iter.toArray(beneficiaryIdMap.keys());

        // --- Step 2: Batch-fetch all required data concurrently ---

        // Fetch event data
        let eventCanisterActor = actor (KonectaConstants.EventCanister) : SharedService.EventCanisterType;
        let eventDataTuples = await eventCanisterActor.getEventArrayFromEventIdArray(eventIds);
        let eventDataMap = HashMap.fromIter<Text, ArgumentTypes.EventProtocolCanisterPayload>(
          Iter.fromArray(eventDataTuples),
          eventDataTuples.size(),
          Text.equal,
          Text.hash,
        );

        // Fetch beneficiary user data
        let beneficiaryDataMap = HashMap.HashMap<Text, ArgumentTypes.UserResponsePayload>(0, Text.equal, Text.hash);
        if (beneficiaryIds.size() > 0) {
          let indexActor = actor (KonectaConstants.IndexCanister) : SharedService.IndexActor;
          let canisterMappings = await indexActor.getUserCanistersByPrincipal(beneficiaryIds);

          let futures = Buffer.Buffer<async ArgumentTypes.UserResponsePayload>(canisterMappings.size());
          for (mapping in canisterMappings.vals()) {
            let userCanister = actor (mapping.canister_id) : SharedService.UserCanisterType;
            futures.add(userCanister.getUserForEventCanister(mapping.principal_id));
          };

          for (future in futures.vals()) {
            let userDetails = await future;
            beneficiaryDataMap.put(userDetails.principal_id, userDetails);
          };
        };

        // --- Step 3: Assemble the final response (synchronously) ---
        let transactionBuffer = Buffer.Buffer<ArgumentTypes.TransactionWithUserDataResponse>(paginatedTransactions.items.size());
        for (transaction in paginatedTransactions.items.vals()) {
          switch (eventDataMap.get(transaction.event_id)) {
            case (?eventData) {

              let beneficiaryUserData = beneficiaryDataMap.get(transaction.beneficiary_user_id);

              let transactionUserData : ?ArgumentTypes.TransactionUser = do ? {
                let u = beneficiaryUserData!;
                {
                  firstname = u.firstname;
                  lastname = u.lastname;
                  username = u.username;
                  email = u.email;
                };
              };

              // This helper function creates the FeedResponsePayloadWithoutUser
              let eventDataForPayload = EventCommonService.createFeedObjectWithoutUserDataFromKonectaObject("", eventData.event_id, TransformService.initialKonectaEventObject, eventData);

              transactionBuffer.add(
                EventCommonService.createTransactionObject(
                  transaction,
                  eventDataForPayload,
                  transactionUserData,
                )
              );
            };
            case (null) {
              // This case means an event linked in a transaction was not found. Log it.
              canistergeekLogger.logMessage("Could not find event data for transaction related to event: " # transaction.event_id);
            };
          };
        };

        // THIS IS THE FIX: The returned object now matches the expected type.
        return #ok({
          items = Buffer.toArray(transactionBuffer);
          totalRecords = paginatedTransactions.totalRecords;
          hasMore = paginatedTransactions.items.size() == paginatedTransactions.limit;
          nextCursor = null; // Cursors are not supported by this older pagination style
        });
      };
    };
  };

  public shared (msg) func transferAmountFromUserToEventSubAccount(
    payload : ArgumentTypes.TransferRequestPayload
  ) : async Result.Result<Text, ArgumentTypes.LedgerIcrc2TransferError> {
    canistergeekMonitor.collectMetrics();
    await SubaccountTransferService.transferAmountFromUserToEventSubAccount(msg.caller, getCurrentCanisterPrincipal(), payload, alfangoDB, canistergeekLogger);
  };

  public shared func transferAmountFromSubAccountToUserForEvent(
    eventId : Text
  ) : async Result.Result<Text, [ArgumentTypes.LedgerIcrc1TransferError]> {
    canistergeekMonitor.collectMetrics();
    await UserTransferService.transferAmountFromSubAccountToUserForEvent(eventId, getCurrentCanisterPrincipal(), alfangoDB, canistergeekLogger);
  };

  public shared func sendEventCompletionEmail() : async Result.Result<Text, Text> {
    await EventCompletionJob.sendEventCompletionEmail(alfangoDB, canistergeekLogger, transform);
  };

  public query func getListOfEventCompletionEmails() : async Result.Result<[ArgumentTypes.EventCompletionResponsePayload], [Text]> {
    EventCompletionReadService.getListOfEventCompletionEmails(alfangoDB);
  };

  public query func getUserFeedbackTableMetadata() : async Database.GetTableMetadataOutputType {
    UserFeedbackReadService.userFeedbackTableMetadata(alfangoDB);
  };

  public query func eventCompletionNotificationTableMetadata() : async Database.GetTableMetadataOutputType {
    EventCompletionReadService.eventCompletionNotificationTableMetadata(alfangoDB);
  };

  public query func expertEmailTableMetadata() : async Database.GetTableMetadataOutputType {
    ForwardUserFeedbackReadService.expertEmailTableMetadata(alfangoDB);
  };

  public query func expertFeedbackTableMetadata() : async Database.GetTableMetadataOutputType {
    ExpertFeedbackReadService.expertFeedbackTableMetadata(alfangoDB);
  };

  public query func resolutionResponseTableMetadata() : async Database.GetTableMetadataOutputType {
    ForwardExpertFeedbackService.resolutionResponseTableMetadata(alfangoDB);
  };

  public shared (msg) func insertUserFeedback(payload : ArgumentTypes.UserFeedbackRequestPayload) : async Result.Result<ArgumentTypes.CreateUserFeedbackResponsePayload, Text> {
    canistergeekMonitor.collectMetrics();
    await UserFeedbackCreateService.insertUserFeedback(msg.caller, payload, alfangoDB, canistergeekLogger);
  };

  public shared (msg) func insertMultipleUserFeedback(payload : [ArgumentTypes.UserFeedbackRequestPayload]) : async Result.Result<[ArgumentTypes.CreateUserFeedbackResponsePayload], Text> {
    canistergeekMonitor.collectMetrics();
    await UserFeedbackCreateService.insertMultipleUserFeedback(msg.caller, payload, alfangoDB, canistergeekLogger);
  };

  public query func getFeedbackById(feedbackId : Text) : async Result.Result<ArgumentTypes.UserFeedbackResponsePayload, [Text]> {
    canistergeekMonitor.collectMetrics();
    UserFeedbackReadService.getUserFeedback(feedbackId, alfangoDB, canistergeekLogger);
  };

  public query func getListOfUserFeedbacks() : async Result.Result<[ArgumentTypes.UserFeedbackResponsePayload], [Text]> {
    canistergeekMonitor.collectMetrics();
    UserFeedbackReadService.getListOfUserFeedbacks(alfangoDB, canistergeekLogger);
  };

  public query func getListOfExpertFeedbacks() : async Result.Result<[ArgumentTypes.ExpertFeedbackResponsePayload], [Text]> {
    canistergeekMonitor.collectMetrics();
    ExpertFeedbackReadService.getListOfExpertFeedbacks(alfangoDB, canistergeekLogger);
  };

  public query func getListOfUserFeedbackForwardedEmailsToExpert() : async Result.Result<[ArgumentTypes.ForwardToExpertResponsePayload], [Text]> {
    ForwardUserFeedbackReadService.getListOfExpertForwardedEmails(alfangoDB);
  };

  public shared func insertExpertFeedback(payload : ArgumentTypes.ExpertFeedbackRequestPayload) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await ExpertFeedbackService.insertExpertFeedback(getCurrentCanisterPrincipal(), payload, alfangoDB, canistergeekLogger, transform);
  };

  public shared (_msg) func runMoneyTransferJob() : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await MoneyTransferJob.moneyTransfer(getCurrentCanisterPrincipal(), alfangoDB, canistergeekLogger, transform);
  };

  public query func getListOfUserActionEmails() : async Result.Result<[ArgumentTypes.UserActionEmailResponse], [Text]> {
    canistergeekMonitor.collectMetrics();
    UserActionEmailService.getListOfUserActionEmails(alfangoDB, canistergeekLogger);
  };

  /**
   * Allows the calling user to apply to a service request event.
   * @param payload Contains the event_id and a note from the applicant.
   * @returns A result indicating success or failure.
   */
  public shared (msg) func applyToServiceRequest(payload : ArgumentTypes.ApplyToServiceRequestPayload) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await ApplyRequestService.applyToServiceRequest(
      msg.caller,
      payload,
      transform,
      alfangoDB,
      canistergeekLogger,
    );
  };

  public composite query func getPaginatedFeed(
    payload : {
      currentTimestamp : Nat;
      isFuture : Bool;
      eventType : ?Text;
      status : ?Text;
      userId : ?Principal;
      categories : ?[Text];
      recordingType : ?[Bool];
      limit : Nat;
      cursor : ?SearchTypes.PaginatedScanCursor;
    }
  ) : async Result.Result<ArgumentTypes.PaginatedFeedResponsePayload, [Text]> {
    canistergeekMonitor.collectMetrics();

    let eventCanisterActor = actor (KonectaConstants.EventCanister) : SharedService.EventCanisterType;
    let result = await eventCanisterActor.getPaginatedFilteredEvents(payload);

    switch (result) {
      case (#err(e)) {
        return #err(e);
      };
      case (#ok(paginatedResult)) {
        let feedBuffer = Buffer.Buffer<ArgumentTypes.FeedResponsePayload>(paginatedResult.items.size());
        for (eventData in paginatedResult.items.vals()) {
          let feed : ArgumentTypes.FeedResponsePayload = {
            konecta_event_id = "";
            event_id = eventData.event_id;
            user_id = eventData.user_id;
            subaccount_id_hex = eventData.subaccount_id_hex;
            coverphoto = eventData.coverphoto;
            name = eventData.name;
            description = eventData.description;
            location = eventData.location;
            start_date = eventData.start_date;
            end_date = eventData.end_date;
            language = eventData.language;
            status = eventData.status;
            userData = eventData.userData;
            event_type = eventData.event_type;
            expertise = eventData.expertise;
            price_token = eventData.price_token;
            token_amount = eventData.token_amount;
            categories = eventData.categories;
            consultations = eventData.consultations;
            interests = eventData.interests;
            showcase_link = eventData.showcase_link;
            participation_type = eventData.participation_type;
            recording_visibility = eventData.recording_visibility;
            is_recording_available = eventData.is_recording_available;
            subaccount_id_index = eventData.subaccount_id_index;
            eventMetadata = eventData.metadata;
            konectaMetadata = [];
          };
          feedBuffer.add(feed);
        };

        return #ok({
          items = Buffer.toArray(feedBuffer);
          totalRecords = paginatedResult.totalRecords;
          hasMore = paginatedResult.hasMore;
          nextCursor = paginatedResult.nextCursor;
        });
      };
    };
  };

  public composite query func getPaginatedApplicationStatusOfMyCreatedEvents(
    userPrincipal : Principal,
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
  ) : async Result.Result<ArgumentTypes.PaginatedApplicationStatusOfMyCreatedEvents, [Text]> {
    canistergeekMonitor.collectMetrics();
    let eventCanisterActor = actor (KonectaConstants.EventCanister) : SharedService.EventCanisterType;

    // 1. Get the user's created service requests in a paginated way
    let myRequestsResult = await eventCanisterActor.getPaginatedFilteredEvents({
      currentTimestamp = Int.abs(Time.now());
      isFuture = true;
      eventType = ?KonectaConstants.EventType.Request;
      status = null;
      userId = ?userPrincipal;
      categories = null;
      recordingType = null;
      limit = limit;
      cursor = cursor;
    });

    let myRequestsPage = switch (myRequestsResult) {
      case (#err(e)) { return #err(e) };
      case (#ok(page)) { page };
    };

    if (myRequestsPage.items.size() == 0) {
      return #ok({
        items = [];
        totalRecords = myRequestsPage.totalRecords;
        hasMore = myRequestsPage.hasMore;
        nextCursor = myRequestsPage.nextCursor;
      });
    };

    // 2. Batch-fetch all applicants for the events on the current page
    let eventIds = Array.map<ArgumentTypes.EventWithUserDataPayload, Text>(myRequestsPage.items, func(e : ArgumentTypes.EventWithUserDataPayload) { e.event_id });

    let attendeeFutures = Buffer.Buffer<async Result.Result<[ArgumentTypes.EventAttendeeResponsePayload], [Text]>>(eventIds.size());
    for (eventId in eventIds.vals()) {
      attendeeFutures.add(eventCanisterActor.getAllAttendeesIds(eventId));
    };

    // 3. Collect applicant principals and map them to their event
    let eventToApplicantsMap = HashMap.HashMap<Text, Buffer.Buffer<ArgumentTypes.EventAttendeeResponsePayload>>(0, Text.equal, Text.hash);
    let allApplicantPrincipals = HashMap.HashMap<Text, ()>(0, Text.equal, Text.hash);

    for (i in eventIds.keys()) {
      let eventId = eventIds[i];
      let result = await attendeeFutures.get(i);
      switch (result) {
        case (#ok(attendees)) {
          let eventApplicants = switch (eventToApplicantsMap.get(eventId)) {
            case (?buffer) buffer;
            case (null) Buffer.Buffer<ArgumentTypes.EventAttendeeResponsePayload>(0);
          };

          for (attendee in attendees.vals()) {
            if (attendee.action == KonectaConstants.EventAttendeeStatus.Applied) {
              eventApplicants.add(attendee);
              allApplicantPrincipals.put(attendee.invitee_user_id, ());
            };
          };
          eventToApplicantsMap.put(eventId, eventApplicants);
        };
        case (#err(e)) {
          canistergeekLogger.logMessage("Error fetching applicants for " # eventId # ": " # debug_show (e));
        };
      };
    };

    // 4. Batch-fetch all unique applicant user data
    let applicantIdsArray = Iter.toArray(allApplicantPrincipals.keys());
    let applicantDataMap = HashMap.HashMap<Text, ArgumentTypes.UserResponsePayload>(0, Text.equal, Text.hash);
    if (applicantIdsArray.size() > 0) {
      let indexActor = actor (KonectaConstants.IndexCanister) : SharedService.IndexActor;
      let canisterMappings = await indexActor.getUserCanistersByPrincipal(applicantIdsArray);
      let userDetailFutures = Buffer.Buffer<async ArgumentTypes.UserResponsePayload>(canisterMappings.size());
      for (mapping in canisterMappings.vals()) {
        let userCanister = actor (mapping.canister_id) : SharedService.UserCanisterType;
        userDetailFutures.add(userCanister.getUserForEventCanister(mapping.principal_id));
      };
      for (future in userDetailFutures.vals()) {
        let userDetails = await future;
        if (Text.size(userDetails.principal_id) > 0) {
          applicantDataMap.put(userDetails.principal_id, userDetails);
        };
      };
    };

    // 5. Assemble the final, structured response
    let finalItems = Buffer.Buffer<ArgumentTypes.ApplicationStatusOfMyCreatedEvents>(myRequestsPage.items.size());
    for (event in myRequestsPage.items.vals()) {
      let applicantsDetailsBuffer = Buffer.Buffer<ArgumentTypes.ApplicantDetailsPayload>(0);
      switch (eventToApplicantsMap.get(event.event_id)) {
        case (?attendeeRecords) {
          for (attendeeRecord in attendeeRecords.vals()) {
            switch (applicantDataMap.get(attendeeRecord.invitee_user_id)) {
              case (?userData) {
                applicantsDetailsBuffer.add({
                  userData = userData;
                  applicationMetadata = attendeeRecord.metadata;
                  applicationStatus = attendeeRecord.action;
                  applicationTimestamp = attendeeRecord.timestamp;
                });
              };
              case (null) {};
            };
          };
        };
        case (null) {};
      };

      if (applicantsDetailsBuffer.size() > 0) {
        finalItems.add({
          event_id = event.event_id;
          event_name = event.name;
          event_description = event.description;
          applied_users_details = Buffer.toArray(applicantsDetailsBuffer);
        });
      };
    };

    return #ok({
      items = Buffer.toArray(finalItems);
      totalRecords = myRequestsPage.totalRecords;
      hasMore = myRequestsPage.hasMore;
      nextCursor = myRequestsPage.nextCursor;
    });
  };

  private func runJobs() : async () {
    canistergeekMonitor.collectMetrics();
    await RunJobsService.runJobs(alfangoDB, canistergeekLogger, transform);
  };

  ignore setTimer<system>(
    #nanoseconds(nextDateInNanoseconds - Int.abs(Time.now())),
    func() : async () {
      ignore recurringTimer<system>(#nanoseconds oneDayInNanoseconds, runJobs);
      await runJobs();
    },
  );

  system func preupgrade() {
    _canistergeekMonitorUD := ?canistergeekMonitor.preupgrade();
    _canistergeekLoggerUD := ?canistergeekLogger.preupgrade();
  };

  system func postupgrade() {
    canistergeekMonitor.postupgrade(_canistergeekMonitorUD);
    _canistergeekMonitorUD := null;

    canistergeekLogger.postupgrade(_canistergeekLoggerUD);
    _canistergeekLoggerUD := null;

    canistergeekLogger.setMaxMessagesCount(3000);
  };

  public query func getCanistergeekInformation(request : Canistergeek.GetInformationRequest) : async Canistergeek.GetInformationResponse {

    Canistergeek.getInformation(?canistergeekMonitor, ?canistergeekLogger, request);
  };

  public shared func updateCanistergeekInformation(request : Canistergeek.UpdateInformationRequest) : async () {

    canistergeekMonitor.updateInformation(request);
  };

  public shared (_msg) func updateOperation({
    updateOpsInput : Database.UpdateOpsInputType;
  }) : async Database.UpdateOpsOutputType {
    return await Database.updateOperation({
      updateOpsInput;
      alfangoDB = alfangoDB;
    });
  };

  public query (_msg) func queryOperation({
    queryOpsInput : Database.QueryOpsInputType;
  }) : async Database.QueryOpsOutputType {
    return Database.queryOperation({ queryOpsInput; alfangoDB = alfangoDB });
  };

  let whiteListedPrincipals = [
    "mmvkb-jfbwr-ijb53-cor5j-nyq6t-rhpjc-vqtg6-w6x3l-ls7uz-3lqxn-bae"
  ];

  public func isWhiteListUser(userId : Text) : async Bool {
    for (principal in whiteListedPrincipals.vals()) {
      if (principal == userId) {
        return true;
      };
    };
    return false;
  };

};
