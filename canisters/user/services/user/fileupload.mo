import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import D3 "mo:d3storage/D3";

module {
  public func saveFile(file : D3.StoreFileInputType, d3 : D3.D3) : async Text {
    let bufferSize = Buffer.fromArray<Nat8>(Blob.toArray(file.fileDataObject)).size();

    if (bufferSize == 0) {
      return "Please enter valid blob data";
    } else {
      var fileId = "";
      let output = await D3.storeFile({
        d3;
        storeFileInput = {
          fileDataObject = file.fileDataObject;
          fileName = file.fileName;
          fileType = file.fileType;
        };
      });

      switch (output) {
        case (response) fileId := response.fileId;
      };

      return fileId;
    };

  };
};
