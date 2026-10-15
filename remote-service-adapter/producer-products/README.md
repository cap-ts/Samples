# producer-products: ProductService (OData V2, port 8008)

Products and categories, served as **OData V2** through
[`@cap-js-community/odata-v2-adapter`](https://www.npmjs.com/package/@cap-js-community/odata-v2-adapter) at
`/odata/v2/product` (and as OData V4 at `/odata/v4/product`). The consumer reads the V2 endpoint, as it would read an
SAP Gateway service. Mocked authentication.

| Entity set | Key | Notes |
| --- | --- | --- |
| `Products` | `ID` | `category_ID` points to `Categories`; `ReleasedAt` is a date-time (`Edm.DateTimeOffset`); `InternalNote` is `sap:filterable="false"` |
| `Categories` | `ID` | |

What the V2 endpoint shows the consumer: `sap:filterable="false"` in `$metadata` (from `@sap.filterable: false`),
`$inlinecount` and counts as text, `/Date(...)/` values, and a case-sensitive `$search` rule (`kind: "odata-v2"`).

```bash
npm install
npm run watch        # http://localhost:8008/odata/v2/product/$metadata
```
