import Database "mo:alfangodb/AlfangoDB";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import HttpTypes "../../../library/emailLibrary/email/src/email_backend/http.types";
import ArgumentTypes "../../../types/argumentTypes";
import Constants "../../../utils/constants";
import HelperService "../../../utils/helper";
import UserFeedbackReadService "../../email/user_feedback/read";
import UserRefundService "../../payment/userRefund";
import UserTransferService "../../payment/userTransfer";
import CommonService "../../shared/common";
import SharedService "../../shared/shared";

module {
  public func insertExpertFeedback(
    canisterPrincipal : Principal,
    payload : ArgumentTypes.ExpertFeedbackRequestPayload,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
    transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload,
  ) : async Result.Result<Text, Text> {

    let reason = HelperService.initializeTextField(payload.reason, "");
    let agreeWithUserFeedback = HelperService.initializeTextField(?CommonService.getFeedbackStatusType(payload.agreeWithUserFeedback), "");
    let userFeedbackId = HelperService.initializeTextField(payload.user_feedback_id, "");
    let remitterFeedbackMissing = payload.remitter_feedback_missing;
    let userId = HelperService.initializeTextField(payload.user_id, "");
    let transferOrRefund = HelperService.initializeTextField(?CommonService.getTransferOrRefundType(payload.transfer_or_refund), "");
    var eventRecordingLink = HelperService.initializeTextField(payload.event_recording_link, "");

    let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
      ("event_id", #text(payload.event_id)),
      ("remitter_feedback_missing", #bool(remitterFeedbackMissing)),
      ("user_feedback_id", #text(userFeedbackId)),
      ("agreeWithUserFeedback", #text(agreeWithUserFeedback)),
      ("user_id", #text(userId)),
      ("transfer_or_refund", #text(transferOrRefund)),
      ("event_recording_link", #text(eventRecordingLink)),
      ("reason", #text(reason)),
    ];
    canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

    let item = await Database.createItem({
      createItemInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.ExpertFeedbackTable;
        attributeDataValues = attributeDataValues;
      };
      alfangoDB = alfangoDB;
    });
    canistergeekLogger.logMessage("Add expert feedback response --->" # debug_show (item));

    switch (item) {
      case (#ok(feedback)) {
        let creatorFeedback = await UserFeedbackReadService.getAccepteeOROfferCreatorFeedbackForEvent(
          payload.event_id,
          alfangoDB,
          canistergeekLogger,
        );
        canistergeekLogger.logMessage("Creator Feedback --->" # debug_show (creatorFeedback));

        if (Text.size(creatorFeedback.recording_link) > 0) {
          eventRecordingLink := creatorFeedback.recording_link;
        };

        let creatorFeedbackObject = {
          email = creatorFeedback.email;
          event_id = creatorFeedback.event_id;
          firstname = creatorFeedback.firstname;
          id = creatorFeedback.id;
          lastname = creatorFeedback.lastname;
          rating = creatorFeedback.rating;
          reason = creatorFeedback.reason;
          recording_link = eventRecordingLink;
          successful = creatorFeedback.successful;
          timezone = creatorFeedback.timezone;
          user_id = creatorFeedback.user_id;
          user_type = creatorFeedback.user_type;
          username = creatorFeedback.username;
        };

        if (not remitterFeedbackMissing) {
          let userFeedbackResponse = UserFeedbackReadService.getUserFeedback(userFeedbackId, alfangoDB, canistergeekLogger);

          switch (userFeedbackResponse) {
            case (#ok(userFeedback)) {
              let emailPayload = {
                user_feedback = userFeedback;
                creator_feedback = creatorFeedbackObject;
                expert_feedback_id = feedback.id;
                remitter_feedback_missing = remitterFeedbackMissing;
              };

              if (userFeedback.successful != agreeWithUserFeedback) {
                let icrc1TransferResponse = await UserRefundService.refundAmountForCalendarEventRemoval(Principal.fromText(userFeedback.user_id), userFeedback.event_id, canisterPrincipal, alfangoDB, canistergeekLogger, emailPayload, transform);
                canistergeekLogger.logMessage("Icrc1TransferResponse --->" # debug_show (icrc1TransferResponse));
                switch (icrc1TransferResponse) {
                  case (#ok(_transactionId)) {
                    #ok(feedback.id);
                  };
                  case (#err(_error)) #err("Failed to refund amount to user " # userFeedback.user_id);
                };
              } else {
                let icrc1TransferResponse = await UserTransferService.transferAmountToBeneficiary(userFeedback.user_id, userFeedback.event_id, canisterPrincipal, alfangoDB, canistergeekLogger, emailPayload, transform);
                canistergeekLogger.logMessage("Icrc1TransferResponse --->" # debug_show (icrc1TransferResponse));
                switch (icrc1TransferResponse) {
                  case (#ok(_transactionId)) {
                    #ok(feedback.id);
                  };
                  case (#err(_error)) #err("Failed to transfer amount of user " # userFeedback.user_id);
                };
              };
            };
            case (#err(error)) {
              canistergeekLogger.logMessage("Get feedback error --->" # debug_show (error));
              #err(HelperService.textArrayToString(error));
            };
          };
        } else {
          let userData = await SharedService.getUserDetails(userId);

          let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;
          let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(payload.event_id);

          if (Text.size(eventData.event_id) == 0) {
            return #err("Failed to fetch event data for expert feedback processing.");
          };

          let userType = CommonService.getUserType(eventData, userId);

          let userFeedbackObject = {
            id = "";
            event_id = payload.event_id;
            user_id = userId;
            firstname = userData.firstname;
            lastname = userData.lastname;
            username = userData.username;
            email = userData.email;
            timezone = userData.timezone;
            user_type = userType;
            successful = "";
            reason = "";
            rating = 0;
            recording_link = "";
          };

          let emailPayload = {
            user_feedback = userFeedbackObject;
            creator_feedback = creatorFeedbackObject;
            expert_feedback_id = feedback.id;
            remitter_feedback_missing = remitterFeedbackMissing;
          };

          if (transferOrRefund == Constants.MoneyTransferActions.RefundToRemitter) {
            let icrc1TransferResponse = await UserRefundService.refundAmountForCalendarEventRemoval(Principal.fromText(userId), payload.event_id, canisterPrincipal, alfangoDB, canistergeekLogger, emailPayload, transform);
            canistergeekLogger.logMessage("Icrc1TransferResponse --->" # debug_show (icrc1TransferResponse));
            switch (icrc1TransferResponse) {
              case (#ok(_transactionId)) {
                #ok(feedback.id);
              };
              case (#err(_error)) #err("Failed to transfer amount of user " # userId);
            };
          } else {
            let icrc1TransferResponse = await UserTransferService.transferAmountToBeneficiary(userId, payload.event_id, canisterPrincipal, alfangoDB, canistergeekLogger, emailPayload, transform);
            canistergeekLogger.logMessage("Icrc1TransferResponse --->" # debug_show (icrc1TransferResponse));
            switch (icrc1TransferResponse) {
              case (#ok(_transactionId)) {
                #ok(feedback.id);
              };
              case (#err(_error)) #err("Failed to transfer amount of user " # userId);
            };
          };
        };
      };
      case (#err(error)) {
        canistergeekLogger.logMessage("Add expert feedback error --->" # debug_show (error));
        #err(HelperService.textArrayToString(error));
      };
    };
  };
};
