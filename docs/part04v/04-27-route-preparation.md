# 04-27 準備: 道具と旧システムを用意する

> 所要時間: 90分(長め。途中で止めてもかまいません)/ 前提レッスン: [04-26](04-26-display-files.md)(ルートの [04-21](04-21-fixed-form-skeleton.md)〜04-26。さらに 02-05 でサンプル・データベースを作り、02-04 で `~/ibmi-kyozai` を clone してあること)/ 目標番号: 4 / 観測方法: ジョブ・ログ・`DSPDTAARA`・SQL(`OBJECT_STATISTICS`)/ 道具: 5250(PDM/SEU)、SSH / 同時接続数: 5250×1(取り込みのときだけ SSH を併用)/ 作る・変えるオブジェクト: `<USER>1` に `TXCKM`・`TXCHECK`・`TXSNAP`・`TXSNAPT`・`QRPGLE112`・`V0601A`・`LASTCD`・`TXLEGLNG`・旧システム一式(固定形式 RPG IV 版)、`<USER>2` に同じ旧システム一式 / DBVER: 1 / 依存するプローブ: なし / PTF 依存: なし / 容量の目安: 数十 KB〜数百 KB

**このレッスンは、第4部・第5部(RPG III)を通ってきた人は行いません。** 第4部・第5部を終えた人は、ここで作るもの(`TXCHECK`・`TXSNAP`・旧システムなど)を、すでにそれぞれのレッスンで作っています。第6部へそのまま進んでください(第5部まで終えた人が旧システムを RPG III のまま使い続ける道は、このレッスンの影響を受けません)。

> **前提を確かめてください。** このルートの対象は、`CRTBNDRPG`(固定形式、または固定形式と `/FREE` の混在)で RPG を書いている職場です。`CRTRPGPGM` で RPG III をコンパイルしている職場は、RPG III そのものを読み書きする必要があるので、このルートの対象外です(通常の一本道に進んでください)。

## ゴール

- `04-27-1`: 第6〜10部の演習が前提にする道具(`TXCHECK`・`TXSNAP`)と、06-01b が開く `V0601A` を、第4部・第5部を通らずに自分の `<USER>1` に用意できる。
- `04-27-2`: 旧システム(`TK0100`・`JU0300`・`ZA0500` など)を固定形式 RPG IV 版(`LANG(*RPGLE)`)で `<USER>1` と `<USER>2` に入れ、RPG III のオブジェクトが1つも残っていないことを `OBJECT_STATISTICS` と `TXLEGLNG` で確かめられる。
- `04-27-3`: 旧システムの CL(`JU0900C`)と RPG IV の `ZA0500` の間にあるパラメーターの桁の食い違い(チケット1)を診断し、`<USER>1` の `JU0900C` を直せる。また、`FORCE(*YES)` で旧システムを入れ直すと、この修正が元に戻ることを説明できる。

## ウォームアップ

<details><summary>前回までの復習</summary>

1. 固定形式 RPG IV の手書きのソースは、どのソース物理ファイルに入れますか(04-21)? `CVTRPGSRC` の変換結果は?
2. CL の `CALL` で渡す数値と、呼ばれる RPG の `*ENTRY PLIST` の長さがずれると、どう困りますか(04-24)?
3. `TXSNAPT` を作るときに `MAXMBRS(*NOMAX)` を付けるのはなぜですか(05-08 で扱う内容です。分からなければ、A2 で読んでから答えてください)?

答え: 1. 手書きは `QRPGLESRC`、`CVTRPGSRC` の変換結果は 06-01 で作る `QRPGLE112` です(どちらも `RCDLEN(112)`)。 2. 個数さえ合っていればコンパイルも呼び出しも通ってしまい、受け取る側が呼ぶ側の確保した長さを超えて読むことがあります。 3. `BEFORE` の次に `AFTER` という2つ目のメンバーを追加できるようにするためです(既定の `MAXMBRS(1)` では2つ目の追加が失敗します)。

</details>

## なぜ学ぶか

第5部には、第6部以降が使う道具と材料を作るレッスンが散らばっています。

