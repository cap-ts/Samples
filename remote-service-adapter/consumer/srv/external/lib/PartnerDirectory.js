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

/** The PartnerID values of a read: its key (`Partners('BP01')` carries it in from.ref[0].where) and its WHERE. */
const partnerIDs = (req) => {
    const { where = [], from } = req.query?.SELECT ?? {};
    return [...valuesOf(from?.ref?.[0]?.where ?? [], 'PartnerID'), ...valuesOf(where, 'PartnerID')];
};

/**
 * Adapter class of the SOAP service (found by the file convention: lib/<Service>.js next to the .cds file).
 * GetPartners takes PartnerID (any number) and Country; everything else of the request is evaluated in memory by the
 * soap-adapter, and again by @cap-ts/remote-service-adapter for the projections on top.
 */
class PartnerDirectory extends soap.Service {
    async init() {
        const { Partners, Channels } = this.entities;

        this.request(Partners, (req) => {
            const payload = {};
            const ids = partnerIDs(req);
            const [country] = valuesOf(req.query?.SELECT?.where ?? [], 'Country');
            if (ids.length) payload.PartnerID = ids;
            if (country) payload.Country = country;
            return payload;
        });

        // GetChannels takes exactly one PartnerID (@Soap.filterRestriction). The soap-adapter enforces it on every read
        // (the /soap routes, the CatalogService.PartnerChannels projection in this process): without PartnerID a 400
        // before this hook, a list of partners one call per partner. So the hook gets one PartnerID.
        this.request(Channels, (req) => ({ PartnerID: partnerIDs(req)[0] }));

        await super.init();
    }
}

module.exports = PartnerDirectory;
