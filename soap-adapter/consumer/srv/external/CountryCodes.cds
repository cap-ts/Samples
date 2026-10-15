using from '@cap-ts/soap-adapter';

/**
 * A SOAP service that is not called at all: its adapter class (srv/adapters/CountryCodes.js, named by `impl` in
 * cds.requires.CountryCodes) answers from a mock(), for offline development and tests.
 */
@Soap
service CountryCodes {
    @Soap.operation   : 'ListCountries'
    @Soap.rootResponse: 'Country'
    entity Countries {
        key Code : String(3);
            Name : String(60);
    }
}