- `TXCHECK`(オブジェクトが存在するかを機械的に確かめる道具): 05-13 で初めて作ります。第6部以降のチェックポイント(06-15・07-05・08-08・09-07・第10部)が使います。
- `TXSNAP`(変更前後の印刷結果を保存する道具): 05-08 で作ります。第8部の改修(08-05・08-05b)が使います。
- `TXLEGACY`(旧システムを入れる道具)と旧システム本体: 05-01 で入れます。第8部・第10部の題材です。
- `<USER>2`(本番役のライブラリー): 05-12 で初めて使います。第8部・第10部が使います。
- チケット1の修正: 05-13 で行います。第8部の 08-05b がその修正を前提にします。

RPG III を通らないルートでは、この5つをここで**1本のレッスンにまとめて**用意します。旧システムは、RPG III のソースではなく、**固定形式 RPG IV に移した版**(`src/legacy/qrpgle112/`)を入れます。オブジェクト名(`JU0300`・`ZA0500`・`TK0100` など)は RPG III 版と同じなので、第8部・第10部の CL やコマンドは変わりません。

## 新出

### 中核(3つ)

- **`TXLEGACY` の `LANG` パラメーター**: 旧システムを入れるときのソースの言語。`*RPG`(RPG III。一本道)、`*RPGLE`(固定形式 RPG IV。このルート)、`*SAME`(既定。`TXLEGLNG` に記録された言語を使い、記録が無ければ `*RPG`)。
- **`TXLEGLNG`**: `TXLEGACY` が最後に記録する、7桁の文字型データ域。どの言語で入れたかが入っています。
- **`OBJECT_STATISTICS` の `OBJATTRIBUTE`**: オブジェクトの属性(プログラムなら、作ったコンパイラーの種類)を返す列。ここでは RPG III と RPG IV を見分けるのに使います。

### コマンド等(6つまで)

- `TXCHECK`・`TXSNAP`: このレッスンで作る道具(中身の説明は 05-13・05-08 にあります)。
- `CRTSRCPF`・`ADDPFM`・`CPYFRMSTMF`: ソースを取り込む、いつもの3点セット(02-05・05-01 と同じ使い方です)。
- `CRTBNDRPG`: 固定形式 RPG IV のコンパイル(04-21)。

### 読解用

`DSPDTAARA`・`CRTCLPGM`・`CRTCMD` は、これまでのレッスンで使い方を学習済みです。

## 説明

### 全体の流れ

このレッスンの手順は、実行する順に A0〜A6、C、B と名前を付けています。

| 手順 | 内容 | 出典 |
|---|---|---|
| A0 | 前提の確認 | 05-01・05-12 |
| A1 | `TXCHECK` を作る | 05-13 |
| A2 | `TXSNAP`・`TXSNAPT` を作る | 05-08 |
| A3 | 06-01b 用の `V0601A` を作る | 06-01 |
| A4 | 旧システムを固定形式 RPG IV 版で `<USER>1` に入れる | 05-01 |
| A5 | RPG III が無いことの確認 | このレッスン |
| A6 | `TXCHECK` の自己確認 | 05-13 |
| C | 本番役 `<USER>2` に旧システムを入れる | 05-12 |
| B | チケット1の診断と修正(08-05b の直前に行う) | 05-13 |

A0〜A6 は続けて行ってください。C は第8部の 08-08 に入る前までに済ませます。B は 08-05b に入る直前に行います(B より先に A4 の旧システムが必要です)。

### 注意: 旧システムを入れ直すと、B の修正は元に戻ります

`TXLEGACY` の `FORCE(*YES)` は、旧システムをソースから作り直します。**作り直しに使う `JU0900C` のソースは、チケット1が直っていない配布版**です。したがって、B で `JU0900C` を直したあとに `TXLEGACY ... FORCE(*YES)` を実行すると、修正は元に戻ります(`JU0900C` が配布版のコンパイル結果に置き換わるため)。第10部で `TXLEGACY LIB(<USER>1) FORCE(*YES)` を実行する場面があれば、そのあとにもう一度 B をやり直してください。`LANG` を省略すれば `*SAME`(`TXLEGLNG` どおり)なので、`*RPGLE` の旧システムはそのまま保たれます。

## 実演

