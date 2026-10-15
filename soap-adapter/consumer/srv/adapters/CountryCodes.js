const { soap } = require('@cap-ts/soap-adapter');

const COUNTRIES = [
    { Code: 'AT', Name: 'Austria' },
    { Code: 'DE', Name: 'Germany' },
    { Code: 'SE', Name: 'Sweden' },
    { Code: 'TW', Name: 'Taiwan' },
];

/**
 * The adapter class of the CountryCodes SOAP service, named by `impl` in cds.requires.CountryCodes.
 *
 * mock() replaces the SOAP call: no destination, no WSDL loading, no HTTP. Its answer is final (no response() hooks,
 * no @Soap.path mapping, no in-memory $filter / paging), so the mock applies the filter it supports itself.
 * A registered mock is always active: register it only in development or test code.
 */
class CountryCodes extends soap.Service {
    async init() {
        const { Countries } = this.entities;
        this.mock(Countries, (req) => {
            const where = req.query?.SELECT?.where ?? [];
            const i = where.findIndex((t) => t?.ref?.[0] === 'Code');
            return i >= 0 && where[i + 1] === '=' ? COUNTRIES.filter((c) => c.Code === where[i + 2].val) : COUNTRIES;
        });
        await super.init();
    }
}

module.exports = CountryCodes;
