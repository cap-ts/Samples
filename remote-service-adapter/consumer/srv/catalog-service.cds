/**
 * CatalogService: read access to every backend kind, one layer directly on the remote models.
 *
 * `@remote` is the whole opt-in: the plugin of @cap-ts/remote-service-adapter makes RemoteApplicationService the
 * implementation. There is no handler file. Every entity is served from its source: CustomerService (OData V4,
 * producer-customers), ProductService (OData V2, producer-products), SalesService (OData V4, producer-sales), PartnerDirectory (SOAP,
 * producer-partners) or the consumer's database.
 *
 * `_Customer : redirected to Customers` (Partners) points an association of the source at an entity of this service.
 */
using { CustomerService as customers } from './external/CustomerService';
using { ProductService as products } from './external/ProductService';
using { SalesService as sales } from './external/SalesService';
using { PartnerDirectory as partners } from './external/PartnerDirectory';
using { rsa.samples.consumer as db } from '../db/schema';
using from './external/extensions';

@remote
service CatalogService {

    // ---------------------------------------------------------------- OData V4 (producer-customers)

    /**
     * The local <-> remote mapping comes from the projection: aliases, structured fields, path columns, calculated
     * columns, boolean flags and virtual elements. Nothing is mapped in code.
     */
    @readonly
    @cds.search: { CustomerName, City, Email, GroupName }
    entity Customers      as projection on customers.Customers {
        key ID,
            Name                                            as CustomerName, // alias: CustomerName <-> Name
            Email,
            Phone,
            Status,
            CompanyCode,
            Address.City                                    as City,         // field of a structured element
            Address.Country                                 as Country,
            ValidFrom,
            ValidTo,
            CreditLimit,
            GroupID,
            _Group.Name                                     as GroupName,    // to-one path column
            _Group._Region.Manager                          as RegionManager, // two hops: remote, then the database
            left(Name, 1)                                   as Initial       : String(1), // filter pushed as startswith
            concat(Name, ' (', CompanyCode, ')')            as DisplayName   : String(100),
            coalesce(Phone, Email)                          as Reachable     : String(100),
            case when Status = 'B' then true else false end as IsBlocked     : Boolean, // filter pushed as Status = 'B'
            @remote.pushdown: false                                          // filter stays in memory
            case when Status = 'A' then true else false end as IsActive      : Boolean,
            virtual Selected                                                 : Boolean, // never requested
            _Group,
            _Contacts
    } actions {
        /** Forwarded to the bound action `block` of CustomerService.Customers (same name). */
        action   block()                                returns Customers;
        /** Forwarded to the bound function `creditCheck`. */
        function creditCheck(Amount : Decimal(15, 2)) returns Boolean;
        /** Forwarded to the bound action `block` under another name. */
        @remote.operation: 'block'
        action   lock()                                 returns Customers;
    };

    @readonly
    entity CustomerGroups as projection on customers.CustomerGroups {
        key ID,
            Name,
            Region,
            _Region
    };

    @readonly
    entity Contacts       as projection on customers.Contacts {
        key ID,
            CustomerID,
            Name,
            Email,
            Role,
            _Customer
    };

    /** Unbound operation of another service: the parameters are sent as they are. */
    @remote.operation: 'CustomerService.setStatus'
    action setCustomerStatus(ID : String(10), Status : String(1)) returns Customers;

    // ---------------------------------------------------------------- the consumer's database

    /** A projection on a database entity: CAP's own database service answers it. */
    @readonly
    entity Regions        as projection on db.Regions;

    // ---------------------------------------------------------------- OData V2 (producer-products)

    /**
     * `@remote.filter.local` on the entity: every field the V2 $metadata declares sap:filterable="false"
     * (InternalNote) is filtered in memory instead of being ignored by the backend. On an element it opts in that
     * element only (Currency), `@remote.filter.local: false` opts one out.
     * $search on an odata-v2 source is case-sensitive.
     */
    @readonly
    @remote.filter.local
    @remote.search.maxRows: 1000
    entity Products       as projection on products.Products {
        key ID,
            Name,
            Description,
            category_ID                as CategoryID,
            _Category.Name             as CategoryName,
            Price,
            @remote.filter.local
            Currency,
            Stock,
            Blocked,
            ReleasedAt                 as ReleaseDate : Date, // a date-time source delivered as a date
            InternalNote,
            _Category
    };

    /** `@remote.paging: false`: a read of every row is one request, for a backend that cannot page. */
    @readonly
    @remote.paging: false
    entity Categories     as projection on products.Categories;

    // ---------------------------------------------------------------- OData V4 (producer-sales)

    /**
     * Associations to other systems: `_Customer` (producer-customers) and `_Items` -> `_Product` (producer-products).
     * `$expand`, path columns and filters through these associations are resolved by the adapter.
     */
    @readonly
    @cds.redirection.target
    entity Orders         as projection on sales.Orders {
        key ID,
            OrderName                                       as Title,
            Kind,
            Status,
            Customer                                        as CustomerID,
            Amount,
            Currency,
            OrderDate,
            Note,
            createdBy                                       as CreatedBy,
            _Customer.Name                                  as CustomerName,   // path into another system
            _Customer._Group.Region                         as CustomerRegion, // two hops, two systems
            case when Status = 'X' then true else false end as IsClosed : Boolean,
            _Customer,
            _Items,
            _ActiveItems : Association to many Items on _ActiveItems.OrderID = $self.ID and _ActiveItems.Status = 'Active'
    };

    @readonly
    @cds.redirection.target
    entity Items          as projection on sales.Items {
        key ID,
            OrderID,
            Product        as ProductID,
            _Product.Name  as ProductName,
            Quantity,
            Price,
            Status,
            _Order,
            _Product
    };

    /** Static data: returned from the annotation, no backend call. */
    @readonly
    @response.data: [
        { code: 'O', name: 'Open' },
        { code: 'X', name: 'Closed' },
        { code: 'C', name: 'Cancelled' }
    ]
    entity OrderStatus    as projection on sales.Orders {
        key Status as code,
            Note   as name
    };

    /**
     * A JOIN view over two systems: orders and items of SalesService (OData V4), left-joined to the products of
     * ProductService (OData V2). The sources are joined here: `$filter` terms on plain columns of one source are pushed to
     * it, a read by key starts at the source of the key, every next source is read by the join keys found. The view's
     * own WHERE, the constant of the ON condition and the expression column apply; `_Order` (a mixin) can be expanded.
     */
    @readonly
    @cds.persistence.skip          // no database view: its sources are remote
    @cds.persistence.mock : false  // keeps the skip when cds watch mocks the remote services
    entity OrderLines     as
        select from sales.Orders as o
        join sales.Items as i on i.OrderID = o.ID and i.Status = 'Active'
        left join products.Products as p on p.ID = i.Product
        mixin {
            _Order : Association to one Orders on _Order.ID = $projection.OrderID;
        }
        into {
            key i.ID,
                o.ID                     as OrderID,
                o.OrderName              as Title,
                o.Currency,
                i.Product                as ProductID,
                p.Name                   as ProductName,
                i.Quantity,
                i.Price,
                i.Quantity * i.Price     as LineTotal : Decimal(15, 2),
                _Order
        }
        where o.Kind = 'STD';

    /** A JOIN view of a SOAP source and an OData source: partners (producer-partners) with their customers (producer-customers). */
    @readonly
    @cds.persistence.skip          // no database view: it joins a remote entity with one that has a table
    @cds.persistence.mock : false  // keeps the skip when cds watch mocks the remote services
    entity PartnerCustomers as
        select from partners.Partners as pa
        join customers.Customers as c on c.ID = pa.Customer {
            key pa.PartnerID,
                pa.Name      as PartnerName,
                pa.Country,
                c.ID         as CustomerID,
                c.Name       as CustomerName,
                c.Status     as CustomerStatus
        };

    /** A JOIN view of a remote source and the consumer's database: customer groups with the manager of their region. */
    @readonly
    @cds.persistence.skip          // no database view: it joins a remote entity with one that has a table
    @cds.persistence.mock : false  // keeps the skip when cds watch mocks the remote services
    entity GroupRegions   as
        select from customers.CustomerGroups as g
        join db.Regions as r on r.code = g.Region {
            key g.ID,
                g.Name,
                r.Name       as RegionName,
                r.Manager
        };

    /** GROUP BY over every row of the remote source, read in pages of @cds.query.limit.max (see extensions.cds). */
    @readonly
    entity ItemStatistics as projection on sales.Items {
        key Product         as ProductID,
            count(ID)       as Lines    : Integer,
            sum(Quantity)   as Quantity : Integer,
            max(Price)      as MaxPrice : Decimal(15, 2)
    } group by Product;

    // ---------------------------------------------------------------- SOAP (producer-partners)

    /** A SOAP source through @cap-ts/soap-adapter, with an association to an OData system. */
    @readonly
    entity Partners       as projection on partners.Partners {
        key PartnerID,
            Name,
            Country,
            Customer as CustomerID,
            Email,
            Phone,
            _Customer : redirected to Customers   // explicit: CAP would pick Customers here by itself
    };

    /**
     * A SOAP operation that takes exactly one PartnerID per call (`@Soap.filterRestriction` in
     * external/PartnerDirectory.cds). `cds.query.remote.agentHints` names the mandatory filter in this entity's docs
     * (MCP describe, `$metadata`), and `cds.query.soap.agentHints` adds the SOAP hints of the source entity; a read
     * without it is a 400 before any call, a list of partners is one call per partner.
     */
    @readonly
    entity PartnerChannels as projection on partners.Channels {
        key PartnerID,
        key Channel,
            Address
    };

    // ---------------------------------------------------------------- limits for expensive reads

    /**
     * `@remote.search.maxRows`: a `$search` here reads every matching order and then the path column CustomerName of
     * each (producer-customers). More than two matches is a 502 naming `$filter`, so a client narrows the request
     * instead of letting it read across systems. `cds.query.remote.search.maxRows` sets the limit for every entity.
     */
    @readonly
    @remote.search.maxRows: 2
    @cds.search: { Title, CustomerName }
    entity OrderSearch     as projection on sales.Orders {
        key ID,
            OrderName      as Title,
            _Customer.Name as CustomerName
    };
}
