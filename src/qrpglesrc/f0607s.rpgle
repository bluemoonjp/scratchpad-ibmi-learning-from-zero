**FREE
//======================================================================
// F0607A - **FREE rewrite of R0413A (04-13 checkpoint: "product-wise
// stock list", see docs/part04/04-13-checkpoint-stock-list.md and
// src/qrpgsrc/r0413s.rpg). Written for lesson 06-07 (data structures
// and arrays).
//
// STATUS: hardware-UNTESTED as of 2026-09-26. This source has NOT
// been compiled or run on PUB400. Treat every behavior described
// below as unverified (docs/style-guide.md V1/V2/V3 scale) until a
// real CRTBNDRPG + CALL session updates this header with a result.
//
// WHAT CHANGED VS R0413A (same business rule, different mechanism):
//   R0413A made ZAIKOM the RPG-cycle primary file (keyed, "IP") and
//   used CHAIN SHOHIM (keyed) once per ZAIKOM record, then COMP
//   SHOHAT to flag LOWSTOCK. This program has no cycle and no
//   primary file. Instead it:
//     1. Reads SHOHIM and ZAIKOM in full into two arrays of
//        qualified data structures: prod (SHOHIM) with a plain,
//        fixed dim(50) and its own manual row counter (nProd), and
//        stock (ZAIKOM) with dim(*auto:50), which tracks its own
//        current count. Both styles are shown deliberately, so this
//        lesson demonstrates plain dim as well as dim(*auto).
//     2. For each stock row, uses %LOOKUP against the SHOHIM array
//        (searched by SHOCD) to find the matching product - this is
//        the array-based replacement for "CHAIN SHOHIM".
//     3. Applies the SAME low-stock test as R0413A (ZASU < SHOHAT,
//        strictly less than) while building a third array of one
//        summary row per product.
//     4. Because native keyed access was traded for an array plus
//        %LOOKUP, product-code order is no longer free (R0413A got
//        it for free from ZAIKOM's keyed primary-file cycle). SORTA
//        restores that same product-code order before printing.
//   Deliberate deviation from R0413A: on a %LOOKUP miss (product
//   code not found in SHOHIM), this program clears the name and
//   reorder point to blanks/zero. R0413A's CHAIN-not-found path
//   (indicator 50) does not clear SHONM/SHOHAT, so a miss there
//   would silently print stale data left over from the previous
//   ZAIKOM record. In practice neither miss path is expected to
//   trigger against the current sample data (04-13 confirms all 6
//   ZAIKOM codes match a SHOHIM row).
//
// FIELDS (source: db/v1/shohim.pf and db/v1/zaikom.pf, read directly
// on 2026-09-26 - this program does not hand-type these lengths; it
// pulls them from the DDS via EXTNAME, so a DDS change is picked up
// by recompiling, not by editing this source):
//   SHOHIM (record format SHOHIR), db/v1/shohim.pf lines 1-6:
//     SHOCD   6A    Product code (key)   shohim.pf:2, key: shohim.pf:6
//     SHONM  30A    Product name         shohim.pf:3
//     SHOTNK  7S 2  Unit price           shohim.pf:4
//     SHOHAT  5S 0  Reorder point        shohim.pf:5
//   ZAIKOM (record format ZAIKOR), db/v1/zaikom.pf lines 1-5:
//     ZASHO   6A    Product code (key)   zaikom.pf:2, key: zaikom.pf:5
//     ZASU    7S 0  Stock quantity       zaikom.pf:3
//     ZAUPD   8S 0  Updated date YYYYMMDD zaikom.pf:4
//
// SYNTAX VERIFIED AGAINST work/design/refs/ilerpgref75.txt (the real
// IBM i 7.5 ILE RPG Language Reference, 73451 lines), 2026-09-26:
//   QUALIFIED data structures, and DIM requiring QUALIFIED:
//     lines 15517-15521, 15599, 30608-30611.
//   EXTNAME(file:extract-type) as a data structure keyword, the
//   2-parameter form that skips format-name, EXTNAME as the
//   required FIRST keyword, and END-DS required for an EXTNAME DS
//   (LIKEDS/LIKEREC skip END-DS, EXTNAME does not):
//     lines 31237-31305 (rule text and the *INPUT/*ALL requirement
//     for I/O use - a DS with NO extract-type specified is
//     explicitly NOT usable for I/O, per line 31305, so *input is
//     given explicitly below); line 32728 and line 56461
//     ("extname(evalcorrpf : *input)") for the 2-parameter form;
//     lines 29051-29054 ("DCL-DS extds1 EXTNAME('MYFILE') END-DS;")
//     for keyword order and END-DS.
//   A concrete worked example combining EXTNAME(...: *input),
//   QUALIFIED, LIKEDS, and a READ loop almost identical to the one
//   in this program (just renamed): lines 56457-56479 (pf_ds /
//   pf_save_ds / "read pfrec pf_ds; dow not %eof; ...").
//   This program reads by FILE name ("read shohim shohimRow;"),
//   not by record-format name. Confirmed allowed for a data
//   structure with no format-name given, in the special case where
//   the file has only one record format (true for both SHOHIM and
//   ZAIKOM - each file's DDS declares exactly one "R" record): lines
//   41250-41256 ("A result data structure may be specified for an
//   I/O operation to an externally described file name ... In the
//   special case where the file contains only one record, the
//   result data structure may be defined as in rule 1.").
//   TEMPLATE keyword (compile-time-only shape, usable only via
//   LIKE/LIKEDS, no storage of its own):
//     lines 35188-35219 (rule text and the employee_type /
//     standardName worked example this file's sumRow_t follows).
//   LIKEDS(...) to instantiate real storage from an EXTNAME'd row
//   or from a TEMPLATE, including DIM combined with LIKEDS:
//     lines 3300-3312 and 3556-3576 (custDs/custArray: the READ-loop
//     + array-append pattern this file's prod/stock arrays follow);
//     line 13426 (LIKEDS of a TEMPLATE).
//   Plain DIM(numeric_constant) - a fixed-size array (prod, above):
//     line 30594 (syntax: DIM(numeric_constant), separate from the
//     DIM(*AUTO:...) / DIM(*VAR:...) / DIM(*CTDATA) forms), and
//     lines 31915-31916 for why prod's unused tail slots cannot be
//     trusted to read as zero (cited again in the declaration
//     comment above).
//   DIM(*auto:max) varying-dimension arrays (stock/sumline, above)
//   and the (*next) index to grow one on assignment:
//     lines 30636-30661 (rule text), lines 30707-30722 (worked
//     example), lines 30685-30705 (restrictions - none of which
//     apply to a top-level data structure array).
//   %LOOKUP against a qualified array DS via DS(*).SUBFIELD, with
//   explicit start-index/number-of-elements (used here so the
//   search is always bounded to the array's CURRENT element count,
//   not its dim(*auto) maximum - ilerpgref75.txt does not explicitly
//   say whether the no-count form defaults to current vs. maximum
//   for a varying-dimension array, so this program does not rely on
//   that default; TODO: verify the no-count default if this ever
//   matters for a differently-shaped array):
//     lines 47175-47186 (signature, incl. start_index/number_of_
//     elements), 47268-47276 (DS(*).SUBFIELD rule), 47207 and 47286
//     (returns 0 on a miss; does NOT set %FOUND - checked with
//     "idx > 0" below, never used as an array index on its own).
//   SORTA on a qualified array DS via DS(*).SUBFIELD, wrapped in
//   %SUBARR with an explicit start/count for the same
//   current-vs-maximum reason as %LOOKUP above:
//     lines 64300-64346 (SORTA syntax, incl. the %SUBARR(keyed-ds-
//     array : start : count) form), 15550-15570 (worked FAMILIES
//     example this file's sumline sort follows).
//
// This program is read-only against SHOHIM and ZAIKOM (matches
// R0413A's own cleanup note: both files are input-only here). It
// does not need TXRESET.
//
// PUB400 placeholders: <USER>, <USER>1, <USER>2 stand for the
// learner's own library names; no real PUB400 user or library name
// appears in this file.
//======================================================================

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-f shohim disk;
dcl-f zaikom disk;
dcl-f qsysprt printer(132) usage(*output);

