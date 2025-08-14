import Database "mo:alfangodb/AlfangoDB";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Text "mo:base/Text";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";
import HashMap "mo:base/HashMap";
import ArgumentTypes "../types/argumentTypes";
import Constants "../utils/constants";
import Helper "../utils/helper";
import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";
import OutputTypes "mo:alfangodb/AlfangoDB/types/output";
import Iter "mo:base/Iter";

import {
  getTupleArrayFromAttributeDataValueArray;
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
      principal_id = "";
      canister_id = "";
      firstname = "";
      lastname = "";
      username = "";
      email = "";
      bio = "";
      categories = [] : [Text];
      profilepic = "";
      coverphoto = "";
      introduction_video_link = "";
      country = "";
      timezone = "";
    };

    event_type = "";
    participation_type = "";
    categories = [];
    consultations = [];
    expertise = "";
    price_token = "";
    token_amount = 0.0;
    interests = [];
    showcase_link = "";
    recording_visibility = "";
    is_recording_available = false;
    subaccount_id_hex = "";
    subaccount_id_index = 0;
  };

  public type UserCanisterType = actor {
    createEventMetaData : (metadata : ArgumentTypes.EventMetadataPayload) -> async Result.Result<Text, Text>;

    updateEventMetaData : (eventMetadataId : Text, metadata : ArgumentTypes.UpdateEventMetadataPayload) -> async Result.Result<Text, Text>;

    upsertCalendarData : (calendarId : Text, calendarData : ArgumentTypes.CalendarRequestPayload) -> async Text;

    getCalendarId : shared query () -> async Text;

    getEventMetadataId : (eventId : Text, calendarId : Text) -> async Text;

    getUserForEventCanister : shared query (userPrincipal : Text) -> async ArgumentTypes.UserResponsePayload;

    updateEventMetadataForAttendee : ({
      eventId : Text;
      eventMetadataPayload : ArgumentTypes.AttendeeEventMetadataRequestPayload;
    }) -> async Result.Result<Text, Text>;
  };

  public type IndexActor = actor {
    getUserCanisterByUserPrincipal : shared query (principal : Text) -> async Text;
    getUserCanistersByPrincipal : shared query (principals : [Text]) -> async [ArgumentTypes.CanisterMapPayload];
  };

  public func getEventStatus(action : ArgumentTypes.EventStatus, initialValue : Text) : Text {
    var status = initialValue;

    switch (action) {
      case (#Draft) status := Constants.EventStatus.Draft;
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
      case (#Withdrawn) actionType := Constants.EventAttendeeStatus.Withdrawn;
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

  public func transformGetEventResponse(eventResponse : Database.GetItemByIdOutputType) : Result.Result<ArgumentTypes.EventResponsePayload, [Text]> {
    let eventBuffer = Buffer.Buffer<ArgumentTypes.EventResponsePayload>(0);

    switch (eventResponse) {
      case (#ok(eventData)) {

        let eventId = eventData.id;
        let eventItem = eventData.item;

        handleEventBuffer(eventId, eventItem, eventBuffer);

        let eventArray = Buffer.toArray(eventBuffer);

        #ok(eventArray[0]);
      };

      case (#err(error)) #err(error);
    };
  };

  public func transformGetEventResponseAsync(
    eventResponse : Database.GetItemByIdOutputType
  ) : async Result.Result<ArgumentTypes.EventWithUserDataPayload, [Text]> {

    switch (eventResponse) {
      case (#err(error)) {
        return #err(error);
      };
      case (#ok(eventData)) {
        let eventId = eventData.id;
        let eventItem = eventData.item;

        let eventBuffer = Buffer.Buffer<ArgumentTypes.EventWithUserDataPayload>(1);

        let eventArray = await handleEventBufferWithUserData(
          eventId,
          eventItem,
          eventBuffer,
        );

        if (eventArray.size() == 0) {
          return #err(["Failed to transform event data"]);
        };

        return #ok(eventArray[0]);
      };
    };
  };

  public func handleEventBuffer(eventId : Text, eventItem : [(Text, Database.AttributeDataValue)], eventBuffer : Buffer.Buffer<ArgumentTypes.EventResponsePayload>) : () {

    let itemMap = Helper.attributeArrayToHashMap(eventItem);

    eventBuffer.add({
      event_id = eventId;
      user_id = Helper.getAttributeFromMapAsText(itemMap, "user_id");
      coverphoto = Helper.getAttributeFromMapAsText(itemMap, "coverphoto");
      name = Helper.getAttributeFromMapAsText(itemMap, "name");
      description = Helper.getAttributeFromMapAsText(itemMap, "description");
      location = Helper.getAttributeFromMapAsText(itemMap, "location");
      start_date = textToNat(Helper.getAttributeFromMapAsText(itemMap, "start_date"));
      end_date = textToNat(Helper.getAttributeFromMapAsText(itemMap, "end_date"));
      language = Helper.getAttributeFromMapAsText(itemMap, "language");
      status = Helper.getAttributeFromMapAsText(itemMap, "status");
      metadata = getTupleArrayFromAttributeDataValueArray(itemMap.get("metadata"));

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
      subaccount_id_index = textToNat(Helper.getAttributeFromMapAsText(itemMap, "subaccount_id_index"));
    });
  };

  private func handleEventBufferWithUserData(
    eventId : Text,
    eventItem : [(Text, Database.AttributeDataValue)],
    eventBuffer : Buffer.Buffer<ArgumentTypes.EventWithUserDataPayload>,
  ) : async [ArgumentTypes.EventWithUserDataPayload] {

    let itemMap = Helper.attributeArrayToHashMap(eventItem);

    let userId = Helper.getAttributeFromMapAsText(itemMap, "user_id");
    let userData = await getUserDetails(userId);

    eventBuffer.add({
      event_id = eventId;
      user_id = userId;
      coverphoto = Helper.getAttributeFromMapAsText(itemMap, "coverphoto");
      name = Helper.getAttributeFromMapAsText(itemMap, "name");
      description = Helper.getAttributeFromMapAsText(itemMap, "description");
      location = Helper.getAttributeFromMapAsText(itemMap, "location");
      start_date = textToNat(Helper.getAttributeFromMapAsText(itemMap, "start_date"));
      end_date = textToNat(Helper.getAttributeFromMapAsText(itemMap, "end_date"));
      language = Helper.getAttributeFromMapAsText(itemMap, "language");
      status = Helper.getAttributeFromMapAsText(itemMap, "status");
      metadata = getTupleArrayFromAttributeDataValueArray(itemMap.get("metadata"));
      userData = userData;

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
      subaccount_id_index = textToNat(Helper.getAttributeFromMapAsText(itemMap, "subaccount_id_index"));
    });

    return Buffer.toArray(eventBuffer);
  };

  public func getUserCanisterId(
    userId : Text
  ) : async Text {
    let indexActor = actor (Constants.IndexCanister) : IndexActor;
    let freshCanisterId = await indexActor.getUserCanisterByUserPrincipal(userId);
    return freshCanisterId;
  };

  public func getUserDetails(
    userId : Text
  ) : async ArgumentTypes.UserResponsePayload {

    let userCanisterId = await getUserCanisterId(userId);

    if (Text.size(userCanisterId) == 0) {
      return initialEventObjectWithUserData.userData;
    };

    let userCanisterActor = actor (userCanisterId) : UserCanisterType;
    let userData = await userCanisterActor.getUserForEventCanister(userId);

    return userData;
  };

  public func createEventWithUserDataObjectFromResponse(eventData : ArgumentTypes.EventResponsePayload, userData : ArgumentTypes.UserResponsePayload) : ArgumentTypes.EventWithUserDataPayload {
    return {
      coverphoto = eventData.coverphoto;
      description = eventData.description;
      end_date = eventData.end_date;
      language = eventData.language;
      location = eventData.location;
      metadata = eventData.metadata;
      name = eventData.name;
      start_date = eventData.start_date;
      status = eventData.status;
      user_id = eventData.user_id;
      event_id = eventData.event_id;
      userData = userData;

      event_type = eventData.event_type;
      participation_type = eventData.participation_type;
      categories = eventData.categories;
      consultations = eventData.consultations;
      expertise = eventData.expertise;
      price_token = eventData.price_token;
      token_amount = eventData.token_amount;
      interests = eventData.interests;
      showcase_link = eventData.showcase_link;
      recording_visibility = eventData.recording_visibility;
      is_recording_available = eventData.is_recording_available;
      subaccount_id_hex = eventData.subaccount_id_hex;
      subaccount_id_index = eventData.subaccount_id_index;
    };
  };

  public func getTotalRecords(tableName : Text, filterExpressions : [SearchTypes.FilterExpressionType], alfangoDB : Database.AlfangoDB) : Nat {
    var totalRecords : Nat = 0;

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
      case (#ok(idsResponse)) totalRecords := Array.size(idsResponse.ids);
      case (#err(_error)) totalRecords := 0;
    };

    return totalRecords;
  };

  public func transformItemToEventPayload(eventId : Text, itemMap : HashMap.HashMap<Text, Database.AttributeDataValue>) : ArgumentTypes.EventResponsePayload {
    return {
      event_id = eventId;
      user_id = Helper.getAttributeFromMapAsText(itemMap, "user_id");
      coverphoto = Helper.getAttributeFromMapAsText(itemMap, "coverphoto");
      name = Helper.getAttributeFromMapAsText(itemMap, "name");
      description = Helper.getAttributeFromMapAsText(itemMap, "description");
      location = Helper.getAttributeFromMapAsText(itemMap, "location");
      start_date = textToNat(Helper.getAttributeFromMapAsText(itemMap, "start_date"));
      end_date = textToNat(Helper.getAttributeFromMapAsText(itemMap, "end_date"));
      language = Helper.getAttributeFromMapAsText(itemMap, "language");
      status = Helper.getAttributeFromMapAsText(itemMap, "status");
      metadata = getTupleArrayFromAttributeDataValueArray(itemMap.get("metadata"));
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
      subaccount_id_index = textToNat(Helper.getAttributeFromMapAsText(itemMap, "subaccount_id_index"));
    };
  };
};
