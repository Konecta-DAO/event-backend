import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import EventReadService "../../services/event/read";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../utils/helper";
import CommonService "../common";

module {
  public func getMyServiceOffers(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
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
            filterExpressionCondition = #EQ(#text(Constants.EventType.Offer));
          },
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    canistergeekLogger.logMessage("My offer requests --->" # debug_show (eventResponse));
    return await CommonService.transformGetAllFeedsResponse(eventResponse);
  };

  public func getMyServiceOffersNoTransformPublic(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Database.ScanOutputType {
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
            filterExpressionCondition = #EQ(#text(Constants.EventType.Offer));
          },
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    canistergeekLogger.logMessage("My offer requests --->" # debug_show (eventResponse));
    return eventResponse;
  };

  public func getServiceOffersApartFromMe(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
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
            filterExpressionCondition = #EQ(#text(Constants.EventType.Offer));
          },
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    canistergeekLogger.logMessage("Offer requests other than me--->" # debug_show (eventResponse));
    return await CommonService.transformGetAllFeedsResponse(eventResponse);
  };

  public func getServiceOffersApartFromMeNoTranformPublic(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : Database.ScanOutputType {

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
            filterExpressionCondition = #EQ(#text(Constants.EventType.Offer));
          },
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    canistergeekLogger.logMessage("Offer requests other than me not tranformed--->" # debug_show (eventResponse));
    return eventResponse;
  };

  public func getServiceOffersForMyProfile(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<[ArgumentTypes.FeedResponsePayload], Text> {

    let myOffers = await getMyServiceOffers(userPrincipal, databases, canistergeekLogger);
    canistergeekLogger.logMessage("My service offers --->" # debug_show (myOffers));

    switch (myOffers) {
      case (#ok(offers)) {

        var offersBuffer = Buffer.Buffer<ArgumentTypes.FeedResponsePayload>(0);
        offersBuffer.insertBuffer(0, Buffer.fromArray(offers));

        let eventCanisterActor = actor (Constants.EventCanister) : CommonService.EventCanisterType;
        let myJoinedOffersEvents = await eventCanisterActor.getEventsForAttendee(Principal.toText(userPrincipal));
        canistergeekLogger.logMessage("My joined offers --->" # debug_show (myJoinedOffersEvents));

        switch (myJoinedOffersEvents) {
          case (#ok(joinedOffersEvents)) {
            let joinedOffersBuffer = Buffer.Buffer<ArgumentTypes.FeedResponsePayload>(0);
            for (eventId in joinedOffersEvents.vals()) {
              canistergeekLogger.logMessage("Joined Event Id --->" # debug_show (eventId));

              let checkEventCanceledResponse = EventReadService.checkIfEventIsCanceled(eventId, databases);

              switch (checkEventCanceledResponse) {
                case (#ok(eventCanceled)) {
                  if (not eventCanceled) {

                    let eventDataResponse = await EventReadService.getFeedDetailsByEventId(eventId, databases);

                    switch (eventDataResponse) {
                      case (#ok(eventData)) {
                        joinedOffersBuffer.add(eventData);

                        canistergeekLogger.logMessage("Joined Event Offers Array --->" # debug_show (Buffer.toArray(joinedOffersBuffer)));
                      };
                      case (#err(error)) {
                        canistergeekLogger.logMessage("Failed to add joined offers to buffer --->" # debug_show (Buffer.toArray(joinedOffersBuffer)));
                      };
                    };
                  };
                };

                case (#err(error)) {
                  canistergeekLogger.logMessage("Failed to check event canceled or not --->" # debug_show (error));
                };
              };
            };

            offersBuffer.append(joinedOffersBuffer);
            canistergeekLogger.logMessage("Offers Array --->" # debug_show (Buffer.toArray(offersBuffer)));
            #ok(Buffer.toArray(offersBuffer));
          };
          case (#err(error)) {
            canistergeekLogger.logMessage("Failed to get My joined offers --->" # debug_show (HelperService.textArrayToString(error)));
            #err(HelperService.textArrayToString(error));
          };
        };

      };

      case (#err(error)) {
        canistergeekLogger.logMessage("Failed to get My offers --->" # debug_show (HelperService.textArrayToString(error)));
        #err(HelperService.textArrayToString(error));
      };
    };
  };
};
