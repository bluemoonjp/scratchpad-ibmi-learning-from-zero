**FREE
//======================================================================
// F0608A ("ZAHIK4") - **FREE rewrite of R0409A ("ZAHIK3", 04-09:
// "update-lock", see docs/part04/04-09-update-lock.md and
// src/qrpgsrc/r0409s.rpg). Written for lesson 06-08 (file I/O with
// dcl-f, likerec, and %kds).
//
// STATUS: CONFIRMED V2 (part06-08-writedelete, 2026-09-27).
// CRTBNDRPG Highest Severity 00. CALL produced the exact expected line
// for all three outcomes (confirmed via separate exercise-variant
// compiles, matching R0409A's own established exercise convention):
// "P00001  0000045  SHORT" (qty=999), "P99999  0000000  NOTFOUND",
// "P00001  0000043  OK" (the real qty=2 default run, ZASU 45->43).
// The WRITE/DELETE/%kds-DELETE/%fields round trip against ZTEST1
// produced no error messages (silent success, as designed). TXRESET
// afterward restored ZAIKOM to its original 6-row state (confirmed by
// a follow-up SELECT).
//
// ====================================================================
// WARNING: THIS PROGRAM WRITES TO THE SHARED ZAIKOM TABLE.
// ZAIKOM is the SAME physical file that R0409A / ZAHIK3 (04-09)
// already updates, and that 04-13's checkpoint, 06-07's exercise,
// 06-11b, and 06-15's checkpoint all read and depend on having known
// values. Running this program's default demo (product P00001,
// quantity 2) changes ZASU the same way 04-09's own exercise does
// (45 to 43). THE LESSON TEXT FOR 06-08 (WHEN WRITTEN) MUST INSTRUCT
// THE LEARNER TO RUN <USER>1/TXRESET AFTERWARD, exactly as 04-09's own
// cleanup section already requires for R0409A. Do not skip this: a
// stale ZAIKOM row will corrupt the checks that 06-07, 06-11b, and
// 06-15 rely on.
// ====================================================================
//
// WHAT CHANGED VS R0409A (same business rule, different mechanism):
//   R0409A declared ZAIKOM as a plain "UF E K DISK" file, used a
//   single CHAIN (which locks the record) to read it, COMP to check
//   for enough stock, then UPDAT. This program instead:
//     1. Declares ZAIKOM with the free-form dcl-f usage/keyed
//        keywords instead of F-spec column positions.
//     2. Receives the WHOLE record format as one data structure via
//        likerec (zaikomRec), instead of letting fields land in
//        separate implicit globals.
//     3. Builds the CHAIN key with %kds against a likerec(...:*key)
//        data structure, instead of a bare literal search argument.
//        ZAIKOM has exactly one key field (ZASHO), so a plain
//        literal search argument (as R0409A used) or a KLIST would
//        normally be simpler than %kds here; this program uses %kds
//        anyway to demonstrate the technique for files with more
//        than one key field, where %kds is the direct replacement
//        for RPG III's KLIST/KFLD.
//     4. Peeks with an UNLOCKED chain(n) first to decide NOTFOUND or
//        SHORT, and only takes the real (locking) CHAIN immediately
//        before the UPDATE. This is a deliberate improvement over
//        R0409A, which takes the lock on its single CHAIN and holds
//        it even on the SHORT path, all the way to *INLR. Because
//        another job could in theory change ZASU between the
//        unlocked peek and the locked re-read, this program
//        re-checks ZASU < QTY again immediately after the locked
//        CHAIN, before deducting.
//     5. Adds a WRITE + DELETE round trip against a disposable test
//        product code ('ZTEST1'), to demonstrate those two operations
//        (also new for this lesson) without touching any of the 6 real
//        products. runWriteDeleteDemo defaults to *on (real-hardware
//        fix, Part 6 source cleanup - it was *off and never actually
//        exercised WRITE/DELETE/%kds-DELETE/%fields in any prior
//        compile) - it is not needed to reproduce R0409A's OK/SHORT/
//        NOTFOUND result, but every normal run now demonstrates it
//        anyway; flip to *off to isolate the allocation logic alone.
//   Parity kept with R0409A: the SHORT test is strictly "less
//   than" (ZASU < QTY), matching R0409A's COMP ... LO test exactly;
//   the demo product/quantity are the same ('P00001', 2).
//
// FIELDS (source: db/v1/zaikom.pf, read directly on 2026-09-26 -
// this program does not hand-type these lengths; likerec pulls them
// from the DDS automatically, so a DDS change is picked up by
// recompiling, not by editing this source):
//   ZAIKOM (record format ZAIKOR), db/v1/zaikom.pf lines 1-5:
//     ZASHO   6A    Product code (key)   zaikom.pf:2, key: zaikom.pf:5
//     ZASU    7S 0  Stock quantity       zaikom.pf:3
//     ZAUPD   8S 0  Updated date YYYYMMDD zaikom.pf:4
//
// SYNTAX VERIFIED AGAINST work/design/refs/ilerpgref75.txt (the real
// IBM i 7.5 ILE RPG Language Reference, 73451 lines), 2026-09-26.
// likerec and %kds are the two least-common keywords/BIFs in this
// file, so they get the most detailed citations (highest-confidence
// section below); everything else is cited too.
//
//   likerec(recname) and likerec(recname : *key) - HIGH CONFIDENCE,
//   directly matched against a full worked example, not inferred:
//     lines 32522-32580: full rule text. Key points used here:
//       - *KEY "extracts just key fields" (lines 32535-32536), in
//         DDS key order.
//       - a data structure defined with LIKEREC is AUTOMATICALLY a
//         QUALIFIED data structure (line 32571-32572) - no
//         "qualified" keyword is written on zaikomRec/zaikomKey
//         below, on purpose, matching this rule.
//       - LIKEREC data structures are written as a single statement
//         with NO end-ds (line 29100-29104, "DCL-DS inputDs
//         LIKEREC(custFmt : *INPUT);").
//     THE key citation - a worked example built from the SAME
//     shape as this file (an externally described keyed DISK file,
//     a likerec(...:*key) data structure for the key, and a CHAIN
//     built from %kds), lines 46746-46800 (Figure 221): declares
//     "D custRecKeys DS LIKEREC(custRec : *key)", assigns
//     "custRecKeys.name = customer;" (qualified subfield access),
//     then "chain %kds(custRecKeys) custRec;" and
//     "chain %kds(custRecKeys : 2) custRec;" (both the
//     no-count and explicit-count forms). zaikomKey/zaikomRec below
//     are this same pattern with ZAIKOM's names substituted in.
//     Also: lines 22087-22145 (a second full worked example, "D
//     Keys DS LIKEREC(Rec1 : *KEY)" then "SETLL %KDS(Keys) Rec1;"
//     and "CHAIN %KDS(Keys : 2) Rec1 File1Flds;").
//   %kds(data-structure-name, optionally followed by a num-keys
//   parameter) - HIGH CONFIDENCE, same
//   citations as immediately above, plus the dedicated rule section
//   at lines 46713-46745 ("%KDS is allowed as the search argument
//   for any keyed Input/Output operation (CHAIN, DELETE, READE,
//   READPE, SETGT, SETLL)" - line 46717-46718, which is why this
//   file also uses %kds for the DELETE in the write/delete demo,
//   not only for CHAIN).
//   CHAIN(N) - the free-form "no lock" extender for an update disk
//   file, used here for the unlocked peek:
//     lines 53141-53147 (free-form syntax: CHAIN, an optional
//     extender group ENHMR in parens, then search-arg, name, and an
//     optional data-structure operand), lines 53188-53192 ("If you are
//     reading from an update disk file, you can specify an N
//     operation extender to indicate that no lock should be placed
//     on the record when it is read (e.g. CHAIN (N))."). Also notes
//     that CHAIN(N) is not valid at all against a pure *INPUT file
//     (line 53188: "all records are read without locks and so no
//     operation extender can be specified") - this is why ZAIKOM is
//     declared usage(*update:*delete:*output) below, not
//     usage(*input) (the *output part is for the WRITE demo, next).
//   UPDATE - "name" (the record format) plus a data-structure
//   operand together (update zaikor zaikomRec below), with
//   zaikomRec's default (unspecified) LIKEREC type, which is
//   explicitly allowed for UPDATE:
//     lines 65809-65867, esp. 65811 (free-form syntax: UPDATE, then
//     name, then an optional data-structure or %FIELDS operand -
//     "name" is REQUIRED, so this file never writes a bare "update
//     zaikomRec;") and 65835-65838 ("the data structure must be a
//     data structure defined from the same file or record format,
//     with *INPUT, *OUTPUT, or *ALL specified ... or no second
//     parameter specified for the LIKEREC keyword").
//   WRITE with a SEPARATE *ALL-typed likerec data structure
//   (zaikomOut, declared likerec(zaikor : *all)), used only by the
//   off-by-default demo:
//     lines 66329-66348, esp. 66339-66341 ("If name refers to a
//     record format from an externally described file, the data
//     structure must be a data structure defined with type
//     EXTNAME(...:*OUTPUT or *ALL) or LIKEREC(...:*OUTPUT or
//     *ALL)."). ZAIKOM's usage keyword must also include *OUTPUT for
//     WRITE to compile at all (lines 66372-66375).
//   DELETE with %kds as the search argument (no prior locked read
//   needed - this is why the demo below does not re-chain before
//   deleting):
//     lines 55181-55230, esp. 55198-55207 (search-arg forms,
//     including %kds) and 55212-55216 (name operand rules).
//   USAGE keyword (dcl-f) and its *UPDATE / *DELETE / *OUTPUT
//   values:
//     lines 28577-28604 (USAGE defaults and combining values, e.g.
//     "USAGE(*INPUT : *UPDATE)"); line 55190-55192 ("The file must
//     be an delete-capable file (identified by specifying *DELETE
//     in the USAGE keyword of a free-form definition ...)").
//   KEYED keyword (dcl-f), separately: lines 27634-27640 ("The
//   KEYED keyword is used in a free-form file definition to specify
//   that the file is to be opened in keyed sequence, and that keyed
//   file operations are allowed for the file. For an externally
//   described file, the KEYED keyword has no parameter." - matches
//   "keyed" with no parameter below, since ZAIKOM is externally
//   described via its DDS).
//   Free-form WRITE to a program-described PRINTER file needing a
//   data structure (not a standalone field) as its target - same
//   citation used in f0607s.rpgle: lines 41217-41218.
//
// %FIELDS (restricting UPDATE to specific fields) - used once, in the
// WRITE/DELETE demo below (update zaikor %fields(zaikomRec.zasu)):
// lines 45845-45876 (Figure 213, "update record %fields(salary:status);"
// - plain implicit fields, no DS) plus note 2 immediately above at
// lines 45857-45861 ("The name can be a subfield from a data structure
// defined with the EXTNAME/LIKEREC keyword ... For a qualified data
// structure, the simple qualified name of the subfield is used") -
// zaikomRec is exactly that shape (likerec(zaikor), auto-qualified), so
// zaikomRec.zasu is a valid %FIELDS name. The main allocation logic
// above still uses the whole-data-structure UPDATE form (zaikomRec),
// matching R0409A's own single UPDAT - %FIELDS is demonstrated only on
// the disposable ZTEST1 row so the two UPDATE styles are both shown
// without doubling the syntax count on the shared-data path.
//
// PUB400 placeholders: <USER>, <USER>1, <USER>2 stand for the
// learner's own library names; no real PUB400 user or library name
// appears in this file.
//======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f zaikom disk usage(*update : *delete : *output) keyed;
dcl-f qsysprt printer(132) usage(*output);

