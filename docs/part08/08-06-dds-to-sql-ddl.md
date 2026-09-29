# 08-06 DDSからSQL DDLへ

> 所要時間: 60分 / 前提レッスン: 08-05b / 目標番号: 6 / 観測方法: 様式レベルID(`DSPFD TYPE(*RCDFMT)`の値の一致)・生成されたDDL文(`CALL QSYS2.GENERATE_SQL`の結果セット)・`DSPFFD`のフィールド一覧 / 道具: SQL(ACSの「実行SQLスクリプト」、CLコマンドとSQLを混在実行)/ 同時接続数: ACS×1(`DSPFD`/`DSPFFD`の結果はスプール・ファイルになるため、確認だけの目的で5250を追加で開くことがあります。詳しくは下の「実演」参照)/ 作る・変えるオブジェクト: なし(`QTEMP`に`TOKUIM`・`SHOHIM`の複製を一時的に作るだけです。共有の本物の`TOKUIM`・`SHOHIM`は一切変更しません)/ DBVER: 1 / 依存するプローブ: P29(`part08-06-lvlid-and-gensql`・`part08-06-lvlid-confirm`で実質解消。`docs/probes.md`末尾の「未実施のプローブ」一覧はこの解決をまだ反映していません)/ PTF 依存: なし / 容量の目安: わずか

## ゴール

- 08-06-1: `QSYS2.GENERATE_SQL`を呼び出し、DDSの外部記述ファイル(`TOKUIM`)からSQLの`CREATE TABLE`文を生成し、`QTEMP`へ実行できる。
- 08-06-2: `DSPFD TYPE(*RCDFMT)`で様式レベルIDを比較し、変換の前後で「形」が変わっていないことを機械的に確認できる。
- 08-06-3: `VARCHAR`/`DECIMAL`/`PRIMARY KEY`のようなSQLの型・制約を使い、`SHOHIM`を意図的に近代化した表として自分で書き直せる。

## ウォームアップ

<details><summary>前回までの復習(05-07/05-09)</summary>

1. (05-09)様式レベルIDとは何ですか? `CPF4131`はどんな場面で起きるエラーでしたか?
2. (05-07)`DSPPGMREF`の`*OUTFILE`をSQLで読むとき、`DSPPGMREF`を実行したジョブと`SELECT`を実行するジョブが同じでなければならなかったのはなぜですか?

答え: 1. 様式レベルIDは、外部記述ファイルのレコード様式ごとに、その「形」(項目の並び・型・長さ)から計算される隠れた識別子です。コンパイル済みプログラムは、参照する外部記述ファイルの様式レベルIDを自分の中に焼き込んでおり、実行時に「自分が焼き込んでいるID」と「今実際にそのファイルが持っているID」を比較します。ファイルの形が変わってズレていると`CPF4131`(様式レベルID不一致)で実行時エラーになります。 2. `QTEMP`はジョブ・スコープの特別なライブラリーで、そのジョブが終わると自動的に消える、そのジョブだけの作業ライブラリーだからです。別のジョブ・別の接続からは中身が見えません。

</details>

## なぜ学ぶか

第8部はここまで、ビルド(08-01)・自動化(08-02)・静的解析(08-03)・テスト(08-04)・レガシーの近代化(08-05/08-05b、RPGのロジックを特性検定で守りながら書き換える)と積み重ねてきました。08-05/08-05bが近代化したのは**ロジック**でしたが、このレッスンが近代化するのは**データ定義**です——DDS(`db/v1/tokuim.pf`のような外部記述ファイル)を、SQLの`CREATE TABLE`という現代的な形へ生成し直せるかどうかを確かめます。

このレッスンで実際に新しく学ぶ道具は`QSYS2.GENERATE_SQL`という1つのIBM iサービス(プロシージャー)だけです。「変換の前後で形が変わっていないか」を確かめる考え方自体は、05-09で既に学んだ**様式レベルID**の応用にすぎません。「`QTEMP`での検証は、それを作ったジョブの中でしか見えない」という注意点も、05-07で既に学んだ`DSPPGMREF`の`*OUTFILE`とまったく同じ原則の応用です。つまりこのレッスンは、新しい概念を1つ(`GENERATE_SQL`という生成の仕組み)だけ足し、残りは08-05/08-05bまでに身につけた「変更の前後を機械的に検証する」という姿勢を、DDSからSQLへの変換という新しい場面に適用する回です。

現場では、古いDDSの物理ファイルをそのままにするか、SQLの表として作り直すか(あるいは両方を共存させるか)という判断が、モダナイゼーション案件の入り口でよく問題になります。「本当に同じ形になっているか」を目視ではなく様式レベルIDという機械的な指標で確かめられることは、この判断を安全に進めるための土台になります。

## 新出

- 中核概念(3つ):
  1. **DDSの外部記述ファイルは、`GENERATE_SQL`を使ってSQLの表として生成し直せる。** `QSYS2.GENERATE_SQL`は、既存の外部記述ファイル(物理ファイル等)の定義を読み取り、それと同じ形を表す`CREATE TABLE`文(および付随する`LABEL ON`/`GRANT`文)を生成するIBM iサービスです。手で1から書き写すのではなく、システム自身に「今の形」を語らせる、という発想です。
  2. **様式レベルIDは「形が変わったかどうか」を機械的に判定する仕組み(05-09の復習・一般化)。** 05-09では、`CHGPF`でDDSの形を変えたときに`CPF4131`(様式レベルID不一致)が起きる場面を扱いました。このレッスンは同じ仕組みを、逆方向(「意図的に形を変えていないつもりの変換が、本当に変わっていないか」を確かめる)に使います。**新しい概念ではなく、05-09で学んだ道具の新しい使い道です。**
  3. **`QTEMP`での検証はジョブ限定(job-scoped)である(05-07の復習の応用)。** 05-07では、`DSPPGMREF`の`*OUTFILE`が`QTEMP`に書かれるため、それを実行したジョブと同じジョブでしか`SELECT`できないという注意点を学びました。このレッスンで`QTEMP`へ作る表(`QTEMP.TOKUIM`・`QTEMP.SHOHIM`)にも、**まったく同じ原則**が及びます——`CREATE TABLE`した接続と、`DSPFD`/`DSPFFD`で確認する接続は、同じACSセッション(同じジョブ)でなければなりません。5250セッションとACSセッションは別ジョブであり、`QTEMP`オブジェクトを共有しないことに注意してください。

