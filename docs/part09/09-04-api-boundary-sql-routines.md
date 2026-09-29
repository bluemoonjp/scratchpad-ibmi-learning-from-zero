# 09-04 API境界(2): SQL外部プロシージャー・関数

> 所要時間: 75分(長め) / 前提レッスン: 09-02・09-03・07-05・08-08(部の扉は[第9部](index.md)。`JUCSRV`・`ZAISRV`は第8部で作り直した後のものを使います) / 目標番号: 7 / 観測方法: SQLの結果(`db2`の出力、`W0904A`表の中身)・`QSYS2.SYSROUTINES`と`OBJECT_STATISTICS`・`RUNSQLSTM`の実行リスト・`CHKOBJ`のメッセージ / 道具: SSH(`RUNSQLSTM SRCSTMF`・`db2`)+ 5250(`RUNSQL`・`CHKOBJ`。この2つは、検証ではCLプログラムの中からバッチ・ジョブで実行しました。5250の対話式ジョブでの実行は未検証(2026-09-29時点))。ACSの「実行SQLスクリプト」での確認はV3 / 同時接続数: 5250×1 + SSH×1 / 作る・変えるオブジェクト: SQLルーチン7個(`GET_CUST_NAME`・`COUNT_CUST_ORDERS`・`GET_STOCK_QTY`・`JUCHU_INQUIRY_JSON`・`LOW_STOCK`・`LOW_STOCK_RS`・`JUCHU_REGISTER`。実体として作られるのは`<自分のユーザー名>1`の`*SRVPGM`の`JUCHUINQJS`・`LOWSTOCKT`と、`*PGM`の`LOWSTOCKRS`・`JUCHUREGST`の4つだけ)、作業表`<自分のユーザー名>1/W0904A`、`JUCHUM`・`JUCHUD`の受注番号`J09901`〜`J09903`の行、演習(a)の応用で作る`LOW_STOCK_BELOW`(実体は`*SRVPGM`の`LOWSTOCKB`)、`RUNSQLSTM`の実行リスト(スプール・ファイル)、演習(a)の応用で書くスクリプト・ファイル`$HOME/lowstockb.sql`。すべて片付けで削除します。既存の`JUCSRV`・`ZAISRV`のプログラムそのものは書き換えませんが、登録の際に登録情報が書き込まれる可能性があります(「説明」参照) / DBVER: 1 / 依存するプローブ: P31(バッチ`part09-04-sql-routines`、2026-09-29に3回の接続で確認、IBM i 7.5。`RUNSQLSTM`・`db2`・`RUNSQL`の経路はV2、ACSでの表示はV3=未検証)・P32の一部(`$`・`[`・`]`を含む`.sql`をCCSID 273タグのまま`RUNSQLSTM`で実行) / PTF 依存: PTFレベルの下限は未検証(2026-09-29時点)(確認したのはV7R5M0のみ) / 容量の目安: わずか(実体のオブジェクトの大きさは記録していません。未検証(2026-09-29時点))

## ゴール

- 09-04-1: `JUCSRV`・`ZAISRV`の既存の手続きを、`LANGUAGE RPGLE`・`PARAMETER STYLE GENERAL`のSQL関数として登録し、値が返ること(見つからない場合の`NOTFOUND`・`-1`、`NULL`引数の`NULL`を含む)を確かめられる。あわせて、エクスポート名の大文字小文字が合わないときの紛らわしいメッセージ(`CPF426A`・`SQL0204`)の意味を説明できる。
- 09-04-2: `LANGUAGE SQL`で、スカラー関数(`JUCHU_INQUIRY_JSON`)・表関数(`LOW_STOCK`)・結果セットを返すプロシージャー(`LOW_STOCK_RS`)を作って呼び出し、`SPECIFIC`名からどんなオブジェクトができるかを`CHKOBJ`・`OBJECT_STATISTICS`で確かめられる。
- 09-04-3: JSON文書1つを受け取り、`JSON_TABLE`の`NESTED PATH`で受注ヘッダーと明細に分けて登録するプロシージャー(`JUCHU_REGISTER`)を呼び、二重登録の拒否と、`COMMIT(*NONE)`のときの「ヘッダーだけ残る」すき間を説明できる。

## ウォームアップ

<details><summary>前回までの復習(07-03・09-02・09-03)</summary>

1. (09-02)`JSON_TABLE`の`NESTED PATH 'lax $.lines[*]'`は、何をしますか。
2. (09-03)`reserve`・`release`をSQL関数として公開しない、と決めたのはなぜですか。`get`は公開してよいのはなぜですか。
3. (07-03・07-05)`JUCSRV`の`getCustName`は混在大文字小文字、`ZAISRV`の`GET`は大文字でエクスポートされています。それぞれ、ソースのどこでそう決まりましたか。

答え: 1. JSON配列の要素1つごとに1行を作り、親の項目(注文番号など)を繰り返した行として返します(09-02の実機では、全12明細行が`J00001`〜`J00008`の親つきで得られました)。 2. `reserve`・`release`は`ZAIKOM`を書き換える副作用があり、`SELECT`文の中で暗黙に何度も評価されうるSQL関数として公開するのは危険だからです。`get`は見るだけで副作用がなく、何度呼んでも同じ結果になる(冪等な)手続きです。 3. `JUCSRV`は各手続きの`EXTPROC(*DCLCASE)`と、バインダー・ソースの`EXPORT SYMBOL('getCustName')`(引用符つき)です。`ZAISRV`はバインダー・ソースの`EXPORT SYMBOL('GET')`等です(エクスポート一覧を`DSPSRVPGM`で直接見たことはありません。07-05では`DRIVER`の束縛で間接的に、このレッスンの検証では`GET`の登録が呼べたことで裏付けられました)。

</details>

## なぜ学ぶか

09-03では「APIに向いた手続きの形(契約)」を紙とコンパイルで考えました。このレッスンは、その契約を**SQLという共通の入口**に載せます。SQLの関数・プロシージャーになれば、ACS、`db2`、JDBC/ODBCなど、SQLを話せる相手なら誰でも同じ形で呼べるからです。現場では「既存のRPGの手続きを、新しいRPGを書かずにSQLから呼べるようにしてほしい」という依頼と、「一覧やJSONを返す小さな入口を、RPGを介さずSQLだけで作りたい」という依頼の両方に出会います。このレッスンは、その2つを1本のスクリプトで体験します。

ここで作る`JUCHU_INQUIRY_JSON`(受注1件をJSONで返す)と`LOW_STOCK`(発注点割れの一覧)は、次の09-05・09-06を経て、09-07の受注サマリーAPI(`ORDER_SUMMARY_JSON`)の部品になります。この部の最後の総まとめも、第10部の総合演習E(API)も、このレッスンの型を土台にします。

もう1つの狙いは、**「動いた」と「正しく動く」の間のわなを先に踏んでおく**ことです。エクスポート名の大文字小文字、ルーチンに保存されるSQLパス、リテラルの数値がJSONで文字列になる現象、呼び出しの順序。どれも、知らないと原因が見当違いのメッセージの後ろに隠れます。

## 新出

- 中核概念(3つ):
  1. **既存の`*SRVPGM`をSQLの窓として登録する**。新しいRPGは書かず、`JUCSRV`・`ZAISRV`の手続きに、SQLの名前と型を与えます。
  2. **3つの型(スカラー関数・表関数・結果セットを返すプロシージャー)と、`SPECIFIC`名で実体を追跡すること**。何を返し、どう呼び、どんなオブジェクトができるかがそれぞれ違います。
  3. **`LANGUAGE SQL`を選ぶ設計判断と、SQL側の決まり(SQLパス・原子性のすき間)**。RPGを介さなければ、活動化グループなどRPG側の設定に悩まずに済みます。そのかわり、ルーチンに保存されるSQLパス(無修飾の名前を探す場所)や、コミット制御なし(`COMMIT(*NONE)`)のときに「ヘッダーだけ残る」すき間など、SQL側の決まりを知る必要があります。
- コマンド・構文(5つ):
  1. `CREATE FUNCTION ... LANGUAGE RPGLE PARAMETER STYLE GENERAL EXTERNAL NAME '...'`(既存の手続きの登録)
  2. `CREATE FUNCTION ... RETURNS TABLE (...) LANGUAGE SQL RETURN SELECT ...`(表関数)
  3. `SELECT ... FROM TABLE(関数名(...)) AS 別名`(表関数の呼び出し)
  4. `CREATE PROCEDURE ... DYNAMIC RESULT SETS n`と、本体の`DECLARE ... CURSOR WITH RETURN`・`OPEN`(結果セット)
  5. `SPECIFIC 名`(ルーチンの実体の名前を、10文字以内の有効なシステム名で自分で決める)
- **読解用(新出に数えません。読んで意味が分かればよく、自分で書けなくて構いません)**:
  - `CREATE FUNCTION`の指定句: `RETURNS NULL ON NULL INPUT`・`NOT FENCED`・`DISALLOW PARALLEL`・`NO SQL`・`NOT DETERMINISTIC`(コピーして使います)。
  - `SIGNAL SQLSTATE`(二重登録を断る)、`SET OPTION COMMIT = *NONE`、`CALL`、`DROP SPECIFIC`(片付け)、`db2`からの呼び出し、`RUNSQL ... NAMING(*SQL)`。
  - `CREATE PROCEDURE ... LANGUAGE SQL`による受注登録(`VARCHAR(n) CCSID 1208`の入力を`JSON_TABLE ... NESTED PATH`で分解。09-02の復習です)。

## 説明

### SQLルーチンとは何か(Windows/Linuxとの比較)

WindowsのDLLやLinuxの共有ライブラリー(`.so`)は、プログラムが「この名前の関数を、この引数で呼ぶ」と約束して使います。IBM iの`*SRVPGM`(サービス・プログラム。07-02)も同じ仲間です。SQLルーチンは、その関数に**SQLの側の名前・引数の型・戻り値の型**を付けて、データベースのカタログ(`QSYS2.SYSROUTINES`)に登録する仕組みです。登録すれば、`SELECT GET_CUST_NAME('C00001') FROM ...`のように、SQLの文の中から呼べます。

ルーチンには、次の3つの型があります。

| 型 | 何を返すか | 呼び方 | このレッスンの例 |
|---|---|---|---|
| スカラー関数 | 値1つ | 式の中(`SELECT`の列、`WHERE`など) | `GET_CUST_NAME`・`COUNT_CUST_ORDERS`・`GET_STOCK_QTY`・`JUCHU_INQUIRY_JSON` |
| 表関数(UDTF) | 行の集まり(表) | `FROM TABLE(関数名(...))` | `LOW_STOCK` |
| プロシージャー | 戻り値なし。`OUT`引数か、結果セット | `CALL` | `LOW_STOCK_RS`(結果セットあり)・`JUCHU_REGISTER`(入力だけ) |

そして、実体(中身)の書き方にも2種類あります。

- **外部ルーチン**(`LANGUAGE RPGLE`など): 中身は既存の`*SRVPGM`・`*PGM`にあり、SQL側は「名前と型の登録」だけです。
- **`LANGUAGE SQL`のルーチン**: 中身もSQLで書きます。Db2が内部でCのプログラムに変換してコンパイルし、実体のオブジェクトを作ります。

### 既存の手続きをSQL関数として登録する

`JUCSRV`の`getCustName`(得意先コードから得意先名を返す)を登録する文は、次のとおりです(`src/sql/09-04-routines.sql`の節1)。

