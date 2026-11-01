/**
 * MCP: the services of this consumer, served to AI agents as well (plugin @cap-js/mcp, see AI-AGENTS.md).
 *
 * `@mcp` is a protocol annotation like `@odata`: a service that names one protocol is served by that protocol only,
 * so `@odata` is named too and every OData endpoint and test/http request stays as it is. Each MCP endpoint
 * (/mcp/catalog, /mcp/restricted) serves the tools `describe`, `query` and `call`; every request runs through the
 * same service implementation (RemoteApplicationService) as an OData request, with the same push-down to the
 * backends and the same `@requires` / `@restrict` checks for the calling user.
 *
 * `@mcp.instructions` holds what only this application knows (the systems, the codes, when an action may be called).
 * How to read efficiently (columns, limits, totals, which entity comes from which system, the request budget) is added
 * to the docs by `cds.query.remote.agentHints` (package.json): `describe` shows it.
 */
using from './catalog-service';
using from './restricted-service';

annotate CatalogService with @odata @mcp @mcp.instructions: 'One model over four systems and a local database: the customer system (OData V4), the product system (OData V2), the sales system (OData V4), the partner directory (SOAP) and Regions in the local database. Orders.CustomerName, Orders.CustomerRegion and Items.ProductName read across systems; OrderLines, PartnerCustomers and GroupRegions are join views over several systems. Order Status: O open, X closed, C cancelled. Customer Status: A active, B blocked. Use describe before the first query and follow the Adapter hints it shows for the service and its entities. setCustomerStatus changes a customer in the customer system: call it only after the user confirmed the change.';

annotate RestrictedService with @odata @mcp @mcp.instructions: 'Customers are restricted: a user without the admin role sees only the customers of the own CompanyCode (none without a CompanyCode). Orders are not restricted: every user of this service sees every order; an expanded _Customer of an order is filtered like Customers.';
