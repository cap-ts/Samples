using { rsa.samples.products as db } from '../db/schema';

/** Served as OData V2 at /odata/v2/product (and as OData V4 at /odata/v4/product). */
service ProductService {
    entity Products   as projection on db.Products;
    entity Categories as projection on db.Categories;
}
