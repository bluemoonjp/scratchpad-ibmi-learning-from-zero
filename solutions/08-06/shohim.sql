-- 08-06 exercise model answer: SHOHIM modernized as a SQL table.
-- See docs/part08/08-06-dds-to-sql-ddl.md, exercise step 2.
--
-- Unlike src/sql/08-06-ddl.sql (a faithful GENERATE_SQL conversion of
-- TOKUIM that intentionally keeps the same record format level ID),
-- this file deliberately CHANGES the shape of SHOHIM (db/v1/shohim.pf):
--
--   SHONM  CHAR(30)  -> VARCHAR(30)    (variable-length modernization)
--   SHOTNK 7S 2       -> DECIMAL(7, 2) (zoned -> packed, chosen on purpose;
--                                        NUMERIC would have kept it zoned,
--                                        the same way GENERATE_SQL mapped
--                                        TOKUPD's 8S 0 to NUMERIC(8, 0))
--   SHOHAT 5S 0       -> NUMERIC(5, 0) (left zoned, unchanged)
--   (new)             -> PRIMARY KEY (SHOCD) (DDS's K SHOCD was only a
--                                        non-unique keyed access path,
--                                        not a uniqueness constraint)
--
-- Because the shape is intentionally different, QTEMP.SHOHIM's record
-- format level ID will NOT match the real SHOHIM's - that mismatch is
-- the expected, correct result here (see the lesson's "演習" section).
-- Run this in the SAME job/connection you will use for the DSPFFD
-- TYPE(*RCDFMT)-equivalent check (DSPFFD FILE(QTEMP/SHOHIM)) afterward,
-- since QTEMP is job-scoped.

CREATE TABLE QTEMP.SHOHIM (
    SHOCD  CHAR(6)       NOT NULL,
    SHONM  VARCHAR(30)   NOT NULL,
    SHOTNK DECIMAL(7, 2) NOT NULL,
    SHOHAT NUMERIC(5, 0) NOT NULL,
    PRIMARY KEY (SHOCD)
);

-- Cleanup (not run automatically - see the lesson's "片付け" section):
--   DROP TABLE QTEMP.SHOHIM;
-- QTEMP is job-scoped, so ending the ACS connection also clears it.
