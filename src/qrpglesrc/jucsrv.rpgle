**FREE
//=======================================================================
// JUCSRV - a *SRVPGM built up across two Part 7 lessons (07-02, 07-03).
// This ONE file is the final state after both lessons; the header below
// marks, procedure by procedure, which lesson/step added it, so the
// lesson prose can narrate the earlier states by pointing at (or
// temporarily deleting) specific blocks below rather than this repo
// carrying three separate snapshot files.
//
// Per work/design/part07-design-v1.md section 0.1: F0611A (JUCLST4) and
// F0612A (JUCINQ4, src/qrpglesrc/f0612s.rpgle) are NOT edited by this
// file or anywhere in Part 7. JUCSRV is a NEW, independent object that
// re-implements the two pieces of F0612A's own logic that Part 7 needs
// (a customer-name lookup and a per-customer order count), called from
// NEW, independent client programs (f0702s.rpgle/F0702A,
// f0703s.rpgle/F0703A) - never wired into the live JUCINQ command.
//
// STATUS: CONFIRMED on real hardware, across multiple connections
// (part07-0203-srvpgm, part07-03-signature - see docs/probes.md and
// src/qsrvsrc/jucsrv.bnd's own header for the full sequence,
// including the EXPORT(*ALL)-vs-binder-source signature-violation
// story 07-03 is built around). getCustName and countCustOrders are
// both confirmed working (correct customer name, correct order count
// across two same-activation-group calls). pingJucsrv is confirmed
// only as a signature-breaking placeholder (07-03's own point), not
// for any return value of its own.
//
// ----------------------------------------------------------------
// 07-02: getCustName(custCode: char(6) const): char(30)
// ----------------------------------------------------------------
// Faithful port of F0612A's TOKUIM lookup ONLY (not F0612A's JUCHUM
// order-counting/printing logic - that is countCustOrders, added below
// in 07-03, and is a deliberately separate procedure. Per the task
// instructions for this lesson pair, these two procedures must not be
// conflated: getCustName ports f0612s.rpgle lines 186-191 only:
//     chain (cust) tokuim;
//     if %found(tokuim);
//       rptnm = toknm;
//     else;
//       rptnm = 'NOTFOUND';
//     endif;
// - same CHAIN-then-%found-else-'NOTFOUND' shape, TOKNM confirmed 30A
// (not 20A) against db/v1/tokuim.pf line 3 ("TOKNM 30A"). The parameter
// is named custCode (per this lesson's assigned signature), not "cust"
// or "tokcd" - it does not collide with TOKUIM's own external field
// TOKCD either way, since this procedure has no program-entry dcl-pi of
// its own to collide with (contrast f0612s.rpgle's own header comment,
// which explains why IT could not use "tokcd" for its parameter name).
//
// This is the FIRST use of EXPORT (procedure-specification keyword) and
// of a bound service-program interface in this repo. Confirmed:
//   NOMAIN keyword (module has no main       ilerpgref75.txt lines
//     procedure/cycle; required so this      25471-25477, 8613, 8833
//     module can be bound into a *SRVPGM
//     with CRTSRVPGM instead of CRTBNDRPG)
//   EXPORT keyword on DCL-PROC ("the         ilerpgref75.txt lines
//     procedure to be called by another      38494-38503
//     module ... If EXPORT is not specified,
//     the procedure can only be called from
//     within the module")
//   DCL-PI *N <return-type> EXTPROC(         ilerpgref75.txt lines
//     *DCLCASE) - worked example             38345-38367 (full worked
//     "getNextOrder", confirms exact         example, incl. this exact
//     keyword placement AND that this        keyword order), also
//     technique fixes the external/export    31676-31711 ("Specifying
//     name to the MIXED-CASE spelling of     *DCLCASE as the External
//     the DCL-PROC name, instead of the      Name")
//     compiler's default (uppercase form -
//     ilerpgref75.txt lines 31381-31383)
//
// WHY *DCLCASE, not a bare EXTPROC or no EXTPROC at all: the binder
// source added in 07-03 (src/qsrvsrc/jucsrv.bnd) writes
// EXPORT SYMBOL('getCustName') etc. QUOTED, in mixed case.
// ileconcepts75.txt lines 4048-4050: "If the exported symbols contain
// lowercase letters, the symbol name should be enclosed within
// apostrophes ... If apostrophes are not used, the symbol name is
// converted to all uppercase letters." A quoted mixed-case EXPORT
// SYMBOL only matches an export whose OWN external name is that same
// mixed-case spelling - which the compiler will NOT produce by default
// (default = uppercase, ilerpgref75.txt lines 31381-31383). Using
// EXTPROC(*DCLCASE) on each procedure's own DCL-PI pins the external
// name to exactly the DCL-PROC spelling (getCustName, pingJucsrv,
// countCustOrders), removing the guesswork instead of leaving it as an
// unverified assumption. This decision is still flagged below with a
// narrower TODO: verify, because the *interaction* of *DCLCASE with
// CRTSRVPGM EXPORT(*ALL) (07-02's first CRTSRVPGM, before any binder
// source exists) has not been hardware-confirmed - *DCLCASE should
// export under *ALL exactly as it does under *SRCFILE (the external
// name is a property of the module's export table either way, not of
// how CRTSRVPGM was told to expose it), but this repo has not compiled
// this yet.
//
// No internal dcl-pr/prototype is declared in THIS file for any of the
// three exported procedures, and no separate .rpgleinc is used either.
// Reasoned choice (ilerpgref75.txt lines 31398-31402: "It is only
// necessary to explicitly specify a prototype when the procedure will
// be called from another RPG module. When the procedure is only called
// from within the same module, or when it is only called by non-RPG
// callers, the prototype can be implicitly derived from the procedure
// interface."): none of getCustName/pingJucsrv/countCustOrders is
// called from elsewhere IN THIS module (this is a NOMAIN module - there
// is no cycle-main, and none of the three calls another), so each
// procedure's own DCL-PI (with EXTPROC(*DCLCASE)) already IS this
// module's authoritative interface declaration for that procedure. The
// callable prototypes that OTHER programs need (f0702s.rpgle,
// f0703s.rpgle) are declared in THOSE files instead, as ordinary
// dcl-pr/extproc blocks - the normal split for a *SRVPGM's public
// interface (caller-side prototype, callee-side procedure interface).
//
// Creating this module + service program (07-02, EXPORT(*ALL) - QSRVSRC
// does not exist yet at this point in the curriculum):
//     CRTRPGMOD MODULE(<USER>1/JUCSRV) SRCFILE(<USER>1/QRPGLESRC)
//               SRCMBR(JUCSRV)
//     CRTSRVPGM SRVPGM(<USER>1/JUCSRV) MODULE(<USER>1/JUCSRV)
//               EXPORT(*ALL) ACTGRP(*CALLER)
// (CRTSRVPGM/CRTRPGMOD parameter shapes confirmed against
// cl_commands_75.txt lines 6994-7166 and 8582-8630 respectively. Per
// cl_commands_75.txt line 7239-7247, CRTSRVPGM's own EXPORT default is
// *SRCFILE, not *ALL - so EXPORT(*ALL) MUST be spelled out explicitly
// here, which is itself this lesson's Issue #8 checklist item.
// ACTGRP(*CALLER) real-hardware confirmed, part07-0203-srvpgm,
// docs/probes.md - this service program runs in whichever activation
// group its caller is currently in, rather than creating its own.)
//
// Binding directory (07-02, so callers can resolve JUCSRV via *LIBL
// instead of a hardcoded library name):
//     CRTBNDDIR BNDDIR(<USER>1/JUCSRVBD)
//     ADDBNDDIRE BNDDIR(<USER>1/JUCSRVBD) OBJ((*LIBL/JUCSRV *SRVPGM))
// (CRTBNDDIR: cl_commands_75.txt lines 9811-9856, one required BNDDIR
// qualified name, no MODULE/SRVPGM-list parameter of its own - entries
// are added afterward. ADDBNDDIRE: cl_commands_75.txt lines 9952-10010,
// OBJ() is a list of two-element items: qualified object name + object
// type (*SRVPGM or *MODULE) - confirmed *SRVPGM is a valid Element 2
// value, matching the design's own OBJ((*LIBL/JUCSRV *SRVPGM)) shape.)
//
// ----------------------------------------------------------------
// 07-03 step 1: pingJucsrv(): ind
// ----------------------------------------------------------------
// TEMPORARY, THROWAWAY procedure, added ONLY to demonstrate breaking an
// EXPORT(*ALL) signature - it is NOT part of JUCSRV's real service, and
// it is a completely different procedure from countCustOrders (added
// later in step 3, see below); the two must not be conflated. Always
// returns *ON; takes no parameters.
//
// This procedure can never be safely DELETED again once F0702A has been
// rebound against a signature that includes it (07-03 step 2, below):
// ileconcepts75.txt lines 3971-3973, "There is no way to remove a
// service program export in a way compatible with existing programs
// and service programs because that export might be needed by programs
// or service programs bound to that service program." So pingJucsrv
// stays in this module, and in BOTH binder-source PGMLVL blocks in
// src/qsrvsrc/jucsrv.bnd, permanently - "temporary" describes its
// PURPOSE (it does nothing useful), not its lifespan in the file.
//
// Step 1's re-creation (still EXPORT(*ALL) at this point - this is what
// breaks F0702A, since EXPORT(*ALL) recomputes the current signature
// from whatever the module exports right now, with no *PRV/compat
// block of its own):
//     CRTRPGMOD MODULE(<USER>1/JUCSRV) SRCFILE(<USER>1/QRPGLESRC)
//               SRCMBR(JUCSRV)
//     CRTSRVPGM SRVPGM(<USER>1/JUCSRV) MODULE(<USER>1/JUCSRV)
//               EXPORT(*ALL)
// F0702A (built against 07-02's getCustName-only signature) now fails
// to activate - TODO: verify the exact message ID on real hardware (not
// recorded anywhere in this repo yet, per the design doc's own note in
// part07-design-v1.md section 9 item 12; do not guess it here).
//
// ----------------------------------------------------------------
// 07-03 step 2: binder source, EXPORT(*SRCFILE), one rebind of F0702A
// ----------------------------------------------------------------
// See src/qsrvsrc/jucsrv.bnd for the binder-source member itself and
// its own header comment for the STRPGMEXP/PGMLVL/EXPORT SYMBOL syntax
// and citations. After switching CRTSRVPGM to EXPORT(*SRCFILE), F0702A
// is rebound EXACTLY ONCE (recompiled/re-created, its own source
// unchanged) to pick up the new (getCustName + pingJucsrv) signature.
// No "no-stop" claim is made for this step - see the design doc's own
// core-concept note for 07-03 (part07-design-v1.md, 07-03 entry): this
// lesson does not promise to repair the EXPORT(*ALL) version in place
// without any interruption.
//
//     CRTSRVPGM SRVPGM(<USER>1/JUCSRV) MODULE(<USER>1/JUCSRV)
//               EXPORT(*SRCFILE) SRCFILE(<USER>1/QSRVSRC)
//               SRCMBR(JUCSRV) ACTGRP(*CALLER)
//
// ----------------------------------------------------------------
// 07-03 step 3: countCustOrders(custCode: char(6) const): zoned(5:0)
// ----------------------------------------------------------------
// THE REAL, faithful port of F0612A's per-customer order-count logic -
// f0612s.rpgle lines 204-220 (the READ/dow/if/orderCnt accumulator
// loop), with the PRINT-specific lines removed (no rptjuno/rptjudt/
// write rptdtl/ovf handling - those exist only because F0612A is a
// printer-report program; JUCSRV is not):
//     read juchum;
//     dow not %eof(juchum);
//       if jutok = cust;
//         orderCnt += 1;
//       endif;
//       read juchum;
//     enddo;
// (f0612s.rpgle's own accumulator: "dcl-s orderCnt zoned(5:0) inz(0);"
// / "orderCnt += 1;" at line 207 inside the same "if jutok = cust"
// test at line 206 - this file reproduces exactly that comparison and
// exactly that accumulator, renaming the parameter cust -> custCode per
// this lesson's assigned signature.)
//
// NOT CUT-AND-PASTE, THOUGH: see the JUCHUM-repositioning fix below,
// which f0612s.rpgle itself never needed (it is a single-shot,
// call-once-and-end program) but which THIS procedure needs precisely
// because it can be called MORE THAN ONCE per activation (that is the
// whole point of a *SRVPGM). See "JUCHUM repositioning" below.
//
// Binder-source update (append countCustOrders to the *CURRENT block;
// see src/qsrvsrc/jucsrv.bnd's own header for the *PRV mechanics) plus
// UPDSRVPGM, so F0702A (bound to the OLD *PRV-preserved signature)
// keeps working WITHOUT being recompiled, while the NEW client F0703A
// (built after this point) picks up the *CURRENT signature that
// includes countCustOrders:
//     CRTRPGMOD MODULE(<USER>1/JUCSRV) SRCFILE(<USER>1/QRPGLESRC)
//               SRCMBR(JUCSRV)
//     UPDSRVPGM SRVPGM(<USER>1/JUCSRV) MODULE(<USER>1/JUCSRV)
//               EXPORT(*SRCFILE) SRCFILE(<USER>1/QSRVSRC)
//               SRCMBR(JUCSRV)
// (UPDSRVPGM parameters confirmed against cl_commands_75.txt lines
// 10274-10493: SRVPGM and MODULE are both required; EXPORT defaults to
// *CURRENT, which cl_commands_75.txt lines 10549-10553 defines as
// "currently exported ... continue to be exported. No new signatures
// are created" - that default would NOT pick up countCustOrders, so
// EXPORT(*SRCFILE) SRCFILE()/SRCMBR() must be spelled out explicitly
// here, the same way EXPORT(*ALL) had to be spelled out for 07-02's
// first CRTSRVPGM.)
//
// JUCHUM repositioning (the design doc's own flagged "needs
// verification" point, part07-design-v1.md 07-03 entry and section 9
// item 3):
//   juchum is declared USROPN below. Per ilerpgref75.txt lines
//   28467-28468, "The STATIC keyword can only be specified for file
//   definitions in subprocedures. The STATIC keyword is implied for
//   files defined in global definitions" - i.e. a GLOBAL file (which
//   juchum is, declared here at module scope, not inside a dcl-proc)
//   ALWAYS behaves like a STATIC file: once opened, it stays open and
//   stays wherever the last READ left it, across every call to every
//   procedure in this module, for as long as this module's activation
//   group lives. Per ilerpgref75.txt lines 9463-9469 ("Implicit Opening
//   of Files") and 9478-9480 ("there is no closing of global files ...
//   in a linear module [NOMAIN module] ... unless they are explicitly
//   closed"), nothing in a NOMAIN module ever closes a global file for
//   you between calls. So a naive port of f0612s.rpgle's read loop
//   (just the dow/if/read loop above, with no open/close) would read
//   juchum to EOF on countCustOrders' FIRST call and then, on a SECOND
//   call within the SAME activation, immediately see %eof(juchum) = *on
//   before reading anything (the file is still positioned at EOF from
//   the first call) - silently returning 0 every time after the first
//   call, not an error. THIS is the bug f0703s.rpgle's two-calls-in-one-
//   activation-group test is designed to surface.
//
//   Fix: force a fresh OPEN before the read loop, every call. CLOSE-
//   then-OPEN (not OPEN alone) is used so this is safe on every call,
//   including the very first one (where juchum has never been opened):
//   ilerpgref75.txt lines 53872-53873, "A CLOSE operation to an already
//   closed file does not produce an error"; contrast line 61312, "If an
//   OPEN operation is specified for a file that is already open, an
//   error occurs" - so OPEN alone, called a second time, would fail.
//   USROPN itself is required to allow this file's FIRST-ever OPEN to
//   be explicit at all: ilerpgref75.txt lines 61304-61306, "To open the
//   file ... for the first time in a module or subprocedure with an
//   explicit OPEN operation, specify the USROPN keyword."
//
//   TODO: verify - this exact CLOSE/OPEN-every-call pattern has not
//   been hardware-tested (this repo's SSH access has been rate-limited
//   throughout Part 6 and Part 7 drafting). An alternative considered
//   and REJECTED here: declaring juchum as a LOCAL file inside
//   countCustOrders's own dcl-proc body instead (automatic-storage local
//   files are opened fresh and closed automatically on every call per
//   ilerpgref75.txt lines 4910-4918, 9467-9469, 28460-28463 - no
//   explicit CLOSE/OPEN needed at all). That was rejected because local
//   files in subprocedures "must be full-procedural files" and "I/O to
//   local files can only be done with data structures ... the compiler
//   does not generate I and O specifications for externally described
//   files" (ilerpgref75.txt lines 26032-26035, 4912-4914, 13256-13261) -
//   it would require restructuring the JUCHUM access into an explicit
//   data structure (LIKEREC/EXTNAME) instead of bare external fields
//   (jutok/juno/judate), a bigger rewrite than this lesson's "not cut-
//   and-paste, but still a small, explicit fix" framing calls for. The
//   global-file-plus-explicit-CLOSE/OPEN approach keeps the same bare-
//   external-field style f0612s.rpgle and getCustName both already use.
//
//   To reproduce the ORIGINAL bug for the lesson (e.g. to demonstrate
//   the failure before showing the fix): delete the two lines marked
//   "-- repositioning fix --" below and re-create the module/service
//   program; f0703s.rpgle's second reported count will then read 0
//   regardless of the first count.
//=======================================================================

