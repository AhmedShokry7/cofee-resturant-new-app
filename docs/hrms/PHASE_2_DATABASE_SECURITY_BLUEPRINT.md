# Phase 2 — HR Database and Security Blueprint

**Status:** Draft for review. Design only; no migration or database change is authorized by this document.

## 1. Scope and evidence

This blueprint follows the approved Phase 1 assumptions: one company, central and branch-scoped administration, Saudi policy configuration, and no separate employee portal in the initial UI scope. It is based on the repository migrations plus a live, read-only PostgreSQL metadata inspection. No employee names, salary rows, or other person-level records were read.

The connected database reported PostgreSQL 17.11 and `transaction_read_only = on`. Its migration ledger contains HR migrations 212–217 and 240–242. The connection used an environment variable named for staging; aggregate row counts from that environment are not treated as production facts.

The repository has pre-existing local changes in the visual editor and an untracked migration 245. They are outside this blueprint and must be preserved.

## 2. Current database boundary

### Reuse without duplication

- `identity.staff_members` is the login identity/account.
- `identity.staff_roles` remains the branch assignment and permission-scope source. A null `branch_id` represents all-branch scope.
- `hr.employment_records` is the employment relationship record linked by `staff_id`.
- Existing `hr.*` tables and public RPCs remain the source for attendance, schedules, leave, compensation, payroll, advances, adjustments, discrepancies, and offboarding.
- `identity.audit_log` remains the shared audit stream.

Do not add a second employee identity, login-to-employee link, or branch assignment table.

### Live security observations

The live schema has 17 HR tables, all with RLS enabled. There are no HR table policies; `anon` and `authenticated` have no `USAGE` on the `hr` schema and no direct HR table grants. The 55 public functions whose names match HR are security definers with empty `search_path`; execution is granted to `authenticated` and denied to `anon`. This preserves the existing RPC-only access model.

RLS is not forced on HR tables. This is consistent with the current design only because client roles cannot access the schema or tables directly and security-definer RPCs enforce the caller’s permissions and scope. New HR access must keep those RPC checks; route visibility in Flutter is not an authorization boundary.

No HR document bucket or HR storage policy exists. The only buckets found are private avatars and public product images. Do not place contracts or personnel documents in either bucket.

### Actual payroll shape

`hr.payroll_runs` has a unique key on `(period_year, period_month)` and no branch scope. `hr.payroll_statements` has a unique key on `(run_id, staff_id)` and no branch allocation. Preview, generation, and approval require all-branch scope. The live schema matches this single company-wide payroll model.

No general ledger, chart-of-accounts, journal, accounts-payable, or accounting reconciliation tables were found. The `payments` schema covers order tenders and POS drawer operations, not general accounting.

## 3. Design decisions to retain

1. Keep one company scope; do not introduce `tenant_id` or a duplicate legal entity model in this deployment.
2. Keep branch access server-enforced through existing identity helpers and `hr.can_access_staff`.
3. Keep the existing RPC-only boundary for HR tables. New data access must use reviewed RPCs with explicit grants, permission checks, branch/employee checks, and audit writes.
4. Preserve existing history. Avoid destructive table rewrites, cascades that erase financial records, and silent overwrites of employment history.
5. Treat calculation, payroll approval, payment evidence, accounting posting, and reconciliation as distinct states/actions.
6. Keep Saudi rules configurable, versioned, effective-dated, and attributable to a reviewed source. Do not hard-code statutory rates or formulas before legal review.

## 4. Payroll scope decision

**Recommendation for this deployment:** retain one monthly company-wide run and let authorized branch users perform only the branch-scoped HR work already supported by server checks. A central payroll operator calculates and approves the consolidated run. Branch views must not imply a branch-only payroll calculation if the RPC returns company-wide amounts.

The Phase 1 navigation proposal mentioned selecting a branch scope for a payroll period. That would change the current model and must be explicitly chosen before a migration is designed. A true branch-specific run needs all of the following:

- A run scope model and uniqueness that permits multiple branch runs without permitting duplicate staff-period pay.
- A payroll-period allocation snapshot for each staff member, independent of mutable `staff_roles` after calculation.
- An approved rule for employees scheduled or assigned to multiple branches and a clear company-wide consolidation report.
- Branch authorization on preview, generation, statements, approval, payment evidence, corrections, and reporting.
- Accounting cost-center allocation that reconciles to the single employee net-pay obligation.

Do not derive historical payroll allocation from current role assignments or create duplicate statements for the same employee and period. Until this choice is approved, keep the database design on the current company-wide model.

## 5. Additive entities to design only when their workflow is approved

These are conceptual candidates, not migration instructions. Before any DDL, compare them with the live schema and current data again.