- 構文(4つ):
  1. `CALL QSYS2.GENERATE_SQL(...)`(DDSの外部記述ファイルからSQLの`CREATE TABLE`文を生成する)。
  2. `DSPFD FILE(...) TYPE(*RCDFMT)`(様式レベルIDを確認する)。
  3. `DATE`/`TIMESTAMP`/`VARCHAR`型宣言(SQLの`CREATE TABLE`で使う、DDSには無い型)。
  4. `PRIMARY KEY`制約(表に主キーを持たせる、DDSの単純な`K`(キー指定)には無い概念)。

**読解用(新出に数えない)**:

- `FOR SYSTEM NAME`: DDSのシステム名(10文字以内の旧来の名前)とSQL名(最大128文字)を両方持たせるための句です。design doc(`work/design/part08-design-v1.md`)は当初この構文も新出に数えていましたが、この教材の実機検証では、`FOR COLUMN`句の位置を誤った自作ミス(下の「実機メモ」参照)で手書きDDL案自体が失敗しており、`FOR SYSTEM NAME`だけを切り分けて確認できた接続は一度もありません。存在自体は`rbafy75.txt`にシーケンス/ビューの文脈で実例がありますが、`GENERATE_SQL`の出力そのものではありません。**一般知識、要確認(V3)として扱ってください。**
- `RCDFMT`(`CREATE TABLE`のキーワード、生成されたDDLに実際に付いてくる`RCDFMT TOKUIR`のような句): 一次資料(`work/design/refs/`)には0件で、design doc自身がこのギャップを明記しています。実際に`GENERATE_SQL`の出力に登場することは実機で確認済みですが、この句自体の詳しい意味・省略時の挙動は**一般知識、要確認(V3)**として扱ってください。
- `DSPFFD`(フィールド単位の情報を見るCLコマンド): 05-12で既に一度使っています(`DSPFFD FILE(<自分のユーザー名>1/TK0100D)`)。ここでは同じコマンドを、生成された表のフィールド構成を1つずつ確認する用途で使うだけです。
- `CCSID`句・`LABEL ON`・`GRANT`: 生成されたDDLに実際に含まれますが、本文の新出構文には数えません(下の「説明」で内容だけ紹介します)。

## 説明

### `GENERATE_SQL`とは: DDSの外部記述ファイルをSQLの表として生成し直す

`QSYS2.GENERATE_SQL`は37個の実引数を持つプロシージャーです(内部の`SPECIFIC_NAME`は`QSQGENSQL`)。この一覧は、この教材の一次資料(`work/design/refs/`)には記載がありませんでしたが、`QSYS2.SYSROUTINES`/`QSYS2.SYSPARMS`という**IBM提供のシステム・カタログ自体**(`ROUTINE_SCHEMA = 'QSYS2' AND ROUTINE_NAME = 'GENERATE_SQL'`で絞り込み)を直接照会することで、37個すべてを正式な列定義として実機で確認できました(`docs/probes.md`「`part08-06-generate-sql-catalog`」)。このレッスンで実際に使うのは、そのうちのごく一部です。

| 位置 | 引数名 | 型 | 役割 |
|---|---|---|---|
| 1 | `DATABASE_OBJECT_NAME` | `VARCHAR(258)` | 変換したいオブジェクト名(例: `'TOKUIM'`) |
| 2 | `DATABASE_OBJECT_LIBRARY_NAME` | `VARCHAR(258)` | そのオブジェクトがあるライブラリー |
| 3 | `DATABASE_OBJECT_TYPE` | `VARCHAR(10)` | オブジェクトの種別(下の「落とし穴」参照) |

残り34個の引数(出力先ソース・ファイルの指定、日付書式、トリガー/制約を含めるかどうか等)は、省略すればすべて既定値のまま動きます。このレッスンでは、この3つの引数だけを指定する最小限の呼び出しを使います。

```sql
CALL QSYS2.GENERATE_SQL(
  DATABASE_OBJECT_NAME => 'TOKUIM',
  DATABASE_OBJECT_LIBRARY_NAME => '<自分のユーザー名>1',
  DATABASE_OBJECT_TYPE => 'TABLE');
```

### 実際に踏んだ落とし穴: `DATABASE_OBJECT_TYPE`は`'*FILE'`ではなく`'TABLE'`

この教材自身、`GENERATE_SQL`を実際に動かすまでに、合計5回の接続が失敗しました(`docs/probes.md`「`part08-06-ddl`」の3回の接続+「`part08-06-generate-sql-retry`」の2回の接続)。最初の失敗は存在しない引数名の指定でしたが、それを直した後も、`DATABASE_OBJECT_TYPE`に`'*FILE'`(IBM iの他の多くのコマンドで見慣れた、アスタリスク付きの特殊値)を**一度も疑わずに**使い続けていたことが、残り4回の失敗の原因だった可能性が高いと分かりました(`docs/probes.md`「`part08-06-lvlid-and-gensql`」自身も、断定はせず「可能性が高い」という言い方をしています)。実際に試すと:

- `DATABASE_OBJECT_TYPE => '*FILE'`: **`SQLSTATE 22023`、`DATABASE_OBJECT_TYPE NOT VALID`で失敗します。** `*FILE`は最初から有効な値ではありませんでした。
- `DATABASE_OBJECT_TYPE => 'TABLE'`: **成功します。**(`docs/probes.md`「`part08-06-lvlid-and-gensql`」で確認済み)

