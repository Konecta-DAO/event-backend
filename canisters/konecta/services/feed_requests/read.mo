import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import SharedConstants "../../../shared/constants";
import SharedInterfaces "../../../shared/interfaces";
import SharedTypes "../../../shared/types";
import SharedServices "../../../shared/services";
import EventReadService "../../services/event/read";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../../shared/common_utils/helper";
import { getTupleValueAsText; textToNat } "../../../shared/common_utils/helper";
import CommonService "../common";

module {
  public func getMyServiceRequests(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
    let eventResponse = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.KonectAEventTable;
        filterExpressions = [
          {
            attributeName = "user_id";
            filterExpressionCondition = #EQ(#text(Principal.toText(userPrincipal)));
          },
          {
            attributeName = "event_type";
            filterExpressionCondition = #EQ(#text(Constants.EventType.Request));
          },
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(SharedTypes.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    Debug.print(debug_show (eventResponse));
    canistergeekLogger.logMessage("My service requests --->" # debug_show (eventResponse));
    return await CommonService.transformGetAllFeedsResponse(eventResponse);
  };

  public func getServiceRequestsApartFromMe(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
    let eventResponse = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.KonectAEventTable;
        filterExpressions = [
          {
            attributeName = "user_id";
            filterExpressionCondition = #NEQ(#text(Principal.toText(userPrincipal)));
          },
          {
            attributeName = "event_type";
            filterExpressionCondition = #EQ(#text(Constants.EventType.Request));
          },
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(SharedTypes.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });
    Debug.print(debug_show (eventResponse));
    canistergeekLogger.logMessage("Service requests other than me--->" # debug_show (eventResponse));
    return await CommonService.transformGetAllFeedsResponse(eventResponse);
  };

  public func checkIfRequestAppliedForEvent(userPrincipal : Principal, eventId : Text, databases : Map.Map<Text, Database.Database>) : Bool {
    var exists = false;

    let eventResponse = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.RequestAppliedTable;
        filterExpressions = [
          {
            attributeName = "event_id";
            filterExpressionCondition = #EQ(#text(eventId));
          },
          {
            attributeName = "applied_user_id";
            filterExpressionCondition = #EQ(#principal(userPrincipal));
          },
        ];
      };
      alfangoDB = { databases };
    });

    switch (eventResponse) {
      case (#ok(applicants)) {
        if (Array.size(applicants) > 0) {
          exists := true;
        } else {
          exists := false;
        };
      };
      case (#err(_err)) exists := false;
    };

    return exists;
  };

  public func getAppliedUsersByActionForEvent(eventId : Text, action : SharedTypes.EventAttendeeActions, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : Result.Result<[ArgumentTypes.AppplicantIdsResponsePayload], [Text]> {

    let actionType = CommonService.getActionType(action);

    let appliedRequestsResponse = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.RequestAppliedTable;
        filterExpressions = [
          {
            attributeName = "event_id";
            filterExpressionCondition = #EQ(#text(eventId));
          },
          {
            attributeName = "action";
            filterExpressionCondition = #EQ(#text(actionType));
          },
        ];
      };
      alfangoDB = { databases };
    });

    Debug.print(debug_show (appliedRequestsResponse));
    canistergeekLogger.logMessage("My applied requests --->" # debug_show (appliedRequestsResponse));

    switch (appliedRequestsResponse) {
      case (#ok(applicantsData)) {
        let userBuffer = Buffer.Buffer<ArgumentTypes.AppplicantIdsResponsePayload>(0);

        for (applicant in applicantsData.vals()) {
          let itemData = applicant.item;

          let userObject = {
            applied_user_id = getTupleValueAsText(itemData, "applied_user_id");
            note = getTupleValueAsText(itemData, "note");
            location = getTupleValueAsText(itemData, "location");
          };
          userBuffer.add(userObject);
        };

        let userArray = Buffer.toArray(userBuffer);
        #ok(userArray);
      };
      case (#err(err)) {
        #err(err);
      };
    };
  };

  public func getAppliedUsersByActionWithUserData(eventId : Text, action : SharedTypes.EventAttendeeActions, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<[ArgumentTypes.ApplicantsWithUserDataPayload], [Text]> {

    let actionType = CommonService.getActionType(action);

    let appliedRequestsResponse = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.RequestAppliedTable;
        filterExpressions = [
          {
            attributeName = "event_id";
            filterExpressionCondition = #EQ(#text(eventId));
          },
          {
            attributeName = "action";
            filterExpressionCondition = #EQ(#text(actionType));
          },
        ];
      };
      alfangoDB = { databases };
    });

    Debug.print(debug_show (appliedRequestsResponse));
    canistergeekLogger.logMessage("My applied requests --->" # debug_show (appliedRequestsResponse));

    switch (appliedRequestsResponse) {
      case (#ok(applicantsData)) {
        let userBuffer = Buffer.Buffer<ArgumentTypes.ApplicantsWithUserDataPayload>(0);

        for (applicant in applicantsData.vals()) {
          let itemData = applicant.item;

          let userObject = {
            userData = await SharedServices.getUserDetails(getTupleValueAsText(itemData, "applied_user_id"));
            note = getTupleValueAsText(itemData, "note");
            location = getTupleValueAsText(itemData, "location");
          };
          userBuffer.add(userObject);
        };

        let userArray = Buffer.toArray(userBuffer);
        #ok(userArray);
      };
      case (#err(err)) {
        #err(err);
      };
    };
  };

  public func getUserStatusInEvent(userPrincipal : Principal, eventId : Text, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : Result.Result<Text, Text> {
    var status = "";

    let appliedRequestsResponse = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.RequestAppliedTable;
        filterExpressions = [
          {
            attributeName = "event_id";
            filterExpressionCondition = #EQ(#text(eventId));
          },
          {
            attributeName = "applied_user_id";
            filterExpressionCondition = #EQ(#principal(userPrincipal));
          },
        ];
      };
      alfangoDB = { databases };
    });

    Debug.print(debug_show (appliedRequestsResponse));
    canistergeekLogger.logMessage("My applied requests --->" # debug_show (appliedRequestsResponse));

    switch (appliedRequestsResponse) {
      case (#ok(applicantsData)) {
        if (Array.size(applicantsData) > 0) {
          let applicantItem = applicantsData[0].item;
          status := getTupleValueAsText(applicantItem, "action");
        };

        #ok(status);
      };
      case (#err(err)) {
        #err(HelperService.textArrayToString(err));
      };
    };
  };

  public func getMyProposals(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<[ArgumentTypes.ProposalResponsePayload], Text> {
    let appliedRequests = Database.scan({
      scanInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.RequestAppliedTable;
        filterExpressions = [
          {
            attributeName = "applied_user_id";
            filterExpressionCondition = #EQ(#principal(userPrincipal));
          },
          {
            attributeName = "action";
            filterExpressionCondition = #IN([#text(SharedTypes.EventAttendeeStatus.Applied), #text(SharedTypes.EventAttendeeStatus.Accepted), #text(SharedTypes.EventAttendeeStatus.Declined)]);
          },
        ];
      };
      alfangoDB = { databases };
    });
    canistergeekLogger.logMessage("My applied requests --->" # debug_show (appliedRequests));

    switch (appliedRequests) {
      case (#ok(requests)) {

        let proposalBuffer = Buffer.Buffer<ArgumentTypes.ProposalResponsePayload>(0);

        for (request in requests.vals()) {
          let item = request.item;

          let eventId = getTupleValueAsText(item, "event_id");
          let eventData = await CommonService.getEventDetails(eventId);
          canistergeekLogger.logMessage("Event Data --->" # debug_show (eventData));

          let proposalObject = {
            event_id = eventId;
            event_name = eventData.name;
            event_description = eventData.description;
            userData = eventData.userData;
            note = getTupleValueAsText(item, "note");
            location = getTupleValueAsText(item, "location");
            action = getTupleValueAsText(item, "action");
            updated_at = textToNat(getTupleValueAsText(item, "timestamp"));
          };
          canistergeekLogger.logMessage("Proposal Object --->" # debug_show (proposalObject));

          proposalBuffer.add(proposalObject);

        };

        canistergeekLogger.logMessage("Proposal Array --->" # debug_show (Buffer.toArray(proposalBuffer)));
        #ok(Buffer.toArray(proposalBuffer));
      };

      case (#err(error)) {
        canistergeekLogger.logMessage("Proposal Array Error --->" # debug_show (HelperService.textArrayToString(error)));
        #err(HelperService.textArrayToString(error));
      };
    };
  };

  public func getServiceRequestsForMyProfile(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<[ArgumentTypes.FeedResponsePayload], Text> {

    let myRequestsResult = await getMyServiceRequests(userPrincipal, databases, canistergeekLogger);
    canistergeekLogger.logMessage("My service requests --->" # debug_show (myRequestsResult));

    switch (myRequestsResult) {
      case (#err(error)) {
        let errorMsg = HelperService.textArrayToString(error);
        canistergeekLogger.logMessage("Failed to get My requests --->" # debug_show (errorMsg));
        return #err(errorMsg);
      };
      case (#ok(myRequests)) {
        var finalFeedsBuffer = Buffer.fromArray<ArgumentTypes.FeedResponsePayload>(myRequests);

        let acceptedRequestsResult = Database.scan({
          scanInput = {
            databaseName = SharedConstants.KonectA;
            tableName = Constants.RequestAppliedTable;
            filterExpressions = [
              {
                attributeName = "applied_user_id";
                filterExpressionCondition = #EQ(#principal(userPrincipal));
              },
              {
                attributeName = "action";
                filterExpressionCondition = #EQ(#text(SharedTypes.EventAttendeeStatus.Accepted));
              },
            ];
          };
          alfangoDB = { databases };
        });

        switch (acceptedRequestsResult) {
          case (#ok(acceptedRequests)) {
            if (Array.size(acceptedRequests) > 0) {

              var eventIdsBuffer = Buffer.Buffer<Text>(acceptedRequests.size());
              for (request in acceptedRequests.vals()) {
                eventIdsBuffer.add(getTupleValueAsText(request.item, "event_id"));
              };
              let eventIds = Buffer.toArray(eventIdsBuffer);

              let eventCanisterActor = actor (SharedConstants.EventCanister) : SharedInterfaces.EventActor;
              let eventDetailsList = await eventCanisterActor.getMultipleEventsDetailsWithUserData(eventIds);

              var eventDetailsMap = HashMap.HashMap<Text, SharedTypes.EventDetailsPayload>(
                eventIds.size(),
                Text.equal,
                Text.hash,
              );
              for ((eventId, eventDetailsOpt) in eventDetailsList.vals()) {
                switch (eventDetailsOpt) {
                  case (?details) eventDetailsMap.put(eventId, details);
                  case null {};
                };
              };

              var konectaEventMap = HashMap.HashMap<Text, ArgumentTypes.EventResponsePayload>(
                eventIds.size(),
                Text.equal,
                Text.hash,
              );
              for (eventId in eventIds.vals()) {
                switch (EventReadService.getEventData(eventId, databases)) {
                  case (#ok(konectaData)) konectaEventMap.put(eventId, konectaData);
                  case (#err(_)) {};
                };
              };

              for (request in acceptedRequests.vals()) {
                let eventId = getTupleValueAsText(request.item, "event_id");

                switch ((eventDetailsMap.get(eventId), konectaEventMap.get(eventId))) {
                  case (?(eventData), ?(konectaData)) {
                    if (eventData.status != SharedTypes.EventStatus.Canceled) {
                      finalFeedsBuffer.add({
                        konecta_event_id = konectaData.konecta_event_id;
                        user_id = eventData.user_id;
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
                        event_type = konectaData.event_type;
                        expertise = konectaData.expertise;
                        price_token = konectaData.price_token;
                        token_amount = konectaData.token_amount;
                        categories = konectaData.categories;
                        consultations = konectaData.consultations;
                        interests = konectaData.interests;
                        eventMetadata = eventData.metadata;
                        konectaMetadata = konectaData.metadata;
                      });
                    };
                  };
                  case _ {};
                };
              };
            };
          };
          case (#err(error)) {
            canistergeekLogger.logMessage("Failed to get My accepted requests --->" # debug_show (HelperService.textArrayToString(error)));
          };
        };

        return #ok(Buffer.toArray(finalFeedsBuffer));
      };
    };
  };

  public func getUserStatusForServiceRequests(userPrincipal : Principal, eventId : Text, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : Text {
    var userStatus = "";
    var statusError = "";
    let eventDataResponse = EventReadService.getEventData(eventId, databases);

    switch (eventDataResponse) {
      case (#ok(eventData)) {
        let eventType = eventData.event_type;

        if (eventType == Constants.EventType.Request) {
          let response = getUserStatusInEvent(userPrincipal, eventId, databases, canistergeekLogger);

          switch (response) {
            case (#ok(status)) {
              userStatus := status;
            };
            case (#err(error)) {
              statusError := error;
            };
          };
        };

        return userStatus;

      };
      case (#err(_error)) {
        return userStatus;
      };
    };

  };

  public func getUserStatusForEvent(userPrincipal : Principal, eventId : Text, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<Text, Text> {

    var userStatus = "";
    let eventDataResponse = EventReadService.getEventData(eventId, databases);

    switch (eventDataResponse) {
      case (#ok(eventData)) {
        let eventType = eventData.event_type;

        if (eventType == Constants.EventType.Request) {
          let response = getUserStatusInEvent(userPrincipal, eventId, databases, canistergeekLogger);

          switch (response) {
            case (#ok(status)) {
              userStatus := status;
              #ok(userStatus);
            };
            case (#err(error)) {
              #err(error);
            };
          };
        } else {
          let eventCanisterActor = actor (SharedConstants.EventCanister) : SharedInterfaces.EventActor;
          let exists = await eventCanisterActor.checkIfAttendeeExistsForEvent(userPrincipal, eventId);
          if (exists) {
            userStatus := SharedTypes.EventAttendeeStatus.Joined;
          };
          #ok(userStatus);
        };

      };
      case (#err(error)) {
        #err(HelperService.textArrayToString(error));
      };
    };
  };

};
