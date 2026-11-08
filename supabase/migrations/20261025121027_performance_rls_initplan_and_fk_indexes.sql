-- A) Wrap auth.uid()/auth.jwt()/auth.role() in (select ...) so it is evaluated once per query, not per row
DO $$
DECLARE
  r record;
  new_qual text;
  new_chk  text;
  stmt text;
BEGIN
  FOR r IN
    SELECT schemaname, tablename, policyname, qual, with_check
    FROM pg_policies
    WHERE schemaname IN ('identity','core','catalog','orders','payments','inventory','loyalty','marketing','engagement','ai','subscriptions','public')
      AND (coalesce(qual,'') ~* 'auth\.(uid|jwt|role)\(\)' OR coalesce(with_check,'') ~* 'auth\.(uid|jwt|role)\(\)')
  LOOP
    new_qual := regexp_replace(r.qual,       '(?<!select )auth\.(uid|jwt|role)\(\)', '(select auth.\1())', 'gi');
    new_chk  := regexp_replace(r.with_check, '(?<!select )auth\.(uid|jwt|role)\(\)', '(select auth.\1())', 'gi');
    IF new_qual IS NOT DISTINCT FROM r.qual AND new_chk IS NOT DISTINCT FROM r.with_check THEN
      CONTINUE;
    END IF;
    stmt := format('ALTER POLICY %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
    IF new_qual IS NOT NULL THEN stmt := stmt || ' USING (' || new_qual || ')'; END IF;
    IF new_chk  IS NOT NULL THEN stmt := stmt || ' WITH CHECK (' || new_chk || ')'; END IF;
    EXECUTE stmt;
  END LOOP;
END $$;

-- B) Covering indexes for every foreign key that lacks one (tables are tiny now, so plain CREATE INDEX is instant)
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT c.conrelid::regclass AS tbl,
           cl.relname AS relname,
           (SELECT string_agg(quote_ident(a.attname), ', ' ORDER BY k.ord)
              FROM unnest(c.conkey) WITH ORDINALITY k(attnum, ord)
              JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum) AS cols,
           (SELECT string_agg(a.attname, '_' ORDER BY k.ord)
              FROM unnest(c.conkey) WITH ORDINALITY k(attnum, ord)
              JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum) AS colnames
    FROM pg_constraint c
    JOIN pg_class cl ON cl.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = cl.relnamespace
    WHERE c.contype = 'f'
      AND n.nspname IN ('identity','core','catalog','orders','payments','inventory','loyalty','marketing','engagement','ai','subscriptions','public')
      AND NOT EXISTS (
        SELECT 1 FROM pg_index i
        WHERE i.indrelid = c.conrelid
          AND (string_to_array(i.indkey::text, ' ')::int2[])[1:array_length(c.conkey,1)] = c.conkey
      )
  LOOP
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON %s (%s)',
                   left('ix_' || r.relname || '_' || r.colnames || '_fk', 63), r.tbl, r.cols);
  END LOOP;
END $$;
