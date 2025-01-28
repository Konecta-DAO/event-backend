import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import EventReadService "../../services/event/read";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../utils/helper";
import { getTupleValueAsText; textToNat } "../../utils/helper";
import CommonService "../common";
module {
  public func getMyServiceRequests(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
    let eventResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
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
            filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    Debug.print(debug_show (eventResponse));
    canistergeekLogger.logMessage("My service requests --->" # debug_show (eventResponse));
    return await CommonService.transformGetAllFeedsResponse(eventResponse);
  };

  public func getMyServiceRequestsNoTransformPublic(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Database.ScanOutputType {
    let eventResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
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
            filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    Debug.print(debug_show (eventResponse));
    canistergeekLogger.logMessage("My service requests --->" # debug_show (eventResponse));
    return eventResponse;
  };

  public func getServiceRequestsApartFromMe(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
    let eventResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
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
            filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });
    Debug.print(debug_show (eventResponse));
    canistergeekLogger.logMessage("Service requests other than me--->" # debug_show (eventResponse));
    return await CommonService.transformGetAllFeedsResponse(eventResponse);
  };

  public func getServiceRequestsApartFromMeNoTranformPublic(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : Database.ScanOutputType {
    let eventResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
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
            filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });
    Debug.print(debug_show (eventResponse));
    canistergeekLogger.logMessage("Service requests other than me not tranformed--->" # debug_show (eventResponse));
    return eventResponse;
  };

  public func checkIfRequestAppliedForEvent(userPrincipal : Principal, eventId : Text, databases : Map.Map<Text, Database.Database>) : Bool {
    var exists = false;

    let eventResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
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
      case (#err(err)) exists := false;
    };

    return exists;
  };

  public func getAppliedUsersByActionForEvent(eventId : Text, action : ArgumentTypes.EventAttendeeActions, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : Result.Result<[ArgumentTypes.AppplicantIdsResponsePayload], [Text]> {

    let actionType = CommonService.getActionType(action);

    let appliedRequestsResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
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
          let itemId = applicant.id;
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

  public func getAppliedUsersByActionWithUserData(eventId : Text, action : ArgumentTypes.EventAttendeeActions, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<[ArgumentTypes.ApplicantsWithUserDataPayload], [Text]> {

    let actionType = CommonService.getActionType(action);

    let appliedRequestsResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
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
          let itemId = applicant.id;
          let itemData = applicant.item;

          let userObject = {
            userData = await CommonService.getUserDetails(getTupleValueAsText(itemData, "applied_user_id"));
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
        databaseName = Constants.KonectA;
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
        databaseName = Constants.KonectA;
        tableName = Constants.RequestAppliedTable;
        filterExpressions = [
          {
            attributeName = "applied_user_id";
            filterExpressionCondition = #EQ(#principal(userPrincipal));
          },
          {
            attributeName = "action";
            filterExpressionCondition = #IN([#text(Constants.EventAttendeeStatus.Applied), #text(Constants.EventAttendeeStatus.Accepted), #text(Constants.EventAttendeeStatus.Declined)]);
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

    let myRequests = await getMyServiceRequests(userPrincipal, databases, canistergeekLogger);
    canistergeekLogger.logMessage("My service requests --->" # debug_show (myRequests));

    switch (myRequests) {
      case (#ok(requests)) {

        var requestsBuffer = Buffer.Buffer<ArgumentTypes.FeedResponsePayload>(0);
        requestsBuffer.insertBuffer(0, Buffer.fromArray(requests));

        let appliedRequests = Database.scan({
          scanInput = {
            databaseName = Constants.KonectA;
            tableName = Constants.RequestAppliedTable;
            filterExpressions = [
              {
                attributeName = "applied_user_id";
                filterExpressionCondition = #EQ(#principal(userPrincipal));
              },
              {
                attributeName = "action";
                filterExpressionCondition = #EQ(#text(Constants.EventAttendeeStatus.Accepted));
              },
            ];
          };
          alfangoDB = { databases };
        });
        canistergeekLogger.logMessage("My applied requests --->" # debug_show (appliedRequests));
        try {

          switch (appliedRequests) {
            case (#ok(acceptedRequests)) {

              let acceptedRequestsBuffer = Buffer.Buffer<ArgumentTypes.FeedResponsePayload>(0);
              for (request in acceptedRequests.vals()) {
                let eventId = getTupleValueAsText(request.item, "event_id");
                canistergeekLogger.logMessage("Accepted Event Id --->" # debug_show (eventId));

                let checkEventCanceledResponse = EventReadService.checkIfEventIsCanceled(eventId, databases);

                switch (checkEventCanceledResponse) {
                  case (#ok(eventCanceled)) {
                    if (not eventCanceled) {

                      let eventDataResponse = await EventReadService.getFeedDetailsByEventId(eventId, databases);
                      canistergeekLogger.logMessage("Accepted Event Data Response --->" # debug_show (eventDataResponse));

                      switch (eventDataResponse) {
                        case (#ok(eventData)) {
                          acceptedRequestsBuffer.add(eventData);

                          canistergeekLogger.logMessage("Accepted Event Requests Array --->" # debug_show (Buffer.toArray(acceptedRequestsBuffer)));
                        };
                        case (#err(error)) {
                          canistergeekLogger.logMessage("Failed to add accepted request to buffer --->" # debug_show (Buffer.toArray(acceptedRequestsBuffer)));
                        };
                      };
                    };
                  };
                  case (#err(error)) {
                    canistergeekLogger.logMessage("Failed to check event canceled or not --->" # debug_show (error));
                  };
                };

              };

              requestsBuffer.append(acceptedRequestsBuffer);
              canistergeekLogger.logMessage("Requests Array --->" # debug_show (Buffer.toArray(requestsBuffer)));
              #ok(Buffer.toArray(requestsBuffer));
            };
            case (#err(error)) {
              canistergeekLogger.logMessage("Failed to get My accepted requests --->" # debug_show (HelperService.textArrayToString(error)));
              #err(HelperService.textArrayToString(error));
            };
          };

        } catch (e) {
          canistergeekLogger.logMessage("Error thrown --->" # debug_show (Error.message(e)));
          throw e;
        };

      };

      case (#err(error)) {
        canistergeekLogger.logMessage("Failed to get My requests --->" # debug_show (HelperService.textArrayToString(error)));
        #err(HelperService.textArrayToString(error));
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
      case (#err(error)) {
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
          let eventCanisterActor = actor (Constants.EventCanister) : CommonService.EventCanisterType;
          let exists = await eventCanisterActor.checkIfAttendeeExistsForEvent(userPrincipal, eventId);
          if (exists) {
            userStatus := Constants.EventAttendeeStatus.Joined;
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
