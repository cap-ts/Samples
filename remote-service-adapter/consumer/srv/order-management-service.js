const cds = require('@sap/cds');
const { RemoteApplicationService } = require('@cap-ts/remote-service-adapter');

const { SELECT } = cds.ql;

/**
 * The implementation of OrderManagementService: RemoteApplicationService plus handlers of its own.
 *
 * Handlers registered before `super.init()` run before the generic ones; an `on` handler replaces the generic one
 * unless it calls `next()`.
 */
class OrderManagementService extends RemoteApplicationService {
    async init() {
        const { Orders, Entries } = this.entities;

        // Backend-only and derived values: CAP drops client values of @readonly Channel, not the handler's.
        this.before('CREATE', Orders, (req) => {
            req.data.Channel = 'API';
            req.data.Status ??= 'O';
            req.data.OrderDate ??= new Date().toISOString();
        });

        // A bound action without a source operation: reads and writes through the adapter's pipeline.
        // readSource / writeSource skip the service's handlers and CAP's authorization: the request is authorized
        // here already (it reached this handler).
        this.on('release', Entries, async (req) => {
            const { CompanyCode, DocNo } = req.params[0];
            const entry = await this.readSource(Entries, { CompanyCode, DocNo });
            if (!entry) return req.reject(404, `Entry ${CompanyCode}/${DocNo} not found`);
            if (entry.Released) return req.reject(409, `Entry ${CompanyCode}/${DocNo} is released already`);
            await this.writeSource('UPDATE', Entries, { CompanyCode, DocNo, Released: true }, { checkWhere: false });
            return this.readSource(Entries, { CompanyCode, DocNo });
        });

        // A query through this service may name path columns, aliases and expressions, as with any CAP service.
        this.on('orderCard', async (req) => {
            const row = await this.run(
                SELECT.one
                    .from(Orders)
                    .columns(
                        'ID',
                        'Title',
                        'Amount as Total',
                        '_Customer.Name as CustomerName',
                        '_Customer.Status as CustomerStatus',
                        { func: 'upper', args: [{ ref: ['Title'] }], as: 'LoudTitle' },
                    )
                    .where({ ID: req.data.ID }),
            );
            return row ?? req.reject(404, `Order ${req.data.ID} not found`);
        });

        // supportsSkipPagination (true for every RemoteApplicationService): other instances may send this service the
        // internal "all rows" hint of their association fetches. An own implementation of a service that is the target
        // of such fetches declares it only when it honors SELECT.__skipPagination.
        this.on('adapterInfo', () => ({ supportsSkipPagination: this.supportsSkipPagination === true }));

        await super.init();
    }
}

module.exports = OrderManagementService;
