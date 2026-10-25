import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { verificationOf, canProgress, matchesStatus, reportStatus } from '../src/reportVerification.js';
assert.equal(canProgress({severity:'High', status:'received'}), false);
assert.equal(canProgress({verification_status:'rejected'}), false);
assert.equal(canProgress({verification_status:'needs_information'}), false);
assert.equal(canProgress({verification_status:'verified'}), true);
assert.equal(verificationOf({status:'assigned'}), 'verified');
const source = fs.readFileSync(new URL('../src/CitizenReportsPage.jsx', import.meta.url), 'utf8');
const handlers = source.slice(source.indexOf('  const handleReview ='), source.indexOf('  const residentName ='));
const writes = [], errors = [];
const report = {id:'test', status:'received', severity:'High', verification_status:'pending'};
let fail = false;
const context = { savingId:null, reports:[report], selectedReport:report, canProgress,
 setSavingId(){}, setError(error){ errors.push(error); },
 async saveReport(item, updates) { if(fail) throw new Error('Failed save'); writes.push(updates); },
};
vm.createContext(context);
vm.runInContext(handlers + '\nglobalThis.review = handleReview; globalThis.progress = handleStatusChange;', context);
await context.progress('test', 'resolved');
assert.equal(writes.length, 0);
assert.match(errors.at(-1), /verify/i);
await assert.rejects(context.review(report, 'rejected', '', 'High'), /reason/);
await assert.rejects(context.review(report, 'verified', '', ''), /severity/);
await context.review(report, 'verified', 'Contacted resident', 'Medium');
assert.equal(writes.at(-1).status, 'assigned');
assert.equal(writes.at(-1).severity, 'Medium');
await context.review(report, 'rejected', 'Confirmed duplicate', 'High');
assert.equal(writes.at(-1).verification_status, 'rejected');
assert.equal(writes.at(-1).status, 'received');
await context.review(report, 'needs_information', 'Please confirm the location', 'High');
assert.equal(writes.at(-1).verification_status, 'needs_information');
fail=true;
await assert.rejects(context.review(report, 'verified', '', 'High'), /Failed save/);
console.log('Admin verification regression checks passed.');

const rejected = {status:'received', verification_status:'rejected'};
assert.equal(reportStatus(rejected), 'rejected');
assert.equal(matchesStatus(rejected, 'rejected'), true);
assert.equal(matchesStatus(rejected, 'received'), false);
assert.equal(matchesStatus(rejected, 'all'), true);
assert.equal(matchesStatus({status:'closed', verification_status:'verified'}, 'resolved'), true);
assert.equal(matchesStatus({status:'closed', verification_status:'verified'}, 'rejected'), false);
console.log('Rejected filters and legacy closed-report regression checks passed.');

assert.equal(matchesStatus({status:'assigned'}, 'active'), true);
assert.equal(matchesStatus({status:'in_progress'}, 'active'), true);
assert.equal(matchesStatus({status:'received'}, 'active'), false);
assert.equal(matchesStatus({status:'resolved'}, 'active'), false);
assert.equal(matchesStatus({status:'assigned', verification_status:'rejected'}, 'active'), false);
console.log('Summary-card grouped progress checks passed.');

const urgentReports = [
 {severity:'High', status:'received', verification_status:'pending'},
 {severity:'High', status:'assigned', verification_status:'verified'},
 {severity:'High', status:'in_progress', verification_status:'verified'},
 {severity:'High', status:'resolved', verification_status:'verified'},
 {severity:'High', status:'closed', verification_status:'verified'},
 {severity:'High', status:'received', verification_status:'rejected'},
 {severity:'Low', status:'received', verification_status:'pending'},
];
const highCount = rows => rows.filter(r => r.severity === 'High' && matchesStatus(r, 'outstanding')).length;
assert.equal(highCount(urgentReports), 3);
assert.equal(highCount(urgentReports.map((r,i)=>i===0 ? {...r, status:'resolved'} : r)), 2);
assert.equal(highCount(urgentReports.map((r,i)=>i===0 ? {...r, verification_status:'rejected'} : r)), 2);
assert.equal(matchesStatus({status:'received', verification_status:'pending'}, 'outstanding'), true);
console.log('High-priority counts exclude resolved, closed and rejected reports and decrease after decisions.');
