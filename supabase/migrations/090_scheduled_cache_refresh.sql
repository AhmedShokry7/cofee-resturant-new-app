-- 090_scheduled_cache_refresh.sql
--
-- تفعيل إضافة pg_cron وجدولة مهمة لتحديث العروض المادية (materialized views)
-- تلقائياً كل ساعة، لتقليل حمل الاستعلامات المباشرة على جداول الكتالوج الكبيرة.
--
-- ملاحظة: pg_cron متوفرة في مشاريع Supabase المدفوعة (Pro فما فوق). في المشاريع
-- المجانية (Free tier) يجب تحديث العروض يدوياً عبر استدعاء
-- public.refresh_materialized_caches() من لوحة SQL Editor أو عبر Cron خارجي.

create extension if not exists pg_cron;

-- جدولة تحديث العروض المادية كل ساعة في الدقيقة 0
select cron.schedule(
  'refresh-materialized-caches',
  '0 * * * *',
  $$select public.refresh_materialized_caches();$$
);

-- سجل الوظائف المجدولة للمراجعة
select jobid, jobname, schedule, command from cron.job;

notify pgrst, 'reload schema';
