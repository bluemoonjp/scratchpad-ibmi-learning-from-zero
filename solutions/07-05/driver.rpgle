**FREE
//=======================================================================
// DRIVER - test driver *PGM for ZAISRV (solutions/07-05/zaisrv.rpgle,
// solutions/07-05/zaisrv.bnd). Part 7 checkpoint, lesson 07-05. Calls
// get/reserve/release in a sequence that exercises: (a) a normal
// reserve and its decremented stock, (b) a SHORT reserve (insufficient
// stock) plus an independent diagnostic check that the lock-release
// fix actually prevents a lingering lock, (c) a release that restores
// stock, (d) calling reserve() twice in a row (smoke test - see
// "ACTIVATION GROUP DESIGN" below for exactly what this can and cannot
// prove).
//
// STATUS: hardware-UNTESTED as of 2026-09-26 (docs/style-guide.md
// V1/V2/V3 scale). Nothing in this file has been compiled or run.
//
// ====================================================================
// WARNING: THIS PROGRAM (VIA ZAISRV) MUTATES THE SHARED ZAIKOM TABLE.
// See solutions/07-05/zaisrv.rpgle's own header for the full warning
// this repeats: ZAIKOM is the SAME physical file R0409A (04-09) and
// F0608A (06-08) already write to, and that 04-13/06-07/06-11b/06-15
// all READ and depend on its known values (06-11b is a DEPENDENT
// reader here, not a writer of ZAIKOM - it writes a different shared
// table, SHOHIM; see f0611bs.rpgle lines 9-11/137). THE 07-05 LESSON
// TEXT (WHEN WRITTEN) MUST
// INSTRUCT THE LEARNER TO RUN <USER>1/TXRESET after running this
// driver, in its exercise, self-check, and cleanup sections. This
// driver's OWN sequence is designed to be net-zero on ZAIKOM (every
// reserve() it issues is matched by an equal release()) so that a
// clean run leaves ZASU unchanged - but TXRESET is still required
// regardless (a run that stops partway through, on a genuine hardware
// surprise, would NOT be net-zero) - do not treat this driver's
// net-zero design as a substitute for TXRESET.
// ====================================================================
//
// BUILD RECIPE: ZAISRV must already exist (see zaisrv.rpgle/zaisrv.bnd
// for that recipe) before this program is built. This program binds
// to ZAISRV via a *BNDDIR (not BNDSRVPGM directly on CRTBNDRPG - that
// parameter does not exist on CRTBNDRPG; verified by reading
// work/design/refs/cl_commands_75.txt's own CRTBNDRPG parameter table
// directly this session, which lists DFTACTGRP/ACTGRP/BNDDIR but no
// BNDSRVPGM at all. CRTBNDRPG DOES have BNDDIR, so that is the path
// used here):
//   CRTBNDDIR BNDDIR(<lib>/ZAISRVBD)
//   ADDBNDDIRE BNDDIR(<lib>/ZAISRVBD) OBJ((*LIBL/ZAISRV *SRVPGM))
//   CRTBNDRPG PGM(<lib>/DRIVER) SRCFILE(<lib>/QRPGLESRC)
//     SRCMBR(DRIVER) DFTACTGRP(*NO) ACTGRP(*NEW)
//     BNDDIR((*LIBL/ZAISRVBD))
// ZAISRVBD is a NEW binding directory, this file's own choice (not
// specified anywhere in work/design/part07-design-v1.md, which leaves
// "ZAISRVBD (new) vs JUCSRVBD (reuse)" as an open question, section 9
// item 10 - but that question is about 07-02's JUCSRV, a DIFFERENT
// service program; reusing JUCSRVBD here would be wrong regardless,
// since JUCSRVBD would resolve to JUCSRV, not ZAISRV). If Part 8 later
// wants one shared binding directory across all of Part 7's service
// programs, this recipe's ZAISRVBD name may need to be reconciled with
// whatever that decision settles on - flagging for a future pass, not
// resolving it here.
//
// The ctl-opt line below (dftactgrp(*no) actgrp(*new) bnddir(...)) is
// AUTHORITATIVE here, unlike a two-step CRTRPGMOD-then-CRTPGM build:
// work/design/part07-design-v1.md's 07-01 entry found that ctl-opt's
// activation-group keywords are ignored by a SEPARATE CRTPGM step
// (CRTPGM decides instead), but this program is compiled in ONE step
// via CRTBNDRPG (module + bind together), so there is no separate
// CRTPGM invocation to override it - the CL recipe above and this
// ctl-opt line agree on purpose, not by accident.
//
// ACTIVATION GROUP DESIGN - why "call reserve() twice in a row" is (or
// is not) a meaningful test here:
//   This program: dftactgrp(*no) actgrp(*new) - a private, named
//   activation group, matching F0608A's own convention
//   (dftactgrp(*no) actgrp(*new), f0608s.rpgle line 183) and the
//   convention this repo's other actgrp(*new) client programs use
//   for calling a *SRVPGM (see work/design/part07-design-v1.md's
//   07-02 entry, F0702A: "dftactgrp(*no) actgrp(*new)
//   bnddir('JUCSRVBD')"). ZAISRV itself is CRTSRVPGM'd with
//   ACTGRP(*CALLER) (see zaisrv.bnd's header) - meaning ZAISRV's
//   module, and the ZAIKOM file it opens internally, activate INTO
//   this program's own activation-group instance, not a separate one
//   of their own.
//
//   Within ONE execution of this program, every call below to get()/
//   reserve()/release() is therefore, trivially, "the same activation
//   group" - there is no RCLACTGRP and no job boundary between them,
//   so this much would be true regardless of which activation group
//   this program itself chose.
//
//   WHY THIS MUST STAY INSIDE ONE EXECUTION (verified against
//   work/design/refs/ileconcepts75.txt lines 1657-1801, read directly
//   this session, not assumed): actgrp(*new) creates a SYSTEM-NAMED
//   activation group, and "for the system-named activation group
//   (created with the ACTGRP(*NEW) option), a normal return from P1
//   [the oldest call stack entry] deletes the associated activation
//   group" (lines 1797-1801). This program IS the oldest call stack
//   entry of its own group, so the MOMENT this program's *inlr=*on
//   returns control to its CL caller, its entire activation group -
//   ZAISRV's ODP on ZAIKOM included - is deleted. Two SEPARATE `CALL
//   DRIVER` commands in the same job would therefore NOT share an
//   activation group at all: the first CALL's group is gone by the
//   time the second CALL creates a brand new one, so nothing could
//   ever carry over between them, fix or no fix. (Contrast a
//   USER-NAMED ACTGRP(name): "a user-named activation group may be
//   left in the job for later use... any normal return... does not
//   delete" it, lines 1791-1792 - that IS how cross-CALL persistence
//   would be tested, but it is not what this program does, and not
//   what this checkpoint's task asks for.)
//
//   PRACTICAL CONSEQUENCE FOR A FUTURE VERIFY-MANIFEST AUTHOR: do NOT
//   "improve" step (d) below by splitting it into two separate `CALL
//   DRIVER` commands in one verify batch (mirroring 07-03's F0703A/
//   countCustOrders two-CALL scenario, work/design/part07-design-v1.md
//   section 9 item 3) - under this program's actgrp(*new), that would
//   prove nothing, because each CALL gets its own fresh, independent
//   activation group per the citation above. Every repeated call this
//   driver makes to reserve()/get()/release() MUST happen inside this
//   one program's one execution, which is exactly how steps (a)-(d)
//   below are written. A named activation group would be the correct
//   choice only if cross-CALL persistence were the thing under test -
//   it is not, here.
//
//   F0608A's own actgrp(*new) choice works the same way: F0608A is
//   likewise the oldest call stack entry of its own system-named
//   group, so its *inlr=*on both closes its own open files (ordinary
//   end-of-program processing) AND deletes its whole activation group
//   on that same normal return (same ileconcepts75.txt citation) - an
//   earlier draft of zaisrv.rpgle's reserve() header described this
//   loosely as "*inlr tears down the activation group"; this header
//   states the mechanism precisely instead, since it turned out to
//   matter for reasoning about ZAISRV's own, different lifetime (see
//   zaisrv.rpgle's reserve() header for the corrected discussion).
//
//   IMPORTANT LIMITATION, stated plainly rather than overclaimed: step
//   (d) below ("reserve() called twice in a row") is a WEAK test by
//   itself. src/qrpglesrc/f0611bs.rpgle's own header states that an
//   unreleased lock "would otherwise be held until this program ends
//   OR THE ROW IS READ AGAIN" (emphasis added) - meaning a SECOND
//   CHAIN through the SAME open file path (ZAISRV's own internal
//   dcl-f zaikom, shared by get/reserve/release for the life of the
//   activation group) would silently replace/refresh any lock left
//   over from a prior call, whether or not the UNLOCK fix is present.
//   So step (d) can only ever demonstrate "no error/hang on a second
//   call" - it CANNOT, by construction, distinguish "the fix works"
//   from "the fix is missing but the second CHAIN silently absorbed
//   the leftover lock anyway". It is labeled a SMOKE TEST below for
//   exactly this reason.
//
//   The genuinely discriminating check is step (b)'s own diagnostic,
//   which opens a SEPARATE instance of ZAIKOM (this program's own
//   dcl-f, a different open data path from ZAISRV's internal one) and
//   attempts its own locking CHAIN immediately after a SHORT reserve()
//   call, before anything else touches the row. TODO: verify - this
//   session has no primary source in work/design/refs/ confirming
//   exactly what a second, same-job, different-open-instance locking
//   CHAIN does when the row is already locked by the first open
//   instance (a genuine conflict with an error status, or a silent
//   same-job pass-through - both are plausible and this session could
//   not resolve it against ilerpgref75.txt). This diagnostic reports
//   whatever %ERROR/%STATUS it actually observes rather than asserting
//   a specific expected value - a real CRTBNDRPG+CALL session must
//   fill in what actually happens. It also does not set an explicit
//   record-wait-time keyword, so if the row genuinely is still locked,
//   this diagnostic step may pause for the file's default record-wait
//   time rather than failing instantly (WAITRCD's own dcl-f syntax is
//   not confirmed against this session's copy of ilerpgref75.txt - a
//   grep for it found zero hits - so it is not guessed at here). A
//   future verify-manifest step for 07-05 should budget for this.
//   Genuinely interactive confirmation (WRKOBJLCK from a SECOND 5250/
//   SSH session, observing the lock from outside this job entirely)
//   remains V3-only and is left to the eventual lesson's own exercise,
//   matching 06-09's and f0611bs.rpgle's own established precedent
//   for this same kind of limitation.
//
// PUB400 placeholders: <USER>, <USER>1, <lib> stand for the learner's
// own library/user names; no real PUB400 user or library name appears
// in this file.
//=======================================================================

