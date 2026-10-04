# 04-28 影響調査(固定形式 RPG IV の旧システムを相手に)

> 所要時間: 60分 / 前提レッスン: [04-27](04-27-route-preparation.md)(ルートの 04-21〜04-27。A4 で旧システムを `LANG(*RPGLE)` で `<USER>1` に入れてあること。04-21 の `V0421D` と 04-23 の `V0423D` を作ってあると、調査結果が増えて読み比べやすくなります)/ 目標番号: 4 / 観測方法: SQL の結果(`QTEMP` の出力ファイル)と `FNDSTRPDM` の一覧 / 道具: ACS「実行 SQL スクリプト」(`CL:` 行)・5250 / 同時接続数: ACS×1 と 5250×1(`FNDSTRPDM` のとき)/ 作る・変えるオブジェクト: なし(`QTEMP` の一時ファイルのみ)/ DBVER: 1 / 依存するプローブ: `part04v-28imp`(実施済み 2026-10-04。再実行で、`JU0300`・`ZA0500`・`TK0100` を `CRTBNDRPG` で作り直した状態まで確認)/ PTF 依存: なし / 容量の目安: わずか

**このレッスンは、第5部を通ってきた人は行いません。** 第5部の [05-07](../part05/05-07-impact-analysis.md) の核を、固定形式 RPG IV の旧システム(`QRPGLE112` のソースを `CRTBNDRPG` でコンパイルしたもの)を相手に書き直したものです。05-07 を終えた人は、次へ進んでください。08-06・08-07・10-02 が、このレッスンを前提にしています。

> **このレッスンは、改修の前の状態を調べます。** 調べたあとで、旧システムを変えることはありません(`JU0300` を直すのは 10-02 です)。

## ゴール

- `04-28-1`: `DSPPGMREF` と `DSPDBR` の `*OUTFILE` を、**同じジョブの中で** SQL で読み、あるファイルを参照しているプログラムを一覧できる(別のジョブから `QTEMP` が見えない理由を説明できる)。
- `04-28-2`: 直接参照と、論理ファイル経由の間接参照の両方を辿り、「影響を受けるオブジェクトと、ソースの行」を表にまとめられる。
- `04-28-3`: `FNDSTRPDM` またはソースの `grep` で、コマンドでは見つからない依存を補い、ヒットが本物の依存か、コメント中の言及かを1行ずつ判定できる。

## ウォームアップ

<details><summary>04-27 の復習</summary>

1. 旧システムが固定形式 RPG IV で入っていることは、`TXLEGLNG` の値と `OBJECT_STATISTICS` のどの列で確かめますか? それぞれ、どんな値が出るはずですか?
2. 旧システムの RPG IV のソースは、`QRPGSRC` と `QRPGLE112` のどちらに入っていますか?
3. 04-27 の手順 C で、`<USER>2` に何を用意しましたか?

答え: 1. `TXLEGLNG` は `*RPGLE`。`OBJECT_STATISTICS` の `OBJATTRIBUTE` は `RPGLE`(RPG III は `RPG`)。 2. `QRPGLE112`(`RCDLEN(112)` のソース物理ファイル)。 3. 本番役のライブラリー `<USER>2` に、旧システム(`LANG(*RPGLE)`)とサンプル・データベースを用意した(`LASTCD` を含む)。

</details>

## なぜ学ぶか

**保守で一番危ないのは、「直しても大丈夫だと思っていたら、実は別のプログラムがそのファイルを使っていた」という事故です。** `JUCHUM`(受注ヘッダー)を例にすると、これを直接開くプログラムだけでなく、`JUCHUM` の上に作られた論理ファイル `JUCHUL1` を開くプログラム、`DCLF` で読む CL プログラムまで、**影響の範囲は1種類の調べ方だけでは見えません。** このレッスンでは、`DSPPGMREF`・`DSPDBR`・ソースの文字列検索という3つの調べ方を組み合わせ、それぞれの得意・不得意を体験します。ここで身につける手順は、08-06(ファイルの形を変えるときの確認)、08-07(権限・システム・ビューの調査)、10-02(`TOKUIM` に項目を足す保守)の出発点です。

職場のシステムが固定形式 RPG IV であっても、考え方は05-07と同じです。**変わるのは、調べる対象の見え方です。** ソースは `QRPGSRC` ではなく `QRPGLE112`(と、自分で書いた `QRPGLESRC`)にあります。プログラムは OPM の RPG III ではなく ILE のプログラムです。そこで、`DSPPGMREF` の結果に ILE 固有の違いが出るかを、実機で確かめた分(`part04v-28imp`、2026-10-04)と、まだ確かめていない分を分けて読み進めます。

## 新出

### 中核(3つ)

- **`DSPPGMREF` の `OUTPUT(*OUTFILE)` を SQL で読む**: プログラムがどのファイル・データ域を参照しているかの一覧を `QTEMP` に落として、SQL で絞り込む。**`DSPPGMREF` を実行したジョブと `SELECT` を実行するジョブは、同じでなければなりません**(`QTEMP` はジョブ・スコープの作業ライブラリーで、別のジョブからは中身が見えないため)。
- **`DSPDBR`**: あるファイルの上に作られている論理ファイルを一覧する。物理ファイルを直接開くプログラムだけでなく、論理ファイル経由で間接的に開くプログラムまで追う出発点になる。
- **ソースの文字列検索**: `DSPPGMREF` はコンパイル済みのプログラムに焼き込まれた参照しか見えない。実行時に組み立てるコマンド・パラメーターの文字列や、CL の `OVRDBF` のような書き方は、ソースを検索しなければ見つからない。

### コマンド等(6つまで)

- `DSPPGMREF PGM(<USER>1/*ALL) OUTPUT(*OUTFILE) OUTFILE(QTEMP/PGMREF)`
- `DSPDBR FILE(<USER>1/JUCHUM) OUTPUT(*OUTFILE) OUTFILE(QTEMP/DBRJUCHUM)`
- `FNDSTRPDM FILE(<USER>1/QRPGLE112) MBR(*ALL) STRING('JUCHUM')`
- ACS の「実行 SQL スクリプト」の **`CL:` 行**(行頭に `CL:` を付けると、その行を CL コマンドとして実行します。次の SQL と同じ接続で実行されます)。
- `DSPFD FILE(<USER>1/JUCHU*) TYPE(*RCDFMT)`(様式レベル ID を見る。08-06 で使います)。

