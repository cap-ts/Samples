const cds = require('@sap/cds');

module.exports = cds.service.impl(function () {
    const { EmployeeSet } = this.entities;

    // Restrict DELETE operation
    this.before('DELETE', EmployeeSet, async (req) => {
        return req.reject(403, 'Deleting Employees is not allowed.');
    });

    // Restrict UPDATE operation
    this.before('UPDATE', EmployeeSet, async (req) => {
        return req.reject(403, 'Updating Employee records is restricted.');
    });
});