**ここから先は、第4部・第5部の実機確認済みの手順を、このルート向けに並べ直したものです。固定形式 RPG IV 版の旧システム(`LANG(*RPGLE)`)を実機で実行した結果は、まだ確認していません(実機メモ参照)。**

### A0 前提の確認

1. `TXSTATUS LIB(<USER>1)` を実行し、`DBVER` が `1` であることを確認します。`TXSTATUS` が無いか、`DBVER` が `1` でなければ、先に 02-05 に戻ってください。
2. SSH で接続し、`~/ibmi-kyozai` を最新にします(05-01 手順1と同じです)。固定形式 RPG IV 版の旧システム(`src/legacy/qrpgle112/`)は、新しい版にしか入っていません。

   ```sh
   cd ~/ibmi-kyozai
   git pull
   ls src/legacy/qrpgle112
   ```

   `ju0300.rpgle`・`za0500.rpgle`・`tk0100.rpgle` の3本が見えることを確かめます。

3. すでに RPG III 版の旧システムを `<USER>1` に入れてしまっている場合は、A4 で `LANG(*RPGLE) FORCE(*YES)` を使って入れ直します(A4 の注意を読んでください)。`DSPDTAARA DTAARA(<USER>1/TXLEGST)` で、値が見えれば入れ済みです。

### A1 `TXCHECK` を作る

出典: 05-13「実演」の手順1(94〜108行目あたり)。`TXCKM` を先に作ります(`TXCHECK` の `DCLF` が実在する `TXCKM` を必要とするため)。

1. ソース・メンバーを作ります(5250)。

   ```text
   ADDPFM FILE(<USER>1/QDDSSRC) MBR(TXCKM) SRCTYPE(PF) TEXT('TXCHECK manifest')
   ADDPFM FILE(<USER>1/QCLSRC) MBR(TXCHECK) SRCTYPE(CLP) TEXT('Run per-lesson checks')
   ADDPFM FILE(<USER>1/QCMDSRC) MBR(TXCHECK) SRCTYPE(CMD) TEXT('TXCHECK command')
   ```

2. SSH で、ソースを取り込みます(02-05・05-01 と同じ `CPYFRMSTMF` です)。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<USER>/ibmi-kyozai/tools/qddssrc/txckm.pf') TOMBR('/QSYS.LIB/<USER>1.LIB/QDDSSRC.FILE/TXCKM.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<USER>/ibmi-kyozai/tools/qclsrc/txcheck.clp') TOMBR('/QSYS.LIB/<USER>1.LIB/QCLSRC.FILE/TXCHECK.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<USER>/ibmi-kyozai/tools/qcmdsrc/txcheck.cmd') TOMBR('/QSYS.LIB/<USER>1.LIB/QCMDSRC.FILE/TXCHECK.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

3. 5250 に戻り、次の順にコンパイルします(`TXCKM` → `TXCHECK` の `*PGM` → `TXCHECK` の `*CMD`)。

   ```text
   CRTPF FILE(<USER>1/TXCKM) SRCFILE(<USER>1/QDDSSRC) SRCMBR(TXCKM)
   CRTCLPGM PGM(<USER>1/TXCHECK) SRCFILE(<USER>1/QCLSRC) SRCMBR(TXCHECK)
   CRTCMD CMD(<USER>1/TXCHECK) PGM(*LIBL/TXCHECK) SRCFILE(<USER>1/QCMDSRC) SRCMBR(TXCHECK)
   ```

`TXCHECK` が確かめるのは、**オブジェクトの存在と型だけ**です(05-13 で説明した v1 の限界)。ロジックが正しいかどうかは、`TXCHECK` では分かりません。

### A2 `TXSNAP` と `TXSNAPT` を作る

出典: 05-08「実演」の手順0〜1。`QCMDSRC` が無ければ、先に `CRTSRCPF FILE(<USER>1/QCMDSRC) RCDLEN(92)` を実行してください(03-11 で作成済みのはずです)。

1. ソース・メンバーを作ります(5250)。

   ```text
   ADDPFM FILE(<USER>1/QCLSRC) MBR(TXSNAP) SRCTYPE(CLP) TEXT('Snapshot a spooled file')
   ADDPFM FILE(<USER>1/QCMDSRC) MBR(TXSNAP) SRCTYPE(CMD) TEXT('TXSNAP command')
   ```

