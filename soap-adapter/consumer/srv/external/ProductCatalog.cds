using from '@cap-ts/soap-adapter';

/**
 * The ProductCatalog web service of producer-catalog (two operations).
 *
 * Served by @cap-ts/soap-adapter at /soap/catalog/<Entity> (`@path`), and as a CAP service in this process.
 * Adapter class: ProductCatalog.js next to this file (the file convention).
 */
@Soap
@path: 'catalog'
service ProductCatalog {

    /**
     * FindProducts answers `Products/item[]`: `rootResponse` drills to `Products`, the `item` list is unwrapped.
     * `Price` arrives as `<Price currency="EUR">29.99</Price>` ({ $value, attributes }): the `$value` is read.
     */
    @Soap.operation: 'FindProducts'
    @Soap.binding  : {
        rootRequest : 'FindProductsRequest',
        rootResponse: 'Products'
    }
    entity Products {
        key ProductID    : String(10);
            Name         : String(60);
            Category     : String(30);
            Price        : Decimal(15, 2);
            Currency     : String(3);
            @Soap.path: 'Supplier.Name'
            SupplierName : String(60);
            @Soap.path: 'Supplier.Country'
            SupplierCountry : String(3);
            /** 'X' in the response; turned into a Boolean by the response() hook */
            Discontinued : Boolean;
            /** The SOAP header Channel, echoed by the backend: shows what the header() hook sent */
            Channel      : String(20);
    }

    /**
     * GetStock takes exactly one ProductID: `multipleSelection: false` turns `ProductID in (...)` into one SOAP call per
     * value (on the /soap routes), `mandatoryFields` rejects a request without it (400).
     */
    @Soap.operation        : 'GetStock'
    @Soap.rootResponse     : 'Stock'
    @Soap.filterRestriction: {
        mandatoryFields  : ['ProductID'],
        multipleSelection: false
    }
    entity Stock {
        key ProductID : String(10);
            Warehouse : String(20);
            Quantity  : Integer;
            Reserved  : Integer;
            /** Computed by an after('READ') handler of the adapter class */
            Available : Integer;
    }
}
