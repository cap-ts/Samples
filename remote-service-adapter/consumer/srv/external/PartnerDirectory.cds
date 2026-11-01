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

    /**
     * GetChannels takes exactly one PartnerID per call. `@Soap.filterRestriction` declares it: with
     * `cds.query.remote.agentHints` (package.json) the docs of CatalogService.PartnerChannels tell agents and other
     * clients that every read needs a filter on PartnerID, and `cds.query.soap.agentHints` adds the same to this entity.
     */
    @Soap.operation        : 'GetChannels'
    @Soap.binding          : {
        rootRequest  : 'GetChannelsRequest',
        rootResponse : 'Channel'
    }
    @Soap.filterRestriction: {
        mandatoryFields  : ['PartnerID'],
        multipleSelection: false
    }
    entity Channels {
        key PartnerID : String(10);
        key Channel   : String(10);
            Address   : String(100);
    }
}