2. SSH で、ソースを取り込みます。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<USER>/ibmi-kyozai/tools/qclsrc/txsnap.clp') TOMBR('/QSYS.LIB/<USER>1.LIB/QCLSRC.FILE/TXSNAP.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<USER>/ibmi-kyozai/tools/qcmdsrc/txsnap.cmd') TOMBR('/QSYS.LIB/<USER>1.LIB/QCMDSRC.FILE/TXSNAP.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

3. 5250 に戻り、コンパイルします。そのあと、保存先の物理ファイル `TXSNAPT` を、**あらかじめ1回だけ**作ります(`CPYSPLF` は `TOFILE` が無いと失敗するため。`MAXMBRS(*NOMAX)` は、`BEFORE` の次に `AFTER` のメンバーを足すためです。05-08 で説明済みです)。

   ```text
   CRTCLPGM PGM(<USER>1/TXSNAP) SRCFILE(<USER>1/QCLSRC) SRCMBR(TXSNAP)
   CRTCMD CMD(<USER>1/TXSNAP) PGM(*LIBL/TXSNAP) SRCFILE(<USER>1/QCMDSRC) SRCMBR(TXSNAP)
   CRTPF FILE(<USER>1/TXSNAPT) RCDLEN(133) MAXMBRS(*NOMAX) TEXT('TXSNAP snapshots')
   ```

### A3 06-01b 用の `V0601A` を作る

06-01 では `R0408A`(RPG III)を `CVTRPGSRC` で変換して `V0601A` を作りますが、このルートには元の `R0408A` がありません。同じ内容の固定形式 RPG IV ソースが `src/qrpglesrc/v0601s.rpgle` にあるので、それを取り込みます。

**入れる先は `QRPGLESRC` ではなく `QRPGLE112` です。** 06-01b の手順6が `V0601A` を `QRPGLE112` から開くためです(04-21 で説明した2つのソース物理ファイルの使い分けのうち、`CVTRPGSRC` の変換結果の置き場所にあたります)。

1. `QRPGLE112` を作ります(5250)。すでにあれば、`CPF5813` などの「既に存在する」という趣旨のメッセージが出ますが、そのまま次に進んでかまいません(`CRTPF` では `CPF5813` の直後に `CPF7302` が出た実績が 06-01b にありますが、**`CRTSRCPF` でのメッセージ ID は未検証(2026-10-01時点)** です)。

   ```text
   CRTSRCPF FILE(<USER>1/QRPGLE112) RCDLEN(112) TEXT('Curriculum RPG IV (fixed form) sources')
   ADDPFM FILE(<USER>1/QRPGLE112) MBR(V0601A) SRCTYPE(RPGLE) TEXT('V0601A (R0408A as fixed-form RPG IV)')
   ```

2. SSH で、ソースを取り込みます。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<USER>/ibmi-kyozai/src/qrpglesrc/v0601s.rpgle') TOMBR('/QSYS.LIB/<USER>1.LIB/QRPGLE112.FILE/V0601A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

3. 5250 に戻り、コンパイルして実行します。

   ```text
   CRTBNDRPG PGM(<USER>1/V0601A) SRCFILE(<USER>1/QRPGLE112) SRCMBR(V0601A)
   CALL PGM(<USER>1/V0601A)
   ```

   `WRKSPLF` で最新の `QSYSPRT` を開き、04-21 の `V0421D` と同じ2行(`ACME TRADING CO` の `J00001` と `J00003`)が印刷されていることを確かめます。`v0601s.rpgle` は、06-01 が実機で確認した `V0601A`(確認日2026-09-26、V2)の変換結果そのままです。

### A4 旧システムを固定形式版で入れる

出典: 05-01「実演」の手順2〜7。ただし、**05-01 の手順9にある `<USER>1B` は誤記なので、そのまま写さないでください**(`<USER>B` が SAVF の置き場です)。

