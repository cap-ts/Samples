using { rsa.samples.sales as db } from '../db/schema';

service SalesService {
    entity Orders   as projection on db.Orders actions {
        /** Sets Status = 'C'. */
        action   cancel()    returns Orders;
        /** Sets Status = 'X'. */
        action   release()   returns Orders;
        /** A printable one-line summary. */
        function printForm() returns String;
    };

    entity Items    as projection on db.Items;
    entity Projects as projection on db.Projects;
    entity Packages as projection on db.Packages;
    entity Bookings as projection on db.Bookings;

    /**
     * A "non-CRUD" API, as some ERP interfaces are: every change is a POST that names the operation in `Op`
     * (C = create, U = update, D = delete). PATCH, PUT and DELETE answer 405.
     */
    entity Entries {
        key CompanyCode : String(4);
        key DocNo       : String(10);
            Note        : String(60);
            Released    : Boolean;
            Op          : String(1);
    }

    /** Unbound: sets the status of an order and returns it. */
    action upsertStatus(ID : String(10), Status : String(1)) returns Orders;
}
