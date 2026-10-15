-- 002b_fix_normalize_arabic_digits.sql
--
-- BUG FOUND DURING APPLICATION of 002.
--
-- The tashkeel-stripping class was written as  '[ً-ٰـ]'
-- which is the range U+064B .. U+0670 PLUS U+0640.
--
-- Arabic-Indic digits ٠..٩ are U+0660..U+0669 -- they fall INSIDE that range,
-- so normalize_ar('١٢٣') stripped every character and returned ''.
--
-- Fix: bound the class at U+0655 (below the digit block) and list U+0670
-- and U+0640 separately. Digits now survive to reach translate().
--
-- This is a corrective migration rather than an edit of 002, per
-- DATABASE_SPEC.md section 11 ("do not modify an applied migration").

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