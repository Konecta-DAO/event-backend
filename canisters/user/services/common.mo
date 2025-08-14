import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";

import ArgumentTypes "../types/argumentTypes";
import Constants "../utils/constants";
import {
  getTextArrayFromAttributeDataValueArray;
  getTupleValue;
  getTupleValueAsText;
  textToNat;
} "../utils/helper";

module {

  public let initialUserObject = {
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
    introduction_video_link = "";
    country = "";
    timezone = "";
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

  public func getFile(fileId : Text, d3 : D3.D3) : D3.GetFileOutputType {
    D3.getFile({
      d3;
      getFileInput = {
        fileId = fileId;
      };
    });
  };

  public func transformGetAllEventMetadataResponse(eventResponse : Database.ScanOutputType) : Result.Result<[ArgumentTypes.EventMetadataResponsePayload], [Text]> {
    let eventMetadataBuffer = Buffer.Buffer<ArgumentTypes.EventMetadataResponsePayload>(0);
    var eventMetadataArray : [ArgumentTypes.EventMetadataResponsePayload] = [];
    switch (eventResponse) {
      case (#ok(eventData)) {
        for (itemObject in eventData.vals()) {
          let eventMetadataId = itemObject.id;
          let eventMetadataItem = itemObject.item;

          eventMetadataArray := Buffer.toArray(handleEventMetadataBuffer(eventMetadataId, eventMetadataItem, eventMetadataBuffer));
        };

        #ok(eventMetadataArray);
      };

      case (#err(error)) #err(error);

    };

  };

  public func transformGetEventMetadataResponse(eventResponse : Database.GetItemByIdOutputType) : Result.Result<ArgumentTypes.EventMetadataResponsePayload, [Text]> {
    let eventBuffer = Buffer.Buffer<ArgumentTypes.EventMetadataResponsePayload>(0);

    switch (eventResponse) {
      case (#ok(eventData)) {

        let eventMetadataId = eventData.id;
        let eventMetadataItem = eventData.item;

        let event = Buffer.toArray(handleEventMetadataBuffer(eventMetadataId, eventMetadataItem, eventBuffer))[0];

        #ok(event);
      };

      case (#err(error)) #err(error);

    };

  };

  private func handleEventMetadataBuffer(eventMetadataId : Text, eventMetadataItem : [(Text, Database.AttributeDataValue)], eventMetadataBuffer : Buffer.Buffer<ArgumentTypes.EventMetadataResponsePayload>) : Buffer.Buffer<ArgumentTypes.EventMetadataResponsePayload> {
    eventMetadataBuffer.add({
      event_metadata_id = eventMetadataId;
      calendar_id = getTupleValueAsText(eventMetadataItem, "calendar_id");
      event_id = getTupleValueAsText(eventMetadataItem, "event_id");
      name = getTupleValueAsText(eventMetadataItem, "name");
      categories = getTextArrayFromAttributeDataValueArray(getTupleValue(eventMetadataItem, "categories"));
      start_date = textToNat(getTupleValueAsText(eventMetadataItem, "start_date"));
      end_date = textToNat(getTupleValueAsText(eventMetadataItem, "end_date"));
      interests = getTextArrayFromAttributeDataValueArray(getTupleValue(eventMetadataItem, "interests"));
      status = getTupleValueAsText(eventMetadataItem, "status");
      created_by = getTupleValueAsText(eventMetadataItem, "created_by");
    });

    return eventMetadataBuffer;
  };

  public func transformUserResponse(userResponse : Database.ScanOutputType) : ?ArgumentTypes.UserPayload {

    switch (userResponse) {
      case (#ok(userData)) {

        if (Array.size(userData) > 0) {

          let userId = userData[0].id;
          let userItem = userData[0].item;

          let canister_id = Principal.fromText(getTupleValueAsText(userItem, "canister_id"));
          let profilepic = getTupleValueAsText(userItem, "profilepic");
          let coverphoto = getTupleValueAsText(userItem, "coverphoto");

          var userProfilePicUrl = "";

          if (Text.size(profilepic) > 0) {
            userProfilePicUrl := "https://" # Principal.toText(canister_id) # ".raw.icp0.io/d3?file_id=" # profilepic;
          };

          var userCoverPicUrl = "";

          if (Text.size(coverphoto) > 0) {
            userCoverPicUrl := "https://" # Principal.toText(canister_id) # ".raw.icp0.io/d3?file_id=" # coverphoto;
          };

          let user = {
            principal_id = Principal.fromText(getTupleValueAsText(userItem, "principal_id"));
            canister_id = canister_id;
            firstname = getTupleValueAsText(userItem, "firstname");
            lastname = getTupleValueAsText(userItem, "lastname");
            username = getTupleValueAsText(userItem, "username");
            email = getTupleValueAsText(userItem, "email");
            bio = getTupleValueAsText(userItem, "bio");
            categories = getTextArrayFromAttributeDataValueArray(getTupleValue(userItem, "categories"));
            profilepic = getTupleValueAsText(userItem, "profilepic");
            coverphoto = getTupleValueAsText(userItem, "coverphoto");
            introduction_video_link = getTupleValueAsText(userItem, "introduction_video_link");
            country = getTupleValueAsText(userItem, "country");
            timezone = getTupleValueAsText(userItem, "timezone");
          };

          return ?user;

        } else {
          return null;
        };
      };

      case (#err(_error)) null;

    };

  };
};