| Capability | Candidate model | Design constraint |
|---|---|---|
| Organization | Hierarchical organizational units; positions/job definitions; effective-dated employee assignment | Replace free-text department/title gradually. Preserve the original strings and map existing rows before enforcing references. Do not use `staff_roles` as the job hierarchy. |
| Contracts | Contract records and append-only amendments/renewals/termination events | Link to the existing employment record. Keep the signed file in private storage and preserve prior contract versions. |
| Personnel documents | Document type and metadata rows with object key, owner staff id, branch scope where applicable, dates, classification, and audit data | Private bucket, server-side path validation, least-privilege read/write/download, short-lived signed URLs, retention policy, no public URLs. Never store document contents in HR audit JSON. |
| Recruitment | Requisitions, candidates, interview stages/evaluations, offers | Candidate identity is not an identity staff account. Conversion must link/create one staff account without duplicating the person. |
| Onboarding | Onboarding case and task rows linked to employment, owner, due date, and completion evidence | Reuse existing offboarding model patterns where appropriate; do not create placeholder pages/tables. |
| Performance | Review cycle, goals, ratings, reviewer/self-review records, improvement plans | Separate private self-review/manager review permissions and immutable submitted snapshots. |
| Training | Course/program, enrollment, attendance/completion, certificate metadata | Certificate access follows personnel-document policy. |
| Disciplinary | Case, investigation events, employee response, decisions, appeal events | Restrict case visibility separately from authority to issue or approve a decision; audit every transition. |
| Policy versions | Jurisdiction/policy family, version, effective range, source reference, reviewer, approval, configurable values | Do not make an unreviewed policy version active; never rewrite the values used by a historical payroll calculation. |
| Accounting | No reuse candidate exists today | Design a chart of accounts and balanced journal model as a separate accounting blueprint before linking HR. |

Do not add a generic approval engine just to normalize current workflows. Existing HR requests already carry reviewer/status fields. Add configurable multi-step approval policy data only after the desired approval paths and delegation rules are approved and mapped against those workflows.

## 6. Accounting integration boundary

A later accounting design must first specify chart of accounts, journal header and balanced lines, period controls, branch/cost-center dimensions, external payment evidence, and reconciliation ownership.

The HR-to-accounting handoff should be server-side and idempotent, keyed to a payroll run and calculation revision. Approved posting is immutable. A reversal creates a linked reversing journal and a corrected posting; it does not edit posted lines. Actual wage payment requires its own evidence/reference and settlement against the payroll liability. An HR status change to `paid` is not proof of a transfer or accounting reconciliation.

Advances also need their own accounting lifecycle if integrated: disbursement, receivable balance, payroll recovery, and repayment/reversal must reconcile without deleting historical events.

## 7. Workflow and audit requirements

For any new sensitive workflow, define requester, reviewer/approver, state transitions, rejection reason, comments, timestamps, self-approval rule, branch scope, cancellation behavior, and retry/idempotency before implementation. Record the event through `identity.audit()` with branch context and concise before/after values. Avoid storing employee document contents, credentials, or unnecessary sensitive data in audit payloads.

Keep the creator, approver, and payment recorder separate for payroll. Review whether the current owner exception is acceptable for this policy before reusing it in a new workflow.

## 8. Acceptance and security test plan

Run these against a non-production database after each approved implementation phase; this blueprint does not claim they have been run:

- Central HR can access all branches; a branch-limited manager cannot read or mutate another branch through either UI or RPC.
- An employee can access only self-service records permitted by the product scope; no employee can enumerate other staff.
- No `anon` role can execute HR RPCs or access HR tables/storage.
- HR documents reject guessed paths and unauthorized read, update, delete, or download; valid signed URLs expire.
- Salary/compensation visibility is denied without the specific server-side permission.
- Payroll preparer cannot approve their run; approval and payment recording are separate actions.
- Retrying a payroll/accounting post cannot duplicate a statement, deduction, or journal.
- Corrections after a closed period preserve the prior statement and produce an auditable correction/reversal.
- Multi-branch employment cannot be paid twice if branch payroll is later approved.
- Offboarding preserves employment, payroll, attendance, and audit history while access suspension remains a separately authorized action.
- Existing SQL suites remain green: HR workforce, leave/attendance, payroll workflow, offboarding, finance exceptions, and scoped cancellation.

## 9. Phase 2 exit gate

Before implementing migrations or moving into dependent phases:

- Approve or amend this blueprint.
- Decide whether payroll remains one company-wide monthly run (recommended) or becomes branch-scoped with explicit allocation rules.
- Confirm the live schema environment used for metadata review is the intended deployment target before relying on its data shape.
- Approve any proposed migration separately, with a rollback/recovery plan and tests, before applying it.

No database changes are included in this draft.

## 10. Source references

- `supabase/migrations/005_core_01_brand_branches.sql`
- `supabase/migrations/018_rls_00_helpers.sql`
- `supabase/migrations/212_hr_workforce.sql`
- `supabase/migrations/213_hr_advance_cancel_staff_scope.sql` through `217_hr_finance_exceptions_report.sql`
- `supabase/migrations/240_hr_leave_attendance.sql` through `242_hr_payroll_workflow.sql`
- `supabase/migrations/084_customer_profile_avatars.sql`, `208_avatars_staff_signed_read.sql`, `209_staff_profile_edit_and_avatar.sql`
- `supabase/tests/hr_workforce_test.sql`, `hr_leave_attendance_test.sql`, `hr_payroll_workflow_test.sql`, `hr_offboarding_test.sql`, `hr_finance_exceptions_test.sql`, `hr_advance_cancel_scope_test.sql`, `hr_leave_cancel_scope_test.sql`