### 読解用

- `QTEMP`(ジョブ終了で自動的に消える、ジョブ専用の作業ライブラリー。03-10 の `EXPSRC` で既に使いました)。
- コンパイル・リストの Cross-Reference Table(相互参照表)。ファイル・項目・標識が、ソースのどの行で使われているかの一覧です(04-21 の「コンパイル・リストの読み方」)。

## 説明

### この旧システムで、何を探すのか

`JUCHUM` を変えるとき、探す相手は次の5種類です。05-07 と同じ旧システムですが、RPG の2本は固定形式 RPG IV に変わっています。F 仕様書は、ソース(`src/legacy/qrpgle112/`)の行そのままです。

| 相手 | 開き方 | ソースの行 |
|---|---|---|
| `JU0900C`(CL) | `DCLF` | `DCLF       FILE(JUCHUM)` |
| `ZA0500`(RPG IV) | プログラム記述(22桁目が `E` ではなく `F`) | `FJUCHUM    IS   F   26        DISK` と、I 仕様書の `IJUCHUM    AA  02` |
| `JU0300`(RPG IV) | 外部記述だが、開くのは論理ファイル | `FJUCHUL1   IP   E           K DISK`(`JUCHUM` という名前はコードに出ない) |
| `JUCINQC`(CL、03-09 で作成) | `DCLF` | `DCLF       FILE(JUCHUM)` |
| `V0421D`・`V0601A`(RPG IV、04-21・04-27 A3 で作成) | 外部記述 | `FJUCHUM    IF   E             DISK` |

**`JU0300` が、このレッスンの要です。** `JUCHUM` を直接開いていないので、`JUCHUM` という名前だけで探すと見落とします。`JUCHUL1`(`db/v1/juchul1.lf`、`PFILE(JUCHUM)`)を経由しているためです。

### なぜ「同じジョブ」でなければならないのか

`DSPPGMREF ... OUTFILE(QTEMP/PGMREF)` の結果は、`QTEMP` に書かれます。`QTEMP` は**ジョブごとに独立し、そのジョブが終わると消える**ライブラリーです。5250 のコマンド行で `DSPPGMREF` を実行し、ACS の「実行 SQL スクリプト」など**別の接続**から `SELECT * FROM QTEMP.PGMREF` をしても、その `QTEMP` は別のジョブのものなので、何も見えません。`DSPPGMREF` の実行と `SELECT` は、**必ず同じ接続の中で**行います。

そこで、この教材では ACS の「実行 SQL スクリプト」に `CL:` 行と SQL を並べて、1つのスクリプトとして実行します。

- **未検証(2026-10-04時点)**: `CL:` 行は ACS の機能で、08-06 と10-02 の本文も使っていますが、著者はこの `QTEMP` と ACS の組み合わせを実機でまだ実行していません。うまく動かないときは、5250 のコマンド行で `DSPPGMREF` を実行し、**同じ 5250 セッションから** `STRSQL` や `RUNSQL` で読む手もあります(どちらも同じジョブになるはずです。こちらも未検証です)。
- **実機で確認(part04v-28imp、2026-10-04)**: 1本の CL ラッパー・ジョブの中で、`DSPPGMREF PGM(ライブラリー/*ALL) OUTPUT(*OUTFILE) OUTFILE(QTEMP/PGMREF)` を実行し(`CPF3030`: 1678 件追加。再実行の値です)、続けて同じジョブの `RUNSQL` と `CPYF` で `QTEMP` の出力ファイルを読めました。`DSPDBR`(1 件)と `DSPFD`(3 件)も同じです。
- **実機で確認(part04v-28imp、2026-10-04)**: 同じ検証の最後に、**別のジョブ**から `SELECT COUNT(*) FROM QTEMP.PGMREF` を実行すると、`SQLSTATE 42704`(`PGMREF in QTEMP type *FILE not found`)で失敗しました。`QTEMP` がジョブ・スコープで、別のジョブからは見えないことの実測です。

### `DSPPGMREF` の `*OUTFILE`: 確認できていること

05-12 の検証(`part05-12-libref-probe`、確認日 2026-09-29。OPM の RPG III プログラム `TK0100` に対するもの)で確認したことです。

- 列は `WHLIB`(プログラムのライブラリー)・`WHPNAM`(プログラム名)・`WHFNAM`(参照先のファイル名)・`WHLNAM`(参照先のライブラリー名)・`WHOBJT` など。このレッスンの問い合わせは、この5列だけを使います。`WHOBJT` は参照先の種類を表す1文字で、ILE の検証(下の「ILE のプログラムでの確認」)では、ファイルが `F`、呼び出すプログラムが `P` でした。
- データ域 `LASTCD` も、`*DTAARA` として行に出ました。参照先のライブラリーは `*LIBL` です。
- 参照先のライブラリー名は、コンパイル時の名前のままです。複製したライブラリーのプログラムでも変わりませんでした。**「ライブラリー名が出た」ことを、実行時の依存と読んではいけません。**
- 10-02 の検証(`part10-02-tokuim`、確認日 2026-09-30)では、`PGM(<USER>2/*ALL)` に `OBJTYPE` を付けない実行は、サービス・プログラム(`*SRVPGM`)を含みませんでした。サービス・プログラムは `OBJTYPE(*SRVPGM)` を付けて別に実行します。

### ILE のプログラムでの確認

**実機で確認(part04v-28imp、2026-10-04)**: ILE のプログラム(04-21・04-27 で作った `V0421D`・`V0601A` など。この検証では `OBJATTRIBUTE` を確かめていません)と CL プログラムが入ったライブラリーで `DSPPGMREF PGM(ライブラリー/*ALL)` を実行した結果です。

