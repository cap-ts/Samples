/**
 * Associations between the imported models.
 *
 * The navigation properties of an imported EDMX have no ON condition. Each association here is declared with its
 * ON condition (or foreign key), which is what $expand, path columns, filters through associations, exists flags,
 * write rules and deep writes of @cap-ts/remote-service-adapter join on. Several cross system boundaries: an
 * order (producer-sales) points to its customer (producer-customers), an item to its product (producer-products), a customer group to a
 * region of the consumer's own database.
 */
using { CustomerService as customers } from './CustomerService';
using { ProductService as products } from './ProductService';
using { SalesService as sales } from './SalesService';
using { PartnerDirectory as partners } from './PartnerDirectory';
using { rsa.samples.consumer as db } from '../../db/schema';

extend customers.Customers with {
    _Group    : Association to one customers.CustomerGroups on _Group.ID = GroupID;
    _Contacts : Association to many customers.Contacts on _Contacts.CustomerID = ID;
};

extend customers.Contacts with {
    _Customer : Association to one customers.Customers on _Customer.ID = CustomerID;
};

extend customers.CustomerGroups with {
    _Region : Association to one db.Regions on _Region.code = Region;
};

extend products.Products with {
    _Category : Association to one products.Categories on _Category.ID = category_ID;
};

extend sales.Orders with {
    _Customer : Association to one customers.Customers on _Customer.ID = Customer;
    _Items    : Association to many sales.Items on _Items.OrderID = ID;
};

extend sales.Items with {
    _Order   : Association to one sales.Orders on _Order.ID = OrderID;
    _Product : Association to one products.Products on _Product.ID = Product;
};

extend partners.Partners with {
    _Customer : Association to one customers.Customers on _Customer.ID = Customer;
};

/** Page size used when every row of the source is read (GROUP BY, DISTINCT, filters evaluated in memory). */
annotate sales.Items with @cds.query.limit: { default: 1000, max: 5000 };
