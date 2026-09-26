using {
  managed,
  Currency
} from '@sap/cds/common';

namespace esi.samples.producer2;

entity Product : managed {
  key ID              : UUID;
      @mandatory name : localized String(111);
      description     : localized String(1111);
      price           : Decimal(10, 2);
      currency        : Currency;
      category        : String(50);
      available       : Boolean;
      stock           : Integer;
}