ctl-opt dftactgrp(*no) actgrp(*new) bnddir('ZAISRVBD');

//-----------------------------------------------------------------------
// Prototypes for ZAISRV's three exported procedures. EXTPROC names
// match zaisrv.bnd's EXPORT SYMBOL entries exactly ('GET'/'RESERVE'/
// 'RELEASE') - see zaisrv.rpgle's header for why these are upper
// case by default. Signatures copied verbatim from
// work/design/part07-design-v1.md's 07-05 task description.
//-----------------------------------------------------------------------
dcl-pr get packed(7:0) extproc('GET');
  prodCode char(6) const;
end-pr;

dcl-pr reserve ind extproc('RESERVE');
  prodCode char(6) const;
  qty      packed(7:0) const;
end-pr;

dcl-pr release ind extproc('RELEASE');
  prodCode char(6) const;
  qty      packed(7:0) const;
end-pr;

//-----------------------------------------------------------------------
// This program's OWN, SEPARATE open instance of ZAIKOM - used ONLY by
// the step (b) diagnostic below, never by the main reserve/release
// exercise (which always goes through ZAISRV's exported procedures,
// never touches ZAIKOM directly otherwise). A second, independent
// dcl-f of the same physical file is exactly what makes that
// diagnostic a genuinely different open data path from ZAISRV's own
// internal one - see the header's "ACTIVATION GROUP DESIGN" note for
// why this is necessary (a second CHAIN through the SAME open
// instance would not be a meaningful test).
//-----------------------------------------------------------------------
dcl-f zaikom disk usage(*update) keyed;
dcl-ds diagRec likerec(zaikor);
dcl-ds diagKey likerec(zaikor : *key);