```sql
CREATE OR REPLACE FUNCTION GET_CUST_NAME (CUST_CODE CHAR(6))
  RETURNS CHAR(30)
  LANGUAGE RPGLE
  SPECIFIC GETCUSTNM
  NOT DETERMINISTIC
  NO SQL
  RETURNS NULL ON NULL INPUT
  EXTERNAL NAME 'JUCSRV(getCustName)'
  PARAMETER STYLE GENERAL
  NOT FENCED
  DISALLOW PARALLEL;
```

- **型の対応**: RPGの`char(6)`はSQLの`CHAR(6)`、`char(30)`は`CHAR(30)`、`zoned(5:0)`は`NUMERIC(5, 0)`、`packed(7:0)`は`DECIMAL(7, 0)`に対応させました(3つとも、この対応で作成でき、呼び出せました)。
- **`PARAMETER STYLE GENERAL`**: 引数がそのまま渡り、戻り値がそのまま返る、素直な形です。`JUCSRV`・`ZAISRV`の手続きは、値渡し・値返しの単純な形なので、この形に合います。
- **`RETURNS NULL ON NULL INPUT`**: 引数が`NULL`なら、手続きを呼ばずに`NULL`を返す指定です(実機で確認。下の手順5)。
- **`NOT FENCED DISALLOW PARALLEL`**: 呼び出し元と同じスレッドで動かす・並列実行しない、という要求です。ただし、IBM Docsは「`NOT FENCED`はデータベースへの提案で、`FENCED`と同じように動かすこともある」と書いています(IBM Docs『Db2 for i SQLプログラミング』の外部関数の説明。実機未確認)。既定は`FENCED`と書かれていますが(同じ説明)、この教材の実機確認は`NOT FENCED`を指定した形だけです。`FENCED`のままにした場合の動作は未検証(2026-09-29時点)です。
- **`SPECIFIC GETCUSTNM`**: この関数の「特定名」(実体を指す名前)です。後の節で説明します。

登録しなかった手続きもあります。`reserve`・`release`は在庫を書き換えるので、SQL関数にしません(09-03)。`pingJucsrv`は動作確認用の使い捨てなので対象外です。

### `EXTERNAL NAME`のわな(1): 大文字小文字は完全一致

`EXTERNAL NAME 'JUCSRV(getCustName)'`の括弧の中は、サービス・プログラムが**エクスポートしている名前と完全に同じ綴り**でなければなりません。`JUCSRV`は混在大文字小文字の`getCustName`、`ZAISRV`は大文字の`GET`です(07-03と、このレッスンの検証で`GET`が呼べたこと)。

実機では、綴りを間違えても**`CREATE`は成功し、呼び出したときに初めて失敗しました**。しかもメッセージが紛らわしいものでした。

| 登録した綴り | `CREATE` | 呼び出し |
|---|---|---|
| `'JUCSRV(getCustName)'`(正しい) | 成功 | 成功 |
| `'JUCSRV(GETCUSTNAME)'`(大文字にした) | 成功 | 失敗: `CPF426A`「User-defined function ... cannot be invoked.」と`SQL0204`「JUCSRV in ライブラリー type *SRVPGM not found.」 |
| `'ZAISRV(get)'`(小文字にした) | 成功 | 同じく失敗(`SQL0204`は「ZAISRV in ... not found.」) |

`SQL0204`は「`JUCSRV`というサービス・プログラムが見つからない」と読めますが、`JUCSRV`は存在します。見つからないのは、**その名前のエクスポート**です。このメッセージが出たら、サービス・プログラムの存在を疑う前に、`DSPSRVPGM SRVPGM(<自分のユーザー名>1/JUCSRV)`でエクスポートの綴りを確かめてください(07-02・07-03で紹介した、エクスポート一覧を見る方法です。対話式の確認で、V3です)。

### `EXTERNAL NAME`のわな(2): ライブラリーを書くか

`EXTERNAL NAME`にライブラリーを書かずに`'JUCSRV(getCustName)'`と書くと、どうなるでしょうか。IBM Docsには、ライブラリーを省略した例がありません。そこで実機で試しました(CLプログラムの中の`RUNSQL`と、`RUNSQLSTM`)。結果は次のとおりです。

- **ライブラリーを書いても('ライブラリー/JUCSRV(getCustName)')、書かなくても、作成でき、どちらも呼び出せました。** このレッスンのスクリプトは、書かない形です。
- ただし、書かなくても**「呼び出すたびにライブラリー・リストで探す」わけではありませんでした**。`QSYS2.SYSROUTINES`の`EXTERNAL_NAME`列を見ると、`RUNSQLSTM`(SQL命名・`DFTRDBCOL`指定)で作ったものは、`ライブラリー/JUCSRVU(getCustName)`のように、**作成した時点で、見つかったライブラリーの名前が付いた形**で記録されていました。一方、`RUNSQL`(システム命名)で作ったものは`*LIBL/JUCSRVU(getCustName)`と記録されました。どちらの記録も、呼び出せました。
- 作成時のライブラリーが、ライブラリー・リストで見つかったのか`DFTRDBCOL`で見つかったのかは、切り分けていません。この教材の検証では、どちらにも同じライブラリーが入っていました(未検証(2026-09-29時点))。

つまり、ルーチンは作った時点のライブラリーを覚えます。第8部の`<自分のユーザー名>1`から`<自分のユーザー名>2`への昇格(`CRTDUPOBJ`等)の後で、SQLルーチンの参照先がどうなるかは、この教材では確かめていません(IBM Docsには「`CRTDUPOBJ`等で、複製した後の実行可能オブジェクトの名前を指す新しい行が`SYSROUTINES`に入る」という記載がありますが、実機では未検証(2026-09-29時点))。昇格や移送のあとは、`EXTERNAL_NAME`列を確かめる習慣をつけてください(実演の手順3の照会がそのまま使えます)。

`*LIBL`で記録された検証用の関数(`RUNSQL`で作ったもの。このレッスンのスクリプトの関数ではありません)には、もう1つ観察がありました。`db2`から`DROP SPECIFIC FUNCTION`したとき、削除は成功したのに`SQL7909`(SQLSTATE 01660「object not modified」)の警告が出ました。`RUNSQLSTM`(ライブラリーつきで記録される)で作ったものでは出ませんでした。`*LIBL`との関係は名前の付き方からの推測で、原因は切り分けていません。

### `LANGUAGE SQL`のルーチンと、できるオブジェクト

`LANGUAGE SQL`のルーチンは、Db2が内部でCのモジュールに変換し、コンパイルして、次のオブジェクトを作りました(実機の`RUNSQLSTM`の完了メッセージと`OBJECT_STATISTICS`で確認)。

| ルーチン | 型 | できるオブジェクト | 属性・テキスト |
|---|---|---|---|
| `JUCHU_INQUIRY_JSON`(`SPECIFIC JUCHUINQJS`) | 関数 | `*SRVPGM`の`JUCHUINQJS` | `CLE`・`SQL FUNCTION JUCHU_INQUIRY_JSON` |
| `LOW_STOCK`(`SPECIFIC LOWSTOCKT`) | 関数 | `*SRVPGM`の`LOWSTOCKT` | `CLE`・`SQL FUNCTION LOW_STOCK` |
| `LOW_STOCK_RS`(`SPECIFIC LOWSTOCKRS`) | プロシージャー | `*PGM`の`LOWSTOCKRS` | `CLE`・`SQL PROCEDURE LOW_STOCK_RS` |
| `JUCHU_REGISTER`(`SPECIFIC JUCHUREGST`) | プロシージャー | `*PGM`の`JUCHUREGST` | `CLE`・`SQL PROCEDURE JUCHU_REGISTER` |
| `GET_CUST_NAME`等3つ(`LANGUAGE RPGLE`) | 関数 | **なし**(カタログの`SYSROUTINES`に行ができるだけ) | |

実体の名前は、`SPECIFIC`名です。そこで、次の決まりがあります。

- **`SPECIFIC`名は、10文字以内の有効なシステム名にする。** IBM Docsによれば、`SPECIFIC`名が有効なシステム名で、**同じ名前のオブジェクトがまだ無い**ときに限り、それがシステム上のオブジェクト名になります。そうでなければ、システムがオブジェクト名を生成します。10文字を超える名前や、同名のオブジェクト(同じライブラリーに同じ名前の`*SRVPGM`・`*PGM`が残っている場合など)があると、実体の名前を予想できません(超えたときに切り詰められるのか生成名になるのか、同名のオブジェクトがあったときの実際の動作は、この教材では試していません。未検証(2026-09-29時点))。そのため、スクリプトのすべてのルーチンに、10文字以内の`SPECIFIC`名を付けています。
- **`CHKOBJ`で確かめられるのは、`LANGUAGE SQL`のルーチンだけ。** 前提は、上のとおり`SPECIFIC`名が実体の名前になっていることです(同名のオブジェクトが残っていれば、別のオブジェクトを見ているかもしれません)。関数なら`OBJTYPE(*SRVPGM)`、プロシージャーなら`OBJTYPE(*PGM)`で、`SPECIFIC`名を指定します。`LANGUAGE RPGLE`の登録(`GETCUSTNM`)は、`*SRVPGM`でも`*PGM`でも`CPF9801`(見つからない)になりました。`TXCHECK`(v1)は`CHKOBJ`による存在と型の確認だけをするので、RPGの外部関数の登録の有無は、`TXCHECK`では確かめられません(`SYSROUTINES`を照会します)。09-07の`TXCHECK`が`ORDER_SUMMARY_JSON`を`*SRVPGM`の`ORDSUMJSN`として確かめられたのは、これが`LANGUAGE SQL`の関数だからです。

### SQLパス: ルーチンの中の無修飾名は、作ったときのSQLパスで探す

`JUCHU_INQUIRY_JSON`は、得意先名を返したいところです。素直に考えると、登録したばかりの`GET_CUST_NAME`を、本体から呼ぶことになります(`TRIM(GET_CUST_NAME(M.JUTOK))`)。ところが、これは**作成できたのに、別のジョブから呼ぶと失敗しました**(`SQL0204`「GET_CUST_NAME in *LIBL not found」。`CPF503E`「User-defined function error」も一緒に出ました)。

考えられる理由は、ルーチンに**作成時のSQLパス(`SQL_PATH`)が保存される**ことです(推測を含みます。失敗したジョブのライブラリー・リストには開発ライブラリーが入っていたので、ライブラリー・リストではなく、保存されたSQLパスで探されていると考えると説明がつく、というところまでです)。09-07の検証で、`LANGUAGE SQL`のルーチン(`ORDER_SUMMARY_JSON`)に保存されていた`SQL_PATH`は`"QSYS","QSYS2","SYSPROC","SYSIBMADM","<自分のユーザー名>"`で、`<自分のユーザー名>1`のようなあなたの開発ライブラリーは入っていませんでした(最後は、ユーザー名と同じ名前のスキーマです)。このレッスンの7個のルーチンの`SQL_PATH`そのものは、記録していません(未検証(2026-09-29時点)。確かめるなら`QSYS2.SYSROUTINES`の`SQL_PATH`列を照会します)。別のジョブから呼ぶと、本体の無修飾の`GET_CUST_NAME`は、このパスの中から探されて見つからない、というのが考えられる筋書きです。

直し方は2つあります。

