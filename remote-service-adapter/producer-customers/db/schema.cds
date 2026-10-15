using { managed } from '@sap/cds/common';

namespace rsa.samples.customers;

/** Postal address, kept as a structured element so the consumer can flatten it (`Address.City as City`). */
type Address {
    Street     : String(60);
    City       : String(40);
    PostalCode : String(10);
    Country    : String(3);
}

entity Customers : managed {
    key ID          : String(10);
        Name        : String(80);
        Email       : String(100);
        Phone       : String(20);
        /** A = active, B = blocked */
        Status      : String(1);
        CompanyCode : String(4);
        Address     : Address;
        ValidFrom   : Date;
        ValidTo     : Date;
        CreditLimit : Decimal(15, 2);
        GroupID     : String(4);
        group       : Association to CustomerGroups on group.ID = GroupID;
        contacts    : Composition of many Contacts on contacts.CustomerID = ID;
}

entity CustomerGroups {
    key ID     : String(4);
        Name   : String(40);
        /** EMEA, AMER, APJ */
        Region : String(4);
}

entity Contacts {
    key ID         : String(10);
        CustomerID : String(10);
        customer   : Association to Customers on customer.ID = CustomerID;
        Name       : String(80);
        Email      : String(100);
        Role       : String(20);
}
