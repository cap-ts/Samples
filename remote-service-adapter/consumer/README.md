# consumer: five services over four backends (port 5005)

The consumer owns one small table (`Regions`). Everything else it serves comes from the four producers, through
[`@cap-ts/remote-service-adapter`](https://www.npmjs.com/package/@cap-ts/remote-service-adapter): no READ handler, no
field mapping in code. The overview of the whole sample, how to run it and the scenario index are in
[../README.md](../README.md).

## Layout

```diagram
consumer/
├── package.json                      ← cds.requires (backends, mocked users), cds.query.remote, log levels
├── _i18n/messages.properties         ← texts of the write rules (@remote.assert)
├── db/
│   ├── schema.cds                    ← Regions: the consumer's own table
│   └── data/                         ← its CSV
├── srv/
│   ├── external/
│   │   ├── CustomerService.cds|edmx  ← cds import of producer-customers (OData V4)
│   │   ├── ProductService.cds|edmx   ← cds import of producer-products (OData V2)
│   │   ├── SalesService.cds|edmx     ← cds import of producer-sales (OData V4)
│   │   ├── PartnerDirectory.cds      ← the SOAP service of producer-partners, @Soap.* annotations
│   │   ├── lib/PartnerDirectory.js   ← its adapter class (@cap-ts/soap-adapter)
│   │   ├── wsdl/PartnerDirectory.wsdl
│   │   └── extensions.cds            ← associations between the imported models (across systems)
│   ├── catalog-service.cds           ← @remote, layer 1: reads over every backend kind
│   ├── overview-service.cds          ← @remote, layer 2 on CatalogService
│   ├── reference-data-service.cds    ← @remote + @remote.cache
│   ├── restricted-service.cds        ← @remote + @requires / @restrict
│   ├── order-management-service.cds  ← writes, rules, deep writes, operations
│   └── order-management-service.js   ← class extends RemoteApplicationService
└── test/http/*.http                  ← one request file per service (VS Code REST Client)
```

## The external models

The three OData models were generated from the producers' `$metadata` with `cds import`:

```bash
cds import srv/external/CustomerService.edmx --as cds
cds import srv/external/ProductService.edmx --as cds
cds import srv/external/SalesService.edmx --as cds
```

`cds import` also writes the `cds.requires` entries (`kind: "odata"` for V4, `"odata-v2"` for V2); `package.json` adds
the credentials. Regenerate them after a change to a producer: download `<service url>/$metadata` into the `.edmx`
file and import again.

**Associations across systems.** An imported navigation property can only point inside its own service, and EDMX
navigation properties often carry no ON condition. [`srv/external/extensions.cds`](srv/external/extensions.cds)
therefore declares the associations the projections use, each with its ON condition:

| Association | From | To |
| --- | --- | --- |
| `Customers._Group`, `._Contacts`; `Contacts._Customer` | producer-customers | producer-customers |
| `CustomerGroups._Region` | producer-customers | the consumer's database |
| `Products._Category` | producer-products | producer-products |
| `Orders._Customer` | producer-sales | producer-customers |
| `Orders._Items`, `Items._Order` | producer-sales | producer-sales |
| `Items._Product` | producer-sales | producer-products |
| `Partners._Customer` | producer-partners (SOAP) | producer-customers |

`$expand`, path columns (`_Customer._Group.Region`), filters through associations (`_Customer/_Group/Region eq
'AMER'`), `exists` flags, write rules and deep writes all join on these conditions.

## Configuration (`package.json`)

| Key | Purpose |
| --- | --- |
| `cds.requires.CustomerService` / `ProductService` / `SalesService` | `kind`, `model`; `[development]`: the producer URL with basic authentication; `[production]`: a BTP destination |
| `cds.requires.PartnerDirectory` | `kind: "soap"`, the local `wsdl`, `credentials.destination` and `credentials.path`. The destination `RSA_SAMPLES_PARTNERS` is defined in the `watch` scripts through the Cloud SDK's `destinations` environment variable |
| `cds.requires.auth` | Mocked users: `alice` (admin), `bob` (CompanyCode 1000), `kim` (CompanyCode 2000), `sam` (no CompanyCode); password = user name |
| `cds.query.remote` | The adapter's runtime settings: `pagesInParallel`, `search.maxRows`, `semiJoin`, `join.maxRows` (rows one source of a JOIN view may contribute; more is a 502), and the caches of aggregates and semi-join key sets (`cache.aggregates`, `cache.semiJoins`, `ttl`, `staleWhileRevalidate`, ...); `warmUp` runs the `@remote.warmUp` reads also in development (`enabled: true`) and makes the server wait for them (`await`: at most 15 seconds) |
| `cds.query.limit` | Page size when every row of a source is read |
| `cds.log.levels.remote: "info"` | Logs every backend request: `[remote] - GET http://localhost:7007/odata/v4/sales/Orders?$select=...` |

`npm run watch:trace` also sets `DEBUG=remote-service` and `LOG_TO_FILE=true`: the adapter's step-by-step trace, with
one correlation id per request, in `logs/remote-service-latest.log`.

## The services

### CatalogService (`/odata/v4/catalog`): one layer over every backend kind

`@remote`, no handler file. [`srv/catalog-service.cds`](srv/catalog-service.cds),
[`test/http/CatalogService.http`](test/http/CatalogService.http).

| Entity | Source | Shows |
| --- | --- | --- |
| `Customers` | producer-customers | alias (`Name as CustomerName`), structured fields (`Address.City as City`), path columns (`_Group.Name`, two hops into the database: `_Group._Region.Manager`), calculated columns (`left`, `concat`, `coalesce`), boolean flags (`IsBlocked`, pushed as `Status eq 'B'`; `IsActive` with `@remote.pushdown: false`), a `virtual` element, `@cds.search`, bound operations forwarded by name and by `@remote.operation` |
| `CustomerGroups`, `Contacts` | producer-customers | association targets |
| `setCustomerStatus` | producer-customers | unbound action forwarded to another service (`@remote.operation: 'CustomerService.setStatus'`) |
| `Regions` | the consumer's database | a database source |
| `Products` | producer-products (V2) | `@remote.filter.local` on the entity (`sap:filterable="false"` fields) and on an element, a `Date` over a date-time source, `@remote.search.maxRows`, `$count` from V2 |
| `Categories` | producer-products (V2) | `@remote.paging: false` |
| `Orders` | producer-sales | paths into another system (`_Customer.Name`, `_Customer._Group.Region`), associations across systems, an association with a constant in its ON condition (`_ActiveItems`) |
| `Items` | producer-sales | path into producer-products (`_Product.Name`) |
| `OrderStatus` | none | static data (`@response.data`) |
| `OrderLines` | producer-sales + producer-products | JOIN view: orders `join` items `left join` products (OData V4 + V2), an expression column (`i.Quantity * i.Price`), the view's WHERE, an ON constant, a mixin association `_Order`; a read by key starts at the items (`@cds.persistence.skip`, `@cds.persistence.mock: false`) |
| `PartnerCustomers` | producer-partners + producer-customers | JOIN view of a SOAP and an OData source (`@cds.persistence.skip`, `@cds.persistence.mock: false`: the SOAP entity has a table) |
| `GroupRegions` | producer-customers + the database | JOIN view of a remote source and the consumer's own table (`@cds.persistence.skip`, `@cds.persistence.mock: false`) |
| `ItemStatistics` | producer-sales | GROUP BY with `count`, `sum`, `max`; page size from `@cds.query.limit` |
| `Partners` | producer-partners (SOAP) | a SOAP source; an association from SOAP into OData (`$expand` with `$select`, filters through it); `$search` matched here |

### OverviewService (`/odata/v4/overview`): a second layer

`@remote` on top of CatalogService: each layer pushes down what it can to the layer below.
[`srv/overview-service.cds`](srv/overview-service.cds), [`test/http/OverviewService.http`](test/http/OverviewService.http).

| Entity | Shows |
| --- | --- |
| `Customers` | a rename of a rename (`CustomerName as Name`), `exists` flags (`case when exists _Contacts ...`, `exists _Contacts[Role = 'Accounting'] as ...`), `$search` handed to the layer below; `@remote.warmUp: { where: (HasAccounting = true) }` reads the semi-join's key set at start |
| `CustomerFinder` | a value help over the layer below: the same searched columns and a flag of its own (`HasContacts`) that is not searched; `$search`, `$top`, `$skip` and `$count` are sent down together, the flag is computed for the page |
| `ProductFinder` | a value help over an OData V2 source (case-sensitive `$search`) with a search copy: `@remote.warmUp: { every: 600, search: 'read' }` keeps the rows, `$search` is matched on them ignoring case with `$filter`, `$orderby`, the page and `$count` |
| `AvailableProducts` | a search copy with a `where` and `search: 'push'`: only a `$search` whose `$filter` contains `Blocked eq false` is answered from it; others, and every search before the warm-up filled it, go to the backend |
| `OrderFlags` | `exists` over an association with a constant ON condition, with an infix filter, through two hops into producer-products |
| `OpenOrders` | the projection's own WHERE: a plain term pushed, a to-one path and `$now` evaluated in memory; a read by key outside the WHERE is 404 |
| `MyOrders` | `where CreatedBy = $user` |
| `BusyCustomers` | GROUP BY with HAVING |
| `SalesByStatus` | GROUP BY on two columns, answered from the aggregate cache (`X-Cache: HIT`); `@remote.warmUp` fills the unfiltered and the `Status = 'O'` entry at start |
| `Currencies` | DISTINCT |
| `Entries` | writes through a second layer over a non-CRUD backend: the `@remote.write.*` settings CDS copied from `OrderManagementService.Entries` are applied once, by the layer below (one POST with `Op` per write) |

### ReferenceDataService (`/odata/v4/reference-data`): caching

`@remote` plus `@remote.cache: true` and `@remote.cache.ttl: 600` on the service; `@remote.cache.ttl: 60` and
`@remote.cache: false` on entities. Reads by key answer `X-Cache: MISS`, `HIT` or `PARTIAL; hits=..; misses=..`.
[`srv/reference-data-service.cds`](srv/reference-data-service.cds),
[`test/http/ReferenceDataService.http`](test/http/ReferenceDataService.http).

### RestrictedService (`/odata/v4/restricted`): CAP authorization on top

`@requires: 'authenticated-user'` and `@restrict` with `where: (CompanyCode = $user.CompanyCode)`: the condition is
pushed to the backend; a user without the attribute gets an empty answer without a backend call; an `$expand` of the
restricted entity is read through the service, so the restriction applies to it too.
[`srv/restricted-service.cds`](srv/restricted-service.cds),
[`test/http/RestrictedService.http`](test/http/RestrictedService.http).

### OrderManagementService (`/odata/v4/order-management`): writes

Implemented by [`srv/order-management-service.js`](srv/order-management-service.js), a class that extends
`RemoteApplicationService` (no `@remote`: the handler file is the implementation).
[`srv/order-management-service.cds`](srv/order-management-service.cds),
[`test/http/OrderManagementService.http`](test/http/OrderManagementService.http).

| Entity / operation | Shows |
| --- | --- |
| `Orders` | CREATE / UPDATE / DELETE written to producer-sales in its names; the projection's WHERE on writes (`Kind = 'STD'` filled in, other rows 404); `@remote.assert` and `@remote.assert.target` checked before anything is written; `@remote.write.value` + `@remote.write.truncate`; a `@readonly` backend-only value set by a `before` handler; `@remote.write.deep` items |
| `Items` | `@mandatory` and `@remote.assert` on child rows of a deep write |
| `Orders` actions | bound action and function forwarded by name, `@remote.operation: 'release'` under another name |
| `setOrderStatus` | unbound action of another service |
| `orderCard` | a handler query with path columns, aliases and an expression (`this.run(SELECT ...)`) |
| `Projects` / `Packages` | deep writes into a composite key, shape checks |
| `Bookings` | rules over associations (`not exists _Project`, `_Project.Customer != Customer`), message arguments (`@remote.assert.args`), all failures in one `MULTIPLE_ERRORS` |
| `Entries` | a non-CRUD backend: `@remote.write.asInsert` and `@remote.write.operation` turn PATCH and DELETE into POSTs with `Op`; a handler action with `readSource` / `writeSource` |

Two rules worth knowing:

- CAP validates the client's data before the adapter sees it: a client value longer than the element is a 400, so
  `@remote.write.truncate` is for values computed by `@remote.write.value` or set by a handler.
- `@mandatory` is checked on every row of a deep write, also on a row that updates an existing child.

## The SOAP service

[`srv/external/PartnerDirectory.cds`](srv/external/PartnerDirectory.cds) models the operation `GetPartners` as the
entity `Partners` with `@Soap.operation`, `@Soap.binding.rootResponse` and `@Soap.path` (the nested `Contact.Email`).
The adapter class [`srv/external/lib/PartnerDirectory.js`](srv/external/lib/PartnerDirectory.js) (found by the file
convention `lib/<Service>.js`) turns the request's key and its `PartnerID` / `Country` terms into the operation's
input; everything else is evaluated in memory. The SOAP service is also served on its own at
`/soap/partnerdirectory/Partners` by `@cap-ts/soap-adapter`.

The model imports the `@Soap` vocabulary (`using from '@cap-ts/soap-adapter'`), so `cds compile` checks the
annotations.