ctl-opt nomain;

//-----------------------------------------------------------------------
// TOKUIM: CHAIN-only access (keyed). CHAIN always searches by key
// regardless of the file's current position, so TOKUIM has no
// repositioning concern the way JUCHUM (sequential READ) does below -
// left as an ordinary global file, no USROPN, opened once at module
// initialization and left open for the life of the activation group
// (ilerpgref75.txt lines 9463-9469).
//-----------------------------------------------------------------------
dcl-f tokuim keyed usage(*input);

//-----------------------------------------------------------------------
// JUCHUM: sequential READ access, added in 07-03 step 3 for
// countCustOrders. USROPN so this file does NOT open automatically at
// module initialization - see the "JUCHUM repositioning" header note
// above for why an explicit, every-call CLOSE/OPEN pair is required
// instead.
//-----------------------------------------------------------------------
dcl-f juchum usage(*input) usropn;

//=======================================================================
// getCustName - 07-02. Port of f0612s.rpgle lines 186-191 (CHAIN TOKUIM
// / %found / else 'NOTFOUND'). See the header comment above for the
// EXTPROC(*DCLCASE) rationale (pins the external/export name to exactly
// "getCustName", matching src/qsrvsrc/jucsrv.bnd's quoted EXPORT
// SYMBOL('getCustName')).
//=======================================================================
dcl-proc getCustName export;
  dcl-pi *n char(30) extproc(*dclcase);
    custCode char(6) const;
  end-pi;

  chain (custCode) tokuim;
  if %found(tokuim);
    return toknm;
  else;
    return 'NOTFOUND';   // same fallback f0612s.rpgle/R0408A used
  endif;
