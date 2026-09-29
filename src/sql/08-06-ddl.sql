-- 08-06: DDS-to-SQL-DDL conversion - TOKUIM's confirmed GENERATE_SQL output.
-- See docs/part08/08-06-dds-to-sql-ddl.md.
--
-- Run this in the SAME job/connection as the lesson's DSPFD
-- TYPE(*RCDFMT) verification step (実演 step 4; QTEMP is job-scoped, so
-- a different connection will not see QTEMP.TOKUIM).
--
-- This is the CREATE TABLE portion of the DDL that QSYS2.GENERATE_SQL
-- actually produced for TOKUIM (db/v1/tokuim.pf) when called as:
--
--   CALL QSYS2.GENERATE_SQL(
--     DATABASE_OBJECT_NAME => 'TOKUIM',
--     DATABASE_OBJECT_LIBRARY_NAME => '<your dev library>',
--     DATABASE_OBJECT_TYPE => 'TABLE')
--
-- DATABASE_OBJECT_TYPE must be the string 'TABLE'. '*FILE' - the value
-- every earlier attempt in this repo's history used unchallenged - is
-- NOT valid and fails with SQLSTATE 22023, "DATABASE_OBJECT_TYPE NOT
-- VALID". See docs/probes.md, the "part08-06-lvlid-and-gensql" entry.
--
-- GENERATE_SQL's full result set also included LABEL ON TABLE / LABEL ON
-- COLUMN / GRANT statements that name the REAL source library (not
-- QTEMP). Those are deliberately left out of this file - running them
-- as-is would touch the real shared TOKUIM's labels/privileges. Only the
-- CREATE TABLE statement is kept here, with the library changed to
-- QTEMP so this never touches the real shared TOKUIM.
--
-- CONFIRMED: running exactly this statement (library swapped to QTEMP)
-- and comparing QTEMP.TOKUIM's DSPFD TYPE(*RCDFMT) format level
-- identifier against the real TOKUIM's produced a byte-for-byte match
-- (3B1ECB3196772 on both sides). See docs/probes.md, the
-- "part08-06-lvlid-confirm" entry.
--
-- LIMITATION (do not skip this): this generated table has no keyed
-- access path. DDS's K TOKCD (db/v1/tokuim.pf) is NOT carried over -
-- GENERATE_SQL's own output includes two IBM warning comments saying so
-- (SQL150B: REUSEDLT ignored; SQL1506: key/attribute ignored). A
-- matching level ID proves the same FIELD structure, not a drop-in
-- replacement for keyed access (e.g. a CHAIN(custCode) TOKUIM pattern
-- would need an explicit PRIMARY KEY or index added separately).
-- GENERAL KNOWLEDGE, NEEDS CONFIRMATION: DDS's K TOKCD is a non-unique
-- keyed access path, while PRIMARY KEY enforces uniqueness - whether a
-- PRIMARY KEY (vs. a plain non-unique index) is actually what restores
-- CHAIN-style compatibility has not been verified in this material.
--
-- Aside from the library-name substitution described above, the two
-- SQL150B/SQL1506 warning comments (shown in the lesson's "実際に生成
-- された TOKUIM のDDL" section) were dropped, and the remaining
-- whitespace/line breaks were reformatted for readability; the
-- column/type definitions themselves are unchanged from the confirmed
-- generated text.

CREATE TABLE QTEMP.TOKUIM (
    TOKCD  CHAR(6)        CCSID 273 NOT NULL DEFAULT '' ,
    TOKNM  CHAR(30)       CCSID 273 NOT NULL DEFAULT '' ,
    TOKZIP CHAR(7)        CCSID 273 NOT NULL DEFAULT '' ,
    TOKTAN CHAR(6)        CCSID 273 NOT NULL DEFAULT '' ,
    TOKUPD NUMERIC(8, 0)            NOT NULL DEFAULT 0
)
RCDFMT TOKUIR;

-- Cleanup (not run automatically - see the lesson's "片付け" section):
--   DROP TABLE QTEMP.TOKUIM;
-- QTEMP is job-scoped, so ending the ACS connection also clears it.