dcl-s prod     char(6) inz('P00001');
dcl-s notFound char(6) inz('P99999');   // same NOTFOUND probe code as
                                         // 04-09's own exercise 2 and
                                         // f0608s.rpgle's own CLEAR
                                         // comment, lines 239-241 -
                                         // reused for consistency, not
                                         // invented fresh here.
dcl-s smallQty packed(7:0) inz(2);
dcl-s hugeQty  packed(7:0) inz(9999999); // packed(7:0)'s own maximum -
                                         // guaranteed SHORT against
                                         // any real ZAIKOM row, without
                                         // needing to know or hardcode
                                         // the row's actual current
                                         // stock.

dcl-s startQty packed(7:0);
dcl-s stockQty packed(7:0);
dcl-s ok       ind;
dcl-s ok2      ind;
dcl-s diagStatus int(10);
dcl-s diagNote   char(20);

dcl-f qsysprt printer(132) usage(*output);
dcl-ds line len(132) end-ds;

//-----------------------------------------------------------------------
// printLine: one QSYSPRT line per step, same program-described-PRINTER
// technique as f0608s.rpgle/f0607s.rpgle (a LEN-only DS as the WRITE
// target, CLEAR before each use - same citations as those files, not
// re-quoted here). Local helper, not exported - same shape as
// f0611bs.rpgle's own reloadSfl2 (dcl-proc name; dcl-pi *n; ... ;
// end-proc;, no EXPORT keyword).
//-----------------------------------------------------------------------
dcl-proc printLine;
  dcl-pi *n;
    step  char(16) const;   // longest literal used below is 15 chars
                             // ("2-RESERVE-SHORT") - 16 leaves headroom.
    p     char(6)  const;
    q     packed(7:0) const;
    okInd ind         const;
    stock packed(7:0) const;
    note  char(20)    const;
  end-pi;

  clear line;
  %subst(line:1:16)  = step;
  %subst(line:18:6)  = p;
  %subst(line:25:4)  = 'QTY=';
  %subst(line:29:8)  = %char(q);
  %subst(line:38:4)  = 'OK= ';
  if okInd;
    %subst(line:42:1) = 'Y';
  else;
    %subst(line:42:1) = 'N';
  endif;
  %subst(line:44:5)  = 'ZASU=';
  %subst(line:49:8)  = %char(stock);
  %subst(line:58:20) = note;
  write qsysprt line;
