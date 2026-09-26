-- 05-08: regression compare via TXSNAP (tools/qclsrc/txsnap.clp). See
-- docs/part05/05-08-logic-change-and-compare.md.
--
-- Workflow:
--   0. CRTPF FILE(<自分のライブラリー>/TXSNAPT) RCDLEN(133) MAXMBRS(*NOMAX)
--      : pre-create the target file with room for more than one member.
--      Two accounts of TXSNAPT's creation disagree and neither is
--      confirmed on real hardware this session: TXSNAP's own header
--      comment implies CPYSPLF creates TXSNAPT itself on first use, while
--      the P17 probe plan (work/design/final_probes.json) pre-creates its
--      equivalent test file with CRTPF ... RCDLEN(133) before using it.
--      Doing this CRTPF once, with MAXMBRS(*NOMAX), covers both cases: if
--      CPYSPLF does auto-create, this just pre-empts it (harmlessly,
--      since the file does not exist yet); if CPYSPLF needs the file to
--      already exist, this supplies it either way. Without it, an
--      auto-created PF would default to MAXMBRS(1) (ordinary CRTPF
--      default) and the SECOND label (AFTER) would fail to add its
--      member. Applied here to a permanent file instead of QTEMP because
--      BEFORE/AFTER must both survive across the two separate TXSNAP
--      calls.
--   1. TXSNAP LABEL(BEFORE) LIB(<自分のライブラリー>) : run the ORIGINAL JU0300
--      against a fixed job date (see the lesson for why the date must be
--      fixed before snapping) and label the spool BEFORE.
--   2. Make the intended change (e.g. add a tax column).
--   3. TXSNAP LABEL(AFTER) LIB(<自分のライブラリー>) : run the CHANGED JU0300
--      the same way and label the spool AFTER.
--   4. Compare (below).
--
-- FIXED (2026-09-26, before any real compile - a plain SQL correctness
-- issue, not a PUB400-specific unknown): "FROM TXSNAPT BEFORE" does NOT
-- select the BEFORE member. In standard SQL, the word after a table name
-- in a FROM clause is a correlation name (an alias for that reference),
-- not a member selector. Both halves of the original EXCEPT would have
-- read the SAME (default) member of TXSNAPT, so the compare could never
-- detect a real difference. Db2 for i's documented way to read a specific
-- member through SQL is CREATE ALIAS ... FOR <lib>.<file> (<member>).
-- UNVERIFIED against a real compile in this session, but this is
-- documented Db2 for i SQL syntax, not a PUB400-specific guess.
--
-- Replace <自分のライブラリー> below with your own library (e.g. the one
-- TXSNAP wrote TXSNAPT into). Do not leave the library off "TXSNAPT" here
-- - an unqualified name resolves against the SQL naming default schema
-- (usually the current user profile's own name), which is very unlikely
-- to be where TXSNAPT actually lives. CREATE OR REPLACE ALIAS (rather
-- than plain CREATE ALIAS) so re-running this script after a second
-- BEFORE/AFTER pair (e.g. the 05-08 edit-code exercise) does not fail on
-- "object already exists".

CREATE OR REPLACE ALIAS QTEMP.SNAPB FOR <自分のライブラリー>.TXSNAPT (BEFORE);
CREATE OR REPLACE ALIAS QTEMP.SNAPA FOR <自分のライブラリー>.TXSNAPT (AFTER);

-- Sanity check before trusting any result: look at the row counts first.
SELECT COUNT(*) AS SNAPB_ROWS FROM QTEMP.SNAPB;
SELECT COUNT(*) AS SNAPA_ROWS FROM QTEMP.SNAPA;

-- Prove the compare CAN fail before trusting a clean result: the change
-- you are about to test (e.g. 05-08's tax column) is itself the proof.
-- If the "AFTER-only" EXCEPT below comes back EMPTY even though you know
-- you changed the code, that does not mean "no effect" - it means the
-- compare itself is broken (the exact mistake this file made until the
-- fix above, where both aliases silently read the same member). Do not
-- trust a zero-row "no difference" result unless you have separately
-- confirmed the two aliases really do point at different, known-distinct
-- members (the COUNT(*) values above are a first, weak check; they can
-- match by coincidence even when the aliases are wrong).

-- Rows in BEFORE that are NOT in AFTER (removed or changed lines):
SELECT *
  FROM QTEMP.SNAPB
EXCEPT
SELECT *
  FROM QTEMP.SNAPA;

-- Rows in AFTER that are NOT in BEFORE (added or changed lines):
SELECT *
  FROM QTEMP.SNAPA
EXCEPT
SELECT *
  FROM QTEMP.SNAPB;

-- If the change is intentional (e.g. a new tax column), every row in the
-- second query should be explainable by that one intended difference. Any
-- OTHER row appearing in either query is an unintended side effect -
-- exactly what "regression compare" is checking for. CMPPFM (DSPF-style
-- side-by-side compare) is the 5250-native alternative to these two
-- queries, for whichever tool is more convenient at the terminal.