1. 列は OPM のときと同じ名前で出ます。全体は `WHLIB`・`WHPNAM`・`WHTEXT`・`WHFNUM`・`WHDTTM`・`WHFNAM`・`WHLNAM`・`WHSNAM`・`WHRFNO`・`WHFUSG`・`WHRFNM`・`WHRFSN`・`WHRFFN`・`WHOBJT`・`WHOTYP`・`WHSYSN`・`WHSPKG`・`WHRFNB` の18列です。**`WHFNAM` と `WHLNAM` で絞る問い合わせは、そのまま使えます。** それでも、**先に `SELECT * FROM QTEMP.PGMREF FETCH FIRST 1 ROW ONLY` で実物を見る**習慣は続けます(05-07 と同じです)。
2. プログラムの種類やモジュールを持つ列は、見当たりません。`WHOTYP` は参照先のオブジェクトの種別で、`*FILE`・`*PGM`・`*DTAARA`・`*SRVPGM` の4種が出ました(`WHOBJT` は順に `F`・`P`・`D`・空白です。ILE のプログラムには、`QRNXIE`・`QRNXIO`・`QRNXUTIL`・`QLEAWI` の `*SRVPGM` の行が付きます。`OBJTYPE` なしの実行でも出ました)。`V0421D`・`V0601A`・`F0604A` などの ILE のプログラムは、CL と同じ形の行で、`WHFNAM = 'JUCHUM'`・`WHOBJT = 'F'` として出ました。
3. 1つのプログラムの同じファイルが、**複数行**で出ることがあります(`JU0900C` は、`JUCHUM` と `JUCHUD` がそれぞれ3行)。問い合わせは `SELECT DISTINCT` にします。
4. ライブラリー全体(`/*ALL`)の結果は、この検証用ライブラリーで 1678 行でした(`JU0300`・`ZA0500`・`TK0100` を作り直した後)。`JUCHUM` を参照する行は 35 行(29 本のプログラム。`ZA0500` を含みます)です(他の検証で作ったプログラムが多く入っているためです)。

**実機で確認(part04v-28imp、2026-10-04)**: 検証の再実行で、`JU0300`・`ZA0500`・`TK0100` を `QRPGLE112` から `CRTBNDRPG` で作り直し(`OBJATTRIBUTE` は `RPG` から `RPGLE` に変わりました)、そのうえで `DSPPGMREF PGM(ライブラリー/*ALL)` を実行しました(1678 行。初回の 1648 行より 30 行増えています。3本を作り直したことによる増加と考えられますが、増えた行の内訳は見ていません)。

- **`ZA0500` のプログラム記述ファイル(`FJUCHUM    IS   F   26        DISK`)は、`DSPPGMREF` の行に出ます。** `JUCHUM` と `JUCHUD`(こちらも同じ形のプログラム記述)が、それぞれ `WHOBJT = 'F'`・`WHOTYP = '*FILE'`・`WHFUSG = 1`・`WHLNAM = '*LIBL'` の1行です。**ただし、外部記述のファイルとは違い、様式名の `WHRFNM` と様式レベル ID の `WHRFSN` は空で、`WHRFFN` は 0 です。** 同じ `ZA0500` の `ZAIKOM`(`E` の外部記述)は、`WHRFNM = 'ZAIKOR'`・`WHRFSN = '2FF50CA837102'`・`WHRFFN = 3` が入り、`WHLNAM` もライブラリー名(コンパイル時の名前)で出ます。よって、`JUCHUM` の行の `WHRFSN` が空なら、**プログラム記述ファイルと見分けられます**(様式レベル ID を持たないので、照合の対象外です。理由は、下の「様式レベル ID は、何を決めるのか」です)。
- **`JU0300` は `JUCHUL1` で出て、`JUCHUM` では出ません。** `WHFNAM = 'JUCHUL1'` の行(`WHRFNM = 'JUCHUR'`・`WHRFSN = '2D46394749174'`・`WHFUSG = 1`)と、`*LDA`(`WHOTYP = '*DTAARA'`)・`QSYSPRT` の行が、`JU0300` のファイル・データ域の参照のすべてです(ほかに、ILE のプログラムに共通の `*SRVPGM` の行が4つ付きます)。この `WHRFSN` は、`JUCHUM`・`JUCHUL1` の `RFID`(下の `DSPFD` の表)と同じ値です。このため、ファイルを変えたあとに、`PGMREF` の `WHRFSN` と `DSPFD` の `RFID` を比べれば、食い違うプログラムを SQL で探せると考えられます(この比較そのものは、実行していません)。
- `TK0100` は `TOKUIM`・`TANTOM`・`TK0100D`(表示ファイル、様式6つ)・`LASTCD`(`*DTAARA`)で出て、`JUCHUM` は出ません。

### `DSPDBR`: 確認できていること

`DSPDBR FILE(.../JUCHUM) OUTPUT(*OUTFILE)` の列は、05-07 の実機メモ(`part05-legacy-probe`、確認日 2026-09-26)と10-02 の検証(`part10-02-tokuim`)で実測済みです。`WHFILE`/`WHLIB` という列は**ありません。**

| 列 | 入る値 |
|---|---|
| `WHRFI`・`WHRLI` | `DSPDBR` の対象そのもの(ここでは `JUCHUM` と、そのライブラリー)。全行に繰り返し出る |
| `WHREFI`・`WHRELI` | 従属するファイル(ここでは論理ファイル `JUCHUL1`)とそのライブラリー |
| `WHTYPE` | 従属側の種別。`D` |

`DSPDBR` は、プログラムの言語とは関係のないファイル・システム側の情報なので、旧システムが RPG IV になっても同じです。**実機で確認(part04v-28imp、2026-10-04)**: ILE のプログラムが入ったライブラリーで `DSPDBR FILE(ライブラリー/JUCHUM) OUTPUT(*OUTFILE)` を実行すると、1行(`WHRTYP` は `P`、`WHRFI` は `JUCHUM`、`WHREFI` は `JUCHUL1`、`WHTYPE` は `D`、`WHRMB` は `*NONE`)でした。**再実行で、`JU0300`・`ZA0500`・`TK0100` を ILE にした状態でも、同じ1行でした**(`DSPDBR` はプログラムを見ないので、変わりません)。

### 間接参照を辿る

1. `DSPPGMREF` の結果から、`WHFNAM = 'JUCHUM'` の行を探す(直接参照)。
2. `DSPDBR` の結果から、`JUCHUM` の上の論理ファイルを探す(`JUCHUL1` が出るはずです)。
3. **見つかった論理ファイル1件ごとに、1の問い合わせをその名前でもう一度実行する**(`WHFNAM = 'JUCHUL1'`)。`JU0300` は、ここで初めて出ます。

