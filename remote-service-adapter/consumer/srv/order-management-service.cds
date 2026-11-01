/**
 * OrderManagementService: writes, write rules, deep writes, a non-CRUD API, actions and functions.
 *
 * No `@remote` here: the service has a handler file (order-management-service.js) whose class extends
 * RemoteApplicationService, so it adds handlers of its own and keeps every generic behavior.
 */
using { CustomerService as customers } from './external/CustomerService';
using { SalesService as sales } from './external/SalesService';
using from './external/extensions';

service OrderManagementService {

    /**
     * CREATE / UPDATE / DELETE are written to SalesService.Orders (producer-sales) in the source's names.
     * The projection's WHERE applies to writes too: CREATE fills Kind = 'STD', an update of a return order is 404.
     */
    entity Orders    as projection on sales.Orders {
        key ID,
            OrderName    as Title,
            Kind,
            Status,
            Customer,
            /** Checked before anything is written (CAP's @assert would run after the remote write). */
            @remote.assert: (case when Amount is null or Amount <= 0 then 'ORDER_AMOUNT_POSITIVE' end)
            Amount,
            Currency,
            OrderDate,
            Note,
            /** A backend-only value: clients cannot set it (CAP drops it), the handler sets it. */
            @readonly
            @UI.Hidden
            Channel,
            /**
             * Computed before the write when the data has none: reads the customer from producer-customers.
             * `@remote.write.truncate` cuts the computed text to the element's length (String(60)).
             */
            @remote.write.truncate
            @remote.write.value: (Customer || ' - ' || _Customer.Name)
            CustomerText,
            /** The customer must exist (ASSERT_TARGET), checked in CustomerService. */
            @remote.assert.target
            _Customer,
            /** Items in the payload are written with the order (one upsert per item). */
            @remote.write.deep
            _Items
    } where Kind = 'STD'
    actions {
        /** Forwarded to the bound action `cancel` of SalesService.Orders. */
        action   cancel()    returns Orders;
        /** Forwarded to the bound function `printForm`. */
        function printForm() returns String;
        /** Forwarded to the bound action `release` under another name. */
        @remote.operation: 'release'
        action   close()     returns Orders;
    };

    entity Items     as projection on sales.Items {
        key ID,
            OrderID,
            /** Checked on every child row of a deep write (CAP checks the root entity only). */
            @mandatory
            Product,
            @remote.assert: (case when Quantity is null or Quantity <= 0 then 'ITEM_QUANTITY_POSITIVE' end)
            Quantity,
            Price,
            Status
    };

    @readonly
    entity Customers as projection on customers.Customers {
        key ID,
            Name,
            Status
    };

    /** Deep writes into another entity of the same backend. */
    entity Projects  as projection on sales.Projects {
        key ProjectID,
            Name,
            Customer,
            StartDate,
            EndDate,
            @remote.write.deep
            _Packages : Association to many Packages on _Packages.ProjectID = $self.ProjectID
    };

    entity Packages  as projection on sales.Packages {
        key ProjectID,
        key PackageID,
            @mandatory
            Description
    };

    /** Write rules over associations, with message arguments. */
    entity Bookings  as projection on sales.Bookings {
        key ID,
            Customer,
            @remote.assert.target
            _Customer : Association to one Customers on _Customer.ID = $self.Customer,
            Project,
            @remote.assert: (case when not exists _Project or _Project.Customer != Customer then 'BOOKING_PROJECT_CUSTOMER' end)
            _Project  : Association to one Projects on _Project.ProjectID = $self.Project,
            @remote.assert: (case when Day < _Project.StartDate or Day > _Project.EndDate then 'BOOKING_OUTSIDE_PROJECT' end)
            @remote.assert.args: [Project, _Project.StartDate, _Project.EndDate]
            Day,
            Hours,
            /** String(20): "C003 - Cobalt Wholesale" is cut to 20 characters. */
            @remote.write.truncate
            @remote.write.value: (Customer || ' - ' || _Customer.Name)
            CustomerText
    };

    /**
     * A non-CRUD backend: every change is a POST that names the operation in the source field Op.
     * PATCH becomes POST with Op = 'U', DELETE becomes POST with Op = 'D'.
     */
    @remote.write.asInsert: ['UPDATE', 'DELETE']
    @remote.write.operation: { field: 'Op', CREATE: 'C', UPDATE: 'U', DELETE: 'D' }
    entity Entries   as projection on sales.Entries {
        key CompanyCode,
        key DocNo,
            Note,
            @readonly
            Released
    } actions {
        /** Implemented in the handler with readSource / writeSource. */
        action release() returns Entries;
    };

    /** Unbound operation of another service: the parameter names are the source operation's names. */
    @remote.operation: 'SalesService.upsertStatus'
    action   setOrderStatus(ID : String(10), Status : String(1)) returns Orders;

    /** Implemented in the handler: a query with path columns, aliases and an expression. */
    function orderCard(ID : String(10))                         returns OrderCard;

    /** Implemented in the handler: what the class API of RemoteApplicationService reports. */
    function adapterInfo()                                      returns {
        supportsSkipPagination : Boolean;
    };

    type OrderCard {
        ID             : String(10);
        Title          : String(60);
        Total          : Decimal(15, 2);
        CustomerName   : String(80);
        CustomerStatus : String(1);
        LoudTitle      : String(60);
    }
}
