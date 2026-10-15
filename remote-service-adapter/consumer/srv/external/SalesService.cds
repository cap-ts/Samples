/* checksum : 099171aa602d0e670610f3882c87c259 */
@cds.external : true
service SalesService {
  @cds.external : true
  action upsertStatus(
    ID : String(10),
    Status : String(1)
  ) returns Orders;

  @cds.external : true
  @cds.persistence.skip : true
  entity Orders {
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
    OrderName : String(60);
    Kind : String(3);
    Status : String(1);
    Customer : String(10);
    Amount : Decimal(15, 2);
    Currency : String(3);
    @odata.Precision : 0
    @odata.Type : 'Edm.DateTimeOffset'
    OrderDate : DateTime;
    Note : String(40);
    Channel : String(10);
    CustomerText : String(60);
    items : Association to many Items {  };
  } actions {
    action cancel() returns Orders;
    action release() returns Orders;
    function printForm() returns String;
  };

  @cds.external : true
  @cds.persistence.skip : true
  entity Items {
    key ID : String(10) not null;
    OrderID : String(10);
    Product : String(10);
    Quantity : Integer;
    Price : Decimal(15, 2);
    Status : String(10);
  };

  @cds.external : true
  @cds.persistence.skip : true
  entity Projects {
    key ProjectID : String(10) not null;
    Name : String(60);
    Customer : String(10);
    StartDate : Date;
    EndDate : Date;
  };

  @cds.external : true
  @cds.persistence.skip : true
  entity Packages {
    key ProjectID : String(10) not null;
    key PackageID : String(10) not null;
    Description : String(60);
  };

  @cds.external : true
  @cds.persistence.skip : true
  entity Bookings {
    key ID : String(10) not null;
    Customer : String(10);
    Project : String(10);
    Day : Date;
    Hours : Decimal(5, 2);
    CustomerText : String(20);
  };

  @cds.external : true
  @cds.persistence.skip : true
  entity Entries {
    key CompanyCode : String(4) not null;
    key DocNo : String(10) not null;
    Note : String(60);
    Released : Boolean;
    Op : String(1);
  };
};

