import { soap } from '@cap-ts/soap-adapter';

const WSSE = 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd';

/** Values compared with `=` or listed with `in` for an element, from a CQN WHERE (top-level `and` only). */
const valuesOf = (where: any[] = [], element: string): unknown[] => {
    const values: unknown[] = [];
    for (let i = 0; i < where.length; i++) {
        if (where[i]?.ref?.[0] !== element) continue;
        const [op, right] = [where[i + 1], where[i + 2]];
        if (op === '=' && right && 'val' in right) values.push(right.val);
        if (op === 'in' && right?.list) values.push(...right.list.map((v: any) => v.val));
    }
    return values;
};

/**
 * The adapter class of the ExchangeRates SOAP service, in TypeScript, found through `@Soap.adapter` on the service.
 * Node.js 22.18 and later load it without a build step (type stripping); `cds watch` with tsx works too.
 */
export default class ExchangeRates extends soap.Service {
    async init(): Promise<void> {
        const { Rates } = this.entities;

        // A structured SOAP header: <wsse:Security><wsse:UsernameToken><wsse:Username>...</wsse:Username>...
        // The user name comes from the service's configuration (cds.requires.ExchangeRates.wsseUser): `this.options`.
        this.header(Rates, (): soap.SoapHeaderObject => ({
            value: { UsernameToken: { Username: (this.options as any).wsseUser } },
            name: 'Security',
            prefix: 'wsse',
            xmlns: WSSE,
        }));

        // One FromCurrency per call (the /soap routes fan `FromCurrency in (...)` out); the ToCurrency values as a list;
        // the operation's input uses the backend's names From / To. `__skipPagination: true` (stripped before the call):
        // GetRates answers every rate of one currency at once, so its answer is never cut to a page of
        // cds.query.soap.pageSize; $filter / $orderby still run in memory, the routes still page what they answer.
        this.request(Rates, (req: any) => {
            const where = req.query?.SELECT?.where;
            const [from] = valuesOf(where, 'FromCurrency');
            const to = valuesOf(where, 'ToCurrency');
            return { From: from, ...(to.length && { To: to }), __skipPagination: true };
        });

        await super.init();
    }
}