1. `TXLEGACY` のソースを取り込みます。`LANG` パラメーターを持つ版が、`git pull` 済みの `tools/` にあります。

   ```text
   ADDPFM FILE(<USER>1/QCLSRC) MBR(TXLEGACY) SRCTYPE(CLP) TEXT('Load legacy system')
   ADDPFM FILE(<USER>1/QCMDSRC) MBR(TXLEGACY) SRCTYPE(CMD) TEXT('TXLEGACY command')
   ```

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<USER>/ibmi-kyozai/tools/qclsrc/txlegacy.clp') TOMBR('/QSYS.LIB/<USER>1.LIB/QCLSRC.FILE/TXLEGACY.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<USER>/ibmi-kyozai/tools/qcmdsrc/txlegacy.cmd') TOMBR('/QSYS.LIB/<USER>1.LIB/QCMDSRC.FILE/TXLEGACY.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

2. 5250 に戻り、コンパイルします。

   ```text
   CRTCLPGM PGM(<USER>1/TXLEGACY) SRCFILE(<USER>1/QCLSRC) SRCMBR(TXLEGACY)
   CRTCMD CMD(<USER>1/TXLEGACY) PGM(*LIBL/TXLEGACY) SRCFILE(<USER>1/QCMDSRC) SRCMBR(TXLEGACY)
   ```

3. `TK0100` が実行時に必要とするデータ域 `LASTCD` を作ります(`TXLEGACY` は作りません。05-01 で確認済みです)。すでにあれば「既に存在する」という趣旨のメッセージが出るだけなので、そのまま次に進みます。

   ```text
   CRTDTAARA DTAARA(<USER>1/LASTCD) TYPE(*CHAR) LEN(6)
   ```

4. 旧システムを、固定形式 RPG IV 版で入れます。

   ```text
   TXLEGACY LIB(<USER>1) LANG(*RPGLE)
   ```

   ジョブ・ログに `TXLEGACY: loading legacy system into library ...` から `TXLEGACY: done. ...` までが並べば完了です。`QRPGLE112` にはこのとき `TK0100`・`JU0300`・`ZA0500` のメンバーが入り、A3 で作った `V0601A` のメンバーはそのまま残ります。

   - **RPG III 版をすでに入れてある場合**(A0 の手順3): 同じコマンドの末尾に `FORCE(*YES)` を付けます。`FORCE(*YES)` は、作り直す前に `<USER>B` に `LG` + 日付の名前の SAVF を作って退避します。`DSPSAVF FILE(<USER>B/LG......)` で、何が退避されたかを自分の目で確かめてください(05-01 手順9と同じ注意です。**全部が入っているとは限りません**)。

     ```text
     TXLEGACY LIB(<USER>1) LANG(*RPGLE) FORCE(*YES)
     ```

   - `FORCE(*NO)` のまま、すでに入っている言語と違う `LANG` を指定すると、「何も作り直さず、入っている言語はこれです」という趣旨の注意メッセージだけが出ます。

5. `DSPDTAARA DTAARA(<USER>1/TXLEGST)` の値が `Y` であることを確認します(05-01 手順7と同じです)。

### A5 RPG III が無いことの確認

1. 旧システムの RPG プログラムと `V0601A` が、**すべて RPG IV(`RPGLE`)でできている**ことを確かめます(ACS の「実行 SQL スクリプト」で実行します)。

   ```sql
   SELECT OBJNAME, OBJTYPE, OBJATTRIBUTE
     FROM TABLE(QSYS2.OBJECT_STATISTICS('<USER>1', '*PGM')) X
    WHERE OBJNAME IN ('TK0100', 'JU0300', 'ZA0500', 'V0601A')
    ORDER BY OBJNAME;
   ```

   4行すべてで `OBJATTRIBUTE` が `RPGLE` になっているはずです。1行でも `RPG`(RPG III)になっていたら、そのプログラムは RPG III のソースから作られています。A4 の `TXLEGACY` が `LANG(*RPGLE)` で動いたか、ジョブ・ログを確かめてください。

   `OBJATTRIBUTE` の列名と、RPG IV のプログラムが `RPGLE`、RPG III のプログラムが `RPG` と出ることは、10-03 の実機メモ(`part10-03-modernize`、V2)が確認済みです。**未検証(2026-10-01時点)**: `CRTBNDRPG` で作った固定形式 RPG IV の `TK0100`・`JU0300`・`ZA0500`・`V0601A` が `RPGLE` と出ることは、このレッスンの手順では実機でまだ確認していません(10-03 の確認は埋め込み SQL のプログラムです)。