- 本体で、ライブラリーを付けて呼ぶ(`<自分のユーザー名>1.GET_CUST_NAME(...)`という形)。検証では、検証用の関数(`PRB_INQ_W`が、ライブラリーつきの`EXTERNAL NAME`で登録した別の関数`PRB_GC_Q`を、ライブラリーを付けて呼ぶ形)で動きました。このレッスンの`GET_CUST_NAME`を本体から修飾して呼ぶ形そのものは、試していません(未検証(2026-09-29時点))。また、これはライブラリー名を本体に埋め込むので、移送のときに問題になります。
- 関数を使わず、表を直接引く(サブセレクト)。このレッスンのスクリプトは、こちらです(`(SELECT TRIM(T.TOKNM) FROM TOKUIM T WHERE T.TOKCD = M.JUTOK)`)。これも`TOKUIM`は無修飾で書いていますが、実機では別のジョブから呼んでも動きました(検索パスにライブラリーが無いのに表が見つかった理由は、この教材では確かめていません。動いたことだけを確認しました。未検証(2026-09-29時点))。

`SET PATH`(SQLパスを文で設定する)を本体の前に置く方法も考えられますが、この教材では試していません(未検証(2026-09-29時点))。

### 命名: `db2`・`RUNSQL`・`RUNSQLSTM`で名前の書き方が違う

同じルーチンでも、実行する道具によって、名前の書き方に決まりがあります。実機で確かめた範囲は、次のとおりです。

| 道具 | 名前の書き方 | 観察 |
|---|---|---|
| `RUNSQLSTM ... NAMING(*SQL) DFTRDBCOL(ライブラリー)` | 無修飾でよい(`DFTRDBCOL`のライブラリーに作られる) | スクリプト全体を実行するのに使う |
| `db2`(SSHのSQLコマンド) | 名前を`ライブラリー.名前`で修飾する。**`SPECIFIC`名も修飾する**(`SPECIFIC ライブラリー.名前`)。無修飾だと、ジョブの既定のスキーマ(ユーザー名と同じ)になる | `CREATE ... 修飾名 ... SPECIFIC 無修飾名`は`SQL0455`(SQLSTATE 42882)で失敗した。`DROP SPECIFIC FUNCTION ライブラリー.名前`のように修飾する |
| `RUNSQL`(システム命名。既定) | `ライブラリー/表名`は使える。**`ライブラリー/関数名(...)`は除算と解釈されて**`SQL0206`になる | 関数・プロシージャーを呼ぶ`RUNSQL`は`NAMING(*SQL)`にして、`ライブラリー.関数名`と書く(検証はCLプログラムの中の`RUNSQL`) |

### JSONを`RUNSQL`の中で組み立てると、数値が文字列になる

`JSON_OBJECT`に**リテラルの数値**(`'unitPrice': 1580.00`のような、文の中に直接書いた数値)を渡す文を、`RUNSQL`(システム命名。検証ではCLプログラムの中、バッチ・ジョブ)の中で実行したところ、数値が文字列になり、小数点がコンマになりました。

```text
{"orderNo":"J09901","customer":"C00001","orderDate":"20260930","salesRep":"T00001","lines":[{"line":"1","product":"P00001","qty":"2","unitPrice":"1580,00"}, ...]}
```

`"qty":"2"`のように引用符が付き、`"unitPrice":"1580,00"`のように小数点がコンマになっています(PUB400のジョブの小数点はコンマですが、これが原因かどうかは分かりません)。**列の値から作ったJSON**(`JUCHU_INQUIRY_JSON`。`unitPrice`は`1580.00`のまま)では、数値のまま出ました。`db2`(CLI)では、整数のリテラルを`JSON_OBJECT`に渡した例(`{"ok":1}`。09-01・09-02)しか確かめていません。`1580.00`のような小数のリテラルを`JSON_OBJECT`に入れて`db2`で実行した結果と、`RUNSQLSTM`の中でリテラルの数値を`JSON_OBJECT`に渡した結果は、未検証(2026-09-29時点)です(`RUNSQLSTM`で確認したのは、列の値を使う本体を持つルーチンの作成だけ)。**原因は、この教材では突き止めていません。** 分かっているのは、`RUNSQL`での観察した事実だけです。

この現象は、受注登録で実害になりました(次の節)。対策は、**JSON文書を、1つのテキスト・リテラルとして渡す**ことです(手順10で、`db2`から渡す形は成功を確認しています。テキスト・リテラルの中の`1580.00`は、文字列のまま`JSON_TABLE`が読むので、`JSON_OBJECT`の問題とは別です)。

### 受注登録`JUCHU_REGISTER`: JSON1つ、`NESTED PATH`、二重登録の拒否

`JUCHU_REGISTER`は、JSON文書1つを受け取り、`JUCHUM`(ヘッダー1行)と`JUCHUD`(明細)に登録します(スクリプトの節5)。

1. 文書の`orderNo`を取り出す(`JSON_TABLE`)。
2. `JUCHUM`に同じ受注番号があれば、`SIGNAL SQLSTATE '75001'`(メッセージ「Order already exists」)で断る。
3. ヘッダーを`INSERT`する。
4. `NESTED PATH 'lax $.lines[*]'`で明細の配列を行にして、`JUCHUD`へ`INSERT`する。

`SET OPTION COMMIT = *NONE`が付いているのは、IBM Docsの実例の位置(`BEGIN`の直前)に従ったためです。付けなかった場合の動作は、試していません(未検証(2026-09-29時点))。

実機の結果は、次のとおりです。

- **正しい文書を、1つのテキスト・リテラルとして渡すと成功**しました(`db2`から。受注`J09901`・`J09902`)。
- **同じ受注番号で2回目を呼ぶと、`SQL0438`(SQLSTATE 75001)で断られ、明細は増えませんでした**(2行のまま)。
- **原子性のすき間**: 前の節の「文字列の`"1580,00"`」の文書を渡したとき(検証の記録は`JUCHU_REGISTER`への呼び出しとしています。ただし、結果のログだけからは、検証用の同型のプロシージャーを呼んだ可能性も排除できません)、明細の`INSERT`が`JUTNK`(単価)を`NULL`にしてしまい、`SQL0407`(`CPF5035`・`CPF5029`のデータ・マッピング・エラーつき)で失敗しました。ところが、ヘッダーの`INSERT`は先に済んでいて、`COMMIT(*NONE)`(コミット制御なし)のため、**ヘッダーだけが残りました**(`JUCHUM`が9行、`JUCHUD`が12行のまま)。残ったヘッダーを`JUCHU_INQUIRY_JSON`で読むと、`"lines":null`になります。トランザクションで囲まれていない`INSERT`は、途中で失敗しても取り消せないからです。
- 対策の考え方は、(1)入力を先に検証する(文書に問題があればヘッダーを書く前に断る)、(2)コミット制御を使って全部か無かにする、のどちらかです。(2)は、対象の表がジャーナルされていることなどが前提になり、この教材では試していません(未検証(2026-09-29時点))。ヘッダーだけが残ったときは、片付けと同じ`DELETE`で消します。

### 結果セットを返すプロシージャー

`LOW_STOCK_RS`は、カーソルを`WITH RETURN`で宣言し、`OPEN`したまま(`CLOSE`せずに)終わります。開いたままのカーソルが、呼び出し元への「結果セット」になります。

```sql
CREATE OR REPLACE PROCEDURE LOW_STOCK_RS ()
  LANGUAGE SQL
  SPECIFIC LOWSTOCKRS
  DYNAMIC RESULT SETS 1
  READS SQL DATA
BEGIN
  DECLARE C1 CURSOR WITH RETURN FOR
    SELECT S.SHOCD, S.SHONM, Z.ZASU, S.SHOHAT
      FROM SHOHIM S
      JOIN ZAIKOM Z ON Z.ZASHO = S.SHOCD
     WHERE Z.ZASU < S.SHOHAT
     ORDER BY S.SHOCD;
  OPEN C1;
END;
```

`db2`(SSHのSQLコマンド)から`CALL`すると、まず`SQLSTATE 0100C`(警告。「1 result sets are available from procedure LOW_STOCK_RS」)が出て、そのあとに2行が表示されました。**ACSの「実行SQLスクリプト」での表示は、未検証(V3、2026-09-29時点)です。** IBM Docsは、結果セットを扱えるインターフェースとして、SQL PL・埋め込みSQL・JDBC・CLI・ODBCを挙げています。`STRSQL`には触れていません。`STRSQL`で結果セットが見えるかどうかは、IBM Docsに記載がなく、実機でも試していません(未検証(2026-09-29時点))。

### 順序: 先に全部`CREATE`、それから呼ぶ

外部ルーチン(`JUCSRV`・`ZAISRV`を指すもの)の`CREATE`・`ALTER`・`DROP`では、Db2は`*SRVPGM`に登録情報を書き込もうとします。IBM Docsによれば、そのためには対象のプログラムに**排他ロック**が取れる必要があり、取れないと`SQL7909`が出ます(IBM Docs『Db2 for i SQLプログラミング』の外部ルーチンの説明。実機未確認)。ここまでが、IBM Docsに書かれていることです。ここから先は推測です。関数を呼ぶと、`JUCSRV`がそのジョブで使用中(活動化)になり、そのジョブが続けて`CREATE`・`DROP`をすると排他ロックが取れなくなるのではないか、と考えられます(この「呼ぶと活動化される」という結びつきは、実機で確かめていません。未検証(2026-09-29時点))。そこで、このレッスンでは次の順序を守ります。**まずスクリプト全体を`CREATE`し、そのあとで呼び出します。** 検証もこの順序で行い、`SQL7909`は`CREATE`では出ませんでした。排他ロックが原因で失敗する場面そのものは、再現していません(IBM Docsの記載に基づく注意です。未検証(2026-09-29時点))。

また、`JUCSRV`・`ZAISRV`を第8部のビルド(08-01・08-02)で作り直すと、`*SRVPGM`の中の登録情報が失われる可能性があります(IBM Docsの記載からの推測です)。**このレッスンは、第8部の作り直しが終わった後に行い、その後で作り直したら`CREATE`をやり直してください。** 失われるかどうかは確かめていません(未検証(2026-09-29時点))。`CREATE OR REPLACE`を、すでに関数を呼んだジョブから再実行してよいかは、確かめていません(未検証(2026-09-29時点)。検証では、すべての`CREATE`が最初の呼び出しより前でした)。やり直すときは、まだ関数を呼んでいない新しいジョブ(新しいSSH接続)から実行し、5250で関数を呼んだ場合は、先にそのセッションをサインオフしてください。

### 読解用の囲み: RPGで表関数や結果セットのルーチンを書くなら

このレッスンは、表関数と結果セットのプロシージャーを`LANGUAGE SQL`で作りました。RPGで書く場合の要点だけ挙げます(**手を動かしません。新出に数えません**)。

- 表関数は`LANGUAGE SQL`で作るのが素直です。RPGなど外部言語で書く場合の正規の形は`PARAMETER STYLE DB2SQL`で、呼び出しの種類(`OPEN`・`FETCH`・`CLOSE`)を引数で受け取って処理を分け、終了時に`SQLSTATE '02000'`を返します(IBM Docsの`LANGUAGE C`の実例による。実機未確認)。
- `GENERAL WITH NULLS`はスカラー関数専用と、IBM Docsに明記されています(実機未確認)。この教材の3つの`GENERAL`の登録はスカラー関数と単純な手続きで、実際に動きました。
- RPGで結果セットを返す場合は、埋め込みSQLで`WITH RETURN TO CLIENT`のカーソルを宣言します(IBM Docsに実例があります。この教材では実行していません)。