これは、新しい道具を使うときによくある落とし穴の実例です——「IBM iの他のコマンドでは`*FILE`のようなアスタリスク付きの特殊値をよく見るから、ここでもそうだろう」という類推が、そのまま外れることがあります。**一般的な感覚に頼らず、実際にカタログ(`QSYS2.SYSPARMS`)やドキュメントで確かめる**ことの大切さを、この教材自身が身をもって示した形です。

成功したときの`SQLSTATE`は`0100C`(クラス`01`=警告であり、エラーではありません)で、これは「1 result sets are available from procedure GENERATE_SQL」という**情報**にすぎません。この警告クラスのSQLSTATEを見て「失敗した」と早合点しないよう注意してください。

### 実際に生成された`TOKUIM`のDDL(実機確認済み)

上のとおり呼び出すと、生成された`CREATE TABLE`文・`LABEL ON`文・`GRANT`文が、結果セットとして返ってきます(`docs/probes.md`「`part08-06-lvlid-and-gensql`」の実機出力を、プレースホルダー化して引用しています)。**実際の結果セットは`SRCSEQ`/`SRCDAT`/`SRCDTA`という列を持つ、生成されたソースの1行ずつが1行になった表の形で返ってきます**(ソース物理ファイルの標準的な列構成です)。下の引用は、その`SRCDTA`列の中身だけを行の順につなげたものです——ACSの結果グリッドでは、この形のまま複数行に分かれて見えるはずなので、`CREATE TABLE`に当たる行だけを自分で拾い出す必要があります。

```sql
CREATE TABLE <自分のユーザー名>1.TOKUIM (
    TOKCD CHAR(6) CCSID 273 NOT NULL DEFAULT '' ,
    TOKNM CHAR(30) CCSID 273 NOT NULL DEFAULT '' ,
    TOKZIP CHAR(7) CCSID 273 NOT NULL DEFAULT '' ,
    TOKTAN CHAR(6) CCSID 273 NOT NULL DEFAULT '' ,
    TOKUPD NUMERIC(8, 0) NOT NULL DEFAULT 0 )
    RCDFMT TOKUIR ;

LABEL ON TABLE <自分のユーザー名>1.TOKUIM IS 'Customer master' ;
LABEL ON COLUMN <自分のユーザー名>1.TOKUIM
( TOKCD TEXT IS 'Customer code' ,
    TOKNM TEXT IS 'Customer name' ,
    TOKZIP TEXT IS 'Zip code' ,
    TOKTAN TEXT IS 'Sales rep code' ,
    TOKUPD TEXT IS 'Updated date YYYYMMDD' ) ;

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE
ON <自分のユーザー名>1.TOKUIM TO <自分のユーザー名> WITH GRANT OPTION ;
```

生成されたコメントの中に、IBM自身の警告メッセージが2件そのまま埋め込まれていました。

```text
-- SQL150B   10   REUSEDLT(*NO) in table TOKUIM in <自分のユーザー名>1 ignored.
-- SQL1506   30   Key or attribute for TOKUIM in <自分のユーザー名>1 ignored.
```

これは`db/v1/tokuim.pf`の`K TOKCD`(キー付きアクセス経路)が、この変換ではSQL側の制約には変換されず、**そのまま無視された**ことを示しています(下の「限界」で詳しく扱います)。

**注意: `LABEL ON`/`GRANT`は本物のライブラリーを指したまま実行してはいけません。** 上のDDLは`<自分のユーザー名>1.TOKUIM`(あなたの実際のライブラリー)をそのまま指しています。このレッスンで実際に実行するのは、**`CREATE TABLE`の部分だけ**を`QTEMP`へ向けて書き換えたものです(次の項)。`LABEL ON`・`GRANT`をこのまま実行すると、本物の共有オブジェクトのラベル・権限を書き換えてしまいます。

型の対応にも注目してください。`TOKUPD`(DDSでは`8S 0`、ゾーン10進数)は、`DECIMAL`ではなく**`NUMERIC(8, 0)`**として生成されています。IBM i(Db2 for i)では、SQLの`NUMERIC`型がゾーン10進数に、`DECIMAL`型がパック10進数に対応します——`GENERATE_SQL`自身がゾーン10進数の`TOKUPD`に`NUMERIC`を選んだこと自体が、この対応関係の実機での裏付けです。この対比は、下の演習(`SHOHIM`の`SHOTNK`をあえて`DECIMAL`にする)で活きてきます。

### 様式レベルIDで確かめる(05-09の復習の応用)

`GENERATE_SQL`が生成したDDLが、本当に元の`TOKUIM`と同じ「形」になっているかを、目で見比べる代わりに、05-09で学んだ**様式レベルID**で機械的に確かめます。`CREATE TABLE`部分だけを`QTEMP`へ実行し(`src/sql/08-06-ddl.sql`)、`DSPFD FILE(...) TYPE(*RCDFMT)`が返すレベルIDを、本物の`TOKUIM`のレベルIDと比較します。

**実機で完全一致を確認済みです**(`docs/probes.md`「`part08-06-lvlid-confirm`」)。`QTEMP.TOKUIM`(生成DDLから作成)と本物の`TOKUIM`(DDS原本)は、どちらも様式レベルID`3B1ECB3196772`(`TOKUIR`様式、5フィールド、57バイト)でした。`DSPFFD`でフィールド一覧を見ても、型(`CHAR`×4・`ZONED 8,0`)・バッファー長・位置まで完全に一致します。

