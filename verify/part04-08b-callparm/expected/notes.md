# part04-08b-callparm: results (CONFIRMED 2026-09-30, 3 connections)

Connection 1 failed to compile R0408BA (F-spec column 16 missing: QRG2025 / QRG2100 / QRG5092), so R0408BB and R0408BE saw MCH3401 (program not found, LO indicator ON, CALL FAILED printed). Connection 2 confirmed everything below; connection 3 re-ran after making the O-spec layout of R0408BD and R0408BX identical, with the same messages.

| Step | Result (connection 3) |
|---|---|
| CPBA..CPBG | Compile, highest severity 00 |
| RUNBB | `C00001  ACME TRADING CO                 0` |
| RUNBX | `00005  R` (5 is below 10, so R). The prediction "O" written before the run was wrong |
| RUNBG | `4,500` |
| RUNBE | `/ACME TRADI/NG CO     /0`, no message, no LO indicator: GUARD was overwritten with characters 11-20 of the name |
| RUNBD | `RPG0907: R0408BC 700 decimal-data error in field (C G S D F).` then `RPG9001`; the caller printed `  005  -      CALL FAILED` (LO indicator 85 ON). Same behaviour as 05-13 ticket 1 (statement 8100) |

Noise: `CPF2103` / `ADDLIB FAILED` (the wrapper already added the library), `CPF2105` / `DLxx FAILED` on the first run (nothing to delete yet).
Also seen: the compile listing's cross-reference shows numeric work fields as packed, e.g. `QTY P(5,0)`.
Not tested: 5250 interactive display of the RPG0907 inquiry message (V3).
