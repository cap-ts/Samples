using { managed } from '@sap/cds/common';

namespace rsa.samples.sales;

entity Orders : managed {
    key ID           : String(10);
        OrderName    : String(60);
        /** STD = standard order, RET = return */
        Kind         : String(3);
        /** O = open, X = closed, C = cancelled */
        Status       : String(1);
        /** ID of a customer of producer-customers (another system: no association here) */
        Customer     : String(10);
        Amount       : Decimal(15, 2);
        Currency     : String(3);
        OrderDate    : DateTime;
        Note         : String(40);
        /** Set by the consumer's handler, never by its clients. */
        Channel      : String(10);
        CustomerText : String(60);
        items        : Association to many Items on items.OrderID = $self.ID;
}

entity Items {
    key ID       : String(10);
        OrderID  : String(10);
        /** ID of a product of producer-products */
        Product  : String(10);
        Quantity : Integer;
        Price    : Decimal(15, 2);
        /** Active, Inactive */
        Status   : String(10);
}

entity Projects {
    key ProjectID : String(10);
        Name      : String(60);
        Customer  : String(10);
        StartDate : Date;
        EndDate   : Date;
}

entity Packages {
    key ProjectID   : String(10);
    key PackageID   : String(10);
        Description : String(60);
}

entity Bookings {
    key ID           : String(10);
        Customer     : String(10);
        Project      : String(10);
        Day          : Date;
        Hours        : Decimal(5, 2);
        CustomerText : String(20);
}

/** The table behind the ledger API (see Entries in the service). */
entity LedgerEntries {
    key CompanyCode : String(4);
    key DocNo       : String(10);
        Note        : String(60);
        Released    : Boolean default false;
}