**この`3B1ECB3196772`という具体的な値についての注意**: この教材の検証は、著者の私的な学習領域(`<自分のユーザー名>1`相当)を検証に使わないという方針上、実際には`<USER>2`というライブラリーに対して行われました(`docs/probes.md`5行目・33行目の方針、08-07の実機メモにも同じ注記があります)。様式レベルIDは対象ファイルの「形」だけから計算されるので、あなた自身の`<自分のユーザー名>1/TOKUIM`でも理論上は同じ値になるはずですが、**このレッスンが実際に確認したのはあくまで`<USER>2`での一致です。** 自分の手順を確認するときに大事なのは、**手順1(変換前の本物の`TOKUIM`)と手順4(`QTEMP.TOKUIM`)、あなた自身が測った2つの値が一致すること**であり、必ずしもこの文書と一字一句同じ16進文字列になっている必要はありません。

### `QTEMP`のジョブ・スコープ(05-07の復習の応用)

`CREATE TABLE QTEMP.TOKUIM`を実行した接続と、`DSPFD FILE(QTEMP/TOKUIM) ...`でそのレベルIDを確認する接続は、**必ず同じジョブ(同じACSの「実行SQLスクリプト」セッション)**でなければなりません。これは05-07で学んだ、`DSPPGMREF`の`*OUTFILE`を`QTEMP`に書いたときとまったく同じ原則です——`QTEMP`はジョブが終わると自動的に消える、そのジョブだけの作業ライブラリーだからです。5250セッションとACSセッションは別ジョブなので、片方で`CREATE TABLE QTEMP.TOKUIM`し、もう片方で`DSPFD FILE(QTEMP/TOKUIM) ...`を実行しても、「オブジェクトが見つからない」というエラーになります。

なお`GENERATE_SQL`自体にも、生成したソースを`QTEMP`のようなソース物理ファイルへ書き出すための引数(`DATABASE_SOURCE_FILE_NAME`・`DATABASE_SOURCE_FILE_LIBRARY_NAME`)が別途用意されています。この教材の検証では、この2つの引数を省略した最小限の呼び出し(結果セットとして直接DDLを受け取る形)で成功を確認しており、この引数を使って実際に`QTEMP`のソース・ファイルへ書き出す経路そのものは、この教材ではまだ実行し切れていません(**一般知識、要確認(V3)**)。もしこの引数を使う場合も、書き出した接続と読み出す接続を同じジョブにする、という同じ原則が及ぶはずです。

### 限界の明記: キー付きアクセス経路は引き継がれない

**「様式レベルIDが一致した」ことと、「そのままキー・アクセス(`CHAIN`等)の代替になる」ことは別問題です。** 上で見たとおり、生成されたDDLには`SQL150B`/`SQL1506`という2つの警告コメントが含まれており、DDSの`K TOKCD`(キー付きアクセス経路)は**この変換には反映されません**。`JUCSRV`(07-02/07-03)や`f0803s.rpgle`(08-01/08-03)が使う`CHAIN(custCode) TOKUIM`のようなパターンは、キー付きアクセス経路を前提にしています。`GENERATE_SQL`がそのまま生成した表には、明示的な`PRIMARY KEY`やインデックスを別途追加しない限り、このアクセス経路がありません。**レベルIDの一致は「フィールド構造が同じ」ことの証明であり、「この生成された表をキー付きアクセス経路が必要な既存コードにそのまま差し込める」ことの証明ではない**、という点を混同しないでください。

### 近代化の構文: `DATE`/`TIMESTAMP`/`VARCHAR`型宣言と`PRIMARY KEY`制約

上の(A)`TOKUIM`の変換は、DDSの形を**変えない**ことを目的にした「忠実な変換」でした。これに対し、下の演習で扱う`SHOHIM`の近代化は、DDSには無い型・制約を**意図的に**使い、形を変えることが目的です。

- `VARCHAR(n)`: 固定長の`CHAR(n)`と違い、実際に入っている文字数だけを保持する可変長文字列型です。DDSの`A`型(固定長)フィールドを、末尾の空白を気にしなくてよい形に近代化するときに使います。
- `DECIMAL(p, s)`: パック10進数です(上で見たとおり、ゾーン10進数のDDS `S`型フィールドに対応するのは`NUMERIC`でした)。`DECIMAL`を選ぶこと自体が、ストレージ上の表現を意図的に変える近代化になります。
- `DATE`/`TIMESTAMP`: DDSにも`L`(DATE)型はありますが(05-09の`JUDLV`が実例です)、SQL側の`DATE`/`TIMESTAMP`型は、演算・比較・書式変換のための組み込み関数が豊富です。今回の演習対象`SHOHIM`には日付らしいフィールドが無いため実際には使いませんが、もし`TOKUIM`の`TOKUPD`(更新日)のような日付を近代化するなら、この型を検討することになります。
- `PRIMARY KEY (列名, ...)`: 表に主キー制約を持たせます。DDSの`K`(キー指定)は「重複を許すアクセス経路」でしかなく、一意性を強制しません。実際、上で見た`TOKUIM`の生成DDLには`PRIMARY KEY`が一切付いていません——DDSの`K TOKCD`は単なる非一意のキー付きアクセス経路であり、`GENERATE_SQL`自身もそれを主キー制約には変換していないからです。`PRIMARY KEY`を持たせるかどうかは、変換ツールに任せるのではなく、**近代化する側が意図して決める**ことになります。

### スコープ外: トリガー・`UNIQUE`/`CHECK`/外部キー制約

このレッスンで扱う制約は`PRIMARY KEY`までです。トリガーや、`UNIQUE`/`CHECK`/外部キー(`FOREIGN KEY`)のような制約は扱いません。一次資料(`rbafy75.txt`)自体には、制約・トリガーの記載が十分にあります(design docの確認によれば合わせて155/217件)。今回扱わないのは一次資料の不足ではなく、このレッスンの新出上限(構文6項目まで)とのトレードオフによる、意図的な範囲の決定です。これらは第10部の棚卸しへ送ります。

## 実演

