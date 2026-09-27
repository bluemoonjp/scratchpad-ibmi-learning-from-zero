**FREE
//=======================================================================
// F0612A - JUCINQ4: order inquiry report for one customer, printed
// through the new P0612A printer file (Part 6, lesson 06-12).
//
// THIS FILE'S SINGLE MOST IMPORTANT CORRECTNESS PROPERTY:
//   Per work/design/part06-design-v1.md section 0.4, this program is
//   designed to become the new CPP (Command Processing Program) of the
//   EXISTING JUCINQ command (03-11, src/qcmdsrc/jucinq.cmd), replacing
//   JUCINQC (03-09), via:
//       CHGCMD CMD(<USER>1/JUCINQ) PGM(<USER>1/F0612A)
//   This CPP swap has never been executed anywhere in this repo before
//   (design doc section 0.4: JUCINQ's CPP has never actually been
//   swapped). CHGCMD "does not change the parameter descriptions
//   or validity checking information in the command definition object"
//   (work/design/refs/cl_commands_75.txt, lines 18-27) - the caller-
//   facing interface of JUCINQ stays exactly as it is today. That means
//   THE PROGRAM-ENTRY PARAMETER LIST BELOW MUST MATCH JUCINQC'S REAL
//   INTERFACE EXACTLY, or the swap silently breaks every existing caller
//   of the JUCINQ command. Confirmed from the real sources (not just
//   the lesson prose), with HIGH CONFIDENCE:
//     - solutions/03-09/jucinqc.clp, line 4: PGM PARM(&TOKCD)
//     - solutions/03-09/jucinqc.clp, line 7: DCL VAR(&TOKCD)
//       TYPE(*CHAR) LEN(6)
//     - src/qcmdsrc/jucinq.cmd, lines 1-3: PARM KWD(TOKCD)
//       TYPE(*CHAR) LEN(6) MIN(1)
//     - docs/part03/03-09-dclf-rcvf.md, lines 46-49 (lesson prose,
//       matches the .clp source exactly)
//   All three agree: JUCINQC/JUCINQ accept EXACTLY ONE parameter, a
//   6-character, fixed-length CHAR field (MIN(1): required, no
//   default). The dcl-pi below declares exactly that: one char(6)
//   parameter, nothing more, nothing longer, nothing optional.
//
// PROGRAM-ENTRY dcl-pi vs. SUBPROCEDURE dcl-pi (contrast with 06-05):
//   06-05 (src/qrpglesrc/f0605s.rpgle) uses dcl-pi INSIDE a dcl-proc
//   block (calcTaxTotal), to declare the parameter interface of a
//   SUBPROCEDURE that other **FREE code calls with a bound
//   (CALLP-style) call - see f0605s.rpgle's own header comment, which
//   already flags this same contrast from the other side and points
//   here for the program-entry form.
//
//   The dcl-pi below is different: it appears at the very top of the
//   source, OUTSIDE any dcl-proc, before the first executable
//   statement. That makes it the procedure interface of THIS PROGRAM'S
//   OWN cycle-main procedure - the free-form replacement for
//   fixed-form RPG's "C *ENTRY PLIST" / "C PARM" pattern. Confirmed in
//   work/design/refs/ilerpgref75.txt:
//     - lines 8661-8663: "The parameters for the cycle-main procedure
//       can be coded using a procedure interface ... in the global
//       Definition specifications, or using a *ENTRY PLIST in the
//       cycle-main procedure's calculations."
//     - lines 29405-29439 ("Free-Form Procedure Interface Definition",
//       example 1): a COMPLETE program, shaped exactly like this file -
//       "CTL-OPT ...; DCL-PI *N; name CHAR(10) CONST; END-PI; ...
//       RETURN;" - with *N as the procedure-interface name because
//       there is no prototype (line 29409: "If you do not specify a
//       prototype for a cycle-main procedure, you use *N as the name
//       for the procedure interface.").
//
// Parameter NAMED "cust", not "tokcd": JUCINQC's own CL variable is
// named &TOKCD, but naming this RPG parameter "tokcd" would COLLIDE
// with TOKUIM's own externally-described field TOKCD once "dcl-f
// tokuim" below is processed (RPG auto-declares a global field per
// externally-described column, and two same-named definitions would
// clash). Program-call parameter matching is purely positional
// (one CHAR(6), MIN(1)) - the LOCAL name on the receiving side has no
// bearing on caller compatibility. "cust" mirrors R0408A's own local
// variable name for this same value ("MOVEL'C00001' CUST 6" /
// "CUST CHAIN TOKUIM" in src/qrpgsrc/r0408s.rpg).
//
// WHAT THIS PROGRAM PORTS (src/qrpgsrc/r0408s.rpg, R0408A / JUCINQ3,
// 04-08, hardware-verified 2026-09-25 - see
// docs/part04/04-08-jucinq3-report.md):
//   R0408A: MOVEL'C00001' CUST 6 / CUST CHAIN TOKUIM / (if not found,
//   MOVEL'NOTFOUND' TOKNM) / then READ JUCHUM in a GOTO LOOP, printing
//   (via EXCPT/O-spec) only the orders where JUTOK = CUST. This file
//   ports that CHAIN+READ+filter logic into **FREE control flow
//   (dow/if instead of GOTO/TAG, %found instead of a result indicator -
//   the same substitution 06-04's f0604s.rpgle already made), and
//   replaces R0408A's HARDCODED 'C00001' literal with the REAL cust
//   parameter received from the command.
//
//   R0408A touches exactly TWO files: TOKUIM (CHAIN, keyed) and JUCHUM
//   (sequential READ, record format JUCHUR). There is no third file -
//   confirmed both by reading r0408s.rpg directly and by listing
//   db/v1/ (only tokuim.pf, juchum.pf, zaikom.pf exist). This program
//   touches the same two files, nothing more.
//
// NEW: a per-customer order-count SUBTOTAL, computed with plain RPG IV
// calculation (an accumulator variable incremented in the read loop),
// NOT the RPG cycle's automatic L1/LR totals - this program has no
// cycle-main total logic to rely on in the first place (per design: a
// subtotal that does not rely on the RPG cycle). JUCHUM carries no
// quantity/amount field to subtotal (confirmed: db/v1/juchum.pf has
// only JUNO/JUTOK/JUDATE/JUTAN), so the natural subtotal for a
// SINGLE-CUSTOMER report is the COUNT of matching orders, printed on
// the new RPTTOT record.
//
// P0612A (src/qddssrc/p0612s.prtf) - the DDS side, using SPACEB/SKIPB/
// EDTCDE, replaces R0408A's O-spec column positions (OQSYSPRT E /
// O TOKNM 30 / O JUNO 38 / O JUDATE 48). See that file's own header
// comment for exactly which of these DDS keywords were confirmed
// against work/design/refs/ and which were not (SPACEB/SKIPB have ZERO
// matches anywhere in work/design/refs/ - flagged there explicitly).
//
// FILE LOCATION vs. the design doc: work/design/part06-design-v1.md
// section 6 lists 06-12's files under solutions/06-12/. This file is
// placed at src/qrpglesrc/f0612s.rpgle instead, per this task's
// explicit instructions (matching how 06-05's f0605s.rpgle and 06-03's
// f0603s.rpgle are also directly under src/, not solutions/) - an
// intentional, task-directed deviation from that one design-doc
// table, not an oversight.
//
// STATUS: hardware-UNTESTED (Part 6 draft, draft/part06 branch). This
// source, and P0612A, have not been compiled, run, or CHGCMD-attached
// to JUCINQ on PUB400 yet. Treat every runtime claim here as "should
// work per the ILE RPG Language Reference / CL command reference", not
// as a verified fact.
//
// Verified against work/design/refs/ilerpgref75.txt (IBM i 7.5 ILE RPG
// Language Reference, 73451 lines) and cl_commands_75.txt at
// approximately these line numbers:
//   Program-entry DCL-PI (cycle-main         ilerpgref75.txt lines
//     procedure interface, no prototype,     8661-8663, 29405-29439
//     *N name)
//   DISK device default, USAGE(*INPUT)       ilerpgref75.txt lines
//     default, KEYED keyword                 26045-26078, 26149
//   PRINTER keyword, optional *EXT or        ilerpgref75.txt lines
//     record-length parameter, *EXT default  28160-28173
//     (externally described)
//   OFLIND(indicator) - named indicator      ilerpgref75.txt lines
//     variable, worked example                27970-27988, 4012
//     "DCL-F qprint printer(132)
//     oflind(qprintOflow);"
//   CHAIN (searcharg) filename               ilerpgref75.txt line 2534
//   %FOUND / dow not %eof(file) patterns     ilerpgref75.txt lines
//                                            6632, 6617, 5569, 28513,
//                                            37291
//   CHGCMD: does not change parameter        cl_commands_75.txt lines
//     descriptions; restrictions on          18-27, 29-47
//     changing PGM() (object mgmt authority
//     needed; threadsafe forced to *NO)
//=======================================================================

