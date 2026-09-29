# part10-02-tokuim の期待値(手計算、実機未確認)

**この接続はまだ一度も実行していません。** ここに書く値はすべて、`db/data/load_v1.sql` と各ソースを読んで計算した予測です。実行したら、実際の結果を `docs/probes.md` に書き、この表と食い違った所は表の側を直します。

## 読む前に必ず確認すること(ゲート)

0. `VFYLOG` に `PREGATE STOP` があれば、`TOKUIM` に既に `TOKYSN` があったので何も実行していない(前回が途中で止まっている)。`CHGGUARD STOP` があれば、退避 `TKUIMBK` が無いので `CHGPF` をしていない(`TOKUIM` は無傷)。どちらも、原因を直してからやり直す。
1. `VFYLOG` に `FAILED` で終わる行が、**どのステップにあるか**を先に全部拾う(`<ラベル> FAILED`)。**ただし `SNAPB`/`SNAPA0`/`SNAPA`/`SNAPR` の `FAILED` と、そこから連鎖する `ALB` `ALA0` `ALA` `ALR` `XBA` `XAB` `XB0` `X0B` `XBR` `XRB` `CNTB` `CNTA0` `CNTA` `CNTR` の `FAILED`、`GREPOVR` の空の結果は想定内**(下の「印刷の読み方」)。`CPJU0300C FAILED` があれば、旧 `JU0300` がもう一度動いただけなので、`EXCEPT` の空の結果は「旗が出ていない」ではなく**「新しいプログラムが作られていない」**。他の `EXCEPT`/件数の節を読まない。
2. `VFYCOL` の `T0-BEFORE` に `TOKYSN` が**無い**こと。あれば、前回の実行が途中で止まり `TOKUIM` が v3 のまま(`BACKUP` は退避が既にあればそれを使う)。先に手で戻す(`RSTDLF`/`RSTDPF`/`RSTDUP`/`RSTLF` と同じ手順)。
3. `VFYPRE` の `N` が 6、`MINCD` が `C00001`、`MAXCD` が `C00006`。
4. `RSTGUARD` の直後にラッパーが `DONE` へ飛んだ(退避が無い)場合は、復元をしていない。`TOKUIM` の状態を先に確認する。

## 主な値

| 項目 | 期待 | 出所 |
|---|---|---|
| `VFYCOL` T0 の `TOKUIM` | `TOKCD` `TOKNM` `TOKZIP` `TOKTAN` `TOKUPD` の5項目 | `db/v1/tokuim.pf` |
| `VFYCOL` T1 の `TOKUIM` | 上の5項目 + `TOKYSN`(位置6、長さ7、小数0) | `tokuim-v3.pf` |
| `VFYCOL` T1 の `TOKUIL1` | 5項目(共有様式)か、6項目か。**どちらも記録する**(未確認) | |
| `VFYCOL` T2 の `TOKUIM` | T0 と同じ5項目 | 復元 |
| `VFYDFT` | `N`=6、`MINYSN`=0、`MAXYSN`=0(`DFT` なしの数値項目)。**0以外なら、その値を記録する** | |
| `VFYINS`(`INSCHK`: 列名を並べて `TOKYSN` を省いた `INSERT`。`TXRESET` の `load_v1.sql` と同じ形) | 1行、`TOKCD`=`C99999`、`TOKYSN`=0。`INSCHK FAILED`(`SQL0407` など)なら、**`CHGPF` の後の `TXRESET` は列を省いた `INSERT` で失敗する**ので記録する(`INSDEL` が行を消す。失敗しても復元で消える) | 未確認 |
| `PRB0`/`PRL0`(変更前) | `TKPROBE V1-PRE: RCVF read a TOKUIM row, no CPF4131` と `TKPROBL` の同じ趣旨の行 | |
| `PRB1`(`CHGPF` 直後、v1 でコンパイルした `TKPROBE`) | **`TKPROBE V1-POST: CPF4131 CONFIRMED`** | `part05-txmigr-to2` の `RUNPROBE` と同じ型 |
| `PRL1`(同、`TKPROBL`) | 未確認。`CPF4131` か、行を読めたか。**どちらでも記録する**(`RBLDLF` を必ず後で行うので、どちらでも先へ進む) | |
| `PRB2`/`PRL2`(再作成・再コンパイル後、v3 の `TKPROB3`/`TKPROBL3`) | `no CPF4131, levels agree` | |
| `PRB2OLD`(v1 の `TKPROBE` を、まだ変更後のファイルに) | `CPF4131 CONFIRMED`(プログラム側を直さない限り消えない) | |
| `PRB3`(復元後、v1 の `TKPROBE`) | `no CPF4131`。**これは `CRTDUPOBJ` で戻した `TOKUIM` の様式レベル ID が元と同じ、という予測の確認**(08-06 でも、SQL の DDL で作った複製の ID が一致した) | |
| `PRB3NEW`(復元後、v3 の `TKPROB3`) | `CPF4131 CONFIRMED` | |
| `TXCHK`(`TXCHECK` 10-02) | `0000000004 passed,` / `0000000000 failed.`(`TOKUIM` `TOKUIL1` `TK0100` `JU0300`) | `txcheck.clp` の出力形式 |
| `VFYPOST` | `N`=6 | 復元後の行数 |
| `TXCKM_1002_LEFT` | 0 | 片付け |

