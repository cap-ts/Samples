const cds = require('@sap/cds');
const { SELECT, INSERT, UPDATE, DELETE } = cds.ql;

module.exports = cds.service.impl(function () {
    const { Orders, Entries } = this.entities;
    const { LedgerEntries } = cds.entities('rsa.samples.sales');

    const setStatus = async (req, ID, Status) => {
        const n = await UPDATE(Orders, ID).with({ Status });
        if (!n) return req.reject(404, `Order ${ID} not found`);
        return SELECT.one.from(Orders, ID);
    };

    this.on('cancel', Orders, (req) => setStatus(req, req.params[0].ID, 'C'));
    this.on('release', Orders, (req) => setStatus(req, req.params[0].ID, 'X'));

    this.on('printForm', Orders, async (req) => {
        const { ID } = req.params[0];
        const o = await SELECT.one.from(Orders, ID);
        if (!o) return req.reject(404, `Order ${ID} not found`);
        return `Order ${o.ID} | ${o.OrderName} | ${o.Amount} ${o.Currency} | status ${o.Status}`;
    });

    this.on('upsertStatus', (req) => {
        const { ID, Status } = req.data;
        if (!['O', 'X', 'C'].includes(Status)) return req.reject(400, `Status must be 'O', 'X' or 'C'`);
        return setStatus(req, ID, Status);
    });

    // The ledger API: reads come from the table, every change is a POST with an operation code.
    // The request's query, redirected to the table (a read by key keeps its key in from.ref[0].where).
    this.on('READ', Entries, (req) => {
        const { from, columns, ...rest } = req.query.SELECT;
        const [first] = from.ref;
        const q = SELECT.from(LedgerEntries);
        q.SELECT = {
            ...rest,
            from: { ref: [typeof first === 'string' ? LedgerEntries.name : { ...first, id: LedgerEntries.name }] },
            ...(columns && { columns: columns.filter((c) => c.ref?.[0] !== 'Op') }),
        };
        return cds.run(q);
    });

    this.on('CREATE', Entries, async (req) => {
        const { Op = 'C', CompanyCode, DocNo, ...rest } = req.data;
        const key = { CompanyCode, DocNo };
        const exists = await SELECT.one.from(LedgerEntries).where(key);
        switch (Op) {
            case 'C':
                if (exists) return req.reject(409, `Entry ${CompanyCode}/${DocNo} exists`);
                await INSERT.into(LedgerEntries).entries({ ...key, ...rest });
                break;
            case 'U':
                if (!exists) return req.reject(404, `Entry ${CompanyCode}/${DocNo} not found`);
                await UPDATE(LedgerEntries).set(rest).where(key);
                break;
            case 'D':
                if (!exists) return req.reject(404, `Entry ${CompanyCode}/${DocNo} not found`);
                await DELETE.from(LedgerEntries).where(key);
                return { ...exists, Op };
            default:
                return req.reject(400, `Unknown operation '${Op}'`);
        }
        return { ...(await SELECT.one.from(LedgerEntries).where(key)), Op };
    });

    this.on(['UPDATE', 'DELETE'], Entries, (req) =>
        req.reject(405, 'The ledger API only accepts POST: send the operation in Op (C, U, D).'));
});
