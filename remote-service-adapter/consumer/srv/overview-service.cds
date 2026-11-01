/**
 * OverviewService: a second layer on top of CatalogService (also `@remote`).
 *
 * Each layer pushes down what it can to the layer below; renamed elements are translated layer by layer. This layer
 * shows what only makes sense on top of local entities: the projection's own WHERE with `$user` / `$now` and to-one
 * paths, `exists` flags, HAVING and DISTINCT, and writes through a second layer over a non-CRUD backend.
 */
using { CatalogService as catalog } from './catalog-service';
using { OrderManagementService as orders } from './order-management-service';

@remote
service OverviewService {

    /**
     * Renamed again (CustomerName -> Name) plus flags computed from to-many associations. `@remote.warmUp` reads
     * `HasAccounting = true` when the server starts and before the cached key set of the semi-join expires
     * (cds.query.remote.cache.semiJoins), so the first user filtering on the flag is answered from the cache too.
     */
    @readonly
    @remote.warmUp: { where: (HasAccounting = true) }
    entity Customers      as projection on catalog.Customers {
        key ID,
            CustomerName                                          as Name,
            City,
            Country,
            GroupName,
            RegionManager,
            Status,
            CompanyCode,
            IsBlocked,
            ValidTo,
            case when exists _Contacts then true else false end   as HasContacts   : Boolean,
            exists _Contacts[Role = 'Accounting']                 as HasAccounting : Boolean,
            _Contacts
    };

    /**
     * A value help over the layer below: it searches the same columns (`@cds.search` of CatalogService.Customers) and
     * adds a flag of its own that is not searched. The search goes down with the page and the count; the flag is
     * computed for the returned rows only.
     */
    @readonly
    @cds.redirection.target: false
    entity CustomerFinder as projection on catalog.Customers {
        key ID,
            CustomerName,
            City,
            Email,
            GroupName,
            case when exists _Contacts then true else false end   as HasContacts   : Boolean
    };

    @readonly
    entity Contacts       as projection on catalog.Contacts;

    /**
     * A product value help over an OData V2 source, whose `$search` is case-sensitive. `search: 'read'` keeps a copy
     * of the rows (filled by the warm-up at start and every 600 seconds; without it the first search reads it): `$search`
     * is matched on the copy ignoring case, with `$filter`, `$orderby`, the page and `$count` applied to it.
     */
    @readonly
    @cds.search: { Name, Description, CategoryName }
    @remote.warmUp: { every: 600, search: 'read' }
    entity ProductFinder  as projection on catalog.Products {
        key ID,
            Name,
            Description,
            CategoryName,
            Price,
            Currency,
            Blocked
    };

    /**
     * `search: 'push'` with a `where`: the copy holds the products that are not blocked. A `$search` whose `$filter`
     * contains `Blocked eq false` is answered from it ignoring case; any other goes to the backend (case-sensitive),
     * as does every search before the warm-up filled the copy.
     */
    @readonly
    @cds.search: { Name, Description }
    @remote.warmUp: { where: (Blocked = false), search: 'push' }
    entity AvailableProducts as projection on catalog.Products {
        key ID,
            Name,
            Description,
            Price,
            Currency,
            Blocked
    };

    /** Flags over to-many associations, an infix filter, and a path through two associations. */
    @readonly
    entity OrderFlags     as projection on catalog.Orders {
        key ID,
            Title,
            Amount,
            Currency,
            case when exists _ActiveItems then true else false end           as HasActiveItems    : Boolean,
            case when exists _Items[Quantity > 10] then true else false end  as HasLargeItems     : Boolean,
            exists _Items._Product[Blocked = true]                           as HasBlockedProduct : Boolean,
            _Items
    };

    /**
     * The projection's own WHERE: `Status = 'O'` is pushed to the backend, the to-one path and `$now` are evaluated
     * in memory. Reads by key re-check it (404 outside), and projections on top inherit it.
     */
    @readonly
    entity OpenOrders     as projection on catalog.Orders {
        key ID,
            Title,
            Amount,
            Currency,
            OrderDate,
            CustomerName,
            _Customer.ValidTo as CustomerValidTo
    } where Status = 'O' and _Customer.ValidTo >= $now;

    /** `$user` in the WHERE: every user sees the orders they created. */
    @readonly
    entity MyOrders       as projection on catalog.Orders {
        key ID,
            Title,
            Amount,
            Status,
            CreatedBy
    } where CreatedBy = $user;

    /**
     * Writes through a second layer over a non-CRUD backend. CDS copies `@remote.write.asInsert` and
     * `@remote.write.operation` of OrderManagementService.Entries to this projection; this layer sends the plain
     * CREATE / UPDATE / DELETE down and the layer below turns it into one POST with Op = 'C' / 'U' / 'D'.
     */
    entity Entries        as projection on orders.Entries;

    /** GROUP BY with HAVING: customers with more than one order. */
    @readonly
    entity BusyCustomers  as projection on catalog.Orders {
        key CustomerID,
            count(ID)   as Orders : Integer,
            sum(Amount) as Total  : Decimal(15, 2)
    } group by CustomerID having count(ID) > 1;

    /**
     * GROUP BY on two columns: the aggregate cache (cds.query.remote.cache.aggregates) answers repeated reads.
     * `@remote.warmUp` fills it at start for the unfiltered read and for `Status = 'O'`, one entry each, and renews them
     * before their time to live (cds.query.remote.cache.ttl) ends. The third record is kept but switched off
     * (`enabled: false`): no read for `Status = 'C'` (the log shows two warm-up lines of SalesByStatus, not three).
     */
    @readonly
    @remote.warmUp: [
        { limit: 1 },
        { where: (Status = 'O') },
        { where: (Status = 'C'), enabled: false }
    ]
    entity SalesByStatus  as projection on catalog.Orders {
        key Status,
        key Currency,
            count(ID)   as Orders  : Integer,
            sum(Amount) as Total   : Decimal(15, 2),
            max(Amount) as Largest : Decimal(15, 2)
    } group by Status, Currency;

    /**
     * GROUP BY written as `select from`, with `distinct`: the same groups as the `projection on` form (SalesByStatus),
     * every group with its aggregates; the key is one of the two group columns.
     */
    @readonly
    entity OrderMix       as select from catalog.Orders distinct {
        key Status,
            Currency,
            count(ID)   as Orders : Integer,
            sum(Amount) as Total  : Decimal(15, 2)
    } group by Status, Currency;

    /** DISTINCT */
    @readonly
    entity Currencies     as select from catalog.Orders distinct {
        key Currency
    };
}