end-proc;

//=======================================================================
// pingJucsrv - 07-03 step 1. TEMPORARY, added only to demonstrate
// breaking an EXPORT(*ALL) signature - NOT part of the real service,
// and NOT the same procedure as countCustOrders below (see the header
// comment above for why it can never be deleted again once F0702A is
// rebound against a signature that includes it).
//=======================================================================
dcl-proc pingJucsrv export;
  dcl-pi *n ind extproc(*dclcase);
  end-pi;

  return *on;
end-proc;

//=======================================================================
// countCustOrders - 07-03 step 3. THE REAL feature added in this
// lesson: a faithful port of f0612s.rpgle lines 204-220's per-customer
// order-count accumulator (JUCHUM full scan, "if jutok = custCode then
// orderCnt += 1"), MINUS the printer-specific lines (no rptjuno/
// rptjudt/write rptdtl/ovf - those belong to F0612A's report, not to
// this service). See the header comment above ("JUCHUM repositioning")
// for why the CLOSE/OPEN pair below is required and is NOT an
// unfaithful deviation from f0612s.rpgle - f0612s.rpgle never needed it
// because it is called (and ends) exactly once per activation.
//=======================================================================
dcl-proc countCustOrders export;
  dcl-pi *n zoned(5:0) extproc(*dclcase);
    custCode char(6) const;
  end-pi;

  dcl-s orderCnt zoned(5:0) inz(0);

  close juchum;   // -- repositioning fix -- (safe even if not open yet:
  open  juchum;   // -- repositioning fix -- ilerpgref75.txt 53872-53873)

  read juchum;
  dow not %eof(juchum);
    if jutok = custCode;
      orderCnt += 1;
    endif;
    read juchum;
  enddo;

  close juchum;

  return orderCnt;
end-proc;
