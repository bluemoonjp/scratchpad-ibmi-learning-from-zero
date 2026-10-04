# part10-03-rpgle の期待値と読み方(2026-10-04に実行済み。下の表は実行前の予測。実測は docs/probes.md の同名の節)

**実測の要点**: 印は `BOUND_SRVPGM_INFO` の `ZAISRV` の行(新だけ。旧・切り戻し後は4行)。列名は正しかった。12行・在庫は旧・新で一致。`CPF4123` は旧に各1回、新に0回。`OBJTEXT` は新で空だった(`TEXT` なし)が、印にはしない。

固定形式 RPG IV ルート(Issue #35)の 10-03 の囲みにある「新旧を見分ける印」を、実機で決めるためのバッチです。**2026-10-04に実行しました(結果は上の要点と docs/probes.md)。** ルートでは旧 `ZA0500` も `OBJATTRIBUTE` が `RPGLE` なので、`OBJECT_STATISTICS` の `OBJATTRIBUTE` では新旧を見分けられません。

旧 `ZA0500`(RPG IV 版)は手で変換したもの(未検証)です。まず変換結果がコンパイルできるかどうかが、最初の関門です。

## 実行前に確かめること

- DBVER 1、旧システムが RPG III であること(外れていれば何も変えずに止まります)。
- `$HOME/ibmi-kyozai` の扱いは、`part10-01-rpgle/expected/notes.md` と同じです。

## 結果を読む順番

0. `VFYLOG` に `part10-03-rpgle FAILSAFE` があれば、監視されていない例外でラッパーが途中で終わっています。**RPG III への復元(`RSTLEG` 以降)は実行されていません。** 最後の状態の行は復元の証拠として読まず、先に下の「復旧」を行います。
1. `VFYLOG` の `GATE STOP`・`SWITCH GATE STOP`・`BKGUARD STOP`。`SWITCH GATE STOP` なら変換結果のコンパイルに失敗(`VFYEVF`・`VFYEVL`)、`BKGUARD STOP` なら退避 `ZA0ORIG` が作れていません。どちらも `RSTLEG` 以降だけ実行しています。
2. `<ラベル> FAILED`。`BMx`・`BSx`・`PIx`(`x` は `O`・`N`・`R`)が `FAILED` なら、`PROGRAM_LIBRARY`・`PROGRAM_NAME` という列名が違う可能性があります。`BMCOLS` の `db2` の出力(`SELECT *` の見出し)と、`SYSCOLUMNS` の一覧(`QSYS2.BOUND_MODULE_INFO` などの列)から、本当の列名を読んで、マニフェストを直して再実行します。
3. `VFYATTR`: `T1-SWITCH` の `ZA0500` が `RPGLE`(旧)。

## 主な値(予測)

| 項目 | 予測 | 見る場所 |
|---|---|---|
| 旧 `ZA0500`(ILE)の `*TEST` の12行(`YTO`) | 12行(`OK` 10・`SHORT` 2)。`part10-03-modernize/expected/golden-test-12.txt` と、末尾の空白を除いて一致するかを記録する。PUB400 の末尾の1行は比べない | `VFYPYTO`、`COUNTS` |
| 旧の `*LIVE` の在庫(`OLD-LIVE`) | `P00001`〜`P00006` が 39・3・235・48・9・20(RPG III 版の実測。`zaikom-live-after.txt`)。違えば、そのまま記録する | `VFYZ`、`VFYMARK` |
| 旧の `CPF4123` | RPG III 版では2回。ILE 版は未確認。`VFYJR3` の `YTO-ID` と `YLO-ID` の行数を数える | `VFYJR3` |
| 新 `ZA0500`(`SQLRPGLE`、`ZAISRV` を束縛)の作成 | `CRTSQLRPGI` が重大度 `00`。`RNS9304` に当たるメッセージ(RPG III 版の検証で出たもの) | `VFYLOG` |
| 新の12行(`YTN`)・`*LIVE` の在庫(`NEW-LIVE`) | 旧と同じ。`VFYZ` の `OLD-LIVE` と `NEW-LIVE` の差は0行(最後の `EXCEPT` の問い合わせ) | `VFYPYTN`、`VFYZ` |
| 新の `CPF4123` | RPG III 版では出なかった。ILE 版は未確認 | `VFYJR3`(`YTN-ID`) |
| 切り戻し後(`YTR`) | 12行、印の状態が旧と同じ | `VFYPYTR`、`VFYBMR` など |
| **印の候補1**: `BOUND_MODULE_INFO` | 旧は `QRPGLE112` のメンバーから作った(ソース・ファイルの列が `QRPGLE112`)、新は `CRTSQLRPGI` が作るので別の値になるはず(`QSQLTEMP1` のような一時ソースが入るかもしれない)。**どの列が新旧で違うかを、`VFYBMO`・`VFYBMN`・`VFYBMR` を並べて決める** | `VFYBMO`・`VFYBMN`・`VFYBMR` |
| **印の候補2**: `BOUND_SRVPGM_INFO` | 新だけ `ZAISRV` を束縛した行が出る(`ctl-opt bnddir`)。旧と切り戻し後は0行。**最も単純な印になる見込み** | `VFYBSO`・`VFYBSN`・`VFYBSR` |
| **印の候補3**: `PROGRAM_INFO` | 活動化グループ・作成時刻などの列に差が出るか。旧の `DFTACTGRP(*YES)` と、新の `ctl-opt` の指定 | `VFYPIO`・`VFYPIN`・`VFYPIR` |
| `OBJECT_STATISTICS` の `OBJCREATED`・`OBJTEXT` | `OBJCREATED` は作り直すたびに変わる。`OBJTEXT` は `TXLEGACY` が付けるテキスト(`Stock allocation`)が、新では変わるかを見る(`OBJTEXT` では駄目、と計画で見込んだ点を確かめる) | `VFYMARK` の `ZA0500-OBJ` |
| 最後の状態 | `Z-FINAL` の `ZA0500`・`JU0300`・`TK0100` が `RPG`、`TXLEGLNG` が `*RPG`、行数 8・12・6、在庫の合計 392 | `VFYATTR`、`VFYMARK` |

## 教材に書く前に確かめる点

`docs/part10/10-03-modernization-devbase.md` の囲み「ルート版の印(候補)」のうち、このバッチで決まるもの。

- 3つの印のうち、新旧で値が違い、切り戻し後に旧と同じ値へ戻るのはどれか。列名(`PROGRAM_LIBRARY`・`PROGRAM_NAME` を含む)が正しいか。
- 旧 `ZA0500`(RPG IV 版)の12行・在庫・`CPF4123`。

答えが出ないもの: `makei` で作った `ZA0500` が束縛する `ZAISRV`(このバッチは `CRTSQLRPGI` で作る。10-03 本文の `makei` の経路とは作り方が違う)、`TSTZA0500`・`RUNTEST` の38件、`rpglint`。

## 途中で止まったときの手作業での復旧

1. 残っているジョブを終わらせる: `ENDJOB JOB(TXR3TO|TXR3LO|TXR3TN|TXR3LN|TXR3TR) OPTION(*IMMED)`。
2. `DSPDTAARA DTAARA(<USER>2/TXLEGLNG)` が `*RPGLE` なら、`<USER>2/TXLEGACY LIB(<USER>2) LANG(*RPG) FORCE(*YES)`、続けて `<USER>2/TXRESET LIB(<USER>2)`。これで `ZA0500`(新を入れていた場合も)は RPG III の旧版に戻ります(`TXLEGACY` が作り直す)。
3. `ZA0500`・`JU0300`・`TK0100` の `OBJATTRIBUTE` が `RPG` であること、`JUCHUM`・`JUCHUD`・`ZAIKOM` が 8・12・6 行、在庫の合計が392であることを確かめる。
4. 作ったままのもの: `RG0500`・`RG0300`・`RG0100`(`*PGM`、`DLTPGM` で消す)、`<USER>B/ZA0ORIG`(`*PGM`。`DLTPGM` で消す)。`ZAISRV`(`*SRVPGM`、`*MODULE`)・`ZAISRVBD`(`*BNDDIR`)と `QRPGLESRC`・`QSRVSRC` のメンバーは、元からあるものを `REPLACE(*YES)` で作り直しただけなので、残します。