2. `TXLEGLNG` の値を確かめます。

   ```text
   DSPDTAARA DTAARA(<USER>1/TXLEGLNG)
   ```

   `*RPGLE` と表示されるはずです。`TXLEGLNG` が無いときや値が `*RPG` のときは、RPG III 版のままです(`TXLEGACY` が最後に記録するデータ域のため、A4 が最後まで終わっていない可能性もあります)。

### A6 `TXCHECK` の自己確認

このレッスンで作ったものが揃っているかを、`TXCKM` に行を登録して `TXCHECK` で確かめます(05-13 の手順2〜4と同じ流れです)。`LESSON` の値は `'04-27'` です。二重登録を避けるため、先に同じ `LESSON` の行を消します。

```sql
DELETE FROM <USER>1/TXCKM WHERE LESSON = '04-27';

INSERT INTO <USER>1/TXCKM
  (LESSON, SEQNBR, OBJNAME, OBJTYPE, OBJATTR, CKDESC)
VALUES
  ('04-27', 10, 'TXCHECK', '*PGM',    ' ', 'TXCHECK exists'),
  ('04-27', 20, 'TXSNAP',  '*PGM',    ' ', 'TXSNAP exists'),
  ('04-27', 30, 'TXSNAPT', '*FILE',   ' ', 'TXSNAPT exists'),
  ('04-27', 40, 'V0601A',  '*PGM',    ' ', 'V0601A exists'),
  ('04-27', 50, 'TK0100',  '*PGM',    ' ', 'TK0100 exists'),
  ('04-27', 60, 'JU0300',  '*PGM',    ' ', 'JU0300 exists'),
  ('04-27', 70, 'ZA0500',  '*PGM',    ' ', 'ZA0500 exists'),
  ('04-27', 80, 'JU0900C', '*PGM',    ' ', 'JU0900C exists'),
  ('04-27', 90, 'LASTCD',  '*DTAARA', ' ', 'LASTCD exists'),
  ('04-27', 100, 'TXLEGLNG', '*DTAARA', ' ', 'TXLEGLNG exists');
```

`*CMD` 経由で実行します(`CALL PGM(...)` ではありません。05-13 のとおり、32バイト・リテラルの罠を避けるためです)。

```text
TXCHECK LESSON('04-27') LIB(<USER>1)
```

ジョブ・ログに `TXCHECK PASS: ...` が10件と、`TXCHECK: lesson 04-27 - 0000000010 passed,` に続く `0000000000 failed.` が出れば、オブジェクトが揃っています(件数は10桁ゼロ埋めです。05-13 と同じ形です)。`FAIL` が出たら、その行の `CKDESC` のオブジェクトを作る手順に戻ってください。`TXCHECK` は存在と型だけを見るので、RPG III か RPG IV かは A5 の確認で見分けます。

### C 本番役ライブラリーを用意する

出典: 05-12「実演」の手順1〜3。このルートでは、`<USER>2` にも旧システムを**固定形式 RPG IV 版で**入れます。第8部の 08-08 と第10部が使います。

1. `TXSTATUS LIB(<USER>2)` で、状態を確認します。「not initialized」と出れば、`<USER>2` を本番役として初めて使う準備をします。すでに準備済みなら、次の `TXSETUP` は不要です。

   ```text
   TXSTATUS LIB(<USER>2)
   TXSETUP LIB(<USER>2)
   ```

2. `LASTCD` を作ります(`<USER>2` にも要ります。05-12 手順3と同じです)。

   ```text
   CRTDTAARA DTAARA(<USER>2/LASTCD) TYPE(*CHAR) LEN(6)
   ```

3. 旧システムを入れます。

   ```text
   TXLEGACY LIB(<USER>2) LANG(*RPGLE)
   ```