## 実演

**警告(共有データ)**: 手順10〜12と演習(b)は、あなたの`JUCHUM`・`JUCHUD`に、受注番号`J09901`〜`J09903`の行を書き込みます。この2つの表は09-07も読みます。`J09901`の受注日は`20260930`で、`J00008`(`20260912`)より新しいので、行が残ったままだと、09-07の`ORDER_SUMMARY_JSON`の期待値(最新の受注が`J00008`・`J00007`)が変わります。途中でやめた場合も、片付けの手順1は必ず実行してください。表を初期状態に戻す`TXRESET`の、第9部での扱いは未検証(2026-09-29時点)です([第9部の扉](index.md)参照)。

前提: `<自分のユーザー名>1`に`JUCSRV`・`ZAISRV`・`JUCHUM`・`JUCHUD`・`ZAIKOM`・`TOKUIM`・`SHOHIM`があること(第8部の作り直し後)。SSHの`$HOME/ibmi-kyozai`が最新であること(`git pull`)。`(SSH)`はSSH、`(5250)`は5250の操作です。(SSH)の手順は、SSH接続後に`qsh`を入力して、qshの中で実行します(`db2`はqshのコマンドです)。**呼び出しの道具を使い分けます。** `LANGUAGE RPGLE`の関数を呼ぶ`RUNSQL`と`CHKOBJ`は、検証では、CLプログラムの中からバッチ・ジョブ(SSHで起動)で実行しました。5250の対話式ジョブで同じコマンドを打つ形は、実機では確かめていません(未検証(2026-09-29時点)。対話式ジョブのライブラリー・リストや`CPD000D`の出方も含みます)。`db2`や、ACSでの呼び出しも、実機では確かめていません(未検証(2026-09-29時点))。`LANGUAGE SQL`のルーチンは、`db2`で確かめた形で呼びます。

1. **(SSH) 最初の件数を控えます。**

   ```sh
   db2 "SELECT (SELECT COUNT(*) FROM <自分のユーザー名>1.JUCHUM) AS M, (SELECT COUNT(*) FROM <自分のユーザー名>1.JUCHUD) AS D, (SELECT COUNT(*) FROM <自分のユーザー名>1.ZAIKOM) AS Z FROM SYSIBM.SYSDUMMY1"
   ```

   期待される結果(検証したときの状態。この状態が`TXRESET`直後の状態と同じかどうかは、未検証(2026-09-29時点)です):

   ```text
   M           D           Z
   ----------- ----------- -----------
             8          12           6
   ```

   ここが`8`・`12`・`6`でなければ、片付けのあとの件数と比べるための基準として、自分の値を控えてください。

2. **(SSH) スクリプト全体で、7個のルーチンを作ります。** 先に全部作ります(「順序」の節)。

   ```sh
   system "RUNSQLSTM SRCSTMF('$HOME/ibmi-kyozai/src/sql/09-04-routines.sql') COMMIT(*NONE) NAMING(*SQL) DFTRDBCOL(<自分のユーザー名>1) ERRLVL(40) OUTPUT(*PRINT)"
   ```

   期待されるメッセージ(検証のバッチの結果。日時などは変わります。`JUCSRV`の代わりに複製の`JUCSRVU`を指した検証でした。「実機メモ」参照):

   ```text
   CPC5D0B: Service program JUCHUINQJS created in library <自分のユーザー名>1.
   CPC5D0B: Service program LOWSTOCKT created in library <自分のユーザー名>1.
   CPC5D07: Program LOWSTOCKRS created in library <自分のユーザー名>1.
   CPC5D07: Program JUCHUREGST created in library <自分のユーザー名>1.
   ```

   `RUNSQLSTM`の実行リスト(スプール・ファイル)には、7個のルーチンそれぞれの`SQL7997`(Function ... was created)・`SQL7989`(Procedure ... was created)が出ます。途中の`CZS0607`(`QTEMP`にモジュールができた)と`CPC2191`(そのモジュールを削除した)は、内部の作業です。

   - ファイルの文字コードは、09-02と同じ注意があります。検証は、CCSID 273のタグのファイルで成功しました(UTF-8の1208のタグでは`SQL0330`)。検証に使ったのは、検証用の道具が置いたファイルの複製と、qshのヒアドキュメントで書いたファイル(273のタグ)です。`git clone`したファイルや、手で書いたファイルのタグは確認していません(未検証(2026-09-29時点))。`SQL0330`が出たら、09-02の「出会うメッセージ ID」を見てください。09-02の対処(`iconv`で変換せず、元のファイルで実行する)でも直らないとき(タグが1208や無指定のとき)の、確かめ済みの逃げ道はありません。試せる代替は、`db2`で1文ずつ、名前を修飾して実行することです(未検証(2026-09-29時点))。
   - `EXTERNAL NAME`にライブラリーを書いた形は、作成でき、呼び出せることを確認しています(検証用の関数)。ただし、ライブラリーを書かずに`CREATE`して`JUCSRV`が「見つからない」と失敗した例は、検証では出ていません。そのときのメッセージと、ライブラリーを書く直し方が本物の`JUCSRV`で効くかどうかは、未検証(2026-09-29時点)です。

3. **(SSH) カタログで、登録の中身を見ます。**

   ```sh
   db2 "SELECT ROUTINE_NAME, SPECIFIC_NAME, ROUTINE_TYPE, EXTERNAL_NAME, EXTERNAL_LANGUAGE, PARAMETER_STYLE FROM QSYS2.SYSROUTINES WHERE ROUTINE_SCHEMA = '<自分のユーザー名>1' ORDER BY ROUTINE_NAME" 2>&1
   ```

   期待される結果(検証。`ライブラリー`は開発ライブラリーの名前。`JUCSRVU`は、検証で使った`JUCSRV`の複製。あなたの環境では`JUCSRV`・`ZAISRV`のはずです):

   | ROUTINE_NAME | SPECIFIC_NAME | ROUTINE_TYPE | EXTERNAL_NAME | EXTERNAL_LANGUAGE | PARAMETER_STYLE |
   |---|---|---|---|---|---|
   | COUNT_CUST_ORDERS | CNTCUSTORD | FUNCTION | ライブラリー/JUCSRVU(countCustOrders) | RPGLE | GENERAL |
   | GET_CUST_NAME | GETCUSTNM | FUNCTION | ライブラリー/JUCSRVU(getCustName) | RPGLE | GENERAL |
   | GET_STOCK_QTY | GETSTOCKQT | FUNCTION | ライブラリー/ZAISRVU(GET) | RPGLE | GENERAL |
   | JUCHU_INQUIRY_JSON | JUCHUINQJS | FUNCTION | ライブラリー/JUCHUINQJS(JUCHU_INQUIRY_JSON_1) | (空) | (空) |
   | JUCHU_REGISTER | JUCHUREGST | PROCEDURE | ライブラリー/JUCHUREGST | (空) | (空) |
   | LOW_STOCK | LOWSTOCKT | FUNCTION | ライブラリー/LOWSTOCKT(LOW_STOCK_1) | (空) | (空) |
   | LOW_STOCK_RS | LOWSTOCKRS | PROCEDURE | ライブラリー/LOWSTOCKRS | (空) | (空) |

   ここで見るべきものは、(1)無修飾で書いた`EXTERNAL NAME`に、作成時のライブラリーが付いていること、(2)`LANGUAGE SQL`のルーチンは、`EXTERNAL_LANGUAGE`・`PARAMETER_STYLE`が空であることです。この照会の列名の指定は、検証の照会と同じですが、`ROUTINE_SCHEMA`の値は検証では開発ライブラリー名でした。

4. **(5250) 実体のオブジェクトを`CHKOBJ`で確かめます。** `SPECIFIC`名で指定します(検証は、CLプログラムの中の`CHKOBJ`でした。5250の対話式ジョブでの実行は未検証(2026-09-29時点)です)。

   ```text
   CHKOBJ OBJ(<自分のユーザー名>1/JUCHUINQJS) OBJTYPE(*SRVPGM)
   CHKOBJ OBJ(<自分のユーザー名>1/LOWSTOCKT) OBJTYPE(*SRVPGM)
   CHKOBJ OBJ(<自分のユーザー名>1/LOWSTOCKRS) OBJTYPE(*PGM)
   CHKOBJ OBJ(<自分のユーザー名>1/JUCHUREGST) OBJTYPE(*PGM)
   ```

   期待される結果: 4つとも、エラーなく終わります(検証のバッチで、失敗の行が出なかったことを確認しました。5250の画面に出る完了メッセージは、確認していません)。続けて、次の2つを実行します。

   ```text
   CHKOBJ OBJ(<自分のユーザー名>1/GETCUSTNM) OBJTYPE(*SRVPGM)
   CHKOBJ OBJ(<自分のユーザー名>1/GETCUSTNM) OBJTYPE(*PGM)
   ```

   期待される結果: `CPF9801`(Object GETCUSTNM in library ... not found)です。`LANGUAGE RPGLE`の登録は、実体のオブジェクトを作らないからです。

   属性とテキストは、SSHで次のようにも見られます(検証の照会に、`OBJNAME`の絞り込みだけ足した形。この形そのものは未実行です。未検証(2026-09-29時点))。

   ```sh
   db2 "SELECT OBJNAME, OBJTYPE, OBJATTRIBUTE, OBJTEXT FROM TABLE(QSYS2.OBJECT_STATISTICS('<自分のユーザー名>1', '*ALL')) X WHERE OBJNAME IN ('JUCHUINQJS', 'LOWSTOCKT', 'LOWSTOCKRS', 'JUCHUREGST') ORDER BY OBJTYPE, OBJNAME" 2>&1
   ```

   期待される行(検証の一覧から): `JUCHUREGST *PGM CLE SQL PROCEDURE JUCHU_REGISTER`、`LOWSTOCKRS *PGM CLE SQL PROCEDURE LOW_STOCK_RS`、`JUCHUINQJS *SRVPGM CLE SQL FUNCTION JUCHU_INQUIRY_JSON`、`LOWSTOCKT *SRVPGM CLE SQL FUNCTION LOW_STOCK`。