**この実演の`GENERATE_SQL`呼び出し・生成DDL・`QTEMP.TOKUIM`の作成・様式レベルIDの一致は、すべて実機(`docs/probes.md`「`part08-06-lvlid-and-gensql`」「`part08-06-lvlid-confirm`」、確認日2026-09-29)でCONFIRMED SUCCESSまで確認済みです。** ACSの「実行SQLスクリプト」を1つ開き、05-07/08-07と同じ要領で、CLコマンド(`CL:`)とSQLを1つのスクリプトの中に混在させて、**最初から最後まで同じ接続(同じジョブ)のまま**進めてください。

1. **変換前の本物の`TOKUIM`の様式レベルIDを確認します(基準値)。**

   ```text
   CL: DSPFD FILE(<自分のユーザー名>1/TOKUIM) TYPE(*RCDFMT) OUTPUT(*PRINT)
   ```

   `OUTPUT(*PRINT)`なので、結果はスプール・ファイルとして作られます。**この教材自身の実機検証では、SSH経由のCLプログラムの中からこのコマンドを実行し、そのジョブの出力テキストをそのまま回収しました。ACSの「実行SQLスクリプト」で`CL:`プレフィックス経由でこのコマンドを実行したときに、結果が出力ペインへそのまま表示されるかどうか自体は、この教材ではまだ確認していません(一般知識、要確認・V3)。** 出力ペインに現れない場合は、5250(または別のACS機能)で`WRKSPLF`を開いて同じ内容を確認してください。**スプール・ファイルは`QTEMP`と違ってジョブ・スコープではありません**——`QTEMP.TOKUIM`という表そのものを別のジョブから見に行っているわけではなく、印字結果をあとから読んでいるだけなので、これは中核概念(3)の「`QTEMP`はジョブ限定」という原則には反しません。手順4で同じ形の出力が出るので、値の見え方はそちらでまとめて示します。

2. **`GENERATE_SQL`を呼び出し、`TOKUIM`のDDSをSQLの`CREATE TABLE`文として生成させます。**

   ```sql
   CALL QSYS2.GENERATE_SQL(
     DATABASE_OBJECT_NAME => 'TOKUIM',
     DATABASE_OBJECT_LIBRARY_NAME => '<自分のユーザー名>1',
     DATABASE_OBJECT_TYPE => 'TABLE');
   ```

   結果セットとして、上の「説明」で示した`CREATE TABLE`/`LABEL ON`/`GRANT`文が返ってきます。**`LABEL ON`・`GRANT`はここでは実行しないでください**(本物のライブラリーを指したままです)。ここで確認するのは、生成された`CREATE TABLE`文の中身と、`SQL150B`/`SQL1506`という2つの警告コメントが実際に付いていることです。

3. **生成された`CREATE TABLE`文を、`QTEMP`へ向けて実行します。** `src/sql/08-06-ddl.sql`の内容をそのまま使います(手順2の結果からライブラリー部分だけを`QTEMP`に書き換えた形です)。

   ```sql
   CREATE TABLE QTEMP.TOKUIM (
       TOKCD  CHAR(6)        CCSID 273 NOT NULL DEFAULT '' ,
       TOKNM  CHAR(30)       CCSID 273 NOT NULL DEFAULT '' ,
       TOKZIP CHAR(7)        CCSID 273 NOT NULL DEFAULT '' ,
       TOKTAN CHAR(6)        CCSID 273 NOT NULL DEFAULT '' ,
       TOKUPD NUMERIC(8, 0)            NOT NULL DEFAULT 0
   )
   RCDFMT TOKUIR;
   ```

   これは**あなた自身の`<自分のユーザー名>1/TOKUIM`にはまったく触れません**——`QTEMP`という、このジョブだけの作業ライブラリーに新しい表を作るだけです。

4. **`QTEMP.TOKUIM`の様式レベルIDを確認します。** 手順1〜3と**同じ接続のまま**、続けて実行してください。

   ```text
   CL: DSPFD FILE(QTEMP/TOKUIM) TYPE(*RCDFMT) OUTPUT(*PRINT)
   ```

   手順1・手順4とも、実機では次の形の出力になります(`docs/probes.md`「`part08-06-lvlid-confirm`」、`QTEMP.TOKUIM`側の実際の出力。本物の`<自分のユーザー名>1/TOKUIM`側もライブラリー名以外は同じ形です)。

   ```text
                                Record Format List
                       Record  Format Level
   Format       Fields  Length  Identifier
   TOKUIR           5      57   3B1ECB3196772
   ```

   (訳: 「様式一覧」——様式名`TOKUIR`、フィールド数`5`、レコード長`57`バイト、様式レベル識別子`3B1ECB3196772`。)

   手順1と手順4、2つの`Identifier`の値を比較してください。**この教材の実機検証では、両方とも`3B1ECB3196772`で完全一致しました**(上の「様式レベルIDで確かめる」の注意のとおり、これは`<USER>2`というライブラリーで確認した値です。あなた自身の環境で大事なのは、この文書と同じ文字列になることではなく、**あなたが測った2つの値どうしが一致すること**です)。

5. **(任意)`DSPFFD`でフィールド単位の一致も確認します。**

   ```text
   CL: DSPFFD FILE(QTEMP/TOKUIM) OUTPUT(*PRINT)
   ```

   型(`CHAR`×4・`ZONED 8,0`)・バッファー長・位置が、本物の`TOKUIM`(`DSPFFD FILE(<自分のユーザー名>1/TOKUIM) OUTPUT(*PRINT)`)と一致することを確認してください(実機確認済み、`docs/probes.md`「`part08-06-lvlid-confirm`」)。`TEXT`(見出し)欄は、`LABEL ON`を実行していないため空欄のままのはずですが、これは様式レベルIDの算出には含まれない情報なので、一致には影響しません。

## 演習

