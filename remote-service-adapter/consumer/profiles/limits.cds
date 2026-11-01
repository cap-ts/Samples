/**
 * Loaded in the profile `limits` only (`npm run watch:limits`), through `cds.requires.[limits].LimitsProfile.model` in
 * package.json; outside srv/, so no other profile loads it.
 *
 * `@remote.warmUp.enabled: false` switches the warm-up of a whole entity off without touching its annotation in
 * srv/overview-service.cds: in this profile the log has no "warm-up OverviewService.ProductFinder" line, and the
 * search copy of ProductFinder is filled by the first `$search` instead (`search: 'read'`).
 */
using { OverviewService } from '../srv/overview-service';

annotate OverviewService.ProductFinder with @remote.warmUp.enabled: false;