5. **(5250) `LANGUAGE RPGLE`の関数を呼びます。** 結果を入れる作業表を作ってから、6回、呼びます(`RUNSQL`は結果を表示できないので、表に入れます)。検証は、開発ライブラリーを現行ライブラリーにした(`CHGCURLIB`)バッチ・ジョブでした。5250の対話式ジョブで、開発ライブラリーがライブラリー・リストにも現行ライブラリーにも無い場合の動作は、未検証(2026-09-29時点)です。うまくいかないときは、`EXTERNAL NAME`にライブラリーを書く形に作り直してください(ライブラリーを書いた形は、確認済みです)。

   まず、作業表を作ります。表の作成は、システム命名(`ライブラリー/表名`)で書きます。

   ```text
   RUNSQL SQL('CREATE OR REPLACE TABLE <自分のユーザー名>1/W0904A (SEQ INT GENERATED ALWAYS AS IDENTITY, TAG VARCHAR(40), VAL VARCHAR(1000))') COMMIT(*NONE)
   ```

   次に、呼び出す文です。関数を呼ぶ`RUNSQL`は、`NAMING(*SQL)`にして、`ライブラリー.関数名`と書きます。

   ```text
   RUNSQL SQL('INSERT INTO <自分のユーザー名>1.W0904A (TAG, VAL) SELECT ''GC-C00001'', ''<'' || CAST(<自分のユーザー名>1.GET_CUST_NAME(''C00001'') AS VARCHAR(60)) || ''>'' FROM SYSIBM.SYSDUMMY1') COMMIT(*NONE) NAMING(*SQL)
   RUNSQL SQL('INSERT INTO <自分のユーザー名>1.W0904A (TAG, VAL) SELECT ''GC-NOTFOUND'', ''<'' || CAST(<自分のユーザー名>1.GET_CUST_NAME(''ZZZZZZ'') AS VARCHAR(60)) || ''>'' FROM SYSIBM.SYSDUMMY1') COMMIT(*NONE) NAMING(*SQL)
   RUNSQL SQL('INSERT INTO <自分のユーザー名>1.W0904A (TAG, VAL) SELECT ''GC-NULLARG'', COALESCE(CAST(<自分のユーザー名>1.GET_CUST_NAME(CAST(NULL AS CHAR(6))) AS VARCHAR(60)), ''SQLNULL'') FROM SYSIBM.SYSDUMMY1') COMMIT(*NONE) NAMING(*SQL)
   RUNSQL SQL('INSERT INTO <自分のユーザー名>1.W0904A (TAG, VAL) SELECT ''CC-C00001'', ''<'' || CAST(<自分のユーザー名>1.COUNT_CUST_ORDERS(''C00001'') AS VARCHAR(20)) || ''>'' FROM SYSIBM.SYSDUMMY1') COMMIT(*NONE) NAMING(*SQL)
   RUNSQL SQL('INSERT INTO <自分のユーザー名>1.W0904A (TAG, VAL) SELECT ''ZG-P00002'', ''<'' || CAST(<自分のユーザー名>1.GET_STOCK_QTY(''P00002'') AS VARCHAR(20)) || ''>'' FROM SYSIBM.SYSDUMMY1') COMMIT(*NONE) NAMING(*SQL)
   RUNSQL SQL('INSERT INTO <自分のユーザー名>1.W0904A (TAG, VAL) SELECT ''ZG-NOTFOUND'', ''<'' || CAST(<自分のユーザー名>1.GET_STOCK_QTY(''P99999'') AS VARCHAR(20)) || ''>'' FROM SYSIBM.SYSDUMMY1') COMMIT(*NONE) NAMING(*SQL)
   ```

   期待される結果: コマンドはエラーなく終わります。ジョブ・ログに、`SQL7905`(表が未ジャーナルの警告。作業表の作成で出ます)と`CPD000D`(「Command RUNSQL not safe for a multithreaded job」。診断メッセージで、処理は続きます。検証では、`NOT FENCED`の外部関数を呼んだバッチ・ジョブで、その後の`RUNSQL`に出ました)が出ることがあります。

6. **(SSH) 作業表を読みます。**

   ```sh
   db2 "SELECT SEQ, TAG, VAL FROM <自分のユーザー名>1.W0904A ORDER BY SEQ"
   ```

   期待される結果(検証の値。`CHAR(30)`の戻り値は、右側が空白で30桁まで埋まります。ここでは`>`の手前の空白で示しています):

   ```text
   SEQ TAG          VAL
   --- ------------ ----------------------------------
     1 GC-C00001    <ACME TRADING CO               >
     2 GC-NOTFOUND  <NOTFOUND                      >
     3 GC-NULLARG   SQLNULL
     4 CC-C00001    <2>
     5 ZG-P00002    <3>
     6 ZG-NOTFOUND  <-1>
   ```

   見るべきものは、(1)存在する得意先は名前、存在しない得意先は`NOTFOUND`(`JUCSRV`が返す約束の値)、(2)`NULL`引数は`NULL`(`RETURNS NULL ON NULL INPUT`の効果。手続きが呼ばれず、`SQLNULL`に置き換わった)、(3)`COUNT_CUST_ORDERS('C00001')`は`2`、(4)`GET_STOCK_QTY`は在庫数、存在しない商品は`-1`です。出力の桁の幅や空白の数は、あなたの`db2`の表示で変わることがあります。

7. **(SSH) 表関数`LOW_STOCK`を呼びます。**

   ```sh
   db2 "SELECT * FROM TABLE(<自分のユーザー名>1.LOW_STOCK()) X ORDER BY 1"
   ```

   期待される結果(検証):

   ```text
   PRODUCT_CODE PRODUCT_NAME    STOCK_QTY  REORDER_POINT
   ------------ --------------- ---------- -------------
   P00002       OFFICE CHAIR            3             5
   P00005       USB CABLE              12            50
   ```

   発注点(`REORDER_POINT`)より在庫(`STOCK_QTY`)が少ない商品だけが出ます。`PRODUCT_NAME`は`CHAR(30)`なので、実際は右側が空白で埋まっています。

8. **(SSH) 結果セットを返すプロシージャー`LOW_STOCK_RS`を呼びます。**

   ```sh
   db2 "CALL <自分のユーザー名>1.LOW_STOCK_RS()"
   ```

   期待される結果(検証):

   ```text
    **** CLI ERROR *****
    SQLSTATE: 0100C
   NATIVE ERROR CODE: 466
   1 result sets are available from procedure LOW_STOCK_RS in ライブラリー.
   SHOCD SHONM ZASU SHOHAT
   ...(P00002・P00005の2行。手順7と同じ値)
   ```

   `CLI ERROR`と出ていますが、エラーではなく警告(`0100C`)で、そのあとに結果セットの行が表示されます。**ACSの「実行SQLスクリプト」での見え方は、未検証(V3)です。** ACSで試す場合は、`CALL LOW_STOCK_RS()`を1文だけ実行してください。

9. **(SSH) スカラー関数`JUCHU_INQUIRY_JSON`で、受注1件をJSONにします。**

   ```sh
   db2 "SELECT <自分のユーザー名>1.JUCHU_INQUIRY_JSON('J00001') FROM SYSIBM.SYSDUMMY1"
   ```

   期待される結果(検証):

   ```text
   {"orderNo":"J00001","customer":"C00001","customerName":"ACME TRADING CO","orderDate":20260901,"salesRep":"T00001","lines":[{"line":1,"product":"P00001","qty":2,"unitPrice":1580.00},{"line":2,"product":"P00003","qty":5,"unitPrice":480.00}]}
   ```

   見るべきものは、`unitPrice`が`1580.00`のまま(引用符も、コンマもない)こと、`lines`が本物の配列であること、`customerName`が付いていることです。

10. **(SSH) 受注を登録します(1回目)。** JSON文書を、**1つのテキスト・リテラル**として渡します。SSHのシェルの二重引用符の中なので、JSONの`"`を`\"`と書きます。

    ```sh
    db2 "CALL <自分のユーザー名>1.JUCHU_REGISTER('{\"orderNo\":\"J09901\",\"customer\":\"C00001\",\"orderDate\":20260930,\"salesRep\":\"T00001\",\"lines\":[{\"line\":1,\"product\":\"P00001\",\"qty\":2,\"unitPrice\":1580.00},{\"line\":2,\"product\":\"P00003\",\"qty\":5,\"unitPrice\":480.00}]}')"
    db2 "SELECT JUNO, JUTOK, JUDATE, JUTAN FROM <自分のユーザー名>1.JUCHUM WHERE JUNO = 'J09901'"
    db2 "SELECT JUNO, JULINE, JUSHO, JUSU, JUTNK FROM <自分のユーザー名>1.JUCHUD WHERE JUNO = 'J09901' ORDER BY JULINE"
    ```

    期待される結果(検証):

    ```text
    DB20000I  THE SQL COMMAND COMPLETED SUCCESSFULLY.

    JUNO   JUTOK  JUDATE     JUTAN
    ------ ------ ---------- ------
    J09901 C00001  20260930  T00001

    JUNO   JULINE  JUSHO  JUSU    JUTNK
    ------ ------- ------ ------- ---------
    J09901    1    P00001      2    1580.00
    J09901    2    P00003      5     480.00
    ```

11. **(SSH) 登録した受注を、JSONで読み戻します(往復)。**

    ```sh
    db2 "SELECT <自分のユーザー名>1.JUCHU_INQUIRY_JSON('J09901') FROM SYSIBM.SYSDUMMY1"
    ```

    期待される結果(検証):

    ```text
    {"orderNo":"J09901","customer":"C00001","customerName":"ACME TRADING CO","orderDate":20260930,"salesRep":"T00001","lines":[{"line":1,"product":"P00001","qty":2,"unitPrice":1580.00},{"line":2,"product":"P00003","qty":5,"unitPrice":480.00}]}
    ```

    入力した文書に、`customerName`が加わった形で戻りました。

12. **(SSH) 同じ受注番号を、もう一度登録します(二重登録)。** 手順10の`CALL`を、もう一度そのまま実行し、明細の行数を数えます。

    ```sh
    db2 "SELECT COUNT(*) AS N FROM <自分のユーザー名>1.JUCHUD WHERE JUNO = 'J09901'"
    ```

    期待される結果(検証。`CALL`のほうは`SQLSTATE 75001`で断られます):

    ```text
     **** CLI ERROR *****
     SQLSTATE: 75001
    NATIVE ERROR CODE: -438
    Message Order already exists returned from SIGNAL, RESIGNAL, or RAISE_ERROR.

    N
    -----------
              2
    ```

    明細が2行のままなのが、拒否が効いている証拠です。

13. **(5250、任意) 数値が文字列になる現象を見ます。** 検証で観察した文です(検証はCLプログラムの中の`RUNSQL`でした。5250の対話式ジョブでの実行は未検証(2026-09-29時点))。実行しても、`JUCHUM`・`JUCHUD`は変わりません(作業表に入れるだけです)。

    ```text
    RUNSQL SQL('INSERT INTO <自分のユーザー名>1/W0904A (TAG, VAL) SELECT ''JSON-BUILT-J09901'', CAST(JSON_OBJECT(''orderNo'': ''J09901'', ''customer'': ''C00001'', ''orderDate'': 20260930, ''salesRep'': ''T00001'', ''lines'': JSON_ARRAY(JSON_OBJECT(''line'': 1, ''product'': ''P00001'', ''qty'': 2, ''unitPrice'': 1580.00), JSON_OBJECT(''line'': 2, ''product'': ''P00003'', ''qty'': 5, ''unitPrice'': 480.00)) FORMAT JSON) AS VARCHAR(4000) CCSID 1208) FROM SYSIBM.SYSDUMMY1') COMMIT(*NONE)
    ```

    `db2`で`W0904A`の最後の行を読むと、検証では次のとおりでした(数値が文字列、小数点がコンマ)。この文書を`JUCHU_REGISTER`に渡してはいけません(演習(b)にも、同じ注意を書いています。検証で、この形の文書が`SQL0407`とヘッダーだけの残りになりました。上の「原子性のすき間」参照)。

    ```text
    {"orderNo":"J09901","customer":"C00001","orderDate":"20260930","salesRep":"T00001","lines":[{"line":"1","product":"P00001","qty":"2","unitPrice":"1580,00"},{"line":"2","product":"P00003","qty":"5","unitPrice":"480,00"}]}
    ```

## 出会うメッセージ ID

