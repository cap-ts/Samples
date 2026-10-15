const cds = require('@sap/cds');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');

/**
 * Transport security for every route, the /soap routes of @cap-ts/soap-adapter included. They are mounted on
 * `served`, after `bootstrap`, so middleware registered here wraps them.
 */
cds.on('bootstrap', (app) => {
    app.use(helmet());
    // CORS: only the origins listed in CORS_ALLOWED_ORIGINS (comma separated); none by default
    app.use(cors({ origin: process.env.CORS_ALLOWED_ORIGINS?.split(',') ?? false, credentials: true }));
    app.use('/soap', rateLimit({ windowMs: 60_000, max: 120, standardHeaders: true, legacyHeaders: false }));
});

module.exports = cds.server;
