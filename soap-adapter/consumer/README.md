# consumer: three SOAP web services in a CAP application (port 4004)

Exposes the SOAP web services of the two producers (and one that is only mocked) as OData-style entities with
[`@cap-ts/soap-adapter`](https://www.npmjs.com/package/@cap-ts/soap-adapter), and uses them in-process from an
ordinary CAP service. The overview of the sample, how to run it and the scenario index are in [../README.md](../README.md).

## Layout

```diagram
consumer/
├── package.json                      ← cds.requires (kind soap, wsdl, destination, strict, impl), cds.query.soap, users
├── srv/
│   ├── server.js                     ← helmet, CORS and a rate limit for /soap, on bootstrap
│   ├── external/
│   │   ├── ProductCatalog.cds        ← @Soap.* model of producer-catalog (@path 'catalog')
│   │   ├── ProductCatalog.js         ← its adapter class: found by the file convention (<Service>.js next to the .cds)
│   │   ├── ExchangeRates.cds         ← @Soap.* model of producer-finance (@path 'rates', @requires, @Soap.adapter)
│   │   ├── CountryCodes.cds          ← a SOAP service that is only mocked
│   │   └── wsdl/*.wsdl               ← the local WSDL files (cds.requires.<Service>.wsdl)
│   ├── adapters/
│   │   ├── ExchangeRates.ts          ← adapter class in TypeScript, named by @Soap.adapter
│   │   └── CountryCodes.js           ← adapter class named by cds.requires.CountryCodes.impl, answers from mock()
│   ├── shop-service.cds              ← ShopService: a CAP service on top of the SOAP services
│   └── shop-service.js               ← srv.run / soap.read / the utility API
└── test/http/*.http                  ← one request file per service (VS Code REST Client)
```

## Configuration (`package.json`)

| Key | Purpose |
| --- | --- |
| `cds.requires.ProductCatalog` | `kind: "soap"`, the local `wsdl`, `credentials.destination` + `credentials.path` (appended to the destination URL) |
| `cds.requires.ExchangeRates` | the same, plus `strict: true` (a missing adapter class stops the start) and `wsseUser`, a setting of its own that the adapter class reads from `this.options` |
| `cds.requires.CountryCodes` | `impl`: the module of its adapter class |
| `cds.requires.auth` | Mocked users: `alice` (role `finance`), `bob` (no role); password = user name |
| `cds.query.soap` | `pageSize: 4` (small, to show `@odata.nextLink`), `multiSelectionConcurrency: 2` (fan-out batches), `pushFilters: true` |

The destinations `SOAP_SAMPLES_CATALOG` and `SOAP_SAMPLES_FINANCE` are defined in the `watch` scripts through the Cloud
SDK's `destinations` environment variable. On SAP BTP they are destinations of the destination service; the caller's
JWT selects the tenant's destination.

`npm run watch:debug` also sets `DEBUG=soap`.

## The SOAP services

### ProductCatalog (`/soap/catalog`): the file convention, hooks, push-down

[`srv/external/ProductCatalog.cds`](srv/external/ProductCatalog.cds),
[`srv/external/ProductCatalog.js`](srv/external/ProductCatalog.js),
[`test/http/ProductCatalog.http`](test/http/ProductCatalog.http).

| Entity | Annotations | Shows |
| --- | --- | --- |
| `Products` | `@Soap.operation: 'FindProducts'`, `@Soap.binding: { rootRequest, rootResponse: 'Products' }`, `@Soap.path: 'Supplier.Name'` | the `item` list unwrapped, `$value` of an element with an attribute (`Price`), nested values |
| `Stock` | `@Soap.operation: 'GetStock'`, `@Soap.rootResponse: 'Stock'`, `@Soap.filterRestriction: { mandatoryFields: ['ProductID'], multipleSelection: false }` | the fan-out of `ProductID in (...)`, the mandatory filter, the 400 for `in` beside `or` |

The adapter class registers:

- `header(Products, ...)`: a plain map (`Channel`, `TraceID`): one SOAP header element per key. The backend echoes
  `Channel` into every product.
- `request(Products, ...)`: the request's `$filter`, `$orderby`, `$top`, `$skip` as the operation's input. When all of
  it can be expressed and the request names a page (`$top`), it sets `__filterPushedDown`: the backend's answer is the
  page. Otherwise (a `contains`, `$count`, no `$top`) the input only narrows the answer and the runtime filters, sorts
  and pages in memory (page of `cds.query.soap.pageSize`, `@odata.nextLink`).
- `response(Products, ...)`: the raw entries before the `@Soap.path` mapping (`'X'` becomes `true`).
- `request(Stock, ...)`: one `ProductID` per call.
- `after('READ', Stock, ...)`: an ordinary CAP handler (`Available`).

### ExchangeRates (`/soap/rates`): TypeScript, `@Soap.adapter`, WS-Security, `@requires`

[`srv/external/ExchangeRates.cds`](srv/external/ExchangeRates.cds),
[`srv/adapters/ExchangeRates.ts`](srv/adapters/ExchangeRates.ts),
[`test/http/ExchangeRates.http`](test/http/ExchangeRates.http).

- `@Soap.adapter: 'srv/adapters/ExchangeRates'` names the TypeScript class (no extension: `.ts` is taken first). Node.js
  22.18 and later load it without a build step.
- `header(Rates, ...)` returns a structured header `{ value, name, prefix, xmlns }`: a WS-Security `UsernameToken`.
- `@Soap.rootResponse: 'Rates.Rate'` takes precedence over `@Soap.binding.rootResponse`.
- `From` / `To` are reserved words in CDS: the elements are `FromCurrency` / `ToCurrency` with `@Soap.path: 'From'`.
- `@requires: 'finance'`: the routes answer 401 without a user, 403 without the role.
- `ValidOn` is an `xsd:date` in the response and a `Date` element: answered as `2026-10-14`.

### CountryCodes (`/soap/countrycodes`): `impl` and `mock()`

[`srv/adapters/CountryCodes.js`](srv/adapters/CountryCodes.js),
[`test/http/CountryCodes.http`](test/http/CountryCodes.http). The class named by `cds.requires.CountryCodes.impl`
registers a `mock()`: no destination, no WSDL loading, no HTTP. A mock's answer is final, so it filters itself.

### The same services as CAP serves them

Every SOAP service of the model is also an OData V4 service of the application (`/odata/v4/catalog`,
`/odata/v4/rates`, `/odata/v4/country-codes`). Reads there run the same pipeline; writes answer 405.

## ShopService (`/odata/v4/shop`): the SOAP services in-process

[`srv/shop-service.js`](srv/shop-service.js), [`test/http/ShopService.http`](test/http/ShopService.http).

| Operation | Uses |
| --- | --- |
| `Offers` | `catalog.run(SELECT ...)` on ProductCatalog (the same pipeline as its routes), `soap.read(...)` per product on `Stock` (one product per call: the fan-out is a feature of the routes), `soap.read` on ExchangeRates, the CountryCodes mock |
| `convert(...)` | `soap.read` on ExchangeRates; 404 from the handler without a rate |
| `soapInfo()` | `soap.isSoapService`, `soap.getEntityKeyFields`, `soap.Service.FORBIDDEN_SOAP_HEADERS`, `soap.Service.stripSensitiveHeaders`, `soap.dedupByKeys` |

## Security middleware

[`srv/server.js`](srv/server.js) adds `helmet()`, CORS (`CORS_ALLOWED_ORIGINS`, none by default) and a rate limit on
`/soap` in CAP's `bootstrap` event. The `/soap` routes are mounted on `served`, after it, so the middleware wraps
them.
