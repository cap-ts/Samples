/* checksum : 7b9aeb7779d24c168988f5a0a9ef4afd */
@cds.external : true
@m.IsDefaultEntityContainer : 'true'
service ProductService {
  @cds.external : true
  @cds.persistence.skip : true
  entity Products {
    key ID : String(10) not null;
    @odata.Type : 'Edm.DateTimeOffset'
    @odata.Precision : 7
    createdAt : Timestamp;
    createdBy : String(255);
    @odata.Type : 'Edm.DateTimeOffset'
    @odata.Precision : 7
    modifiedAt : Timestamp;
    modifiedBy : String(255);
    Name : String(60);
    Description : String(200);
    category_ID : String(4);
    Price : Decimal(15, 2);
    Currency : String(3);
    Stock : Integer;
    Blocked : Boolean;
    @odata.Type : 'Edm.DateTimeOffset'
    ReleasedAt : DateTime;
    @sap.filterable : 'false'
    InternalNote : String(100);
    category : Association to Categories {  };
  };

  @cds.external : true
  @cds.persistence.skip : true
  entity Categories {
    key ID : String(4) not null;
    Name : String(40);
  };
};

