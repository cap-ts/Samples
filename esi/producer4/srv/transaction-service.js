const cds = require('@sap/cds');

module.exports = cds.service.impl(function () {
    const { TransactionSet } = this.entities;

    // Restrict DELETE operation
    this.before('DELETE', TransactionSet, async (req) => {
        return req.reject(403, 'Deleting Transactions is not allowed.');
    });

    // Restrict UPDATE operation
    this.before('UPDATE', TransactionSet, async (req) => {
        return req.reject(403, 'Updating Transaction records is restricted.');
    });
});
