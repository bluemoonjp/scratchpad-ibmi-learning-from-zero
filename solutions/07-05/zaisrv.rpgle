**FREE
//=======================================================================
// ZAISRV - stock allocation SERVICE PROGRAM (*SRVPGM). Part 7
// checkpoint, lesson 07-05. Three exported procedures: get (unlocked
// peek), reserve (locking allocate), release (locking give-back, new
// logic). See solutions/07-05/zaisrv.bnd for the matching binder
// source and build recipe, and solutions/07-05/driver.rpgle for the
// test driver that exercises all three.
//
// STATUS: hardware-UNTESTED as of 2026-09-26 (docs/style-guide.md
// V1/V2/V3 scale - nothing in this file has been compiled or run).
// Nothing in Part 6 or Part 7 is hardware-tested yet at this point in
// the repo's history. Treat every behavior below as unverified until a
// real CRTRPGMOD + CRTSRVPGM + CALL session updates this header.
//
// ====================================================================
// WARNING: THIS SERVICE PROGRAM MUTATES THE SHARED ZAIKOM TABLE.
// ZAIKOM is the SAME physical file that R0409A (04-09) and F0608A
// (06-08) already write to, and that 04-13's checkpoint, 06-07's
// exercise, 06-11b, and 06-15's checkpoint all READ and depend on
// having known values (f0608s.rpgle's own header states this same
// dependent list verbatim - 06-11b is a DEPENDENT reader here, not a
// writer of ZAIKOM; it writes a DIFFERENT shared table, SHOHIM - see
// f0611bs.rpgle lines 9-11/137). reserve() and release() below both
// call UPDATE against ZAIKOM's ZASU field, exactly like F0608A's own
// mainline does.
//
// THE 07-05 LESSON TEXT (WHEN WRITTEN) MUST INSTRUCT THE LEARNER TO
// RUN <USER>1/TXRESET after exercising reserve()/release(), in ALL
// THREE of its exercise, self-check, and cleanup sections (enshu /
// serufuchekku / katazuke in the lesson's own Japanese headings) -
// matching the house-style precedent at
// docs/part04/04-09-update-lock.md (explicit exercise-section
// instruction to run TXRESET + a self-check checkbox for it + a
// cleanup note), and exactly as 04-09/06-08/06-11b's own source headers
// already require for this same shared table. THIS WARNING IS WRITTEN
// HERE, PROMINENTLY, SO A FUTURE LESSON-WRITER BUILDING 07-05'S PROSE
// FROM THIS SOURCE CANNOT MISS IT - do not remove or bury it.
// ====================================================================
//
// WHAT THIS PORTS FROM F0608A (src/qrpglesrc/f0608s.rpgle, "ZAHIK4",
// 06-08) AND WHAT IS NEW:
//   get()     - F0608A's OUTER, UNLOCKED chain(n) peek, lines 230
//               (key assignment), 245 (clear before first use), 249
//               (the chain(n) itself), and 251 (the %found test - not
//               F0608A's lines 252-254, which compare against a QTY
//               this procedure does not take; get() has no qty
//               parameter, per its signature below, so it can only
//               report NOTFOUND-or-not, never SHORT).
//   reserve() - F0608A's INNER, LOCKING chain-then-UPDATE block, lines
//               260-272 verbatim in structure, with ONE addition: an
//               explicit UNLOCK on the SHORT branch only (line
//               266-267 in F0608A). See reserve()'s own header below
//               for the full reasoning - this is the corrected,
//               NARROW fix from work/design/part07-design-v1.md's
//               07-05 entry (an earlier draft of that design said
//               "SHORT/NOTFOUND branches generally", which adversarial
//               review found too broad; only this one branch ever
//               takes a lock in the first place).
//   release() - NOT in F0608A at all. New logic, built by symmetry
//               with reserve() (same locking discipline, opposite
//               arithmetic). See release()'s own header below for why
//               this introduces no new syntax/technique.
//
// FIELDS (source: db/v1/zaikom.pf, read directly on 2026-09-26, same
// as F0608A's own header - likerec pulls these from the DDS
// automatically, not hand-typed):
//   ZAIKOM (record format ZAIKOR), db/v1/zaikom.pf lines 1-5:
//     ZASHO   6A    Product code (key)   zaikom.pf:2, key: zaikom.pf:5
//     ZASU    7S 0  Stock quantity       zaikom.pf:3
//     ZAUPD   8S 0  Updated date YYYYMMDD zaikom.pf:4
//
// USAGE differs from F0608A on purpose: F0608A declares ZAIKOM with
// usage(*update:*delete:*output) because its own file also has an
// off-by-default WRITE/DELETE demo (see f0608s.rpgle lines 300-324).
// None of get()/reserve()/release() below ever add or remove a ZAIKOM
// row - only CHAIN and UPDATE against existing rows - so this file
// declares usage(*update) only. Narrower on purpose, not an oversight.
//
// SYNTAX CITATIONS (work/design/refs/ilerpgref75.txt, IBM i 7.5 ILE
// RPG Language Reference, 73451 lines, read directly 2026-09-26):
//   likerec/likerec(...:*key)/%kds/CHAIN(N)/UPDATE/KEYED/USAGE - all
//   IDENTICAL techniques to F0608A's own, already cited in exhaustive
//   detail in that file's header (f0608s.rpgle lines 80-166). Not
//   re-quoted here in full to avoid duplicating that citation work;
//   see that file directly for the line numbers if needed. The one
//   NEW element relative to F0608A is UNLOCK, cited in full in
//   reserve()'s own header below.
//   NOMAIN (ctl-opt, below): lines 6975-6976 ("NOMAIN Indicates that
//   the module has only subprocedures") and the free-form worked
//   example at lines 38552-38556/38564-38567/38577-38579 ("CTL-OPT
//   NOMAIN; DCL-PROC PROC1 EXPORT; END-PROC;" - this file's own
//   ctl-opt/dcl-proc...export shape matches this exactly).
//   Default EXPORT SYMBOL casing for a dcl-proc with no EXTPROC
//   keyword at all (resolves work/design/part07-design-v1.md section
//   9 item 5, which flagged this as unconfirmed against
//   ileconcepts75.txt's EXPORT SYMBOL examples alone - this file
//   instead found the rule in ilerpgref75.txt's EXTPROC section):
//   lines 31322-31324 ("If neither EXTPGM or EXTPROC is specified for
//   a prototype, then the compiler assumes ... and assigns the
//   external procedure name to be the upper-case form of the
//   prototype name"), 31334-31336 (same rule stated for a bare EXTPROC
//   keyword on a procedure interface), and 31381-31383 (same rule
//   restated a third time, for "neither EXTPGM or EXTPROC ... assigns
//   it the upper-case form of ... the name of the procedure"). None
//   of get/reserve/release below specify EXTPROC or a separate dcl-pr
//   prototype at all, so this file relies on this default: the
//   exported symbols are GET, RESERVE, RELEASE (upper case), matching
//   solutions/07-05/zaisrv.bnd's EXPORT SYMBOL('GET') etc. TODO:
//   verify against a real compile (DSPSRVPGM / the binder listing)
//   that this default still applies with no dcl-pr present anywhere
//   in the module - the three citations above describe "a prototype"
//   or "a procedure interface" specifically, and this file has
//   neither for these three procedures (only dcl-proc + dcl-pi), so
//   the exact wording is not a byte-for-byte match to this file's
//   shape. Treat as high-confidence, not hardware-confirmed.
//
// BUILD RECIPE (two-step: CRTRPGMOD then CRTSRVPGM - a *SRVPGM cannot
// be produced by CRTBNDRPG, which only ever creates a *PGM; verified
// by grepping work/design/refs/cl_commands_75.txt's own CRTBNDRPG
// parameter table, which has no SRVPGM-shaped output at all):
//   CRTRPGMOD MODULE(<lib>/ZAISRV) SRCFILE(<lib>/QRPGLESRC)
//     SRCMBR(ZAISRV)
//   CRTSRVPGM SRVPGM(<lib>/ZAISRV) MODULE(<lib>/ZAISRV)
//     EXPORT(*SRCFILE) SRCFILE(<lib>/QSRVSRC) SRCMBR(ZAISRV)
//     ACTGRP(*CALLER)
// ACTGRP(*CALLER) is written explicitly, not left to default, per
// work/design/refs/cl_commands_75.txt's CRTSRVPGM parameter table
// (ACTGRP: "Name , *CALLER") and description ("*CALLER - When this
// service program gets called, the service program is activated into
// the caller's activation group", read directly this session). This
// is exactly the rule solutions/07-05/driver.rpgle's own header relies
// on for its "same activation group across repeated calls" reasoning
// - see that file for the full discussion. <lib> is a placeholder for
// the learner's own library (see docs/style-guide.md - never a real
// PUB400 library/user name in source).
//
// PUB400 placeholders: <USER>, <USER>1, <USER>2, <lib> stand for the
// learner's own library/user names; no real PUB400 user or library
// name appears in this file.
//=======================================================================

