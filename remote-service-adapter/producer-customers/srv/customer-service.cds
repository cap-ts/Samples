using { rsa.samples.customers as db } from '../db/schema';

service CustomerService {
    entity Customers      as projection on db.Customers actions {
        /** Sets Status = 'B' and returns the customer. */
        action   block()                                returns Customers;
        /** true when the amount fits into the customer's credit limit. */
        function creditCheck(Amount : Decimal(15, 2)) returns Boolean;
    };

    entity CustomerGroups as projection on db.CustomerGroups;
    entity Contacts       as projection on db.Contacts;

    /** Unbound: sets the status of a customer and returns it. */
    action setStatus(ID : String(10), Status : String(1)) returns Customers;
}
