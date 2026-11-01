using from '@cap-ts/soap-adapter';

/**
 * An internal SOAP service: `@protocol: 'none'`, as for CAP's own protocol adapters. No route is mounted (no
 * `/soap/warehouses`, no `/warehouses`, no `/odata/v4/warehouses`: 404);  ShopService reads it in-process. Every
 * in-process read (srv.run, soap.read, a projection of another service) checks `@requires` / `@restrict` for the
 * request's user, as CAP checks an ApplicationService (see Authentication in the package README).
 * The adapter class (srv/adapters/Warehouses.js, named by `impl`) answers from a mock().
 */
@Soap
@protocol: 'none'
@requires: 'finance'
@path    : 'warehouses'
service Warehouses {
    @Soap.operation   : 'ListWarehouses'
    @Soap.rootResponse: 'Warehouse'
    entity Sites {
        key Code    : String(20);
            City    : String(60);
            Country : String(3);
    }
}
