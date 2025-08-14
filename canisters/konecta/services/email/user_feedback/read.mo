import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Bool "mo:base/Bool";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import HashMap "mo:base/HashMap";

import ArgumentTypes "../../../types/argumentTypes";
import Constants "../../../utils/constants";
import HelperService "../../../utils/helper";
import SharedService "../../shared/shared";
import TransformService "../../shared/transform";

module {

  public func getUserFeedback(
    userFeedbackId : Text,
    alfangoDB : Database.AlfangoDB,
    _canistergeekLogger : Canistergeek.Logger,
  ) : Result.Result<ArgumentTypes.UserFeedbackResponsePayload, [Text]> {
    let item = Database.getItemById({
      getItemByIdInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.UserFeedbackTable;
        id = userFeedbackId;
      };
      alfangoDB = alfangoDB;
    });
    return TransformService.transformGetFeedbackResponse(item);
  };

  public func getUserFeedbackForUserByEvent(
    userId : Text,
    eventId : Text,
    userType : Text,
    alfangoDB : Database.AlfangoDB,
    _canistergeekLogger : Canistergeek.Logger,
  ) : ArgumentTypes.UserFeedbackResponsePayload {
    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "user_id";
        filterExpressionCondition = #EQ(#text(userId));
      }),
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
      #expression({
        attributeNames = "user_type";
        filterExpressionCondition = #EQ(#text(userType));
      }),
    ]);
    let item = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.UserFeedbackTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    let feedbackResponse = TransformService.transformGetAllFeedbacksResponse(item);

    switch (feedbackResponse) {
      case (#ok(feedbackArr)) {
        if (Array.size(feedbackArr) > 0) {
          feedbackArr[0];
        } else {
          TransformService.initialFeedbackObject;
        };
      };
      case (#err(_error)) { TransformService.initialFeedbackObject };
    };
  };

  public func getListOfUserFeedbacks(alfangoDB : Database.AlfangoDB, _canistergeekLogger : Canistergeek.Logger) : Result.Result<[ArgumentTypes.UserFeedbackResponsePayload], [Text]> {
    let item = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.UserFeedbackTable;
        filter = #AND([]);
      };
      alfangoDB = alfangoDB;
    });
    TransformService.transformGetAllFeedbacksResponse(item);
  };

  public func getAccepteeOROfferCreatorFeedbackForEvent(
    eventId : Text,
    alfangoDB : Database.AlfangoDB,
    _canistergeekLogger : Canistergeek.Logger,
  ) : async ArgumentTypes.UserFeedbackResponsePayload {
    let eventCanisterActor = actor (Constants.EventCanister) : SharedService.EventCanisterType;
    let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(eventId);
    var userType = "";

    if (Text.size(eventData.event_id) > 0) {
      switch (eventData.event_type) {
        case ("Request") {
          userType := Constants.EventCompletionEmailUserType.Acceptee;
        };
        case ("Offer") {
          userType := Constants.EventCompletionEmailUserType.OfferCreator;
        };
        case _ ();
      };
      getUserFeedbackForUserByEvent(eventData.user_id, eventId, userType, alfangoDB, _canistergeekLogger);
    } else {
      TransformService.initialFeedbackObject;
    };
  };

  public func checkFeedbackByUserForEvent(
    userId : Text,
    eventId : Text,
    userType : [Database.RelationalExpressionAttributeDataValue],
    alfangoDB : Database.AlfangoDB,
    _canistergeekLogger : Canistergeek.Logger,
  ) : Bool {
    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "user_id";
        filterExpressionCondition = #EQ(#text(userId));
      }),
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
      #expression({
        attributeNames = "user_type";
        filterExpressionCondition = #IN(userType);
      }),
    ]);
    let item = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.UserFeedbackTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (item) {
      case (#ok(feedbackArr)) { return feedbackArr.size() > 0 };
      case (#err(_error)) { return false };
    };
  };

  public func getFeedbackSubmittedEventIds(
    userPrincipal : Principal,
    alfangoDB : Database.AlfangoDB,
  ) : Result.Result<HashMap.HashMap<Text, ()>, [Text]> {
    let filter : SearchTypes.QueryFilter = #expression({
      attributeNames = "user_id";
      filterExpressionCondition = #EQ(#text(Principal.toText(userPrincipal)));
    });

    let feedbackScanResult = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.UserFeedbackTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (feedbackScanResult) {
      case (#ok(feedbackItems)) {
        let submittedIds = HashMap.HashMap<Text, ()>(feedbackItems.size(), Text.equal, Text.hash);
        for (item in feedbackItems.vals()) {
          let eventId = HelperService.getTupleValueAsText(item.item, "event_id");
          submittedIds.put(eventId, ());
        };
        return #ok(submittedIds);
      };
      case (#err(e)) {
        return #err(e);
      };
    };
  };

  public func userFeedbackTableMetadata(alfangoDB : Database.AlfangoDB) : Database.GetTableMetadataOutputType {
    Database.getTableMetadata({
      getTableMetadataInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.UserFeedbackTable;
      };
      alfangoDB = alfangoDB;
    });
  };
};
