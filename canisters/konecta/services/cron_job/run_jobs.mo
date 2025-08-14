import Database "mo:alfangodb/AlfangoDB";
import Principal "mo:base/Principal";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import HttpTypes "../../library/emailLibrary/email/src/email_backend/http.types";
import Constants "../../utils/constants";
import EventCompletionSendService "./event_completion_job";
import MoneyTransferService "./money_transfer_job";

module {

  public func runJobs(alfangoDB : Database.AlfangoDB, canistergeekLogger : Canistergeek.Logger, transform : shared query HttpTypes.TransformArgs -> async HttpTypes.HttpResponsePayload) : async () {
    let canisterPrincipal = Principal.fromText(Constants.KonectaCanister);
    let _eventCompletionJobResponse = await EventCompletionSendService.sendEventCompletionEmail(alfangoDB, canistergeekLogger, transform);
    let _moneyTransferResponse = await MoneyTransferService.moneyTransfer(canisterPrincipal, alfangoDB, canistergeekLogger, transform);
  };
};