end-proc;

//-----------------------------------------------------------------------
// Step 0: baseline. get() is the unlocked peek - captures whatever
// ZAIKOM actually holds right now, so every check below is relative to
// this captured value rather than a hardcoded assumption (e.g. "45") -
// this program has no way to know, and does not need to know, what
// TXRESET last restored P00001 to.
//-----------------------------------------------------------------------
startQty = get(prod);
printLine('0-BASELINE'   : prod : 0 : *on : startQty : 'get() peek');

//-----------------------------------------------------------------------
// (a) Normal reserve: expect ok = *on, stock decremented by smallQty.
//-----------------------------------------------------------------------
ok = reserve(prod : smallQty);
stockQty = get(prod);
printLine('1-RESERVE-OK' : prod : smallQty : ok : stockQty : 'expect ON, -qty');

//-----------------------------------------------------------------------
// (b) SHORT reserve: hugeQty guarantees insufficient stock regardless
// of the actual current quantity. Expect ok = *off, stock UNCHANGED
// from the previous step (SHORT never deducts - same parity as
// F0608A's own SHORT outcome). The diagnostic immediately below runs
// BEFORE this driver's own get(prod) call for this step - see that
// diagnostic's own comment for why order matters here.
//-----------------------------------------------------------------------
ok2 = reserve(prod : hugeQty);

//-----------------------------------------------------------------------
// (b) continued - THE DIAGNOSTIC: this must be the VERY NEXT operation
// against ZAIKOM after the SHORT reserve() call directly above -
// nothing else, not even this driver's own get(), may touch ZAIKOM
// first. Reason: get() is itself a CHAIN(N) through ZAISRV's own open
// data path, and src/qrpglesrc/f0611bs.rpgle's own header states that
// an unreleased lock "would otherwise be held until this program ends
// OR THE ROW IS READ AGAIN" - i.e. a later read through that SAME open
// instance could itself silently clear a leftover lock, regardless of
// whether the UNLOCK fix exists. Running get() first would make this
// diagnostic meaningless (it could only ever observe "no conflict",
// whether or not the fix works). This diagnostic instead opens ITS
// OWN, separate instance of ZAIKOM (this program's own dcl-f, above)
// and attempts a REAL locking CHAIN through that different open data
// path, immediately, before ZAISRV's own path is read again.
//-----------------------------------------------------------------------
diagKey.zasho = prod;
clear diagRec;
chain(e) %kds(diagKey) zaikor diagRec;
if %error;
  // A conflict was reported by this second open instance. TODO:
  // verify - this is the observation a real hardware run needs to
  // record; this session cannot say in advance whether this branch,
  // the %found branch below, or the final defensive branch is what
  // actually happens.
  diagStatus = %status(zaikom);
  diagNote = 'LOCK STILL HELD?';