**`SHOHIM`(`db/v1/shohim.pf`)を、意図的に近代化した表として書き直してください。** ここから先は**この教材ではまだ実機確認していません(V3)**——あなた自身の接続で実際に試し、自分の目で結果を確かめる、正真正銘の演習です。`TOKUIM`の実演と違い、ここでは「形を変えない」のではなく「形を意図的に変える」ことが目標なので、様式レベルIDの一致を確認する意味はありません(むしろ一致してしまったら、近代化が実際には起きていないことになります)。

`SHOHIM`のDDS定義は次のとおりです。

```text
     A          R SHOHIR                    TEXT('Product master')
     A            SHOCD          6A         TEXT('Product code')
     A            SHONM         30A         TEXT('Product name')
     A            SHOTNK         7S 2       TEXT('Unit price')
     A            SHOHAT         5S 0       TEXT('Reorder point')
     A          K SHOCD
```

1. **(任意、比較のため)まず`TOKUIM`と同じ要領で、`SHOHIM`に対しても`GENERATE_SQL`を「忠実な変換」として呼び出してみてください。**

   ```sql
   CALL QSYS2.GENERATE_SQL(
     DATABASE_OBJECT_NAME => 'SHOHIM',
     DATABASE_OBJECT_LIBRARY_NAME => '<自分のユーザー名>1',
     DATABASE_OBJECT_TYPE => 'TABLE');
   ```

   `SHOCD`・`SHONM`・`SHOTNK`(おそらく`NUMERIC(7, 2)`)・`SHOHAT`(おそらく`NUMERIC(5, 0)`)という、`TOKUIM`のときと同じ傾向の生成結果になるはずですが、**この呼び出し自体、この教材ではまだ実機確認していません**(`TOKUIM`で確認済みの同じ形の呼び出しなので、同様に成功する可能性は高いと考えられますが、断定はしません)。

2. **次に、`SHOHIM`を手書きで近代化した`CREATE TABLE`文を書きます。** 次の3点を反映してください。
   - `SHONM CHAR(30)` → `VARCHAR(30)`(可変長化)。
   - `SHOTNK 7S 2`(ゾーン10進数) → `DECIMAL(7, 2)`(あえて`NUMERIC`ではなく`DECIMAL`を選び、パック10進数へ変える近代化)。**`DECIMAL`を選ぶと実際にパック10進数として保存されるという対応は、`NUMERIC`側(上の「説明」で見た`TOKUPD`の実例)ほど確かめられていません——一般知識、要確認(V3)として扱い、下の手順4の`DSPFFD`で自分の目で確認してください。**
   - `SHOCD`に`PRIMARY KEY`制約を付ける(DDSの`K SHOCD`は非一意のアクセス経路にすぎず、主キーではありませんでした)。

   `SHOHAT 5S 0`(発注点)は、そのまま`NUMERIC(5, 0)`(ゾーン10進数のまま)としてかまいません。**(発展・任意)** `INTEGER`型への変更も妥当な近代化ですが、必須ではありません。時間があれば試してみてください。`SHOHIM`には`TOKUPD`のような日付らしいフィールドが無いため、`DATE`/`TIMESTAMP`型は今回使いません(もし日付フィールドがあれば、`TOKUIM`の`TOKUPD`と同じ要領で検討することになります)。

   ```sql
   CREATE TABLE QTEMP.SHOHIM (
       SHOCD  CHAR(6)       NOT NULL,
       SHONM  VARCHAR(30)   NOT NULL,
       SHOTNK DECIMAL(7, 2) NOT NULL,
       SHOHAT NUMERIC(5, 0) NOT NULL,
       PRIMARY KEY (SHOCD)
   );
   ```

   **このレッスンで扱う制約は`PRIMARY KEY`までです。** トリガーや`UNIQUE`/`CHECK`/外部キーのような制約は、この演習の範囲外です(上の「説明」参照)。

3. **`QTEMP`へ実行します。** 本物の`<自分のユーザー名>1/SHOHIM`にはまったく触れません。

4. **`DSPFFD`で結果を確認します。**

   ```text
   CL: DSPFFD FILE(QTEMP/SHOHIM) OUTPUT(*PRINT)
   ```

   `SHOTNK`が`PACKED`(パック10進数、`TOKUPD`で見た`ZONED`ではなく)として表示されるはずです——ただし、この対応(`DECIMAL`宣言→`DSPFFD`上で`PACKED`と表示される)自体は、`NUMERIC`側(本文の`TOKUPD`の実例)ほどこの教材で実機確認できていません。**一般知識、要確認(V3)として、自分の目で確かめてください。** `SHONM`が`DSPFFD`上でどう表示されるか(`VARCHAR`という表記になるか、別の欄で可変長だと分かるか)も、この教材ではまだ確認していません(同じくV3)。

   成功の基準は「様式レベルIDが本物の`SHOHIM`と一致すること」**ではありません**——意図的に形を変えているので、一致しないのが正しい結果です。確認すべきは、**表が正常に作成できること(コンパイル・エラーが無いこと)**と、`DSPFFD`で意図した型(`SHOTNK`が`PACKED`)になっていることです。`DSPFFD`はフィールドの型・長さを見るコマンドであり、**`PRIMARY KEY`制約が付いているかどうかまでは表示しません**(実際、本文の`TOKUIM`の`DSPFFD`出力にも、キー・制約に関する欄は一切現れていません)。`SHOCD`が本当に主キーとして機能しているかを確かめたい場合は、`INSERT INTO QTEMP.SHOHIM`で同じ`SHOCD`を2回試し、2回目が一意性制約違反で拒否されることを確認してください(この確認方法自体は、この教材ではまだ実行していません・V3)。

## セルフチェック

