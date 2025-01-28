/**
 * This is the main Motoko file for the Konecta Canister.
 * It contains the implementation of the KonectaCanister actor class, which provides various functions for managing Konecta events.
 */

import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import EventCommonService "services/common";
import EventCreateService "services/event/create";
import EventReadService "services/event/read";
import EventUpdateService "services/event/update";
import EventJoinService "services/feed_offers/join";
import FeedOfferReadService "services/feed_offers/read";
import AcceptRequestService "services/feed_requests/accept";
import ApplyRequestService "services/feed_requests/apply";
import DeclineRequestService "services/feed_requests/decline";
import FeedRequestReadService "services/feed_requests/read";
import SchemaService "services/schema";
import ArgumentTypes "types/argumentTypes";
import KonectaConstants "utils/constants";

shared ({ caller = initializer }) actor class KonectaCanister() = this {

  stable var databases = Map.new<Text, Database.Database>();

  private let canistergeekMonitor = Canistergeek.Monitor();
  private let canistergeekLogger = Canistergeek.Logger();
  stable var _canistergeekMonitorUD : ?Canistergeek.UpgradeData = null;
  stable var _canistergeekLoggerUD : ?Canistergeek.LoggerUpgradeData = null;

  /**
   * Generates the schema for the Konecta Canister.
   * This function creates the project database and the Konecta event table.
   * @returns A text indicating the success or failure of schema generation.
   */
  public func generateSchema() : async Text {
    canistergeekMonitor.collectMetrics();
    let _database = await SchemaService.createProjectDatabase(databases, canistergeekLogger);
    canistergeekLogger.logMessage("Create Project Database --->" # debug_show (_database));

    let _eventTableResponse = await SchemaService.createKonectaEventTable(databases, canistergeekLogger);
    canistergeekLogger.logMessage("Event table response --->" # debug_show (_eventTableResponse));

    let _requestAppliedTableResponse = await SchemaService.createRequestAppliedTable(databases, canistergeekLogger);
    canistergeekLogger.logMessage("Request Applied table --->" # debug_show (_requestAppliedTableResponse));

    return "Schema created successfully";
  };

  /**
   * Retrieves the list of trusted origins (white-listed canisters).
   * @returns An array of text containing the trusted origins.
   */
  public query func get_trusted_origins() : async [Text] {
    return KonectaConstants.whiteListedCanisters;
  };

  /**
   * Creates a Konecta event.
   * @param userCanisterId The ID of the user's canister.
   * @param payload The payload of the event.
   * @returns A text indicating the success or failure of event creation.
   */
  public shared (msg) func createKonectaEvent(userCanisterId : Text, payload : ArgumentTypes.EventRequestPayload) : async Text {
    canistergeekMonitor.collectMetrics();
    await EventCreateService.createEvent(msg.caller, userCanisterId, payload, databases, canistergeekLogger);
  };

  public shared (msg) func cancelKonectaEvent(eventId : Text) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await EventUpdateService.cancelKonectaEvent(msg.caller, eventId, databases, canistergeekLogger);
  };

  public shared func cancelKonectaEventPublic(principal : Text, eventId : Text) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await EventUpdateService.cancelKonectaEvent(Principal.fromText(principal), eventId, databases, canistergeekLogger);
  };

  /**
   * Retrieves the details of a Konecta event by event ID.
   * @param eventId The ID of the event.
   * @returns An array of tuples containing the event details.
   */
  public query func getKonectaEventDetailsByEventId(eventId : Text) : async Result.Result<ArgumentTypes.EventResponsePayload, [Text]> {
    return EventReadService.getEventData(eventId, databases);
  };

  public query func checkIfEventIsCanceled(eventId : Text) : async Result.Result<Bool, Text> {
    return EventReadService.checkIfEventIsCanceled(eventId, databases);
  };

  public shared func getFeedDetailsByEventId(eventId : Text) : async Result.Result<ArgumentTypes.FeedResponsePayload, [Text]> {
    return await EventReadService.getFeedDetailsByEventId(eventId, databases);
  };

  /**
   * Updates a Konecta event.
   * @param userCanisterId The ID of the user's canister.
   * @param payload The updated payload of the event.
   * @returns A text indicating the success or failure of event update.
   */
  public shared (msg) func updateKonectaEvent(userCanisterId : Text, payload : ArgumentTypes.EventRequestPayload) : async Text {
    canistergeekMonitor.collectMetrics();
    await EventUpdateService.updateEvent(msg.caller, userCanisterId, payload, databases, canistergeekLogger);
  };

  public shared (msg) func joinPublicEvent(eventId : Text) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await EventJoinService.joinPublicEvent(msg.caller, eventId, databases, canistergeekLogger);
  };

  public shared (msg) func applyToServiceRequest(payload : ArgumentTypes.ApplyToServiceRequestPayload) : async Text {
    await ApplyRequestService.applyToServiceRequest(msg.caller, payload, databases, canistergeekLogger);
  };

  public shared (msg) func acceptUserApplication(userIdOfApplicant : Text, eventId : Text) : async Result.Result<Text, Text> {
    await AcceptRequestService.acceptUserApplication(msg.caller, userIdOfApplicant, eventId, databases, canistergeekLogger);
  };

  public shared (msg) func declineUserApplication(userIdOfApplicant : Text, eventId : Text) : async Result.Result<Text, Text> {
    await DeclineRequestService.declineUserApplication(msg.caller, userIdOfApplicant, eventId, databases, canistergeekLogger);
  };

  public query func getAppliedUsersByActionForEvent(eventId : Text, action : ArgumentTypes.EventAttendeeActions) : async Result.Result<[ArgumentTypes.AppplicantIdsResponsePayload], [Text]> {
    FeedRequestReadService.getAppliedUsersByActionForEvent(eventId, action, databases, canistergeekLogger);
  };

  public composite query func getAppliedUsersByActionWithUserData(eventId : Text, action : ArgumentTypes.EventAttendeeActions) : async Result.Result<[ArgumentTypes.ApplicantsWithUserDataPayload], [Text]> {
    let response = FeedRequestReadService.getAppliedUsersByActionForEvent(eventId, action, databases, canistergeekLogger);
    let userBuffer = Buffer.Buffer<ArgumentTypes.ApplicantsWithUserDataPayload>(0);

    switch (response) {
      case (#ok(applicants)) {
        for (applicant in applicants.vals()) {
          let user = await getUserDetailsByCompositeQuery(applicant.applied_user_id);
          userBuffer.add({
            userData = user;
            note = applicant.note;
            location = applicant.location;
          });
        };
        #ok(Buffer.toArray(userBuffer));
      };

      case (#err(err)) {
        return #err(err);
      };
    };
  };

  public composite query (msg) func getUserStatusForEvent(eventId : Text) : async Text {
    Debug.print(debug_show (msg.caller));
    let eventType = EventReadService.getEventType(eventId, databases);
    if (eventType == KonectaConstants.EventType.Request) {
      return await getUserStatusForServiceRequests(msg.caller, eventId);
    } else {
      return await getUserStatusForServiceOffers(msg.caller, eventId);
    };
  };

  public query func getUserStatusForServiceRequests(userPrincipal : Principal, eventId : Text) : async Text {
    FeedRequestReadService.getUserStatusForServiceRequests(userPrincipal, eventId, databases, canistergeekLogger);
  };

  public composite query func getUserStatusForServiceOffers(userPrincipal : Principal, eventId : Text) : async Text {
    Debug.print(debug_show (userPrincipal));
    var status = "";
    let eventCanisterActor = actor (KonectaConstants.EventCanister) : EventCommonService.EventCanisterType;
    let exists = await eventCanisterActor.checkIfAttendeeExistsForEvent(userPrincipal, eventId);
    if (exists) {
      status := KonectaConstants.EventAttendeeStatus.Joined;
    };
    return status;
  };

  public query func getAllKonectAEvents() : async Result.Result<[ArgumentTypes.EventResponsePayload], [Text]> {
    canistergeekMonitor.collectMetrics();
    EventReadService.getAllEvents(databases);
  };

  public shared (msg) func getMyProposals() : async Result.Result<[ArgumentTypes.ProposalResponsePayload], Text> {
    canistergeekMonitor.collectMetrics();
    await FeedRequestReadService.getMyProposals(msg.caller, databases, canistergeekLogger);
  };

  public shared (msg) func getServiceOffersForMyProfile() : async Result.Result<[ArgumentTypes.FeedResponsePayload], Text> {
    canistergeekMonitor.collectMetrics();
    await FeedOfferReadService.getServiceOffersForMyProfile(msg.caller, databases, canistergeekLogger);
  };

  public shared (msg) func getServiceRequestsForMyProfile() : async Result.Result<[ArgumentTypes.FeedResponsePayload], Text> {
    canistergeekMonitor.collectMetrics();
    await FeedRequestReadService.getServiceRequestsForMyProfile(msg.caller, databases, canistergeekLogger);
  };

  public shared func getMyProposalsPublic(userPrincipal : Text) : async Result.Result<[ArgumentTypes.ProposalResponsePayload], Text> {
    canistergeekMonitor.collectMetrics();
    await FeedRequestReadService.getMyProposals(Principal.fromText(userPrincipal), databases, canistergeekLogger);
  };

  public shared func getServiceOffersForMyProfilePublic(userPrincipal : Text) : async Result.Result<[ArgumentTypes.FeedResponsePayload], Text> {
    canistergeekMonitor.collectMetrics();
    await FeedOfferReadService.getServiceOffersForMyProfile(Principal.fromText(userPrincipal), databases, canistergeekLogger);
  };

  public shared func getServiceRequestsForMyProfilePublic(userPrincipal : Text) : async Result.Result<[ArgumentTypes.FeedResponsePayload], Text> {
    canistergeekMonitor.collectMetrics();
    await FeedRequestReadService.getServiceRequestsForMyProfile(Principal.fromText(userPrincipal), databases, canistergeekLogger);
  };

  public shared (msg) func getMyServiceRequests() : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
    canistergeekMonitor.collectMetrics();
    await FeedRequestReadService.getMyServiceRequests(msg.caller, databases, canistergeekLogger);
  };

  public shared func getMyServiceRequestsPublic(pid : Text) : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
    canistergeekMonitor.collectMetrics();
    await FeedRequestReadService.getMyServiceRequests(Principal.fromText(pid), databases, canistergeekLogger);
  };

  public shared func getMyServiceRequestsNoTransformPublic(pid : Text) : async Database.ScanOutputType {
    canistergeekMonitor.collectMetrics();
    await FeedRequestReadService.getMyServiceRequestsNoTransformPublic(Principal.fromText(pid), databases, canistergeekLogger);
  };

  public shared (msg) func getServiceRequestsApartFromMe() : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
    canistergeekMonitor.collectMetrics();
    await FeedRequestReadService.getServiceRequestsApartFromMe(msg.caller, databases, canistergeekLogger);
  };

  public shared func getServiceRequestsApartFromMePublic(pid : Text) : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
    canistergeekMonitor.collectMetrics();
    await FeedRequestReadService.getServiceRequestsApartFromMe(Principal.fromText(pid), databases, canistergeekLogger);
  };

  public shared func getServiceRequestsApartFromMeNoTranformPublic(pid : Text) : async Database.ScanOutputType {
    canistergeekMonitor.collectMetrics();
    FeedRequestReadService.getServiceRequestsApartFromMeNoTranformPublic(Principal.fromText(pid), databases, canistergeekLogger);
  };

  public shared (msg) func getMyServiceOffers() : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
    canistergeekMonitor.collectMetrics();
    await FeedOfferReadService.getMyServiceOffers(msg.caller, databases, canistergeekLogger);
  };

  public shared func getMyServiceOffersPublic(pid : Text) : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
    canistergeekMonitor.collectMetrics();
    await FeedOfferReadService.getMyServiceOffers(Principal.fromText(pid), databases, canistergeekLogger);
  };

  public shared func getMyServiceOffersNoTransformPublic(pid : Text) : async Database.ScanOutputType {
    canistergeekMonitor.collectMetrics();
    await FeedOfferReadService.getMyServiceOffersNoTransformPublic(Principal.fromText(pid), databases, canistergeekLogger);
  };

  public shared (msg) func getServiceOffersApartFromMe() : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
    canistergeekMonitor.collectMetrics();
    await FeedOfferReadService.getServiceOffersApartFromMe(msg.caller, databases, canistergeekLogger);
  };

  public shared func getServiceOffersApartFromMePublic(pid : Text) : async Result.Result<[ArgumentTypes.FeedResponsePayload], [Text]> {
    canistergeekMonitor.collectMetrics();
    await FeedOfferReadService.getServiceOffersApartFromMe(
      Principal.fromText(pid),
      databases,
      canistergeekLogger,
    );
  };

  public shared func getServiceOffersApartFromMeNoTranformPublic(pid : Text) : async Database.ScanOutputType {
    canistergeekMonitor.collectMetrics();
    FeedOfferReadService.getServiceOffersApartFromMeNoTranformPublic(Principal.fromText(pid), databases, canistergeekLogger);
  };

  public composite query func getUserDetailsByCompositeQuery(userId : Text) : async ArgumentTypes.UserResponsePayload {
    let indexActor = actor (KonectaConstants.IndexCanister) : EventCommonService.IndexActor;
    let userCanisterId = await indexActor.getUserCanisterByUserPrincipal(userId);

    let userCanisterActor = actor (userCanisterId) : EventCommonService.UserCanisterType;
    await userCanisterActor.getUserForEventCanister(userId);
  };

  public query func getKonectaEventTableMetadata() : async Database.GetTableMetadataOutputType {
    EventReadService.eventTableMetadata(databases);
  };

  system func preupgrade() {
    _canistergeekMonitorUD := ?canistergeekMonitor.preupgrade();
    _canistergeekLoggerUD := ?canistergeekLogger.preupgrade();
  };

  system func postupgrade() {
    canistergeekMonitor.postupgrade(_canistergeekMonitorUD);
    _canistergeekMonitorUD := null;

    canistergeekLogger.postupgrade(_canistergeekLoggerUD);
    _canistergeekLoggerUD := null;

    //Optional: override default number of log messages to your value
    canistergeekLogger.setMaxMessagesCount(3000);
  };

  public query func getCanistergeekInformation(request : Canistergeek.GetInformationRequest) : async Canistergeek.GetInformationResponse {

    Canistergeek.getInformation(?canistergeekMonitor, ?canistergeekLogger, request);
  };

  public shared func updateCanistergeekInformation(request : Canistergeek.UpdateInformationRequest) : async () {

    canistergeekMonitor.updateInformation(request);
  };

};
