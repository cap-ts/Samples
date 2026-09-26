using { CustomerService.CustomerSet } from './external/CustomerService';
using { ProductService.ProductSet } from './external/ProductService';
using { EmployeeService.EmployeeSet } from './external/EmployeeService';
using { TransactionService.TransactionSet } from './external/TransactionService';

service ConsumerService {
    entity MeshedUpTransactionSet as projection on TransactionSet {
        *,
        _Customer: Association to one CustomerSet on _Customer.ID = $self.customer,
        _Product: Association to one ProductSet on _Product.ID = $self.product,
        _Employee: Association to one EmployeeSet on _Employee.ID = $self.employee
    };
}