ctl-opt nomain;

dcl-f zaikom disk usage(*update) keyed;

// The whole ZAIKOM record as one data structure (likerec is
// automatically QUALIFIED, same as F0608A - subfields are written as
// zaikomRec.zasho / .zasu / .zaupd).
dcl-ds zaikomRec likerec(zaikor);

// Just the key field (ZASHO) of ZAIKOM, for %kds - same technique
// demonstration reasoning as F0608A (ZAIKOM has only one key field,
// but %kds is used anyway; see f0608s.rpgle's header for why).
dcl-ds zaikomKey likerec(zaikor : *key);

//=======================================================================
// get: UNLOCKED peek at PROD's current stock quantity. Faithful port
// of F0608A's OUTER unlocked chain(n) peek (src/qrpglesrc/f0608s.rpgle
// lines 230, 245, 249, 251) - NOT F0608A's inner locking chain (that
// is reserve()'s job, below). CHAIN(N) never takes a record lock (see
// f0608s.rpgle's own CHAIN(N) citation, lines 113-125 of that file),
// so this procedure never needs an UNLOCK.
//
// Returns the current ZASU value, or -1 if prodCode does not exist in
// ZAIKOM. -1 is a safe sentinel: ZASU is packed(7:0) and this table's
// business meaning never has negative stock (0 is a valid real
// quantity - out of stock - so 0 cannot be the sentinel).
//=======================================================================
dcl-proc get export;
  dcl-pi *n packed(7:0);
    prodCode char(6) const;
  end-pi;

  zaikomKey.zasho = prodCode;

  // CLEAR before first use, same reasoning as f0608s.rpgle lines
  // 232-244 (a data structure's numeric subfields default to raw
  // blanks, not zero, without INZ or CLEAR). Not strictly load-bearing
  // in THIS procedure, since zaikomRec.zasu is only read below inside
  // the %found branch (a successful chain always refreshes it first)
  // - kept anyway for consistency with the ported source and as
  // defense-in-depth against a future edit that reads zaikomRec
  // outside that guard.
  clear zaikomRec;

  chain(n) %kds(zaikomKey) zaikor zaikomRec;

  if %found(zaikom);
    return zaikomRec.zasu;
  else;
    return -1;
  endif;