| ID | 原因 | 対処 |
|---|---|---|
| `SQL7997`・`SQL7989` | `RUNSQLSTM`の実行リストで、関数(7997)・プロシージャー(7989)が作られたという情報 | 何もしない |
| `CPC5D0B`・`CPC5D07` | `LANGUAGE SQL`の関数から`*SRVPGM`(5D0B)・プロシージャーから`*PGM`(5D07)ができた | 何もしない。ここで出た名前が`SPECIFIC`名 |
| `CZS0607`・`CPC2191` | 内部の作業モジュールが`QTEMP`にできた・削除された | 何もしない |
| `SQL7905`(重大度20) | 作業表などが未ジャーナルで作られた警告 | `ERRLVL(40)`で後続の文は動く(09-02のとおり)。作業表では無視してよい |
| `CPF426A` + `SQL0204`「JUCSRV in ライブラリー type *SRVPGM not found」 | `EXTERNAL NAME`の括弧の中の綴りが、エクスポート名と大文字小文字まで一致していない(実機で、`GETCUSTNAME`・`get`で発生) | `DSPSRVPGM`でエクスポート名を見て、綴りを直す。`CREATE`は成功するので、作成時には気づけない |
| `SQL0204`「GET_CUST_NAME in *LIBL not found」(`CPF503E`も一緒に出る) | ルーチンの本体の無修飾の名前が、保存されたSQLパスの中に無いためと考えられる(推測) | 本体でライブラリーを付けて呼ぶか、表を直接引く |
| `SQL0455`(SQLSTATE 42882、「Schema ... for specific name not same as routine schema」) | `db2`で、ルーチン名は修飾したのに`SPECIFIC`名を修飾しなかった | `SPECIFIC ライブラリー.名前`と修飾する(`DROP SPECIFIC`も同様) |
| `SQL0206`「Column or global variable ... not found」 | `RUNSQL`(システム命名)で`ライブラリー/関数名(...)`と書いた。除算と解釈された | `NAMING(*SQL)`にして`ライブラリー.関数名`と書く |
| `SQL0407` + `CPF5035`・`CPF5029`(Data mapping error on member JUCHUD) | `JUCHU_REGISTER`の明細の`INSERT`で(検証の記録による)、`JUTNK`が`NULL`になった(文字列`"1580,00"`が数値として読めなかった) | JSONを1つのテキスト・リテラルで渡す。ヘッダーだけが残っていれば`DELETE`で消す |
| `SQL0438`(SQLSTATE 75001) | `JUCHU_REGISTER`が、`SIGNAL`で二重登録を断った(「Order already exists」) | 想定どおり。別の受注番号にする |
| SQLSTATE `0100C`(NATIVE ERROR 466) | `db2`で結果セットを返すプロシージャーを`CALL`した。1つ結果セットがある、という警告 | エラーではない。続く行を読む |
| SQLSTATE `02000`(NATIVE ERROR 100、「Row not found for DELETE」) | `db2`の`DELETE`が0行に当たった(片付けで、すでに消えていた) | 想定どおり |
| `SQL7909`(SQLSTATE 01660、「object not modified」) | `DROP SPECIFIC FUNCTION`で、削除は成功したが、対象の`*SRVPGM`は変更できなかった(実機では、`RUNSQL`で作った検証用の関数の削除で観察。その関数は`*LIBL/...`で記録されていましたが、`*LIBL`が原因かどうかは推測) | 警告。ルーチンが消えているか、`SYSROUTINES`で確かめる。原因は切り分けていない |
| `CPD000D`「Command RUNSQL not safe for a multithreaded job」 | `NOT FENCED`の外部関数を呼んだジョブで、続く`RUNSQL`等のCLコマンドに出る診断メッセージ | 処理は続いた。無視してよい |
| `CPF9801`(`CHKOBJ`) | 指定した名前・型のオブジェクトが無い | `LANGUAGE RPGLE`の登録は、実体を作らないので想定どおり |
| `SQL0084` | `RUNSQLSTM`で`SELECT`単独文を実行した(09-02) | ACSか`db2`で実行する。このレッスンのスクリプトは、`SELECT`を実行しない(「試す」の行は、コメント) |
| `SQL0330` | `.sql`を`iconv`でUTF-8(1208)に変換して`RUNSQLSTM`に渡した(09-02) | 変換せず、元のファイルで実行する |

`SQL0104`(構文エラー)にも注意してください。SQLの数値の並びは、コンマの直後に空白を入れます(`SUBSTR(x, 1, 200)`。[スタイル・ガイド](../style-guide.md)。PUB400は小数点がコンマのため、`1,200`が1つの数値と読まれます)。このレッスンのスクリプトは、この規則を守っています。メッセージ全般は[付録B](../appendix/b-message-ids.md)も参照してください(このレッスンの`SQL0455`・`SQL0438`等は、付録Bにはまだ載っていません)。

## 出力が違うとき

- **手順2で`RUNSQLSTM`が`SQL0330`になる**: 上の表のとおり、文字コードのタグの問題です。09-02の手順に従ってください。
- **手順5の`RUNSQL`が`SQL0204`(見つからない)になる**: 関数の名前を、ライブラリーで修飾していない(`ライブラリー.GET_CUST_NAME`と書く)か、`JUCSRV`の綴りが違います(`CPF426A`が一緒に出れば綴りです)。
- **手順5・6で`GC-C00001`の名前が`NOTFOUND`になる**: `TXRESET`をしていない、または`TOKUIM`に`C00001`がありません。手順1の件数と、`SELECT TOKCD FROM <自分のユーザー名>1.TOKUIM`で確かめてください。
- **手順7の行が2行と違う**: `ZAIKOM`の在庫が、検証したときの値と違います。考えられる原因は、ほかのレッスンで在庫を書き換えたことです(未検証)。`TXSTATUS`で確かめ、必要なら`TXRESET`を使ってください(第9部での戻し方は未検証(2026-09-29時点)です)。
- **手順8で、行が出ない**: `db2`の表示は、警告(`0100C`)のあとに行を出します。警告だけで終わったなら、実行したのが`db2`ではなく、結果セットを表示しない別の道具ではないか確かめてください(`STRSQL`で結果セットが見えるかどうかは、IBM Docsに記載がなく、未検証です)。
- **手順10で`SQL0407`になる**: 文書を、`JSON_OBJECT`で組み立てていませんか。1つのテキスト・リテラルで渡してください。失敗したあと、`J09901`のヘッダーが残っています。手順10を再実行する前に、片付けの`DELETE`(`J09901`)を先に実行してください。なお、`JUCHU_REGISTER`の呼び出しを、`RUNSQL`の中でJSON_OBJECTを使って組み立てるのは避けてください(手順13のとおり)。
- **手順12で`CALL`が成功して、明細が4行になった**: 作った`JUCHU_REGISTER`が、スクリプトの版と違い、受注番号の確認が入っていない可能性があります(この状況は、実機では起きていません。未検証)。スクリプトを、新しいジョブ(新しいSSH接続。5250で関数を呼んだ場合は、そのセッションをサインオフしてから)で、もう一度実行してください。関数を呼んだあとのジョブから再実行できるかは、未検証(2026-09-29時点)です。
- **ACSでの結果が違う**: このレッスンの期待値は、`db2`・`RUNSQL`・`RUNSQLSTM`で確認したものです。ACSでの表示形式(桁区切り、引用符の扱い、`0100C`の警告の見え方)は、未検証(V3、2026-09-29時点)です。

## 演習

演習は、ふつうの実行を確かめる問題(a)と(b)、紙の上の問題(c)です。スタイル・ガイドの4段階(例題を読む→修正・穴埋め→独力→応用)との対応は、次のとおりです。例題は実演の手順そのもの、(a)の1・2が「修正」(手順5・7の形で商品を変える)、(a)の3と(b)が「独力・応用」、(c)が紙の上の確認です。穴埋め形式の問題は設けていません。同じように、テンプレート上の「同じ手順を別の対象で」の節は、(a)・(b)が代わりになるので、意図的に省略しています。(a)・(b)の答えは、手順の値から導かれるものと、この教材で実行していないものに分かれます。答えの中で、そのつど区別しています。(a)の3の模範のスクリプトは、実機で実行していないので、未検証のファイル(`solutions/09-04/lowstockb.sql`)として置いています。

### 演習(a): 在庫照会をほかの商品・条件で

1. `LOW_STOCK`の結果を、商品`P00005`だけに絞って表示する`SELECT`を書いて実行してください。
2. `P00005`の在庫数を、`GET_STOCK_QTY`で直接引いて、1と同じ数になることを確かめてください(`RUNSQL`で、手順5と同じ形)。
3. (応用)発注点ではなく、引数で指定した在庫数**未満**の商品を返す表関数`LOW_STOCK_BELOW`を作ってください。`SPECIFIC`名は`LOWSTOCKB`です。

<details><summary>答え</summary>

1. `LOW_STOCK`は表関数なので、通常の表と同じように`WHERE`で絞れます(手順7の形の`WHERE`つきです。この文そのものは、実機では実行していません。未検証(2026-09-29時点))。文は`solutions/09-04/README.txt`にあります。期待される結果は、手順7の`P00005`の1行(`USB CABLE`、在庫12、発注点50)です。
2. 手順5の5行目の`GET_STOCK_QTY(''P00002'')`を`''P00005''`に変えます。期待される値は`12`です(手順7の`P00005`の在庫。`GET_STOCK_QTY('P00005')`の実行そのものは未実施。未検証(2026-09-29時点))。`GET_STOCK_QTY('P00002')`は`3`(実機確認済み)です。
3. 模範は`solutions/09-04/lowstockb.sql`です(**実機では実行していません。未検証(2026-09-29時点)**)。`RETURNS TABLE`の型は、`LOW_STOCK`と揃えています。`RUNSQLSTM`で作るときは、手順2と同じコマンドの`SRCSTMF`を、自分のファイルに変えます。

   自分で書くときのファイル: 名前は`$HOME/lowstockb.sql`とします。作り方は、検証で273のタグで動いた形(qshのヒアドキュメント)に合わせて、SSHで`cat > $HOME/lowstockb.sql <<'EOF'`と入力し、文を貼って`EOF`で終えます(この書き方そのもの、および出来上がったファイルのタグは、未検証(2026-09-29時点)です)。ファイルを作らない場合は、`db2`から、関数名・`SPECIFIC`名・表名のすべてを`<自分のユーザー名>1.`で修飾して実行します(`SQL0455`のため。`db2`の既定のスキーマはユーザー名なので、表名も修飾が要ります)。

   `P_LIMIT`に`4`を渡すと、`P00002`(在庫3)が含まれるはずです(3<4)。`3`を渡すと含まれません(3<3は偽)。それ以外の商品が出るかどうかは、`ZAIKOM`の在庫の値によります(この教材では、`P00002`・`P00005`以外の在庫数は記録していません)。作ったら、片付けで消します(片付けの手順4・7)。

</details>

### 演習(b): 受注を登録する

