# part10-01-rpgle の期待値と読み方(未実行。すべて予測)

固定形式 RPG IV ルート(Issue #35)の 10-01 の囲みにある「未検証(2026-10-01時点)」を、実機で決めるためのバッチです。**まだ実行していません(PUB400 に接続できない間に作りました)。** この文書の数字は、RPG III 版の実測(`docs/probes.md` の「第10部 10-01」)からの予測です。実測値が出たら、この文書ではなく `docs/probes.md` に書きます。

`ZA0500`・`JU0300`・`TK0100` の固定形式 RPG IV 版は手で変換したもの(未検証。`src/legacy/qrpgle112/`)です。まず変換結果がコンパイルできるかどうかが、このバッチの最初の関門です。

## 実行前に確かめること

- `<USER>2` が DBVER 1 で、旧システムが RPG III であること。外れていれば、バッチ自身が何も変えずに止まります(`GATE STOP`)。
- `$HOME/ibmi-kyozai` が git の作業ツリーかどうか(`MKTREE` の `ls -d .git` の出力)。作業ツリーなら、`src/legacy/qrpgle112/*.rpgle` は、未追跡のファイルとして新しくできるか、追跡されているファイルが上書きされます(`TREE-REPLACED`)。この3本は、毎回リポジトリーの最新で置き換えます(変換が変わっても古い版が残らないように)。ほかのツリーのファイルは、既にあれば残します(`TREE-KEEP`)。
- 接続の間隔(15分)と、ハーネスの台帳。

## 結果を読む順番

0. `VFYLOG` に `part10-01-rpgle FAILSAFE` があれば、監視されていない例外でラッパーが途中で終わっています。**RPG III への復元(`RSTLEG` 以降)は実行されていません。** 最後の状態の行は復元の証拠として読まず、先に下の「復旧」を行います。
1. `VFYLOG` に `GATE STOP`・`SWITCH GATE STOP`・`SAME GATE STOP` のような停止の行があるか。`SWITCH GATE STOP` なら、`VFYEVF`・`VFYEVL`(コンパイルのイベント。ライブラリーの `EVFEVENT` と `QTEMP` の `EVFEVENT` の2通りの写し。どちらが取れるかは未確認)と `VFYLOG` の `RNF` で変換の失敗を読み、その後は `RSTLEG` から先(RPG III への復元)だけが実行されています。
2. `VFYLOG` の `<ラベル> FAILED`(ステップが失敗した印)を全部拾う。`ENDFAIL`・`ENDUNFX`(ジョブが既に無いときの `ENDJOB`)・`LNG0`(最初は `TXLEGLNG` が無いかもしれない)・`FIXALT`(0行の更新は失敗にならないはず)は、失敗していても雑音です。
3. `VFYATTR`: `T1-SWITCH` の `ZA0500`・`JU0300`・`TK0100` が `RPGLE`、作成時刻が今回のもの。`T0-START` は `RPG`。
4. `VFYMARK`: `T2-SAME` の `TXLEGLNG` が `*RPGLE` なら、`LANG` を省いた `TXLEGACY`(既定 `*SAME`)が言語を保つ、という 10-01 の囲みの主張が確かめられたことになります。`*RPG` なら、その主張は誤りです(教材を直す)。

## 主な値(予測)

| 項目 | 予測 | 見る場所 |
|---|---|---|
| 基準の実行(`RBASE`) | 印字12行(`OK` 10・`SHORT` 2)と、PUB400 の末尾の1行。`RPG`/`RNQ`/`RNX`/`CEE` の失敗なし。`ZAIKOM` の合計392のまま | `VFYPRBASE`、`COUNTS` の `RBASE`、`VFYJR1`(`RBASE-ID` の行) |
| 基準の実行の `CPF4123` | RPG III 版と同じく2回出るかどうかは、実測で決める(10-03 の旧版の確認にも使う) | `VFYJR1`、タグ `RBASE-ID` |
| 失敗の実行(`RFAIL`)のメッセージの ID と並び | **予測しない。** RNQ・RNX・CEE・MCH のどれがどの順で出るかを、`VFYJR1`(タグ `RFAIL-ID`)と `VFYJR1X`(`FPGM`・`FINS` などの列。列名は未確認)から読む | 同左 |
| `JU0900C` の `MONMSG CPF0000` が受けたか | 受けたなら `JU0900C: ZA0500 ended abnormally.` の行がある。無ければ、ILE の例外は `CPF` で上がらず(または `CPF9999` の関数チェックになり)受けていない | `VFYJR1` の `RFAIL` の行 |
| 呼び出しのジョブの終わり方 | `TXRCAP: the call ended normally.` なら正常終了、`escape message` なら ILE の例外が `JU0900C` の外へ出た。`VFYMARK` の `JOB-TXR1FAIL`(0/- なら終了済み、`1/MSGW` なら止まっていた) | `VFYJR1`、`VFYMARK` |
| 印字(`RFAIL`) | RPG III 版は印刷なし(`CPF3309`)。ILE 版は未確認。`VFYPRFAIL` の行数と、`TXRCAP: CPYSPLF of QSYSPRT failed.` の有無 | `VFYPRFAIL`、`VFYJR1` |
| 壊れた行の `HEX(JUSU)` | `4B4B4B4B4B`、失敗の前後で変わらない | `VFYMARK` の `C-PLANT`・`D-FAIL` |
| 修復後の再投入(`RFIXD`) | `J00000` の行 + 基準の12行 = 13行になるかを記録する(RPG III 版は13行。ILE 版は未確認) | `VFYPRFIXD`、`COUNTS` |
| チケット1が未修正の実行(`RUNFX`) | `8100` は RPG III の番号なので予測しない。症状(エラーになるか、黙って違う値で動くか)を、メッセージと印字から読む | `VFYPRUNFX`、`VFYJR1`(`RUNFX-ID`) |
| 在庫の合計 | すべての `ZAIKOM-SUM` が 392(`*TEST` は更新しない) | `VFYMARK` |
| 変換したソースの行 | ステートメント番号と行を突き合わせるための `ZA0500` の全行 | `VFYSRCR`(`SRCSEQ`、`SRCDTA`) |

## 教材に書く前に確かめる点

`docs/part10/10-01-preparation-incident.md` の囲みにある未検証の点のうち、このバッチで答えが出るもの。

- `TXCAPST` が仕込む「数字項目に `.` のバイトが入った行」を ILE 版の `ZA0500` が読んだときの、メッセージの ID・並び・ステートメント番号。
- `JU0900C` の `MONMSG MSGID(CPF0000)` が、それを受けるか。
- チケット1が未修正のときの症状。
- 手順15の印字が13行になるか。
- `TXLEGACY` の `LANG` を省いた形が `*RPGLE` を保つか。

答えが出ないもの(このバッチの範囲外): `part05-lggold` による RPG III 版との12行の一致、`TXLOAD`、5250 の対話。

## 途中で止まったときの手作業での復旧

バッチは、止まらずに最後まで走れば `<USER>2` を RPG III と `TXRESET` の状態に戻します。ジョブが `MSGW` で止まったり、接続が切れたりしたときは、5250 か `qsh` で次のとおりにします。

1. 残っているジョブを終わらせる: `WRKSBMJOB`、または `ENDJOB JOB(TXR1BASE|TXR1FAIL|TXR1FIXD|TXR1UNFX) OPTION(*IMMED)`。
2. `DSPDTAARA DTAARA(<USER>2/TXLEGLNG)` を見る。`*RPGLE` のままなら、`<USER>2/TXLEGACY LIB(<USER>2) LANG(*RPG) FORCE(*YES)`。
3. `<USER>2/TXRESET LIB(<USER>2)`。
4. `JUCHUM`・`JUCHUD` から `J00000`・`C05119` の行を消し、`DLTDTAARA DTAARA(<USER>2/TXCAPFL)`。
5. `ZA0500`・`JU0300`・`TK0100` の `OBJATTRIBUTE` が `RPG` であること、`JUCHUM`・`JUCHUD`・`ZAIKOM` が 8・12・6 行(`JUCHUM` は削除済みレコードを含まない有効行)、在庫の合計が392であることを確かめる。
6. `<USER>2/EVFEVENT`(コンパイルのイベント・ファイル)が残ることがあります。残してかまいません。
7. 作ったままのものは、`RG0500`・`RG0300`・`RG0100`(`*PGM`)だけです。`DLTPGM` で消します。`VFY` で始まる証拠の表・ファイルと `TXRGRUN`・`TXRGATE`・`TXRNOL`・`TXRCAP` は、残してかまいません。