- [ ] `GENERATE_SQL`の`DATABASE_OBJECT_TYPE`は`'*FILE'`ではなく`'TABLE'`でなければならない理由を、実際に起きたエラー(`SQLSTATE 22023`)を根拠に説明できる。
- [ ] `TOKUIM`に対して`GENERATE_SQL`を実行し、生成された`CREATE TABLE`文を`QTEMP`で実行できた。
- [ ] `DSPFD TYPE(*RCDFMT)`で、変換前後の様式レベルIDが一致することを確認した。
- [ ] 様式レベルIDの一致が「フィールド構造が同じ」ことの証明であり、「キー付きアクセス経路(`CHAIN`)の代替になる」ことの証明ではない理由を、`SQL150B`/`SQL1506`の警告コメントを根拠に説明できる。
- [ ] `QTEMP`での検証が同じジョブ(同じ接続)の中でしか通用しない理由を、05-07の`DSPPGMREF`の原則と結びつけて説明できる。
- [ ] `NUMERIC`(ゾーン10進数)と`DECIMAL`(パック10進数)の対応を、`TOKUPD`の生成結果を根拠に説明できる。
- [ ] `SHOHIM`を`VARCHAR`/`DECIMAL`/`PRIMARY KEY`を使って近代化した`CREATE TABLE`文を自分で書き、`QTEMP`で実行し、`DSPFFD`で意図した型になっていることを確認した。
- [ ] このレッスンで扱う制約が`PRIMARY KEY`までであり、トリガー・`UNIQUE`/`CHECK`/外部キー制約は扱っていないことを理解している。
- [ ] この実演・演習が、共有の本物の`TOKUIM`・`SHOHIM`を一度も変更していないことを理解している。

## 片付け

**このレッスンは、共有の本物の`TOKUIM`・`SHOHIM`を一度も作成・変更していません。** `QTEMP.TOKUIM`・`QTEMP.SHOHIM`はどちらも`QTEMP`(ジョブ・スコープの作業ライブラリー)に作った表なので、ACSの接続を終了すれば自動的に消えます。

同じ接続を続けて使う場合は、次のように明示的に`DROP TABLE`しておくことをお勧めします。08-04(`TESTKIT`の`testInit()`)で学んだとおり、**無修飾のDDL文(`CREATE TABLE`等)は現行ライブラリー(`*CURLIB`、通常`<自分のユーザー名>1`)に対して行われます**——`*LIBL`をたどる無修飾のDML文(`SELECT`等)とは違うルールです。このため、ライブラリーを付けない`TOKUIM`/`SHOHIM`という名前は、`QTEMP`ではなく本物の`<自分のユーザー名>1/TOKUIM`・`<自分のユーザー名>1/SHOHIM`を指してしまう恐れの方が大きいと考えられます(ACSの「実行SQLスクリプト」の命名モード(システム命名/SQL命名)によって挙動が変わる可能性があり、この点はこの教材ではまだ確認していません・一般知識、要確認・V3)。**どちらの意味でも、ライブラリーを省略しないことが唯一の確実な対策です。**

```sql
DROP TABLE QTEMP.TOKUIM;
DROP TABLE QTEMP.SHOHIM;
```

**`QTEMP.`を必ず付けてください。** ライブラリー部分を省いた無修飾の`DROP TABLE TOKUIM`/`DROP TABLE SHOHIM`は、上のとおり本物の`<自分のユーザー名>1/TOKUIM`・`<自分のユーザー名>1/SHOHIM`を指してしまう危険があるため、絶対に実行しないでください。

## まとめ

| 英語 | 日本語 |
|---|---|
| `GENERATE_SQL` | DDSの外部記述ファイルからSQLの`CREATE TABLE`文等を生成するIBM iサービス |
| Record format level ID | 様式レベルID(05-09で既習、このレッスンでは変換の一致判定に使う) |
| `NUMERIC` / `DECIMAL` | ゾーン10進数 / パック10進数に対応するSQLの数値型 |
| `VARCHAR` | 可変長文字列型(DDSの固定長`A`型との対比) |
| `PRIMARY KEY` | 主キー制約(DDSの`K`はアクセス経路にすぎず、一意性を強制しない) |

次のレッスン(08-07)では、`QSYS2`配下のIBM iサービスを、今度は権限・監査の視点で扱います。「自分自身にフィルターする」という新しい規律が中心になりますが、`QTEMP`のジョブ・スコープという今回の注意点は、そちらでも同じ形で登場します。

## 実機メモ

