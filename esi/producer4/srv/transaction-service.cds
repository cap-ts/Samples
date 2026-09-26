using {esi.samples.producer4.Transaction} from '../db/schema';

service TransactionService {
    entity TransactionSet as projection on Transaction;
}
