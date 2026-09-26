const cds = require('@sap/cds');

module.exports = cds.service.impl(function () {
    const { ProductSet } = this.entities;

    // Restrict DELETE operation
    this.before('DELETE', ProductSet, async (req) => {
        return req.reject(403, 'Deleting Products is not allowed.');
    });

    // Restrict UPDATE operation
    this.before('UPDATE', ProductSet, async (req) => {
        return req.reject(403, 'Updating Product records is restricted.');
    });
});
