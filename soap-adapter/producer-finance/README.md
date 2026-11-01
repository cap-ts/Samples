# producer-finance: ExchangeRates (SOAP, port 8092)

A plain Node.js SOAP 1.1 web service (no CAP), built with [`soap`](https://www.npmjs.com/package/soap).

| Item | Value |
| --- | --- |
| Endpoint | `http://localhost:8092/soap/rates` |
| WSDL | [`wsdl/ExchangeRates.wsdl`](wsdl/ExchangeRates.wsdl) (also `?wsdl` on the endpoint) |
| `GetRates` | Input: exactly one `From` currency (a SOAP fault without) and any number of `To` currencies (all without). Output: `Rates/Rate[]` (`From`, `To`, `Rate`, `ValidOn` as `xsd:date`, `PublishedAt` as `xsd:dateTime`, `RateID` a GUID). |
| SOAP header | Required: a WS-Security `UsernameToken` with a `Username` (a SOAP fault without). The password is not checked. |
| Data | [`data/rates.json`](data/rates.json) |

```bash
npm install
npm run watch        # restarts on changes (node --watch)
```

Every call is logged with its input and the user of the header: `[soap] GetRates {"From":"EUR"} for sample-shop -> 3 rate(s)`.
