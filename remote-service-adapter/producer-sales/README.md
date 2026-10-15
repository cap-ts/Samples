# producer-sales: SalesService (OData V4, writable, port 7007)

Transactional data of the sample. Unlike the other producers it accepts writes, so the consumer's
`OrderManagementService` can create, update and delete through its projections. Mocked authentication.

| Entity set | Key | Notes |
| --- | --- | --- |
| `Orders` | `ID` | `Customer` holds a customer ID of producer-customers (no association: another system); `Kind` STD / RET; `Status` O / X / C; `Channel` is set by the consumer's handler only |
| `Items` | `ID` | `OrderID`; `Product` holds a product ID of producer-products |
| `Projects`, `Packages` | `ProjectID` / `ProjectID, PackageID` | Target of the consumer's deep writes |
| `Bookings` | `ID` | `CustomerText` is `String(20)` (the consumer cuts its computed text to it) |
| `Entries` | `CompanyCode, DocNo` | A **non-CRUD API**: every change is a `POST` that names the operation in `Op` (C, U, D); `PATCH` / `DELETE` answer 405 |

Operations: bound actions `Orders/cancel()`, `Orders/release()`, bound function `Orders/printForm()`, unbound action
`upsertStatus(ID, Status)`.

Restart the app to reset its data.

```bash
npm install
npm run watch        # http://localhost:7007/odata/v4/sales
```