elseif %found(zaikom);
  // A real lock WAS acquired via this second open instance, with no
  // conflict reported - consistent with the UNLOCK fix having
  // released reserve()'s SHORT-branch lock. Release THIS diagnostic's
  // own lock immediately (same UNLOCK syntax as reserve() above), so
  // the diagnostic itself never leaves anything behind - this matches
  // reserve()'s own discipline of only unlocking a branch certain to
  // hold a lock (this elseif, guarded by %found, is that branch here).
  unlock zaikom;
  diagStatus = 0;
  diagNote = 'NO CONFLICT SEEN';
else;
  // Not found - should not happen for 'P00001' (defensive branch
  // only). A failed, non-erroring CHAIN takes no lock, so there is
  // nothing to release here - same reasoning as reserve()'s own
  // NOTFOUND branch, which likewise never calls UNLOCK.
  diagStatus = 0;
  diagNote = 'UNEXPECTED-NOTFND';
endif;

// Only NOW, after the diagnostic above has already run, is it safe to
// read ZAIKOM again through ZAISRV's own get() - see the diagnostic's
// comment for why doing this any earlier would defeat the test.
stockQty = get(prod);
printLine('2-RESERVE-SHORT' : prod : hugeQty : ok2 : stockQty
  : 'expect OFF, same');
printLine('2B-DIAG-CHAIN' : prod : 0 : *on : diagStatus : diagNote);

//-----------------------------------------------------------------------
// (c) release: restore the smallQty reserved in step 1. Expect ok =
// *on, stock back to startQty (net-zero so far).
//-----------------------------------------------------------------------
ok = release(prod : smallQty);
stockQty = get(prod);
printLine('3-RELEASE'    : prod : smallQty : ok : stockQty
  : 'expect ON, =start');

//-----------------------------------------------------------------------
// (d) reserve() called TWICE IN A ROW - see header's "ACTIVATION GROUP
// DESIGN" note for exactly what this smoke test can and cannot prove.
// Both calls happen inside this one program execution, hence the same
// job and the same activation-group instance, with no RCLACTGRP in
// between - the minimum bar work/design/part07-design-v1.md's 07-05
// entry asks for. Expect BOTH ok = *on (no hang, no spurious SHORT/
// NOTFOUND from the first call's own lock interfering with the
// second).
//-----------------------------------------------------------------------
ok  = reserve(prod : smallQty);
ok2 = reserve(prod : smallQty);
stockQty = get(prod);
printLine('4-TWICE-A'    : prod : smallQty : ok  : stockQty : 'expect ON');
printLine('4-TWICE-B'    : prod : smallQty : ok2 : stockQty
  : 'expect ON, -2*qty');

// Restore both units taken by step (d), returning ZAIKOM to startQty -
// keeps this driver's overall run net-zero (see header warning banner
// - TXRESET is still required regardless, this is a courtesy, not a
// substitute).
ok  = release(prod : smallQty);
ok2 = release(prod : smallQty);
stockQty = get(prod);
printLine('5-RESTORE'    : prod : smallQty : ok  : stockQty : 'expect =start');

//-----------------------------------------------------------------------
// Bonus parity check (not one of the four required steps, but cheap
// and directly mirrors F0608A's own three-way NOTFOUND/SHORT/OK
// outcome): a product code that does not exist at all. Expect get() =
// -1 (the NOTFOUND sentinel - see zaisrv.rpgle's get() header) and
// reserve() = *off via the NOTFOUND branch specifically (not SHORT) -
// this branch never takes a lock in the first place (see zaisrv.rpgle
// reserve() header), so there is nothing for this driver to check
// beyond the returned indicator itself.
//-----------------------------------------------------------------------
stockQty = get(notFound);
printLine('6-NOTFOUND-GET' : notFound : 0 : *on : stockQty : 'expect -1');
ok = reserve(notFound : smallQty);
printLine('7-NOTFOUND-RSV' : notFound : smallQty : ok : 0 : 'expect OFF');

*inlr = *on;
return;