4. A5 と同じ確認を `<USER>2` に対して行います。

   ```sql
   SELECT OBJNAME, OBJTYPE, OBJATTRIBUTE
     FROM TABLE(QSYS2.OBJECT_STATISTICS('<USER>2', '*PGM')) X
    WHERE OBJNAME IN ('TK0100', 'JU0300', 'ZA0500')
    ORDER BY OBJNAME;
   ```

   ```text
   DSPDTAARA DTAARA(<USER>2/TXLEGLNG)
   ```

   3行すべてが `RPGLE`、`TXLEGLNG` が `*RPGLE` であれば完了です(未検証の部分は A5 と同じです)。

### B 08-05b の直前に行う: チケット1の診断と修正

出典: 05-13「課題」のチケット1と、模範解答 [`solutions/05-13/ju0900c-ticket1.clp`](../../solutions/05-13/ju0900c-ticket1.clp)。08-05b は、このチケット1が直っていることを前提にします。**この手順は、08-05b を始める直前に行ってください。**

1. **診断する。** `<USER>1/QCLSRC` の `JU0900C` で、`&MINQTY` を宣言している行を探します。

   ```text
   DCL        VAR(&MINQTY) TYPE(*DEC) LEN(3 0)
   ```

   次に、`<USER>1/QRPGLE112` の `ZA0500` を開き、`*ENTRY PLIST` の `MINQTY` に対応する `PARM` の行を探します(04-24 で練習した形です。桁数と小数点位置が、結果フィールドの欄に書いてあります)。CL 側は `3,0`、RPG IV 側は `5,0` なのが食い違いです。**個数が合っているので、コンパイルは通ります**(03-08・04-24 のとおりです)。どちらを直しても、両方が一致すれば正解です。ここでは、模範解答に合わせて CL 側を `5,0` に広げます。

2. **直す。** SSH で、模範解答のソースを `QCLSRC` の `JU0900C` メンバーに取り込みます(配布版が置き換わります)。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<USER>/ibmi-kyozai/solutions/05-13/ju0900c-ticket1.clp') TOMBR('/QSYS.LIB/<USER>1.LIB/QCLSRC.FILE/JU0900C.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

3. 5250 に戻り、`REPLACE(*YES)` で再コンパイルします。

   ```text
   CRTCLPGM PGM(<USER>1/JU0900C) SRCFILE(<USER>1/QCLSRC) SRCMBR(JU0900C) REPLACE(*YES)
   ```

4. 取り込んだメンバーに `DCL VAR(&MINQTY) TYPE(*DEC) LEN(5 0)` があることを、`WRKMBRPDM` などで開いて確かめます。

5. **注意。** `TXLEGACY LIB(<USER>1) FORCE(*YES)` を実行すると、`JU0900C` は配布版のソース(`LEN(3 0)` のまま)から作り直されるので、この修正は元に戻ります。そのあとは、もう一度この手順の2〜4を行ってください。

**実行結果の確認は、このレッスンではしません。** RPG III 版の `ZA0500` では、食い違ったまま `JU0900C` から呼ぶと、実機で毎回 `RPG0907`(10進データ・エラー)で異常終了し、直すとそれが解消することが確認済みです(05-13 の実機メモ)。RPG IV 版の `ZA0500` で、どのメッセージ ID が出るかは**未検証(2026-10-01時点)**です。

## セルフチェック

- [ ] 第4部・第5部を通っていない自分の `<USER>1` に、`TXCHECK`・`TXSNAP`・`TXSNAPT` が揃った。
- [ ] `QRPGLE112` に `V0601A` を入れてコンパイルし、実行して2行(`J00001`・`J00003`)が印刷された。
- [ ] `TXLEGACY LIB(<USER>1) LANG(*RPGLE)` が `TXLEGACY: done.` まで終わった。
- [ ] `OBJECT_STATISTICS` の結果で、`TK0100`・`JU0300`・`ZA0500`・`V0601A` の属性がすべて `RPGLE` で、`TXLEGLNG` が `*RPGLE` だった。
- [ ] `TXCHECK LESSON('04-27') LIB(<USER>1)` で、10件とも PASS した。
- [ ] `<USER>2` にも旧システムを入れ、`TXLEGLNG` が `*RPGLE` だった。
- [ ] (08-05b の直前に)`JU0900C` の `&MINQTY` を `LEN(5 0)` にして再コンパイルし、`FORCE(*YES)` で入れ直すとこの修正が元に戻る理由を説明できる。

