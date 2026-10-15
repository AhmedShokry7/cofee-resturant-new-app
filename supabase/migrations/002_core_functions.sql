-- 002_core_functions.sql
-- Shared, pure helper functions. Created before any table that triggers on them.
--
-- core.normalize_ar() is a direct port of the Dart implementation at
-- lib/features/assistant/data/assistant_language.dart:14-48 so that server
-- side search matches what the client already produced.
-- Decision D6.

-- ---------------------------------------------------------------------------
-- Arabic / English text normalization
--   - lowercase
--   - strip tashkeel (harakat) and tatweel
--   - fold letter variants: alef forms, ta-marbuta, alef-maqsura, hamza forms,
--     Persian kaf/cheh/peh/feh, and Arabic-Indic digits -> ASCII
--   - collapse every non-alphanumeric run into a single space
--   - split the conjunction "و" when glued to a 4+ letter word
--   - drop the definite article "ال" when glued to a 2+ letter word
--   - collapse 3+ repetitions of the same letter down to one
--   - trim
-- ---------------------------------------------------------------------------
create or replace function core.normalize_ar(input text)
returns text
language sql
immutable
strict
as $fn$
  select btrim(
    regexp_replace(
      -- (3 or more of the same letter) -> 1
      regexp_replace(
        -- "ال" + 2 letters -> drop the article
        regexp_replace(
          -- "و" + 4 letters -> split the conjunction off the word
          regexp_replace(
            -- anything that is not a letter or digit -> one space
            regexp_replace(
              -- fold letter variants and Arabic-Indic digits
              translate(
                -- lowercase, then drop tashkeel + tatweel
                regexp_replace(lower(input), '[ً-ٰـ]', '', 'g'),
                --  1   2   3   4   5   6   7   8   9  10  11  12   13..22
                'أإآٱةىؤئگچپڤ٠١٢٣٤٥٦٧٨٩',
                'ااااهيويكجبف0123456789'
              ),
              '[^[:alnum:]]+', ' ', 'g'
            ),
            '(^| )و([[:alpha:]]{4,})', '\1و \2', 'g'
          ),
          '(^| )ال([[:alpha:]]{2,})', '\1\2', 'g'
        ),
        '([[:alpha:]])\1{2,}', '\1', 'g'
      ),
      '\s+', ' ', 'g'
    )
  );
$fn$;

comment on function core.normalize_ar(text) is
  'Arabic/English normalization. Port of assistant_language.dart normalizeText().';

-- ---------------------------------------------------------------------------
-- updated_at maintenance. Applied per-table in later migrations.
-- ---------------------------------------------------------------------------
create or replace function core.set_updated_at()
returns trigger
language plpgsql
as $fn$
begin
  new.updated_at := now();
  return new;
end;
$fn$;

comment on function core.set_updated_at() is 'BEFORE UPDATE trigger: stamp updated_at.';

-- ---------------------------------------------------------------------------
-- ordering helper used by catalog listings
-- ---------------------------------------------------------------------------
create or replace function core.slugify(input text)
returns text
language sql
immutable
strict
as $fn$
  select btrim(regexp_replace(lower(input), '[^[:alnum:]]+', '-', 'g'), '-');
$fn$;

comment on function core.slugify(text) is 'Lowercase, non-alphanumerics collapse to single dash.';