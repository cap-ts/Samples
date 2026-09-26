using { esi.samples.producer1.Customer } from '../db/schema';

service CustomerService {
    entity CustomerSet as projection on Customer;
}
