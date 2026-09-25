-- 05-11: inspect the planted decimal data error with HEX(). See
-- docs/part05/05-11-decimal-data-error.md and src/qclsrc/c0511s.clp.

-- The suspect row (src/qclsrc/c0511s.clp plants JUNO='C05119', JULINE=1).
-- JUSU is the field expected to hold invalid zoned-decimal bytes.
SELECT JUNO, JULINE, JUSHO, JUSU, HEX(JUSU) AS JUSU_HEX, JUTNK
  FROM JUCHUD
 WHERE JUNO = 'C05119';

-- For comparison, a normal row's JUSU in hex (each digit's zone nibble
-- should be 'F', except the last byte's zone nibble, which carries the
-- sign - 'C' for positive/unsigned, 'D' for negative). Pick any real
-- order line already in the sample database instead of 'C05119'.
SELECT JUNO, JULINE, JUSU, HEX(JUSU) AS JUSU_HEX
  FROM JUCHUD
 WHERE JUNO <> 'C05119'
 FETCH FIRST 1 ROW ONLY;

-- If HEX(JUSU) on the suspect row does NOT end in a valid sign nibble (C/D/F
-- in the last byte) or has a non-digit zone nibble elsewhere, that is the
-- corruption C0511S planted, now visible without needing STRDBG or a dump.
