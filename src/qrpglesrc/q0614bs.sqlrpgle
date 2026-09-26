**FREE
//==================================================================
// Q0614BA - Lesson 06-14b: DATE / NULL-capable columns, %nullind,
//           ALWNULL(*USRCTL), SQL NULL indicator host variables.
//
// This program creates its OWN work table, QTEMP/W0614BA, at the
// start of every run, and never touches the shared sample database
// (TOKUIM itself is never opened or modified here). W0614BA is a
// reduced copy of TOKUIM (TOKCD, TOKNM only) plus one new column,
// TOKLORD (kept to 10 characters or fewer, matching every other
// column name in this table, so Db2 does not have to invent a
// separate generated short system column name for it), a NULL-
// capable DATE column that does not exist on the real TOKUIM. QTEMP
// is job-scoped, so nothing here needs a TXRESET afterwards; the
// table disappears when the job ends. The table is dropped (ignoring
// any error) before it is (re)created, so
// this program can also be CALLed more than once in the same job
// (for example, during interactive testing) without accumulating
// extra rows in a table that is still there from a previous CALL.
//
// Output goes to QSYSPRT (program-described, no Output specifications
// -- see below), not DSPLY, so this program can also be run non-
// interactively (the verify/ harness in
// work/design/part06-design-v1.md section 5.1 batch
// "part06-14b-null" calls it over SSH).
//
// HARDWARE STATUS: UNTESTED as of 2026-09-26 (Part 6 is a draft
// branch; no probe or verify/ run has compiled this member yet).
// Compile with CRTSQLRPGI. Because QTEMP/W0614BA does not exist at
// precompile time, expect the precompiler/compiler step for this
// member to raise informational or warning-severity messages about
// the table not being found ahead of time (this is normal for a
// QTEMP work table created at run time, not a real problem) -- do
// not read a non-zero Highest Severity on this member alone as a
// failure without checking what the message actually says. By
// default this should not stop the compile either way:
// cl_commands_75.txt, "Severity level (GENLVL)" -- the default is 10,
// and "the compiler is not called" only "if precompiler errors are
// generated that have a message severity level greater than the
// value specified", so a severity-10 message alone still lets the
// compiler run.
//
// On embedded CREATE TABLE in SQLRPGLE (task finding, see report):
// this program embeds "EXEC SQL CREATE TABLE ...;" and
// "EXEC SQL DROP TABLE ...;" directly (static SQL, no PREPARE/
// EXECUTE IMMEDIATE) rather than falling back to a documented-DDL-
// only companion comment. Evidence for this, from
// work/design/refs/cl_commands_75.txt, CRTSQLRPGI's own
// "Commitment control (COMMIT)" parameter description:
//   - "*CHG or *UR: Specifies the objects referred to in SQL ALTER,
//     CALL, COMMENT ON, CREATE, DROP, GRANT, LABEL ON, RENAME, and
//     REVOKE statements and the rows updated, deleted, and inserted
//     are locked until the end of the unit of work..."
//   - "*NONE or *NC: ... If the SQL DROP SCHEMA statement is
//     included in the program, *NONE or *NC must be used."
// Both quotes describe CREATE/DROP-family statements as things that
// can be coded directly "in the program" that CRTSQLRPGI compiles,
// governed by the same COMMIT setting as any other embedded
// statement, with no mention of a PREPARE/EXECUTE requirement. This
// is RPG/CRTSQLRPGI-specific evidence (not an inference from a
// different host language), but it is still a documentation
// citation, not a hardware confirmation -- treat "embedded CREATE
// TABLE / DROP TABLE work in SQLRPGLE" as high-confidence, and let
// the verify/ harness confirm it the first time this member is
// actually compiled.
//
// Other primary-source citations:
//  - ALWNULL(*USRCTL) control-specification keyword and %NULLIND
//    BIF requiring it: ilerpgref75.txt, "%NULLIND (Query or Set Null
//    Indicator)" (search that heading) -- "This built-in function
//    can only be used if the ALWNULL(*USRCTL) keyword is specified
//    on a control specification or as a command parameter. The
//    fieldname can be a null-capable array element, data structure,
//    stand-alone field, subfield, or multiple occurrence data
//    structure."
//  - The NULLIND definition-specification keyword, used here WITHOUT
//    a parameter to make a stand-alone field null-capable while
//    addressing its indicator only through %NULLIND:
//    ilerpgref75.txt, the NULLIND keyword section (search "The
//    NULLIND keyword allows you to explicitly define the %NULLIND
//    value for a field or data structure" / "You can omit the
//    parameter for the NULLIND keyword if the item being defined is
//    not a data structure. In that case, the variable or array is
//    null-capable, but the null-indicators must be addressed by
//    using the %NULLIND built-in function.").
//  - %NULLIND read/write usage pattern (testing it in an if
//    condition; assigning *on/*off to it): ilerpgref75.txt, same
//    "%NULLIND (Query or Set Null Indicator)" section, Figure 228
//    example.
//  - SQL NULL indicator host variables (a small integer set to a
//    negative value by SQL when the fetched column is NULL, used as
//    a host variable followed by a second, indicator host variable
//    on FETCH/SELECT INTO): rzajp75.txt, "Using indicator variables
//    in C and C++ applications that use SQL" (search "EXEC SQL FETCH
//    CLS_CURSOR INTO :ClsCd" / ":Day :DayInd"). This is a DIFFERENT
//    mechanism from RPG's own ALWNULL/%NULLIND: the SQL indicator
//    variable and the RPG native null indicator are not the same
//    storage and are not linked automatically by the precompiler in
//    anything found in these references, so this program bridges the
//    two explicitly (see step 4 below), rather than assuming one
//    updates the other.
//  - DATE 'yyyy-mm-dd' literal syntax: rbafy75.txt (search
//    "DATE '1950-01-01'").
//  - Concatenation operator restriction: docs/style-guide.md,
//    distributed-source character/format rules section (this
//    program's literal INSERTs do not need string concatenation, but
//    the same restriction applies to any embedded SQL text in this
//    repository, so it is spelled out here for anyone extending this
//    program with a concatenated column value).
//  - Program-described printer file WRITE with a data structure and
//    no Output specifications: ilerpgref75.txt, "File Operations"
//    (search "The WRITE and UPDATE operations that specify a program
//    described file name in factor 2 must have a data structure name
//    specified in the result field").
//==================================================================