end-proc;

//=======================================================================
// reserve: the REAL, LOCKING allocation. Faithful port of F0608A's
// INNER locking-chain-then-UPDATE block, src/qrpglesrc/f0608s.rpgle
// lines 260-272 - the block that in F0608A runs only after its own
// outer unlocked peek already looked sufficient. This procedure does
// NOT repeat that peek (no call to get() from inside here) - it always
// takes the real lock directly and re-checks the quantity itself. That
// re-check IS F0608A's own "re-check ZASU < QTY again immediately
// after the locked CHAIN, in case another job changed ZASU between the
// peek and this point" (f0608s.rpgle lines 256-259) - there is no
// separate peek-then-recheck step here because this procedure's one
// locking chain already IS the authoritative check.
//
// Returns *on if QTY units were actually deducted from PROD's ZASU
// (F0608A's "OK" outcome). Returns *off for BOTH of F0608A's failure
// outcomes (SHORT: found but insufficient stock; NOTFOUND: no such
// PROD) - a caller that needs to tell these apart should call get()
// first (a -1 result distinguishes NOTFOUND from a real, insufficient
// ZASU value).
//
// *** UNLOCK - the one addition this *SRVPGM needs beyond F0608A ***
// F0608A's own inner CHAIN (lines 260-272) never released the lock it
// took on the SHORT branch (line 266-267) - harmless there, because
// F0608A is a one-shot *PGM compiled dftactgrp(*no) actgrp(*new): its
// *inlr=*on triggers a normal RPG-cycle return, which (a) closes the
// files F0608A itself opened, as normal end-of-program processing
// always does, and (b) - since F0608A is the OLDEST call stack entry
// of its own system-named activation group - also DELETES that whole
// activation group outright (work/design/refs/ileconcepts75.txt lines
// 1791-1801, read directly this session: "for the system-named
// activation group (created with the ACTGRP(*NEW) option), a normal
// return from P1 deletes the associated activation group", where P1
// is "the oldest call stack entry"). Either mechanism alone would
// already release F0608A's lock; both happen together in practice.
//
// This procedure, running inside ZAISRV, NEVER reaches *inlr - a
// nomain module has no RPG cycle to end - and ZAISRV itself is
// CRTSRVPGM'd with ACTGRP(*CALLER) (see zaisrv.bnd's header), so it
// has no activation-group boundary of its own at all: it activates
// into WHATEVER activation group its caller established, and the
// ZAIKOM file this module opens stays open, and any lock it holds
// stays held, for exactly as long as THAT activation group instance
// lives - not just until this one procedure call returns. How long
// that actually is depends entirely on the CALLER's own choice, not
// on anything in this file: a caller compiled ACTGRP(*NEW) (a
// system-named group, like F0608A's own convention) has its group
// deleted the moment THAT caller returns normally (same citation as
// above); a caller compiled with a USER-NAMED ACTGRP(name) instead
// leaves its group in the job "for later use" until an explicit
// RCLACTGRP or job end (same ileconcepts75.txt passage, lines
// 1791-1792). See solutions/07-05/driver.rpgle's own header for the
// concrete case this repo actually builds and exercises. Either way,
// a lock left on the SHORT branch persists past the single reserve()
// call that created it, which is the reason this fix is needed at
// all - just not necessarily "for the rest of the job", as an earlier
// draft of this comment overclaimed before this session verified the
// *NEW-vs-named distinction against ileconcepts75.txt directly.
//
// Per work/design/part07-design-v1.md's 07-05 entry (the corrected,
// NARROWED version - an earlier draft said "SHORT/NOTFOUND branches
// generally", which adversarial review found too broad), only ONE
// branch below ever actually holds a lock: the SHORT branch
// immediately below (found by the locking CHAIN, but insufficient
// stock). The NOTFOUND branch (elseif not %found) takes NO lock at
// all - a failed CHAIN locks nothing, same reasoning as
// src/qrpglesrc/f0611bs.rpgle's own comment ("Not found -> the failed
// CHAIN took no lock at all... nothing to release here", lines
// 235-237 of that file) - so it gets no UNLOCK here, matching that
// file's discipline exactly. The OK branch's UPDATE consumes/releases
// its own lock automatically (f0611bs.rpgle's header, "a successful
// UPDATE or DELETE consumes/releases it"), so it needs no UNLOCK
// either. UNLOCK therefore appears EXACTLY ONCE below, on the SHORT
// branch only.
//
// UNLOCK syntax verified against work/design/refs/ilerpgref75.txt
// lines 65693-65761 ("UNLOCK (Unlock a Data Area or Release a
// Record)"; free-form syntax "UNLOCK{(E)} name", line 65695; and
// "Releasing record locks... name must be the name of the UPDATE disk
// file", lines 65758-65761) and cross-checked against the actual call
// sites that use it in this repo - src/qrpglesrc/f0611bs.rpgle lines
// 232, 275, and 303, all "unlock shohim;" (shohim is the FILE name
// there, not the record format name SHOHIR/SHOHIM's record format -
// zaikom below is this same file-name argument, for ZAIKOM). This
// repo's own part07 design doc originally cited f0611s.rpgle for this
// technique; that was wrong (f0611s.rpgle only mentions UNLOCK in a
// comment - it never calls it). f0611bs.rpgle is the file that
// actually calls UNLOCK, and is the one read and cited here.
//
// TODO: verify - "is calling UNLOCK on a record that is not currently
// locked harmless?" is NOT confirmed by the UNLOCK reference text
// above (that text describes releasing a lock that exists; it does
// not say what happens if none does). This procedure sidesteps the
// question entirely rather than relying on an answer: UNLOCK is
// called ONLY on the one branch below that is certain to hold a lock
// (the locking CHAIN just above it succeeded), never on a branch that
// might or might not hold one.
//=======================================================================
dcl-proc reserve export;
  dcl-pi *n ind;
    prodCode char(6) const;
    qty      packed(7:0) const;
  end-pi;

  dcl-s ok ind inz(*off);

  zaikomKey.zasho = prodCode;
  clear zaikomRec;   // same defense-in-depth note as get(), above.

  chain %kds(zaikomKey : 1) zaikor zaikomRec;
  if not %found(zaikom);
    // Not-found CHAIN takes no lock - nothing to release. See header.
    ok = *off;
  elseif zaikomRec.zasu < qty;
    // Found AND locked, but insufficient stock - the ONE branch that
    // actually holds a lock without an UPDATE to consume it. Release
    // it explicitly before returning failure (see header - this is
    // the fix this *SRVPGM adds beyond F0608A).
    unlock zaikom;
    ok = *off;
  else;
    zaikomRec.zasu -= qty;
    update zaikor zaikomRec;   // UPDATE consumes/releases the lock -
                                // see f0611bs.rpgle's header note,
                                // cited above.
    ok = *on;
  endif;

  return ok;
