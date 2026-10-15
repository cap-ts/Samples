using from '@cap-ts/soap-adapter';   // the @Soap.* vocabulary: cds compile checks the annotations below

/**
 * The SOAP web service of producer-partners, modelled for @cap-ts/soap-adapter. cds.requires.PartnerDirectory has
 * kind 'soap', the local WSDL and the destination; the adapter class is lib/PartnerDirectory.js.
 */
@Soap
service PartnerDirectory {
    @Soap.operation   : 'GetPartners'
    @Soap.binding     : {
        rootRequest  : 'GetPartnersRequest',
        rootResponse : 'Partner'
    }
    entity Partners {
        key PartnerID : String(10);
            Name      : String(80);
            Country   : String(3);
            Customer  : String(10);
            @Soap.path: 'Contact.Email'
            Email     : String(100);
            @Soap.path: 'Contact.Phone'
            Phone     : String(20);
    }
}