## 片付け

ここで作ったものは、第6〜10部で使うので、そのまま残してください。`<USER>2` の旧システムも残します(第10部が使います)。`TXSNAPT` に溜まった `BEFORE`・`AFTER` のメンバーは、第8部の演習で作り直すので、不要になったら `CLRPFM FILE(<USER>1/TXSNAPT) MBR(*ALL)` で空にしてもかまいません(このレッスンでは、まだメンバーは入りません)。

`<USER>B` に溜まった `LG......` の SAVF は、容量はわずかですが、不要になったものを `DLTF FILE(<USER>B/LG......)` で削除してもかまいません。

## まとめ

| 英語 | 日本語 |
|---|---|
| Legacy system | 旧システム |
| Manifest | 台帳(`TXCKM` の行の一覧) |
| Snapshot | スナップショット(`TXSNAP` が保存する印刷結果) |
| Source language | ソースの言語(`TXLEGACY` の `LANG`) |
| Object attribute | オブジェクト属性(`OBJATTRIBUTE`) |
| Production role | 本番役(`<USER>2`) |

次は [04-28](04-28-impact-analysis.md)(影響調査)に進みます。04-28 は、A4 で入れた旧システムを相手に調べるので、このレッスンのあとに行ってください。そのあとは [06-01b](../part06/06-01b-reading-fixed-mixed-form.md) に進みます。

## 実機メモ

- **未検証(2026-10-01時点)**: このレッスンの手順をそのまま通して実行した記録は、まだありません。実機で確認したのは、次の「根拠」の個別の部品だけです。
- **根拠(それぞれの出典のレッスンの実機メモが正本です)**:
  - `TXCKM`・`TXCHECK` の `*PGM` と `*CMD`: 05-13 の実機メモ(`part05-txcheck-probe` の V2、`part06-15-checkpoint` での `*CMD` 呼び出しの V2)。
  - `TXSNAP`・`TXSNAPT`(`CRTPF ... MAXMBRS(*NOMAX)`): 05-08(この手順そのものの通しは、05-08 の実機メモで確認してください)。
  - `V0601A`: 06-01 の実機メモ(`part06-01-cvtrpgsrc`、確認日2026-09-26、`CRTBNDRPG` と実行の V2)。`src/qrpglesrc/v0601s.rpgle` は、その `CVTRPGSRC` の出力をそのまま写したものです。
  - `TXLEGACY`(RPG III 版、`FORCE` なしの初回ロード): 05-01 の実機メモ(`part05-txlegacy-exec`、確認日2026-09-27、V2)。
  - `<USER>2` への `TXSETUP`・`TXLEGACY` と `LASTCD`: 05-12 の実機メモ。
  - チケット1の食い違いと `solutions/05-13/ju0900c-ticket1.clp` による解消: `part05-ju0900c-baseline`・`part05-13-tickets`(確認日2026-09-27、RPG III 版の `ZA0500` に対して V2)。
- **未検証(2026-10-01時点)**:
  - `TXLEGACY` の `LANG` パラメーター(`*RPGLE`・`*SAME`・`*RPG`)と `TXLEGLNG` の動き。`QRPGLE112` に作る `TK0100`・`JU0300`・`ZA0500` が `CRTBNDRPG` でコンパイルできること、`src/legacy/qrpgle112/` のソースの内容。
  - `CRTBNDRPG` で作った固定形式 RPG IV のプログラムが、`OBJECT_STATISTICS` の `OBJATTRIBUTE` で `RPGLE` を返すこと(列名と、埋め込み SQL のプログラムでの値は 10-03 で確認済み)。
  - A6 の `TXCKM` の10行(`*FILE`・`*DTAARA` を含む)を `TXCHECK` が処理して `10 passed, 0 failed` を返すこと(05-13 の確認は `*PGM` の行です)。
  - RPG IV 版の `ZA0500` が、食い違った `PARM` で受けたときに出すメッセージ ID(RPG III 版の `RPG0907` とは限りません)。
  - A3 で、`QRPGLE112` がすでにある場合に出るメッセージ ID(`CPF5813` かどうか)。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
