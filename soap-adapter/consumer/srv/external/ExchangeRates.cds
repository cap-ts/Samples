using from '@cap-ts/soap-adapter';

/**
 * The ExchangeRates web service of producer-finance. It requires a WS-Security UsernameToken SOAP header.
 *
 * Adapter class: srv/adapters/ExchangeRates.ts (TypeScript), named by `@Soap.adapter`. `@requires` protects its
 * /soap routes (401 without a user, 403 without the role). `strict: true` in cds.requires: a missing adapter class would
 * stop the start instead of answering 501.
 */
@Soap
@Soap.adapter: 'srv/adapters/ExchangeRates'
@path        : 'rates'
@requires    : 'finance'
service ExchangeRates {

    /**
     * `@Soap.rootResponse` takes precedence over `@Soap.binding.rootResponse`: the rows are `Rates/Rate[]`.
     * One From currency per call: `FromCurrency in ('EUR', 'USD')` is fanned out on the /soap routes.
     * `From` is a reserved word in CDS: the elements are named otherwise and `@Soap.path` names the response field.
     */
    @Soap.operation        : 'GetRates'
    @Soap.binding          : {
        rootRequest : 'GetRatesRequest',
        rootResponse: 'Rates'
    }
    @Soap.rootResponse     : 'Rates.Rate'
    @Soap.filterRestriction: {
        mandatoryFields  : ['FromCurrency'],
        multipleSelection: false
    }
    entity Rates {
        @Soap.path: 'From'
        key FromCurrency : String(3);
        @Soap.path: 'To'
        key ToCurrency   : String(3);
            Rate         : Decimal(15, 5);
            ValidOn      : Date;
            /** `xsd:dateTime` in the response: a `$filter` on it takes a date-time literal with an offset. */
            PublishedAt  : DateTime;
            /** A GUID as `xsd:string`: a `$filter` on it takes an unquoted GUID literal. */
            RateID       : UUID;
    }
}
