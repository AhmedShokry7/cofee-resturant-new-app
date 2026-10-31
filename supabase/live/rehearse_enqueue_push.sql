-- Rehearsal only: proves engagement.enqueue_push() now finds the webhook
-- configuration. The transaction always rolls back, so the queued pg_net
-- request is discarded and no push leaves the project.
begin;

select engagement.enqueue_push(
  (select row(
     null::uuid,                    -- id
     '00000000-0000-0000-0000-000000000000'::uuid, -- user_id
     'system',                      -- type
     'اختبار',                      -- title_ar
     'test',                        -- title_en
     'اختبار',                      -- body_ar
     'test',                        -- body_en
     '{}'::jsonb,                   -- payload
     null::text,                    -- related_entity_type
     null::uuid,                    -- related_entity_id
     false,                         -- is_read
     null::timestamptz,             -- read_at
     null::text,                    -- dedupe_key
     now(),                         -- created_at
     null::uuid,                    -- campaign_id
     null::uuid                     -- created_by
   )::engagement.notifications)
) as enqueued;

rollback;
