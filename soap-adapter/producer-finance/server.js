/**
 * ExchangeRates: a SOAP 1.1 web service with one operation, GetRates.
 *
 * Input:  exactly one From currency (a fault without) and any number of To currencies (all without).
 * Output: Rates/Rate[] (From, To, Rate, ValidOn, PublishedAt, RateID).
 *
 * Every call needs a WS-Security UsernameToken SOAP header with a Username (a fault without), as many enterprise
 * services do. The password is not checked: this is a sample.
 */
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const soap = require('soap');

const PORT = Number(process.env.PORT || 8092);
const wsdl = fs.readFileSync(path.join(__dirname, 'wsdl', 'ExchangeRates.wsdl'), 'utf8');
const rates = JSON.parse(fs.readFileSync(path.join(__dirname, 'data', 'rates.json'), 'utf8'));

const asList = (v) => (v === undefined || v === null ? [] : Array.isArray(v) ? v : [v]);
const fault = (text) => ({ Fault: { faultcode: 'soap:Client', faultstring: text } });

const service = {
    ExchangeRates: {
        ExchangeRatesPort: {
            GetRates(input, _cb, headers) {
                const user = headers?.UsernameToken?.Username;
                if (!user) throw fault('Authentication required: send a wsse:UsernameToken header');
                const from = input?.From;
                if (!from || Array.isArray(from)) throw fault('GetRates takes exactly one From currency');
                const to = asList(input.To);
                const Rate = rates.filter((r) => r.From === from && (!to.length || to.includes(r.To)));
                process.stdout.write(`[soap] GetRates ${JSON.stringify(input)} for ${user} -> ${Rate.length} rate(s)\n`);
                return { Rates: { Rate } };
            },
        },
    },
};

const server = http.createServer((req, res) => {
    res.statusCode = 404;
    res.end('Not found: the SOAP endpoint is /soap/rates (WSDL: /soap/rates?wsdl)');
});

server.listen(PORT, () => {
    soap.listen(server, '/soap/rates', service, wsdl);
    process.stdout.write(`[soap] ExchangeRates listening on http://localhost:${PORT}/soap/rates\n`);
});
