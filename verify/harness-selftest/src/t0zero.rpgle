**FREE
// Harness self-test: force a divide-by-zero (RPG0102, severity 99 inquiry) to confirm
// CHGJOB INQMSGRPY(*DFT) auto-answers it instead of hanging a non-interactive job.
// (Same reproduction as lesson 04-12.)
dcl-s a int(10) inz(10);
dcl-s b int(10) inz(0);
dcl-s c int(10);

c = a / b;

*inlr = *on;
