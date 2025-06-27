import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Text "mo:base/Text";
import D3 "mo:d3storage/D3";
import SharedTypes "../../shared/types";
import SharedServices "../../shared/services";
import ArgumentTypes "../types/argumentTypes";
import {
  getTupleArrayFromAttributeDataValueArray;
  getTupleValue;
  getTupleValueAsText;
  textToNat;
} "../../shared/common_utils/helper";

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

  public func getEventStatus(action : SharedTypes.EventStatus, initialValue : Text) : Text {
    var status = initialValue;

    switch (action) {
      case (#Created) status := SharedTypes.EventStatus.Created;
      case (#Canceled) status := SharedTypes.EventStatus.Canceled;
    };

    return status;
  };

  public func getActionType(action : SharedTypes.EventAttendeeActions) : Text {
    var actionType = "";

    switch (action) {
      case (#Applied) actionType := SharedTypes.EventAttendeeStatus.Applied;
      case (#Joined) actionType := SharedTypes.EventAttendeeStatus.Joined;
      case (#Invited) actionType := SharedTypes.EventAttendeeStatus.Invited;
      case (#Accepted) actionType := SharedTypes.EventAttendeeStatus.Accepted;
      case (#Declined) actionType := SharedTypes.EventAttendeeStatus.Declined;
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

  public func transformGetAllEventsResponseAsync(eventResponse : Database.ScanOutputType) : async Result.Result<[SharedTypes.EventDetailsPayload], [Text]> {
    let eventBuffer = Buffer.Buffer<SharedTypes.EventDetailsPayload>(0);
    var eventsArray : [SharedTypes.EventDetailsPayload] = [];
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

  public func transformGetEventResponseAsync(eventResponse : Database.GetItemByIdOutputType) : async Result.Result<SharedTypes.EventDetailsPayload, [Text]> {
    let eventBuffer = Buffer.Buffer<SharedTypes.EventDetailsPayload>(0);

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

  private func handleEventBufferWithUserData(eventId : Text, eventItem : [(Text, Database.AttributeDataValue)], eventBuffer : Buffer.Buffer<SharedTypes.EventDetailsPayload>) : async [SharedTypes.EventDetailsPayload] {

    let userId = getTupleValueAsText(eventItem, "user_id");
    let userData = await SharedServices.getUserDetails(userId);

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
};
