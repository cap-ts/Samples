using { ProductCatalog } from './external/ProductCatalog';
using { ExchangeRates } from './external/ExchangeRates';
using { CountryCodes } from './external/CountryCodes';

/**
 * ShopService: an ordinary CAP service (OData V4) that uses the SOAP services in-process: `srv.run(SELECT ...)` on the
 * SOAP service, `soap.read(...)` (a fresh request per call, keys de-duplicated) and the other utilities of the package.
 */
@path: 'shop'
service ShopService {

    /** Products of the catalog that are not discontinued, with their stock and their price in USD. */
    @readonly
    @cds.persistence.skip
    entity Offers {
        key ProductID    : String(10);
            Name         : String(60);
            Category     : String(30);
            Price        : Decimal(15, 2);
            Currency     : String(3);
            PriceUSD     : Decimal(15, 2);
            Available    : Integer;
            Warehouse    : String(20);
            SupplierName : String(60);
            Country      : String(60);
    }

    /** The stock of one product: a request built with `soap.createRequest` and dispatched to ProductCatalog. */
    function stockOf(ProductID : String(10)) returns {
        ProductID : String(10);
        Warehouse : String(20);
        Quantity  : Integer;
        Available : Integer;
    };

    /** Converts an amount with the rate of the ExchangeRates service. */
    function convert(Amount : Decimal(15, 2), From : String(3), To : String(3)) returns Decimal(15, 2);

    /** What the utility API of @cap-ts/soap-adapter tells about the services of this application. */
    function soapInfo() returns {
        soapServices      : many String;
        keysOfRates       : many String;
        forbiddenHeaders  : Integer;
        strippedHeaders   : many String;
        dedupedRows       : Integer;
    };
}