## 印刷の読み方(先にここを読む)

`docs/probes.md`(`part06-0103-freeform`、`part08-02-driver-bsh`)の既知の発見: このハーネスの qsh `system()` 経由のジョブが印刷装置ファイルに書いた出力は、実在するスプール・ファイルにならず、接続の標準出力(結果 JSON の `run` セクション)へ直接流れ込む。したがって `TXSNAP`(中身は `CPYSPLF FILE(QSYSPRT)`)は `CPF3303` で失敗する見込みが高く、下の `TXSNAPT` / EXCEPT / `GREPOVR` の数は取れない可能性が高い。**主な証拠は `run` セクションの `JU0300` の印刷4回分**(呼び出し順に `BEFORE`、`AFTER0`、`AFTER`、`RESTORE`。各回は `GRAND TOTAL` の行で終わる)。数え方:

- 数えるのは明細行だけ(行頭が受注番号 `J000nn`、行の右側に `OVER LIMIT`)。**`CRTRPGPGM` のコンパイル・リストも同じ `run` に出て、ソース中の `OVER LIMIT` という文字列を含むので、行頭が受注番号でない行は数えない。**
- 期待: 1回目 0 行、2回目 8 行、3回目 2 行(`J00002`、`J00006`)、4回目 0 行。1回目と4回目は、行ごとに一致するはず。
- `TXSNAP` が意外に動いたときだけ、下の表(`TXSNAPT` の EXCEPT と `GREPOVR`)も第2の観測として読む。

## `JU0300` の比較(`TXSNAPT` の EXCEPT。`TXSNAP` が動いた場合だけ意味を持つ)

`JU0300` の印刷は、受注8件の明細行(`DTL`)と、日付・得意先・全体の小計行から成ります。旗が付くのは明細行だけです。旗の条件は、**受注の1行目**(`JULINE`=1)の数量 × `SHOHIM` の現在単価が、得意先の `TOKYSN` を超えること(`ju0300-credit.rpg` の冒頭コメント)。`load_v1.sql` から計算した1行目の金額:

| 受注 | 得意先 | 1行目 | 数量 × 単価 |
|---|---|---|---|
| J00001 | C00001 | P00001 | 2 × 1580.00 = 3160.00 |
| J00002 | C00002 | P00002 | 1 × 12800.00 = **12800.00** |
| J00003 | C00001 | P00004 | 10 × 650.00 = 6500.00 |
| J00004 | C00003 | P00001 | 1 × 1580.00 = 1580.00 |
| J00005 | C00004 | P00006 | 2 × 3200.00 = 6400.00 |
| J00006 | C00005 | P00002 | 2 × 12800.00 = **25600.00** |
| J00007 | C00006 | P00005 | 5 × 890.00 = 4450.00 |
| J00008 | C00003 | P00001 | 3 × 1580.00 = 4740.00 |