// The whole ZAIKOM record as one data structure (likerec is
// automatically QUALIFIED - see header - so subfields are written
// as zaikomRec.zasho, zaikomRec.zasu, zaikomRec.zaupd).
dcl-ds zaikomRec likerec(zaikor);

// Just the key field(s) of ZAIKOM, in DDS key order, for %kds.
// ZAIKOM has only ZASHO as a key (db/v1/zaikom.pf line 5), so this
// data structure ends up with a single subfield - see header for
// why %kds is still used here (technique demonstration for the
// general, multi-key-field case).
dcl-ds zaikomKey likerec(zaikor : *key);

// A second, *ALL-typed data structure of the same record, used only
// by the (off-by-default) WRITE/DELETE demo below - kept separate
// from zaikomRec so the main allocation logic above always uses an
// unambiguous *input-shaped buffer.
dcl-ds zaikomOut likerec(zaikor : *all);

dcl-s prod   char(6) inz('P00001');
dcl-s qty    packed(7:0) inz(2);
dcl-s msg    char(10);
dcl-s numTxt varchar(10);
dcl-s padded char(7);

// On by default: see header point 5. Flip to *off to isolate the
// allocation logic alone. Neither setting changes the OK/SHORT/NOTFOUND
// result below (they operate on disposable product code ZTEST1).
dcl-s runWriteDeleteDemo ind inz(*on);

