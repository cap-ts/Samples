# consumer for AI agents: the same services over MCP

The consumer integrates four backends (OData V4, OData V2, SOAP) and its own database into one CDS model, with
[`@cap-ts/remote-service-adapter`](https://www.npmjs.com/package/@cap-ts/remote-service-adapter). The same model is served to AI
agents through the [Model Context Protocol](https://modelcontextprotocol.io) by SAP's CAP plugin
[`@cap-js/mcp`](https://cap.cloud.sap/docs/guides/protocols/mcp): no tool code, no second integration.

```diagram
AI agent (any MCP client)                          Fiori / any OData client
          │ MCP: describe · query · call                  │ OData V4
          ▼                                               ▼
   /mcp/catalog, /mcp/restricted           /odata/v4/catalog, /odata/v4/restricted
          └────────────── same CAP services ──────────────┘
              RemoteApplicationService (@cap-ts/remote-service-adapter)
                  push-down, mapping, key reads, joins, @restrict
          │ OData V4          │ OData V2           │ OData V4          │ SOAP
          ▼                   ▼                    ▼                   ▼
   producer-customers   producer-products    producer-sales     producer-partners
```

---

## 📑 Table of Contents

🧩 [What is added](#-what-is-added)\
▶️ [Running it](#️-running-it)\
🤖 [Connecting an agent](#-connecting-an-agent)\
🔗 [Downstream: one question, three systems](#-downstream-one-question-three-systems)\
🔒 [Upstream: the agent is the user](#-upstream-the-agent-is-the-user)\
✏️ [Changes through actions](#️-changes-through-actions)\
🧭 [Guardrails for agents](#-guardrails-for-agents)\
🚧 [Limits](#-limits)

---

## 🧩 What is added

| File | Purpose |
| --- | --- |
| [srv/mcp.cds](srv/mcp.cds) | `@odata @mcp` on CatalogService and RestrictedService, with `@mcp.instructions`: what only this application knows (the systems, the codes, when an action may be called) |
| [package.json](package.json) | the dependency `@cap-js/mcp`; `cds.mcp.prefix` (tool names `CatalogService-query`, ...), `cds.mcp.autowire` (the mocked user of the automatic registration) |
| [test/http/MCP.http](test/http/MCP.http) | the requests of this page as raw MCP calls, for any HTTP client that runs `.http` files |

`@mcp` is a protocol annotation like `@odata`; a service that names protocols is served by those only, so both are
named and every OData endpoint and `test/http` request stays as it is. Each MCP endpoint serves three tools:

| Tool | What it does | Hint to the client |
| --- | --- | --- |
| `<Service>-describe` | entities, elements, keys, associations, query limits; the doc comments of the `.cds` files become descriptions | read only |
| `<Service>-query` | one CQL `SELECT` (paths through associations, nested expands, aggregates), run as a query of the service | read only |
| `<Service>-call` | an unbound action or function of the service | destructive: the client asks the user |

---

## ▶️ Running it

Start the four producers and the consumer as described in [../README.md](../README.md). The consumer's boot log lists
both endpoints of each service:

```text
[cds] - serving CatalogService {
  at: [ '/odata/v4/catalog', '/mcp/catalog' ],
[cds] - serving RestrictedService {
  at: [ '/odata/v4/restricted', '/mcp/restricted' ],
```

---

## 🤖 Connecting an agent

Any AI agent or MCP client that supports remote MCP servers over Streamable HTTP can use the endpoints. Register each
endpoint in the agent's MCP configuration with these settings:

| Setting | Value |
| --- | --- |
| Transport | Streamable HTTP (often named `http`); the endpoints are stateless, every request is one POST |
| URL | `http://localhost:5005/mcp/catalog` or `http://localhost:5005/mcp/restricted` |
| Header | `Authorization: Basic <user:password in Base64>`: `YWxpY2U6YWxpY2U=` is `alice:alice`, `Ym9iOmJvYg==` is `bob:bob`, `a2ltOmtpbQ==` is `kim:kim` |

The file and the key names depend on the agent; a typical entry:

```json
{
  "catalog": {
    "type": "http",
    "url": "http://localhost:5005/mcp/catalog",
    "headers": { "Authorization": "Basic YWxpY2U6YWxpY2U=" }
  }
}
```

Register the same endpoint once per user to compare what each user gets (e.g. `restricted-bob`, `restricted-kim`).
Then ask the agent in plain language; it calls `describe` first and writes the CQL itself.

**Automatic registration.** Under `cds watch` (profile `development`) `@cap-js/mcp` also registers the endpoints with
the local agents it supports (see its [documentation](https://cap.cloud.sap/docs/guides/protocols/mcp)) when the
server starts, and removes them when it stops: entries `cds:CatalogService` and `cds:RestrictedService` in the agents'
configuration files in the user's home directory, with a basic-authentication header of `cds.mcp.autowire` (here the
mocked user `alice`). A server that is killed (not stopped) leaves its entries behind; the next start overwrites them.
Set `"autowire": false` under `cds.mcp` to turn it off.

---

## 🔗 Downstream: one question, three systems

> Which open orders above 100 have the highest amounts, for which customers and regions, and with which products?

The agent sends one `query`:

```sql
SELECT from Orders { ID, Title, Status, CustomerName, CustomerRegion, _Items { ProductName, Quantity } }
 where Status = 'O' and Amount > 100 order by Amount desc limit 3
```

and the consumer log shows what reached the backends: the filter, order and limit are pushed to the sales system,
everything else is read by key.

```text
[mcp] - CatalogService query
[remote] - GET http://localhost:7007/odata/v4/sales/Orders?$select=ID,OrderName,Status,Customer&$filter=Status eq 'O' and Amount gt 100&$top=3&$count=true&$orderby=Amount desc,ID asc
[remote] - GET http://localhost:9009/odata/v4/customer/Customers?$select=Name,GroupID,ID&$filter=(ID eq 'C004' or ID eq 'C007' or ID eq 'C001')
[remote] - GET http://localhost:9009/odata/v4/customer/CustomerGroups?$select=Region,ID&$filter=(ID eq 'G300' or ID eq 'G200' or ID eq 'G100')
[remote] - GET http://localhost:7007/odata/v4/sales/Items?$select=Quantity,OrderID,Product,ID&$filter=(OrderID eq 'O006' or OrderID eq 'O009' or OrderID eq 'O001')&...
[remote] - GET http://localhost:8008/odata/v2/product/Products?$select=Name,ID&$filter=(ID eq 'P004' or ID eq 'P001' or ...)
```

The answer names local fields only (`Title`, `CustomerName`, `CustomerRegion`, `ProductName`): the agent never sees
the backends' names, URLs or credentials. The join view `PartnerCustomers` does the same for the SOAP partner
directory and the customer system (one SOAP call, one read by key).

Totals are computed by the service, not by the agent: a `group by` with `count`, `sum`, `avg`, `min` or `max` reads
the rows the filter leaves once (at most 5000) and groups them here; a group column from another system is read by key,
like any path column.

```sql
SELECT from Orders { CustomerRegion, count(*) as Orders, sum(Amount) as Total }
 where Status != 'C' group by CustomerRegion order by Total desc
```

```text
[remote] - GET http://localhost:7007/odata/v4/sales/Orders?$select=Amount,Customer&$filter=Status ne 'C'&$top=5001
[remote] - GET http://localhost:9009/odata/v4/customer/Customers?$select=GroupID,ID&$filter=(ID eq 'C001' or ID eq 'C002' or ...)
[remote] - GET http://localhost:9009/odata/v4/customer/CustomerGroups?$select=Region,ID&$filter=(ID eq 'G100' or ID eq 'G300' or ...)
```

---

## 🔒 Upstream: the agent is the user

The agent calls with the identity of its connection, and CAP checks `@requires` / `@restrict` as for any OData
request. The same `query` on RestrictedService:

| User | Rows | Sent to producer-customers |
| --- | --- | --- |
| `alice` (admin) | 8 | `$select=ID,Name,CompanyCode&$top=1000&$orderby=ID` |
| `bob` (CompanyCode 1000) | 4 | `... &$filter=(CompanyCode eq '1000')` |
| `kim` (CompanyCode 2000) | 2 | `... &$filter=(CompanyCode eq '2000')` |
| `sam` (no CompanyCode) | 0 | nothing: no backend call |
| wrong password | HTTP 401 | nothing |

Entities and actions a user may not read or call are left out of that user's `describe` and tools.

---

## ✏️ Changes through actions

The MCP tools read and call unbound actions; they do not create, update or delete rows. CatalogService has one unbound
action, `setCustomerStatus`, forwarded to `CustomerService.setStatus` of producer-customers. The `call` tool is
marked destructive, so the agent asks before it runs, and `@mcp.instructions` tells it to wait for the user's
confirmation:

```json
{ "action": "setCustomerStatus", "parameters": { "ID": "C006", "Status": "B" } }
```

A following `query` of `Customers` shows `Status: B`, `IsBlocked: true`. [test/http/MCP.http](test/http/MCP.http)
sets it back.

---

## 🧭 Guardrails for agents

The consumer turns on the opt-in settings of `cds.query.remote` meant for agents (in `package.json`, shared with the
OData clients):

| Setting | What the agent and the operator get |
| --- | --- |
| `agentHints: true` | `describe` shows `Adapter hints: ...` in the docs. Of the service: select only the columns needed, keep a limit, totals with `group by` (at most 5000 rows read), which entity comes from which system, the request budget. Of entities and elements: a filter on the whole key is one read by key, the row cap of aggregates, the fields filtered in memory (`Products`), the associations to another system (`Orders.CustomerName` comes from CustomerService). The `@mcp.instructions` only add what the model can not tell. |
| `budget: { requests: 200, rows: 100000, seconds: 60 }` | One budget per tool call over every service layer: a query that would need more is answered `Request budget exceeded: ... cds.query.remote.budget.requests (200)`, before the next backend request. |
| `audit: true` | One `[remote-audit]` line per call: `READ CatalogService.Orders {"user":"alice","protocol":"mcp","status":200,"backendRequests":2,"backendRows":4,...}`, no filter values. MCP and OData calls are told apart by `protocol`. |
| `maskBackendErrors: true` (profile `production`) | A backend's error text (host, table, values) stays in the log; the agent gets a generic message with the reference of the log line. |
| `cds.query.soap.agentHints: true` | `describe` of an entity over a SOAP operation with a mandatory filter (`PartnerChannels`) also shows `SOAP hints: Every read needs a filter on PartnerID ...`, next to the adapter's own `The SOAP source needs a filter on PartnerID in every read`. A query without it is a tool error with `Mandatory filter field(s) missing: PartnerID`, so the agent can correct the query. |

## 🚧 Limits

- Bound actions and functions (`Customers.block`, `creditCheck`) and CREATE / UPDATE / DELETE are not served over
  MCP; expose a change as an unbound action.
- The tools are meant for agents and are not a stable API; programs use OData.
- `@cap-js/mcp` does not filter what the backends return: data can contain text that tries to steer an agent.
  Connect trusted agents only, and keep a human confirmation on every `call`.
- Every MCP query is a query of the service: `@cds.query.limit` (here 1000 / 5000) and the
  `cds.query.remote` limits apply as for OData.
- The SAP API Policy applies to SAP data served through MCP, as through any other protocol.
