# part10-02-rpgle の期待値と読み方(2026-10-04 に実行済み。下の「実測」を先に読む)

固定形式 RPG IV ルート(Issue #35)の 10-02 の囲みにある「未検証(2026-10-01時点)」を、実機で決めるためのバッチです。2026-10-04 に PUB400 で、1回の接続で最後まで実行しました。以下の「主な値(予測)」は実行前の予測で、実測は次の節です。

## 実測(2026-10-04、基の行を直した見本も再実行で確認済み)

- `JU0300C`(見本の以前の版)の `CRTBNDRPG`: `RNS9304`、最高重大度 `00`、情報18件のみ(`RNF2318`・`RNF6011`・`RNF7031`・`RNF7066`・`RNF7086`)。`TK0100`・`JU0300`・`ZA0500`(変換結果のまま)も `00`。
- `OVER LIMIT` の明細行(`COUNTS`): `XJU0` 0、`XA0` 8、`XA1` 2、`XJR1` 0。どの印刷にも `GRAND TOTAL 8 XFOOT= 8 OK`。
- `DSPPGMREF`: 全体 1788 レコード、`OBJTYPE(*SRVPGM)` 18、`TK0100` 13(`TOKUIM` の様式レベルID `3B1ECB3196772`)、原本の `JU0300` 7(`TOKUIM` なし)、改修版 `JU0300` 10(`TOKUIM`・`SHOHIM`・`JUCHUD` が増える)。`DSPDBR` は `TOKUIL1` の1行。`JUCSRV` は `*SRVPGM` の実行にだけ出る。
- `CPYSRCF`(`JU0300` → `JU0300X`、`QRPGLE112` の中): 通る。`JU0300`=186、`JU0300X`=186。
- `CPF4131` のあと(`V10PRB` と実際の `TK0100`。どちらも同じ): `CPF4131`、`RNX1216`、`RNQ1216`、応答 `C`、`CEE9901`(`RNX1216 unmonitored by ...`)。`INQMSGRPY(*DFT)` のバッチ・ジョブはメッセージ待ちにならず終了(`ACTTK0` は `0/-`、`ENDTK0` は `CPF1321` で雑音)。変更前の `V10PRB`(`XPRB0`)は正常終了。
- `TOKYSN` は位置6・長さ7・小数0。`CHGPF` 後の様式レベルID `2E09E054754F9`、戻したあと `3B1ECB3196772`、`TOKUIM` 5項目6行。最後の状態は予測どおり(`ZA0500`・`JU0300`・`TK0100` が `RPG`、`TXLEGLNG` が `*RPG`、行数 8・12・6、在庫の合計 392)。
- 雑音: `TXLEGACY` の退避は `CPA4067` に `C` が返って行われなかった(保存ファイル `LG261004` に前のデータが残っていた)。`TXRNOL` は `QUSER1` を探して `CPF2110`(ライブラリー1は外れていない)。`EVFEVENT` は取れず(`EVF*`・`EVJC` などが `FAILED`)、コンパイル・リストは `run` の出力から読む。`TKUIMRG` は `<USER>B` に残っている(設計どおり。結果を受け入れたあとで手で消す)。
- 見本 `ju0300-credit-4x.rpgle` は、この実行のあと、基の行を本物の変換結果に合わせ直した(`CT` の D 仕様書が `5S 0` から `5  0` へ、`FTOK` の桁が `D  FTOK` へ)。**この版も、同日の再実行で最高重大度 00 でコンパイルでき、`OVER LIMIT` の行数は 0・8・2・0 のままでした。**

`JU0300`・`TK0100` は本物の `CVTRPGSRC` の出力です(`docs/probes.md` の `part05-lgcvt`)。

## 実行前に確かめること

- DBVER 1、旧システムが RPG III、`TOKUIM` に `TOKYSN` がまだ無いこと。外れていれば、何も変えずに止まります(`GATE STOP`、`PREGATE STOP`)。
- 前の実行が途中で止まって `TOKUIM` が新しい形のまま残っているときは、`TKUIMRG`(今回の退避)ではなく、先に手で戻してください(下の「復旧」)。`PREGATE` が止めます。
- `$HOME/ibmi-kyozai` の扱いは、`part10-01-rpgle/expected/notes.md` と同じです。

## 結果を読む順番

0. `VFYLOG` に `part10-02-rpgle FAILSAFE` があれば、監視されていない例外でラッパーが途中で終わっています。**RPG III への復元(`RSTLEG` 以降)は実行されていません。** 最後の状態の行は復元の証拠として読まず、先に下の「復旧」を行います。
1. `VFYLOG` の `GATE STOP`・`PREGATE STOP`・`CHGGUARD STOP`・`SWITCH GATE STOP`。`SWITCH GATE STOP` なら、変換結果のコンパイルに失敗しています(`VFYEVF`・`VFYEVL` の `RNF`。どちらの写しが取れるかは未確認)。その後は `RSTLEG` 以降だけ実行されています。`RSTGUARD` から `RSTLEG` へ飛んだ場合は、退避 `TKUIMRG` が無く、`TOKUIM` を戻せていません。`VFYCOL` の `T2-RESTORE` を先に見ます。
2. `<ラベル> FAILED`。`ENDTK0`(ジョブが既に無いときの `ENDJOB`)・`LNG0`・`SRCROWS`(`SYSPARTITIONSTAT` の列名は未確認)は、失敗していても雑音のことがあります。
3. `VFYCOL`: `T0-V1` の `TOKUIM` が5項目、`T1-CHGPF` で `TOKYSN` が加わり(位置6・長さ7・小数0。RPG III 版の実測)、`T2-RESTORE` で5項目に戻る。

## 主な値(予測)

| 項目 | 予測 | 見る場所 |
|---|---|---|
| `JU0300C` のコンパイル(`CMPJC`) | 最高重大度 `00`。`RNF` のエラーなし。変換のしかたで桁が違えば `RNF` が出る(それも記録) | `VFYEVF`、`VFYLOG` |
| `OVER LIMIT` の明細行の数 | 変更前の原本(`XJU0`)0、`TOKYSN` 0 の改修版(`XA0`)8、`TOKYSN` 10000(`XA1`)2、復元後の原本(`XJR1`)0。数えるのは `COUNTS` の `OVERLIMIT=`(印字の写しの行)。RPG III 版の実測と同じになるかが確かめたいこと | `COUNTS`、`VFYPXJU0`・`VFYPXA0`・`VFYPXA1`・`VFYPXJR1` |
| `JU0300` の印字がどのジョブでも取れたか | 取れなければ `TXRCAP: CPYSPLF of QSYSPRT failed.` と、その ID | `VFYJR2` |
| `DSPPGMREF`(全体 `VFYPGMR`) | レコード数は RPG III 版(1069)と違ってよい。**比べるのは `TOKUIM`・`TOKUIL1` を参照するプログラムの名前**。`TK0100` は出る。RPG III 版では、原本の `JU0300` は出ない | `VFYPGMR`、`VFYPR1`(`TK0100` だけ)、`VFYPR2`(原本の `JU0300`) |
| 改修版 `JU0300` の `DSPPGMREF`(`VFYPR3`) | `TOKUIM`・`SHOHIM`・`JUCHUD` を参照する行が出る | `VFYPR3` |
| `DSPPGMREF OBJTYPE(*SRVPGM)`(`VFYSVPR`) | `JUCSRV` が `TOKUIM` を参照する行を含む(RPG III 版は18レコード) | `VFYSVPR` |
| `CPYSRCF` の `JU0300` → `JU0300X` | `QRPGLE112` 内で通る。行数は `JU0300` と同じ(`SRCROWS`) | `VFYMARK`、`VFYLOG` |
| 変更前に作ったプローブ `V10PRB` を `CHGPF` の後に呼ぶ(`XPRB1`) | 開く時のレベル確認で `CPF4131`。**そのあとに ILE の RPG が続けて出すメッセージの ID と並びは予測しない。** `VFYJR2`(`XPRB1-ID`)から読む | `VFYJR2`、`VFYJR2X` |
| `TK0100` を `CHGPF` の後に呼ぶ(`XTK0`) | 同じ。ただし画面ファイルのプログラムなので、バッチでは別の失敗(画面ファイルを開けない、`LASTCD` が無い、など)が先に出るかもしれない。`VFYMARK` の `JOB-TXR2TK` が `1/MSGW` なら止まっていた(`ENDJOB` で終了させている) | `VFYJR2`(`XTK0-ID`)、`VFYMARK` |
| 変更前のプローブ(`XPRB0`) | 正常終了。`CPF4131` なし | `VFYJR2` |
| `TOKUIM` の復元 | `T2-RESTORE` の列が5項目、`E-RESTORE` の行数が6、`VFYFDM2` の様式レベル ID が `VFYFDM0` と同じ(RPG III 版では `3B1ECB3196772`) | `VFYCOL`、`VFYMARK`、`VFYFDM0`〜`VFYFDM2` |
| 最後の状態 | `Z-FINAL` の `ZA0500`・`JU0300`・`TK0100` が `RPG`、`TXLEGLNG` が `*RPG`、`TOKUIM-COLS` が5、行数 8・12・6、在庫の合計 392 | `VFYATTR`、`VFYMARK` |

## 教材に書く前に確かめる点

`docs/part10/10-02-maintenance-tokyusn.md` の囲みの未検証の点のうち、このバッチで答えが出るもの。

- `CRTBNDRPG` で `JU0300C` を作ったときの最高重大度と、印の付く行が 0・8・2・0 行になるか。
- 手順3の `DSPPGMREF` が ILE のプログラムで使え、どの行が出るか。
- 手順7の `CPF4131` と、そのあとの ILE のメッセージ。
- `CPYSRCF` を `QRPGLE112` の中で行う形。

答えが出ないもの: 5250 の対話での `TK0100` の動き(画面を出す)、`SEU`、学習者の手元で変換した `JU0300` と見本の桁の違い。

## 途中で止まったときの手作業での復旧

最優先は `TOKUIM` を元の形(5項目)に戻すことです。その後で言語を RPG III に戻します。

1. 残っているジョブを終わらせる: `ENDJOB JOB(TXR2PRB0|TXR2JU0|TXR2PRB1|TXR2TK|TXR2A0|TXR2A1|TXR2JR1) OPTION(*IMMED)`。同じ名前のジョブが前の実行から出力待ち行列に残っていると、`ENDJOB` が「同じ名前のジョブが複数ある」で失敗することがあります。その場合は `WRKACTJOB` で番号付きのジョブ名を探して、番号付きで終わらせます。`TK0100` のジョブが止まって `TOKUIM` を開いたままにしていると、バッチの `RSTDPF`(`DLTF`)が失敗し、`TOKUIM` が新しい形のまま残ります。ファイルを開いたままのジョブが残っていると、次の `DLTF` が `CPF3202`(ロック)で失敗します。
2. `TOKUIM` に `TOKYSN` があるか確かめる(`SELECT COUNT(*) FROM QSYS2.SYSCOLUMNS WHERE TABLE_SCHEMA = '<USER>2' AND TABLE_NAME = 'TOKUIM'` が6なら新しい形)。新しい形なら、`<USER>B/TKUIMRG` から戻す: `DLTF <USER>2/TOKUIL1`、`DLTF <USER>2/TOKUIM`、`CRTDUPOBJ OBJ(TKUIMRG) FROMLIB(<USER>B) OBJTYPE(*FILE) TOLIB(<USER>2) NEWOBJ(TOKUIM) DATA(*YES)`、`CRTLF FILE(<USER>2/TOKUIL1) SRCFILE(<USER>2/QDDSSRC) SRCMBR(TOKUIL1V1)`。`TKUIMRG` が無ければ、`TKUIMBK`(前のバッチの退避。変更前の形で6行)も使えます。
3. `DSPDTAARA DTAARA(<USER>2/TXLEGLNG)` が `*RPGLE` なら、`<USER>2/TXLEGACY LIB(<USER>2) LANG(*RPG) FORCE(*YES)`、続けて `<USER>2/TXRESET LIB(<USER>2)`。
4. `ZA0500`・`JU0300`・`TK0100` の `OBJATTRIBUTE` が `RPG` であることを確かめる。
5. 作ったままのもの: `RG0500`・`RG0300`・`RG0100`(`*PGM`、`DLTPGM` で消す)、`V10PRB`(`*PGM`)、`QRPGLE112` のメンバー `JU0300X`・`JU0300C`・`V10PRB`、`<USER>B/TKUIMRG`(受け入れたあとで手で消す)。