DDS の論理ファイルは物理ファイルの上に作るので、この旧システムでは、2段(直接と論理ファイル経由)で完了です。

### `DCLF` は `DSPPGMREF` に見えるか

`DCLF FILE(JUCHUM)` を持つ CL は、コンパイルするとき様式レベル ID を一緒に焼き込みます。**実機で確認(part04v-28imp、2026-10-04)**: `DSPPGMREF` に見えます。`JUCINQC`(`DCLF FILE(JUCHUM)` だけの CL)も `JU0900C` も、`WHFNAM = 'JUCHUM'`・`WHOBJT = 'F'` の行で出ました。それでも、**ソースの検索は必ず行います**(`OVRDBF` や `QCMDEXC` の文字列は、プログラムに焼き込まれません)。実演の手順7で、自分の環境でも確かめます。

### ソースの検索

`DSPPGMREF` は、プログラムに焼き込まれた参照だけを見ます。次のものは、ソースを検索しなければ見つかりません。

- `OPNQRYF` の `FILE()`、`OVRDBF` の `TOFILE()`、`CPYTOIMPF` の `FROMFILE()` に書かれたファイル名(実行時に決まる)。
- `QCMDEXC` で組み立てるコマンド文字列。

**この旧システムの RPG のソースは `QRPGLE112` にあります。** 05-07 が検索していた `QRPGSRC` は、ルートでは使いません。検索先は次のとおりです。

| ソース物理ファイル | 入っているもの |
|---|---|
| `QRPGLE112` | 旧システムの RPG IV(`TK0100`・`JU0300`・`ZA0500`)と、04-27 の A3 で作った `V0601A` |
| `QRPGLESRC` | 04-21〜04-26 で自分が書いたもの(`V0421D` など) |
| `QCLSRC` | `JU0900C`・`MN0000C`・自分で作った CL(`JUCINQC`) |
| `QDDSSRC` | DDS(物理ファイル・論理ファイル・画面) |

`FNDSTRPDM` の確認できていること(`part05-12-fndstrpdm`、確認日 2026-09-29。検索先は `QRPGSRC` でした)は次のとおりです。

- **非対話のジョブで画面を出さずに動いた形**: `FNDSTRPDM FILE(<USER>1/QRPGSRC) MBR(*ALL) STRING('文字列') OPTION(*NONE) PRTMBRLIST(*YES) PRTRCDS(*ALL)`。`OPTION(*NONE)` だけだと `PDM0572`、`OPTION(*PRINT)` は `PDM0571`(無効な値)で失敗しました。
- 大文字・小文字は、既定(`CASE(*IGNORE)`)では区別されません。`CASE(*MATCH)` にすると、小文字の文字列は0件でした。
- 印字結果のスプール・ファイル名は `QSYSPRT` ではなく、`CPYSPLF FILE(QSYSPRT)` は `CPF3303` で失敗しました(印字名は未確認)。**よって、検索結果の一覧は 5250 の画面(または `WRKSPLF`)で自分の目で読みます。**
- 代わりに、qsh の `grep` でも検索できました(`qsh` または SSH で実行)。`grep -il` は該当するメンバー名を、`grep -in` は行番号つきの行を返します。

```sh
grep -in 'juchum' /QSYS.LIB/<USER>1.LIB/QRPGLE112.FILE/*.MBR
```

**実機で確認(part04v-28imp、2026-10-04)**: 検索先が `QRPGLE112`(`RCDLEN(112)`)・`QCLSRC` のとき、`FNDSTRPDM FILE(ライブラリー/QRPGLE112) MBR(*ALL) STRING('JUCHUM') OPTION(*NONE) PRTMBRLIST(*YES) PRTRCDS(*ALL)` は、`QRPGSRC` のときと同じように画面を出さずに終わりました(`PDM0594`「29 records are printed」・`PDM0574`「The list is printed」・`PDM0575`「7 members match the Find string」)。`QCLSRC` は `PDM0594` が 213 行・`PDM0575` が 29 メンバーでした。`qsh` の `grep -in`・`grep -il` も、`QRPGLE112`・`QCLSRC` に対して動きました。印字された一覧は、検証の出力の中で読めました(メンバーごとに、ヘッダー、ヒットした行の行番号つきの内容、`Number of records found` が並びます。ヒットした文字列の位置には、行の上に印が付きます)。5250 の画面や `WRKSPLF` での見え方は、未検証(2026-10-04時点)です。行番号は `grep` の結果とも突き合わせました。

`QRPGLE112` で `JUCHUM` を検索した結果(`grep` による行番号)は、次のとおりです。

| メンバー | ヒット | 内容 |
|---|---|---|
| `ZA0500` | 7件(7・9・42・45・50・62・71行) | 5件はヘッダー・コメント(`*` が7桁目)、62行が `FJUCHUM    IS   F   26        DISK`、71行が `IJUCHUM    AA  02` |
| `JU0300` | 2件(6・58行) | **2件ともコメント**(`JUCHUM/JUCHUL1` の言及)。F 仕様書は `FJUCHUL1` なので、コードには `JUCHUM` が出ません |
| `V0601A` | 2件(4・10行) | 4行が `FJUCHUM    IF   E             DISK`、10行が `C                   READ      JUCHUM` |

`QCLSRC` では、`JUCINQC` が2件(1行目のコメントと、6行目の `DCLF       FILE(JUCHUM)`)、`JU0900C` が8件(7・10・47行のコメント、33行の `DCLF`、53行の `OVRDBF     FILE(JUCHUM) TOFILE(...)`、56・59行のメッセージ文、106行の `DLTOVR`)でした。**8件のうち、コードの依存はコマンドの3行(`DCLF`・`OVRDBF`・`DLTOVR`)で、残りはコメントとメッセージ文の言及です。** 検索先ライブラリーには、他の検証で作った `LGZA0500`・`LLJU0300` のような複製メンバーも入っていて、同じ行がそれぞれにもヒットします。

### ヒットは依存ではない: コメントの言及

この旧システムのソースには、コメント中に `JUCHUM` と書いてある行があります。たとえば `ju0300.rpgle` のヘッダー・コメントに `(JUCHUM/JUCHUL1)` と書いてあります。`JU0300` が実際に開くのは `JUCHUL1` だけです。**ヒットした行は1行ずつ読み、コード(F 仕様書・I 仕様書・CL のコマンド)なのか、コメント(固定形式 RPG IV では `*` が7桁目)なのかを判定します。** ヒット=依存、と機械的に判断しません。