ctl-opt option(*srcstmt);

//-----------------------------------------------------------------------
// Program-entry dcl-pi: the free-form *ENTRY PLIST replacement (see
// the header comment above). ONE parameter, CHAR(6), matching
// JUCINQC/JUCINQ exactly. No EXTPGM/prototype needed - this program is
// not meant to be called by other RPG programs via a prototype; it is
// called the same way JUCINQC is called today (CL CALL / a command's
// CPP), which needs no RPG-side prototype at all.
//-----------------------------------------------------------------------
dcl-pi *n;
  cust char(6);
end-pi;

//-----------------------------------------------------------------------
// Same two files R0408A used: TOKUIM (CHAIN, keyed) and JUCHUM
// (sequential READ). DISK is the default device (not stated), USAGE
// and KEYED are stated explicitly for clarity even though *INPUT is
// itself the default.
//-----------------------------------------------------------------------
dcl-f tokuim keyed usage(*input);
dcl-f juchum usage(*input);

//-----------------------------------------------------------------------
// P0612A: the new PRTF (see src/qddssrc/p0612s.prtf).
//
// OFLIND, RESTORED with a working form (2026-09-27, part06-decisions-1
// re-investigation): the first two attempts both failed to compile -
// "dcl-ind ovf;" (not a real RPG IV keyword, RNF5347/RNF7030), then
// "dcl-s ovf ind;" + "oflind(ovf)" (RNF2037, "The Overflow Indicator is
// already defined", severity 20). A THIRD attempt, "oflind(*inoa)"
// (the named special indicator directly, no separate dcl-s at all -
// candidate A of 3 tried in the same connection) hit the SAME severity-
// 20 compile failure as the *inoa-via-ovf attempt (RNS9308/RNS9310 in
// the job log; the specific RNFnnnn was not captured, but the failure
// class matches). A FOURTH attempt, oflind(*in01) - a NUMBERED
// indicator instead of the *INOA-*INOG/*INOV named-overflow family -
// compiled cleanly (Highest Severity 00, confirmed real hardware,
// candidate B of the same connection). Both forms are listed as valid
// OFLIND parameters in ilerpgref75.txt lines 27970-27988 ("Valid
// Parameters: *INOA-*INOG, *INOV" / "*IN01 through *IN99" separately),
// but only the numbered-indicator family actually compiles against an
// EXTERNALLY DESCRIBED printer file on this PUB400 PTF level - the
// *INOA family appears to be reserved/already-claimed for externally
// described printer files specifically - CONFIRMED (part06-decisions-2):
// the identical oflind(*inoa) keyword compiles and runs fine on a
// PROGRAM-described printer file (verify/part06-12-prtf-cpp-swap/src/
// t612ofc.rpgle, using QSYSPRT), so the conflict is specific to
// externally described printer files, not to *INOA in general. *IN01's
// compile AND run-time behavior were BOTH confirmed with a throwaway
// 100-line WRITE loop probe (verify/part06-12-prtf-cpp-swap/src/
// t612ofb.rpgle, NOT shipped) - CONFIRMED SUCCESS, all 100 lines
// printed correctly (found in the connection result's own "run"
// section text - CPYSPLF cannot capture this file's spooled output in
// this harness's job environment, a separate, unrelated limitation
// also confirmed for QSYSPRT itself, part06-0103-freeform). *IN01
// never turned on across those 100 lines (the default form length is
// evidently longer); this lesson's own normal 2-row run below never
// overflows a page either, so *IN01 stays *OFF for every real run of
// F0612A itself - the page-break exercise (06-12 lesson text, not yet
// written) is where a learner is meant to actually force and observe
// overflow (e.g. by overriding FORMLEN to something small).
//-----------------------------------------------------------------------
dcl-f p0612a printer usage(*output) oflind(*in01);

