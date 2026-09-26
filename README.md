# cap-ts Samples

Welcome to the cap-ts Samples Git Repository.

It contains sample implementations and helpful resources demonstrating the features and capabilities of the npm
packages published by [cap-ts](https://github.com/cap-ts). Every sample is a small, runnable
[SAP CAP](https://cap.cloud.sap/docs/) (Node.js) project.

---

## 📑 Table of Contents

📦 [Published packages](#-published-packages)\
🗂️ [Repository layout](#️-repository-layout)\
🔗 [ESI sample: mashing up four remote services](#-esi-sample-mashing-up-four-remote-services)\
▶️ [Running the ESI sample locally](#️-running-the-esi-sample-locally)\
🧪 [Trying it out](#-trying-it-out)\
💬 [Support & feedback](#-support--feedback)

---

## 📦 Published packages

| Package | Version | What it does | Samples |
| --- | --- | --- | --- |
| [`@cap-ts/esi`](https://www.npmjs.com/package/@cap-ts/esi) | [![npm](https://img.shields.io/npm/v/@cap-ts/esi.svg)](https://www.npmjs.com/package/@cap-ts/esi) | **Enterprise System Integration** for CAP: reads remote services and mashes them up into local entities, including associations across services, configured in `package.json`. [Source](https://github.com/cap-ts/esi) | [`esi/`](esi) |
| [`@cap-ts/soap-adapter`](https://www.npmjs.com/package/@cap-ts/soap-adapter) | [![npm](https://img.shields.io/npm/v/@cap-ts/soap-adapter.svg)](https://www.npmjs.com/package/@cap-ts/soap-adapter) | CAP plugin that exposes **legacy SOAP web services** as read-only OData v4 entities: annotate an entity with `@Soap.*`, ship an adapter class, and the plugin handles routing, destinations, JWT propagation and XML mapping. [Source](https://github.com/cap-ts/soap-adapter) | none yet — see the package README |
| [`@cap-ts/remote-service-adapter`](https://www.npmjs.com/package/@cap-ts/remote-service-adapter) | [![npm](https://img.shields.io/npm/v/@cap-ts/remote-service-adapter.svg)](https://www.npmjs.com/package/@cap-ts/remote-service-adapter) | Generic `RemoteApplicationService` that turns CDS projections on remote OData / SOAP services into working READ endpoints — `$filter` push-down, alias mapping, `$expand` across services, `$search`, aggregation — with no handler code. Opt in with `@remote`. [Source](https://github.com/cap-ts/remote-service-adapter) | none yet — see the package README |

> **Obsolete package.** [`esi-cap`](https://www.npmjs.com/package/esi-cap) is the predecessor of `@cap-ts/esi` and is
> marked *obsolete* on npm. Use `@cap-ts/esi` for new projects.

---

## 🗂️ Repository layout

```diagram
samples/
├── README.md               ← this file
└── esi/                    ← samples for @cap-ts/esi
    ├── producer1/          ← CustomerService     (port 9009)
    ├── producer2/          ← ProductService      (port 8008)
    ├── producer3/          ← EmployeeService     (port 7007)
    ├── producer4/          ← TransactionService  (port 6006)
    └── consumer/           ← ConsumerService     (port 5005), reads all four through ESI
```

Samples for the other packages will get their own top-level folder next to `esi/`.

---

## 🔗 ESI sample: mashing up four remote services

Four independent CAP apps (**producers**) each own one business object and serve it over OData v4 from an in-memory
SQLite database seeded with CSV data. A fifth app (**consumer**) owns no data at all: it reads everything from the
producers through ESI and combines it into one entity.

| App | Service | Entity set | Fields | Port |
| --- | --- | --- | --- | --- |
| `producer1` | `CustomerService` | `CustomerSet` | `firstName`, `lastName`, `email`, `phoneNumber`, `address` | 9009 |
| `producer2` | `ProductService` | `ProductSet` | `name`, `description`, `price`, `currency`, `category`, `available`, `stock` | 8008 |
| `producer3` | `EmployeeService` | `EmployeeSet` | `firstName`, `lastName`, `email`, `department`, `title`, `hireDate`, `active` | 7007 |
| `producer4` | `TransactionService` | `TransactionSet` | `date`, `quantity`, `totalAmount`, `customer`, `employee`, `product`, `note` | 6006 |
| `consumer` | `ConsumerService` | `MeshedUpTransactionSet` | all transaction fields plus `_Customer`, `_Product`, `_Employee` associations | 5005 |

Every producer rejects `UPDATE` and `DELETE` with `403` and uses mocked authentication.

**How the consumer is wired:**

1. `consumer/srv/external/*.csn|edmx` holds the imported models of the four producer services, and
   `cds.requires` in `consumer/package.json` points each one at its producer URL.
2. `consumer/srv/consumer-service.cds` defines `MeshedUpTransactionSet` as a projection on `TransactionSet` with
   associations to the customer, product and employee of each transaction — entities that live in three other apps.
3. `consumer/srv/consumer-service.js` hands the service to ESI with one call:

   ```js
   const { esi } = require('esi-cap');
   module.exports = cds.service.impl(async function () {
       return await esi.impl.RemoteService(this);
   });
   ```

4. The `esi.requires` block in `consumer/package.json` tells ESI which remote system serves which entity
   (`RemoteService`) and how the local associations resolve across services (`LocalService` → `navigations`), including
   the fields `$search` looks at.

> **Package used by this sample.** The consumer still depends on the obsolete `esi-cap` package
> (`"esi-cap": "*"` and `require('esi-cap')`). `@cap-ts/esi` exposes the same `esi.impl.RemoteService(this)` entry
> point, but this sample has not been migrated to it and tested yet.

---

## ▶️ Running the ESI sample locally

**Prerequisites:** Node.js ≥ 20 and the CAP development kit (`npm i -g @sap/cds-dk`) for `cds watch`.

**1. Install and start the four producers**, each in its own terminal:

```bash
cd esi/producer1 && npm install && npm run watch
cd esi/producer2 && npm install && npm run watch
cd esi/producer3 && npm install && npm run watch
cd esi/producer4 && npm install && npm run watch
```

The `watch` scripts set the port with `PORT=<port> cds watch`, which works in macOS / Linux shells. On Windows run
`cds watch --port <port>` instead.

**2. Point the consumer at your local producers.** The `credentials.url` values in `esi/consumer/package.json` point
to an SAP Business Application Studio workspace. For a local run, replace them with:

| Service | Local URL |
| --- | --- |
| `CustomerService` | `http://localhost:9009/odata/v4/customer` |
| `ProductService` | `http://localhost:8008/odata/v4/product` |
| `EmployeeService` | `http://localhost:7007/odata/v4/employee` |
| `TransactionService` | `http://localhost:6006/odata/v4/transaction` |

**3. Install and start the consumer:**

```bash
cd esi/consumer && npm install && npm run watch
```

The mashed-up entity is then served at `http://localhost:5005/odata/v4/consumer/MeshedUpTransactionSet`.

---

## 🧪 Trying it out

[`esi/consumer/test/http/ConsumerService.http`](esi/consumer/test/http/ConsumerService.http) contains ready-made
requests (user `alice`, empty password) for the VS Code REST Client:

| Request | Shows |
| --- | --- |
| `GET …/MeshedUpTransactionSet` | Transactions read from `producer4` through the consumer |
| `…?$search=<id>&$expand=_Customer,_Employee,_Product` | `$search` plus associations resolved from three other services |
| `…?$count=true&$expand=_Customer($select=…),_Employee($select=…),_Product($select=…)` | `$select` inside `$expand` across services |
| `…?$filter=_Product/category eq 'Electronics' and contains(_Customer/address, 'Berlin') and _Employee/active eq true` | Filtering on fields of associated entities that live in other apps |

---

## 💬 Support & feedback

Found a problem or have an idea? Open an issue in the repository of the package concerned:

- [`@cap-ts/esi` issues](https://github.com/cap-ts/esi/issues)
- [`@cap-ts/soap-adapter` issues](https://github.com/cap-ts/soap-adapter/issues)
- [`@cap-ts/remote-service-adapter` issues](https://github.com/cap-ts/remote-service-adapter/issues)

Issues with the samples themselves go to [Samples](https://github.com/cap-ts/Samples/issues).
