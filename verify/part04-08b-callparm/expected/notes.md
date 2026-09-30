# part04-08b-callparm: expected results (predictions until run)

Nothing here is confirmed yet. Judge each line by the run section and vfylog.

| Step | Prediction |
|---|---|
| CPBA..CPBG | Compile, highest severity 00 (not yet confirmed) |
| RUNBB | `C00001  ACME TRADING CO                 0` |
| RUNBX | `5  O` (QTY 5,0 passed correctly; 5 is not below 10) |
| RUNBG | `4,500` |
| RUNBE | Runs without a message (predicted). Whether GUARD is overwritten depends on the storage layout and is observed, not predicted. |
| RUNBD | Predicted: RPG0907 in R0408BC (decimal-data error at the COMP), same as 05-13 ticket 1 (JU0900C to ZA0500, statement 8100). Not confirmed for RPG-to-RPG. |