end-proc;

//=======================================================================
// release: give QTY units of PROD back to ZAIKOM. NOT present in
// F0608A - new logic, built for ZAISRV by SYMMETRY with reserve()
// above: the same locking discipline (a single locking CHAIN
// immediately before an UPDATE - reserve()'s own pattern, and
// F0608A's own established pattern before that), with the opposite
// arithmetic (+= instead of -=). Per work/design/part07-design-v1.md's
// 07-05 entry ("shinshutsu nashi" / no new syntax), this procedure
// introduces NOTHING beyond what F0608A and reserve()/get() above
// already established: CHAIN with %kds, %found, UPDATE with a likerec
// data structure. Confirmed by inspection: no keyword or BIF appears
// below that is not already used in get()/reserve() above or in
// f0608s.rpgle itself.
//
// UNLOCK is deliberately NOT called anywhere in this procedure. Unlike
// reserve(), release() has only two outcomes: NOTFOUND (the CHAIN
// takes no lock - nothing to release) or a successful locked CHAIN
// followed immediately by an UPDATE (which consumes/releases the lock
// itself - same reasoning as reserve()'s OK branch). There is no
// "found but cannot proceed" branch here at all (release has no
// upper-bound check to fail on - see the limitation noted below), so
// there is no branch that takes a lock and then returns without an
// UPDATE to release it. This keeps this file's header claim -
// "UNLOCK is called on exactly one branch across all three
// procedures, reserve()'s SHORT branch" - literally true.
//
// KNOWN LIMITATION (not exercised by driver.rpgle's own test data, and
// not fixed here - flagging rather than guessing per this task's
// instructions): ZASU is packed(7:0), maximum 9999999. reserve()'s
// SHORT check guards against underflow (going below zero); release()'s
// zasu += qty has no symmetric guard against overflowing past 9999999
// if ever called with an unrealistically large qty. F0608A never had
// to consider this, since it only ever subtracts. TODO: verify/
// consider an overflow guard before exposing release() to untrusted
// input - out of scope for this checkpoint, which only needs to
// demonstrate the locking discipline itself, by symmetry with
// reserve().
//
// ZAUPD (the updated-date field) is left untouched here, matching
// F0608A's own UPDATE, which likewise never assigns ZAUPD (see
// db/v1/zaikom.pf and f0608s.rpgle lines 269-270 - only zasu is
// assigned before UPDATE there).
//=======================================================================
dcl-proc release export;
  dcl-pi *n ind;
    prodCode char(6) const;
    qty      packed(7:0) const;
  end-pi;

  dcl-s ok ind inz(*off);

  zaikomKey.zasho = prodCode;
  clear zaikomRec;   // same defense-in-depth note as get()/reserve().

  chain %kds(zaikomKey : 1) zaikor zaikomRec;
  if not %found(zaikom);
    // No lock taken - nothing to release, nothing to unlock. See
    // header (release() never needs UNLOCK at all, by construction).
    ok = *off;
  else;
    zaikomRec.zasu += qty;
    update zaikor zaikomRec;
    ok = *on;
  endif;

  return ok;
end-proc;
