/**
 * ReferenceDataService: the opt-in caches of @cap-ts/remote-service-adapter.
 *
 * `@remote.cache: true` on the service caches reads by key of every entity (`Entity('K')`, `$filter=Key eq 'K'`,
 * `Key in (...)`, the key reads behind `$expand` and path columns) for `@remote.cache.ttl` seconds. The response
 * header X-Cache says HIT, MISS or PARTIAL. `@remote` and `@remote.cache` are two annotations:
 * `@remote: { cache: true }` would compile to `@remote.cache` only and the service would not be served.
 */
using { CustomerService as customers } from './external/CustomerService';
using { ProductService as products } from './external/ProductService';
using from './external/extensions';

@remote
@remote.cache: true
@remote.cache.ttl: 600
service ReferenceDataService {

    /** Service settings: cached for 600 seconds. */
    @readonly
    entity CustomerGroups as projection on customers.CustomerGroups {
        key ID,
            Name,
            Region
    };

    /** Its own time to live. */
    @readonly
    @remote.cache.ttl: 60
    entity Categories     as projection on products.Categories;

    /** Opted out: stock changes all the time. */
    @readonly
    @remote.cache: false
    entity Stock          as projection on products.Products {
        key ID,
            Name,
            Stock
    };

    /** `ID in ('C001', 'C002')` reads only the keys that are not cached yet. */
    @readonly
    entity CustomerNames  as projection on customers.Customers {
        key ID,
            Name,
            GroupID,
            _Group
    };
}