| スナップショット | `OVER LIMIT` を含む行 | 意味 |
|---|---|---|
| `BEFORE`(旧 `JU0300`) | 0 | 旗の無い元の出力 |
| `AFTER0`(`TOKYSN` が `CHGPF` 直後の 0) | **8**(全受注) | 金額 > 0 なので全件が超過 |
| `AFTER`(`TOKYSN` を 10000 に更新) | **2**(J00002 / C00002、J00006 / C00005) | 12800 と 25600 だけが 10000 を超える(他は 6500 以下) |
| `RESTORE`(復元後、旧 `JU0300`) | 0 | `BEFORE` と同じ |

`GREPOVR`(`sh`、ラッパーの後)がこの4つの数を `grep -c 'OVER LIMIT'` で直接出す(別名が消えた後でも読める。`TXSNAP` が失敗していればメンバーが無く、数は出ない)。

`EXCEPT` の結果表(`VFYXBA` など)の期待:

| 表 | 意味 | 行数 |
|---|---|---|
| `VFYXBA` | `BEFORE` にあって `AFTER` に無い行 | **2**(J00002 と J00006 の旗なしの明細行) |
| `VFYXAB` | `AFTER` にあって `BEFORE` に無い行 | **2**(同じ2行に `OVER LIMIT` が付いたもの) |
| `VFYXB0` / `VFYX0B` | `BEFORE` 対 `AFTER0` | 各 **8** |
| `VFYXBR` / `VFYXRB` | `BEFORE` 対 `RESTORE` | 各 **0**(復元で元の出力に戻る) |

`VFYCNT` は各スナップショットの総行数で、4つとも同じになるはず(旗は行を足さず、同じ行の右側に文字を足すだけ)。**違えば、印刷のレイアウトが崩れている。**

## 例外・失敗したときの読み方

- `DOCHGPF` または `RSTDPF` で `CPF3202`・`CPF3203`・`CPF7304` が出たら、同じジョブの直前の `RUNSQL` などが `TOKUIM` のロックを残している疑い(`CPF3202` は割り当て不能、`CPF3203` はオブジェクトの割り当て失敗)。
- `CPJU0300C FAILED` なら、コンパイル・リストを読む。**`KLIST`/`KFLD`、追加した3つの F仕様書、`MULT`/`COMP` の桁位置**が最初の疑い(この形は、このリポジトリーでまだ一度もコンパイルしていない)。
- `TXSNAP` は実機で一度も動かしていない。`SNAPB FAILED` なら `CPYSPLF` のエラー(`CPF3303`、スプールが見つからない、など)を読む。**このハーネスでは失敗が既定の見込み**(上の「印刷の読み方」)。
- `CLNSVPR FAILED` なら `DSPPGMREF` の `OBJTYPE(*SRVPGM)` が実機で通らなかった可能性がある(このキーワードはリポジトリー内に実機の証拠が無い)。既定の `OBJTYPE(*ALL)` の `CLNPGMR`(`VFYPGMR`)に `*SRVPGM` の行が出ていないかも見る。
- `DOCHGPF`/`RSTDLF` の前の `RCLRSC` は、同じジョブの先行する SQL が残したロックへの予防(効果は未確認)。
- `TXCHK` の行が2回出る、または `CPF4174` が出たら、同じジョブで `TXCHECK` を2回呼んでいる。このバッチは1回だけ。
- `RSTDUP` が失敗した場合、`TOKUIM` が無い状態が続く。すぐ手で `CRTDUPOBJ OBJ(TKUIMBK) FROMLIB(<USER>B) OBJTYPE(*FILE) TOLIB(<USER>2) NEWOBJ(TOKUIM) DATA(*YES)` を実行し、`TOKUIL1` を `CRTLF` する。