逆に、**ヒットが無い=依存が無い、でもありません**。`JU0300` のコードには `JUCHUM` が出ないのに、`JUCHUM` の変更の影響を受けます(論理ファイル経由)。

### 相互参照表: 1本のプログラムの中を見る

`DSPPGMREF` はファイル単位の一覧と考えてください(ILE のプログラムの出力 18 列に、項目名と分かる列は見当たりません。`WHRFNM`・`WHRFSN`・`WHRFFN` は、様式名・様式レベル ID・数でした。実機で確認、part04v-28imp、2026-10-04。`JUCHUR` は 4、`ZAIKOR` は 3 で、プログラム記述のファイルでは空白と 0 です。この数が何の数かは、確認していません)。たとえば `JUCHUM` に項目を足すとき、プログラム記述の `ZA0500` は、**I 仕様書の桁位置を手で直す**必要があります。

```text
     IJUCHUM    AA  02
     I                                  1    6  JUNO            M1
     I                                  7   12  JUTOK
     I                                 13   20 0JUDATE
     I                                 21   26  JUTAN
```

1本のプログラムを細かく見るには、`CRTBNDRPG` のコンパイル・リストを読みます。Cross-Reference Table の節に、ファイル・項目・標識が、どの行で使われているかが載ります。**実機で確認(part04v-28imp、2026-10-04)**: `CRTBNDRPG` を既定のオプションで実行したコンパイル・リストに、`*XREF` が入っていて、`Cross Reference` の節に `File and Record References`・`Global Field References`・`Indicator References` が、それぞれ行番号つきで載りました(`JU0300` では、`JUCHUL1` が 138 行で定義、143 行で参照、など)。リストに出ていないときに `OPTION(*XREF)` を付ける手順は、未検証(2026-10-04時点)です。

### 様式レベル ID は、何を決めるのか

`DSPPGMREF` と `DSPDBR` は、**だれが関係しているか**を教えます。**変更したとき実際に止まるのはだれか**を決めるのは、様式レベル ID です(04-23 の「落とし穴 2」)。

- 外部記述のファイル(`JU0300`・`V0421D` など)は、コンパイルしたときの様式レベル ID を覚えていて、実行時にファイルの今の ID と比べます。ずれると `CPF4131`(Level check)です。
- プログラム記述のファイル(`ZA0500` の `JUCHUM` と `JUCHUD`)は、**この照合の対象外**です(05-09 の話で、ILE RPG の一次資料にも同じ記述があります。**ILE の `ZA0500` では、`PGMREF` の `JUCHUM` の行に様式レベル ID が無いことまでを、実機で確認しました(part04v-28imp、2026-10-04)。ずれたファイルを実際に開いて動かす確認は、未検証(2026-10-04時点)です**)。ずれたまま、**エラーにならず別の位置のデータを読みます**。影響調査で見つけて、手で直します。
- ID の見方は、`DSPFD FILE(<USER>1/JUCHU*) TYPE(*RCDFMT)` です([08-06](../part08/08-06-dds-to-sql-ddl.md) が、`DSPFD` で ID を比べます)。
- 10-02 の検証(`part10-02-tokuim`、確認日 2026-09-30)では、`TOKUIM` に `CHGPF` で項目を足したとき、**論理ファイル `TOKUIL1` も、作り直す前に、物理ファイルと同じ新しい ID になっていました。** 物理ファイルを変えると、その上の論理ファイルを開くプログラムも、止まる側に入ります。同じ検証で、`DSPPGMREF` の一覧に出る再コンパイルしていないプログラムが、実際に `CPF4131` を出すかどうかは、観測していません。**一覧に出ること=止まること、ではありません。**

**実機で確認(part04v-28imp、2026-10-04)**: `DSPFD FILE(ライブラリー/JUCHU*) TYPE(*RCDFMT) OUTPUT(*OUTFILE) OUTFILE(QTEMP/FDJUCHU)` の出力ファイルは、様式ごとに1行(3件)で、ID を読む列は `RFID` です。そのほか `RFFILE`(ファイル名)・`RFLIB`・`RFNAME`(様式名)・`RFFLDN`(項目数)・`RFLEN`(レコード長)・`RFFTYP`(`P` か `L`)などがあります。`DBVER` 1 のサンプルでは、次の値でした。

| `RFFILE` | `RFNAME` | `RFFLDN` | `RFLEN` | `RFID` |
|---|---|---|---|---|
| `JUCHUM` | `JUCHUR` | 4 | 26 | `2D46394749174` |
| `JUCHUL1` | `JUCHUR` | 4 | 26 | `2D46394749174` |
| `JUCHUD` | `JUCHDR` | 5 | 27 | `3B05FA0363592` |

**`JUCHUL1` の ID は `JUCHUM` と同じです**(項目リストの無い論理ファイルは、物理ファイルの様式を共有するため)。だから `JUCHUM` を変えると、`JUCHUL1` を開く `JU0300` も止まる側に入ります。

### この教材のルートでの `JUDLV` の扱い

**08-06 の本文は、`JUDLV` を日付型(DDS の `L` 型)の例として名前を挙げています。**`JUDLV` は、05-09 が `JUCHUM` に足す「納期」の項目です(`db/v2/juchum.pf`)。このルートは 05-09 を通らず、`DBVER` は 1 のままなので、**`JUCHUM` には `JUDLV` がありません**(`db/v1/juchum.pf` の項目は、`JUNO`・`JUTOK`・`JUDATE`・`JUTAN` の4つで、`JUDATE` は `8S 0`、つまり YYYYMMDD の数字です)。

08-06 は、`JUDLV` を使う手順を実行しません(`SHOHIM` を例に、日付型の説明の1行で触れるだけです)。ルートの読者は、その1行を「DDS にも日付型があるという一般の話」として読み流してかまいません。このレッスンの演習も、`JUDLV` を必要としません。

## 実演

**04-27 の A4 で、旧システムを `<USER>1` に `LANG(*RPGLE)` で入れてあることを前提にします。** 次のコマンドは、`<USER>1` を対象にしています(`<USER>2` も同じ手順です。あとで繰り返します)。

