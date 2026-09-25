# 02-05 TXSETUP で DB を完成させる

> 所要時間: 75分(長め)/ 前提レッスン: 02-04 / 目標番号: 1 / 観測方法: `TXSTATUS` の表示 / 道具: 5250 / 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1` に `TXSETUP`・`TXSTATUS`・`TXRESET`(プログラム)、6物理ファイル+2論理ファイル、`TXSTATE`(データ域)/ DBVER: **この時点で 1 になる** / 依存するプローブ: P07, P13 / PTF 依存: なし / 容量の目安: 数百 KB

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
5. SSH でもう一度接続し、次の3つを実行してソースを取り込む(1回の接続でまとめて行います)。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/tools/qclsrc/txsetup.clp') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QCLSRC.FILE/TXSETUP.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/tools/qclsrc/txstatus.clp') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QCLSRC.FILE/TXSTATUS.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/tools/qclsrc/txreset.clp') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QCLSRC.FILE/TXRESET.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

6. 5250 に戻り、3本ともコンパイルする。

   - `CRTCLPGM PGM(<自分のユーザー名>1/TXSETUP) SRCFILE(<自分のユーザー名>1/QCLSRC) SRCMBR(TXSETUP)`
   - `CRTCLPGM PGM(<自分のユーザー名>1/TXSTATUS) SRCFILE(<自分のユーザー名>1/QCLSRC) SRCMBR(TXSTATUS)`
   - `CRTCLPGM PGM(<自分のユーザー名>1/TXRESET) SRCFILE(<自分のユーザー名>1/QCLSRC) SRCMBR(TXRESET)`

7. `CALL PGM(TXSETUP)`(パラメーターは省略でき、既定で `*CURLIB` と、ホーム・ディレクトリー配下の `ibmi-kyozai` が使われます)。数十秒かかることがあります。
8. `CALL PGM(TXSTATUS)` を実行し、`DBVER=1` と表示されることを確認する。

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

- 確認日: 2026-09-25。DDS(6物理ファイル+2論理ファイル)は `<USER>2` で実機コンパイル0エラーを確認済み。`TXSETUP`/`TXSTATUS`/`TXRESET` の CL は、実機コンパイルで4件のバグを修正済みだが、**`TXSETUP` 全体を通しで実行する検証は、このセッションの SSH 接続数上限により未完了。** 次回 SSH が使えるようになり次第、優先して完了させる(`docs/probes.md` 参照)。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
