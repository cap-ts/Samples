/**
 * RestrictedService: CAP's own authorization on top of the adapter, which has none of its own.
 *
 * `@restrict ... where` with a user attribute: CAP adds the condition to the query, the adapter pushes it to the
 * backend. A user without the attribute gets the literal `'1' = '2'`: an empty answer without a backend call.
 * CAP checks `@restrict` only on the entity a request targets; an `$expand` of Orders/_Customer is therefore read
 * through RestrictedService.Customers (not pushed to the backend as $expand), so the restriction applies there too.
 */
using { CustomerService as customers } from './external/CustomerService';
using { SalesService as sales } from './external/SalesService';
using from './external/extensions';

@remote
@requires: 'authenticated-user'
service RestrictedService {

    @readonly
    @restrict: [
        { grant: 'READ', to: 'admin' },
        { grant: 'READ', where: (CompanyCode = $user.CompanyCode) }
    ]
    entity Customers as projection on customers.Customers {
        key ID,
            Name,
            CompanyCode,
            Status
    };

    @readonly
    entity Orders    as projection on sales.Orders {
        key ID,
            OrderName as Title,
            Amount,
            Currency,
            Customer  as CustomerID,
            _Customer
    };
}
