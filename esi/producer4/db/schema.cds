using {managed} from '@sap/cds/common';

namespace esi.samples.producer4;

entity Transaction : managed {
  key ID          : UUID;
      date        : DateTime;
      quantity    : Integer;
      totalAmount : Decimal(10, 2);
      customer    : UUID;
      employee    : UUID;
      product     : UUID;
      note        : String(200);
}