dcl-s orderCnt zoned(5:0) inz(0);

//-----------------------------------------------------------------------
// CHAIN: same TOKUIM lookup R0408A did with a hardcoded literal
// ("MOVEL'C00001' CUST 6" / "CUST CHAIN TOKUIM"), except cust now
// arrives as the real program-entry parameter instead of a literal.
// %found replaces R0408A's HI result indicator (99), the same
// substitution 06-04 already made for this exact kind of CHAIN.
//-----------------------------------------------------------------------
chain (cust) tokuim;
if %found(tokuim);
  rptnm = toknm;
else;
  rptnm = 'NOTFOUND';   // same fallback R0408A used: MOVEL'NOTFOUND'TOKNM
endif;
rptcust = cust;

write rpthdr;

//-----------------------------------------------------------------------
// READ loop: same JUCHUM full scan + "JUTOK = CUST" filter as R0408A's
// "READ JUCHUM / JUTOK IFEQ CUST / EXCPT / GOTO LOOP", written with
// dow/if instead of GOTO/TAG (06-04's substitution again). orderCnt is
// the per-customer subtotal, computed here with an explicit
// accumulator and an explicit WRITE (no RPG-cycle total time at all -
// this program has no cycle-main total processing to hook into).
//-----------------------------------------------------------------------
read juchum;
dow not %eof(juchum);
  if jutok = cust;
    orderCnt += 1;
    rptjuno = juno;
    rptjudt = judate;
    write rptdtl;
  endif;
  read juchum;
enddo;

rptcnt = orderCnt;
write rpttot;

*inlr = *on;
return;
