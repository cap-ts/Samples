# producer-customers: CustomerService (OData V4, port 9009)

Master data of the remote-service-adapter sample: customers, customer groups and contacts, served by CAP from an
in-memory SQLite database seeded with CSV data. Mocked authentication (any user, any password).

| Entity set | Key | Notes |
| --- | --- | --- |
| `Customers` | `ID` | `Address` is a structured type (`Street`, `City`, `PostalCode`, `Country`); `Status` A = active, B = blocked; `GroupID` points to `CustomerGroups` |
| `CustomerGroups` | `ID` | `Region`: EMEA, AMER, APJ |
| `Contacts` | `ID` | `CustomerID` points to `Customers` |

Operations: bound action `Customers/block()`, bound function `Customers/creditCheck(Amount)`, unbound action
`setStatus(ID, Status)`.

`.cdsrc.json` sets `odata.structs: true`, so `$metadata` declares `Address` as a complex type, and
`srv/customer-service.js` answers it nested (`"Address": { "City": ... }`), the way S/4 answers complex types. The
consumer reads it with `Address.City as City`.

```bash
npm install
npm run watch        # http://localhost:9009/odata/v4/customer
```
