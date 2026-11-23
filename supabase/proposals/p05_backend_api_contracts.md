# P0.6-B Backend API Contracts — Marketing Hub

Single café. All Marketing Hub tables live in `marketing` schema.
All admin RPCs are `SECURITY DEFINER, set search_path=''`, check
`identity.has_permission(...)`, and audit via `identity.audit`.
Branch scope: campaigns are café-wide (legacy rule preserved); branch
filtering remains operational scope for orders/payments, not customer data.

## Customer APIs (authenticated, no staff permission required)

| RPC | Inputs | Output | Read/Write |
|---|---|---|---|
| `public.set_my_marketing_consent(p_channel, p_purpose, p_granted)` | channel (push/email), purpose (promotions/offers/loyalty_marketing), granted | event id (uuid) | Write (own consent only; fixed source `in_app_settings`, fixed `auth.uid()`) |
| `public.my_marketing_consents()` | — | jsonb array of {channel, purpose, status, updated_at} | Read (own only) |

Errors: `42501` unauthenticated, `22023` invalid channel/purpose.

## Admin APIs (staff permission required)

| RPC | Permission | Inputs | Output | Read/Write |
|---|---|---|---|---|
| `marketing.list_campaigns()` | marketing.read | — | jsonb array of campaign + recipient/sent totals | Read |
| `marketing.get_campaign(p_campaign_id)` | marketing.read | campaign uuid | jsonb campaign + current/approved version + executions | Read |
| `marketing.create_campaign(p_name, p_channel, p_purpose, p_segment_id?)` | marketing.create | name, channel, purpose, segment? | campaign uuid | Write |
| `marketing.create_campaign_version(p_campaign_id, titles/bodies, payload?, image?, destination?)` | marketing.create | campaign uuid + content | version uuid | Write (new draft; returns campaign to draft) |
| `marketing.submit_campaign_for_review(p_campaign_id)` | marketing.create | campaign uuid | void | Write (draft→pending_review) |
| `marketing.approve_campaign(p_campaign_id)` | marketing.review | campaign uuid | void | Write (pending_review→approved; creator ≠ approver) |
| `marketing.return_campaign_to_draft(p_campaign_id, p_reason?)` | marketing.review | campaign uuid | void | Write (pending_review→draft) |
| `marketing.schedule_campaign(p_campaign_id, p_scheduled_for)` | marketing.schedule | campaign uuid, future timestamp | execution uuid | Write (idempotent per approved version; freezes snapshot + recipients) |
| `marketing.cancel_campaign(p_campaign_id)` | marketing.send | campaign uuid | void | Write (pre-processing only) |
| `marketing.pause_execution(p_execution_id)` | marketing.send | execution uuid | void | Write (running→paused) |
| `marketing.resume_execution(p_execution_id)` | marketing.send | execution uuid | void | Write (paused→queued) |
| `marketing.list_campaign_recipients(p_execution_id, p_limit?)` | marketing.read | execution uuid | jsonb array | Read |
| `marketing.list_campaign_attempts(p_execution_id)` | marketing.read | execution uuid | jsonb array | Read |
| `public.admin_marketing_consents(p_user_id)` | marketing.consent.read | customer uuid | jsonb array of states | Read |

Validation errors: `42501` missing permission / self-approval / locked campaign,
`22023` invalid payload or illegal transition, `P0002` not found.
Failure states: unauthorized, missing session, RPC absent (migration not
applied yet). Admin UI must show "unavailable — backend not applied" for
`PGRST202` instead of fabricating data.

## Internal Worker APIs (service_role only — never granted to authenticated)

| Function | Caller | Input | Effect |
|---|---|---|---|
| `marketing.run_campaign_executions(p_limit?)` | service_role / scheduler | limit (default 200) | Claims executions (SKIP LOCKED, 5-min lease), re-checks consent/reachability, inserts engagement.notifications + attempts |
| `marketing.record_consent_event_trusted(...)` | service_role / trusted paths | user/channel/purpose/action/source | Appends consent event + monotonic state |
| `marketing.is_marketing_deliverable_internal(...)` | service_role / worker | user/channel/purpose | bool (consent + channel enabled + reachability) |

## Reused legacy APIs (unchanged)

`public.admin_send_notification`, `public.admin_notifications_filtered`,
`public.admin_notification_metrics`, `public.admin_notification_audience`,
`public.admin_set_notification_read`, `public.admin_delete_notification`,
`public.mark_notifications_read`, `public.delete_notifications` — immediate
admin send path and customer read paths. Not replaced; new engine is additive.

## RBAC seed (proposal)

| Role | Permissions |
|---|---|
| owner | implicit (all) |
| manager | marketing.read/create/review/schedule/send, marketing.consent.read |
| branch_manager | marketing.read |
| cashier, staff | none |
| (owner-only) | marketing.consent.write, admin.role.write — guarded inside `admin_set_role_permission` replacement |
