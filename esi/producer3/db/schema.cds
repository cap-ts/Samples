using {
  managed
} from '@sap/cds/common';

namespace esi.samples.producer3;

entity Employee : managed {
 key ID          : UUID;
      firstName   : String(50);
      lastName    : String(50);
      email       : String(100);
      department  : String(50);
      title       : String(50);
      hireDate    : Date;
      active      : Boolean;
}