1. **(ACS) 旧システムが RPG IV であることを確かめます。** 04-27 の A5 と同じ問い合わせです。

   ```sql
   SELECT OBJNAME, OBJTYPE, OBJATTRIBUTE
     FROM TABLE(QSYS2.OBJECT_STATISTICS('<USER>1', '*PGM')) X
    WHERE OBJNAME IN ('TK0100', 'JU0300', 'ZA0500')
    ORDER BY OBJNAME;
   ```

   3行すべて `OBJATTRIBUTE` が `RPGLE` のはずです(実機で確認、part04v-28imp、2026-10-04。`CRTBNDRPG` で作り直した直後に3本とも `RPGLE`、作り直す前と `CRTRPGPGM` で戻した後は `RPG` でした)。

2. **(ACS)「実行 SQL スクリプト」で、次を1つのスクリプトとして実行します。**

   ```text
   CL: DSPPGMREF PGM(<USER>1/*ALL) OUTPUT(*OUTFILE) OUTFILE(QTEMP/PGMREF)
   CL: DSPDBR FILE(<USER>1/JUCHUM) OUTPUT(*OUTFILE) OUTFILE(QTEMP/DBRJUCHUM)
   ```

3. **まず列名を確かめます。**

   ```sql
   SELECT * FROM QTEMP.PGMREF FETCH FIRST 1 ROW ONLY;
   SELECT * FROM QTEMP.DBRJUCHUM FETCH FIRST 1 ROW ONLY;
   ```

   `PGMREF` に `WHPNAM`・`WHFNAM`・`WHLNAM`・`WHOBJT` があるか(あれば、以降の問い合わせをそのまま使えます。実機では、ILE のプログラムが入ったライブラリーでも、ありました。part04v-28imp、2026-10-04)。`DBRJUCHUM` に `WHRFI`・`WHREFI`・`WHTYPE` があるか。違っていたら、以降の問い合わせをその場で直します。

4. **`JUCHUM` を直接参照しているプログラムを見ます。**

   ```sql
   SELECT DISTINCT WHPNAM, WHFNAM, WHLNAM, WHOBJT
     FROM QTEMP.PGMREF
    WHERE WHFNAM = 'JUCHUM'
    ORDER BY WHPNAM;
   ```

   `JU0900C`・`ZA0500` が出るはずです(`JUCINQC`・`V0421D`・`V0601A` は、作ってあれば出ます)。実機では、`JU0900C`・`JUCINQC`・`V0421D`・`V0601A` と `ZA0500`(プログラム記述のファイル)が `WHOBJT = 'F'` で出ました(part04v-28imp、2026-10-04)。**`JU0300` は出ないはずです**(実機でも出ませんでした)。`ZA0500` が出なければ、プログラム記述のファイルが `DSPPGMREF` に出ない環境です(実機では出ました)。メモしておき、手順8のソース検索で拾います。

5. **`JUCHUM` の上の論理ファイルを見ます。**

   ```sql
   SELECT WHRFI, WHREFI, WHTYPE
     FROM QTEMP.DBRJUCHUM;
   ```

   `JUCHUL1` が1行、`WHTYPE` は `D` のはずです(05-07 と同じ。この列名は実測済みです)。

6. **見つかった論理ファイルごとに、手順4と同じ問い合わせをもう一度行います。**

   ```sql
   SELECT DISTINCT WHPNAM, WHFNAM, WHLNAM, WHOBJT
     FROM QTEMP.PGMREF
    WHERE WHFNAM = 'JUCHUL1'
    ORDER BY WHPNAM;
   ```

   `JU0300` が出るはずです(実機で確認、part04v-28imp、2026-10-04。`JU0300` は `JUCHUL1` の行で出て、`JUCHUM` の行には出ませんでした)。**直接参照だけを調べると、`JU0300` を見落とします。**

7. **`DCLF` が見えるかを確かめます。** 手順4の結果に、`JU0900C` に並んで `JUCINQC`(`DCLF FILE(JUCHUM)` と `RCVF` しかない CL)が出ているかを見ます。出ていれば「`DCLF` は見える」、出ていなければ「`DCLF` は死角」と確定します(実機では「見える」でした。part04v-28imp、2026-10-04)。**どちらの結果でも、次の手順8は行います。**

8. **(5250 または SSH) ソースの文字列を検索します。** 5250 のコマンド行で、次の3本を順に実行します。一覧が出たら、ヒットした行を1行ずつ読みます(画面の出方は、この教材では確認していません。V3、未検証(2026-10-04時点)。非対話のジョブでは、画面を出さずに終わりました)。

   ```text
   FNDSTRPDM FILE(<USER>1/QRPGLE112) MBR(*ALL) STRING('JUCHUM')
   FNDSTRPDM FILE(<USER>1/QCLSRC) MBR(*ALL) STRING('JUCHUM')
   FNDSTRPDM FILE(<USER>1/QRPGLESRC) MBR(*ALL) STRING('JUCHUM')
   ```

   画面が出てしまうと困るときは、SSH で `qsh` に入り、次の形で行付きの結果を読みます(検索先を `QRPGLE112` に替えても、動きました。part04v-28imp、2026-10-04)。

   ```sh
   grep -in 'juchum' /QSYS.LIB/<USER>1.LIB/QRPGLE112.FILE/*.MBR
   grep -in 'juchum' /QSYS.LIB/<USER>1.LIB/QCLSRC.FILE/*.MBR
   ```

   確かめること:
   - `ZA0500` の F 仕様書・I 仕様書の行(**コードの依存**)。
   - `JU0900C`・`JUCINQC` の `DCLF` 行(コードの依存)。
   - `JU0300` のヘッダー・コメントの `JUCHUM`(**コメントの言及**。依存ではありません)。
   - 小文字の検索文字列を使うと、`CASE(*IGNORE)` が既定なので、大文字のソースにも当たります。

