/* checksum : 9f8df5c940b52d8c61356e294f142790 */
@cds.external : true
service CustomerService {
  @cds.external : true
  action setStatus(
    ID : String(10),
    Status : String(1)
  ) returns Customers;

  @cds.external : true
  @cds.persistence.skip : true
  entity Customers {
    @odata.Precision : 7
    @odata.Type : 'Edm.DateTimeOffset'
    @UI.HiddenFilter : true
    @UI.ExcludeFromNavigationContext : true
    @Core.Immutable : true
    @Core.Computed : true
    @Common.Label : 'Created On'
    createdAt : Timestamp;
    /** User's unique ID */
    @UI.HiddenFilter : true
    @UI.ExcludeFromNavigationContext : true
    @Core.Immutable : true
    @Core.Computed : true
    @Common.Label : 'Created By'
    createdBy : String(255);
    @odata.Precision : 7
    @odata.Type : 'Edm.DateTimeOffset'
    @UI.HiddenFilter : true
    @UI.ExcludeFromNavigationContext : true
    @Core.Computed : true
    @Common.Label : 'Changed On'
    modifiedAt : Timestamp;
    /** User's unique ID */
    @UI.HiddenFilter : true
    @UI.ExcludeFromNavigationContext : true
    @Core.Computed : true
    @Common.Label : 'Changed By'
    modifiedBy : String(255);
    key ID : String(10) not null;
    Name : String(80);
    Email : String(100);
    Phone : String(20);
    Status : String(1);
    CompanyCode : String(4);
    Address : rsa_samples_customers_Address;
    ValidFrom : Date;
    ValidTo : Date;
    CreditLimit : Decimal(15, 2);
    GroupID : String(4);
    group : Association to one CustomerGroups on group.ID = GroupID;
    contacts : Composition of many Contacts {  };
  } actions {
    action block() returns Customers;
    function creditCheck(
      Amount : Decimal(15, 2) default null
    ) returns Boolean;
  };

  @cds.external : true
  @cds.persistence.skip : true
  entity CustomerGroups {
    key ID : String(4) not null;
    Name : String(40);
    Region : String(4);
  };

  @cds.external : true
  @cds.persistence.skip : true
  entity Contacts {
    key ID : String(10) not null;
    CustomerID : String(10);
    Name : String(80);
    Email : String(100);
    Role : String(20);
    customer : Association to one Customers on customer.ID = CustomerID;
  };

  @cds.external : true
  type rsa_samples_customers_Address {
    Street : String(60);
    City : String(40);
    PostalCode : String(10);
    Country : String(3);
  };
};

