const cds = require('@sap/cds');
const { soap } = require('@cap-ts/soap-adapter');

const LOG = cds.log('shop');

/** The terms of a CQN WHERE at its top-level `and` (`[]` when it has a top-level `or`: nothing can be taken out). */
const andTerms = (where = []) => {
    if (where.some((t) => t === 'or')) return null;
    const terms = [[]];
    for (const t of where) {
        if (t === 'and') terms.push([]);
        else terms[terms.length - 1].push(t);
    }
    return terms.filter((t) => t.length);
};
const isRef = (t, name) => t?.ref?.length === 1 && t.ref[0] === name;

/**
 * The adapter class of the ProductCatalog SOAP service (found by the file convention: <Service>.js next to the .cds).
 * It is the CAP service of the SOAP service: one instance, hooks registered in init().
 */
class ProductCatalog extends soap.Service {
    async init() {
        const { Products, Stock } = this.entities;

        // SOAP headers of every call (a plain map: one element per key). Keys of soap.Service.FORBIDDEN_SOAP_HEADERS
        // (Authorization, Cookie, ...) would be dropped. The backend echoes Channel into every product.
        this.header(Products, (req) => ({ Channel: 'SHOP-API', TraceID: req.id }));

        /**
         * Products: the request's $filter / $orderby / $top / $skip as the operation's input. When ALL of it could be
         * expressed and the request names a page ($top), the payload carries `__filterPushedDown: true` and the backend's
         * answer is the page. Otherwise the input only narrows the answer and the runtime filters, sorts and pages in
         * memory: with $count (it needs every matching row), and without $top (the page of cds.query.soap.pageSize and
         * its @odata.nextLink come from the runtime).
         */
        this.request(Products, (req) => {
            const { where, orderBy, limit, count } = req.query?.SELECT ?? {};
            const payload = {};
            let complete = true;
            for (const term of andTerms(where) ?? (complete = false, [])) {
                const [left, op, right] = term;
                if (isRef(left, 'ProductID') && op === '=' && 'val' in right) payload.ProductID = [right.val];
                else if (isRef(left, 'ProductID') && op === 'in' && right?.list) payload.ProductID = right.list.map((v) => v.val);
                else if (isRef(left, 'Category') && op === '=' && 'val' in right) payload.Category = right.val;
                else if (term.length === 1 && term[0].func === 'contains' && isRef(term[0].args?.[0], 'Name')) {
                    payload.NameContains = term[0].args[1].val;   // the backend ignores case: it narrows, $filter decides
                    complete = false;
                } else complete = false;
            }
            if (orderBy?.length === 1 && ['Name', 'Price', 'ProductID', 'Category'].includes(orderBy[0].ref?.[0])) {
                payload.SortBy = orderBy[0].ref[0];
                payload.Descending = orderBy[0].sort === 'desc';
            } else if (orderBy?.length) complete = false;
            if (complete && !count && limit?.rows) {
                payload.MaxHits = limit.rows.val;
                if (limit.offset) payload.Skip = limit.offset.val;
                payload.__filterPushedDown = true;   // stripped before the call
            }
            LOG.debug('FindProducts input', payload);
            return payload;
        });

        // Raw entries, before the @Soap.path mapping: 'X' / '' becomes a Boolean
        this.response(Products, (req, rows) => rows.map((r) => ({ ...r, Discontinued: r.Discontinued === 'X' })));

        // Stock: one ProductID per call (the /soap routes fan `in (...)` out, see @Soap.filterRestriction)
        this.request(Stock, (req) => {
            const term = (andTerms(req.query?.SELECT?.where) ?? []).find((t) => isRef(t[0], 'ProductID') && t[1] === '=');
            return term ? { ProductID: term[2].val } : {};
        });

        // Ordinary CAP handlers work on a SOAP service, around the SOAP pipeline
        this.after('READ', Stock, (rows) => {
            for (const r of Array.isArray(rows) ? rows : [rows]) if (r && r.Quantity != null) r.Available = r.Quantity - (r.Reserved ?? 0);
        });

        await super.init();   // registers the SOAP READ pipeline
    }
}

module.exports = ProductCatalog;