ctl-opt dftactgrp(*no) actgrp(*new) alwnull(*usrctl);

// --- 1. files and host variables -------------------------------------
// All Definition specifications (D-specs) must appear before the
// first Calculation specification (C-spec); every "EXEC SQL ...;"
// statement below (including SET OPTION, DROP TABLE, and CREATE
// TABLE) compiles down to C-spec-equivalent code. See
// ilerpgref75.txt, "Order of Specifications" (Table 99).
dcl-f qsysprt printer(132) usage(*output);

dcl-ds prtLine len(132);
  prtText char(132) pos(1);
end-ds;

dcl-s wTokcd char(6);
dcl-s wToknm char(30);

// SQL-side NULL indicator host variable (classic embedded-SQL
// mechanism, separate from RPG's own null indicator -- see header).
dcl-s wLastOrderInd int(5);
dcl-s wLastOrderSql date;

// RPG-native null-capable stand-alone field. NULLIND with no
// parameter means its indicator is addressed only through
// %nullind(wLastOrder) (see header citation). ALWNULL(*USRCTL) on
// the ctl-opt above is required for this to be legal.
dcl-s wLastOrder date NULLIND;

exec sql SET OPTION commit = *none, naming = *sys;

// --- 2. QTEMP-scoped work table: reduced copy of TOKUIM plus one --
//        new NULL-capable DATE column. Dropped first (result
//        ignored -- it normally fails with "table not found" on the
//        first CALL in a job, which is expected and harmless) so a
//        second CALL in the same job starts from a clean table too.
exec sql DROP TABLE QTEMP/W0614BA;

exec sql
  CREATE TABLE QTEMP/W0614BA (
    TOKCD   CHAR(6)  NOT NULL,
    TOKNM   CHAR(30) NOT NULL,
    TOKLORD DATE
  );

// Check SQLCODE, not SQLSTATE, here: creating a table in QTEMP (which
// has no journal) is expected to succeed with a positive SQLCODE /
// class-01 SQLSTATE warning ("table created but not journaled"), not
// SQLSTATE '00000'. rzajp75.txt (search "If SQL encounters an error
// while processing the statement, the SQLCODE is a negative number")
// confirms only a NEGATIVE SQLCODE means a real error; a positive
// SQLCODE is a warning/exception condition that still completed the
// statement. Testing SQLSTATE = '00000' here would treat that normal
// warning as a failure on every single successful run.
if SQLCODE < 0;
  prtText = 'CREATE TABLE failed, SQLCODE=' + %char(SQLCODE);
  write qsysprt prtLine;
  *inlr = *on;
  return;
endif;

// One row with a real last-order date, one row where it is unknown
// (NULL).
exec sql
  INSERT INTO QTEMP/W0614BA (TOKCD, TOKNM, TOKLORD)
    VALUES ('C00001', 'ACME TRADING CO', DATE '2026-09-05');

exec sql
  INSERT INTO QTEMP/W0614BA (TOKCD, TOKNM, TOKLORD)
    VALUES ('C00099', 'NEW PROSPECT CO', NULL);

// --- 3. cursor over the 2 demo rows ---------------------------------
exec sql DECLARE C2 CURSOR FOR
  SELECT TOKCD, TOKNM, TOKLORD
    FROM QTEMP/W0614BA
    ORDER BY TOKCD;

exec sql OPEN C2;

exec sql
  FETCH C2 INTO :wTokcd, :wToknm, :wLastOrderSql :wLastOrderInd;

dow SQLSTATE = '00000';

  // --- 4. bridge: SQL indicator -> RPG %nullind, explicitly. -------
  // This is the point of the lesson: %nullind is not maintained for
  // us by embedded SQL; a negative SQL indicator must be translated
  // into the RPG null indicator by hand before the field is safe to
  // use in RPG expressions.
  if wLastOrderInd < 0;
    %nullind(wLastOrder) = *on;
  else;
    %nullind(wLastOrder) = *off;
    wLastOrder = wLastOrderSql;
  endif;

  // --- 5. differentiate the NULL row from the real-date row. ------
  if %nullind(wLastOrder);
    prtText = %trim(wTokcd) + ' ' + %trim(wToknm)
            + ': last order date is NULL (unknown)';
  else;
    prtText = %trim(wTokcd) + ' ' + %trim(wToknm)
            + ': last order ' + %char(wLastOrder);
  endif;
  write qsysprt prtLine;

  exec sql
    FETCH C2 INTO :wTokcd, :wToknm, :wLastOrderSql :wLastOrderInd;
enddo;

exec sql CLOSE C2;

*inlr = *on;
return;
