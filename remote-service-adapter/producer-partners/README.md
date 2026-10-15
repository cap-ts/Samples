# producer-partners: PartnerDirectory (SOAP, port 6006)

A plain Node.js SOAP 1.1 web service (no CAP), built with [`soap`](https://www.npmjs.com/package/soap). It stands in
for a legacy SOAP backend.

| Item | Value |
| --- | --- |
| Endpoint | `http://localhost:6006/soap/partners` |
| WSDL | [`wsdl/PartnerDirectory.wsdl`](wsdl/PartnerDirectory.wsdl) (also `?wsdl` on the endpoint) |
| Operation | `GetPartners`: input any number of `PartnerID` and an optional `Country`; output the matching `Partner` entries, each with a nested `Contact` (`Email`, `Phone`). No input: every partner. |
| Data | [`data/partners.json`](data/partners.json) |

It accepts any credentials. The consumer reaches it through the destination `RSA_SAMPLES_PARTNERS` (basic
authentication), defined in the consumer's `watch` script.

```bash
npm install
npm run watch        # restarts on changes (node --watch)
```

Every call is logged: `[soap] GetPartners {"Country":"DE"} -> 2 partner(s)`.
