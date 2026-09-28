**FREE
//==================================================================
// Q0613A - Lesson 06-13: embedded SQL (1).
//
// Demonstrates, against TOKUIM (customer master, part02-verified):
//   - SET OPTION (COMMIT / NAMING / CLOSQLCSR) coded in the source
//   - SELECT INTO for a single-row read
//   - UPDATE
//   - SQLSTATE checking after the UPDATE
//   - GET DIAGNOSTICS for detailed error text
//
// Output goes to QSYSPRT (program-described, WRKSPLF is the normal
// way to read it in this curriculum), not DSPLY. DSPLY only works
// from an interactive job (ilerpgref75.txt, "DSPLY (Display
// Message)": "DSPLY allows interactive communication between the
// program and the operator or ... the display work station that
// requested the program"), and the verify/ harness in
// work/design/part06-design-v1.md section 5.1 (batch
// "part06-1314-sql") calls this program non-interactively over SSH,
// the same reason lesson 06-09's design already picked QSYSPRT/job
// log over DSPLY for its own non-interactive check. QSYSPRT here is
// a plain program-described printer file (dcl-f ... printer(132)),
// written to with a data structure, with no Output specifications:
// ilerpgref75.txt, "File Operations" (search "The WRITE and UPDATE
// operations that specify a program described file name in factor 2
// must have a data structure name specified in the result field") --
// this is the free-form way to do program-described printer output
// without O-specs, which this part of the curriculum does not
// introduce as new syntax (see work/design/part06-design-v1.md,
// section 1, the list of things this part deliberately does not
// cover).
//
// HARDWARE STATUS: CONFIRMED (part06-1314-sql, 2026-09-27, 2nd
// connection): CRTSQLRPGI succeeded and CALL produced "Found C00001:
// ACME TRADING CO" / "Zip=1000001 Rep=T00001 Updated=20260901" /
// "UPDATE OK" - SELECT INTO and UPDATE both work as designed (V2,
// confirmed by reading the connection's raw run-section text). The
// 1st connection hit an unrelated compile bug first (SQL0104:
// DB2_MESSAGE_TEXT is not a valid GET DIAGNOSTICS item name on this
// PTF level - MESSAGE_TEXT, no DB2_ prefix, is; fixed below). See
// docs/probes.md's part06-1314-sql section. This program's own SET
// OPTION line hardcodes COMMIT(*NONE), so it never reaches SQL7008 -
// that reproduction is verify/part06-1314-sql/src/q0613v.sqlrpgle
// (Q0613V), a verify-only variant with exactly one line different
// (see that file's own header) - the lesson text teaches that same
// one-line edit as an exercise, not the whole SET OPTION line removed.
//
// Primary-source citations (see work/design/refs/):
//  - CLOSQLCSR's two allowed values for CRTSQLRPGI, *ENDACTGRP and
//    *ENDMOD, and their exact mechanics: cl_commands_75.txt, the
//    CRTSQLRPGI parameter table's CLOSQLCSR row (around line 4182),
//    and the prose section "Close SQL cursor (CLOSQLCSR)" a little
//    further down in the same file (around lines 4840-4858; search
//    that heading). Honest caveat on which one is the DEFAULT: this
//    plain-text dump of the parameter table has no separate "Default"
//    column or bold marker, only value order, so "*ENDACTGRP is
//    listed first" is suggestive (the same table's REPLACE row lists
//    "*YES , *NO" and *YES is REPLACE's well-known real default) but
//    not, by itself, ironclad proof for every parameter in this table
//    (this same file's TGTRLS row lists "Simple name" first, which is
//    a value-type placeholder rather than the real default, *CURRENT).
//    work/design/part06-design-v1.md section 06-13 also concludes
//    *ENDACTGRP is the default and cites this same file, but that
//    design doc is not an independent second source for this specific
//    fact -- it is where this program's own conclusion started from,
//    and this comment is repeating the same underlying evidence, not
//    confirming it a second, different way. See the ctl-opt section
//    below for the exact quoted mechanics and how they apply (or do
//    not) to this specific program.
//  - COMMIT's default is *CHG, and DDL statements such as CREATE
//    (and by extension, other schema statements) are explicitly
//    covered by the COMMIT parameter's own description: same file,
//    "Commitment control (COMMIT)" section -- "*CHG or *UR:
//    Specifies the objects referred to in SQL ALTER, CALL, COMMENT
//    ON, CREATE, DROP, GRANT, LABEL ON, RENAME, and REVOKE statements
//    and the rows updated, deleted, and inserted are locked..." and
//    "*NONE or *NC: ... If the SQL DROP SCHEMA statement is included
//    in the program, *NONE or *NC must be used." Both quotes confirm
//    that CRTSQLRPGI expects such statements to be coded directly in
//    the program (not necessarily built and run through PREPARE).
//  - SQLSTATE is generated automatically as a subfield of the SQLCA
//    data structure the precompiler inserts before the first C-spec
//    (unless SET OPTION SQLCA = *NO is used): rzajp75.txt, "Defining
//    the SQL communication area in ILE RPG applications that use
//    SQL" (search that heading; the generated DCL-DS SQLCA ...
//    END-DS SQLCA block quoted there ends with a plain, non-qualified
//    subfield declared as 5 characters). This is why this program
//    does not declare its own SQLSTATE field.
//  - GET DIAGNOSTICS CONDITION syntax and item names: rzajp75.txt,
//    "Example: Logging items from the SQL diagnostics area" (search
//    "DB2_MESSAGE_TEXT") shows DB2_MESSAGE_ID/DB2_MESSAGE_TEXT
//    together, but a real CRTSQLRPGI on this repo's actual target
//    (V7R5M0, part06-1314-sql, 2026-09-27) rejected DB2_MESSAGE_TEXT
//    with SQL0104 ("Token DB2_MESSAGE_TEXT was not valid") and its own
//    valid-token list has DB2_MESSAGE_ID but only the UNPREFIXED
//    MESSAGE_TEXT, not DB2_MESSAGE_TEXT - so DB2_MESSAGE_ID is used
//    below (matches the citation and confirmed valid) but the message
//    text item is MESSAGE_TEXT (real-hardware finding overriding the
//    cited doc's own worked example, which may reflect an older or
//    different release).
//  - End-of-data / not-found SQLSTATE '02000' (SQLCODE +100): a
//    DIFFERENT section of the same file, "Handling exception
//    conditions with the WHENEVER statement" (search "Specify NOT
//    FOUND to indicate what you want done when an SQLCODE of +100").
//    Not directly exercised by this program (no cursor here; see
//    q0614s.sqlrpgle), but the SELECT INTO below could return this
//    SQLSTATE if the row is missing, so the else-branch after it is
//    written with that in mind.
//  - Free-form "EXEC SQL ... ;" statement placement (one statement
//    per line, ends with a semicolon): rzajp75.txt / rbafy75.txt,
//    "Embedding SQL statements in ILE RPG applications that use
//    SQL" -> "Free-form RPG" subsection.
//  - Concatenation operator restriction: docs/style-guide.md,
//    distributed-source character/format rules section (heading
//    starts with the kanji for "distributed source characters and
//    format") -- the double vertical bar character used by SQL's
//    string concatenation operator is a CCSID 273 variable character
//    and must not appear in distributed source, so this program uses
//    the SQL CONCAT() function for concatenation instead, and this
//    comment spells the operator out in words rather than quoting
//    the two-character symbol itself.
//
// IMPORTANT (per work/design/part06-design-v1.md, section 06-13, and
// the underlying GitHub tracking issue this lesson answers): message
// SQL7008 ("table not journaled") is reproduced by an UPDATE or
// INSERT running under commitment control against a table that is
// not journaled -- it is NOT reproduced by a plain SELECT INTO,
// because a read never needs to write to a journal. This is why the
// failure path demonstrated below is deliberately built around the
// UPDATE (step 2), not the SELECT INTO (step 1).
//
// How to reproduce SQL7008 with this source (expected, untested):
//   1. Comment out (or delete) the "EXEC SQL SET OPTION ...;"
//      statement below, and make sure COMMIT(*NONE) is not passed as
//      a CRTSQLRPGI command parameter either.
//   2. Recompile. The program now precompiles under CRTSQLRPGI's own
//      default, COMMIT(*CHG) (see citation above), instead of the
//      COMMIT(*NONE) this source normally asks for.
//   3. Run it against a copy of TOKUIM that is confirmed NOT to be
//      journaled (whether the real TOKUIM is journaled has not been
//      checked yet -- probe P12 has not been run; docs/probes.md has
//      no journal-related entries as of this writing). Step 1
//      (SELECT INTO) is still expected to succeed. Step 2 (UPDATE)
//      is expected to fail with SQLSTATE not equal to '00000' and
//      message SQL7008, because *CHG commitment control needs a
//      journal to record the change for possible rollback, while a
//      read has nothing to roll back and needs no journal at all.
//==================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