// One row of SHOHIM / ZAIKOM, shaped straight from the DDS via
// EXTNAME (see header for exact source lines - no hand-typed
// lengths here). QUALIFIED so DIM (below, on the arrays built from
// these) and the DS(*).SUBFIELD syntax used by %LOOKUP/SORTA are
// legal, and so the two files' fields never collide by name even
// if a future DDS change gave them a same-named column.
dcl-ds shohimRow extname('SHOHIM' : *input) qualified end-ds;
dcl-ds zaikomRow extname('ZAIKOM' : *input) qualified end-ds;

// One printed line of the report: product code, name, on-hand
// quantity, reorder point, and a low-stock flag. Not tied to any
// file, so this is a hand-built TEMPLATE (compile-time shape only -
// see header). LIKEDS below turns it into real storage, once for a
// one-row scratch variable and once for the whole report array.
// Subfield types are borrowed with LIKE() from the DDS-derived rows
// above so a length never has to be hand-typed twice.
dcl-ds sumRow_t qualified template;
  shocd    like(shohimRow.shocd);
  shonm    like(shohimRow.shonm);
  zasu     like(zaikomRow.zasu);
  shohat   like(shohimRow.shohat);
  lowstock ind;
end-ds;

// prod uses plain dim(50): a fixed-size array (DIM(numeric_constant)
// - ilerpgref75.txt line 30594). With a plain dim, THIS PROGRAM must
// track how many of the 50 slots actually hold a row (nProd, below)
// - the unused tail slots are not automatically "empty": a data
// structure array element that is never assigned keeps whatever its
// no-INZ default gave it, which for a numeric subfield is raw blanks,
// not zero (lines 31915-31916 - the same fact that makes "clear"
// necessary elsewhere in this lesson's f0608s.rpgle). %elem(prod)
// would report 50 here, not "how many rows were loaded", so every
// %LOOKUP against prod() below is bounded by nProd explicitly, never
// by %elem(prod).
//
// stock and sumline use dim(*auto:50) instead: each grows on its own
// as rows are actually appended with (*next), and %elem() always
// reports the CURRENT count for these two (see the %LOOKUP/SORTA
// citations further up) - no separate counter field is needed for
// them. 50 is just a safe ceiling for these small exercise tables.
dcl-ds prod    likeds(shohimRow) dim(50);
dcl-ds stock   likeds(zaikomRow) dim(*auto:50);
dcl-ds sumRow  likeds(sumRow_t);
dcl-ds sumline likeds(sumRow_t) dim(*auto:50);

