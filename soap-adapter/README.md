# cap-ts Samples: @cap-ts/soap-adapter

A runnable landscape that shows what [`@cap-ts/soap-adapter`](https://www.npmjs.com/package/@cap-ts/soap-adapter)
does: legacy SOAP web services become read-only, OData-style entities of a [SAP CAP](https://cap.cloud.sap/docs/)
(Node.js) application, with `@Soap.*` annotations and one adapter class per service.

---

## 📑 Table of Contents

🗂️ [Repository layout](#️-repository-layout)\
🔗 [The landscape](#-the-landscape)\
▶️ [Running the sample locally](#️-running-the-sample-locally)\
🧪 [Trying it out](#-trying-it-out)\
🗺️ [Scenario index](#️-scenario-index)\
💬 [Support & feedback](#-support--feedback)

---

## 🗂️ Repository layout

```diagram
soap-adapter/
├── README.md               ← this file
├── producer-catalog/       ← ProductCatalog   SOAP, plain Node.js   (port 8091)
├── producer-finance/       ← ExchangeRates    SOAP, plain Node.js   (port 8092)
└── consumer/               ← CAP application with @cap-ts/soap-adapter (port 4004)
```

Each app has its own README: [producer-catalog](producer-catalog/README.md),
[producer-finance](producer-finance/README.md), [consumer](consumer/README.md).

---

## 🔗 The landscape

```diagram
           Client (test/http/*.http)
                     │
        ┌────────────┴─────────────┐
        ▼ /soap/<path>/<Entity>    ▼ /odata/v4/shop
┌───────────────────────── consumer (4004) ──────────────────────────┐
│ ProductCatalog        ExchangeRates          CountryCodes          │
│ (file convention)     (@Soap.adapter, .ts)   (impl, mock())        │
│        ▲                     ▲                     ▲               │
│        └──────── ShopService (in-process: srv.run, soap.read) ─────┤
│                       @cap-ts/soap-adapter                         │
└────────┬─────────────────────┬─────────────────────────────────────┘
         │ SOAP 1.1            │ SOAP 1.1 + WS-Security header
         ▼                     ▼
  producer-catalog (8091)   producer-finance (8092)
  FindProducts, GetStock    GetRates
```

| App | Kind | Operations | Port |
| --- | --- | --- | --- |
| `producer-catalog` | SOAP 1.1 (plain Node.js, `soap`) | `FindProducts` (server-side filter, sort, paging; `item` list; an element with an attribute; nested values), `GetStock` (one product per call) | 8091 |
| `producer-finance` | SOAP 1.1 (plain Node.js, `soap`) | `GetRates` (one `From` per call; a WS-Security header is required) | 8092 |
| `consumer` | CAP | three SOAP services (`/soap/catalog`, `/soap/rates`, `/soap/countrycodes`) and `ShopService` (`/odata/v4/shop`) | 4004 |

---

## ▶️ Running the sample locally

**Prerequisites:** Node.js 22.18 or later (it loads the TypeScript adapter class without a build step), the CAP
development kit for `cds watch` (`npm i -g @sap/cds-dk`), and for trying it out the VS Code
[REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) extension (or any HTTP client).

**1. Start the two SOAP producers**, each in its own terminal:

```bash
cd soap-adapter/producer-catalog && npm install && npm run watch
cd soap-adapter/producer-finance && npm install && npm run watch
```

**2. Start the consumer:**

```bash
cd soap-adapter/consumer && npm install && npm run watch
```

The `watch` script defines the two destinations (`SOAP_SAMPLES_CATALOG`, `SOAP_SAMPLES_FINANCE`) through the Cloud SDK's
`destinations` environment variable. On Windows set that variable as in the script and run `cds watch --port 4004`.

The boot log names the adapter class of each SOAP service and how it was found:

```text
[soap] - serving ProductCatalog { at: ['/soap/catalog'], impl: 'srv/external/ProductCatalog.js' }
[soap] - serving ExchangeRates { at: ['/soap/rates'], impl: 'srv/adapters/ExchangeRates.ts' }
[soap] - serving CountryCodes { at: ['/soap/countrycodes'], impl: 'srv/adapters/CountryCodes.js' }
```

---

## 🧪 Trying it out

[`consumer/test/http/`](consumer/test/http) has one request file per service; every request says what it shows. The
producer terminals log each SOAP call with its input and header.

| File | Covers |
| --- | --- |
| [`ProductCatalog.http`](consumer/test/http/ProductCatalog.http) | query options, push-down, paging with `@odata.nextLink`, read by key, fan-out, mandatory filters, errors, the CAP-served endpoint |
| [`ExchangeRates.http`](consumer/test/http/ExchangeRates.http) | `@requires` (401 / 403), WS-Security header, TypeScript adapter, fan-out with `$orderby` / `$top` / `$count` |
| [`CountryCodes.http`](consumer/test/http/CountryCodes.http) | `mock()` |
| [`ShopService.http`](consumer/test/http/ShopService.http) | the SOAP services in-process: `srv.run`, `soap.read`, the utility API |

Users (password = user name): `alice` (role `finance`), `bob` (no role).

---

## 🗺️ Scenario index

Model and code files are under `consumer/srv/`, requests under `consumer/test/http/`.

### Model (`@Soap.*`)

| Feature | Where | Request |
| --- | --- | --- |
| `using from '@cap-ts/soap-adapter'`: the annotations are checked by `cds compile` | every `external/*.cds` | |
| `@Soap` on the service, `@path` for the route | `external/ProductCatalog.cds` | `ProductCatalog.http` |
| `@Soap.operation` | every SOAP entity | all |
| `@Soap.binding: { rootRequest, rootResponse }` | `ProductCatalog.Products` | `ProductCatalog.http` |
| `@Soap.rootResponse` (and its precedence over the binding) | `ProductCatalog.Stock`, `ExchangeRates.Rates` | both |
| `@Soap.path`: nested values, another element name | `ProductCatalog.Products`, `ExchangeRates.Rates` | both |
| `item` lists and `$value` of an element with attributes | `ProductCatalog.Products` | `ProductCatalog.http` |
| A parsed `xsd:date` as a `Date` element | `ExchangeRates.Rates.ValidOn` | `ExchangeRates.http` |
| `@Soap.filterRestriction`: `mandatoryFields`, `multipleSelection: false` (fan-out) | `ProductCatalog.Stock`, `ExchangeRates.Rates` | both |
| `@Soap.adapter` on the service | `external/ExchangeRates.cds` | `ExchangeRates.http` |
| `@requires` on a SOAP service (401 / 403 on the routes) | `external/ExchangeRates.cds` | `ExchangeRates.http` |

### Adapter class (`soap.Service`)

| Feature | Where | Request |
| --- | --- | --- |
| Found by the file convention (`<Service>.js` next to the `.cds`) | `external/ProductCatalog.js` | `ProductCatalog.http` |
| Named by `@Soap.adapter`, written in TypeScript | `adapters/ExchangeRates.ts` | `ExchangeRates.http` |
| Named by `cds.requires.<Service>.impl` | `adapters/CountryCodes.js` | `CountryCodes.http` |
| `strict: true` (a missing class stops the start) | `package.json`, `ExchangeRates` | |
| `header()`: a plain map | `external/ProductCatalog.js` | `ProductCatalog.http` |
| `header()`: a structured WS-Security header, reading `this.options` | `adapters/ExchangeRates.ts` | `ExchangeRates.http` |
| `request()`: the operation's input from the query | both adapter classes | both |
| `__filterPushedDown` (and when not to set it: `$count`, no `$top`, an inexact term) | `external/ProductCatalog.js` | `ProductCatalog.http` |
| `response()`: transform the raw entries | `external/ProductCatalog.js` | `ProductCatalog.http` |
| `mock()` | `adapters/CountryCodes.js` | `CountryCodes.http` |
| CAP handlers on a SOAP service (`after('READ')`) | `external/ProductCatalog.js` | `ProductCatalog.http` |

### Routes and query options

| Feature | Request |
| --- | --- |
| `$select`, `$filter` (functions, `in`, `and` / `or`), `$orderby`, `$top`, `$skip`, `$count` | `ProductCatalog.http` |
| Paging of `cds.query.soap.pageSize` with `@odata.nextLink`, `$skiptoken` | `ProductCatalog.http` |
| Read by key, 404 | `ProductCatalog.http`, `CountryCodes.http` |
| 400: `$expand`, a malformed `$filter`, a function on the left of a comparison, a missing mandatory filter, `in` beside `or` | `ProductCatalog.http`, `ExchangeRates.http` |
| Fan-out, one SOAP call per key value, `$orderby` / `$top` / `$count` on the merged rows | `ProductCatalog.http`, `ExchangeRates.http` |
| The CAP-served OData endpoint of a SOAP service; writes 405 | `ProductCatalog.http`, `ExchangeRates.http` |

### In-process and utilities

| Feature | Where | Request |
| --- | --- | --- |
| `srv.run(SELECT ...)` on a SOAP service | `shop-service.js` | `ShopService.http` |
| `soap.read(...)` | `shop-service.js` | `ShopService.http` |
| `soap.isSoapService`, `soap.getEntityKeyFields`, `soap.dedupByKeys`, `soap.Service.FORBIDDEN_SOAP_HEADERS`, `soap.Service.stripSensitiveHeaders` | `shop-service.js` (`soapInfo`) | `ShopService.http` |

### Configuration and security

| Feature | Where |
| --- | --- |
| `kind: "soap"`, `wsdl`, `credentials.destination`, `credentials.path` | `consumer/package.json` |
| `cds.query.soap`: `pageSize`, `multiSelectionConcurrency`, `pushFilters` | `consumer/package.json` |
| Local destinations through the `destinations` environment variable | `consumer/package.json` (`watch`) |
| helmet, CORS and a rate limit for `/soap` on `bootstrap` | `consumer/srv/server.js` |
| `DEBUG=soap` | `consumer/package.json` (`watch:debug`) |

---

## 💬 Support & feedback

- Problems with the package: [`@cap-ts/soap-adapter` issues](https://github.com/cap-ts/soap-adapter/issues)
- Problems with the sample itself: [Samples issues](https://github.com/cap-ts/Samples/issues)
