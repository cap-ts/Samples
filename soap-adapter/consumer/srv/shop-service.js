const cds = require('@sap/cds');
const { soap } = require('@cap-ts/soap-adapter');

const { SELECT } = cds.ql;

module.exports = class ShopService extends cds.ApplicationService {
    async init() {
        const catalog = await cds.connect.to('ProductCatalog');
        const rates = await cds.connect.to('ExchangeRates');
        const countries = await cds.connect.to('CountryCodes');

        /** One rate through soap.read: a fresh request per call (headers of the inbound request stripped). */
        const rateOf = async (req, From, To) => {
            if (From === To) return 1;
            const [row] = await soap.read(rates, 'Rates', req, SELECT.from('Rates').where({ FromCurrency: From, ToCurrency: To }));
            if (!row) return req.reject(404, `No exchange rate ${From} -> ${To}`);
            return Number(row.Rate);
        };

        this.on('READ', 'Offers', async (req) => {
            // srv.run on the SOAP service: the same pipeline as its /soap routes (hooks, call, mapping, in-memory filter).
            // Discontinued is filtered in memory, and that answer is cut to one page (cds.query.soap.pageSize, 4 here):
            // SELECT.__skipPagination asks for every matching product, as the offers are paged below.
            const query = SELECT.from('ProductCatalog.Products').where({ Discontinued: false });
            query.SELECT.__skipPagination = true;
            const products = await catalog.run(query);
            const usd = await rateOf(req, 'EUR', 'USD');
            const names = Object.fromEntries((await countries.run(SELECT.from('CountryCodes.Countries'))).map((c) => [c.Code, c.Name]));
            // GetStock takes one product per call (multipleSelection: false): one soap.read with the list of products is
            // one SOAP call per product, merged (cds.query.soap.multiSelectionConcurrency at a time); __skipPagination: every
            // merged row, not a page of pageSize
            const stockQuery = SELECT.from('Stock').where({ ProductID: { in: products.map((p) => p.ProductID) } });
            stockQuery.SELECT.__skipPagination = true;
            const stocks = await soap.read(catalog, 'Stock', req, stockQuery);
            const stockOf = Object.fromEntries(stocks.map((s) => [s.ProductID, s]));
            const offers = products.map((p) => {
                const stock = stockOf[p.ProductID];
                return {
                    ProductID: p.ProductID, Name: p.Name, Category: p.Category, Price: p.Price, Currency: p.Currency,
                    PriceUSD: Math.round(Number(p.Price) * usd * 100) / 100,
                    Available: stock?.Available ?? null, Warehouse: stock?.Warehouse ?? null,
                    SupplierName: p.SupplierName, Country: names[p.SupplierCountry] ?? p.SupplierCountry,
                };
            });
            // $filter (Category eq '...'), $orderby and paging of Offers, applied here
            const { where, orderBy, limit, count } = req.query.SELECT;
            const category = where?.[0]?.ref?.[0] === 'Category' && where[1] === '=' ? where[2].val : undefined;
            let result = category ? offers.filter((o) => o.Category === category) : offers;
            for (const { ref, sort } of [...(orderBy ?? [])].reverse()) {
                const dir = sort === 'desc' ? -1 : 1;
                result = [...result].sort((a, b) => (a[ref[0]] < b[ref[0]] ? -dir : a[ref[0]] > b[ref[0]] ? dir : 0));
            }
            const total = result.length;
            const offset = limit?.offset?.val ?? 0;
            if (limit?.rows) result = result.slice(offset, offset + limit.rows.val);
            if (count) result.$count = total;
            return result;
        });

        this.on('convert', async (req) => {
            const { Amount, From, To } = req.data;
            return Math.round(Number(Amount) * (await rateOf(req, From, To)) * 100) / 100;
        });

        // soap.createRequest: a real cds.Request of its own (fresh context id, the caller's user, sensitive headers of
        // the inbound request not copied), dispatched to the SOAP service directly. soap.read does the same plus the key
        // de-duplication; createRequest is for a dispatch you control yourself.
        this.on('stockOf', async (req) => {
            const { Stock } = catalog.entities;
            const request = soap.createRequest({
                event: 'READ',
                query: SELECT.from(Stock).where({ ProductID: req.data.ProductID }),
                target: Stock,
                user: req.user,
                headers: soap.Service.stripSensitiveHeaders(req.headers ?? {}),
            });
            const [row] = await catalog.dispatch(request);
            return row ?? req.reject(404, `No stock for ${req.data.ProductID}`);
        });

        this.on('soapInfo', (req) => {
            const inbound = { authorization: 'Basic ...', cookie: 'x', 'x-correlation-id': '1', 'accept-language': 'en' };
            const rows = [{ ProductID: 'P1', Name: 'a' }, { ProductID: 'P1', Name: 'b' }, { ProductID: 'P2', Name: 'c' }];
            return {
                soapServices: ['ProductCatalog', 'ExchangeRates', 'CountryCodes', 'ShopService'].filter((s) => soap.isSoapService(s)),
                keysOfRates: soap.getEntityKeyFields(rates.entities.Rates),
                forbiddenHeaders: soap.Service.FORBIDDEN_SOAP_HEADERS.length,
                strippedHeaders: Object.keys(soap.Service.stripSensitiveHeaders(inbound)),
                dedupedRows: soap.dedupByKeys(rows, ['ProductID']).length,
            };
        });

        await super.init();
    }
};
