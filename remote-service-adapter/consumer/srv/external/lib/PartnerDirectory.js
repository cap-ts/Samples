const { soap } = require('@cap-ts/soap-adapter');

/** Values compared with `=` or listed with `in` for an element, from a CQN WHERE (top-level `and` only). */
const valuesOf = (where, element) => {
    const values = [];
    for (let i = 0; i < where.length; i++) {
        const left = where[i];
        if (left?.ref?.[left.ref.length - 1] !== element) continue;
        const op = where[i + 1];
        const right = where[i + 2];
        if (op === '=' && right && 'val' in right) values.push(right.val);
        if (op === 'in' && right?.list) values.push(...right.list.map((v) => v.val));
    }
    return values;
};

/**
 * Adapter class of the SOAP service (found by the file convention: lib/<Service>.js next to the .cds file).
 * The operation takes PartnerID (any number) and Country; everything else of the request is evaluated in memory
 * by the soap-adapter, and again by @cap-ts/remote-service-adapter for the projections on top.
 */
class PartnerDirectory extends soap.Service {
    async init() {
        const { Partners } = this.entities;

        this.request(Partners, (req) => {
            const { where = [], from } = req.query?.SELECT ?? {};
            // A read by key (Partners('BP01')) carries its key in from.ref[0].where.
            const keyWhere = from?.ref?.[0]?.where ?? [];
            const payload = {};
            const ids = [...valuesOf(keyWhere, 'PartnerID'), ...valuesOf(where, 'PartnerID')];
            const [country] = valuesOf(where, 'Country');
            if (ids.length) payload.PartnerID = ids;
            if (country) payload.Country = country;
            return payload;
        });

        await super.init();
    }
}

module.exports = PartnerDirectory;
