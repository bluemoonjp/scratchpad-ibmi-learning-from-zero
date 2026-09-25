-- 05-08: regression compare via TXSNAP (tools/qclsrc/txsnap.clp). See
-- docs/part05/05-08-logic-change-and-compare.md.
--
-- Workflow:
--   1. TXSNAP LABEL(BEFORE) LIB(<自分のライブラリー>) : run the ORIGINAL JU0300
--      against a fixed job date (see the lesson for why the date must be
--      fixed before snapping) and label the spool BEFORE.
--   2. Make the intended change (e.g. add a tax column).
--   3. TXSNAP LABEL(AFTER) LIB(<自分のライブラリー>) : run the CHANGED JU0300
--      the same way and label the spool AFTER.
--   4. Compare. Both labels are separate MEMBERS of the same file TXSNAPT
--      (CPYSPLF's own default record format - normally one field holding
--      each print line, unconfirmed against a real compile in this
--      session), so a member-qualified SELECT/EXCEPT works without
--      needing to know that field's exact name.

-- Rows in BEFORE that are NOT in AFTER (removed or changed lines):
SELECT *
  FROM TXSNAPT BEFORE
EXCEPT
SELECT *
  FROM TXSNAPT AFTER;

-- Rows in AFTER that are NOT in BEFORE (added or changed lines):
SELECT *
  FROM TXSNAPT AFTER
EXCEPT
SELECT *
  FROM TXSNAPT BEFORE;

-- If the change is intentional (e.g. a new tax column), every row in the
-- second query should be explainable by that one intended difference. Any
-- OTHER row appearing in either query is an unintended side effect -
-- exactly what "regression compare" is checking for. CMPPFM (DSPF-style
-- side-by-side compare) is the 5250-native alternative to these two
-- queries, for whichever tool is more convenient at the terminal.
