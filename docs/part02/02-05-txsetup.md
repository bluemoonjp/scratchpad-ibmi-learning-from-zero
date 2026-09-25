# 02-05 TXSETUP で DB を完成させる

> 所要時間: 75分(長め)/ 前提レッスン: 02-04 / 目標番号: 1 / 観測方法: `TXSTATUS` の表示 / 道具: 5250 / 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1` に `TXSETUP`・`TXSTATUS`・`TXRESET`(プログラム、同名のコマンド)、6物理ファイル+2論理ファイル、`TXSTATE`(データ域)/ DBVER: **この時点で 1 になる** / 依存するプローブ: P07, P13 / PTF 依存: なし / 容量の目安: 数百 KB

## ゴール

- `TXSETUP` を自分でコンパイルし、実行して、サンプル・データベースを完成させられる。
- `TXSTATUS` で `DBVER=1` になったことを確認できる。

## ウォームアップ

<details><summary>前回の復習</summary>

1. `git clone --sparse` の後、git を使うために最初にすることは?
2. 5250 と SSH は同じジョブ?

答え: 1. PATH を通す(`export PATH=/QOpenSys/pkgs/bin:$PATH`) 2. 別のジョブ

</details>

## なぜ学ぶか

02-02 で `TOKUIM`・`SHOHIM` を手で作りましたが、残り4つの物理ファイルと2つの論理ファイル、そして初期データまで、すべて手で作るのは大変です。ここでは、`TXSETUP` という CL プログラム(このリポジトリーに含まれています)を1本だけコンパイルして実行し、残りを一括で完成させます。

## 新出

- `TXSETUP`・`TXSTATUS`・`TXRESET`(この教材専用のツール)
- `RUNSQLSTM`(SQL スクリプトをまとめて実行する)
- 状態データ域 `TXSTATE`(`DBVER` を保持する)
- `CRTCMD`(CL プログラムを、専用のコマンドとして使えるようにする。詳しい書き方は03-11で学びます)

## 説明

### TXSETUP がすること

`TXSETUP`(`tools/qclsrc/txsetup.clp`)は、次の順に処理します。

1. まだ構築されていなければ、`QDDSSRC` に6つの物理ファイルと2つの論理ファイルのソースを取り込み、コンパイルする(02-02 で手入力した `TOKUIM`・`SHOHIM` は、既にあるものとして上書きしません)。
2. `RUNSQLSTM` で、`db/data/load_v1.sql` の内容(初期データ)を読み込む。
3. `TXSTATE` というデータ域を作り、`DBVER`(データベースの版数)を `1` にする。

### TXSTATUS と TXRESET

- `TXSTATUS` は、`TXSTATE` の値(`DBVER`)を表示するだけの、状態確認用のプログラムです。
- `TXRESET` は、**スキーマ(ファイルの構造)はそのままに、データだけを初期状態に戻します。** 演習でデータを更新・削除した後、元に戻すときに使います(02-07 で使います)。

## 実演

1. SSH で接続し、`~/ibmi-kyozai` が最新であることを確認する(`git pull`)。`exit` で 5250 に戻る。
2. 5250 のコマンド行に `ADDPFM FILE(<自分のユーザー名>1/QCLSRC) MBR(TXSETUP) SRCTYPE(CLP) TEXT('Build sample DB')` と打ち、Enter を押す。
3. `ADDPFM FILE(<自分のユーザー名>1/QCLSRC) MBR(TXSTATUS) SRCTYPE(CLP) TEXT('Show DB version')` を実行する。
4. `ADDPFM FILE(<自分のユーザー名>1/QCLSRC) MBR(TXRESET) SRCTYPE(CLP) TEXT('Reset DB data')` を実行する。
5. 5250 のコマンド行に `CRTSRCPF FILE(<自分のユーザー名>1/QCMDSRC) RCDLEN(92) TEXT('Command sources')` と打つ(`QCLSRC` は `<USER>1` に最初から入っていますが、`QCMDSRC`(**コマンド定義**のソース)はありません。01-06 で `QRPGSRC` を作ったのと同じ要領です)。
6. SSH でもう一度接続し、次の6つを実行してソースを取り込む(1回の接続でまとめて行います)。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/tools/qclsrc/txsetup.clp') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QCLSRC.FILE/TXSETUP.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/tools/qclsrc/txstatus.clp') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QCLSRC.FILE/TXSTATUS.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/tools/qclsrc/txreset.clp') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QCLSRC.FILE/TXRESET.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/tools/qcmdsrc/txsetup.cmd') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QCMDSRC.FILE/TXSETUP.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/tools/qcmdsrc/txstatus.cmd') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QCMDSRC.FILE/TXSTATUS.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/tools/qcmdsrc/txreset.cmd') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QCMDSRC.FILE/TXRESET.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

7. 5250 に戻り、3本の CL プログラムと、3本の**コマンド**をコンパイルする。

   - `CRTCLPGM PGM(<自分のユーザー名>1/TXSETUP) SRCFILE(<自分のユーザー名>1/QCLSRC) SRCMBR(TXSETUP)`
   - `CRTCLPGM PGM(<自分のユーザー名>1/TXSTATUS) SRCFILE(<自分のユーザー名>1/QCLSRC) SRCMBR(TXSTATUS)`
   - `CRTCLPGM PGM(<自分のユーザー名>1/TXRESET) SRCFILE(<自分のユーザー名>1/QCLSRC) SRCMBR(TXRESET)`
   - `CRTCMD CMD(<自分のユーザー名>1/TXSETUP) PGM(*LIBL/TXSETUP) SRCFILE(<自分のユーザー名>1/QCMDSRC) SRCMBR(TXSETUP)`
   - `CRTCMD CMD(<自分のユーザー名>1/TXSTATUS) PGM(*LIBL/TXSTATUS) SRCFILE(<自分のユーザー名>1/QCMDSRC) SRCMBR(TXSTATUS)`
   - `CRTCMD CMD(<自分のユーザー名>1/TXRESET) PGM(*LIBL/TXRESET) SRCFILE(<自分のユーザー名>1/QCMDSRC) SRCMBR(TXRESET)`

   **`*CMD`(コマンド)と `*PGM`(プログラム)は、同じ名前でも別のオブジェクトとして共存できます。** コマンドは「呼び出されたときにプログラムを実行する」だけの薄い定義で、CPP(Command Processing Program、ここでは同名の `*PGM`)に処理を委譲します。**`PGM()` にはライブラリー名を `<自分のユーザー名>1` と決め打ちせず `*LIBL` を指定してください。** `CRTCMD` の `PGM()` は、指定したライブラリー名をコマンド定義の中に永続的に持ちます(05-12・08-08 で、開発用ライブラリーへの参照が残っていないか確認する回があります)。`*LIBL` にしておけば、実行時の `*LIBL` にある同名の `*PGM` を毎回探すため、将来 `<自分のユーザー名>2`(本番役)へ移しても書き換えが要りません。

8. `TXSETUP`(コマンド名をそのまま打つだけです。`CALL PGM(...)` は使いません)。数十秒かかることがあります。

   **なぜ `CALL PGM(TXSETUP) PARM(...)` ではなく、専用のコマンドを経由するのか**: `CALL` にコマンド行から直接リテラルを渡すと、文字リテラルは32バイトまでしか正しく渡らないという CL の落とし穴があります(03-08 で詳しく学びます)。`TXSETUP` の `CLONEDIR` パラメーター(200桁)のような長いパラメーターを `CALL ... PARM()` に直接書くと、この罠にかかってエラーになることがあります。**`*CMD` 経由の呼び出しは、コマンド定義の宣言どおりにパラメーターを組み立てるため、この罠が起きません。** これが、CL プログラムを直接 `CALL` させず、専用のコマンドでラップして配布している理由です。

9. `TXSTATUS` を実行し、`DBVER=1` と表示されることを確認する。

## 演習

1. `DSPPFM FILE(<自分のユーザー名>1/ZAIKOM)` を実行し、6件の在庫データが入っていることを確認してください(02-01 の ER 図で確認した `SHOHIM` の6商品と対応します)。
2. `DSPPFM FILE(<自分のユーザー名>1/JUCHUD)` で、受注明細のデータも入っていることを確認してください。

## 出力が違うとき

- コンパイルでエラーが出た場合、`git pull` で最新のソースを取り込んでいるか確認してください(この教材自体に修正が入っている可能性があります)。
- `TXSETUP` の実行で失敗した場合、`DSPJOBLOG` を確認してください。よくある原因は、SSH で取り込んだファイルのパスの誤りです。

## セルフチェック

- [ ] `TXSETUP`・`TXSTATUS`・`TXRESET` をコンパイルできた。
- [ ] `TXSETUP` を実行し、`DBVER=1` になったことを確認できた。
- [ ] `DSPPFM` で、データが入っていることを確認できた。

## 片付け

作成したオブジェクトは、この先ずっと使うのでそのまま残してください。

## まとめ

次のレッスン(02-06)では、実際に SQL で受注照会をしてみます(この教材を通して繰り返す「受注照会」の最初の形です)。

## 実機メモ

- 確認日: 2026-09-25。DDS(6物理ファイル+2論理ファイル)・`TXSETUP`/`TXSTATUS`/`TXRESET` の CL・**`*CMD`(コマンド定義)は、すべて `<USER>2` で実機コンパイル0エラーを確認済み。** `TXSETUP` の実行そのもの(ハングの原因だった `MONMSG` の誤りを修正した版)は、`CALL PGM(...) PARM(...)` で明示的にパラメーターを渡す形と、**`*CMD` 経由(`TXSETUP LIB(<USER>2)`)の両方で完走を確認済み**(`DBVER=1`、全6物理ファイル+2論理ファイルの件数も確認)。`*CMD` 経由では、パラメーター省略時の `CPD0172` は再現しなかった。**`RTVJOBA USER()` が `QUSER` を返す問題は、`*CMD` 経由でも再現することが後日の追加検証で判明し、`tools/qclsrc/txsetup.clp`/`txreset.clp` を `RTVJOBA CURUSER()` に修正した(`docs/probes.md` の「訂正」節を参照)。この修正版での完全な通し実行(`CLONEDIR` 省略・実際の `git clone --sparse` との組み合わせ)は、SSH の接続数制限のためこのセッションでは完了できていない。** また、この手順(2〜9)が指示している「5250 の対話的コマンド行からの一連の操作」そのものの実機確認は、SSH 経由の `system()` を使った検証で代替しており、5250 の対話的コマンド行そのもので試したわけではない。詳細は `docs/probes.md` を参照。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