9. **ここまでの結果を、影響調査表にまとめます。** 行を埋めるのに使ったソースの行は、メモしておきます(行番号は、自分の `QRPGLE112` のメンバーを `SEU` や Code for i で開いて見ます。配布のファイルは、`src/legacy/qrpgle112/` にあります)。

   | オブジェクト | 種類 | 参照の仕方 | 止まるか(様式レベル ID) |
   |---|---|---|---|
   | `JU0900C` | CL | `DCLF FILE(JUCHUM)` | 止まる(外部記述の `DCLF`) |
   | `JUCINQC` | CL | `DCLF FILE(JUCHUM)` | 止まる |
   | `ZA0500` | RPG IV | プログラム記述 `FJUCHUM`・I 仕様書 | **止まらない。手で直す** |
   | `JUCHUL1` | LF | `PFILE(JUCHUM)` | 作り直す(物理ファイルの変更で ID が変わる) |
   | `JU0300` | RPG IV | 外部記述 `FJUCHUL1`(`JUCHUL1` 経由) | 止まる |
   | `V0421D`・`V0601A` | RPG IV | 外部記述 `FJUCHUM` | 止まる |

   この表の「止まるか」の列は、様式レベル ID の仕組みからの**予想**です(ILE では未検証(2026-10-04時点)。`JUCHUL1` が `JUCHUM` と同じ ID であることは、実機で確認しました)。この表が、`JUCHUM` を変えるときの「再作成・再コンパイル・手で直す」の対象そのものです。

10. **`<USER>2` でも繰り返します。** 本番役のライブラリー `<USER>2` にも旧システムがあります(04-27 の C)。`DSPPGMREF PGM(<USER>2/*ALL)` を実行して、同じ問い合わせをもう一度します。**`DSPPGMREF PGM(あるライブラリー/*ALL)` は、そのライブラリーの中しか見ません。** 影響調査は、関係するライブラリーごとに繰り返します。05-12 の検証のとおり、参照先のライブラリー名はコンパイル時のものなので、`<USER>2` のプログラムの参照先が `<USER>1` と出ても、それが実行時の依存とは限りません。

## 出力が違うとき

| 症状 | 考えること |
|---|---|
| 手順3の `SELECT` が「ファイルが見つかりません」になる | `CL:` 行と `SELECT` が別の接続・別のジョブで実行されています。同じ「実行 SQL スクリプト」の中で実行し直します。 |
| `PGMREF` に `WHPNAM` や `WHFNAM` が無い | 実機の ILE では、ありました(2026-10-04)。無いときは、手順3の実物の列名に合わせて、問い合わせを直します。 |
| 手順4で、同じプログラムが同じファイルで何行も出る | 1つのプログラムが、同じファイルを複数の行で参照しているためです(`JU0900C` は3行)。`SELECT DISTINCT` にします。 |
| 手順4に `ZA0500` が出ない | 実機では、プログラム記述のファイルも `DSPPGMREF` の行になりました(2026-10-04)。出ないときは、`ZA0500` が `RPGLE` で作り直されているか(手順1)と、対象のライブラリーを見直し、手順8のソース検索の結果も根拠にします。 |
| 手順4に、4本以外のプログラムも多く出る | ライブラリー全体(`/*ALL`)を調べているためです。作った覚えのないものも、自分のライブラリーのものだけです。 |
| `FNDSTRPDM` が画面を出して止まる | PDM の一覧画面が出ます(画面操作は、この教材の検証では確認していません。V3)。`F3` で戻り、`qsh` の `grep` に替えます。 |
| `grep` が何も返さない | パスの `<USER>1` を、自分のユーザー名にそろえます。メンバーの無い `QRPGLE112` に当たっている可能性もあります(04-27 の A4)。 |

## 演習

**同じ手順を `ZAIKOM` で行ってください。**

1. `DSPPGMREF` を `ZAIKOM` 向けに調べ(`WHFNAM = 'ZAIKOM'`)、直接参照しているプログラムを探してください。
2. `ZA0500`(`FZAIKOM    UF   E           K DISK`)が出るはずです(実機で確認、part04v-28imp、2026-10-04。`WHFUSG` は 5、`WHRFNM` は `ZAIKOR`)。04-23 で作った `V0423D`・`V0423E`・`W0423A` も、作ってあれば出ます(実機で確認、part04v-28imp、2026-10-04)。**旧システムの `ZA0510`(05-07 の演習が挙げる独立の教材)は、この旧システムには入っていません**(`TXLEGACY` が入れないため)。05-07 の演習と、出る顔ぶれが違います。
3. `ZAIKOM` の上に論理ファイルがあるか、`DSPDBR` で確認してください。`db/` には `ZAIKOM` の論理ファイルが無いので、間接参照の段は発生しないはずです(自分の目で確かめます)。
4. ソースの検索で `ZAIKOM` を探してください。`JU0900C` のヘッダー・コメント(`RUNMODE` の説明)に `ZAIKOM` が出ます。これは**コメントの言及**で、`JU0900C` は `ZA0500` を `CALL` するだけです。ヒット=依存、と判断しないことの実例として確認してください。
5. `ZAIKOM` と `JUCHUM` の影響調査表を並べ、**どちらにも出るプログラム**(`ZA0500`)を挙げてください。2つのファイルを同時に変える保守では、そのプログラムの手直しが重くなります。

## セルフチェック

- [ ] `DSPPGMREF` と `DSPDBR` の `*OUTFILE` を、同じジョブの中で SQL で読めた(別ジョブからは `QTEMP` が見えない理由を説明できる)。
- [ ] 手順3で、実物の列名を見てから問い合わせを書いた。
- [ ] `JU0300` を、直接参照だけの調査では見落とすことを、手順4と手順6の結果の違いで確認した。
- [ ] `ZA0500` が、様式レベル ID で止まらない(手で直す)側であることを説明できる。
- [ ] ソース検索のヒットを、「コードの依存」と「コメントの言及」に分けて判定した。
- [ ] `ZAIKOM` について同じ手順を独力で行った。

## 片付け

`QTEMP` に作った `PGMREF`・`DBRJUCHUM` などは、ジョブが終われば自動的に消えます。後片付けは不要です。この調査で、旧システムも、サンプル・データも、変えていません。

## まとめ

| 英語 | 日本語 |
|---|---|
| Impact analysis | 影響調査 |
| Outfile | 出力ファイル(`*OUTFILE`) |
| Job-scoped | ジョブ・スコープ(そのジョブの間だけ存在する) |
| Direct / indirect reference | 直接参照 / 間接参照 |
| Program-described file | プログラム記述ファイル |
| Cross-Reference Table | 相互参照表 |
| Record format level identifier | 様式レベル ID |