// All Definition specifications (D-specs -- dcl-s/dcl-f/dcl-ds here)
// must appear before the first Calculation specification (C-spec).
// This is a structural rule of RPG IV itself, not an SQL rule:
// ilerpgref75.txt, "Order of Specifications" (Table 99, search "The
// RPG IV source must be entered into the system in the order shown")
// gives the fixed main-source-section order H, F/D (may intermix),
// I, C, O. Every "EXEC SQL ...;" statement below (including SET
// OPTION) compiles down to C-spec-equivalent code, so the file and
// all host variables are declared here, before the first one.
dcl-f qsysprt printer(132) usage(*output);

dcl-ds prtLine len(132);
  prtText char(132) pos(1);
end-ds;

dcl-s wTokcd  char(6) inz('C00001');
dcl-s wToknm  char(30);
dcl-s wTokzip char(7);
dcl-s wToktan char(6);
dcl-s wTokupd zoned(8:0);

dcl-s wMsgId   char(10);
dcl-s wMsgText char(200);

// SET OPTION is a precompile-time directive (like a CRTSQLRPGI
// command parameter, but coded in the source itself; if both are
// specified, the SET OPTION value wins -- rzajp75.txt, "Preparing
// and running a program with SQL statements", search "By specifying
// them in the input source").
//
//   naming    = *sys   : "library/table" qualification, matching the
//                         rest of this repository's convention.
//   commit    = *none  : overrides CRTSQLRPGI's own default of
//                         *CHG. *NONE means no commitment control,
//                         so the UPDATE below can run against TOKUIM
//                         even if TOKUIM is not journaled. See the
//                         header comment for what happens if this
//                         line is removed.
//   closqlcsr = *endmod: overrides CRTSQLRPGI's own default of
//                         *ENDACTGRP. Quoting cl_commands_75.txt,
//                         "Close SQL cursor (CLOSQLCSR)":
//                           *ENDACTGRP (default) - SQL cursors are
//                             closed, SQL prepared statements are
//                             discarded, and LOCK TABLE locks are
//                             released "when the activation group
//                             ends".
//                           *ENDMOD (this program) - SQL cursors are
//                             closed and prepared statements are
//                             discarded "when the module is exited";
//                             LOCK TABLE locks release "when the
//                             first SQL program on the call stack
//                             ends". The source adds a subtlety: a
//                             cursor "may only be logically closed"
//                             at module exit, and is only
//                             "physically closed" later, when the
//                             first SQL program on the call stack
//                             leaves it (and only if that first
//                             program was not itself compiled
//                             *ENDACTGRP).
//                         This program is compiled ACTGRP(*NEW) via
//                         its ctl-opt above -- confirmed to actually
//                         take effect because CRTSQLRPGI's default
//                         OBJTYPE(*PGM) (the parameter table lists
//                         "*PGM , *SRVPGM, *MODULE") makes the
//                         precompiler "issue the CRTBNDxxx command to
//                         create the program" (rzajp75.txt, "Compiling
//                         an ILE application program that uses SQL"),
//                         and CRTBNDRPG is the normal single-step
//                         compile that honors ctl-opt keywords
//                         directly, so a fresh activation
//                         group is created and destroyed on every
//                         single CALL: module exit and activation-
//                         group end happen at essentially the same
//                         moment here, so *ENDACTGRP vs *ENDMOD makes
//                         no observable difference in THIS program.
//                         Also, this specific program has no cursor
//                         and no PREPAREd statement at all (that is
//                         lesson 06-14's subject, see q0614s.sqlrpgle
//                         and q0614bs.sqlrpgle), so there is nothing
//                         concrete for CLOSQLCSR to act on here
//                         either way -- it is coded on this SET
//                         OPTION line purely to demonstrate the
//                         syntax and the concept ahead of 06-14,
//                         which is what this lesson's own new-syntax
//                         list calls for. The setting is expected to
//                         start making an observable difference only
//                         once a program using a cursor or a prepared
//                         statement is bound into a caller whose
//                         activation group outlives that one call
//                         (for example ACTGRP(*CALLER) or a named,
//                         longer-lived activation group) -- a
//                         scenario this program does not build.
exec sql SET OPTION commit = *none, naming = *sys, closqlcsr = *endmod;

