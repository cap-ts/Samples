const cds = require('@sap/cds');

module.exports = cds.service.impl(function () {
    const { CustomerSet } = this.entities;

    // Restrict DELETE operation
    this.before('DELETE', CustomerSet, async (req) => {
        return req.reject(403, 'Deleting customers is not allowed.');
    });

    // Restrict UPDATE operation
    this.before('UPDATE', CustomerSet, async (req) => {
        return req.reject(403, 'Updating customer records is restricted.');
    });
});
