using { esi.samples.producer3.Employee } from '../db/schema';

service EmployeeService {
    entity EmployeeSet as projection on Employee;
}
