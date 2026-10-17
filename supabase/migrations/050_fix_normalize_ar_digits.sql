-- 050_fix_normalize_ar_digits.sql
--
-- Production drift repair for `core.normalize_ar`.
--
-- `002b_fix_normalize_arabic_digits.sql` is recorded in `_ops.migration_log`,
-- but production still runs the buggy 002 body: its harakat class spans
-- U+064B..U+0670, which swallows the Arabic-Indic digit block U+0660..U+0669.
-- Verified on production before this migration:
--   core.normalize_ar(chr(1633)||chr(1634)||chr(1635))  ->  ''   (wrong)
--   core.normalize_ar('مقهى عربي')                       ->  'مقهي عربي'
--
-- This migration re-applies exactly the 002b function body (no other
-- 002b change) so `normalize_ar('١٢٣')` returns `'123'` again. It is written
-- as a new numbered migration rather than editing 002/002b, per the rule
-- against modifying applied migrations.
--
-- Impact on stored search sources is nil: no catalog row contains characters
-- in U+0656..U+066F, so no search index needs rebuilding.

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
                -- lowercase, then drop harakat (U+064B..U+0655),
                -- superscript alef (U+0670) and tatweel (U+0640).
                -- NOTE: must NOT span to U+0670 as a range, that range
                -- contains the Arabic-Indic digit block U+0660..U+0669.
                regexp_replace(lower(input), '[ً-ٰٕـ]', '', 'g'),
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
  'Arabic/English normalization. Port of assistant_language.dart normalizeText(). Arabic-Indic digit fix.';
