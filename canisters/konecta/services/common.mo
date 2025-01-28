import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";

import ArgumentTypes "../types/argumentTypes";
import Constants "../utils/constants";
import {
  getAttributeDataValue;
  getFloatFromAttributeDataValueArray;
  getTextArrayFromAttributeDataValueArray;
  getTupleArrayFromAttributeDataValueArray;
  getTupleValue;
  getTupleValueAsText;
  textToFloat;
  textToNat;
} "../utils/helper";

module {

  // Define the types for the user and event canisters
  public type UserCanisterType = actor {
    createEventMetaData : (metadata : ArgumentTypes.CreateEventMetadataRequestPayload) -> async Result.Result<Text, Text>;
    updateEventMetaData : (eventMetadataId : Text, metadata : ArgumentTypes.UpdateEventMetadataPayload) -> async Text;
    getCalendarId : (eventId : Text) -> async Text;
    getEventMetadataId : (eventId : Text, calendarId : Text) -> async Text;
    upsertCalendarData : (userPrincipal : Text, calendarId : Text, calendarData : ArgumentTypes.CalendarRequestPayload) -> async Text;
    getUserForEventCanister : shared query (userPrincipal : Text) -> async ArgumentTypes.UserResponsePayload;
  };

  public type EventCanisterType = actor {
    addEventAttendee : (payload : ArgumentTypes.EventAttendeeRequestPayload) -> async Result.Result<Text, Text>;
    cancelEvent : (userPrincipal : Principal, eventId : Text) -> async Result.Result<Text, Text>;
    checkIfAttendeeExistsForEvent : shared query (userPrincipal : Principal, eventId : Text) -> async Bool;
    getEventsForAttendee : shared query (userPrincipal : Text) -> async Result.Result<[Text], [Text]>;
    updateEventUsingUserPrincipal : (userPrincipal : Principal, userCanisterId : Text, eventId : Text, payload : ArgumentTypes.EventCanisterRequestPayload) -> async Result.Result<Text, Text>;
  };

  public type IndexActor = actor {
    getUserCanisterByUserPrincipal : shared query (principal : Text) -> async Text;
  };

  public func getEventType(action : ArgumentTypes.EventType, initialValue : Text) : Text {
    var eventType = initialValue;

    switch (action) {
      case (#Request) eventType := Constants.EventType.Request;
      case (#Offer) eventType := Constants.EventType.Offer;
    };

    return eventType;
  };

  public func getEventStatus(action : ArgumentTypes.EventStatus, initialValue : Text) : Text {
    var status = initialValue;

    switch (action) {
      case (#Created) status := Constants.EventStatus.Created;
      case (#Canceled) status := Constants.EventStatus.Canceled;
    };

    return status;
  };

  public func getActionType(action : ArgumentTypes.EventAttendeeActions) : Text {
    var actionType = "";

    switch (action) {
      case (#Applied) actionType := Constants.EventAttendeeStatus.Applied;
      case (#Joined) actionType := Constants.EventAttendeeStatus.Joined;
      case (#Invited) actionType := Constants.EventAttendeeStatus.Invited;
      case (#Accepted) actionType := Constants.EventAttendeeStatus.Accepted;
      case (#Declined) actionType := Constants.EventAttendeeStatus.Declined;
    };

    return actionType;
  };

  // Function to transform the response of getting all events
  public func transformGetAllEventsResponse(eventResponse : Database.ScanOutputType) : Result.Result<[ArgumentTypes.EventResponsePayload], [Text]> {
    let eventBuffer = Buffer.Buffer<ArgumentTypes.EventResponsePayload>(0);
    var eventsArray : [ArgumentTypes.EventResponsePayload] = [];
    switch (eventResponse) {
      case (#ok(eventData)) {
        for (itemObject in eventData.vals()) {
          let konectaEventId = itemObject.id;
          let eventItem = itemObject.item;

          eventsArray := Buffer.toArray(handleEventBuffer(konectaEventId, eventItem, eventBuffer));
        };

        #ok(eventsArray);
      };

      case (#err(error)) #err(error);

    };

  };

  // Function to transform the response of getting all feeds
  public func transformGetAllFeedsResponse(eventResponse : Database.ScanOutputType) : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
    let eventBuffer = Buffer.Buffer<ArgumentTypes.FeedResponsePayload>(0);
    var eventsArray : [ArgumentTypes.FeedResponsePayload] = [];
    switch (eventResponse) {
      case (#ok(eventData)) {
        for (itemObject in eventData.vals()) {
          let konectaEventId = itemObject.id;
          let eventItem = itemObject.item;

          eventsArray := await handleFeedBuffer(konectaEventId, eventItem, eventBuffer);
        };

        #ok(eventsArray);
      };

      case (#err(error)) #err(error);

    };

  };

  // Function to transform an array of length one
  public func transformArrayOfLengthOne(eventResponse : Database.ScanOutputType) : Result.Result<ArgumentTypes.EventResponsePayload, [Text]> {
    let eventBuffer = Buffer.Buffer<ArgumentTypes.EventResponsePayload>(0);
    var eventsArray : [ArgumentTypes.EventResponsePayload] = [];
    switch (eventResponse) {
      case (#ok(eventData)) {
        for (itemObject in eventData.vals()) {
          let konectaEventId = itemObject.id;
          let eventItem = itemObject.item;

          eventsArray := Buffer.toArray(handleEventBuffer(konectaEventId, eventItem, eventBuffer));
        };

        #ok(eventsArray[0]);
      };

      case (#err(error)) #err(error);

    };
  };

  // Function to transform an array of feeds of length one
  public func transformFeedArrayOfLengthOne(eventResponse : Database.ScanOutputType) : async Result.Result<ArgumentTypes.FeedResponsePayload, [Text]> {
    let eventBuffer = Buffer.Buffer<ArgumentTypes.FeedResponsePayload>(0);
    var eventsArray : [ArgumentTypes.FeedResponsePayload] = [];
    switch (eventResponse) {
      case (#ok(eventData)) {
        for (itemObject in eventData.vals()) {
          let konectaEventId = itemObject.id;
          let eventItem = itemObject.item;

          eventsArray := await handleFeedBuffer(konectaEventId, eventItem, eventBuffer);
        };

        #ok(eventsArray[0]);
      };

      case (#err(error)) #err(error);

    };
  };

  // Function to transform the response of getting a single event
  public func transformGetEventResponse(eventResponse : Database.GetItemByIdOutputType) : Result.Result<ArgumentTypes.EventResponsePayload, [Text]> {
    let eventBuffer = Buffer.Buffer<ArgumentTypes.EventResponsePayload>(0);

    switch (eventResponse) {
      case (#ok(eventData)) {

        let konectaEventId = eventData.id;
        let eventItem = eventData.item;

        let event = Buffer.toArray(handleEventBuffer(konectaEventId, eventItem, eventBuffer))[0];

        #ok(event);
      };

      case (#err(error)) #err(error);

    };

  };

  // Function to transform the response of getting a single feed
  public func transformGetFeedResponse(eventResponse : Database.GetItemByIdOutputType) : async Result.Result<ArgumentTypes.FeedResponsePayload, [Text]> {
    let eventBuffer = Buffer.Buffer<ArgumentTypes.FeedResponsePayload>(0);

    switch (eventResponse) {
      case (#ok(eventData)) {

        let konectaEventId = eventData.id;
        let eventItem = eventData.item;

        let event = (await handleFeedBuffer(konectaEventId, eventItem, eventBuffer))[0];

        #ok(event);
      };

      case (#err(error)) #err(error);

    };

  };

  // Helper function to handle the event buffer
  private func handleEventBuffer(konectaEventId : Text, eventItem : [(Text, Database.AttributeDataValue)], eventBuffer : Buffer.Buffer<ArgumentTypes.EventResponsePayload>) : Buffer.Buffer<ArgumentTypes.EventResponsePayload> {

    let tokenAmount = textToFloat(getTupleValueAsText(eventItem, "token_amount"));
    var amount = 0.0;
    switch (tokenAmount) {
      case (#ok(value)) {
        amount := value;
      };
      case (#err(error)) {
        amount := 0.0;
      };
    };

    eventBuffer.add({
      konecta_event_id = konectaEventId;
      user_id = getTupleValueAsText(eventItem, "user_id");
      event_id = getTupleValueAsText(eventItem, "event_id");
      event_type = getTupleValueAsText(eventItem, "event_type");
      status = getTupleValueAsText(eventItem, "status");
      expertise = getTupleValueAsText(eventItem, "expertise");
      price_token = getTupleValueAsText(eventItem, "price_token");
      token_amount = amount;
      categories = getTextArrayFromAttributeDataValueArray(getTupleValue(eventItem, "categories"));
      consultations = getTextArrayFromAttributeDataValueArray(getTupleValue(eventItem, "consultations"));
      interests = getTextArrayFromAttributeDataValueArray(getTupleValue(eventItem, "interests"));
      metadata = getTupleArrayFromAttributeDataValueArray(getTupleValue(eventItem, "metadata"));
    });

    return eventBuffer;
  };

  // Function to get event details
  public func getEventDetails(eventId : Text) : async ArgumentTypes.EventProtocolCanisterPayload {

    let eventCanisterActor = actor (Constants.EventCanister) : actor {
      getEventDetailsWithUserData : (eventId : Text) -> async ArgumentTypes.EventProtocolCanisterPayload;
    };

    let eventData = await eventCanisterActor.getEventDetailsWithUserData(eventId);
    return eventData;
  };

  // Helper function to handle the feed buffer
  private func handleFeedBuffer(konectaEventId : Text, eventItem : [(Text, Database.AttributeDataValue)], eventBuffer : Buffer.Buffer<ArgumentTypes.FeedResponsePayload>) : async [ArgumentTypes.FeedResponsePayload] {

    let eventId = getTupleValueAsText(eventItem, "event_id");
    let eventData = await getEventDetails(eventId);

    eventBuffer.add({
      konecta_event_id = konectaEventId;
      user_id = getTupleValueAsText(eventItem, "user_id");
      event_id = eventId;
      coverphoto = eventData.coverphoto;
      name = eventData.name;
      description = eventData.description;
      location = eventData.location;
      start_date = eventData.start_date;
      end_date = eventData.end_date;
      language = eventData.language;
      status = eventData.status;
      userData = eventData.userData;
      event_type = getTupleValueAsText(eventItem, "event_type");
      expertise = getTupleValueAsText(eventItem, "expertise");
      price_token = getTupleValueAsText(eventItem, "price_token");
      token_amount = getFloatFromAttributeDataValueArray(getTupleValue(eventItem, "token_amount"));
      categories = getTextArrayFromAttributeDataValueArray(getTupleValue(eventItem, "categories"));
      consultations = getTextArrayFromAttributeDataValueArray(getTupleValue(eventItem, "consultations"));
      interests = getTextArrayFromAttributeDataValueArray(getTupleValue(eventItem, "interests"));
      eventMetadata = eventData.metadata;
      konectaMetadata = getTupleArrayFromAttributeDataValueArray(getTupleValue(eventItem, "metadata"));
    });

    return Buffer.toArray(eventBuffer);
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

  // Function to create event metadata
  public func createEventMetadataMethod(creatorPrincipal : Principal, userIdOfApplicant : Principal, userCanisterId : Text, payload : ArgumentTypes.FeedResponsePayload, canistergeekLogger : Canistergeek.Logger) : async Result.Result<Text, Text> {
    let userCanister = actor (userCanisterId) : UserCanisterType;
    Debug.print(debug_show ("User canister --->" # userCanisterId));

    let calendarObject = {
      name = payload.name;
      description = payload.description;
    };
    Debug.print(debug_show ("Calendar object --->" # debug_show (calendarObject)));
    canistergeekLogger.logMessage("Calendar object --->" # debug_show (calendarObject));

    let calendarId = await userCanister.upsertCalendarData(Principal.toText(userIdOfApplicant), "", calendarObject);
    Debug.print(debug_show ("Calendar id --->" # debug_show (calendarId)));
    canistergeekLogger.logMessage("Calendar id --->" # debug_show (calendarId));

    let eventObject = {
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

  public func addEventAttendee(creatorPrincipal : Principal, userIdOfApplicant : Principal, action : ArgumentTypes.EventAttendeeActions, feedData : ArgumentTypes.FeedResponsePayload, canistergeekLogger : Canistergeek.Logger) : async Result.Result<Bool, Text> {

    let eventCanisterActor = actor (Constants.EventCanister) : EventCanisterType;
    try {
      // Get the user's canister ID
      let userCanisterId = await getUserCanisterId(Principal.toText(userIdOfApplicant));
      canistergeekLogger.logMessage("User Canister Id --->" # debug_show (userCanisterId));

      // Create event metadata
      let eventMetadataId = await createEventMetadataMethod(creatorPrincipal, userIdOfApplicant, userCanisterId, feedData, canistergeekLogger);
      canistergeekLogger.logMessage("Event Metadata Id --->" # debug_show (eventMetadataId));

      let eventAttendeeObject = {
        event_id = feedData.event_id;
        invitee_user_id = userIdOfApplicant;
        action = action;
        timestamp = Int.abs(Time.now());
      };
      let addEventAttendeeResponse = await eventCanisterActor.addEventAttendee(eventAttendeeObject);
      canistergeekLogger.logMessage("Add Event Attendee To Event Attendee Table --->" # debug_show (addEventAttendeeResponse));

      switch (addEventAttendeeResponse) {
        case (#ok(response)) {
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