1. 次の内容の受注を、`JUCHU_REGISTER`で登録してください: 受注番号`J09902`、得意先`C00002`、受注日`20260930`、担当`T00001`、明細1行(1行目、商品`P00002`、数量1、単価`12800.00`)。文書は、手順10と同じ形で、1つのテキスト・リテラルにします。
2. `JUCHUM`・`JUCHUD`の行を`SELECT`で確かめ、`JUCHU_INQUIRY_JSON('J09902')`で読み戻してください。(注意)手順13の「文字列の数値」になった文書を、`JUCHU_REGISTER`に渡してはいけません(ヘッダーだけが残ります)。文書は、必ず1つのテキスト・リテラルで渡し、`RUNSQL`の中で`JSON_OBJECT`を使って組み立てる形は避けてください。
3. (考える・試す)**共有データに注意**: このあとで作る`J09903`のヘッダーは、失敗すると残ります。片付けの手順1を必ず実行してください。明細の`unitPrice`を書かない文書(`{"line":1,"product":"P00001","qty":2}`)で、受注番号`J09903`を登録すると、何が起きると思いますか。予想してから実行し、`JUCHUM`と`JUCHUD`の行を確かめてください。

<details><summary>答え</summary>

1. 次のとおりです(実機で成功を確認した文書です)。

   ```sh
   db2 "CALL <自分のユーザー名>1.JUCHU_REGISTER('{\"orderNo\":\"J09902\",\"customer\":\"C00002\",\"orderDate\":20260930,\"salesRep\":\"T00001\",\"lines\":[{\"line\":1,\"product\":\"P00002\",\"qty\":1,\"unitPrice\":12800.00}]}')"
   ```

2. `JUCHUD`には、次の1行が入ります(実機確認済み)。

   ```text
   JUNO   JULINE  JUSHO  JUSU    JUTNK
   ------ ------- ------ ------- ---------
   J09902    1    P00002      1   12800.00
   ```

   `JUCHU_INQUIRY_JSON('J09902')`の`customerName`は、`C00002`の得意先名(検証で、この受注のヘッダーだけを読んだとき`NORTH STAR LTD`でした)になります。読み戻しの文字列全体は、この受注では実行していません(未検証(2026-09-29時点))。
3. 予想: 明細の`INSERT`で`JUTNK`(単価)が`NULL`になり、`SQL0407`で失敗し、ヘッダー(`J09903`)だけが残るはずです。検証では、単価が`"1580,00"`という文字列で渡った場合に、同じ`SQL0407`とヘッダーだけの残りを観察しました(手順13の文書)。**単価を書かない文書そのものは、この教材では実行していません(未検証(2026-09-29時点))。** 実行したら、片付けの`DELETE`で`J09903`を消してください。ヘッダーを先に検証する形に、`JUCHU_REGISTER`を直す課題は、時間があれば挑戦してください(ヒント: 「対策の考え方」の(1)。答えは示しません)。

</details>

### 演習(c): ルーチンの実体を予想する(紙の上)

次の3つのルーチンについて、`SPECIFIC`名を付けて作ったとき、できるオブジェクトの型(`*SRVPGM`・`*PGM`・なし)を答えてください。`CHKOBJ`で確かめられるものは、どれですか。

1. `LANGUAGE SQL`で書いた、値を1つ返す関数。
2. `LANGUAGE SQL`で書いた、`OUT`引数だけのプロシージャー。
3. `LANGUAGE RPGLE`で、既存の`*PGM`を指すプロシージャー。

<details><summary>答え</summary>

1. `*SRVPGM`(名前は`SPECIFIC`名)。`CHKOBJ ... OBJTYPE(*SRVPGM)`で確かめられます(`LOWSTOCKT`等で確認)。
2. `*PGM`(名前は`SPECIFIC`名)。`CHKOBJ ... OBJTYPE(*PGM)`で確かめられます(`JUCHUREGST`等で確認)。`OUT`引数があることによる違いは、確認していません(未検証(2026-09-29時点))。
3. 実体は作られない(カタログだけ)と予想されます。実機で確かめたのは、`LANGUAGE RPGLE`の**関数**(3つ)で、実体が作られなかったことだけです。外部**プロシージャー**の登録は、確認していません(未検証(2026-09-29時点))。既存の`*PGM`があるので、`CHKOBJ`でそれを確かめるとしても、それは登録の確認にはなりません。

</details>

## セルフチェック

- [ ] `JUCSRV`・`ZAISRV`の手続きを、`LANGUAGE RPGLE`・`PARAMETER STYLE GENERAL`の関数として登録し、手順6の6つの値(名前・`NOTFOUND`・`SQLNULL`・`2`・`3`・`-1`)が出ることを、自分の環境で確かめた。
- [ ] `EXTERNAL NAME`の綴りが大文字小文字まで一致しないと、`CREATE`は成功し、呼び出しが`CPF426A`・`SQL0204`で失敗すること、そのとき最初に見るのがエクスポート名であることを説明できる。
- [ ] `EXTERNAL NAME`にライブラリーを書かなくてよいこと、ただし作成時のライブラリーが`SYSROUTINES.EXTERNAL_NAME`に記録されることを説明できる。
- [ ] `LANGUAGE SQL`の関数・プロシージャーから、それぞれ`*SRVPGM`・`*PGM`ができること、`LANGUAGE RPGLE`の登録は実体を作らないこと、その結果`CHKOBJ`・`TXCHECK`で確かめられる範囲を説明できる。
- [ ] `SPECIFIC`名を10文字以内の有効なシステム名にする理由(有効なシステム名で、同名のオブジェクトが無いときだけ実体の名前になること)を言える。
- [ ] `db2`で、ルーチン名と`SPECIFIC`名の両方を修飾しないと`SQL0455`になることを言える。
- [ ] 本体の無修飾の関数呼び出しが、別のジョブで`SQL0204`になる理由(保存されたSQLパス)と、直し方を2つ言える。
- [ ] `LOW_STOCK`が表関数、`LOW_STOCK_RS`が結果セットのプロシージャーであること、呼び方の違い(`TABLE(...)`と`CALL`)を言える。`db2`の`CALL`で`0100C`の警告のあとに行が出ることを確かめた。
- [ ] `JUCHU_REGISTER`で、二重登録が`SQL0438`(75001)で断られ、明細が増えないことを確かめた。
- [ ] `COMMIT(*NONE)`のとき、明細が失敗するとヘッダーだけが残ること(`"lines":null`)を説明できる。
- [ ] JSON文書を、1つのテキスト・リテラルで渡す理由(`RUNSQL`の中でリテラルの数値が文字列になる現象。原因は未確認)を説明できる。
- [ ] 「先に全部`CREATE`、それから呼ぶ」理由(排他ロック。IBM Docsの記載。呼ぶと活動化されるという結びつきは推測)と、第8部の作り直しの後に行う順序の依存を説明できる。

## 片付け

このレッスンで作ったものを、次の順で削除します。**`JUCSRV`・`ZAISRV`・`JUCHUM`・`JUCHUD`・`ZAIKOM`そのものは、削除しません。**

1. **(SSH) 登録した受注の行を消します。** 明細(`JUCHUD`)を先に、ヘッダー(`JUCHUM`)を後に消します。

   ```sh
   db2 "DELETE FROM <自分のユーザー名>1.JUCHUD WHERE JUNO IN ('J09901', 'J09902', 'J09903')"
   db2 "DELETE FROM <自分のユーザー名>1.JUCHUM WHERE JUNO IN ('J09901', 'J09902', 'J09903')"
   ```

   `db2`は、0行に当たった`DELETE`で`SQLSTATE 02000`(Row not found for DELETE)を出します。演習(b)の3を試さなかった場合の`J09903`のように、すでに無い行が対象のときに出ますが、エラーではありません(検証でも観察)。この2つの`DELETE`は、09-07の期待値を守るために必ず実行してください。

2. **(SSH) 件数を確かめます。** 手順1の値(通常は`8`・`12`・`6`)に戻っているはずです。

   ```sh
   db2 "SELECT (SELECT COUNT(*) FROM <自分のユーザー名>1.JUCHUM) AS M, (SELECT COUNT(*) FROM <自分のユーザー名>1.JUCHUD) AS D, (SELECT COUNT(*) FROM <自分のユーザー名>1.ZAIKOM) AS Z FROM SYSIBM.SYSDUMMY1"
   ```

   期待される結果(検証の片付け後): `M`が8、`D`が12、`Z`が6。**`ZAIKOM`は、このレッスンで書き換えていません**(`GET_STOCK_QTY`は`get`を呼ぶだけで、在庫を書き換えません)。ですから、通常`TXRESET`は要りません。件数が基準と違うときだけ、`<自分のユーザー名>1/TXRESET LIB(<自分のユーザー名>1)`を実行してください(`JUCHUM`・`JUCHUD`・`ZAIKOM`は、ほかのレッスンと共有のデータです。第9部での戻し方は、[第9部の扉](index.md)のとおり未検証(2026-09-29時点)です)。

3. **(5250・SSH) 呼び出しに使ったジョブを終わらせます。** 手順5で関数を呼んだ5250のセッションをサインオフし、手順2〜12で使ったSSH接続も切ります。RPGの外部関数を呼んだジョブが`JUCSRV`・`ZAISRV`を使ったままだと、`DROP`が`SQL7909`になるおそれがあるためです(IBM Docsの排他ロックの記載に基づく注意で、実機で確かめていません)。検証は、関数を呼んだジョブが終わったあと、新しいジョブで`DROP`しました。呼んだジョブがサインオンしたままで`DROP`した場合は、未検証(2026-09-29時点)です。

4. **(SSH、新しい接続) SQLルーチンを削除します。** `db2`では、`SPECIFIC`名もライブラリーで修飾します(`SQL0455`)。演習(a)の3を作らなかった場合、`LOWSTOCKB`の行は、ルーチンが見つからないという趣旨のエラーになるはずですが、続けて構いません(そのメッセージ IDは未検証(2026-09-29時点)です。存在しない`SPECIFIC`名の`DROP`は、実行していません)。

   ```sh
   db2 "DROP SPECIFIC PROCEDURE <自分のユーザー名>1.JUCHUREGST"
   db2 "DROP SPECIFIC PROCEDURE <自分のユーザー名>1.LOWSTOCKRS"
   db2 "DROP SPECIFIC FUNCTION <自分のユーザー名>1.LOWSTOCKT"
   db2 "DROP SPECIFIC FUNCTION <自分のユーザー名>1.LOWSTOCKB"
   db2 "DROP SPECIFIC FUNCTION <自分のユーザー名>1.JUCHUINQJS"
   db2 "DROP SPECIFIC FUNCTION <自分のユーザー名>1.GETSTOCKQT"
   db2 "DROP SPECIFIC FUNCTION <自分のユーザー名>1.CNTCUSTORD"
   db2 "DROP SPECIFIC FUNCTION <自分のユーザー名>1.GETCUSTNM"
   ```

   期待される結果: 各行が`DB20000I  THE SQL COMMAND COMPLETED SUCCESSFULLY.`で終わります(検証の`DROP`。`RUNSQLSTM`で作ったルーチンでは、関数を呼んだジョブが終わったあとの新しいジョブで、成功しました。`SQL7909`が出たら、警告です。上の表を参照)。`LOWSTOCKB`は、検証では作っていないので、その行の結果は未検証です。実体の`*SRVPGM`・`*PGM`(`LOWSTOCKT`等)も、ルーチンの削除で一緒に消えます(検証の最後の照会で、`OBJECT_STATISTICS`にこれらが出なくなったことを確認)。

   確認(検証の最後の照会と同じ形。ルーチンが0行になります):

   ```sh
   db2 "SELECT ROUTINE_NAME, SPECIFIC_NAME, ROUTINE_TYPE FROM QSYS2.SYSROUTINES WHERE ROUTINE_SCHEMA = '<自分のユーザー名>1' ORDER BY ROUTINE_NAME"
   ```

