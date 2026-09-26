using {
  managed
} from '@sap/cds/common';

namespace esi.samples.producer1;

entity Customer : managed {
  key ID          : UUID;
      firstName   : String(50);
      lastName    : String(50);
      email       : String(100);
      phoneNumber : String(20);
      address     : String(200);
}