次は [06-01b](../part06/06-01b-reading-fixed-mixed-form.md) に進みます。第6部へ進む前に、ここで作った影響調査表を手元に残してください。10-02 で `TOKUIM` に項目を足すとき、同じ手順を `TOKUIM` に対して行います。

## 実機メモ

- **実施した検証: `verify/part04v-28imp`(2026-10-04、再実行)。** 初回は、検証用ライブラリーに `JU0300`・`ZA0500`・`TK0100` のプログラムが無く(前のバッチ `27set` が消していたためです)、ゲートが「作り直さない」と判断しました。再実行では、3本を `QRPGLE112` から `CRTBNDRPG` で作り直し、`DSPPGMREF`・`DSPDBR`・`DSPFD`・`FNDSTRPDM`・`grep` を実行したあと、`CRTRPGPGM` で RPG III に戻し、`TXRESET` でデータを初期状態にしました(戻した後の `OBJATTRIBUTE` は3本とも `RPG`)。
- **実機で確認したこと(part04v-28imp、2026-10-04)**:
  - 同じジョブの中で `DSPPGMREF`(`CPF3030`: 1678 件。初回は 1648 件)・`DSPDBR`(1 件)・`DSPFD`(3 件)を `QTEMP` に出力し、`RUNSQL`・`CPYF` で読めた。別のジョブからの `SELECT` は `SQLSTATE 42704` で失敗した(ジョブ・スコープ)。
  - `ZA0500` のプログラム記述の `JUCHUM`・`JUCHUD` は `DSPPGMREF` に出る(`WHOBJT = 'F'`・`WHOTYP = '*FILE'`・`WHFUSG = 1`・`WHLNAM = '*LIBL'`、`WHRFNM`・`WHRFSN` は空、`WHRFFN` は 0)。外部記述の `ZAIKOM` は `WHRFNM = 'ZAIKOR'`・`WHRFSN = '2FF50CA837102'`・`WHRFFN = 3`・`WHFUSG = 5`。`JU0300` は `JUCHUL1`(`WHRFSN` は `DSPFD` の `RFID` と同じ `2D46394749174`)で出て、`JUCHUM` では出ない。`WHOTYP` は `*FILE`・`*PGM`・`*DTAARA`・`*SRVPGM` の4種。
  - `OBJECT_STATISTICS` の `OBJATTRIBUTE`: 作り直す前は3本とも `RPG`、`CRTBNDRPG` の後は `RPGLE`。
  - `ZAIKOM` を参照する行に `ZA0500`・`V0423D`・`V0423E`・`W0423A` が出る(検証用ライブラリーの内容として `ZA0510` も出る)。
  - `PGMREF` の列(18列。`WHLIB`・`WHPNAM`・`WHTEXT`・`WHFNUM`・`WHDTTM`・`WHFNAM`・`WHLNAM`・`WHSNAM`・`WHRFNO`・`WHFUSG`・`WHRFNM`・`WHRFSN`・`WHRFFN`・`WHOBJT`・`WHOTYP`・`WHSYSN`・`WHSPKG`・`WHRFNB`)。ILE のプログラム(`V0421D`・`V0601A`)も CL(`JU0900C`・`JUCINQC`)も `WHFNAM = 'JUCHUM'`・`WHOBJT = 'F'` で出る。`DCLF` は見える。`JU0900C` から `ZA0500` を呼ぶ行は `WHOBJT = 'P'`。同じファイルが複数行で出る。
  - `DSPDBR`: `JUCHUM` の上は `JUCHUL1` の1行(`WHTYPE = 'D'`)。
  - `DSPFD ... TYPE(*RCDFMT)` の出力ファイルの `RFID` で ID を読める。`JUCHUM` と `JUCHUL1` は同じ `2D46394749174`、`JUCHUD` は `3B05FA0363592`。
  - `FNDSTRPDM`(`OPTION(*NONE) PRTMBRLIST(*YES) PRTRCDS(*ALL)`)は `QRPGLE112`・`QCLSRC` でも画面を出さず終わり(`PDM0594`・`PDM0574`・`PDM0575`)、`grep` も動く。ヒットのコード/コメントの内訳は、上の表のとおり。
- **未検証(2026-10-04時点)のこと**:
  - `WHRFFN` が何の数か(様式の項目数か、使った項目数か)と、`WHFUSG` の値の意味(観測した値は 1・2・3・5 など)。
  - コンパイル・リストに相互参照表が出ないときの `OPTION(*XREF)` の効果(既定のオプションで出ることは確認済み)。
  - ACS の `CL:` 行と SQL を、同じジョブで実行できるか(著者は ACS で実行していません)。
  - `ZA0500` の様式レベル・チェックが、ILE でも効かないか(`PGMREF` に ID が無いことまでは確認。ずれたファイルを実際に開く確認は、未実施)。
  - `FNDSTRPDM` の印字結果の、5250 の画面と `WRKSPLF` での見え方(印字内容そのものは確認済み)。
- **検証用ライブラリーについて**: 検証用ライブラリーには、他の検証で作ったプログラム・ソース・複製メンバーが多く入っています。`JUCHUM` を参照する行が35行(29本)出たのも、`ZAIKOM` の結果に `ZA0510` が出たのも、そのためです。あなたのライブラリーでは、この数にはなりません(演習の「`ZA0510` は入っていません」は、ルートの旧システムのとおりです)。
- **ほかのレッスンとのつながり**: [08-06](../part08/08-06-dds-to-sql-ddl.md) は `DSPFD ... TYPE(*RCDFMT) OUTPUT(*PRINT)` で ID を比べます。上の `OUTPUT(*OUTFILE)` の `RFID`・`RFNAME` を使えば、同じ比較を SQL で書けます(08-06 の本文の書き換えは要りません)。10-02 の影響調査(`DSPDBR`・`DSPPGMREF` の `WHPNAM`・`WHFNAM`)は、ここで確認した列名と同じです。
- **`JUDLV` について(上の説明の再掲)**: 08-06 は `JUDLV` を日付型の例として名前を挙げるだけで、使う手順は無い。ルートの `JUCHUM`(`DBVER` 1)には `JUDLV` が無い(検証でも、`JUCHUM` は4列、`JUDLV` は0列でした)。08-06 を書き直す必要はない。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