5. **(5250、新しいセッション) 作業表を削除します。**

   ```text
   DLTF FILE(<自分のユーザー名>1/W0904A)
   ```

   この`DLTF`の実行そのものは、このレッスンの検証では試していません(検証は、`DROP TABLE`ではなく作業表を残す形でした。未検証(2026-09-29時点))。

6. **スプール・ファイル。** `RUNSQLSTM ... OUTPUT(*PRINT)`は、実行リストのスプール・ファイルを作ります。手順2の1回分と、演習(a)の3で`RUNSQLSTM`を実行した場合はその2回目の分も、5250の`WRKSPLF`で見て、不要なら`4`(削除)を入力します。この削除操作は、実機では試していません(未検証(2026-09-29時点))。

7. **(SSH) 演習(a)の3で作ったスクリプト・ファイルを削除します。** 作った場合だけです。

   ```sh
   rm $HOME/lowstockb.sql
   ```

   この`rm`は、実行していません(未検証(2026-09-29時点))。

## まとめ

| 英語 | 日本語 |
|---|---|
| Routine / UDF / UDTF / stored procedure | ルーチン / ユーザー定義関数 / ユーザー定義表関数 / ストアード・プロシージャー |
| `EXTERNAL NAME` | 外部名(登録する実体の指定。括弧の中はエクスポート名、大文字小文字まで一致) |
| `PARAMETER STYLE GENERAL` | 引数・戻り値がそのまま渡る、素直な引数の渡し方 |
| `SPECIFIC` name | 特定名(有効なシステム名で、同名のオブジェクトが無ければ、実体のオブジェクト名になる。10文字以内) |
| Result set | 結果セット(プロシージャーが開いたまま返すカーソル) |
| SQL path | SQLパス(ルーチンの中の無修飾の名前を探す場所。作成時のものが保存される) |
| Atomicity | 原子性(全部成功するか、全部無かったことになるか) |

- 新しいメッセージ ID: `SQL0455`・`SQL0438`・`SQL7909`・`CPF426A`(このレッスンの意味で)・`CPC5D0B`・`CPC5D07`。
- 決まり: 綴りは大文字小文字まで一致、`SPECIFIC`名は10文字以内の有効なシステム名(同名のオブジェクトが無いこと)、先に全部`CREATE`、JSONは1つのテキスト・リテラル、`db2`では`SPECIFIC`名も修飾。
- 次のレッスン([09-05 外部API: アダプターとモック](09-05-external-api-adapter-mock.md))では、外部のAPIを呼ぶアダプター`JUHTTPSV`を作り、モックと実通信を切り替えます。ここで作った`JUCHU_INQUIRY_JSON`・`LOW_STOCK`は、09-07([09-07 チェックポイント](09-07-checkpoint-order-summary-api.md))の受注サマリーAPIの部品になります。データ待ち行列は[09-06](09-06-data-queues-async.md)で扱います。

## 実機メモ

- **確認日: 2026-09-29。バッチ`part09-04-sql-routines`(3回の接続: 16:49・17:05・18:05)、PUB400、IBM i 7.5(V7R5M0)。** 検証は、著者の検証用ライブラリーで行いました(実機の記録は[../probes.md](../probes.md)の「第9部 09-04」の節にあります)。学習者の`<自分のユーザー名>1`そのものでの再現は、個別には確認していません(未検証(2026-09-29時点))。
  - **`JUCSRV`・`ZAISRV`の代わりに、複製(`CRTDUPOBJ`で作った`JUCSRVU`・`ZAISRVU`)を指して検証しました。** スクリプトの`EXTERNAL NAME`を、`JUCSRV(`から`JUCSRVU(`に置き換えた版(内容はコメント以外同じ)を実行し、最後に複製を削除しました。本物の`JUCSRV`への登録は、ライブラリーを書いた別名の関数(`getCustName`・`countCustOrders`・`GET`)を作って呼ぶ形だけ、実機で確認しています。**レッスンのスクリプトそのもの(本物の`JUCSRV`・`ZAISRV`を無修飾で指す形)を、そのまま実行した結果ではありません(未検証(2026-09-29時点))。**
  - 1回目(16:49)は、検証用の呼び出しの書き方の誤り(`db2`の`SPECIFIC`名が無修飾で`SQL0455`、`RUNSQL`のシステム命名で`SQL0206`)が多く出ました。2回目(17:05)と3回目(18:05)で修正して確認しました。
- **V2で確認できたこと**:
  - 3つの`LANGUAGE RPGLE`・`PARAMETER STYLE GENERAL`関数を作成でき、`RUNSQL`(`NAMING(*SQL)`。CLプログラムの中から、開発ライブラリーを現行ライブラリー(`CHGCURLIB`)にしたバッチ・ジョブで実行。5250の対話式ジョブではありません)から呼べました: `GET_CUST_NAME('C00001')`が`ACME TRADING CO`(`CHAR(30)`、右側空白)、存在しない得意先が`NOTFOUND`、`NULL`引数が`NULL`、`COUNT_CUST_ORDERS('C00001')`が`2`、`GET_STOCK_QTY('P00002')`が`3`、存在しない商品が`-1`。ライブラリー修飾あり・なしの両方の`EXTERNAL NAME`で同じ結果でした。
  - エクスポート名の大文字小文字が合わない登録(`GETCUSTNAME`・`get`)は`CREATE`が成功し、呼び出しが`CPF426A`・`SQL0204`で失敗しました。
  - `SYSROUTINES.EXTERNAL_NAME`は、`RUNSQLSTM`(SQL命名・`DFTRDBCOL`)では`ライブラリー/…`、`RUNSQL`(システム命名)では`*LIBL/…`で記録されました。`*LIBL/…`で記録された検証用の関数の`db2`からの`DROP`で`SQL7909`(01660)が出ました(このレッスンのスクリプトの関数ではありません)。
  - `LANGUAGE SQL`の関数は`*SRVPGM`、プロシージャーは`*PGM`(属性`CLE`)ができ、`LANGUAGE RPGLE`の関数は実体を作りませんでした。`CHKOBJ`は、前者を見つけ、後者は`CPF9801`でした。
  - `LOW_STOCK()`が`P00002`(3<5)・`P00005`(12<50)を返しました。`LOW_STOCK_RS`を`db2`から`CALL`すると、`0100C`のあと同じ2行が出ました。`JUCHU_INQUIRY_JSON('J00001')`が期待どおりの文書を返しました。
  - 本体の無修飾の`GET_CUST_NAME`が別ジョブで`SQL0204`になりました。ライブラリー修飾した呼び出しは、検証用の関数(`PRB_INQ_W`が`PRB_GC_Q`を呼ぶ形)で動きました。`TOKUIM`のサブセレクトも動きました。保存された`SQL_PATH`(`"QSYS","QSYS2","SYSPROC","SYSIBMADM","<自分のユーザー名>"`)は、09-07の`ORDER_SUMMARY_JSON`で確認したもので、このレッスンのルーチンのものではありません。SQLパスが原因、という説明は推測です。
  - `JUCHU_REGISTER`: 1つのテキスト・リテラルの文書で、`J09901`(明細2行)・`J09902`(明細1行)が登録でき、`JUCHU_INQUIRY_JSON`で往復できました。二重登録は`SQL0438`(75001)で断られ、明細は2行のままでした。文字列の`"1580,00"`の文書では`SQL0407`で明細が失敗し、ヘッダーだけが残りました(`"lines":null`)。片付けの`DELETE`で、件数は`8`・`12`・`6`に戻りました。
  - `RUNSQLSTM`(SQL命名)で、7個のルーチンすべてが作成できました(`SQL7997`・`SQL7989`)。`SQL0330`は、`iconv`でUTF-8にした版だけで出ました。
  - `JSON_OBJECT`にリテラルの数値を渡した文を`RUNSQL`(システム命名。CLラッパーのバッチ・ジョブ)で実行すると、`"qty":"2"`・`"unitPrice":"1580,00"`のように文字列とコンマになりました(原因は未確認)。列の値から作ると数値のままでした。
  - `NOT FENCED`の外部関数を呼んだバッチ・ジョブの、その後の`RUNSQL`で`CPD000D`が出ましたが、処理は続きました。
- **未検証(2026-09-29時点)**:
  - 5250・ACSでの表示(V3)。特に、ACSの「実行SQLスクリプト」での結果セットの表示、`LANGUAGE RPGLE`の関数を`db2`・ACSから呼ぶ形。`RUNSQL`・`CHKOBJ`は、CLプログラムの中からバッチ・ジョブで実行しただけで、5250の対話式ジョブでの実行(ライブラリー・リストの設定なし、`CPD000D`の出方を含む)は未検証。
  - レッスンのスクリプトを、本物の`JUCSRV`・`ZAISRV`に対して無修飾でそのまま実行した結果。作成時のライブラリーが、ライブラリー・リストと`DFTRDBCOL`のどちらで決まったか。`git clone`したファイルのタグでの`RUNSQLSTM`。
  - `<自分のユーザー名>1`から`<自分のユーザー名>2`への昇格(`CRTDUPOBJ`等)の後の`EXTERNAL_NAME`の変わり方。`JUCSRV`・`ZAISRV`の作り直し後に、登録情報が失われるか。
  - `FENCED`(既定)での外部関数の動作。
  - 排他ロックによる`SQL7909`の再現(順序の節はIBM Docsの記載に基づく。関数を呼ぶと活動化される、という結びつきは推測)。関数を呼んだあとのジョブからの`CREATE OR REPLACE`・`DROP`。`STRSQL`で結果セットが見えるかどうか(IBM Docsは対応インターフェースとしてSQL PL・埋め込みSQL・JDBC・CLI・ODBCを挙げ、`STRSQL`には触れていません)。`RUNSQLSTM`の中と、`db2`での小数のリテラルの`JSON_OBJECT`。ライブラリーなしの`CREATE`が「見つからない」で失敗するときのメッセージと直し方。存在しない`SPECIFIC`名の`DROP`のメッセージ。
  - `SET OPTION COMMIT = *NONE`を付けない場合の動作。コミット制御での原子化。ヘッダーを先に検証する形。`SET PATH`による直し方。
  - `SPECIFIC`名が10文字を超えたときの動作(切り詰めか、システムによる名前の生成か)と、同名のオブジェクトがあるときの生成名(記録したのは、10文字以内の名前が使えたことだけ)。
  - 手で書いた・`git clone`したファイルのタグ(273以外のとき)と、演習(a)の3のヒアドキュメントでのファイル作成。
  - `LOW_STOCK_BELOW`(演習(a)の3。`solutions/09-04/lowstockb.sql`)、`P00005`への絞り込みと`GET_STOCK_QTY('P00005')`の実行(演習(a)の1・2)、`J09902`の読み戻しの全文と単価を書かない文書(演習(b))、外部プロシージャーの登録の実体(演習(c))。
  - `DLTF`(作業表)・`WRKSPLF`での削除・`OBJECT_STATISTICS`の`OBJNAME`絞り込み・`SYSROUTINES`の`ROUTINE_SCHEMA`絞り込みの、学習者の環境での結果。
  - 読解用の囲みの、RPGの結果セットの実例(IBM Docsの実例で、実行していない)と、`GENERAL WITH NULLS`の制限(IBM Docsの記載)。
  - 空の`lines`配列(明細0件)の文書を渡したときの動作。
  - 容量(実体のオブジェクトの大きさ)。
