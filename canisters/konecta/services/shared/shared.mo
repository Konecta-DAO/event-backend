import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";

module {

  public type UserCanisterType = actor {
    createEventMetaData : (metadata : ArgumentTypes.CreateEventMetadataRequestPayload) -> async Result.Result<Text, Text>;
    updateEventMetaData : (eventMetadataId : Text, metadata : ArgumentTypes.UpdateEventMetadataPayload) -> async Result.Result<Text, Text>;
    getCalendarId : shared query (userPrincipal : Text) -> async Text;
    getEventMetadataId : (eventId : Text, calendarId : Text) -> async Text;
    upsertCalendarData : (calendarId : Text, calendarData : ArgumentTypes.CalendarRequestPayload) -> async Text;
    getUserForEventCanister : shared query (userPrincipal : Text) -> async ArgumentTypes.UserResponsePayload;
    removeCalendarEvent : (eventMetadataId : Text) -> async Result.Result<Text, Text>;
  };

  /**
   * @notice This type defines the public interface of the `event` canister.
   * After refactoring, the `event` canister is the single source of truth for all event data.
   * The `konecta` canister calls these functions to manage and query event information.
   */
  public type EventCanisterType = actor {
    // --- Event Management (CRUD) ---

    /**
     * @desc Creates a new event with all its associated data in a single call.
     * @param userCanisterId The canister ID of the creator's user canister for calendar integration.
     * @param payload A comprehensive payload containing all event details, including konecta-specific fields.
     * @return The unique ID of the newly created event.
     */
    createEvent : (userCanisterId : Text, payload : ArgumentTypes.EventRequestPayload) -> async Text;

    /**
     * @desc Updates an existing event.
     * @param userPrincipal The principal of the user performing the update.
     * @param userCanisterId The user's canister ID.
     * @param eventId The ID of the event to update.
     * @param payload The payload with the updated fields.
     */
    updateEventUsingUserPrincipal : (userPrincipal : Principal, userCanisterId : Text, eventId : Text, payload : ArgumentTypes.EventRequestPayload) -> async Result.Result<Text, Text>;

    /**
     * @desc Processes an application acceptance. Accepts one user and declines all others.
     * @param eventId The ID of the event.
     * @param acceptedUserId The Principal of the user being accepted.
     * @return A result indicating success.
     */
    acceptApplication : (eventId : Text, acceptedUserId : Principal) -> async Result.Result<Text, Text>;

    /**
     * @desc Explicitly declines a single user's application for an event.
     * @param eventId The ID of the event.
     * @param declinedUserId The Principal of the user whose application is being declined.
     * @return A result indicating success or failure.
     */
    declineApplication : (eventId : Text, declinedUserId : Principal) -> async Result.Result<Text, Text>;

    updateEvent : (userCanisterId : Text, eventId : Text, payload : ArgumentTypes.EventRequestPayload) -> async Result.Result<Text, Text>;

    /**
     * @desc Cancels an event, updating its status and notifying attendees.
     * @param userPrincipal The principal of the user canceling the event.
     * @param eventId The ID of the event to cancel.
     * @param eventType The type of the event ("Request" or "Offer").
     * @return A list of attendee principals who were notified.
     */
    cancelEvent : (userPrincipal : Principal, eventId : Text, eventType : Text) -> async Result.Result<[Text], Text>;

    // --- Attendee & Applicant Management ---

    /**
     * @desc Adds an attendee to an event (e.g., joining an offer, accepting a request).
     */
    addEventAttendee : (payload : ArgumentTypes.EventAttendeeRequestPayload) -> async Result.Result<Text, Text>;

    /**
     * @desc Updates the status of a specific attendee for an event.
     * @param eventId The ID of the event.
     * @param inviteeUserId The Principal of the user to update.
     * @param currentAction The user's current status (e.g., #Applied).
     * @param newAction The new status to set (e.g., #Accepted).
     * @return The ID of the updated attendee record on success.
     */
    updateEventAttendeeStatus : (
      eventId : Text,
      inviteeUserId : Principal,
      currentAction : ArgumentTypes.EventAttendeeActions,
      newAction : ArgumentTypes.EventAttendeeActions,
    ) -> async Result.Result<Text, Text>;

    /**
     * @desc Withdraws an attendee from an event.
     * @return The full event data payload after the withdrawal.
     */
    withdrawEventAttendee : (payload : ArgumentTypes.WithdrawAttendeeRequestPayload) -> async Result.Result<ArgumentTypes.EventProtocolCanisterPayload, Text>;

    // --- Data Fetching & Queries ---

    /**
     * @desc A fast, read-only query to get all attendee records for a given event.
     */
    getAllAttendeesIds : shared query (eventId : Text) -> async Result.Result<[ArgumentTypes.EventAttendeeResponsePayload], [Text]>;

    /**
     * @desc A composite query to get the full, detailed payload for a single event, including the creator's user data.
     * @param eventId The ID of the event.
     * @return The complete event payload.
     */
    getEventDetailsWithUserData : shared composite query (eventId : Text) -> async ArgumentTypes.EventProtocolCanisterPayload;

    /**
     * @desc A composite query to get the full, detailed payload for a single event, including the creator's user data.
     * @param eventId The ID of the event.
     * @return The complete event payload.
     */
    getEventDetailsWithUserDataAsync : (eventId : Text) -> async ArgumentTypes.EventProtocolCanisterPayload;

    /**
     * @desc A composite query to efficiently fetch an array of event details from an array of event IDs.
     * @param eventIdArray An array of event IDs.
     * @return An array of tuples, where each tuple is (event_id, EventWithUserDataPayload).
     */
    getEventArrayFromEventIdArray : shared composite query (eventIdArray : [Text]) -> async ArgumentTypes.EventWithUserDataTupleArray;

    /**
     * @desc A query to get a batch of event data for a given list of IDs. This is less detailed than the composite query above but is a pure query.
     * @param eventIds An array of event IDs to fetch.
     * @return An array of event data payloads, without user data.
     */
    getBatchEventsByCompositeQuery : shared query (eventIds : [Text]) -> async [ArgumentTypes.EventCanisterResponseWithoutUser];

    /**
     * @desc A composite query for paginated fetching of events a user has joined, including full user data.
     * @param userPrincipal The principal of the user.
     * @param offset The starting point for pagination.
     * @param limit The number of items per page.
     * @return A paginated result of event data.
     */
    getPaginatedEventsForAttendee : shared composite query (
      userPrincipal : Text,
      limit : Nat,
      cursor : ?SearchTypes.PaginatedScanCursor,
    ) -> async Result.Result<ArgumentTypes.PaginatedEventWithUserDataPayload, [Text]>;

    /**
     * @desc Checks if a user is an attendee of an event (status is "Joined").
     */
    checkIfAttendeeExistsForEvent : shared query (userPrincipal : Principal, eventId : Text) -> async Bool;

    /**
     * @desc Checks if a user is either an attendee ("Joined") or has been accepted to a request ("Accepted").
     */
    checkIfAttendeeOrAcceptedUserExistsForEvent : shared query (userPrincipal : Principal, eventId : Text) -> async Bool;

    /**
     * @desc Gets the specific status of a user for a given event (e.g., "Joined", "Withdrawn").
     */
    getAttendeeStatusForEvent : shared query (userPrincipal : Principal, eventId : Text) -> async Text;

    /**
  * @desc A composite query to get a list of attendees with their user details for a specific event and action.
  * @param eventId The ID of the event.
  * @param action The attendee action to filter by (e.g., #Joined, #Accepted).
  * @return A result containing an array of user data payloads or an error.
  */
    getAttendeesByActionWithUserDetails : composite query (eventId : Text, action : ArgumentTypes.EventAttendeeActions) -> async Result.Result<[ArgumentTypes.UserResponsePayload], [Text]>;

    /**
  * @desc A func for the cron job to fetch events that have ended within a specific time range.
  * @param startTime The start of the time window (nanoseconds).
  * @param endTime The end of the time window (nanoseconds).
  * @return A result containing an array of full event payloads or an error.
  */
    getCompletedEventsForCron : (startTime : Nat, endTime : Nat) -> async Result.Result<[ArgumentTypes.EventProtocolCanisterPayload], [Text]>;
    /**
  * @desc An async (update call) function to get a list of attendees with their user details for a specific event and action.
  * @param eventId The ID of the event.
  * @param action The attendee action to filter by (e.g., #Joined, #Accepted).
  * @return A result containing an array of user data payloads or an error.
  */
    getAttendeesByActionWithUserDetailsAsync : (eventId : Text, action : ArgumentTypes.EventAttendeeActions) -> async Result.Result<[ArgumentTypes.UserResponsePayload], [Text]>;
    getPaginatedFilteredEvents : composite query (
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
    ) -> async Result.Result<ArgumentTypes.PaginatedEventWithUserDataPayload, [Text]>;
    getServiceRequestsForUser : composite query (userPrincipal : Principal) -> async Result.Result<[ArgumentTypes.EventProtocolCanisterPayload], [Text]>;
    getServiceOffersExcludingUser : (userPrincipal : Principal) -> async Result.Result<[ArgumentTypes.EventProtocolCanisterPayload], [Text]>;
    getFilteredEvents : composite query (
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
    ) -> async Result.Result<{ items : [ArgumentTypes.EventProtocolCanisterPayload]; totalRecords : Nat }, [Text]>;
  };

  public type IndexActor = actor {
    getUserCanisterByUserPrincipal : shared query (principal : Text) -> async Text;
    getUserCanistersByPrincipal : shared query (principals : [Text]) -> async [ArgumentTypes.CanisterMapPayload];
  };

  // Function to get the user canister ID
  public func getUserCanisterId(userId : Text) : async Text {
    let indexActor = actor (Constants.IndexCanister) : IndexActor;
    return await indexActor.getUserCanisterByUserPrincipal(userId);
  };

  // Function to get user details
  public func getUserDetails(userId : Text) : async ArgumentTypes.UserResponsePayload {
    let userCanisterId = await getUserCanisterId(userId);

    let userCanisterActor = actor (userCanisterId) : UserCanisterType;
    let userData = await userCanisterActor.getUserForEventCanister(userId);

    return userData;
  };

  private func createEventMetadataMethod(
    creatorPrincipal : Principal,
    userIdOfApplicant : Principal,
    userCanisterId : Text,
    payload : ArgumentTypes.EventProtocolCanisterPayload,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, Text> {
    let userCanister = actor (userCanisterId) : UserCanisterType;
    Debug.print(debug_show ("User canister --->" # userCanisterId));

    var calendarId = await userCanister.getCalendarId(Principal.toText(userIdOfApplicant));
    Debug.print(debug_show (calendarId));

    let calendarObject = {
      name = payload.name;
      description = payload.description;
    };
    Debug.print(debug_show ("Calendar object --->" # debug_show (calendarObject)));
    canistergeekLogger.logMessage("Calendar object --->" # debug_show (calendarObject));

    if (Text.size(calendarId) == 0) {
      calendarId := await userCanister.upsertCalendarData(calendarId, calendarObject);
    };

    Debug.print(debug_show ("Calendar id --->" # debug_show (calendarId)));
    canistergeekLogger.logMessage("Calendar id --->" # debug_show (calendarId));

    let eventObject : ArgumentTypes.CreateEventMetadataRequestPayload = {
      event_id = payload.event_id;
      name = payload.name;
      start_date = payload.start_date;
      end_date = payload.end_date;
      calendar_id = calendarId;
      status = Constants.EventStatusVariant.Created;
      created_by = creatorPrincipal;
      categories = payload.categories;
      interests = payload.interests;
    };
    Debug.print(debug_show ("Event object --->" # debug_show (eventObject)));
    canistergeekLogger.logMessage("Event object --->" # debug_show (eventObject));

    let eventMetadataResponse = await userCanister.createEventMetaData(eventObject);
    Debug.print(debug_show ("Event metadata response ---> " # debug_show (eventMetadataResponse)));
    canistergeekLogger.logMessage("Event metadata response ---> " # debug_show (eventMetadataResponse));

    return eventMetadataResponse;
  };

  public func addEventAttendee(
    creatorPrincipal : Principal,
    userIdOfApplicant : Principal,
    action : ArgumentTypes.EventAttendeeActions,
    payload : ArgumentTypes.EventProtocolCanisterPayload,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Bool, Text> {

    let eventCanisterActor = actor (Constants.EventCanister) : EventCanisterType;
    try {
      let userCanisterId = await getUserCanisterId(Principal.toText(userIdOfApplicant));
      canistergeekLogger.logMessage("User Canister Id --->" # debug_show (userCanisterId));

      let eventMetadataId = await createEventMetadataMethod(creatorPrincipal, userIdOfApplicant, userCanisterId, payload, canistergeekLogger);
      canistergeekLogger.logMessage("Event Metadata Id --->" # debug_show (eventMetadataId));

      let eventAttendeeObject = {
        event_id = payload.event_id;
        invitee_user_id = userIdOfApplicant;
        action = action;
        timestamp = Int.abs(Time.now());
        event_status = payload.status;
        event_type = payload.event_type;
        participation_type = payload.participation_type;
      };
      let addEventAttendeeResponse = await eventCanisterActor.addEventAttendee(eventAttendeeObject);
      canistergeekLogger.logMessage("Add Event Attendee To Event Attendee Table --->" # debug_show (addEventAttendeeResponse));

      switch (addEventAttendeeResponse) {
        case (#ok(_response)) {
          #ok(true);
        };
        case (#err(error)) {
          #err(error);
        };
      };
    } catch (e) {
      throw e;
    };
  };

};
