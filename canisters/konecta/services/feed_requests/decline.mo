import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";

import SharedService "../../services/shared/shared";
import KonectaConstants "../../utils/constants";

module {
  /**
   * Orchestrates declining a user's application.
   * This function is called by the main Konecta canister.
   */
  public func declineUserApplication(
    creatorPrincipal : Principal, // The event creator performing the action
    userIdOfApplicantToDecline : Text,
    eventId : Text,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, Text> {

    let applicantPrincipal = Principal.fromText(userIdOfApplicantToDecline);
    canistergeekLogger.logMessage(
      "Creator " # Principal.toText(creatorPrincipal) #
      " is declining application from " # userIdOfApplicantToDecline #
      " for event " # eventId
    );

    // 1. Get an actor reference to the Event canister
    let eventCanisterActor = actor (KonectaConstants.EventCanister) : SharedService.EventCanisterType;

    // 2. Delegate the core state-change logic to the Event canister
    let declineResult = await eventCanisterActor.declineApplication(eventId, applicantPrincipal);

    // 3. (Optional) Fire-and-forget an email notification to the declined user.
    // This part can be added later if needed, but the core logic is complete here.

    // 4. Return the result from the Event canister directly to the user
    return declineResult;
  };
};
