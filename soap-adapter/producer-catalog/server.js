/**
 * ProductCatalog: a SOAP 1.1 web service with two operations.
 *
 * FindProducts  input:  any number of ProductID, Category, NameContains, SortBy (+ Descending), Skip, MaxHits
 *               output: TotalHits and Products/item[], each with a Price element that carries an attribute
 *                       (<Price currency="EUR">29.99</Price>) and a nested Supplier
 * GetStock      input:  exactly one ProductID (a fault without)
 *               output: Stock of that product
 *
 * The server filters, sorts and pages itself, so a client can push its query into the request. It echoes the SOAP
 * header element Channel into every product it returns. It accepts any credentials.
 */
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const soap = require('soap');

const PORT = Number(process.env.PORT || 8091);
const read = (file) => JSON.parse(fs.readFileSync(path.join(__dirname, ...file), 'utf8'));
const wsdl = fs.readFileSync(path.join(__dirname, 'wsdl', 'ProductCatalog.wsdl'), 'utf8');
const products = read(['data', 'products.json']);
const stock = read(['data', 'stock.json']);

const asList = (v) => (v === undefined || v === null ? [] : Array.isArray(v) ? v : [v]);
const fault = (text) => ({ Fault: { faultcode: 'soap:Client', faultstring: text } });
const log = (op, args, rows) => process.stdout.write(`[soap] ${op} ${JSON.stringify(args)} -> ${rows} row(s)\n`);

const service = {
    ProductCatalog: {
        ProductCatalogPort: {
            FindProducts(input, _cb, headers) {
                const args = input ?? {};   // an empty request arrives as null
                const ids = asList(args.ProductID);
                const word = args.NameContains?.toLowerCase();
                let found = products.filter((p) => (!ids.length || ids.includes(p.ProductID))
                    && (!args.Category || p.Category === args.Category)
                    && (!word || p.Name.toLowerCase().includes(word)));
                if (args.SortBy && products[0][args.SortBy] !== undefined) {
                    const dir = String(args.Descending) === 'true' ? -1 : 1;
                    found = [...found].sort((a, b) => (a[args.SortBy] < b[args.SortBy] ? -dir : a[args.SortBy] > b[args.SortBy] ? dir : 0));
                }
                const total = found.length;
                const skip = Number(args.Skip ?? 0);
                found = found.slice(skip, args.MaxHits !== undefined ? skip + Number(args.MaxHits) : undefined);
                const channel = headers?.Channel;
                log('FindProducts', { ...args, Channel: channel }, found.length);
                return {
                    TotalHits: total,
                    Products: {
                        item: found.map((p) => ({
                            ...p,
                            Price: { attributes: { currency: p.Currency }, $value: p.Price.toFixed(2) },
                            ...(channel && { Channel: channel }),
                        })),
                    },
                };
            },
            GetStock(input) {
                const id = input?.ProductID;
                if (!id || Array.isArray(id)) throw fault('GetStock takes exactly one ProductID');
                const row = stock.find((s) => s.ProductID === id);
                log('GetStock', input, row ? 1 : 0);
                return row ? { Stock: row } : {};
            },
        },
    },
};

const server = http.createServer((req, res) => {
    res.statusCode = 404;
    res.end('Not found: the SOAP endpoint is /soap/catalog (WSDL: /soap/catalog?wsdl)');
});

server.listen(PORT, () => {
    soap.listen(server, '/soap/catalog', service, wsdl);
    process.stdout.write(`[soap] ProductCatalog listening on http://localhost:${PORT}/soap/catalog\n`);
});
