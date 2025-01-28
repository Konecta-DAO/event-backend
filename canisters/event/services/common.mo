import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Text "mo:base/Text";
import D3 "mo:d3storage/D3";

import ArgumentTypes "../types/argumentTypes";
import Constants "../utils/constants";
import {
  getTupleArrayFromAttributeDataValueArray;
  getTupleValue;
  getTupleValueAsText;
  textToNat;
} "../utils/helper";
module {

  public let initialEventObjectWithUserData = {
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
    userData = {
      id = "";
      principal_id = "";
      canister_id = "";
      firstname = "";
      lastname = "";
      username = "";
      email = "";
      bio = "";
      categories = [];
      profilepic = "";
      coverphoto = "";
      country = "";
      timezone = "";
    };
  };

  public type UserCanisterType = actor {
    createEventMetaData : (metadata : ArgumentTypes.EventMetadataPayload) -> async Result.Result<Text, Text>;
    updateEventMetaData : (eventMetadataId : Text, metadata : ArgumentTypes.EventMetadataPayload) -> async Text;
    upsertCalendarData : (userPrincipal : Text, calendarId : Text, calendarData : ArgumentTypes.CalendarRequestPayload) -> async Text;
    getCalendarId : (eventId : Text) -> async Text;
    getEventMetadataId : (eventId : Text, calendarId : Text) -> async Text;
    getUserForEventCanister : shared query (userPrincipal : Text) -> async ArgumentTypes.UserResponsePayload;
  };

  public type IndexActor = actor {
    getUserCanisterByUserPrincipal : shared query (principal : Text) -> async Text;
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

  public func getFile(fileId : Text, d3 : D3.D3) : D3.GetFileOutputType {
    D3.getFile({
      d3;
      getFileInput = {
        fileId = fileId;
      };
    });
  };

  public func transformGetAllEventsResponse(eventResponse : Database.ScanOutputType) : Result.Result<[ArgumentTypes.EventResponsePayload], [Text]> {
    let eventBuffer = Buffer.Buffer<ArgumentTypes.EventResponsePayload>(0);
    var eventsArray : [ArgumentTypes.EventResponsePayload] = [];
    switch (eventResponse) {
      case (#ok(eventData)) {
        for (itemObject in eventData.vals()) {
          let eventId = itemObject.id;
          let eventItem = itemObject.item;

          eventsArray := handleEventBuffer(eventId, eventItem, eventBuffer);
        };

        #ok(eventsArray);
      };

      case (#err(error)) #err(error);

    };

  };

  public func transformGetEventResponse(eventResponse : Database.GetItemByIdOutputType) : Result.Result<ArgumentTypes.EventResponsePayload, [Text]> {
    let eventBuffer = Buffer.Buffer<ArgumentTypes.EventResponsePayload>(0);

    switch (eventResponse) {
      case (#ok(eventData)) {

        let eventId = eventData.id;
        let eventItem = eventData.item;

        let event = handleEventBuffer(eventId, eventItem, eventBuffer)[0];

        #ok(event);
      };

      case (#err(error)) #err(error);

    };

  };

  public func transformGetAllEventsResponseAsync(eventResponse : Database.ScanOutputType) : async Result.Result<[ArgumentTypes.EventWithUserDataPayload], [Text]> {
    let eventBuffer = Buffer.Buffer<ArgumentTypes.EventWithUserDataPayload>(0);
    var eventsArray : [ArgumentTypes.EventWithUserDataPayload] = [];
    switch (eventResponse) {
      case (#ok(eventData)) {
        for (itemObject in eventData.vals()) {
          let eventId = itemObject.id;
          let eventItem = itemObject.item;

          eventsArray := await handleEventBufferWithUserData(eventId, eventItem, eventBuffer);
        };

        #ok(eventsArray);
      };

      case (#err(error)) #err(error);

    };

  };

  public func transformGetEventResponseAsync(eventResponse : Database.GetItemByIdOutputType) : async Result.Result<ArgumentTypes.EventWithUserDataPayload, [Text]> {
    let eventBuffer = Buffer.Buffer<ArgumentTypes.EventWithUserDataPayload>(0);

    switch (eventResponse) {
      case (#ok(eventData)) {

        let eventId = eventData.id;
        let eventItem = eventData.item;

        let event = (await handleEventBufferWithUserData(eventId, eventItem, eventBuffer))[0];

        #ok(event);
      };

      case (#err(error)) #err(error);

    };

  };

  private func handleEventBuffer(eventId : Text, eventItem : [(Text, Database.AttributeDataValue)], eventBuffer : Buffer.Buffer<ArgumentTypes.EventResponsePayload>) : [ArgumentTypes.EventResponsePayload] {

    let userId = getTupleValueAsText(eventItem, "user_id");

    eventBuffer.add({
      event_id = eventId;
      coverphoto = getTupleValueAsText(eventItem, "coverphoto");
      user_id = userId;
      name = getTupleValueAsText(eventItem, "name");
      description = getTupleValueAsText(eventItem, "description");
      location = getTupleValueAsText(eventItem, "location");
      start_date = textToNat(getTupleValueAsText(eventItem, "start_date"));
      end_date = textToNat(getTupleValueAsText(eventItem, "end_date"));
      language = getTupleValueAsText(eventItem, "language");
      status = getTupleValueAsText(eventItem, "status");
      metadata = getTupleArrayFromAttributeDataValueArray(getTupleValue(eventItem, "metadata"));
    });

    return Buffer.toArray(eventBuffer);
  };

  private func handleEventBufferWithUserData(eventId : Text, eventItem : [(Text, Database.AttributeDataValue)], eventBuffer : Buffer.Buffer<ArgumentTypes.EventWithUserDataPayload>) : async [ArgumentTypes.EventWithUserDataPayload] {

    let userId = getTupleValueAsText(eventItem, "user_id");
    let userData = await getUserDetails(userId);

    eventBuffer.add({
      event_id = eventId;
      coverphoto = getTupleValueAsText(eventItem, "coverphoto");
      user_id = userId;
      name = getTupleValueAsText(eventItem, "name");
      description = getTupleValueAsText(eventItem, "description");
      location = getTupleValueAsText(eventItem, "location");
      start_date = textToNat(getTupleValueAsText(eventItem, "start_date"));
      end_date = textToNat(getTupleValueAsText(eventItem, "end_date"));
      language = getTupleValueAsText(eventItem, "language");
      status = getTupleValueAsText(eventItem, "status");
      metadata = getTupleArrayFromAttributeDataValueArray(getTupleValue(eventItem, "metadata"));
      userData = userData;
    });

    return Buffer.toArray(eventBuffer);
  };

  // Function to get the user canister ID
  public func getUserCanisterId(userId : Text) : async Text {
    let indexActor = actor (Constants.IndexCanister) : IndexActor;
    return await indexActor.getUserCanisterByUserPrincipal(userId);
  };

  public func getUserDetails(userId : Text) : async ArgumentTypes.UserResponsePayload {

    let userCanisterId = await getUserCanisterId(userId);

    let userCanisterActor = actor (userCanisterId) : UserCanisterType;
    let userData = await userCanisterActor.getUserForEventCanister(userId);

    return userData;
  };

};