// The WRITE operation to a program-described file (QSYSPRT here)
// must target a data structure, not a standalone field
// (ilerpgref75.txt lines 41217-41218, same citation used in
// f0607s.rpgle). A LEN-only DS with no subfields is used as a plain
// 132-byte buffer, matching the DCL-DS prtDs LEN(132) END-DS
// pattern shown at line 29046. CLEAR resets it to blanks each time
// (lines 53639-53652, same citation used in f0607s.rpgle).
dcl-ds line len(132) end-ds;

// ----------------------------------------------------------------
// Allocate QTY units of PROD from ZAIKOM, same three-way outcome as
// R0409A (NOTFOUND / SHORT / OK).
// ----------------------------------------------------------------
zaikomKey.zasho = prod;

// CLEAR before the first use of zaikomRec. Without INZ, a data
// structure's numeric subfields default-initialize to raw blanks,
// not zero (ilerpgref75.txt lines 31907-31916: "When neither the
// INZ keyword nor the CONST keyword is specified for the data
// structure, subfields that do not have the INZ keyword specified
// are initialized to blanks, regardless of their data type."). A
// failed CHAIN leaves the target data structure unchanged (line
// 41280-41282), so without this CLEAR, a NOTFOUND case (e.g. the
// same 'P99999' product code R0409A's own exercise 2 uses) would
// leave zaikomRec.zasu holding raw blanks, and %char() on that
// below would fail with a decimal-data error instead of printing
// NOTFOUND cleanly. CLEAR initializes by type (zero for numeric;
// lines 53649-53652), unlike the no-INZ default above.
clear zaikomRec;

