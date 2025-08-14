import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Canistergeek "mo:canistergeek/canistergeek";
import Text "mo:base/Text";
import Map "mo:map/Map";

import ArgumentTypes "../../../types/argumentTypes";
import Constants "../../../utils/constants";
import HelperService "../../../utils/helper";
import CommonService "../../shared/common";
import SharedService "../../shared/shared";

module {
  public func insertUserFeedback(
    userPrincipal : Principal,
    payload : ArgumentTypes.UserFeedbackRequestPayload,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<ArgumentTypes.CreateUserFeedbackResponsePayload, Text> {

    let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;
    let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(payload.event_id);

    if (Text.size(eventData.event_id) == 0) {
      Debug.print("Failed to fetch event data --->" # payload.event_id);
      canistergeekLogger.logMessage("Failed to fetch event data --->" # payload.event_id);
      return #err("Failed to fetch event data.");
    };

    let rating = HelperService.initializeNatField(payload.rating, 0);
    let reason = HelperService.initializeTextField(payload.reason, "");
    let successful = CommonService.getFeedbackStatusType(?payload.successful);
    let recordingLink = HelperService.initializeTextField(payload.recording_link, "");

    var userType = CommonService.getUserType(eventData, Principal.toText(userPrincipal));

    let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
      ("event_id", #text(payload.event_id)),
      ("user_id", #text(Principal.toText(userPrincipal))),
      ("firstname", #text(payload.firstname)),
      ("lastname", #text(payload.lastname)),
      ("username", #text(payload.username)),
      ("email", #text(payload.email)),
      ("timezone", #text(payload.timezone)),
      ("user_type", #text(userType)),
      ("successful", #text(successful)),
      ("reason", #text(reason)),
      ("rating", #nat(rating)),
      ("recording_link", #text(recordingLink)),
    ];
    canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

    let item = await Database.createItem({
      createItemInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.UserFeedbackTable;
        attributeDataValues = attributeDataValues;
      };
      alfangoDB = alfangoDB;
    });
    Debug.print("Add user feedback --->" # debug_show (item));
    canistergeekLogger.logMessage("Add user feedback --->" # debug_show (item));

    switch (item) {
      case (#ok(feedback)) {
        Debug.print("Feedback response --->" # debug_show (feedback));

        let konectaEventDataForResponse : ArgumentTypes.EventResponsePayload = {
          konecta_event_id = ""; // This field is obsolete
          user_id = eventData.user_id;
          event_id = eventData.event_id;
          event_name = eventData.name;
          event_description = eventData.description;
          subaccount_id_hex = eventData.subaccount_id_hex;
          event_type = eventData.event_type;
          status = eventData.status;
          start_date = eventData.start_date;
          end_date = eventData.end_date;
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
          metadata = eventData.metadata;
        };

        let createFeedbackResponse = {
          feedbackId = feedback.id;
          konectaEventData = konectaEventDataForResponse;
        };
        #ok(createFeedbackResponse);
      };
      case (#err(error)) {
        Debug.print("Add user feedback error --->" # debug_show (error));
        canistergeekLogger.logMessage("Add user feedback error --->" # debug_show (error));
        #err(HelperService.textArrayToString(error));
      };
    };
  };

  public func insertMultipleUserFeedback(
    userPrincipal : Principal,
    userFeedbackArr : [ArgumentTypes.UserFeedbackRequestPayload],
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<[ArgumentTypes.CreateUserFeedbackResponsePayload], Text> {
    let errorBuffer = Buffer.Buffer<Text>(0);
    let successBuffer = Buffer.Buffer<ArgumentTypes.CreateUserFeedbackResponsePayload>(0);
    let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;

    for (payload in userFeedbackArr.vals()) {
      let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(payload.event_id);

      if (Text.size(eventData.event_id) == 0) {
        errorBuffer.add("Failed to fetch event data for event_id: " # payload.event_id);
      };

      let rating = HelperService.initializeNatField(payload.rating, 0);
      let reason = HelperService.initializeTextField(payload.reason, "");
      let successful = CommonService.getFeedbackStatusType(?payload.successful);
      let recordingLink = HelperService.initializeTextField(payload.recording_link, "");
      var userType = CommonService.getUserType(eventData, Principal.toText(userPrincipal));

      let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
        ("event_id", #text(payload.event_id)),
        ("user_id", #text(Principal.toText(userPrincipal))),
        ("firstname", #text(payload.firstname)),
        ("lastname", #text(payload.lastname)),
        ("username", #text(payload.username)),
        ("email", #text(payload.email)),
        ("timezone", #text(payload.timezone)),
        ("user_type", #text(userType)),
        ("successful", #text(successful)),
        ("reason", #text(reason)),
        ("rating", #nat(rating)),
        ("recording_link", #text(recordingLink)),
      ];
      canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

      let item = await Database.createItem({
        createItemInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.UserFeedbackTable;
          attributeDataValues = attributeDataValues;
        };
        alfangoDB = alfangoDB;
      });
      Debug.print("Add user feedback --->" # debug_show (item));
      canistergeekLogger.logMessage("Add user feedback --->" # debug_show (item));

      switch (item) {
        case (#ok(feedback)) {
          Debug.print("Feedback response --->" # debug_show (feedback));

          let konectaEventDataForResponse : ArgumentTypes.EventResponsePayload = {
            konecta_event_id = "";
            user_id = eventData.user_id;
            event_id = eventData.event_id;
            event_name = eventData.name;
            event_description = eventData.description;
            subaccount_id_hex = eventData.subaccount_id_hex;
            event_type = eventData.event_type;
            status = eventData.status;
            start_date = eventData.start_date;
            end_date = eventData.end_date;
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
            metadata = eventData.metadata;
          };

          successBuffer.add({
            feedbackId = feedback.id;
            konectaEventData = konectaEventDataForResponse;
          });
        };
        case (#err(error)) {
          Debug.print("Add user feedback error --->" # debug_show (error));
          canistergeekLogger.logMessage("Add user feedback error --->" # debug_show (error));
          errorBuffer.add(HelperService.textArrayToString(error));
        };
      };
    };

    let errorArray = Buffer.toArray(errorBuffer);
    if (Array.size(errorArray) > 0) {
      #err(HelperService.textArrayToString(errorArray));
    } else {
      let successArray = Buffer.toArray(successBuffer);
      #ok(successArray);
    };
  };
};
