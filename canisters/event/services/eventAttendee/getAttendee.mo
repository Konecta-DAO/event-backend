import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import Iter "mo:base/Iter";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import HashMap "mo:base/HashMap";
import ArgumentTypes "../../types/argumentTypes";
import EventConstants "../../utils/constants";
import HelperService "../../utils/helper";
import {
  getStringAttributeDataValueArray;
  getTupleValueAsText;
  textArrayToString;
  textToNat;
} "../../utils/helper";
import CommonService "../common";

module {

  /**
  * @desc Finds the unique database ID for a specific attendee record based on their principal,
  * the event, and their current action/status. This is essential for targeting a specific record for updates.
  * @param userPrincipal The principal of the attendee.
  * @param eventId The ID of the event.
  * @param action The current action of the attendee (e.g., #Applied).
  * @param alfangoDB The database instance.
  * @returns An optional Text containing the record ID if found, otherwise null.
  */
  public func getAttendeeRecordId(
    userPrincipal : Principal,
    eventId : Text,
    action : ArgumentTypes.EventAttendeeActions,
    alfangoDB : Database.AlfangoDB,
  ) : ?Text {
    // Convert the Motoko variant to its text representation for the query
    let actionType = CommonService.getActionType(action);

    // Build a precise filter to find the exact record
    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
      #expression({
        attributeNames = "invitee_user_id";
        filterExpressionCondition = #EQ(#principal(userPrincipal));
      }),
      #expression({
        attributeNames = "action";
        filterExpressionCondition = #EQ(#text(actionType));
      }),
    ]);

    // Scan the database for a single matching record
    let response = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = EventConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filter = filter;
        limit = 1;
        cursor = null;
      };
      alfangoDB = alfangoDB;
    });

    switch (response) {
      case (#ok(page)) {
        if (page.items.size() > 0) {
          ?page.items[0].id;
        } else {
          null;
        };
      };
      case (#err(_err)) {
        null;
      };
    };
  };

  public func getEventAttendeeCount(eventId : Text, alfangoDB : Database.AlfangoDB) : Nat {
    Debug.print(debug_show (eventId));
    var count = 0;

    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
      #expression({
        attributeNames = "action";
        filterExpressionCondition = #EQ(#text(EventConstants.EventAttendeeStatus.Joined));
      }),
    ]);

    let idsResponse = Database.scanAndGetIds({
      scanAndGetIdsInput = {
        databaseName = EventConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (idsResponse) {
      case (#ok(response)) {
        count := Array.size(response.ids);
      };
      case (#err(_err)) {
        count := 0;
      };
    };

    return count;
  };

  public func checkIfAttendeeExistsForEvent(userPrincipal : Principal, eventId : Text, alfangoDB : Database.AlfangoDB) : Bool {
    var exists = false;

    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
      #expression({
        attributeNames = "invitee_user_id";
        filterExpressionCondition = #EQ(#principal(userPrincipal));
      }),
      #expression({
        attributeNames = "action";
        filterExpressionCondition = #EQ(#text(EventConstants.EventAttendeeStatus.Joined));
      }),
    ]);

    let eventResponse = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = EventConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filter = filter;
        limit = 1;
        cursor = null;
      };
      alfangoDB = alfangoDB;
    });

    switch (eventResponse) {
      case (#ok(page)) {
        if (Array.size(page.items) > 0) {
          exists := true;
        };
      };
      case (#err(_err)) {
        exists := false;
      };
    };

    return exists;
  };

  public func checkIfAttendeeOrAcceptedUserExistsForEvent(userPrincipal : Principal, eventId : Text, alfangoDB : Database.AlfangoDB) : Bool {
    var exists = false;

    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
      #expression({
        attributeNames = "invitee_user_id";
        filterExpressionCondition = #EQ(#principal(userPrincipal));
      }),
      #expression({
        attributeNames = "action";
        filterExpressionCondition = #IN([#text(EventConstants.EventAttendeeStatus.Joined), #text(EventConstants.EventAttendeeStatus.Accepted)]);
      }),
    ]);

    let eventResponse = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = EventConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filter = filter;
        limit = 1;
        cursor = null;
      };
      alfangoDB = alfangoDB;
    });

    Debug.print(debug_show (eventResponse));
    switch (eventResponse) {
      case (#ok(page)) {
        if (Array.size(page.items) > 0) {
          exists := true;
        };
      };
      case (#err(_err)) {
        exists := false;
      };
    };

    return exists;
  };

  public func getAttendeeStatusForEvent(userPrincipal : Principal, eventId : Text, alfangoDB : Database.AlfangoDB) : Text {
    Debug.print(debug_show (userPrincipal));
    Debug.print(debug_show (eventId));
    var status = "";

    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
      #expression({
        attributeNames = "invitee_user_id";
        filterExpressionCondition = #EQ(#principal(userPrincipal));
      }),
      #expression({
        attributeNames = "action";
        filterExpressionCondition = #IN([#text(EventConstants.EventAttendeeStatus.Joined), #text(EventConstants.EventAttendeeStatus.Withdrawn)]);
      }),
    ]);

    let eventResponse = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = EventConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filter = filter;
        limit = 1;
        cursor = null;
      };
      alfangoDB = alfangoDB;
    });

    Debug.print(debug_show (eventResponse));
    switch (eventResponse) {
      case (#ok(page)) {
        if (Array.size(page.items) > 0) {
          status := getTupleValueAsText(page.items[0].item, "action");
        };
      };
      case (#err(_err)) status := "";
    };

    return status;
  };

  public func getAttendeesIdsByAction(eventId : Text, action : ArgumentTypes.EventAttendeeActions, alfangoDB : Database.AlfangoDB) : Result.Result<[Text], [Text]> {

    let actionType = CommonService.getActionType(action);

    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
      #expression({
        attributeNames = "action";
        filterExpressionCondition = #EQ(#text(actionType));
      }),
    ]);

    let attendees = Database.scan({
      scanInput = {
        databaseName = EventConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (attendees) {
      case (#err(err)) {
        return #err(err);
      };
      case (#ok(attendeeData)) {
        let seen = HashMap.HashMap<Text, ()>(attendeeData.size(), Text.equal, Text.hash);
        let uniqueUserIdBuffer = Buffer.Buffer<Text>(0);

        for (attendee in attendeeData.vals()) {
          let itemData = attendee.item;
          let user = getTupleValueAsText(itemData, "invitee_user_id");

          switch (seen.replace(user, ())) {
            case (null) { uniqueUserIdBuffer.add(user) };
            case (?_) { () };
          };
        };
        return #ok(Buffer.toArray(uniqueUserIdBuffer));
      };
    };
  };

  public func getAttendeesIdsByActionArray(eventId : Text, actions : [ArgumentTypes.EventAttendeeActions], alfangoDB : Database.AlfangoDB) : Result.Result<[Text], [Text]> {

    let actionBuffer = Buffer.Buffer<Text>(0);

    for (action in actions.vals()) {
      let actionType = CommonService.getActionType(action);
      actionBuffer.add(actionType);
    };
    let actionAttributeArray = getStringAttributeDataValueArray(Buffer.toArray(actionBuffer));

    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
      #expression({
        attributeNames = "action";
        filterExpressionCondition = #IN(actionAttributeArray);
      }),
    ]);

    let attendees = Database.scan({
      scanInput = {
        databaseName = EventConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (attendees) {
      case (#err(err)) {
        return #err(err);
      };
      case (#ok(attendeeData)) {
        let seen = HashMap.HashMap<Text, ()>(attendeeData.size(), Text.equal, Text.hash);
        let uniqueUserIdBuffer = Buffer.Buffer<Text>(0);

        for (attendee in attendeeData.vals()) {
          let itemData = attendee.item;
          let user = getTupleValueAsText(itemData, "invitee_user_id");

          if (seen.replace(user, ()) == null) {
            uniqueUserIdBuffer.add(user);
          };
        };
        return #ok(Buffer.toArray(uniqueUserIdBuffer));
      };
    };
  };

  public func getAllAttendeesIds(eventId : Text, alfangoDB : Database.AlfangoDB) : Result.Result<[ArgumentTypes.EventAttendeeResponsePayload], [Text]> {

    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
      #expression({
        attributeNames = "action";
        filterExpressionCondition = #EQ(#text(EventConstants.EventAttendeeStatus.Joined));
      }),
    ]);

    let attendees = Database.scan({
      scanInput = {
        databaseName = EventConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (attendees) {
      case (#err(err)) {
        return #err(err);
      };
      case (#ok(attendeeData)) {
        let responseBuffer = Buffer.Buffer<ArgumentTypes.EventAttendeeResponsePayload>(attendeeData.size());

        for (attendee in attendeeData.vals()) {
          let itemId = attendee.id;

          let itemMap = HelperService.attributeArrayToHashMap(attendee.item);

          let metadata : ?[(Text, Database.StringAttributeDataValue)] = switch (itemMap.get("metadata")) {
            case (?#map(m)) {
              let buf = Buffer.Buffer<(Text, Database.StringAttributeDataValue)>(m.size());
              for ((k, v) in m.vals()) {
                switch (v) {
                  case (#text(t)) { buf.add((k, #text(t))) };
                  case (_) {};
                };
              };
              ?buf.toArray();
            };
            case _ {
              null;
            };
          };

          responseBuffer.add({
            id = itemId;
            event_id = HelperService.getAttributeFromMapAsText(itemMap, "event_id");
            invitee_user_id = HelperService.getAttributeFromMapAsText(itemMap, "invitee_user_id");
            action = HelperService.getAttributeFromMapAsText(itemMap, "action");
            event_status = HelperService.getAttributeFromMapAsText(itemMap, "event_status");
            timestamp = textToNat(HelperService.getAttributeFromMapAsText(itemMap, "timestamp"));
            metadata = metadata;
          });
        };

        return #ok(Buffer.toArray(responseBuffer));
      };
    };
  };

  public func getEventsForAttendee(userPrincipal : Principal, alfangoDB : Database.AlfangoDB) : Result.Result<[Text], [Text]> {

    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "invitee_user_id";
        filterExpressionCondition = #EQ(#principal(userPrincipal));
      }),
      #expression({
        attributeNames = "action";
        filterExpressionCondition = #EQ(#text(EventConstants.EventAttendeeStatus.Joined));
      }),
    ]);

    let events = Database.scan({
      scanInput = {
        databaseName = EventConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (events) {
      case (#err(err)) {
        return #err(err);
      };
      case (#ok(eventAttendeesData)) {
        let seen = HashMap.HashMap<Text, ()>(eventAttendeesData.size(), Text.equal, Text.hash);
        let uniqueEventIdBuffer = Buffer.Buffer<Text>(0);

        for (eventAttendee in eventAttendeesData.vals()) {
          let itemData = eventAttendee.item;
          let eventId = getTupleValueAsText(itemData, "event_id");

          switch (seen.replace(eventId, ())) {
            case (null) { uniqueEventIdBuffer.add(eventId) };
            case (?_) { () };
          };
        };
        return #ok(Buffer.toArray(uniqueEventIdBuffer));
      };
    };
  };

  public func getEventsForAttendeeWithEventData(userPrincipal : Principal, alfangoDB : Database.AlfangoDB) : Result.Result<[ArgumentTypes.EventResponsePayload], [Text]> {

    let eventIdsResponse = getEventsForAttendee(userPrincipal, alfangoDB);

    switch (eventIdsResponse) {
      case (#ok(eventIds)) {
        if (Array.size(eventIds) == 0) {
          return #ok([]);
        };

        let eventsResponse = Database.batchGetItemById({
          batchGetItemByIdInput = {
            databaseName = EventConstants.KonectA;
            tableName = EventConstants.EventTable;
            ids = eventIds;
          };
          alfangoDB = alfangoDB;
        });

        switch (eventsResponse) {
          case (#ok(multipleEventItems)) {
            let eventBuffer = Buffer.Buffer<ArgumentTypes.EventResponsePayload>(0);

            let eventItems = multipleEventItems.items;
            for (itemObject in eventItems.vals()) {
              let eventId = itemObject.id;
              let eventItem = itemObject.item;

              CommonService.handleEventBuffer(eventId, eventItem, eventBuffer);
            };

            #ok(Buffer.toArray(eventBuffer));
          };
          case (#err(error)) #err(error);
        };

      };
      case (#err(error)) {
        #err(error);
      };
    };
  };

  public func getRequestIdForJoinedAttendee(userIdOfJoinee : Text, eventId : Text, action : Text, alfangoDB : Database.AlfangoDB) : Result.Result<Text, Text> {

    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
      #expression({
        attributeNames = "invitee_user_id";
        filterExpressionCondition = #EQ(#principal(Principal.fromText(userIdOfJoinee)));
      }),
      #expression({
        attributeNames = "action";
        filterExpressionCondition = #EQ(#text(action));
      }),
    ]);

    let appliedRequestsResponse = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = EventConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filter = filter;
        limit = 1;
        cursor = null;
      };
      alfangoDB = alfangoDB;
    });

    switch (appliedRequestsResponse) {
      case (#ok(page)) {
        if (Array.size(page.items) == 0) {
          #err("User has not applied for this event");
        } else {
          #ok(page.items[0].id);
        };
      };
      case (#err(error)) #err(textArrayToString(error));
    };
  };

  public func getPaginatedEventsForAttendee(
    userPrincipal : Principal,
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : Result.Result<ArgumentTypes.PaginatedEventIdsWithCursor, [Text]> {

    let filterExpressions : [SearchTypes.FilterExpressionType] = [
      {
        attributeNames = "invitee_user_id";
        filterExpressionCondition = #EQ(#principal(userPrincipal));
      },
      {
        attributeNames = "action";
        filterExpressionCondition = #EQ(#text(EventConstants.EventAttendeeStatus.Joined));
      },
      {
        attributeNames = "event_status";
        filterExpressionCondition = #NEQ(#text(EventConstants.EventStatus.Canceled));
      },
    ];

    // Only get total records on the first page load
    let totalRecords = if (cursor == null) {
      CommonService.getTotalRecords(EventConstants.EventAttendeeTable, filterExpressions, alfangoDB);
    } else {
      0;
    };

    canistergeekLogger.logMessage("Total records for attendee --> " # Nat.toText(totalRecords));

    let queryFilters = Array.map<SearchTypes.FilterExpressionType, SearchTypes.QueryFilter>(
      filterExpressions,
      func(expr) { #expression(expr) },
    );
    let filter : SearchTypes.QueryFilter = #AND(queryFilters);

    let paginatedEvents = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = EventConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filter = filter;
        limit = limit;
        cursor = cursor;
      };
      alfangoDB = alfangoDB;
    });

    canistergeekLogger.logMessage("Paginated Events for Attendee --> " # debug_show (paginatedEvents));
    switch (paginatedEvents) {
      case (#err(err)) {
        return #err(err);
      };
      case (#ok(page)) {
        let eventIdBuffer = Buffer.Buffer<Text>(page.items.size());
        for (eventAttendee in page.items.vals()) {
          let itemData = eventAttendee.item;
          let eventId = getTupleValueAsText(itemData, "event_id");
          eventIdBuffer.add(eventId);
        };

        let uniqueEventIdBuffer = Buffer.Buffer<Text>(0);
        let seen = HashMap.HashMap<Text, ()>(0, Text.equal, Text.hash);
        for (eventId in eventIdBuffer.vals()) {
          if (seen.replace(eventId, ()) == null) {
            uniqueEventIdBuffer.add(eventId);
          };
        };
        let eventIdArray = Buffer.toArray(uniqueEventIdBuffer);

        return #ok({
          ids = eventIdArray;
          totalRecords = totalRecords;
          hasMore = page.hasMore;
          nextCursor = page.nextCursor;
        });
      };
    };
  };

  public func getAttendeeRecordsForUserByAction(
    userPrincipal : Principal,
    action : ArgumentTypes.EventAttendeeActions,
    alfangoDB : Database.AlfangoDB,
  ) : Result.Result<[Text], [Text]> {
    let actionType = CommonService.getActionType(action);
    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "invitee_user_id";
        filterExpressionCondition = #EQ(#principal(userPrincipal));
      }),
      #expression({
        attributeNames = "action";
        filterExpressionCondition = #EQ(#text(actionType));
      }),
    ]);

    let events = Database.scan({
      scanInput = {
        databaseName = EventConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (events) {
      case (#err(err)) { return #err(err) };
      case (#ok(eventAttendeesData)) {

        let seen = HashMap.HashMap<Text, ()>(eventAttendeesData.size(), Text.equal, Text.hash);
        let uniqueEventIdBuffer = Buffer.Buffer<Text>(0);

        for (eventAttendee in eventAttendeesData.vals()) {
          let itemData = eventAttendee.item;
          let eventId = getTupleValueAsText(itemData, "event_id");

          if (seen.replace(eventId, ()) == null) {
            uniqueEventIdBuffer.add(eventId);
          };
        };
        return #ok(Buffer.toArray(uniqueEventIdBuffer));
      };
    };
  };

  public func getPaginatedAttendeeRecordsForUserByAction(
    userPrincipal : Principal,
    action : ArgumentTypes.EventAttendeeActions,
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
    alfangoDB : Database.AlfangoDB,
  ) : Result.Result<ArgumentTypes.PaginatedEventAttendeeResponse, [Text]> {
    let actionType = CommonService.getActionType(action);
    let filterExpressions : [SearchTypes.FilterExpressionType] = [
      {
        attributeNames = "invitee_user_id";
        filterExpressionCondition = #EQ(#principal(userPrincipal));
      },
      {
        attributeNames = "action";
        filterExpressionCondition = #EQ(#text(actionType));
      },
    ];

    // Get the total count for the frontend, but only if it's the first page
    let totalRecords = if (cursor == null) {
      CommonService.getTotalRecords(EventConstants.EventAttendeeTable, filterExpressions, alfangoDB);
    } else {
      0; // Don't re-calculate on subsequent pages
    };

    let queryFilters = Array.map<SearchTypes.FilterExpressionType, SearchTypes.QueryFilter>(
      filterExpressions,
      func(expr) { #expression(expr) },
    );
    let filter : SearchTypes.QueryFilter = #AND(queryFilters);

    let pageResponse = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = EventConstants.KonectA;
        tableName = EventConstants.EventAttendeeTable;
        filter = filter;
        limit = limit;
        cursor = cursor;
      };
      alfangoDB = alfangoDB;
    });

    switch (pageResponse) {
      case (#err(e)) { return #err(e) };
      case (#ok(page)) {

        let resultBuffer = Buffer.Buffer<ArgumentTypes.EventAttendeeResponsePayload>(page.items.size());
        for (item in page.items.vals()) {
          let itemMap = HelperService.attributeArrayToHashMap(item.item);

          let metadata : ?[(Text, Database.StringAttributeDataValue)] = switch (itemMap.get("metadata")) {
            case (null) {
              null;
            };
            case (?#map(m)) {
              let strMap = Buffer.Buffer<(Text, Database.StringAttributeDataValue)>(m.size());
              for ((k, v) in m.vals()) {
                switch (v) {
                  case (#text(t)) { strMap.add((k, #text(t))) };
                  case (_) {};
                };
              };
              ?Buffer.toArray(strMap);
            };
            case (_) {
              null;
            };
          };

          resultBuffer.add({
            id = item.id;
            event_id = HelperService.getAttributeFromMapAsText(itemMap, "event_id");
            invitee_user_id = HelperService.getAttributeFromMapAsText(itemMap, "invitee_user_id");
            action = HelperService.getAttributeFromMapAsText(itemMap, "action");
            timestamp = textToNat(HelperService.getAttributeFromMapAsText(itemMap, "timestamp"));
            event_status = HelperService.getAttributeFromMapAsText(itemMap, "event_status");
            metadata = metadata;
          });
        };

        // Return the structured paginated result
        return #ok({
          items = Buffer.toArray(resultBuffer);
          totalRecords = totalRecords;
          hasMore = page.hasMore;
          nextCursor = page.nextCursor;
        });
      };
    };
  };
};
