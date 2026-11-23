# Product Rules

- Preserve admin permissions and business workflows.
- Do not weaken authorization.
- Do not remove features.
- Keep Supabase schema unchanged except for approved Supabase changes:
  a schema change is allowed only after separate explicit approval of the
  full SQL, risks, rollback plan, isolated/non-production tests, and target
  phase. Never apply SQL to production without a separate production
  approval. Never execute db push, db reset, or manual ledger edits without
  that approval.
- Modify admin_app only.