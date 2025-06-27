import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import SharedConstants "../../../shared/constants";
import SharedInterfaces "../../../shared/interfaces";
import SharedTypes "../../../shared/types";
import EventReadService "../../services/event/read";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../../shared/common_utils/helper";
import CommonService "../common";

module {
  public func getMyServiceOffers(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
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
            filterExpressionCondition = #EQ(#text(Constants.EventType.Offer));
          },
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(SharedTypes.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    canistergeekLogger.logMessage("My offer requests --->" # debug_show (eventResponse));
    return await CommonService.transformGetAllFeedsResponse(eventResponse);
  };

  public func getServiceOffersApartFromMe(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
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
            filterExpressionCondition = #EQ(#text(Constants.EventType.Offer));
          },
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(SharedTypes.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    canistergeekLogger.logMessage("Offer requests other than me--->" # debug_show (eventResponse));
    return await CommonService.transformGetAllFeedsResponse(eventResponse);
  };

  public func getServiceOffersForMyProfile(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<[ArgumentTypes.FeedResponsePayload], Text> {

    let myOffersResult = await getMyServiceOffers(userPrincipal, databases, canistergeekLogger);
    canistergeekLogger.logMessage("My service offers --->" # debug_show (myOffersResult));

    switch (myOffersResult) {
      case (#err(error)) {
        let errorMsg = HelperService.textArrayToString(error);
        canistergeekLogger.logMessage("Failed to get My offers --->" # debug_show (errorMsg));
        return #err(errorMsg);
      };
      case (#ok(myOffers)) {
        var finalFeedsBuffer = Buffer.fromArray<ArgumentTypes.FeedResponsePayload>(myOffers);

        let myJoinedOffersEventsResult = await (actor (SharedConstants.EventCanister) : SharedInterfaces.EventActor).getEventsForAttendee(Principal.toText(userPrincipal));
        canistergeekLogger.logMessage("My joined offers --->" # debug_show (myJoinedOffersEventsResult));

        switch (myJoinedOffersEventsResult) {
          case (#ok(joinedEventIds)) {
            if (Array.size(joinedEventIds) > 0) {

              let eventIds = joinedEventIds;

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

              for (eventId in joinedEventIds.vals()) {
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
            canistergeekLogger.logMessage("Failed to get My joined offers --->" # debug_show (HelperService.textArrayToString(error)));
          };
        };

        return #ok(Buffer.toArray(finalFeedsBuffer));
      };
    };
  };
};
