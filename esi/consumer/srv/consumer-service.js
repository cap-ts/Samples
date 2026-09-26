const cds = require('@sap/cds');
const { esi } = require('esi-cap');

module.exports = cds.service.impl(async function () {
    const { MeshedUpTransactionSet } = this.entities;

    // Restrict DELETE operation
    this.before('DELETE', MeshedUpTransactionSet, async (req) => {
        return req.reject(403, 'Deleting Transactions is not allowed.');
    });

    // Restrict UPDATE operation
    this.before('UPDATE', MeshedUpTransactionSet, async (req) => {
        return req.reject(403, 'Updating Transaction records is restricted.');
    });

    return await esi.impl.RemoteService(this);
});
