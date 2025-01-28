  module {
   
        type implementationType = {
                #AvailableCycles;
                #BlackholeCanister;
                #CygnusLibrary;
                #SnsCanister;
        };

     public type Self = actor {
        registerProjectCanister : shared (
            {
                projectId : Text;
                canisterIdToBeRegistered : Text;
                canisterName : Text;
                implementationType : implementationType;
                topUpAmountInTrillon: ?Float;
                thresholdAmountInTrillon:?Float;
            })-> async (Text);
        };

  };
    