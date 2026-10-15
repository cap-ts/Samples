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
            // srv.run on the SOAP service: the same pipeline as its /soap routes (hooks, call, mapping, in-memory filter)
            const products = await catalog.run(SELECT.from('ProductCatalog.Products').where({ Discontinued: false }));
            const usd = await rateOf(req, 'EUR', 'USD');
            const names = Object.fromEntries((await countries.run(SELECT.from('CountryCodes.Countries'))).map((c) => [c.Code, c.Name]));
            // GetStock takes one product per call: one soap.read per product (the fan-out of the routes is route-only)
            const offers = await Promise.all(products.map(async (p) => {
                const [stock] = await soap.read(catalog, 'Stock', req, SELECT.from('Stock').where({ ProductID: p.ProductID }));
                return {
                    ProductID: p.ProductID, Name: p.Name, Category: p.Category, Price: p.Price, Currency: p.Currency,
                    PriceUSD: Math.round(Number(p.Price) * usd * 100) / 100,
                    Available: stock?.Available ?? null, Warehouse: stock?.Warehouse ?? null,
                    SupplierName: p.SupplierName, Country: names[p.SupplierCountry] ?? p.SupplierCountry,
                };
            }));
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
