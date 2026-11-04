-- supabase/migrations/227_app_design_theme.sql
--
-- WHY THIS EXISTS
--
-- 226 froze the document at `schema_version = 1` and said nothing about shape:
-- the builder only moved sections around. The panel now carries a design theme
-- - ten colour roles, a text scale, a radius scale - inside the same document,
-- because a published colour without its layout is half a screen and a rollback
-- has to undo both together. That is schema version 2.
--
-- Two things have to change on the server and nothing else:
--
--   * `core.app_design_is_valid` accepts version 1 OR 2, and validates the
--     optional `theme` object when it is there.
--   * the same function refuses a `theme` inside a version-1 document: the
--     stamp and the payload may not disagree about what the document holds.
--
-- WHY THE OLD STAMP STAYS VALID
--
-- Nothing was published under 226 yet - `core.app_settings` holds no
-- `app_design_*` row at all - but a draft or a version written as version 1 is
-- still readable: its theme is the neutral one, which serialises to no key. An
-- installed customer build that only knows version 1 leaves a version-2 document
-- alone and keeps the last design it could draw, which is what the stamp is for.
--
-- WHY THE THEME IS CHECKED HERE AND NOT ONLY IN THE PANEL
--
-- The panel builds every value from enums and a hex field, but the RPC takes
-- whatever jsonb it is given. A theme with an unknown role, a colour that is
-- not a colour, or a scale name no renderer maps to a number would reach the
-- customer as a screen that cannot be drawn - so the server decides what a
-- legal theme is, and the role and scale lists live here as the contract the
-- Flutter side is written against.
--
-- WHAT DOES NOT CHANGE
--
-- No table, no column, no policy, no permission, no new RPC. The document is
-- still two rows in `core.app_settings` and a version list in
-- `core.app_design_versions`; publish, draft and restore keep storing the
-- stamp they are handed. Widget types remain the panel's business: 226
-- deliberately does not name them in SQL and this migration does not start.

-- ---------------------------------------------------------------------------
-- 1. Structure check, now theme-aware.
-- ---------------------------------------------------------------------------
create or replace function core.app_design_is_valid(p_document jsonb)
returns text
language plpgsql
immutable
set search_path = ''
as $fn$
declare
  v_page        jsonb;
  v_check       jsonb;
  v_ids         jsonb := '[]'::jsonb;
  v_version     numeric;
  v_theme       jsonb;
begin
  if jsonb_typeof(p_document) <> 'object' then
    return 'document';
  end if;
  -- النسختان اللتان يعرفهما المحرّر الحيّ: 1 بلا شكل عام، و2 معها طبقة theme
  -- اختيارية. أعلى من هذا تركها الهاتف على ما قبلها ولا معنى لقبولها هنا.
  if jsonb_typeof(p_document -> 'schema_version') <> 'number' then
    return 'schema_version';
  end if;
  v_version := (p_document ->> 'schema_version')::numeric;
  if v_version not in (1, 2) then
    return 'schema_version';
  end if;
  if jsonb_typeof(p_document -> 'pages') <> 'array'
     or jsonb_array_length(p_document -> 'pages') = 0 then
    return 'pages';
  end if;
  if jsonb_array_length(p_document -> 'pages') > 7 then
    return 'page_count';
  end if;
  -- الشاشات التي يفتحها الهاتف لا تزيد. قائمة ثابتة لا سجل تحرير: صفحة لا
  -- يعرفها التطبيق لا تُعرض ولا تُحرَّر.
  if exists (
    select 1
      from jsonb_array_elements(p_document -> 'pages') p
     where coalesce(p ->> 'page', '') not in
       ('home', 'categories', 'search', 'product_details', 'cart',
        'favourites', 'settings')
  ) then
    return 'page_key';
  end if;
  if (
    select count(distinct p ->> 'page')
      from jsonb_array_elements(p_document -> 'pages') p
  ) <> jsonb_array_length(p_document -> 'pages') then
    return 'page_duplicate';
  end if;

  for v_page in select jsonb_array_elements(p_document -> 'pages') loop
    if jsonb_typeof(v_page) <> 'object' then
      return 'page_entry';
    end if;
    v_check := core.app_design_node_check(v_page -> 'root', 1);
    if not (v_check ->> 'ok')::boolean then
      return coalesce(v_check ->> 'reason', 'root');
    end if;
    v_ids := v_ids || (v_check -> 'ids');
  end loop;

  if jsonb_array_length(v_ids) > 400 then
    return 'node_count';
  end if;
  if (
    select count(distinct i) from jsonb_array_elements_text(v_ids) i
  ) <> jsonb_array_length(v_ids) then
    return 'node_duplicate';
  end if;

  ---------------------------------------------------------------------------
  -- The theme block. Absent is the normal case, not a licence for anything:
  -- a version-1 document that carries one is stamped wrong, and a version-2
  -- document may carry only the keys the renderers actually read.
  ---------------------------------------------------------------------------
  v_theme := p_document -> 'theme';
  if v_theme is not null then
    if v_version <> 2 then
      return 'theme_version';
    end if;
    if jsonb_typeof(v_theme) <> 'object' then
      return 'theme';
    end if;
    if exists (
      select 1
        from jsonb_object_keys(v_theme) k
       where k not in ('colors', 'text_scale', 'radius_scale')
    ) then
      return 'theme_key';
    end if;

    if v_theme ? 'colors' then
      if jsonb_typeof(v_theme -> 'colors') <> 'object' then
        return 'theme_colors';
      end if;
      if exists (
        select 1
          from jsonb_object_keys(v_theme -> 'colors') r
         where r not in (
           'primary', 'secondary', 'background', 'surface',
           'text_primary', 'text_secondary', 'border',
           'success', 'error', 'disabled')
      ) then
        return 'theme_color_role';
      end if;
      -- لون لا يُقرأ بستة أو ثمانية عشر أرقام ليس لونًا، وشاشة نصفها أسود لا
      -- تُكتشف إلا عند الزبون.
      if exists (
        select 1
          from jsonb_each(v_theme -> 'colors') c
         where jsonb_typeof(c.value) <> 'string'
            or c.value #>> '{}' !~ '^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$'
      ) then
        return 'theme_color_value';
      end if;
    end if;

    if v_theme ? 'text_scale' and (
      jsonb_typeof(v_theme -> 'text_scale') <> 'string'
      or v_theme ->> 'text_scale' not in
         ('default', 'compact', 'comfortable', 'large')
    ) then
      return 'theme_text_scale';
    end if;
    if v_theme ? 'radius_scale' and (
      jsonb_typeof(v_theme -> 'radius_scale') <> 'string'
      or v_theme ->> 'radius_scale' not in
         ('default', 'sharp', 'soft', 'round', 'pill')
    ) then
      return 'theme_radius_scale';
    end if;
  end if;

  return null;
end;
$fn$;

comment on function core.app_design_is_valid(jsonb) is
  'Null when a design document is structurally publishable, else the first broken part as a code the panel prints. Accepts schema_version 1 (no theme) and 2 (optional theme); validates colour roles, hex values and scale names (227).';

-- ---------------------------------------------------------------------------
-- 226 ends by reloading PostgREST; a replaced function is a new signature to
--    its cache, so the same two lines close this one.
-- ---------------------------------------------------------------------------
notify pgrst, 'reload config';
notify pgrst, 'reload schema';
