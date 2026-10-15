# producer-catalog: ProductCatalog (SOAP, port 8091)

A plain Node.js SOAP 1.1 web service (no CAP), built with [`soap`](https://www.npmjs.com/package/soap).

| Item | Value |
| --- | --- |
| Endpoint | `http://localhost:8091/soap/catalog` |
| WSDL | [`wsdl/ProductCatalog.wsdl`](wsdl/ProductCatalog.wsdl) (also `?wsdl` on the endpoint) |
| `FindProducts` | Input: any number of `ProductID`, `Category`, `NameContains` (case-insensitive), `SortBy` + `Descending`, `Skip`, `MaxHits`. Output: `TotalHits` and `Products/item[]`; each product has `<Price currency="EUR">29.99</Price>` (an element with an attribute) and a nested `Supplier` (`Name`, `Country`). |
| `GetStock` | Input: exactly one `ProductID` (a SOAP fault without, or with several). Output: `Stock` (`Warehouse`, `Quantity`, `Reserved`). |
| SOAP header | `Channel`, when sent, is echoed into every product. |
| Data | [`data/products.json`](data/products.json), [`data/stock.json`](data/stock.json) |

The server filters, sorts and pages `FindProducts` itself, so a client can push its whole query into the request.
It accepts any credentials.

```bash
npm install
npm run watch        # restarts on changes (node --watch)
```

Every call is logged with its input and the SOAP header: `[soap] FindProducts {"Category":"Furniture",...,"Channel":"SHOP-API"} -> 2 row(s)`.