// Unlocked peek (see header point 4): decide NOTFOUND/SHORT without
// ever taking a lock on the record.
chain(n) %kds(zaikomKey) zaikor zaikomRec;

if not %found(zaikom);
  msg = 'NOTFOUND';
elseif zaikomRec.zasu < qty;
  msg = 'SHORT';
else;
  // Looked sufficient on the unlocked peek above - now take the
  // real lock and re-check, in case another job changed ZASU
  // between the peek and this point. %kds(zaikomKey : 1) shows the
  // explicit num-keys form (ZAIKOM has exactly 1 key field).
  chain %kds(zaikomKey : 1) zaikor zaikomRec;
  if not %found(zaikom);
    // Extremely unlikely (would need another job to delete this
    // record between the unlocked peek above and this point), but
    // handled for safety rather than assumed away.
    msg = 'NOTFOUND';
  elseif zaikomRec.zasu < qty;
    msg = 'SHORT';
  else;
    zaikomRec.zasu -= qty;
    update zaikor zaikomRec;
    msg = 'OK';
  endif;
endif;

// ----------------------------------------------------------------
// Print, in the same left-to-right field order as R0409A's O-specs
// (PROD, ZASU, MSG). Column positions match R0409A's O-spec end
// columns (6 / 15 / 27) exactly, so this line should be directly
// comparable to R0409A's spool output.
// ----------------------------------------------------------------
clear line;
%subst(line:1:6) = prod;

// Zero-pad ZASU to 7 digits (e.g. "0000043"), matching R0409A's
// unedited numeric O-spec output. %CHAR alone would give "43"
// without the leading zeros the original spool file shows (same
// technique as f0607s.rpgle's report line, verified there against
// no exotic edit-code assumptions).
numTxt = %char(zaikomRec.zasu);
if %len(numTxt) < 7;
  padded = %subst('0000000' : 1 : 7 - %len(numTxt)) + numTxt;
else;
  padded = numTxt;
endif;
%subst(line:9:7) = padded;

%subst(line:18:10) = msg;
write qsysprt line;

// ----------------------------------------------------------------
// Optional WRITE/DELETE demonstration (see header point 5 and
// runWriteDeleteDemo above). Uses product code 'ZTEST1', which does
// not collide with the real P00001-P00006 products, so the shared
// ZAIKOM table ends this run with the same rows it had before -
// still run TXRESET afterward regardless (see the warning banner).
// ----------------------------------------------------------------
if runWriteDeleteDemo;
  zaikomOut.zasho = 'ZTEST1';
  zaikomOut.zasu  = 999;
  zaikomOut.zaupd = 20260926;
  write zaikor zaikomOut;

  zaikomKey.zasho = 'ZTEST1';
  chain %kds(zaikomKey) zaikor zaikomRec;
  if %found(zaikom);
    zaikomRec.zasu = 500;
    // %FIELDS: update ZASU alone, leaving ZAUPD (already 20260926 from
    // the WRITE above) untouched - contrast with the main allocation
    // logic's whole-data-structure UPDATE (see header note).
    update zaikor %fields(zaikomRec.zasu);
  endif;

  // %kds also works as the search argument for DELETE (see header
  // citation for lines 46717-46718), so no extra CHAIN is needed
  // just to locate the record to delete.
  delete %kds(zaikomKey) zaikor;
endif;

*inlr = *on;
return;
