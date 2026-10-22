# cap-ts Samples: @cap-ts/remote-service-adapter

A runnable landscape of five [SAP CAP](https://cap.cloud.sap/docs/) (Node.js) apps that shows what
[`@cap-ts/remote-service-adapter`](https://www.npmjs.com/package/@cap-ts/remote-service-adapter) does: CDS projections
on remote OData V4, OData V2 and SOAP services (and on the local database) become working OData endpoints, for reading,
writing and operations, without handler code and without field mapping in code.

---

## 📑 Table of Contents

🗂️ [Repository layout](#️-repository-layout)\
🔗 [The landscape](#-the-landscape)\
▶️ [Running the sample locally](#️-running-the-sample-locally)\
🧪 [Trying it out](#-trying-it-out)\
🗺️ [Scenario index](#️-scenario-index)\
🔍 [Watching what goes to the backends](#-watching-what-goes-to-the-backends)\
🚧 [Not covered](#-not-covered)\
💬 [Support & feedback](#-support--feedback)

---

## 🗂️ Repository layout

```diagram
remote-service-adapter/
├── README.md               ← this file
├── producer-customers/     ← CustomerService     OData V4             (port 9009)
├── producer-products/      ← ProductService      OData V2             (port 8008)
├── producer-sales/         ← SalesService        OData V4, writable   (port 7007)
├── producer-partners/      ← PartnerDirectory    SOAP, plain Node.js  (port 6006)
└── consumer/               ← five services over all four            (port 5005)
```

Each app has its own README: [producer-customers](producer-customers/README.md),
[producer-products](producer-products/README.md), [producer-sales](producer-sales/README.md),
[producer-partners](producer-partners/README.md), [consumer](consumer/README.md).

---

## 🔗 The landscape

```diagram
                          Client (OData V4, test/http/*.http)
                                          │
                                          ▼
┌───────────────────────────────── consumer (5005) ──────────────────────────────────┐
│ OverviewService ──► CatalogService          ReferenceDataService (cache)           │
│   (layer 2)          (layer 1, JOIN views)  RestrictedService (@restrict)          │
│                                             OrderManagementService (writes)        │
│              @cap-ts/remote-service-adapter            own db: Regions             │
└─────────┬──────────────────────┬──────────────────────┬──────────────────────┬─────┘
          │ OData V4             │ OData V2             │ OData V4             │ SOAP
          ▼                      ▼                      ▼                      ▼
   producer-customers     producer-products      producer-sales         producer-partners
   (9009)                 (8008)                 (7007)                 (6006)
   Customers              Products               Orders, Items          PartnerDirectory
   CustomerGroups         Categories             Projects, Packages       GetPartners
   Contacts                                      Bookings, Entries
```

| App | Backend kind | Data | Port |
| --- | --- | --- | --- |
| `producer-customers` | OData V4 (CAP) | customers with a structured address, customer groups, contacts; bound and unbound operations | 9009 |
| `producer-products` | OData V2 (CAP + `@cap-js-community/odata-v2-adapter`) | products (one `sap:filterable="false"` field, a date-time), categories | 8008 |
| `producer-sales` | OData V4 (CAP), writable | orders, items, projects, packages, bookings, and a non-CRUD ledger API; bound and unbound operations | 7007 |
| `producer-partners` | SOAP 1.1 (plain Node.js, `soap`) | partners with a nested contact, one operation `GetPartners` | 6006 |
| `consumer` | | five services, all served by `RemoteApplicationService` | 5005 |

The data is linked across systems: an order (producer-sales) has a customer (producer-customers) and items whose
products live in producer-products; a customer group (producer-customers) points to a region in the consumer's own
database; a partner (producer-partners, SOAP) points to a customer (producer-customers). The consumer declares these
associations in [`consumer/srv/external/extensions.cds`](consumer/srv/external/extensions.cds).

---

## ▶️ Running the sample locally

**Prerequisites:** Node.js 22 or later, the CAP development kit for `cds watch` (`npm i -g @sap/cds-dk`), and for
trying it out the VS Code [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)
extension (or any HTTP client).

**1. Start the four producers**, each in its own terminal:

```bash
cd remote-service-adapter/producer-customers && npm install && npm run watch
cd remote-service-adapter/producer-products && npm install && npm run watch
cd remote-service-adapter/producer-sales && npm install && npm run watch
cd remote-service-adapter/producer-partners && npm install && npm run watch
```

**2. Start the consumer:**

```bash
cd remote-service-adapter/consumer && npm install && npm run watch
```

The consumer's `package.json` already points to the producers on `localhost` (profile `development`, basic
authentication with the mocked user `alice`), and its `watch` script defines the destination of the SOAP service
(`RSA_SAMPLES_PARTNERS`, through the Cloud SDK's `destinations` environment variable). Under profile `production` the
OData services use the BTP destinations `RSA_SAMPLES_CUSTOMERS`, `RSA_SAMPLES_PRODUCTS` and `RSA_SAMPLES_SALES`.

The scripts set the port with `PORT=<port> ...`, which works in macOS / Linux shells. On Windows run
`cds watch --port <port>` (`cds-serve --port 8008` for producer-products), and for the consumer set the `destinations`
variable as in its `watch` script.

producer-products runs `cds-serve`, not `cds watch`, also in its `watch` script. `cds watch` registers every service it
serves in the local binding registry (`~/.cds/services/<port>.json`, `~/.cds-services.json` before `@sap/cds` 10.2),
and the consumer, also under `cds watch`, takes the URL of a required service from there. The registry knows only the
OData V4 endpoint of ProductService, so the consumer would read `/odata/v4/product` with `kind: odata` instead of the
V2 endpoint of its configuration, and none of the OData V2 scenarios would run. If ProductService was started with
`cds watch` before, delete `~/.cds/services/8008.json`. The consumer's log shows which endpoint it uses:

```text
[cds] - connect to ProductService > odata-v2 { url: 'http://localhost:8008/odata/v2/product', ... }
```

The boot log of the consumer names `RemoteApplicationService` as the implementation of the `@remote` services and the
class of `order-management-service.js` for OrderManagementService:

```text
[cds] - serving CatalogService {
  at: [ '/odata/v4/catalog' ],
  impl: 'node_modules/@cap-ts/remote-service-adapter/src/lib/RemoteApplicationService.js'
}
```

---

## 🧪 Trying it out

[`consumer/test/http/`](consumer/test/http) has one request file per service. Every request has a comment that says
what it shows and what to expect; run them top to bottom.

| File | Service | Covers |
| --- | --- | --- |
| [`CatalogService.http`](consumer/test/http/CatalogService.http) | `/odata/v4/catalog` | mapping, push-down, paths, `$expand`, `$search`, navigation, operations, OData V2, SOAP, static data, GROUP BY |
| [`OverviewService.http`](consumer/test/http/OverviewService.http) | `/odata/v4/overview` | layered services, `exists` flags, the projection's WHERE with `$user` / `$now`, HAVING, DISTINCT, the aggregate cache |
| [`ReferenceDataService.http`](consumer/test/http/ReferenceDataService.http) | `/odata/v4/reference-data` | the cache of reads by key (`X-Cache`) |
| [`RestrictedService.http`](consumer/test/http/RestrictedService.http) | `/odata/v4/restricted` | `@requires`, `@restrict` with a user attribute, restricted `$expand` |
| [`OrderManagementService.http`](consumer/test/http/OrderManagementService.http) | `/odata/v4/order-management` | writes, write rules, deep writes, a non-CRUD API, actions, functions, `readSource` / `writeSource` |

Users (password = user name): `alice` (admin), `bob` (CompanyCode 1000), `kim` (CompanyCode 2000), `sam` (no
CompanyCode). The writes change producer-sales's in-memory data; restart producer-sales to reset it.

---

## 🗺️ Scenario index

Where each feature of the package is shown. Model files are under `consumer/srv/`, requests under
`consumer/test/http/`.

### Modelling and reading

| Feature | Model | Request |
| --- | --- | --- |
| Opt-in with `@remote`, no handler file | every `@remote` service | all |
| Field alias (`Name as CustomerName`) | `CatalogService.Customers` | `CatalogService.http` |
| Structured field (`Address.City as City`) | `CatalogService.Customers` | `CatalogService.http` |
| Path column, one hop / two hops / into another system / into the database | `CatalogService.Customers`, `.Orders`, `.Items` | `CatalogService.http` |
| JOIN views: inner and left joins, three sources over two systems, a SOAP source, a database source, an expression column, the view's WHERE, ON constants, a mixin association; reads by key, pushed filters, `$search`, `$orderby`, `$count`; rows per source capped by `cds.query.remote.join.maxRows` | `CatalogService.OrderLines`, `.PartnerCustomers`, `.GroupRegions` | `CatalogService.http` |
| `@cds.persistence.skip` and `@cds.persistence.mock: false` on the JOIN views (no database view; `cds watch` keeps the skip) | `CatalogService.OrderLines`, `.PartnerCustomers`, `.GroupRegions` | |
| Calculated column (`left`, `concat`, `coalesce`) | `CatalogService.Customers` | `CatalogService.http` |
| `left(...)` filter pushed as `startswith` | `CatalogService.Customers.Initial` | `CatalogService.http` |
| Boolean flag pushed as `Field = 'v'`; `@remote.pushdown: false` | `CatalogService.Customers.IsBlocked`, `.IsActive` | `CatalogService.http` |
| `virtual` element | `CatalogService.Customers.Selected` | |
| `$filter` split: pushed part and in-memory part | `CatalogService.Customers` | `CatalogService.http` |
| `$search`, `@cds.search`, path columns in the search | `CatalogService.Customers`, `.Products` | `CatalogService.http` |
| `$search` with `&`: unquoted, CAP ends the term at the `&` (also `%26`); quoted (`%22...%22`), the whole phrase | `CatalogService.Customers` | `CatalogService.http` |
| `$search` through two layers | `OverviewService.Customers` | `OverviewService.http` |
| `$search` through a layer with a flag of its own that is not searched: the search, `$top`, `$skip` and `$count` go down together | `OverviewService.CustomerFinder` | `OverviewService.http` |
| `$expand`, nested, with `$select`, across systems, into the database | `CatalogService` | `CatalogService.http` |
| `$top` / `$orderby` / `$count` inside an `$expand`, per parent | `CatalogService.Orders` | `CatalogService.http` |
| Navigation by key (`Orders('O006')/_Items`) | `CatalogService.Orders` | `CatalogService.http` |
| Filters through associations (semi-joins), `any()`, several hops, several systems | `CatalogService.Orders`, `.Items` | `CatalogService.http` |
| Key lists as reads by key; unknown key 404 | `CatalogService.Orders` | `CatalogService.http` |
| `$orderby` on a path column, paging, `$count`, count only | `CatalogService.Orders`, `.Products` | `CatalogService.http` |
| Static data (`@response.data`) | `CatalogService.OrderStatus` | `CatalogService.http` |
| GROUP BY with aggregates, `@cds.query.limit` | `CatalogService.ItemStatistics`, `OverviewService.SalesByStatus` | both |
| HAVING | `OverviewService.BusyCustomers` | `OverviewService.http` |
| DISTINCT | `OverviewService.Currencies` | `OverviewService.http` |
| Layered services, renames per layer | `OverviewService` on `CatalogService` | `OverviewService.http` |
| `exists` flags (constant ON condition, infix filter, two hops), filter on a flag | `OverviewService.Customers`, `.OrderFlags` | `OverviewService.http` |
| The projection's own WHERE: pushed, in memory, `$now`, to-one path; 404 outside | `OverviewService.OpenOrders` | `OverviewService.http` |
| `$user` in the WHERE | `OverviewService.MyOrders` | `OverviewService.http` |
| Database source | `CatalogService.Regions` | `CatalogService.http` |

### Backends

| Feature | Model | Request |
| --- | --- | --- |
| OData V4 | producer-customers, producer-sales | all |
| OData V2: `$inlinecount`, count as text | `CatalogService.Products` | `CatalogService.http` |
| `@remote.filter.local` (entity: `sap:filterable="false"` fields; element) | `CatalogService.Products` | `CatalogService.http` |
| `Date` over a date-time source (`ReleasedAt as ReleaseDate : Date`) | `CatalogService.Products` | `CatalogService.http` |
| `@remote.paging: false` | `CatalogService.Categories` | `CatalogService.http` |
| `@remote.search.maxRows` | `CatalogService.Products` | |
| SOAP through `@cap-ts/soap-adapter`: model, adapter class, key and filter push to the operation | `CatalogService.Partners`, `external/PartnerDirectory.*` | `CatalogService.http` |
| From SOAP into OData: `$expand` with `$select` of renamed columns, filters through the association, `$search` on the SOAP entity | `CatalogService.Partners` | `CatalogService.http` |
| Development credentials vs. production destinations | `consumer/package.json` | |

### Caching

| Feature | Model / setting | Request |
| --- | --- | --- |
| Rows by key: `@remote.cache` on the service, `@remote.cache.ttl` on service and entity, `@remote.cache: false` | `ReferenceDataService` | `ReferenceDataService.http` |
| `X-Cache: MISS`, `HIT`, `PARTIAL` | `ReferenceDataService.CustomerNames` | `ReferenceDataService.http` |
| Aggregates (`cds.query.remote.cache.aggregates`) | `OverviewService.SalesByStatus` | `OverviewService.http` |
| Semi-join key sets, stale-while-revalidate, time to live | `cds.query.remote.cache.*` in `package.json` | |
| Warm-up at start and before the time to live ends: `@remote.warmUp` with a `where` per record, `cds.query.remote.warmUp` (`enabled`, `await`) | `OverviewService.SalesByStatus`, `OverviewService.Customers` | `OverviewService.http` |

### Security

| Feature | Model | Request |
| --- | --- | --- |
| `@requires: 'authenticated-user'` (401 without user) | `RestrictedService` | `RestrictedService.http` |
| `@restrict ... where (CompanyCode = $user.CompanyCode)` pushed to the backend | `RestrictedService.Customers` | `RestrictedService.http` |
| Missing user attribute: empty answer, no backend call | `RestrictedService.Customers` | `RestrictedService.http` |
| `$expand` of a restricted target read through its service | `RestrictedService.Orders` | `RestrictedService.http` |

### Writing and operations

| Feature | Model | Request |
| --- | --- | --- |
| CREATE / UPDATE / DELETE through a projection with aliases | `OrderManagementService.Orders` | `OrderManagementService.http` |
| The projection's WHERE on writes (value filled in, contradiction 400, outside 404) | `OrderManagementService.Orders` | `OrderManagementService.http` |
| Subclass of `RemoteApplicationService` with `before` / `on` handlers | `order-management-service.js` | `OrderManagementService.http` |
| Backend-only `@readonly` value set by a handler | `OrderManagementService.Orders.Channel` | `OrderManagementService.http` |
| `@remote.assert`, `@remote.assert.target`, `@remote.assert.args`, i18n messages, `MULTIPLE_ERRORS` | `OrderManagementService.Orders`, `.Bookings` | `OrderManagementService.http` |
| `@remote.write.value`, `@remote.write.truncate` | `OrderManagementService.Orders`, `.Bookings` | `OrderManagementService.http` |
| Deep writes (`@remote.write.deep`): create, upsert, composite keys, `@mandatory` on child rows, shape check | `OrderManagementService.Orders`, `.Projects` | `OrderManagementService.http` |
| Non-CRUD backend (`@remote.write.asInsert`, `@remote.write.operation`) | `OrderManagementService.Entries` | `OrderManagementService.http` |
| `readSource` / `writeSource` | `order-management-service.js` (`Entries.release`) | `OrderManagementService.http` |
| A handler's query with path columns, aliases, expressions | `order-management-service.js` (`orderCard`) | `OrderManagementService.http` |
| Bound action / function forwarded by name; `@remote.operation` with another name | `CatalogService.Customers`, `OrderManagementService.Orders` | both |
| Unbound operation of another service (`@remote.operation: '<Service>.<name>'`) | `CatalogService.setCustomerStatus`, `OrderManagementService.setOrderStatus` | both |

---

## 🔍 Watching what goes to the backends

The consumer sets `cds.log.levels.remote` to `info`, so its terminal shows every request sent to a producer. A filter
through two associations, for example, is three small key reads and no full read of the orders (URLs decoded and
shortened):

```text
GET /odata/v4/catalog/Orders?$filter=_Customer/_Group/Region eq 'AMER'&$select=ID,CustomerID

[remote] - GET http://localhost:9009/odata/v4/customer/CustomerGroups?$select=ID&$filter=Region eq 'AMER'&...
[remote] - GET http://localhost:9009/odata/v4/customer/Customers?$select=ID&$filter=(GroupID eq 'G300')&...
[remote] - GET http://localhost:7007/odata/v4/sales/Orders?$select=ID,Customer&$filter=(Customer eq 'C004' or Customer eq 'C005')&...
```

For the adapter's step-by-step trace, start the consumer with `npm run watch:trace` (`DEBUG=remote-service`,
`LOG_TO_FILE=true`) and follow one request by its correlation id in `consumer/logs/remote-service-latest.log`.

---

## 🚧 Not covered

| Feature | Why |
| --- | --- |
| Multi-tenancy, BTP destinations | The sample runs locally; the `[production]` profile shows the destination configuration. |

---

## 💬 Support & feedback

- Problems with the package: [`@cap-ts/remote-service-adapter` issues](https://github.com/cap-ts/remote-service-adapter/issues)
- Problems with the SOAP part: [`@cap-ts/soap-adapter` issues](https://github.com/cap-ts/soap-adapter/issues)
- Problems with the sample itself: [Samples issues](https://github.com/cap-ts/Samples/issues)