- **確認日: 2026-09-29。** このレッスンの核心(`GENERATE_SQL`の実引数確認→正しい呼び出し→生成DDL取得→`QTEMP`実行→様式レベルID完全一致)は、複数回の接続にまたがる調査の末にCONFIRMED SUCCESSへ到達しました。すべて`docs/probes.md`の該当節を参照してください。
- **`part08-06-ddl`(1〜3回目の接続)**: 探索的な最初の3回の接続です。1回目は存在しない引数名`DATABASE_FILE_TYPE`を使ってしまい失敗(`Named argument ... not valid`)、2回目は型を誤った修正で`Conversion error`、3回目は`SQL0443`(外部ルーチン内部のエラーを示す汎用メッセージ)で失敗し、この時点でいったん「一般知識、要確認」に倒す判断をしています。
- **`part08-06-generate-sql-catalog`**: `QSYS2.SYSROUTINES`/`QSYS2.SYSPARMS`を照会し、`GENERATE_SQL`(`SPECIFIC_NAME`は`QSQGENSQL`)の実引数37個すべてを正式な列定義として確認しました。`part08-06-ddl`の失敗を再検証し、1回目は存在しない引数名、2回目は`CREATE_OR_REPLACE_OPTION`(実際は`CHAR(1)`)の型不一致が疑わしいと特定しています。
- **`part08-06-generate-sql-retry`**: カタログで確定した引数の型を反映して2回接続しましたが、2回目も`SQL0443`で失敗しました。**修正した引数の型は正しいはずなのに同じ汎用エラーで止まったことから、原因は型・名前ではなく別の要因(値の組み合わせ等)にあると判断し、いったんこの経路での実働例の確立を打ち切っています。** この接続で、本物の`TOKUIM`の様式レベルID(`3B1ECB3196772`)自体は確認済みでした。
- **`part08-06-lvlid-and-gensql`**: **それまでの5回の接続すべてが`DATABASE_OBJECT_TYPE => '*FILE'`を疑わずに使い続けていたこと自体が真因だった**と判明した接続です。`'TABLE'`に変えるとただちに成功し(`SQLSTATE 0100C`、情報レベルの警告)、`TOKUIM`の完全な生成DDL(本文で引用したもの)を取得しました。`'*FILE'`は`SQLSTATE 22023`(`DATABASE_OBJECT_TYPE NOT VALID`)で改めて失敗を再確認しています。同じ接続で、`FOR COLUMN`句の位置を誤った手書きDDL案(`TOKCD FOR COLUMN TOKCD CHAR(6)`という誤った語順)が`SQL0612`で失敗しており、これが本文で`FOR SYSTEM NAME`をV3として扱っている理由です(この手書き案自体は、`GENERATE_SQL`が実際に動いたことで不要になりました)。
- **`part08-06-lvlid-confirm`**: `part08-06-lvlid-and-gensql`で得た生成DDLの`CREATE TABLE`部分だけ(`LABEL ON`/`GRANT`は含めない)を実際に`QTEMP.TOKUIM`として実行し、本物の`TOKUIM`と様式レベルIDを直接比較しました。**`QTEMP.TOKUIM`・本物の`TOKUIM`とも`3B1ECB3196772`で完全一致(CONFIRMED SUCCESS)。** `DSPFFD`のフィールド一覧(型・バッファー長・位置)も完全一致することを確認しています。生の結果は`work/verify/results/part08-06-lvlid-and-gensql-*.json`・`work/verify/results/part08-06-lvlid-confirm-*.json`に残っています。
- **実際に検証したライブラリーは`<USER>2`でした**(著者の私的な学習領域`<USER>1`を検証に使わないという、この教材の確定方針。`docs/probes.md`5行目・33行目、08-07の実機メモにも同じ注記があります)。学習者向けの本文は、この教材のこれまでの慣例どおり`<自分のユーザー名>1`への手順として書いています。様式レベルIDはファイルの「形」だけから決まるはずなので、`<自分のユーザー名>1/TOKUIM`でも同じ値になると考えられますが、**これは`<USER>1`側で個別に実機確認したわけではありません。**
- **この教材の実機検証で実際に使った経路は、本文が案内するACSの「実行SQLスクリプト」とは異なります。** `CALL QSYS2.GENERATE_SQL(...)`は`db2`コマンド(SSH経由のCLI)から直接実行しました(`RUNSQL`より詳細な`SQLSTATE`/ネイティブ・エラー・コードが得られるためです)。`CREATE TABLE QTEMP.TOKUIM ...`は、SSH経由で生成した独立のCLプログラムの中の`RUNSQL`コマンドとして実行しました。`DSPFD`/`DSPFFD`も同じCLプログラムの中で`OUTPUT(*PRINT)`として実行し、そのジョブの出力テキストをそのまま回収しました。ACSの「実行SQLスクリプト」で`CL: DSPFD ...`を実行したときに結果が出力ペインへ直接表示されるかどうかは、この教材ではまだ確認していません(一般知識、要確認・V3)。08-07の実機メモが`GRTOBJAUT`/`RVKOBJAUT`について注記しているのと同じ意味で、**挙動自体は同じはずですが、厳密には別の実行経路です。**
- **`GENERATE_SQL`の`DATABASE_SOURCE_FILE_NAME`/`DATABASE_SOURCE_FILE_LIBRARY_NAME`引数(生成したソースを`QTEMP`のソース・ファイルへ書き出す経路)は、`part08-06-generate-sql-retry`で`DATABASE_SOURCE_FILE_LIBRARY_NAME => 'QTEMP'`を指定して試みましたが、その接続自体が`SQL0443`で失敗しており、この経路そのものの成功は確認できていません。** 最終的に成功した`part08-06-lvlid-and-gensql`の呼び出しは、この2引数を両方省略した最小形(結果セットとして直接DDLを受け取る形)です。本文が「GENERATE_SQL自体もQTEMPへの書き出し引数を持つ」と述べている部分は、この理由により一般知識・要確認(V3)として扱っています。
- **`SHOHIM`に対する`GENERATE_SQL`の呼び出し・手書きの近代化`CREATE TABLE`文(`VARCHAR`/`DECIMAL`/`PRIMARY KEY`)は、この教材のどの接続でも実行していません。** 演習は設計どおり、学習者自身が実機で確認する内容です。`DECIMAL`型が実際にパック10進数として`DSPFFD`に現れるという対応も、`NUMERIC`側(`TOKUPD`の実例)のような実機的な裏付けはなく、一般知識・要確認(V3)です。
- **P29**: design doc(`work/design/final_probes.json`)自身の定義は「`CALL QSYS2.GENERATE_SQL('TOKUIM','<USER>1','TABLE') → QTEMPに作成 → DSPFD TYPE(*RCDFMT)でレベルIDを比べる → 影響: 08-06`」であり、これは上記`part08-06-lvlid-and-gensql`・`part08-06-lvlid-confirm`で実質的に解消しています(引数を位置指定から名前付きに変えた点、対象ライブラリーが`<USER>2`だった点を除き、内容は一致します)。**ただし`docs/probes.md`末尾の「未実施のプローブ」一覧(P02〜P44のうち未実施でないものを列挙する節)は、この解決をまだ反映していません。** 一覧の更新自体はこのレッスンの範囲外ですが、本文が「P29(確認済み)」ではなく上記のとおり詳しく注記しているのはこのためです。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
