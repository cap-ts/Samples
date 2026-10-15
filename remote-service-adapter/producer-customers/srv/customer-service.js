const cds = require('@sap/cds');
const { SELECT, UPDATE } = cds.ql;

/**
 * Nests the flat `Address_*` columns of a row into `Address: { ... }`, the shape `$metadata` declares
 * (`cds.odata.structs: true`). Remote systems such as S/4 answer complex types this way, which is what the consumer's
 * `Address.City as City` columns read.
 */
const nestAddress = (rows) => {
    for (const row of Array.isArray(rows) ? rows : rows ? [rows] : []) {
        const keys = Object.keys(row).filter((k) => k.startsWith('Address_'));
        if (!keys.length) continue;
        row.Address = {};
        for (const k of keys) {
            row.Address[k.slice('Address_'.length)] = row[k];
            delete row[k];
        }
    }
};

module.exports = cds.service.impl(function () {
    const { Customers } = this.entities;

    this.after('READ', Customers, nestAddress);

    this.on('block', Customers, async (req) => {
        const { ID } = req.params[0];
        await UPDATE(Customers, ID).with({ Status: 'B' });
        const row = await SELECT.one.from(Customers, ID);
        nestAddress(row);
        return row;
    });

    this.on('creditCheck', Customers, async (req) => {
        const { ID } = req.params[0];
        const customer = await SELECT.one.from(Customers, ID).columns('CreditLimit');
        if (!customer) return req.reject(404, `Customer ${ID} not found`);
        return Number(req.data.Amount) <= Number(customer.CreditLimit);
    });

    this.on('setStatus', async (req) => {
        const { ID, Status } = req.data;
        if (!['A', 'B'].includes(Status)) return req.reject(400, `Status must be 'A' or 'B'`);
        const n = await UPDATE(Customers, ID).with({ Status });
        if (!n) return req.reject(404, `Customer ${ID} not found`);
        const row = await SELECT.one.from(Customers, ID);
        nestAddress(row);
        return row;
    });
});