dcl-s i      int(10);
dcl-s idx    int(10);      // %LOOKUP result: 0 = product code not found
dcl-s nProd  int(10);      // how many of prod()'s 50 slots are used
dcl-s numTxt varchar(10);
dcl-s padded char(7);

// The WRITE operation to a program-described file (QSYSPRT here)
// must target a data structure, not a standalone field
// (ilerpgref75.txt lines 41217-41218: "The WRITE and UPDATE
// operations that specify a program described file name ... must
// have a data structure name specified in the result field."). A
// LEN-only DS with no subfields (matching the DCL-DS prtDs LEN(132)
// END-DS pattern at line 29046) is used as a plain 132-byte buffer;
// CLEAR resets it to blanks each time (lines 53639-53652: CLEAR
// resets a structure or variable to its type's default
// initialization value, blanks for character data).
dcl-ds line len(132) end-ds;

// ----------------------------------------------------------------
// 1. Load SHOHIM (product master) into the prod() array. prod is a
//    fixed dim(50) array (see declaration above), so this loop
//    tracks the row count itself in nProd instead of using (*next)
//    ((*next) only applies to a dim(*auto)/dim(*var) array).
// ----------------------------------------------------------------
read shohim shohimRow;
dow not %eof(shohim);
  nProd += 1;
  prod(nProd) = shohimRow;
  read shohim shohimRow;
