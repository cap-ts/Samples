using { esi.samples.producer2.Product } from '../db/schema';

service ProductService {
    entity ProductSet as projection on Product;
}
