/**
 * PartnerDirectory: a SOAP 1.1 web service with one operation, GetPartners.
 *
 * Input:  zero or more PartnerID elements and an optional Country.
 * Output: the matching Partner entries (all of them without input), each with a nested Contact.
 *
 * Stands in for a legacy SOAP backend. It accepts any credentials: the consumer reaches it through a destination
 * with basic authentication, as it would reach a real system.
 */
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const soap = require('soap');

const PORT = Number(process.env.PORT || 6006);
const wsdl = fs.readFileSync(path.join(__dirname, 'wsdl', 'PartnerDirectory.wsdl'), 'utf8');
const partners = JSON.parse(fs.readFileSync(path.join(__dirname, 'data', 'partners.json'), 'utf8'));

const asList = (v) => (v === undefined || v === null ? [] : Array.isArray(v) ? v : [v]);

const service = {
    PartnerDirectory: {
        PartnerDirectoryPort: {
            GetPartners(input) {
                const args = input ?? {}; // an empty request arrives as null
                const ids = asList(args.PartnerID);
                const country = args.Country;
                const Partner = partners.filter(
                    (p) => (!ids.length || ids.includes(p.PartnerID)) && (!country || p.Country === country),
                );
                process.stdout.write(`[soap] GetPartners ${JSON.stringify(args)} -> ${Partner.length} partner(s)\n`);
                return { Partner };
            },
        },
    },
};

const server = http.createServer((req, res) => {
    res.statusCode = 404;
    res.end('Not found: the SOAP endpoint is /soap/partners (WSDL: /soap/partners?wsdl)');
});

server.listen(PORT, () => {
    soap.listen(server, '/soap/partners', service, wsdl);
    process.stdout.write(`[soap] PartnerDirectory listening on http://localhost:${PORT}/soap/partners\n`);
});