// --- 1. SELECT INTO: single-row read -----------------------------
exec sql
  SELECT TOKNM, TOKZIP, TOKTAN, TOKUPD
    INTO :wToknm, :wTokzip, :wToktan, :wTokupd
    FROM TOKUIM
    WHERE TOKCD = :wTokcd;

if SQLSTATE = '00000';
  prtText = 'Found ' + %trim(wTokcd) + ': ' + %trim(wToknm);
  write qsysprt prtLine;
  prtText = 'Zip=' + wTokzip + ' Rep=' + wToktan
          + ' Updated=' + %char(wTokupd);
  write qsysprt prtLine;
else;
  // Not expected for 'C00001' (see 02-06/04-08 for this row's
  // history), but handled so the program does not fall through into
  // the UPDATE with garbage host variables. A missing row here would
  // show up as SQLSTATE '02000' (see the WHENEVER citation above).
  prtText = 'SELECT INTO: no row, SQLSTATE=' + SQLSTATE;
  write qsysprt prtLine;
  *inlr = *on;
  return;
endif;

// --- 2. UPDATE: the statement that can surface SQL7008 -----------
// This UPDATE is deliberately a no-op (CONCAT(TOKNM, '') re-assigns
// the same value) so that running this lesson against the shared
// TOKUIM table needs no TXRESET afterwards -- but it is still a
// real UPDATE statement that goes through the same journaling
// requirement as any other UPDATE. CONCAT is used instead of the
// double vertical bar operator (see header).
exec sql
  UPDATE TOKUIM
    SET TOKNM = CONCAT(TOKNM, '')
    WHERE TOKCD = :wTokcd;

// --- 3. SQLSTATE check after the UPDATE ---------------------------
if SQLSTATE = '00000';
  prtText = 'UPDATE OK';
  write qsysprt prtLine;
else;
  prtText = 'UPDATE failed, SQLSTATE=' + SQLSTATE;
  write qsysprt prtLine;

  // --- 4. GET DIAGNOSTICS: detailed error text --------------------
  // CONDITION 1 is the most severe/only condition from the UPDATE
  // above (rzajp75.txt confirms the first diagnostics area always
  // matches the SQLSTATE variable; see header citation).
  exec sql
    GET DIAGNOSTICS CONDITION 1
      :wMsgId   = DB2_MESSAGE_ID,
      :wMsgText = MESSAGE_TEXT;
  prtText = wMsgId;
  write qsysprt prtLine;
  prtText = wMsgText;
  write qsysprt prtLine;
endif;

*inlr = *on;
return;