enddo;

// ----------------------------------------------------------------
// 2. Load ZAIKOM (stock) into the stock() array.
// ----------------------------------------------------------------
read zaikom zaikomRow;
dow not %eof(zaikom);
  stock(*next) = zaikomRow;
  read zaikom zaikomRow;
enddo;

// ----------------------------------------------------------------
// 3. For each stock row, find its product with %LOOKUP - the
//    array-based replacement for R0413A's "CHAIN SHOHIM". A miss
//    (idx = 0) is handled explicitly (see header "deliberate
//    deviation").
// ----------------------------------------------------------------
for i = 1 to %elem(stock);
  idx = %lookup(stock(i).zasho : prod(*).shocd : 1 : nProd);

  sumRow.shocd = stock(i).zasho;
  if idx > 0;
    sumRow.shonm  = prod(idx).shonm;
    sumRow.shohat = prod(idx).shohat;
  else;
    sumRow.shonm  = *blanks;
    sumRow.shohat = 0;
  endif;
  sumRow.zasu = stock(i).zasu;

  // Same test as R0413A's "COMP SHOHAT" with the LO (low) result
  // indicator: stock strictly below the reorder point is low.
  sumRow.lowstock = (sumRow.zasu < sumRow.shohat);

  sumline(*next) = sumRow;
endfor;

// ----------------------------------------------------------------
// 4. R0413A printed in product-code order for free, because ZAIKOM
//    was a keyed primary file processed by the RPG cycle. This
//    version gave up native keyed access for array + %LOOKUP, so it
//    must sort the summary array back into that same order before
//    printing.
// ----------------------------------------------------------------
sorta %subarr(sumline(*).shocd : 1 : %elem(sumline));

// ----------------------------------------------------------------
// 5. Print, in the same left-to-right field order as R0413A's
//    O-specs (ZASHO, SHONM, ZASU, conditional LOWSTOCK). Column
//    positions below are a best-effort visual match to the O-spec
//    layout, not a byte-verified reproduction (exact columns matter
//    for 06-15's checkpoint, not for this lesson).
// ----------------------------------------------------------------
for i = 1 to %elem(sumline);
  clear line;
  %subst(line:3:6)   = sumline(i).shocd;
  %subst(line:13:30) = sumline(i).shonm;

  numTxt = %char(sumline(i).zasu);
  if %len(numTxt) < 7;
    padded = %subst('0000000' : 1 : 7 - %len(numTxt)) + numTxt;
  else;
    padded = numTxt;
  endif;
  %subst(line:49:7) = padded;

  if sumline(i).lowstock;
    %subst(line:63:8) = 'LOWSTOCK';
  endif;

  write qsysprt line;
endfor;

// ----------------------------------------------------------------
// Bonus demonstration (not part of R0413A): %LOOKUP used standalone
// to find one product by code, instead of walking the whole array.
// P00002 is the office chair that 04-13 confirmed is LOWSTOCK
// (stock 3, reorder point 5; see docs/part04/04-13-checkpoint-
// stock-list.md). Printed to QSYSPRT (not DSPLY, which only works
// interactively and, in a non-interactive/batch run, would land on
// QSYSOPR - a message target docs/style-guide.md's "PUB400 manners"
// section forbids sending to). This adds ONE extra spool line
// beyond R0413A's own six-product report, clearly labeled BONUS.
// ----------------------------------------------------------------
idx = %lookup('P00002' : prod(*).shocd : 1 : nProd);
clear line;
%subst(line:1:30) = 'BONUS: LOOKUP P00002 -> INDEX';
numTxt = %char(idx);
%subst(line:32:%len(numTxt)) = numTxt;
if idx = 0;
  %subst(line:32:9) = '(not fnd)';
endif;
write qsysprt line;

*inlr = *on;
return;
