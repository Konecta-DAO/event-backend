import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Canistergeek "mo:canistergeek/canistergeek";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Order "mo:base/Order";
import Nat "mo:base/Nat";
import EventCommonService "services/common";
import EventAddService "services/event/create";
import EventReadService "services/event/read";
import EventUpdateService "services/event/update";
import EventAttendeeAddService "services/eventAttendee/addAttendee";
import EventAttendeeUpdateService "services/eventAttendee/updateAttendee";
import EventAttendeeGetService "services/eventAttendee/getAttendee";
import EventSchemaService "services/schema";
import ArgumentTypes "types/argumentTypes";
import EventConstants "utils/constants";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Helper "./utils/helper";
import Constants "./utils/constants";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import OutputTypes "mo:alfangodb/AlfangoDB/types/output";

shared ({ caller = initializer }) actor class EventCanister() = this {

  stable var alfangoDB : Database.AlfangoDB = {
    databases = Map.new<Text, Database.Database>();
    STABLE_MEMORY_LIMIT = 3_221_225_472; // 3 GiB
    var totalStableBytes = 0;
  };

  stable let d3 = D3.D3();

  private let canistergeekMonitor = Canistergeek.Monitor();
  private let canistergeekLogger = Canistergeek.Logger();
  stable var _canistergeekMonitorUD : ?Canistergeek.UpgradeData = null;
  stable var _canistergeekLoggerUD : ?Canistergeek.LoggerUpgradeData = null;

  public composite query func getEventsWithUserData(
    events : [OutputTypes.ItemOutputType]
  ) : async [ArgumentTypes.EventWithUserDataPayload] {
    if (events.size() == 0) {
      return [];
    };

    // --- Step 1: Collect unique user IDs from the events ---
    let userIdMap = HashMap.HashMap<Text, ()>(events.size(), Text.equal, Text.hash);
    for (event in events.vals()) {
      let userId = Helper.getTupleValueAsText(event.item, "user_id");
      if (Text.size(userId) > 0) { userIdMap.put(userId, ()) };
    };
    let userIds = Buffer.toArray(Buffer.fromIter<Text>(userIdMap.keys()));

    // --- Step 2: Fetch all user data in batch (Inlined logic from getUsersDetails) ---
    let userDataMap = HashMap.HashMap<Text, ArgumentTypes.UserResponsePayload>(userIds.size(), Text.equal, Text.hash);

    if (userIds.size() > 0) {
      let indexActor = actor (Constants.IndexCanister) : EventCommonService.IndexActor;
      let canisterMappings = await indexActor.getUserCanistersByPrincipal(userIds);

      if (canisterMappings.size() > 0) {
        let userDetailFutures = Buffer.Buffer<async ArgumentTypes.UserResponsePayload>(canisterMappings.size());
        for (mapping in canisterMappings.vals()) {
          let userCanisterActor = actor (mapping.canister_id) : EventCommonService.UserCanisterType;
          userDetailFutures.add(userCanisterActor.getUserForEventCanister(mapping.principal_id));
        };

        for (future in userDetailFutures.vals()) {
          let userDetails = await future;
          if (Text.size(userDetails.principal_id) > 0) {
            userDataMap.put(userDetails.principal_id, userDetails);
          };
        };
      };
    };

    // --- Step 3: Combine event data with the fetched user data ---
    let resultBuffer = Buffer.Buffer<ArgumentTypes.EventWithUserDataPayload>(events.size());
    for (event in events.vals()) {
      let eventId = event.id;
      let eventItem = event.item;
      let itemMap = Helper.attributeArrayToHashMap(eventItem);
      let userId = Helper.getAttributeFromMapAsText(itemMap, "user_id");

      let userData = switch (userDataMap.get(userId)) {
        case (?u) u;
        case null EventCommonService.initialEventObjectWithUserData.userData;
      };

      let eventPayload = EventCommonService.transformItemToEventPayload(eventId, itemMap);
      resultBuffer.add({
        event_id = eventPayload.event_id;
        user_id = eventPayload.user_id;
        coverphoto = eventPayload.coverphoto;
        name = eventPayload.name;
        description = eventPayload.description;
        location = eventPayload.location;
        start_date = eventPayload.start_date;
        end_date = eventPayload.end_date;
        language = eventPayload.language;
        status = eventPayload.status;
        metadata = eventPayload.metadata;
        event_type = eventPayload.event_type;
        participation_type = eventPayload.participation_type;
        categories = eventPayload.categories;
        consultations = eventPayload.consultations;
        expertise = eventPayload.expertise;
        price_token = eventPayload.price_token;
        token_amount = eventPayload.token_amount;
        interests = eventPayload.interests;
        showcase_link = eventPayload.showcase_link;
        recording_visibility = eventPayload.recording_visibility;
        is_recording_available = eventPayload.is_recording_available;
        subaccount_id_hex = eventPayload.subaccount_id_hex;
        subaccount_id_index = eventPayload.subaccount_id_index;
        userData = userData;
      });
    };
    return Buffer.toArray(resultBuffer);
  };

  private func getEventsWithUserDataAsync(
    events : [OutputTypes.ItemOutputType]
  ) : async [ArgumentTypes.EventWithUserDataPayload] {
    if (events.size() == 0) {
      return [];
    };

    // --- Step 1: Collect unique user IDs from the events ---
    let userIdMap = HashMap.HashMap<Text, ()>(events.size(), Text.equal, Text.hash);
    for (event in events.vals()) {
      let userId = Helper.getTupleValueAsText(event.item, "user_id");
      if (Text.size(userId) > 0) { userIdMap.put(userId, ()) };
    };
    let userIds = Buffer.toArray(Buffer.fromIter<Text>(userIdMap.keys()));

    // --- Step 2: Fetch all user data in batch (Inlined logic from getUsersDetails) ---
    let userDataMap = HashMap.HashMap<Text, ArgumentTypes.UserResponsePayload>(userIds.size(), Text.equal, Text.hash);

    if (userIds.size() > 0) {
      let indexActor = actor (Constants.IndexCanister) : EventCommonService.IndexActor;
      let canisterMappings = await indexActor.getUserCanistersByPrincipal(userIds);

      if (canisterMappings.size() > 0) {
        let userDetailFutures = Buffer.Buffer<async ArgumentTypes.UserResponsePayload>(canisterMappings.size());
        for (mapping in canisterMappings.vals()) {
          let userCanisterActor = actor (mapping.canister_id) : EventCommonService.UserCanisterType;
          userDetailFutures.add(userCanisterActor.getUserForEventCanister(mapping.principal_id));
        };

        for (future in userDetailFutures.vals()) {
          let userDetails = await future;
          if (Text.size(userDetails.principal_id) > 0) {
            userDataMap.put(userDetails.principal_id, userDetails);
          };
        };
      };
    };

    // --- Step 3: Combine event data with the fetched user data ---
    let resultBuffer = Buffer.Buffer<ArgumentTypes.EventWithUserDataPayload>(events.size());
    for (event in events.vals()) {
      let eventId = event.id;
      let eventItem = event.item;
      let itemMap = Helper.attributeArrayToHashMap(eventItem);
      let userId = Helper.getAttributeFromMapAsText(itemMap, "user_id");

      let userData = switch (userDataMap.get(userId)) {
        case (?u) u;
        case null EventCommonService.initialEventObjectWithUserData.userData;
      };

      let eventPayload = EventCommonService.transformItemToEventPayload(eventId, itemMap);
      resultBuffer.add({
        event_id = eventPayload.event_id;
        user_id = eventPayload.user_id;
        coverphoto = eventPayload.coverphoto;
        name = eventPayload.name;
        description = eventPayload.description;
        location = eventPayload.location;
        start_date = eventPayload.start_date;
        end_date = eventPayload.end_date;
        language = eventPayload.language;
        status = eventPayload.status;
        metadata = eventPayload.metadata;
        event_type = eventPayload.event_type;
        participation_type = eventPayload.participation_type;
        categories = eventPayload.categories;
        consultations = eventPayload.consultations;
        expertise = eventPayload.expertise;
        price_token = eventPayload.price_token;
        token_amount = eventPayload.token_amount;
        interests = eventPayload.interests;
        showcase_link = eventPayload.showcase_link;
        recording_visibility = eventPayload.recording_visibility;
        is_recording_available = eventPayload.is_recording_available;
        subaccount_id_hex = eventPayload.subaccount_id_hex;
        subaccount_id_index = eventPayload.subaccount_id_index;
        userData = userData;
      });
    };
    return Buffer.toArray(resultBuffer);
  };

  public composite query func getMyPaginatedProposals(
    userPrincipal : Principal,
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
  ) : async Result.Result<ArgumentTypes.PaginatedProposalsResponse, [Text]> {

    // 1. Get paginated "Applied" records using the new efficient service
    let proposalRecordsResult = EventAttendeeGetService.getPaginatedAttendeeRecordsForUserByAction(
      userPrincipal,
      #Applied,
      limit,
      cursor,
      alfangoDB,
    );

    let proposalRecords = switch (proposalRecordsResult) {
      case (#ok(res)) res;
      case (#err(e)) return #err(e);
    };

    if (proposalRecords.items.size() == 0) {
      return #ok({
        items = [];
        totalRecords = proposalRecords.totalRecords;
        hasMore = false;
        nextCursor = null;
      });
    };

    // 2. Extract Event IDs from the current page of proposals
    let eventIds = Array.map(
      proposalRecords.items,
      func(p : ArgumentTypes.EventAttendeeResponsePayload) : Text {
        p.event_id;
      },
    );

    // 3. Batch fetch Event Data
    let eventDataTuples = await getEventArrayFromEventIdArray(eventIds);
    let eventDataMap = HashMap.fromIter<Text, ArgumentTypes.EventWithUserDataPayload>(
      Iter.fromArray(eventDataTuples),
      eventDataTuples.size(),
      Text.equal,
      Text.hash,
    );

    // 4. Combine into the final response payload for this page
    let finalItems = Buffer.Buffer<ArgumentTypes.ProposalResponsePayload>(proposalRecords.items.size());
    for (proposal in proposalRecords.items.vals()) {
      switch (eventDataMap.get(proposal.event_id)) {
        case (?eventData) {
          finalItems.add({
            eventData = eventData;
            proposalMetadata = proposal.metadata;
          });
        };
        case (null) {};
      };
    };

    return #ok({
      items = Buffer.toArray(finalItems);
      totalRecords = proposalRecords.totalRecords;
      hasMore = proposalRecords.hasMore;
      nextCursor = proposalRecords.nextCursor;
    });
  };

  public shared query func getAllAttendeesIds(eventId : Text) : async Result.Result<[ArgumentTypes.EventAttendeeResponsePayload], [Text]> {
    canistergeekMonitor.collectMetrics();
    EventAttendeeGetService.getAllAttendeesIds(eventId, alfangoDB);
  };

  public composite query func getFilteredEvents(
    payload : {
      currentTimestamp : Nat;
      isFuture : Bool;
      eventType : ?Text;
      status : ?Text;
      userId : ?Principal;
      categories : ?[Text];
      recordingType : ?[Bool];
      limit : Nat;
      offset : Nat;
    }
  ) : async Result.Result<{ items : [ArgumentTypes.EventWithUserDataPayload]; totalRecords : Nat }, [Text]> {
    var filterExpressions = Buffer.Buffer<SearchTypes.FilterExpressionType>(5);

    if (payload.isFuture) {
      filterExpressions.add({
        attributeNames = "start_date";
        filterExpressionCondition = #GTE(#nat(payload.currentTimestamp));
      });
    } else {
      filterExpressions.add({
        attributeNames = "start_date";
        filterExpressionCondition = #LT(#nat(payload.currentTimestamp));
      });
    };

    switch (payload.eventType) {
      case (?et) {
        filterExpressions.add({
          attributeNames = "event_type";
          filterExpressionCondition = #EQ(#text(et));
        });
      };
      case null {};
    };
    switch (payload.status) {
      case (?s) {
        filterExpressions.add({
          attributeNames = "status";
          filterExpressionCondition = #EQ(#text(s));
        });
      };
      case null {};
    };
    switch (payload.userId) {
      case (?uid) {
        filterExpressions.add({
          attributeNames = "user_id";
          filterExpressionCondition = #EQ(#principal(uid));
        });
      };
      case null {};
    };
    switch (payload.categories) {
      case (?cats) {
        if (cats.size() > 0) {
          filterExpressions.add({
            attributeNames = "categories";
            filterExpressionCondition = #IN(Helper.getStringAttributeDataValueArray(cats));
          });
        };
      };
      case null {};
    };
    switch (payload.recordingType) {
      case (?rec) {
        if (rec.size() > 0) {
          filterExpressions.add({
            attributeNames = "is_recording_available";
            filterExpressionCondition = #IN(Helper.getBoolAttributeDataValueArray(rec));
          });
        };
      };
      case null {};
    };

    let queryFilters = Array.map<SearchTypes.FilterExpressionType, SearchTypes.QueryFilter>(
      Buffer.toArray(filterExpressions),
      func(e) { #expression(e) },
    );
    let filter : SearchTypes.QueryFilter = #AND(queryFilters);

    let allItemsResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (allItemsResponse) {
      case (#err(e)) { return #err(e) };
      case (#ok(allItems)) {
        let compareEvents = func(a : OutputTypes.ItemOutputType, b : OutputTypes.ItemOutputType) : Order.Order {
          let dateA = switch (Nat.fromText(Helper.getTupleValueAsText(a.item, "start_date"))) {
            case (?n) n;
            case (null) 0;
          };
          let dateB = switch (Nat.fromText(Helper.getTupleValueAsText(b.item, "start_date"))) {
            case (?n) n;
            case (null) 0;
          };
          let order = Nat.compare(dateA, dateB);
          if (payload.isFuture) { return order } else {
            return if (order == #less) #greater else if (order == #greater) #less else #equal;
          };
        };
        let sortedItems = Array.sort<OutputTypes.ItemOutputType>(allItems, compareEvents);

        let end = Nat.min(payload.offset + payload.limit, sortedItems.size());
        let paginatedItems : [OutputTypes.ItemOutputType] = if (payload.offset >= sortedItems.size()) {
          [];
        } else {
          Iter.toArray(Array.slice<OutputTypes.ItemOutputType>(sortedItems, payload.offset, end));
        };

        let enrichedItems = await getEventsWithUserData(paginatedItems);

        return #ok({
          items = enrichedItems;
          totalRecords = sortedItems.size();
        });
      };
    };
  };

  public func generateSchema() : async Text {

    let _schemaResponse = EventSchemaService.generateEventSchema(alfangoDB, canistergeekLogger);
    return "Schema created successfully";
  };

  public query func get_trusted_origins() : async [Text] {
    return EventConstants.whiteListedCanisters;
  };

  public shared query func icrc28_trusted_origins() : async {
    trusted_origins : [Text];
  } {
    let trusted_origins = EventConstants.whiteListedCanisters;
    return { trusted_origins };
  };

  public shared (msg) func createEvent(userCanisterId : Text, payload : ArgumentTypes.EventRequestPayload) : async Text {
    canistergeekMonitor.collectMetrics();
    await EventAddService.createEvent(msg.caller, userCanisterId, payload, alfangoDB, d3, canistergeekLogger);
  };

  public shared func cancelEvent(userPrincipal : Principal, eventId : Text, eventType : Text) : async Result.Result<[Text], Text> {
    canistergeekMonitor.collectMetrics();
    await EventUpdateService.cancelEvent(userPrincipal, eventId, eventType, alfangoDB, canistergeekLogger);
  };

  public shared func addEventAttendee(payload : ArgumentTypes.EventAttendeeRequestPayload) : async Result.Result<Text, Text> {
    await EventAttendeeAddService.addEventAttendee(payload, alfangoDB, canistergeekLogger);
  };

  public shared func updateEventAttendeeStatus(
    eventId : Text,
    inviteeUserId : Principal,
    currentAction : ArgumentTypes.EventAttendeeActions,
    newAction : ArgumentTypes.EventAttendeeActions,
  ) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await EventAttendeeUpdateService.updateEventAttendeeStatus(
      eventId,
      inviteeUserId,
      currentAction,
      newAction,
      alfangoDB,
    );
  };

  public shared func withdrawEventAttendee(payload : ArgumentTypes.WithdrawAttendeeRequestPayload) : async Result.Result<ArgumentTypes.EventWithUserDataPayload, Text> {
    await EventAttendeeAddService.withdrawEventAttendee(
      payload,
      alfangoDB,
      canistergeekLogger,
    );
  };

  public shared query func checkIfAttendeeOrAcceptedUserExistsForEvent(userPrincipal : Principal, eventId : Text) : async Bool {
    EventAttendeeGetService.checkIfAttendeeOrAcceptedUserExistsForEvent(userPrincipal, eventId, alfangoDB);
  };

  public shared query func getAttendeeStatusForEvent(userPrincipal : Principal, eventId : Text) : async Text {
    EventAttendeeGetService.getAttendeeStatusForEvent(userPrincipal, eventId, alfangoDB);
  };

  public func getCompletedEventsForCron(
    startTime : Nat,
    endTime : Nat,
  ) : async Result.Result<[ArgumentTypes.EventWithUserDataPayload], [Text]> {
    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "end_date";
        filterExpressionCondition = #BETWEEN((#nat(startTime), #nat(endTime)));
      }),
      #expression({
        attributeNames = "status";
        filterExpressionCondition = #EQ(#text(Constants.EventStatus.Created));
      }),
    ]);

    let scanResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (scanResponse) {
      case (#err(e)) {
        return #err(e);
      };
      case (#ok(items)) {
        let enrichedItems = await getEventsWithUserDataAsync(items);
        return #ok(enrichedItems);
      };
    };
  };

  public composite query func getAttendeesByActionWithUserDetails(eventId : Text, action : ArgumentTypes.EventAttendeeActions) : async Result.Result<[ArgumentTypes.UserResponsePayload], [Text]> {
    canistergeekMonitor.collectMetrics();

    let response = EventAttendeeGetService.getAttendeesIdsByAction(eventId, action, alfangoDB);

    switch (response) {
      case (#ok(userIds)) {
        if (Array.size(userIds) == 0) {
          return #ok([]);
        };

        let indexActor = actor (EventConstants.IndexCanister) : EventCommonService.IndexActor;
        let canisterMappings = await indexActor.getUserCanistersByPrincipal(userIds);

        // DISPATCH: Start all async calls concurrently.
        let futures = Buffer.Buffer<async ArgumentTypes.UserResponsePayload>(canisterMappings.size());
        for (mapping in canisterMappings.vals()) {
          let userCanisterActor = actor (mapping.canister_id) : EventCommonService.UserCanisterType;
          futures.add(userCanisterActor.getUserForEventCanister(mapping.principal_id));
        };

        // COLLECT: Await the results.
        let results = Buffer.Buffer<ArgumentTypes.UserResponsePayload>(futures.size());
        for (future in futures.vals()) {
          results.add(await future);
        };

        return #ok(Buffer.toArray(results));
      };
      case (#err(err)) {
        return #err(err);
      };
    };
  };

  public func getAttendeesByActionWithUserDetailsAsync(eventId : Text, action : ArgumentTypes.EventAttendeeActions) : async Result.Result<[ArgumentTypes.UserResponsePayload], [Text]> {
    canistergeekMonitor.collectMetrics();

    let response = EventAttendeeGetService.getAttendeesIdsByAction(eventId, action, alfangoDB);

    switch (response) {
      case (#ok(userIds)) {
        if (Array.size(userIds) == 0) {
          return #ok([]);
        };

        let indexActor = actor (EventConstants.IndexCanister) : EventCommonService.IndexActor;
        let canisterMappings = await indexActor.getUserCanistersByPrincipal(userIds);

        // DISPATCH: Start all async calls concurrently.
        let futures = Buffer.Buffer<async ArgumentTypes.UserResponsePayload>(canisterMappings.size());
        for (mapping in canisterMappings.vals()) {
          let userCanisterActor = actor (mapping.canister_id) : EventCommonService.UserCanisterType;
          futures.add(userCanisterActor.getUserForEventCanister(mapping.principal_id));
        };

        // COLLECT: Await the results.
        let results = Buffer.Buffer<ArgumentTypes.UserResponsePayload>(futures.size());
        for (future in futures.vals()) {
          results.add(await future);
        };

        return #ok(Buffer.toArray(results));
      };
      case (#err(err)) {
        return #err(err);
      };
    };
  };

  public composite query func getAppliedUsersWithData(eventId : Text) : async Result.Result<[ArgumentTypes.UserResponsePayload], [Text]> {
    await getAttendeesByActionWithUserDetails(eventId, #Applied);
  };

  public composite query func getPaginatedEventsForAttendee(
    userPrincipal : Text,
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
  ) : async Result.Result<ArgumentTypes.PaginatedEventWithUserDataPayload, [Text]> {
    canistergeekMonitor.collectMetrics();

    // 1. Get the paginated list of event IDs the user has joined.
    let eventsResponse = EventAttendeeGetService.getPaginatedEventsForAttendee(
      Principal.fromText(userPrincipal),
      limit,
      cursor,
      alfangoDB,
      canistergeekLogger,
    );

    switch (eventsResponse) {
      case (#err(error)) {
        return #err(error);
      };
      case (#ok(paginatedIds)) {
        if (paginatedIds.ids.size() == 0) {
          // If there are no events on this page, return an empty result.
          return #ok({
            items = [];
            totalRecords = paginatedIds.totalRecords;
            hasMore = paginatedIds.hasMore;
            nextCursor = paginatedIds.nextCursor;
          });
        };

        // 2. Fetch the full event data for the retrieved IDs.
        let eventItems = EventReadService.getBatchEventsByCompositeQuery(
          paginatedIds.ids,
          alfangoDB,
          canistergeekLogger,
        );

        let rawEventsResponse = Database.batchGetItemById({
          batchGetItemByIdInput = {
            databaseName = Constants.KonectA;
            tableName = Constants.EventTable;
            ids = paginatedIds.ids;
          };
          alfangoDB = alfangoDB;
        });

        let rawEventItems = switch (rawEventsResponse) {
          case (#ok(res)) res.items;
          case (#err(_)) [];
        };

        // 3. Rnrich the raw event items with user data.
        let enrichedItems = await getEventsWithUserData(rawEventItems);

        // 4. Return the final, structured paginated result.
        return #ok({
          items = enrichedItems;
          totalRecords = paginatedIds.totalRecords;
          hasMore = paginatedIds.hasMore;
          nextCursor = paginatedIds.nextCursor;
        });
      };
    };
  };

  public shared query func getEventsForAttendeeWithEventData(userPrincipal : Text) : async Result.Result<[ArgumentTypes.EventResponsePayload], [Text]> {
    EventAttendeeGetService.getEventsForAttendeeWithEventData(Principal.fromText(userPrincipal), alfangoDB);
  };

  public query func getEventTableMetadata() : async Database.GetTableMetadataOutputType {
    EventReadService.eventTableMetadata(alfangoDB);
  };

  public composite query func getEventArrayFromEventIdArray(eventIdArray : [Text]) : async ArgumentTypes.EventWithUserDataTupleArray {
    if (Array.size(eventIdArray) == 0) {
      return [];
    };

    // Step 1 & 2: Batch-fetch events and collect unique user IDs.
    let eventsResponse = EventReadService.getBatchEventsByCompositeQuery(eventIdArray, alfangoDB, canistergeekLogger);
    if (Array.size(eventsResponse) == 0) { return [] };

    let userIdMap = HashMap.HashMap<Text, ()>(eventsResponse.size(), Text.equal, Text.hash);
    for (event in eventsResponse.vals()) {
      userIdMap.put(event.user_id, ());
    };
    let userIds = Buffer.toArray(Buffer.fromIter<Text>(userIdMap.keys()));
    if (Array.size(userIds) == 0) {
      let resultBuffer = Buffer.Buffer<(Text, ArgumentTypes.EventWithUserDataPayload)>(eventsResponse.size());
      for (eventData in eventsResponse.vals()) {
        let userData = EventCommonService.initialEventObjectWithUserData.userData;
        resultBuffer.add((eventData.event_id, EventCommonService.createEventWithUserDataObjectFromResponse(eventData, userData)));
      };
      return Buffer.toArray(resultBuffer);
    };

    // Step 3: Batch-fetch all user canister mappings in a SINGLE call.
    let indexActor = actor (EventConstants.IndexCanister) : EventCommonService.IndexActor;
    let canisterMappings = await indexActor.getUserCanistersByPrincipal(userIds);

    // Step 4: Fetch all user data concurrently using the "dispatch-collect" pattern.
    let userDataMap = HashMap.HashMap<Text, ArgumentTypes.UserResponsePayload>(canisterMappings.size(), Text.equal, Text.hash);

    // Step 4a: DISPATCH all async calls. Store the pending futures in a buffer.
    let userDetailFutures = Buffer.Buffer<async ArgumentTypes.UserResponsePayload>(canisterMappings.size());
    for (mapping in canisterMappings.vals()) {
      let userCanisterActor = actor (mapping.canister_id) : EventCommonService.UserCanisterType;
      userDetailFutures.add(userCanisterActor.getUserForEventCanister(mapping.principal_id));
    };

    // Step 4b: COLLECT the results.
    for (future in userDetailFutures.vals()) {
      let userDetails = await future;
      if (Text.size(userDetails.principal_id) > 0) {
        userDataMap.put(userDetails.principal_id, userDetails);
      };
    };

    // Step 5: Assemble the final result locally. (This is very fast).
    let resultBuffer = Buffer.Buffer<(Text, ArgumentTypes.EventWithUserDataPayload)>(eventsResponse.size());
    for (eventData in eventsResponse.vals()) {
      let userData = switch (userDataMap.get(eventData.user_id)) {
        case (?user) user;
        case null EventCommonService.initialEventObjectWithUserData.userData;
      };
      resultBuffer.add((eventData.event_id, EventCommonService.createEventWithUserDataObjectFromResponse(eventData, userData)));
    };

    return Buffer.toArray(resultBuffer);
  };

  public shared (msg) func updateEvent(userCanisterId : Text, eventId : Text, payload : ArgumentTypes.EventRequestPayload) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await EventUpdateService.updateEvent(msg.caller, userCanisterId, eventId, payload, alfangoDB, d3, canistergeekLogger);
  };

  public query func getFile(fileId : Text) : async D3.GetFileOutputType {
    EventReadService.getFile(fileId, d3);
  };

  public query func http_request(httpRequest : D3.HttpRequest) : async D3.HttpResponse {
    D3.getFileHTTP({ d3; httpRequest; httpStreamingCallbackActor = this });
  };

  public query func http_request_streaming_callback(streamingCallbackToken : D3.StreamingCallbackToken) : async D3.StreamingCallbackHttpResponse {
    D3.httpStreamingCallback({ d3; streamingCallbackToken });
  };

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
    canistergeekLogger.logMessage("postupgrade");
  };

  public query func getCanistergeekInformation(request : Canistergeek.GetInformationRequest) : async Canistergeek.GetInformationResponse {
    Canistergeek.getInformation(?canistergeekMonitor, ?canistergeekLogger, request);
  };

  public shared func updateCanistergeekInformation(request : Canistergeek.UpdateInformationRequest) : async () {
    canistergeekMonitor.updateInformation(request);
  };

  public composite query func fetchUserData(userId : Text, canisterId : Text) : async ArgumentTypes.UserResponsePayload {
    let userCanisterActor = actor (canisterId) : EventCommonService.UserCanisterType;
    await userCanisterActor.getUserForEventCanister(userId);
  };

  public composite query func getServiceRequestsForUser(userPrincipal : Principal) : async Result.Result<[ArgumentTypes.EventWithUserDataPayload], [Text]> {
    let filterExpressions : [SearchTypes.FilterExpressionType] = [
      {
        attributeNames = "user_id";
        filterExpressionCondition = #EQ(#principal(userPrincipal));
      },
      {
        attributeNames = "event_type";
        filterExpressionCondition = #EQ(#text(Constants.EventType.Request));
      },
      {
        attributeNames = "status";
        filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
      },
    ];
    let queryFilters = Array.map<SearchTypes.FilterExpressionType, SearchTypes.QueryFilter>(filterExpressions, func(expr) { #expression(expr) });
    let filter : SearchTypes.QueryFilter = #AND(queryFilters);

    let eventResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (eventResponse) {
      case (#err(e)) { return #err(e) };
      case (#ok(eventItems)) {
        if (eventItems.size() == 0) { return #ok([]) };

        // Step 1: Get all canister mappings
        let userIdMap = HashMap.HashMap<Text, ()>(eventItems.size(), Text.equal, Text.hash);
        for (itemObject in eventItems.vals()) {
          let userId = Helper.getTupleValueAsText(itemObject.item, "user_id");
          if (Text.size(userId) > 0) { userIdMap.put(userId, ()) };
        };
        let userIds = Buffer.toArray(Buffer.fromIter<Text>(userIdMap.keys()));

        let canisterMappingMap = HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);
        if (userIds.size() > 0) {
          let indexActor = actor (Constants.IndexCanister) : EventCommonService.IndexActor;
          let canisterMappings = await indexActor.getUserCanistersByPrincipal(userIds);
          for (mapping in canisterMappings.vals()) {
            canisterMappingMap.put(mapping.principal_id, mapping.canister_id);
          };
        };

        // Step 2: Create futures ONLY for users with a found canister
        let userDetailFutures = Buffer.Buffer<async ArgumentTypes.UserResponsePayload>(0);
        let userIdsWithCanisters = Buffer.Buffer<Text>(0);

        for (userId in userIds.vals()) {
          switch (canisterMappingMap.get(userId)) {
            case (?canisterId) {
              userIdsWithCanisters.add(userId);
              userDetailFutures.add(fetchUserData(userId, canisterId));
            };
            case (null) { /* Skip, will use default later */ };
          };
        };

        // Step 3: Await the real futures and build the results map
        let userDetailsMap = HashMap.HashMap<Text, ArgumentTypes.UserResponsePayload>(0, Text.equal, Text.hash);
        let userIdsWithCanistersArray = Buffer.toArray(userIdsWithCanisters);
        for (i in userIdsWithCanistersArray.keys()) {
          let userId = userIdsWithCanistersArray[i];
          let userData = await userDetailFutures.get(i);
          if (Text.size(userData.principal_id) > 0) {
            userDetailsMap.put(userId, userData);
          };
        };

        // Step 4: Assemble the final result, using the default for users not in the map
        let resultBuffer = Buffer.Buffer<ArgumentTypes.EventWithUserDataPayload>(eventItems.size());
        for (itemObject in eventItems.vals()) {
          let eventId = itemObject.id;
          let eventItem = itemObject.item;
          let itemMap = Helper.attributeArrayToHashMap(eventItem);
          let userId = Helper.getAttributeFromMapAsText(itemMap, "user_id");
          let userData = switch (userDetailsMap.get(userId)) {
            case (?u) u;
            case null EventCommonService.initialEventObjectWithUserData.userData;
          };

          resultBuffer.add({
            event_id = eventId;
            user_id = userId;
            userData = userData;
            coverphoto = Helper.getAttributeFromMapAsText(itemMap, "coverphoto");
            name = Helper.getAttributeFromMapAsText(itemMap, "name");
            description = Helper.getAttributeFromMapAsText(itemMap, "description");
            location = Helper.getAttributeFromMapAsText(itemMap, "location");
            start_date = Helper.textToNat(Helper.getAttributeFromMapAsText(itemMap, "start_date"));
            end_date = Helper.textToNat(Helper.getAttributeFromMapAsText(itemMap, "end_date"));
            language = Helper.getAttributeFromMapAsText(itemMap, "language");
            status = Helper.getAttributeFromMapAsText(itemMap, "status");
            metadata = Helper.getTupleArrayFromAttributeDataValueArray(itemMap.get("metadata"));
            event_type = Helper.getAttributeFromMapAsText(itemMap, "event_type");
            participation_type = Helper.getAttributeFromMapAsText(itemMap, "participation_type");
            categories = switch (itemMap.get("categories")) {
              case (null) [];
              case (?attrValue) Helper.getTextArrayFromAttributeDataValueArray(attrValue);
            };
            consultations = switch (itemMap.get("consultations")) {
              case (null) [];
              case (?attrValue) Helper.getTextArrayFromAttributeDataValueArray(attrValue);
            };
            expertise = Helper.getAttributeFromMapAsText(itemMap, "expertise");
            price_token = Helper.getAttributeFromMapAsText(itemMap, "price_token");
            token_amount = switch (Helper.textToFloat(Helper.getAttributeFromMapAsText(itemMap, "token_amount"))) {
              case (#ok(f)) f;
              case (#err(_)) 0.0;
            };
            interests = switch (itemMap.get("interests")) {
              case (null) [];
              case (?attrValue) Helper.getTextArrayFromAttributeDataValueArray(attrValue);
            };
            showcase_link = Helper.getAttributeFromMapAsText(itemMap, "showcase_link");
            recording_visibility = Helper.getAttributeFromMapAsText(itemMap, "recording_visibility");
            is_recording_available = Helper.getAttributeFromMapAsText(itemMap, "is_recording_available") == "true";
            subaccount_id_hex = Helper.getAttributeFromMapAsText(itemMap, "subaccount_id_hex");
            subaccount_id_index = Helper.textToNat(Helper.getAttributeFromMapAsText(itemMap, "subaccount_id_index"));
          });
        };
        return #ok(Buffer.toArray(resultBuffer));
      };
    };
  };

  public composite query func getMyProposals(userPrincipal : Principal) : async Result.Result<[ArgumentTypes.EventWithUserDataPayload], [Text]> {
    // 1. Use our helper to get the IDs of events the user has applied to
    let appliedEventIdsResult = EventAttendeeGetService.getAttendeeRecordsForUserByAction(
      userPrincipal,
      #Applied,
      alfangoDB,
    );

    let eventIds = switch (appliedEventIdsResult) {
      case (#ok(ids)) ids;
      case (#err(e)) return #err(e);
    };

    if (eventIds.size() == 0) {
      return #ok([]);
    };

    // 2. Fetch the basic event data for these IDs.
    let eventItems = EventReadService.getBatchEventsByCompositeQuery(eventIds, alfangoDB, canistergeekLogger);

    if (eventItems.size() == 0) {
      return #ok([]);
    };

    // 3. Collect all unique creator user IDs from the fetched events.
    let creatorIdMap = HashMap.HashMap<Text, ()>(eventItems.size(), Text.equal, Text.hash);
    for (event in eventItems.vals()) {
      if (Text.size(event.user_id) > 0) {
        creatorIdMap.put(event.user_id, ());
      };
    };
    let creatorIds = Buffer.toArray(Buffer.fromIter<Text>(creatorIdMap.keys()));

    // 4. Batch-fetch all user data for the creators.
    let userDataMap = HashMap.HashMap<Text, ArgumentTypes.UserResponsePayload>(creatorIds.size(), Text.equal, Text.hash);
    if (creatorIds.size() > 0) {
      let indexActor = actor (Constants.IndexCanister) : EventCommonService.IndexActor;
      let canisterMappings = await indexActor.getUserCanistersByPrincipal(creatorIds);

      if (canisterMappings.size() > 0) {
        let userDetailFutures = Buffer.Buffer<async ArgumentTypes.UserResponsePayload>(canisterMappings.size());
        for (mapping in canisterMappings.vals()) {
          let userCanisterActor = actor (mapping.canister_id) : EventCommonService.UserCanisterType;
          userDetailFutures.add(userCanisterActor.getUserForEventCanister(mapping.principal_id));
        };

        for (future in userDetailFutures.vals()) {
          let userDetails = await future;
          if (Text.size(userDetails.principal_id) > 0) {
            userDataMap.put(userDetails.principal_id, userDetails);
          };
        };
      };
    };

    // 5. Assemble the final, fully enriched result.
    let finalResultBuffer = Buffer.Buffer<ArgumentTypes.EventWithUserDataPayload>(eventItems.size());
    for (event in eventItems.vals()) {
      let creatorUserData = switch (userDataMap.get(event.user_id)) {
        case (?u) u;
        case null EventCommonService.initialEventObjectWithUserData.userData;
      };

      finalResultBuffer.add({
        event_id = event.event_id;
        user_id = event.user_id;
        coverphoto = event.coverphoto;
        name = event.name;
        description = event.description;
        location = event.location;
        start_date = event.start_date;
        end_date = event.end_date;
        language = event.language;
        status = event.status;
        metadata = event.metadata;
        event_type = event.event_type;
        participation_type = event.participation_type;
        categories = event.categories;
        consultations = event.consultations;
        expertise = event.expertise;
        price_token = event.price_token;
        token_amount = event.token_amount;
        interests = event.interests;
        showcase_link = event.showcase_link;
        recording_visibility = event.recording_visibility;
        is_recording_available = event.is_recording_available;
        subaccount_id_hex = event.subaccount_id_hex;
        subaccount_id_index = event.subaccount_id_index;
        userData = creatorUserData;
      });
    };

    return #ok(Buffer.toArray(finalResultBuffer));
  };

  public composite query func getEventDetailsWithUserData(
    eventId : Text
  ) : async ArgumentTypes.EventWithUserDataPayload {
    canistergeekMonitor.collectMetrics();

    // 1. Fetch the raw event data from the local DB
    let eventResponse = EventReadService.eventDataById(eventId, alfangoDB);

    switch (eventResponse) {
      case (#err(_e)) {
        return EventCommonService.initialEventObjectWithUserData;
      };
      case (#ok(eventPayload)) {
        // 2. Fetch the user's canister ID from the Index canister
        let indexActor = actor (Constants.IndexCanister) : EventCommonService.IndexActor;
        let userCanisterId = await indexActor.getUserCanisterByUserPrincipal(eventPayload.user_id);

        var userData = EventCommonService.initialEventObjectWithUserData.userData;

        if (Text.size(userCanisterId) > 0) {
          // 3. Fetch the user's profile data from their User canister
          let userCanisterActor = actor (userCanisterId) : EventCommonService.UserCanisterType;
          userData := await userCanisterActor.getUserForEventCanister(eventPayload.user_id);
        };

        // 4. Combine the event data and user data into the final payload
        return EventCommonService.createEventWithUserDataObjectFromResponse(eventPayload, userData);
      };
    };
  };

  public func getEventDetailsWithUserDataAsync(
    eventId : Text
  ) : async ArgumentTypes.EventWithUserDataPayload {
    canistergeekMonitor.collectMetrics();

    // 1. Fetch the raw event data from the local DB
    let eventResponse = EventReadService.eventDataById(eventId, alfangoDB);

    switch (eventResponse) {
      case (#err(_e)) {
        // If event not found, return an empty/initial object
        return EventCommonService.initialEventObjectWithUserData;
      };
      case (#ok(eventPayload)) {
        // 2. Fetch the user's canister ID from the Index canister
        let indexActor = actor (Constants.IndexCanister) : EventCommonService.IndexActor;
        let userCanisterId = await indexActor.getUserCanisterByUserPrincipal(eventPayload.user_id);

        var userData = EventCommonService.initialEventObjectWithUserData.userData;

        if (Text.size(userCanisterId) > 0) {
          // 3. Fetch the user's profile data from their User canister
          let userCanisterActor = actor (userCanisterId) : EventCommonService.UserCanisterType;
          userData := await userCanisterActor.getUserForEventCanister(eventPayload.user_id);
        };

        // 4. Combine the event data and user data into the final payload
        return EventCommonService.createEventWithUserDataObjectFromResponse(eventPayload, userData);
      };
    };
  };

  public composite query func getPaginatedFilteredEvents(
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
  ) : async Result.Result<ArgumentTypes.PaginatedEventWithUserDataPayload, [Text]> {
    canistergeekMonitor.collectMetrics();

    // --- 1. Build Filter Expressions (same as your old function) ---
    var filterExpressions = Buffer.Buffer<SearchTypes.FilterExpressionType>(5);

    if (payload.isFuture) {
      filterExpressions.add({
        attributeNames = "start_date";
        filterExpressionCondition = #GTE(#nat(payload.currentTimestamp));
      });
    } else {
      filterExpressions.add({
        attributeNames = "start_date";
        filterExpressionCondition = #LT(#nat(payload.currentTimestamp));
      });
    };
    switch (payload.eventType) {
      case (?et) {
        filterExpressions.add({
          attributeNames = "event_type";
          filterExpressionCondition = #EQ(#text(et));
        });
      };
      case null {};
    };
    switch (payload.status) {
      case (?s) {
        filterExpressions.add({
          attributeNames = "status";
          filterExpressionCondition = #EQ(#text(s));
        });
      };
      case null {};
    };
    switch (payload.userId) {
      case (?uid) {
        filterExpressions.add({
          attributeNames = "user_id";
          filterExpressionCondition = #EQ(#principal(uid));
        });
      };
      case null {};
    };
    switch (payload.categories) {
      case (?cats) {
        if (cats.size() > 0) {
          filterExpressions.add({
            attributeNames = "categories";
            filterExpressionCondition = #IN(Helper.getStringAttributeDataValueArray(cats));
          });
        };
      };
      case null {};
    };
    switch (payload.recordingType) {
      case (?rec) {
        if (rec.size() > 0) {
          filterExpressions.add({
            attributeNames = "is_recording_available";
            filterExpressionCondition = #IN(Helper.getBoolAttributeDataValueArray(rec));
          });
        };
      };
      case null {};
    };

    let filterExpressionsArray = Buffer.toArray(filterExpressions);
    let queryFilters = Array.map<SearchTypes.FilterExpressionType, SearchTypes.QueryFilter>(
      filterExpressionsArray,
      func(e) { #expression(e) },
    );
    let filter : SearchTypes.QueryFilter = #AND(queryFilters);

    // --- 2. Get Total Record Count (only for the first page) ---
    let totalRecords = if (payload.cursor == null) {
      // This is a cheaper query to get just the count of matching items.
      EventCommonService.getTotalRecords(Constants.EventTable, filterExpressionsArray, alfangoDB);
    } else {
      0; // Don't recalculate for subsequent pages. The frontend should persist this.
    };

    // --- 3. Fetch the Page from the Database (The Scalable Part) ---
    let pageResponse = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
        filter = filter;
        limit = payload.limit;
        cursor = payload.cursor;
      };
      alfangoDB = alfangoDB;
    });

    switch (pageResponse) {
      case (#err(e)) { return #err(e) };
      case (#ok(page)) {
        // --- 4. Enrich the Page with User Data ---
        let enrichedItems = await getEventsWithUserData(page.items);

        // --- 5. Return the Structured Paginated Response ---
        return #ok({
          items = enrichedItems;
          totalRecords = totalRecords;
          hasMore = page.hasMore;
          nextCursor = page.nextCursor;
        });
      };
    };
  };

  public shared func getPaginatedFilteredEventsNoComposite(
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
  ) : async Result.Result<ArgumentTypes.PaginatedEventWithUserDataPayload, [Text]> {
    canistergeekMonitor.collectMetrics();

    // --- 1. Build Filter Expressions (same as your old function) ---
    var filterExpressions = Buffer.Buffer<SearchTypes.FilterExpressionType>(5);

    if (payload.isFuture) {
      filterExpressions.add({
        attributeNames = "start_date";
        filterExpressionCondition = #GTE(#nat(payload.currentTimestamp));
      });
    } else {
      filterExpressions.add({
        attributeNames = "start_date";
        filterExpressionCondition = #LT(#nat(payload.currentTimestamp));
      });
    };
    switch (payload.eventType) {
      case (?et) {
        filterExpressions.add({
          attributeNames = "event_type";
          filterExpressionCondition = #EQ(#text(et));
        });
      };
      case null {};
    };
    switch (payload.status) {
      case (?s) {
        filterExpressions.add({
          attributeNames = "status";
          filterExpressionCondition = #EQ(#text(s));
        });
      };
      case null {};
    };
    switch (payload.userId) {
      case (?uid) {
        filterExpressions.add({
          attributeNames = "user_id";
          filterExpressionCondition = #EQ(#principal(uid));
        });
      };
      case null {};
    };
    switch (payload.categories) {
      case (?cats) {
        if (cats.size() > 0) {
          filterExpressions.add({
            attributeNames = "categories";
            filterExpressionCondition = #IN(Helper.getStringAttributeDataValueArray(cats));
          });
        };
      };
      case null {};
    };
    switch (payload.recordingType) {
      case (?rec) {
        if (rec.size() > 0) {
          filterExpressions.add({
            attributeNames = "is_recording_available";
            filterExpressionCondition = #IN(Helper.getBoolAttributeDataValueArray(rec));
          });
        };
      };
      case null {};
    };

    let filterExpressionsArray = Buffer.toArray(filterExpressions);
    let queryFilters = Array.map<SearchTypes.FilterExpressionType, SearchTypes.QueryFilter>(
      filterExpressionsArray,
      func(e) { #expression(e) },
    );
    let filter : SearchTypes.QueryFilter = #AND(queryFilters);

    // --- 2. Get Total Record Count (only for the first page) ---
    let totalRecords = if (payload.cursor == null) {
      // This is a cheaper query to get just the count of matching items.
      EventCommonService.getTotalRecords(Constants.EventTable, filterExpressionsArray, alfangoDB);
    } else {
      0; // Don't recalculate for subsequent pages. The frontend should persist this.
    };

    // --- 3. Fetch the Page from the Database (The Scalable Part) ---
    let pageResponse = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
        filter = filter;
        limit = payload.limit;
        cursor = payload.cursor;
      };
      alfangoDB = alfangoDB;
    });

    switch (pageResponse) {
      case (#err(e)) { return #err(e) };
      case (#ok(page)) {
        var events = page.items;

        // --- 4. Enrich the Page with User Data ---
        // let enrichedItems = await getEventsWithUserData(page.items);
        if (events.size() == 0) {
          return #err(["NO_EVENTS_FOUND"]);
        };

        // --- SubStep 1: Collect unique user IDs from the events ---
        let userIdMap = HashMap.HashMap<Text, ()>(events.size(), Text.equal, Text.hash);
        for (event in events.vals()) {
          let userId = Helper.getTupleValueAsText(event.item, "user_id");
          if (Text.size(userId) > 0) { userIdMap.put(userId, ()) };
        };
        let userIds = Buffer.toArray(Buffer.fromIter<Text>(userIdMap.keys()));

        // --- SubStep 2: Fetch all user data in batch (Inlined logic from getUsersDetails) ---
        let userDataMap = HashMap.HashMap<Text, ArgumentTypes.UserResponsePayload>(userIds.size(), Text.equal, Text.hash);

        if (userIds.size() > 0) {
          let indexActor = actor (Constants.IndexCanister) : EventCommonService.IndexActor;
          let canisterMappings = await indexActor.getUserCanistersByPrincipal(userIds);

          if (canisterMappings.size() > 0) {
            let userDetailFutures = Buffer.Buffer<async ArgumentTypes.UserResponsePayload>(canisterMappings.size());
            for (mapping in canisterMappings.vals()) {
              let userCanisterActor = actor (mapping.canister_id) : EventCommonService.UserCanisterType;
              userDetailFutures.add(userCanisterActor.getUserForEventCanister(mapping.principal_id));
            };

            for (future in userDetailFutures.vals()) {
              let userDetails = await future;
              if (Text.size(userDetails.principal_id) > 0) {
                userDataMap.put(userDetails.principal_id, userDetails);
              };
            };
          };
        };

        // --- SubStep 3: Combine event data with the fetched user data ---
        let resultBuffer = Buffer.Buffer<ArgumentTypes.EventWithUserDataPayload>(events.size());
        for (event in events.vals()) {
          let eventId = event.id;
          let eventItem = event.item;
          let itemMap = Helper.attributeArrayToHashMap(eventItem);
          let userId = Helper.getAttributeFromMapAsText(itemMap, "user_id");

          let userData = switch (userDataMap.get(userId)) {
            case (?u) u;
            case null EventCommonService.initialEventObjectWithUserData.userData;
          };

          let eventPayload = EventCommonService.transformItemToEventPayload(eventId, itemMap);
          resultBuffer.add({
            event_id = eventPayload.event_id;
            user_id = eventPayload.user_id;
            coverphoto = eventPayload.coverphoto;
            name = eventPayload.name;
            description = eventPayload.description;
            location = eventPayload.location;
            start_date = eventPayload.start_date;
            end_date = eventPayload.end_date;
            language = eventPayload.language;
            status = eventPayload.status;
            metadata = eventPayload.metadata;
            event_type = eventPayload.event_type;
            participation_type = eventPayload.participation_type;
            categories = eventPayload.categories;
            consultations = eventPayload.consultations;
            expertise = eventPayload.expertise;
            price_token = eventPayload.price_token;
            token_amount = eventPayload.token_amount;
            interests = eventPayload.interests;
            showcase_link = eventPayload.showcase_link;
            recording_visibility = eventPayload.recording_visibility;
            is_recording_available = eventPayload.is_recording_available;
            subaccount_id_hex = eventPayload.subaccount_id_hex;
            subaccount_id_index = eventPayload.subaccount_id_index;
            userData = userData;
          });
        };

        // --- 5. Return the Structured Paginated Response ---
        return #ok({
          items = Buffer.toArray(resultBuffer);
          totalRecords = totalRecords;
          hasMore = page.hasMore;
          nextCursor = page.nextCursor;
        });
      };
    };
  };

  public shared (msg) func acceptApplication(eventId : Text, acceptedUserId : Principal) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await EventUpdateService.acceptApplication(msg.caller, eventId, acceptedUserId, alfangoDB, canistergeekLogger);
  };

  public shared (msg) func declineApplication(eventId : Text, declinedUserId : Principal) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await EventUpdateService.declineApplication(msg.caller, eventId, declinedUserId, alfangoDB, canistergeekLogger);
  };

  public shared (msg) func updateMultipleEvents(
    userCanisterId : Text,
    updates : [ArgumentTypes.UpdateMultipleEventsPayload],
  ) : async ArgumentTypes.UpdateMultipleEventsResponse {
    canistergeekMonitor.collectMetrics();
    await EventUpdateService.updateMultipleEvents(
      msg.caller,
      userCanisterId,
      updates,
      alfangoDB,
      d3,
      canistergeekLogger,
    );
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

  /* Validate and reject anonymous calls*/
  // system func inspect({ caller : Principal }) : Bool {
  //   not (Principal.isAnonymous(caller));
  // };

  // system func preupgrade() {
  //   EventService.generateEventSchema(alfangoDB);
  // };
};
