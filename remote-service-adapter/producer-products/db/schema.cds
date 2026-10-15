using { managed } from '@sap/cds/common';

namespace rsa.samples.products;

entity Products : managed {
    key ID           : String(10);
        Name         : String(60);
        Description  : String(200);
        category     : Association to Categories;
        Price        : Decimal(15, 2);
        Currency     : String(3);
        Stock        : Integer;
        Blocked      : Boolean;
        /** A date-time on the backend; the consumer exposes it as a Date. */
        ReleasedAt   : DateTime;
        /**
         * Rendered as sap:filterable="false" in the OData V2 $metadata: SAP Gateway services ignore a
         * $filter on such a field. The consumer opts in to in-memory evaluation with @remote.filter.local.
         */
        @sap.filterable: false
        InternalNote : String(100);
}

entity Categories {
    key ID   : String(4);
        Name : String(40);
}
