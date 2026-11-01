const { soap } = require('@cap-ts/soap-adapter');

const SITES = [
    { Code: 'WH-NORTH', City: 'Hamburg', Country: 'DE' },
    { Code: 'WH-SOUTH', City: 'Graz', Country: 'AT' },
    { Code: 'WH-EAST', City: 'Taipei', Country: 'TW' },
];

/**
 * The adapter class of the internal Warehouses SOAP service, named by `impl` in cds.requires.Warehouses. It answers
 * from a mock() (no SOAP call); the mock applies the key filter it supports itself.
 */
class Warehouses extends soap.Service {
    async init() {
        const { Sites } = this.entities;
        this.mock(Sites, (req) => {
            const where = req.query?.SELECT?.where ?? [];
            const i = where.findIndex((t) => t?.ref?.[0] === 'Code');
            return i >= 0 && where[i + 1] === '=' ? SITES.filter((s) => s.Code === where[i + 2].val) : SITES;
        });
        await super.init();
    }
}

module.exports = Warehouses;
