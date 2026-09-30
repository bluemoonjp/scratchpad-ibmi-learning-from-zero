# 10-04 課題E: APIの公開設計書と、第10部の振り返り

> 所要時間: 約200分(実演の実作業に約90分、設計書に約60分、振り返りに約20分、片付けに約20分の目安。任意の演習(e)を除く。手順7の終わりと手順10の終わりで休めます。学習者での計測は未検証(2026-09-30時点)) / 前提レッスン: 09-07・09-04・09-05・08-08・10-01〜10-03(部の扉は[第10部](index.md)) / 目標番号: 7(あわせて、目標1〜6の振り返り) / 観測方法: `db2`の出力(JSON文字列・行数)・`APILOG`の中身・`RUNSQLSTM`の実行リスト・`ls -l`のバイト数・`IFS_READ_UTF8`の読み戻し・`TXCHECK`のPASS/FAILメッセージ(ジョブ・ログ)・`QSYS2.SYSROUTINES`の行数 / 道具: SSH(`db2`・`system`・`RUNSQLSTM SRCSTMF`)+ 5250(`CHGCURLIB`・`CALL`・`CRTSQLRPGI`・`CRTDUPOBJ`・`TXCHECK`)+ PC側のテキストエディター(設計書)。ACS・VS Codeは使いません / 同時接続数: 5250×1 + SSH×1(検証はSSHのみ。5250は未検証(2026-09-30時点)) / 作る・変えるオブジェクト(この節で一度だけ書きます。ライブラリー名は第9部・第10部と同じく`<自分のユーザー名>1`・`<自分のユーザー名>2`・`<自分のユーザー名>B`のプレースホルダーで表し、この課題は本番役の`<自分のユーザー名>2`で行います): `<自分のユーザー名>2`に、ビュー`LOWALERT`・`ZIPCHECK`・`ZIPCHKLOG`・`APIZIP`、SQLプロシージャー`EXPORT_LOWSTOCK`(`SPECIFIC`名`EXPLOWJSN`)、09-04のSQLルーチン7本(`SPECIFIC`名`GETCUSTNM`・`CNTCUSTORD`・`GETSTOCKQT`・`JUCHUINQJS`・`LOWSTOCKT`・`LOWSTOCKRS`・`JUCHUREGST`。上の`EXPLOWJSN`と合わせて計8本)、表`APICFG`・`APIMOCK`・`APILOG`、プログラム`JUHTTPSV`、受注`J09901`の行、`TXCKM`に`10-04`の4行、IFSのテスト・ファイル。`<自分のユーザー名>B`に、昇格の予行で作る`ZAISRVP`・`JUCSRVP`(片付けで消します)。`ZAISRV`・`JUCSRV`は、消して作り直します(下の実演の手順8) / DBVER: 1(検証は`TXSTATE`を使っていません) / 依存するプローブ: バッチ`part10-04-checkpoint`(2026-09-30、IBM i 7.5。2回の接続で、V2)。部品は第9部のバッチ`part09-04-sql-routines`・`part09-05-mock`・`part09-07-checkpoint`(2026-09-29、V2)に頼ります / PTF 依存: PTFレベルの下限は未検証(2026-09-30時点)(確認したのはV7R5M0のみ) / 容量の目安: わずか(オブジェクトの大きさは記録していません。未検証(2026-09-30時点))

## ゴール

- 10-04-1: 第9部で作った3つの操作(受注の照会・受注の登録・郵便番号の検証)について、[API設計テンプレート](../templates/api-design.md)の11節すべてを埋めた公開設計書を書ける。とくに「8. 冪等性」(二重に呼ばれたとき・途中で失敗したとき)と「10. テスト証拠」(いつ・何で・どの結果か)に、確かめた事実と未検証を書き分けられる。
- 10-04-2: 低在庫アラート(`LOWALERT`)・郵便番号の判定(`ZIPCHECK`・`ZIPCHKLOG`)・IFSへのJSON書き出し(`EXPORT_LOWSTOCK`)の3つの接着部品を動かし、確認済みの値と照らして説明できる。ビューの中でルーチンを無修飾で呼ぶと`SQL0204`になる理由(`DFTRDBCOL`はSQLパスではない)と、直し方を言える。
- 10-04-3: `ZAISRV`・`JUCSRV`の昇格の予行(複製して消して戻す)を、複製の確認を先に済ませる順で行い、`TXCHECK LESSON('10-04')`で4件PASSを確かめ、片付け後に`SYSROUTINES`が0件・件数が8・12・6に戻ることを確かめられる。あわせて、7つの目標を第10部でどこまでできたか、根拠を挙げて自己評価できる。

## ウォームアップ

<details><summary>前回までの復習(09-04・09-05・09-07・08-08)</summary>

1. (09-04)ルーチンの本体の中から、別のルーチンを無修飾で呼ぶと、別のジョブで何が起きましたか。直し方を2つ挙げてください。
2. (09-07)`TXCHECK`を同じジョブで2回続けて呼ぶと何が出ますか。それは失敗ですか。
3. (08-08)`CRTDUPOBJ`で複製を作ってから元を消す順にする理由は何ですか。

答え: 1. 作成はできたのに、別のジョブから呼ぶと`SQL0204`(見つからない)になりました。09-04では推測でしたが、10-04で、ビューの作成時のSQLパスに開発ライブラリーが入らないことを実行リストで確認しました(2026-09-30、`part10-04-checkpoint`、V2)。ルーチンの作成時のSQLパスが同じかどうかは、まだ推測です。直し方は、ライブラリーで修飾して呼ぶか、表を直接引く(副問い合わせにする)ことです。 2. `CPF4174`と「could not query the manifest」が出ます。08-08で見つかった既知の不具合の再現で、PASSでもFAILでもない「確認不能」です。新しいジョブで1回だけ実行します。 3. 複製が無事にできたと確かめてから元を消せば、失敗しても元が残るからです。順序を逆にすると、元も複製も無い状態になりえます。

</details>

## なぜ学ぶか

**このレッスンは第10部の最後の課題で、新しい中核概念はありません**(下の「新出」)。第9部の部品(`JUCHU_INQUIRY_JSON`・`LOW_STOCK`・`JUCHU_REGISTER`・`JUHTTPSV`)を、**3つの操作を持つ1つのAPI**としてまとめ、第10部の3つの課題(障害対応・保守・近代化と開発基盤)で身に付けた「確かめてから直す・戻せる形で変える・証拠を残す」を、API公開の場面でもう一度使います。

現場でAPIを頼まれたとき、動くコードより先に求められるのは、たいてい次の3つです(09-07と同じです)。

- 呼び出し元が何を渡し、何が返るのかを、1ページで説明できること。
- 失敗したとき・0件のとき・二重に呼ばれたときの振る舞いを、決めてあること。
- それが本当にそうなることを、いつ・何で確かめたかを示せること。

もう1つ、このレッスンには**実機で見つかった失敗**が入っています。最初に書いた低在庫アラートのビューは、`RUNSQLSTM`で`SQL0204`になりました(手順7)。うまくいった手順だけでなく、うまくいかなかった手順を、設計書の「3. 業務ロジックの置き場所」と「10. テスト証拠」にどう残すかが、設計書の質を決めます。

このレッスンで書く設計書と振り返りが、第10部の成果物の最後の1つです(部の扉の[成果物](index.md)の表)。

## 新出

**新しい中核概念はありません。** 新しく出る操作は、下の「読解用」の3つと、任意の手順で使う`REPEAT`だけです(どれも新出の数には入れません。読んで意味が分かればよく、暗記は不要です)。ほかは、既習の組み合わせで進めます(09-02のJSON・09-04のSQLルーチン・09-05のアダプター・08-08の昇格・05-13から続く`TXCHECK`)。

**既習の応用(新出に数えません)**:

- `RUNSQLSTM SRCSTMF`・`db2`・`CRTSQLRPGI`・`CRTDUPOBJ`・`TXCHECK`(09-04・09-05・08-08・09-07)。`RMVM`(01-06b)・`TXRESET`(第10部の前のレッスン)・`DROP SPECIFIC`(09-04)。
- `IFS_READ_UTF8`の`TABLE(...)`での呼び出し(名前付き引数`=>`を含む形。`QSYS2.IFS_READ_UTF8`は09-02で既習。読み戻しの確認だけに使います)。`ls -l`・`mkdir -p`・`rm -f`(シェルの基本操作。第9部・08-08などで使いました。`rmdir`も同じ系統です)。
- `JSON_OBJECT`・`JSON_ARRAYAGG`・`JSON_TABLE`(09-02)、`QSYS2.IFS_WRITE_UTF8`・`QSYS2.IFS_READ_UTF8`(09-02)。
- 第9部の部品の呼び出し(`JUHTTPSV`・`APILOG`・`JUCHU_REGISTER`)。

**読解用(新出に数えません。読んで意味が分かればよく、自分で書けなくて構いません)**:

- `LOCATE('"address1"', 列)`(文字列の中で、探す文字列が何文字目にあるかを返す関数。無ければ0。`ZIPCHECK`の中で、JSONのパス式を使わずに「住所の項目がある」を判定するのに使っています。**この教材では、ここで初めて出ます**)。
- `CASE WHEN ... THEN ... END`(条件で値を選ぶ。`ZIPCHECK`・`ZIPCHKLOG`の判定)。
- `LEFT JOIN`(片方に相手の行が無くても、行を残す結合。`ZIPCHKLOG`で、住所の行が無い応答を残すために使っています。**この教材では、ここで初めて出ます**)。
- `REPEAT('A', 3000)`(文字を指定の回数だけ繰り返す関数。7-4の長さの確認だけで使います。**この教材では、ここで初めて出ます**)。

## 説明

### 全体の形: 1つのAPIの、3つの操作

このレッスンで設計書にする「API」は、HTTPではなく、**SQLの接続から呼ぶ入口**です(09-07と同じ。HTTPで公開する方法との比べ方は[09-07](../part09/09-07-checkpoint-order-summary-api.md)の読解用の表を参照してください)。

| 記号 | 操作 | 実体 | 読む/書く | このレッスンの接着部品 |
|---|---|---|---|---|
| 操作1 | 受注の照会 | SQL関数`JUCHU_INQUIRY_JSON`(`SPECIFIC`名`JUCHUINQJS`) | 読むだけ | `LOWALERT`(隣の警告) |
| 操作2 | 受注の登録 | SQLプロシージャー`JUCHU_REGISTER`(`JUCHUREGST`) | 書く | (なし。09-04のまま) |
| 操作3 | 郵便番号の検証 | アダプター`JUHTTPSV`+`APIMOCK`・`APILOG` | 外部を読む(既定はモック) | `ZIPCHECK`・`ZIPCHKLOG` |

3つの操作に共通の出口として、`EXPORT_LOWSTOCK`が、警告のJSONをIFSのファイルに書き出します(手順7)。**低在庫アラートは、手で実行する問い合わせです。** 夜間・定時に動く仕組みは作りません(09-06のワーカー`C0906A`もこのビューを読みません。設計上の線引き)。

### なぜ`LOWALERT`は、`LOW_STOCK()`を呼ばずに、同じ問い合わせを書き写しているのか

最初の版は、`LOWALERT`ビューの中で`LOW_STOCK()`を**無修飾で**呼んでいました。`RUNSQLSTM`(`NAMING(*SQL)`・`DFTRDBCOL`指定)で作ると、`SQL0204`(`LOW_STOCK in *LIBL type *N not found`)で失敗しました(2026-09-30、`part10-04-checkpoint`の1回目の接続、V2)。その直前に、`LOW_STOCK`は同じライブラリーに作ってあった(`SQL7997`)にもかかわらず、です。

原因は、**`DFTRDBCOL`が決めるのは、表などの既定のスキーマであって、SQLパスではない**ことです。実行リストに出たSQLパスは、`QSYS`・`QSYS2`・`SYSPROC`・`SYSIBMADM`・ユーザー名と同名のスキーマで、あなたの開発ライブラリーは入っていませんでした。09-04で見た「本体の無修飾の関数が、別ジョブで`SQL0204`」と同じ根の問題と考えられます(推測を含む。10-04の実行リストで確認できたのは、ビューの作成時のSQLパスに開発ライブラリーが無かったことです)。

直し方は2つあり、どちらも実機で確かめました(V2。1つ目は2回目の接続、2つ目は1回目の接続)。

| 直し方 | 実機の結果 |
|---|---|
| ビューの中に、`LOW_STOCK`と同じ問い合わせ(`SHOHIM`と`ZAIKOM`の結合)を書き写す。配布の`lowstock-alert.sql`はこちら | `RUNSQLSTM`で`SQL7951`(ビューができた)。最高重大度00。JSONは`count`が2で、180文字 |
| `TABLE(ライブラリー.LOW_STOCK())`のように、ライブラリーを書く | ライブラリーを書いた版は作成でき、`db2`から読めた(V2)。同じ180文字のJSON |

**ソースのファイルにライブラリー名を書き込まない**という、この教材の決まりのため([スタイル・ガイド](../style-guide.md))、配布のファイルは1つ目の形です。代償は、「発注点を下回る」という条件が、`LOW_STOCK`とこのビューの**2か所**に書かれることです(二重保守。09-07で見た`ORDER_SUMMARY_JSON`と同じ)。設計書の「3. 業務ロジックの置き場所」に、この代償を書きます。`SET PATH`でSQLパスを足す方法も考えられますが、試していません(未検証(2026-09-30時点))。

### 郵便番号の判定は、住所の「有無」だけで行う

`ZIPCHECK`・`ZIPCHKLOG`は、応答に住所の項目(`address1`)が**あるかどうか**で、`FOUND`・`NOTFOUND`を決めます。日本語の住所の文字列そのものは、比べません。09-05で、日本語の住所をジョブのCCSIDの列に取り出すと`3F3F3F`になったからです。判定は、次のようになります。

- `HTTPERR`: モックの状態が400以上または0(`ZIPCHKLOG`では、アダプターの結果コードが`HTTPERR`)。
- `NOMOCK`: モックに登録が無い郵便番号(`ZIPCHKLOG`だけ)。
- `FOUND`: 応答に`address1`がある。
- `NOTFOUND`: 上のどれでもない(HTTPの状態は200なのに、住所が無い)。

**住所が無いことは、エラー(`RC`が`OK`以外)ではなく、正常系の`NOTFOUND`**として表します。モックの`9999999`が、その例です(状態200・`results`が`null`)。

### IFSへの書き出しで分かったこと

`QSYS2.IFS_WRITE_UTF8`について、実機で分かったことは次のとおりです(V2)。設計書の「9. 量・頻度の上限」に効きます。

- `LINE`に、リテラルも、変数(ビューの列から取り出した値)も、スカラーの副問い合わせも渡せました。
- `LINE`は、20000バイトという、`VARCHAR(4000)`の列の上限(4000)を超える長さも、そのまま全部書けました(3000バイトも同様)。設計書の上限は、書き出し側ではなく、ビューの戻り値の型(`VARCHAR(4000)`)から来ると考えられます(これは`LOWALERT`の型からの推論で、4000文字を超える文書は実機で試していません。未検証(2026-09-30時点))。
- **相対パスは、スクリプトのある場所ではなく、ジョブのホーム・ディレクトリーに書かれました。** 必ず絶対パスで指定してください。
- `IFS_READ_UTF8`で読み戻すと、1行(`LINE_NUMBER`が1)で、書いた内容と同じでした。ファイルの中身を`od`で見ると、別の文字に見えることがありました(画面上の見え方と考えられます。原因は確認していません)。**中身の確認には、`IFS_READ_UTF8`を使ってください。**

`IFS_WRITE_UTF8`が使えない環境の代替として、`CPYTOIMPF`(`RCDDLM(*CR)`が要る。省くと`CPF2845`)があります。**この教材では実演したことがありません**(未検証(2026-09-30時点))。

## 実演

**前提**: 第9部と10-01〜10-03を終えていて、次が揃っていること。

- `<自分のユーザー名>2`に、`JUCHUM`・`JUCHUD`・`ZAIKOM`・`SHOHIM`・`TOKUIM`、サービス・プログラム`JUCSRV`・`ZAISRV`があること。`JUCSRV`・`ZAISRV`が無ければ、08-08の`CRTDUPOBJ`の昇格の形で`<自分のユーザー名>1`から複製します(このレッスンの検証では、両方が`<自分のユーザー名>2`に元からありました。複製する形はこのレッスンでは行っていません。未検証(2026-09-30時点))。
- `<自分のユーザー名>2`にソース物理ファイル`QRPGLESRC`があること。5250で`CHKOBJ OBJ(<自分のユーザー名>2/QRPGLESRC) OBJTYPE(*FILE)`と打って確かめ、無ければ、06-01bと同じ形で`CRTSRCPF FILE(<自分のユーザー名>2/QRPGLESRC) RCDLEN(112)`を実行します(検証では、検証の道具が用意しました。この形は、このレッスンの検証では確かめていません。未検証(2026-09-30時点))。
- `<自分のユーザー名>B`ライブラリーがあること(08-08で使ったもの。手順8の複製の置き場です。検証では、あるものを使いました。無い場合に作る形は、このレッスンでは確かめていません。未検証(2026-09-30時点))。
- `TXCKM`・`TXCHECK`が`<自分のユーザー名>2`にあること(10-01〜10-03で使ったもの)。
- SSHの`$HOME/ibmi-kyozai`が最新であること(`git pull`)。**`solutions/`が手元に無ければ**、[第9部の扉](../part09/index.md)の「解答ファイルの取得」と同じ、`cd $HOME/ibmi-kyozai && git sparse-checkout add solutions && git pull`を1回実行します(実機では未検証(2026-09-30時点))。

**警告(共有データ)**: 手順5は、`JUCHUM`・`JUCHUD`に受注`J09901`を書き込みます。途中でやめても、片付けの手順1の`DELETE`は必ず実行してください。

**なぜ`<自分のユーザー名>2`で行うのか**: 第10部は、本番役の`<自分のユーザー名>2`で作業する課題です。このレッスンの検証も、1つのライブラリーの中に、ルーチンもモックの表も`TXCKM`も置いて行い、バックアップだけを別のライブラリー(`<自分のユーザー名>B`に当たる)に置きました。**検証したのは著者の検証用ライブラリーで、あなたの`<自分のユーザー名>2`そのものでの再現は、個別には確認していません**(未検証(2026-09-30時点))。以下、`(SSH)`はSSH(`qsh`の中)、`(5250)`は5250の操作です。**検証は、バッチ・ジョブ(CLプログラムの中)と`db2`(SSH)で行いました。** 5250の対話式ジョブで打つ形は、実機では確かめていません。

1. **(SSH) 前提と件数を確かめます。**

   ```sh
   system "CHKOBJ OBJ(<自分のユーザー名>2/JUCSRV) OBJTYPE(*SRVPGM)"
   system "CHKOBJ OBJ(<自分のユーザー名>2/ZAISRV) OBJTYPE(*SRVPGM)"
   db2 "SELECT (SELECT COUNT(*) FROM <自分のユーザー名>2.JUCHUM) AS M, (SELECT COUNT(*) FROM <自分のユーザー名>2.JUCHUD) AS D, (SELECT COUNT(*) FROM <自分のユーザー名>2.ZAIKOM) AS Z FROM SYSIBM.SYSDUMMY1"
   ```

   期待される結果: `CHKOBJ`は、あればエラーなく終わります(無ければ`CPF9801`。一般知識、要確認。検証の道具は、実行前に両方があることを確かめました)。件数は、次のとおりです(値は検証のもの。桁の並びと改行位置は目安です)。

   ```text
   M           D           Z
   ----------- ----------- -----------
             8          12           6
   ```

   `8`・`12`・`6`でなければ、`TXRESET LIB(<自分のユーザー名>2)`で戻してから進めてください。

2. **(SSH) 09-04のルーチンと、09-05のモックを作ります。** 第9部の片付けを済ませていれば、`<自分のユーザー名>2`には何もありません。どちらも、`DFTRDBCOL`に`<自分のユーザー名>2`を指定します。`apimock.sql`は`CREATE OR REPLACE TABLE`なので、`APILOG`は空から始まります。以前の行が消えて構いません(第9部の`APILOG`の記録は、この表では取っておけません)。

   ```sh
   system "RUNSQLSTM SRCSTMF('$HOME/ibmi-kyozai/src/sql/09-04-routines.sql') COMMIT(*NONE) NAMING(*SQL) DFTRDBCOL(<自分のユーザー名>2) ERRLVL(40) OUTPUT(*PRINT)"
   system "RUNSQLSTM SRCSTMF('$HOME/ibmi-kyozai/db/mock/apimock.sql') COMMIT(*NONE) NAMING(*SQL) DFTRDBCOL(<自分のユーザー名>2) ERRLVL(40) OUTPUT(*PRINT)"
   ```

   期待される結果: 実行リスト(スプール)に、ルーチンごとの作成完了(関数は`SQL7997`)と、`APICFG`・`APIMOCK`・`APILOG`の作成(`SQL7905`は未ジャーナルの警告で、無視してよい。09-05)が出ます。09-04の`.sql`には、`ORDER_SUMMARY_JSON`は含まれません(09-07の`solutions/09-07`にあります)。**確認の範囲**: 検証では、この2つのファイルを、検証の道具が置いたコピー(CCSID 273のタグ)で実行しました。`git clone`したままのタグのファイルでの実行は、確認していません(09-04・09-05・09-07と同じ注意。未検証(2026-09-30時点))。

3. **アダプターのソースを取り込み(SSH)、コンパイルします(5250)。** 09-05の手順3・4と同じです。**先に3aを済ませてから、3bを打ちます。**

   3a. (SSH) ソースを取り込みます。

   ```sh
   system "CPYFRMSTMF FROMSTMF('$HOME/ibmi-kyozai/src/qrpglesrc/juhttpsv.sqlrpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>2.LIB/QRPGLESRC.FILE/JUHTTPSV.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

   09-05の手順3と同じ形です。この取り込みそのものは、検証では検証の道具が行ったので、確認していません。メンバーが無いときにこのコマンドが作るかどうかも、確かめていません(未検証(2026-09-30時点))。

   3b. (5250) コンパイルします。`CHGCURLIB`は、そのジョブの間だけ有効です。

   ```text
   CHGCURLIB CURLIB(<自分のユーザー名>2)
   CRTSQLRPGI OBJ(<自分のユーザー名>2/JUHTTPSV) SRCFILE(<自分のユーザー名>2/QRPGLESRC) SRCMBR(JUHTTPSV) OBJTYPE(*PGM) COMMIT(*NONE) REPLACE(*YES)
   ```

   期待される結果(ジョブ・ログ): `Program JUHTTPSV placed in library ... 00 highest severity.`(検証で確認)。

   **確認の範囲**: 検証では、`CHGCURLIB`のあとに、CLプログラムの中で同じコンパイルを実行しました。5250の対話式ジョブで打つ形は、確かめていません。

4. **(SSH) 操作1と警告を確かめます。**

   1. 受注`J00001`の照会。

      ```sh
      db2 "SELECT <自分のユーザー名>2.JUCHU_INQUIRY_JSON('J00001') AS J FROM SYSIBM.SYSDUMMY1"
      ```

      期待される結果(検証。バッチ・ジョブの`RUNSQL`(修飾あり)で表に入れて確かめた値です。上の`db2`の`SELECT`そのものは実行していません。未検証(2026-09-30時点)。1行が長いので、画面で折り返されることがあります):

      ```text
      {"orderNo":"J00001","customer":"C00001","customerName":"ACME TRADING CO","orderDate":20260901,"salesRep":"T00001","lines":[{"line":1,"product":"P00001","qty":2,"unitPrice":1580.00},{"line":2,"product":"P00003","qty":5,"unitPrice":480.00}]}
      ```

      `db2`の版によっては、長い列が途中で切れて表示されるかもしれません(この表示は確かめていません。JSONの長さも、記録していません)。切れたら、`LENGTH()`で長さを確認してください。

      `JSON_TABLE`で読み戻すと、2行(`P00001`が数量2、`P00003`が数量5)になりました(V2)。**存在しない受注番号**(`ZZZZZZ`)を渡すと、戻り値は**SQLのNULL**でした(空の文書でも、エラーでもありません。V2)。この振る舞いが、設計書の「2. 入力・出力の形」の「該当なし」と、「4. エラー・ステータスの規約」の「見つからない」の答えになります。確かめるには、次のようにします(検証は、この形の`COALESCE`を使い、`SQLNULL`が出ました。`db2`から打つ形そのものは、実行していません。未検証(2026-09-30時点))。

      ```sh
      db2 "SELECT COALESCE(<自分のユーザー名>2.JUCHU_INQUIRY_JSON('ZZZZZZ'), 'SQLNULL') AS J FROM SYSIBM.SYSDUMMY1"
      ```

   2. `LOW_STOCK`の2行(ライブラリーで修飾します)。

      ```sh
      db2 "SELECT PRODUCT_CODE, TRIM(PRODUCT_NAME) AS NAME, STOCK_QTY, REORDER_POINT FROM TABLE(<自分のユーザー名>2.LOW_STOCK()) X ORDER BY PRODUCT_CODE"
      ```

      期待される結果(値は、検証で`LOW_STOCK()`を読んだもの。上の`db2`の`ORDER BY`つきの形そのものは実行していません。未検証(2026-09-30時点)。表示の体裁は`db2`の版で違うことがあります):

      | PRODUCT_CODE | NAME | STOCK_QTY | REORDER_POINT |
      |---|---|---|---|
      | P00002 | OFFICE CHAIR | 3 | 5 |
      | P00005 | USB CABLE | 12 | 50 |

5. **(SSH) 操作2を確かめます(書く操作)。** 事前掃除のあと、1つのテキスト・リテラルで登録し、往復し、もう1度呼んで二重登録を確かめます(09-04と同じ形です)。

   ```sh
   db2 "DELETE FROM <自分のユーザー名>2.JUCHUD WHERE JUNO IN ('J09901', 'J09902', 'J09903')"
   db2 "DELETE FROM <自分のユーザー名>2.JUCHUM WHERE JUNO IN ('J09901', 'J09902', 'J09903')"
   db2 "CALL <自分のユーザー名>2.JUCHU_REGISTER('{\"orderNo\":\"J09901\",\"customer\":\"C00001\",\"orderDate\":20260930,\"salesRep\":\"T00001\",\"lines\":[{\"line\":1,\"product\":\"P00001\",\"qty\":2,\"unitPrice\":1580.00},{\"line\":2,\"product\":\"P00003\",\"qty\":5,\"unitPrice\":480.00}]}')"
   db2 "SELECT JUNO, JUTOK, JUDATE, JUTAN FROM <自分のユーザー名>2.JUCHUM WHERE JUNO = 'J09901'"
   db2 "SELECT JUNO, JULINE, JUSHO, JUSU, JUTNK FROM <自分のユーザー名>2.JUCHUD WHERE JUNO = 'J09901' ORDER BY JULINE"
   db2 "SELECT <自分のユーザー名>2.JUCHU_INQUIRY_JSON('J09901') FROM SYSIBM.SYSDUMMY1"
   ```

   最初の2つの`DELETE`は、行が無いと`SQLSTATE 02000`「Row not found for DELETE」を出しますが、エラーではありません(検証でも出ました。想定どおりの雑音です)。

   期待される結果(検証。ヘッダーと明細。値は検証のもの。桁の並びと改行位置は目安です):

   ```text
   J09901 C00001  20260930  T00001
   J09901    1    P00001      2    1580.00
   J09901    2    P00003      5     480.00
   ```

   往復の`JUCHU_INQUIRY_JSON('J09901')`は、`J00001`と同じ形で、`orderDate`が`20260930`のJSONを返しました(V2)。

   **同じ`CALL`をもう1回**実行します(二重登録)。

   ```sh
   db2 "CALL <自分のユーザー名>2.JUCHU_REGISTER('{\"orderNo\":\"J09901\",\"customer\":\"C00001\",\"orderDate\":20260930,\"salesRep\":\"T00001\",\"lines\":[{\"line\":1,\"product\":\"P00001\",\"qty\":2,\"unitPrice\":1580.00},{\"line\":2,\"product\":\"P00003\",\"qty\":5,\"unitPrice\":480.00}]}')"
   db2 "SELECT COUNT(*) AS N FROM <自分のユーザー名>2.JUCHUD WHERE JUNO = 'J09901'"
   db2 "SELECT COUNT(*) AS H FROM <自分のユーザー名>2.JUCHUM WHERE JUNO = 'J09901'"
   ```

   期待される結果(検証): 2回目の`CALL`は、`SQLSTATE: 75001`・`NATIVE ERROR CODE: -438`と、メッセージ`Order already exists`(`SIGNAL`で返したもの)で断られました。明細の件数`N`は**2のまま**、ヘッダーの件数`H`は**1**でした。これが、設計書の「8. 冪等性」の、「二重に呼ばれたとき」の答えです(受注番号で二重かどうかを見分け、拒否する)。**途中で失敗したときの原子性は、この呼び出しでは確かめていません**([09-04](../part09/09-04-api-boundary-sql-routines.md)で、2026-09-29に確認した、数値が文字列になった文書でヘッダーだけが残る例を参照してください)。

6. **(SSH と 5250) 操作3を確かめます。** 09-05と同じく、5250で`JUHTTPSV`を5つの郵便番号で呼びます(`APIMODE`が`MOCK`であること。`db2 "SELECT APIMODE FROM <自分のユーザー名>2.APICFG"`で確かめる。この`SELECT`そのものは実行していません。未検証(2026-09-30時点))。

   ```text
   CHGCURLIB CURLIB(<自分のユーザー名>2)
   CALL PGM(<自分のユーザー名>2/JUHTTPSV) PARM('1000001' '        ')
   CALL PGM(<自分のユーザー名>2/JUHTTPSV) PARM('9999999' '        ')
   CALL PGM(<自分のユーザー名>2/JUHTTPSV) PARM('9999504' '        ')
   CALL PGM(<自分のユーザー名>2/JUHTTPSV) PARM('9999404' '        ')
   CALL PGM(<自分のユーザー名>2/JUHTTPSV) PARM('1234567' '        ')
   ```

   **実通信(`REAL`)は、このレッスンでは行いません**(共有の練習機に、無用な通信をしないため。09-05の作法)。続けて、`APILOG`の中身を見ます。

   ```sh
   db2 "SELECT LOGID, APIMODE, ZIP, RC, HTTPST, RESPLEN, SQLST FROM <自分のユーザー名>2.APILOG ORDER BY LOGID"
   ```

   期待される結果(検証。`LOGID`の値は環境で違うので省き、呼んだ順に並べます。値は、検証で表に取り込んで読んだもの。上の`db2`の`SELECT`そのものは実行していません。未検証(2026-09-30時点)):

   | ZIP | RC | HTTPST | RESPLEN | SQLST |
   |---|---|---|---|---|
   | 1000001 | OK | 200 | 148 | 00000 |
   | 9999999 | OK | 200 | 46 | 00000 |
   | 9999504 | HTTPERR | 504 | 0 | 00000 |
   | 9999404 | HTTPERR | 404 | 0 | 00000 |
   | 1234567 | NOMOCK | 0 | 0 | 02000 |

   ここまでは09-05の再確認です。次に、判定のビューを作ります。`parse-zip.sql`(09-05の演習(b)の見本。`APIZIP`ビュー)を先に作り、続けて`validate-zip.sql`を実行します。

   ```sh
   system "RUNSQLSTM SRCSTMF('$HOME/ibmi-kyozai/solutions/09-05/parse-zip.sql') COMMIT(*NONE) NAMING(*SQL) DFTRDBCOL(<自分のユーザー名>2) ERRLVL(40) OUTPUT(*PRINT)"
   system "RUNSQLSTM SRCSTMF('$HOME/ibmi-kyozai/solutions/10-04/validate-zip.sql') COMMIT(*NONE) NAMING(*SQL) DFTRDBCOL(<自分のユーザー名>2) ERRLVL(40) OUTPUT(*PRINT)"
   db2 "SELECT ZIP, HTTPST, VERDICT FROM <自分のユーザー名>2.ZIPCHECK ORDER BY ZIP"
   db2 "SELECT LOGID, ZIP, RC, VERDICT FROM <自分のユーザー名>2.ZIPCHKLOG ORDER BY LOGID"
   ```

   `parse-zip.sql`は、最後に`SELECT`単独文を持つため、`RUNSQLSTM`が`SQL0084`を出します(既知で、無害。ビューは作られています)。`validate-zip.sql`の2つのビューは、エラーなく作れました(`SQL7951`。V2)。

   期待される結果(検証。値は、検証で表に取り込んで読んだもの。上の`db2`の`SELECT`そのものは実行していません。未検証(2026-09-30時点)):

   | ZIP | HTTPST | VERDICT(`ZIPCHECK`) |
   |---|---|---|
   | 1000001 | 200 | FOUND |
   | 9999404 | 404 | HTTPERR |
   | 9999504 | 504 | HTTPERR |
   | 9999999 | 200 | NOTFOUND |

   `ZIPCHKLOG`(呼んだ順)は、`1000001`が`FOUND`、`9999999`が`NOTFOUND`、`9999504`・`9999404`が`HTTPERR`、`1234567`が`NOMOCK`でした。`ZIPCHECK`には`1234567`の行が無い(モックに登録が無い)ので、`NOMOCK`は`ZIPCHKLOG`にだけ出ます。

7. **(SSH) 警告のJSONと、IFSへの書き出しを確かめます。**

   1. `LOWALERT`を作って、読みます(「説明」のとおり、`LOW_STOCK`を呼ばず、問い合わせを書き写した版です)。

      ```sh
      system "RUNSQLSTM SRCSTMF('$HOME/ibmi-kyozai/solutions/10-04/lowstock-alert.sql') COMMIT(*NONE) NAMING(*SQL) DFTRDBCOL(<自分のユーザー名>2) ERRLVL(40) OUTPUT(*PRINT)"
      db2 "SELECT ALERT_JSON FROM <自分のユーザー名>2.LOWALERT"
      ```

      期待される結果(検証。実行リストに`SQL7951`「View LOWALERT created」、`00 level severity errors found`。JSONは180文字):

      ```text
      {"alert":"LOW_STOCK","count":2,"items":[{"product":"P00002","name":"OFFICE CHAIR","stock":3,"reorderPoint":5},{"product":"P00005","name":"USB CABLE","stock":12,"reorderPoint":50}]}
      ```

      **0件のときの形は、まだ確かめていません**(下の「実機メモ」と演習(a)(e))。

   2. 出力先のディレクトリーを作り、`export-json.sql`を実行します。ファイルの1つ目の文(リテラルの`LINE`。相対パス`p1004lit.txt`)と、2つ目のプロシージャー`EXPORT_LOWSTOCK`の作成が含まれます。

      ```sh
      mkdir -p $HOME/work
      system "RUNSQLSTM SRCSTMF('$HOME/ibmi-kyozai/solutions/10-04/export-json.sql') COMMIT(*NONE) NAMING(*SQL) DFTRDBCOL(<自分のユーザー名>2) ERRLVL(40) OUTPUT(*PRINT)"
      ls -l $HOME/p1004lit.txt
      ```

      `mkdir -p $HOME/work`と、`$HOME/work/...`のパスは、このレッスンでの形です。検証では`$HOME/vfy/part10-04-checkpoint/`の下に書いたので、このとおりには実行していません(未検証(2026-09-30時点))。

      期待される結果: プロシージャーは`SQL7989`(作成)で、`ls -l`は**21バイト**のファイルを、ホーム・ディレクトリー(`/home/<自分のユーザー名>/`)の直下に示します。**スクリプトの隣ではなく、ホームに書かれます**(相対パスの罠。V2)。

   3. 列から取った値を、IFSに書き、読み戻します(絶対パスで指定します)。

      ```sh
      db2 "CALL <自分のユーザー名>2.EXPORT_LOWSTOCK('$HOME/work/lowstock.json')"
      ls -l $HOME/work/lowstock.json
      db2 "SELECT LINE_NUMBER, LINE FROM TABLE(QSYS2.IFS_READ_UTF8(PATH_NAME => '$HOME/work/lowstock.json'))"
      ```

      期待される結果(検証): ファイルは**180バイト**。読み戻しは1行(`LINE_NUMBER`が1、長さ180)で、上の`LOWALERT`のJSONと同じでした。`JSON_TABLE`で読み戻すと、`P00002`・`P00005`の2件(`count`が2)でした。

      `EXPORT_LOWSTOCK`は、SQLプロシージャーの中で、ビューの列の値を変数に入れて`IFS_WRITE_UTF8`に渡す形です。スカラーの副問い合わせを直接`LINE`に渡す形(`LINE => (SELECT ALERT_JSON FROM ...LOWALERT)`)も、`db2`から書けました(180バイト。V2)。

   4. (任意)長さの確認。`LINE`は、`VARCHAR(4000)`の列の上限を超える20000バイトでも書けます。

      ```sh
      db2 "CALL QSYS2.IFS_WRITE_UTF8(PATH_NAME => '$HOME/work/l3000.txt', LINE => REPEAT('A', 3000), OVERWRITE => 'REPLACE', END_OF_LINE => 'NONE')"
      db2 "CALL QSYS2.IFS_WRITE_UTF8(PATH_NAME => '$HOME/work/l20000.txt', LINE => REPEAT('A', 20000), OVERWRITE => 'REPLACE', END_OF_LINE => 'NONE')"
      ls -l $HOME/work/l3000.txt $HOME/work/l20000.txt
      ```

      期待される結果(検証): 3000バイトと20000バイト。**20000バイトを超える長さは、試していません**(未検証(2026-09-30時点))。

8. **(5250) 昇格の予行: `ZAISRV`・`JUCSRV`を、複製して、消して、戻します。** 08-08の「複製してから消す」順の練習です。**複製の確認(`CHKOBJ`)が成功してから、元を消します。** 複製が無いのに元を消すと、元を失います。まず、古い複製の削除(あれば)から始めます。

   ```text
   DLTSRVPGM SRVPGM(<自分のユーザー名>B/ZAISRVP)
   CRTDUPOBJ OBJ(ZAISRV) FROMLIB(<自分のユーザー名>2) OBJTYPE(*SRVPGM) TOLIB(<自分のユーザー名>B) NEWOBJ(ZAISRVP)
   CHKOBJ OBJ(<自分のユーザー名>B/ZAISRVP) OBJTYPE(*SRVPGM)
   ```

   ここまでで`CHKOBJ`がエラーなく終わった場合だけ、次へ進みます。**この間、手順2のルーチン(`GETCUSTNM`など)は登録されたままです。** 元の`ZAISRV`を消すと、そのルーチンは、戻すまで動かないおそれがあります(このレッスンの検証では、この間にルーチンを呼んでいません。未検証(2026-09-30時点))。

   ```text
   DLTSRVPGM SRVPGM(<自分のユーザー名>2/ZAISRV)
   CRTDUPOBJ OBJ(ZAISRVP) FROMLIB(<自分のユーザー名>B) OBJTYPE(*SRVPGM) TOLIB(<自分のユーザー名>2) NEWOBJ(ZAISRV)
   CHKOBJ OBJ(<自分のユーザー名>2/ZAISRV) OBJTYPE(*SRVPGM)
   ```

   **戻しの`CRTDUPOBJ`か`CHKOBJ`が失敗したら、先へ進まず**、`<自分のユーザー名>B/ZAISRVP`が残っていることを`CHKOBJ`で確かめ、同じ`CRTDUPOBJ`(`FROMLIB(<自分のユーザー名>B)`)をもう一度実行します。複製が残っている間は、元に戻せます。この復旧の操作は、検証では必要にならず、行っていません(未検証(2026-09-30時点))。

   `JUCSRV`も、名前を`JUCSRV`・`JUCSRVP`に替えて、同じ手順(古い複製の削除から、戻したあとの`CHKOBJ`まで)を実行します。

   期待される結果(検証。CLプログラムの中で実行): 両方とも、複製・削除・戻しがエラーなく終わり、`OBJECT_STATISTICS`で`ZAISRV`・`JUCSRV`が`*SRVPGM`として見えました。**最初の`DLTSRVPGM`は、古い複製が無ければ`CPF2105`(オブジェクトが見つからない)になります。想定どおりの雑音です**(検証でも出ました)。副作用として、**作り直した`ZAISRV`・`JUCSRV`の作成日時が新しくなります**(検証で確認。中の`*MODULE`の日時は変わりませんでした)。切り戻しは、この操作の逆(複製から戻す)で、08-08のとおりです。

   **確認の範囲**: 検証したのは、**同じライブラリーの中での複製・削除・戻し**です。`<自分のユーザー名>1`から`<自分のユーザー名>2`へ複製して昇格する形は、08-08で行いました。このレッスンの検証では、行っていません(未検証(2026-09-30時点))。**作り直したあとの`ZAISRV`・`JUCSRV`を使うルーチン(`GETCUSTNM`など、`LANGUAGE RPGLE`で登録した関数)を、もう1度呼ぶことは、確かめていません**(未検証(2026-09-30時点))。サービス・プログラムを作り直すと、登録が影響を受けるおそれがあります([第9部の扉](../part09/index.md)の、`SQL7909`の注意)。

9. **(SSH) `TXCKM`に`10-04`の4行を登録します。** 二重登録を避けるため、まず消してから入れます(09-07の手順7と同じ形)。

   ```sh
   db2 "DELETE FROM <自分のユーザー名>2.TXCKM WHERE LESSON = '10-04'"
   db2 "INSERT INTO <自分のユーザー名>2.TXCKM (LESSON, SEQNBR, OBJNAME, OBJTYPE, OBJATTR, CKDESC) VALUES ('10-04', 10, 'JUHTTPSV', '*PGM', ' ', 'JUHTTPSV adapter exists'), ('10-04', 20, 'APIMOCK', '*FILE', ' ', 'APIMOCK mock table exists'), ('10-04', 30, 'ZAISRV', '*SRVPGM', ' ', 'ZAISRV service program exists'), ('10-04', 40, 'JUCSRV', '*SRVPGM', ' ', 'JUCSRV service program exists')"
   ```

   `TXCKM`は、`CHKOBJ`で確かめられる**オブジェクト**の存在と型だけを検査します。SQLルーチン(関数・プロシージャー・ビュー)は、そのままでは`CHKOBJ`で確かめられないものがあるため、`TXCKM`には入れません(ルーチンの確認は、片付けの`SYSROUTINES`の問い合わせで行います)。**この`INSERT`文そのものは実行していません**(未検証(2026-09-30時点))。検証では、同じ4行を、CLプログラムの中の`RUNSQL`で入れました。

10. **(5250) `*CMD`経由で`TXCHECK`を、新しいジョブで1回だけ実行します。** `CALL`ではなく、コマンドとして打ちます(05-13・07-05・08-08・09-07と同じ)。まず、いったんサインオフして、サインオンし直します(新しいジョブになります)。この時点で`TXCHECK`をまだ1回も打っていなければ、そのまま1回だけ打っても構いません。サインオフで`CHGCURLIB`は戻りますが、下のコマンドは`LIB(<自分のユーザー名>2)`を明示しているので、そのまま実行できます(5250で直接打つ形は、検証では確かめていません。未検証(2026-09-30時点))。

    ```text
    TXCHECK LESSON('10-04') LIB(<自分のユーザー名>2)
    ```

    期待される結果(検証。ジョブ・ログ。`CKDESC`は手順9で入れた文字列です。値は検証のもの。改行位置は目安です):

    ```text
    TXCHECK PASS: JUHTTPSV adapter exists
    TXCHECK PASS: APIMOCK mock table exists
    TXCHECK PASS: ZAISRV service program exists
    TXCHECK PASS: JUCSRV service program exists
    TXCHECK: lesson 10-04 - 0000000004 passed,
    0000000000 failed.
    ```

    **PASSが4件、failedが0件**が確認した形です。検証は、CLプログラムの中から、`TXCHKRUN`というヘルパー(`QCMDEXC`でコマンド文字列を実行する検証用の道具で、教材の一部ではありません)経由で、**1回だけ**行いました。**5250のコマンド行に直接打った実行と、同じジョブでの2回目の呼び出しは、このレッスンの検証では確かめていません**(同じジョブの2回目が`CPF4174`になることは、08-08・09-07で確認した既知の不具合で、このレッスンの検証では2回目を呼んでいません)。

11. **(PCのエディター) 設計書を書きます。** ここが、このレッスンの中心です(所要時間の約60分)。テンプレート([`docs/templates/api-design.md`](../templates/api-design.md))を自分のファイルにコピーし、**3つの操作**について、11節すべてを埋めます。ここまでの手順の結果が、「10. テスト証拠」の材料です。**書き終えるまで、`solutions/10-04/api-design-filled.md`(記入例)を開かないでください**(先に読むと、演習の意味がなくなります。模範解答を見るかどうかは、あなた自身の判断に任せる、名誉制です)。`ls solutions/10-04`には`api-design-filled.md`が並びます。名前だけを見るのは構いませんが、中身は、設計書を書き終えるまで開かないでください。

    次の点を守ります。

    - 3つの操作を、節ごとに書き分ける(1つの表にまとめてもよい)。
    - 「8. 冪等性」の操作2に、「二重に呼ばれたとき」と「途中で失敗したとき」の両方を書く。
    - 「10. テスト証拠」の各行に、方法・結果・日付(と、バッチ名か手順の番号)を書く。確かめていない行は、空欄にせず「未検証(日付時点)」と書く。5250の対話式ジョブでの結果と、バッチ・`db2`での結果は書き分ける。
    - 「3. 業務ロジックの置き場所」に、`LOWALERT`が問い合わせを書き写した理由(SQLパス)と、二重保守の代償を書く。
    - 実在のユーザー名・ライブラリー名・メール・アドレスを書かない(`<自分のユーザー名>2`のような表記にする)。

## 出会うメッセージID

この表のうち、`SQL0204`(ビュー)・`SQL7951`・`SQL7997`・`SQL7989`・`SQL0084`・`75001`・`02000`・`CPF2105`は、`part10-04-checkpoint`(2026-09-30、V2)で出会ったものです。`SQL7905`は09-05、`CPF4174`は08-08、`CPF9801`は前のレッスンで確認したもので、このレッスンの検証では出ていません。

| ID | 原因 | 対処 |
|---|---|---|
| `SQL0204`(`LOW_STOCK in *LIBL type *N not found`) | ビューの中で`LOW_STOCK()`を無修飾で呼んだ。`DFTRDBCOL`はSQLパスではない | 問い合わせを書き写す(配布の版)か、ライブラリーを付けて呼ぶ |
| `SQL7951` | ビューを作った(View ... created) | 作れた印。何もしない |
| `SQL7997`・`SQL7989` | 関数を作った・プロシージャーを作った | 作れた印。何もしない |
| `SQL7905`(重大度20) | ジャーナルなしで表を作った警告 | 無視してよい(09-05) |
| `SQL0084` | `RUNSQLSTM`が、`SELECT`単独文を実行した(`parse-zip.sql`の末尾) | 既知で無害。結果は`db2`で見る |
| `SQLSTATE 75001`(`NATIVE ERROR CODE -438`) | `JUCHU_REGISTER`が、同じ受注番号の2回目を断った(`SIGNAL`) | 想定どおり。設計書の「8. 冪等性」に書く |
| `SQLSTATE 02000` 「Row not found for DELETE」 | 事前掃除の`DELETE`で、消す行が無かった | 想定どおり。エラーではない |
| `CPF2105` | 存在しない古い複製(`ZAISRVP`・`JUCSRVP`)を`DLTSRVPGM`した | 想定どおり |
| `CPF9801` | `CHKOBJ`が、オブジェクトを見つけられない(前のレッスンで確認) | オブジェクトの綴り・ライブラリーを確かめる |
| `CPF4174`「OPNID(TXCKM) ... already exists」 | 同じジョブで2回目の`TXCHECK`(08-08で見つかった既知の不具合) | 新しいジョブで1回だけ実行する |

メッセージ全般は[付録B](../appendix/b-message-ids.md)・[付録C](../appendix/c-troubleshooting.md)も参照してください。

## 出力が違うとき

- **`LOWALERT`の作成で`SQL0204`になる。** ビューの中で`LOW_STOCK()`を無修飾で呼んでいませんか。配布の`lowstock-alert.sql`は、問い合わせを書き写してあり、ルーチン名を含みません。自分で書き換えたなら、元に戻すか、ライブラリーを付けます。
- **`LOWALERT`のJSONで、`count`が2ではない。** `ZAIKOM`の在庫が初期状態と違います。`TXRESET LIB(<自分のユーザー名>2)`で戻します。
- **`ZIPCHKLOG`が空、または`ZIPCHECK`の`FOUND`が出ない。** `JUHTTPSV`を呼ぶ前に`ZIPCHKLOG`を見ていないか(`APILOG`が空)、`parse-zip.sql`を先に実行したか、`APIMODE`が`MOCK`か、を確かめます。呼んだのと同じジョブ(`CHGCURLIB`のあと)で`CALL`したかも確かめます(09-05)。
- **`EXPORT_LOWSTOCK`の実行で、パスが見つからない。** 出力先のディレクトリー(`$HOME/work`)を`mkdir`しましたか。ディレクトリーが無いと失敗すると考えられます。この教材では試していません(未検証(2026-09-30時点))。
- **書き出したはずのファイルが、`export-json.sql`のある場所に無い。** 相対パスは、ジョブのホーム・ディレクトリーに書かれます。絶対パスにしてください。
- **`ls`で見るバイト数が、期待と違う。** 改行を付けていない(`END_OF_LINE => 'NONE'`)ので、`LOWALERT`のJSONは180バイトです。`OVERWRITE`が`REPLACE`でないと、追記や失敗になるかもしれません(確かめていません。未検証(2026-09-30時点))。
- **`od`でファイルを見ると、文字が違って見える。** `od`では別の文字に見えることがありました(画面上の見え方と考えられます。原因は確認していません)。確認には`IFS_READ_UTF8`を使ってください。
- **`JUCHU_REGISTER`の2回目で、エラーが出ない。** 1回目が実際には失敗していて、2回目が初めての登録になっている可能性があります。ヘッダー・明細の件数を確かめてください。
- **`TXCHECK`にFAILが混じる。** `JUHTTPSV`(`*PGM`)・`APIMOCK`(`*FILE`)・`ZAISRV`・`JUCSRV`(`*SRVPGM`)が、`LIB(...)`に指定したライブラリーにあるかを、`CHKOBJ`で確かめます。
- **`TXCHECK`が「could not query the manifest」になる。** 同じジョブで2回目に呼んでいます。サインオフして、サインオンし直し、新しいジョブで1回だけ打ちます(08-08の提案)。
- **この教材の値と、日付や桁が違う。** 受注日・作成日時・`LOGID`・オブジェクトの日時は環境で違います。JSONの形・件数・`RC`・`SQLSTATE`が合っていれば、問題ありません。

## 演習

例題を読む → 穴埋め → 独力 → 応用、の順です。解答は、下の`<details>`にあります。演習(b)の解答は、演習(c)を書いた後に開いてください(設計書の書き分けの答えの一部が入っています)。

### 演習(a): 例題を読む(紙の上)

1. 最初の版の`LOWALERT`は、`LOW_STOCK()`を無修飾で呼んで、`RUNSQLSTM`で`SQL0204`になりました。`LOW_STOCK`は、直前に同じライブラリーに作ってありました。それなのに見つからなかったのは、なぜですか。
2. 配布の`LOWALERT`は、問い合わせを書き写して、この失敗を避けています。それによって、設計書の「3. 業務ロジックの置き場所」に、何を書き足す必要が生じますか。
3. `ZIPCHECK`は、`LOCATE('"address1"', BODY)`で住所の有無を判定しています。日本語の住所の文字列を比べる判定にしなかったのは、なぜですか。

<details><summary>解答例</summary>

1. `DFTRDBCOL`は、表などの既定のスキーマを決めるもので、SQLパス(ルーチン名を探す場所)ではないからです。実行リストのSQLパスに、開発ライブラリーは入っていませんでした(実機で確認)。ルーチンの名前を探す場所に、ライブラリーが入っていなかった、ということです。
2. 「発注点を下回る」の条件が、`LOW_STOCK`とビューの2か所にあること(二重保守の芽)。条件を変えるときは、両方を直す必要があること。抑え方の案として、ライブラリーを付けて`LOW_STOCK`を呼ぶ形にすると1か所になるが、ソースにライブラリー名を書き込むことになり、この教材の決まりに反する、というトレードオフも書けます。
3. 日本語の住所を、ジョブのCCSIDの列に取り出すと`3F3F3F`になり、比較に使えなかったからです(09-05で確認)。存在だけを見れば、文字コードに依存しません。

</details>

### 演習(b): 穴埋め — テスト証拠の表

次は、手順の途中で得た観察のメモです。これを、「10. テスト証拠」の行として書くと、**確認済みの行**と**未検証の行**に分かれます。表の`____`を埋めてください。

| 確かめたこと | 方法 | 結果 | 日付・出典 |
|---|---|---|---|
| `J00001`の照会 | `db2`(または`RUNSQL`)で`JUCHU_INQUIRY_JSON('J00001')` | ____ | 2026-09-30・`part10-04-checkpoint` |
| 存在しない受注番号 | `COALESCE(JUCHU_INQUIRY_JSON('ZZZZZZ'), 'SQLNULL')` | ____ | 2026-09-30・`part10-04-checkpoint` |
| 二重登録 | 同じ`JUCHU_REGISTER`をもう1回 | ____ | 2026-09-30・`part10-04-checkpoint` |
| 0件のときの`LOWALERT` | (ビューそのものは0件で実行していない) | ____ | ____ |
| 5250のコマンド行に直接打った`TXCHECK` | (未実施) | ____ | ____ |
| ACS・VS Codeからの呼び出し | (未実施) | ____ | ____ |

<details><summary>解答例</summary>

| 確かめたこと | 方法 | 結果 | 日付・出典 |
|---|---|---|---|
| `J00001`の照会 | 同上 | 受注のJSONが返り、`JSON_TABLE`で明細2行(`P00001`が数量2、`P00003`が数量5)に読み戻せた | 2026-09-30・`part10-04-checkpoint` |
| 存在しない受注番号 | 同上 | SQLのNULLが返った(`SQLNULL`) | 同上 |
| 二重登録 | 同上 | `SQLSTATE 75001`(`-438`)で断られ、明細は2件・ヘッダーは1件のまま | 同上 |
| 0件のときの`LOWALERT` | 同上 | 未検証(2026-09-30時点)。`WHERE 1 = 0`の複製(`LOW_STOCK`を呼ぶ)で`{"count":0,"items":null}`が返ったが、ビューそのものは0件で実行していない | 未検証(2026-09-30時点) |
| 5250のコマンド行に直接打った`TXCHECK` | 同上 | 未検証(2026-09-30時点)(確認したのは`TXCHKRUN`経由の1回で、4件PASS・failed 0) | 未検証(2026-09-30時点) |
| ACS・VS Codeからの呼び出し | 同上 | 未検証(2026-09-30時点)。V3 | (あなたの環境で確かめ、日付と結果を書く) |

「0件のとき」の行のように、**近い実験(複製での結果)は、証拠として書いてよいが、確かめたものそのものとは書かない**、というのが、この表の作法です。

</details>

### 演習(c): 独力 — 3つの操作の公開設計書を書く

実演の手順11の要領で、受注の照会・受注の登録・郵便番号の検証の**3つの操作**の公開設計書を、11節すべて書いてください。模範解答は、`solutions/10-04/api-design-filled.md`にあります(書き終えてから読み、自分の設計書と見比べてください)。採点表で、自分で採点します。

### 演習(d): 応用 — 第10部の振り返りを書く

下の「まとめ」の「第10部全体の振り返り」の表に、7つの目標のそれぞれについて、**自己評価**(扉の評価表の段階)と、**根拠**(あなたが実際に確かめたこと。1行)を書いてください。根拠は、「〜できたと感じる」ではなく、「〜を実行して、〜が出た」の形にします。1つだけ、「もう1度やるなら、ここを変える」という点も書きます。表は、自分のPC側のテキストに写して(設計書と同じ場所)書き込みます。教材のファイル自体は編集しません。

### 演習(e): 応用 — 0件のときの警告を、確かめる設計をする(紙の上、任意)

`LOWALERT`ビューそのものが、0件のときに出すJSONは、確かめていません。`ZAIKOM`を書き換えずに、これを確かめる方法を考えてください(ヒント: 共有のデータを書き換えない・元に戻せる・消す手間が小さい)。検証では、次の形の**複製**で、`{"count":0,"items":null}`が出ました。ただし、これは`LOW_STOCK`を呼ぶ複製であり、ビューそのものではありません。

```sql
SELECT CAST(JSON_OBJECT('count': (SELECT COUNT(*) FROM TABLE(<自分のユーザー名>2.LOW_STOCK()) L WHERE 1 = 0), 'items': (SELECT JSON_ARRAYAGG(JSON_OBJECT('product': L.PRODUCT_CODE)) FROM TABLE(<自分のユーザー名>2.LOW_STOCK()) L WHERE 1 = 0) FORMAT JSON) AS VARCHAR(4000) CCSID 1208) FROM SYSIBM.SYSDUMMY1
```

<details><summary>解答例</summary>

考えられる方法の例: ビューの複製(別名、例えば`W1004A`のような自分用の名前)を作り、`WHERE`に常に偽になる条件(`Z.ZASU < S.SHOHAT AND 1 = 0`)を足して、0件のときの形を確かめる。この形も、ビューそのものではなく複製なので、設計書には「複製で確かめた」と書きます。`JSON_ARRAYAGG`が0行のとき`NULL`を返すことは、上の実験で確認しています(`items`が`null`)。呼び出し元は、`items`が配列のときと`null`のときの両方を受け取れるように書く、というのが設計書の「2. 入力・出力の形」に入れる内容です(09-07の`latestOrders`と同じ)。**この複製のビューは、実行していません**(未検証(2026-09-30時点))。作ったら、片付けで`DROP VIEW`してください。

</details>

### 採点表

自分で採点してください。「◯」の数ではなく、理由を説明できるかを重視してください。**部の扉の評価表の3つの必須の点検項目(ソースにライブラリー名で修飾した記述がない・ASCIIだけで書いている・片付けを終えている)も、あわせて確かめてください。`TXCHECK`は、これらを確かめられません**([第10部の扉](index.md))。

| 観点 | 基準 | 自己採点(◯・△・×) |
|---|---|---|
| 3つの操作の設計書 | 3つの操作それぞれについて、テンプレート11節すべてに、答えか「未検証」がある。空欄が無い | |
| 冪等性 | 操作2に、「二重に呼ばれたとき(`75001`で拒否)」と「途中で失敗したとき(原子性が無い)」の両方を書き、自動の再試行で復旧できないことを説明できる | |
| 「該当なし」の扱い | 操作1(存在しない受注番号はSQLのNULL)と操作3(`NOTFOUND`は正常系)の扱いを、実機の結果に基づいて書いた | |
| 業務ロジックの置き場所 | `LOWALERT`が問い合わせを書き写した理由(SQLパス)と、二重保守の代償を書いた | |
| テスト証拠 | 各行に方法・結果・日付がある。近い実験(複製)を、確かめたものそのものと書いていない。5250の対話式ジョブの結果と、バッチ・`db2`の結果を書き分けた | |
| 接着部品の実行 | `LOWALERT`が180文字・`count`2、`ZIPCHECK`・`ZIPCHKLOG`の判定、IFSの書き出しと`IFS_READ_UTF8`での読み戻しを確かめた | |
| IFSの相対パス | 相対パスがホームに書かれること、絶対パスで指定する理由を言える | |
| 昇格の予行 | 複製の確認(`CHKOBJ`)を先にしてから元を消した。切り戻しの向きを説明できる。作り直したあとのルーチンを呼んだ結果は、確かめていないと言える | |
| `TXCHECK` | 4件PASS・failed 0を、新しいジョブで1回だけ確かめた。2回目の`CPF4174`が、失敗でないことを説明できる | |
| 公開の判断 | 設計書に、実在のユーザー名・ライブラリー名・メール・アドレスが入っていない | |
| 振り返り | 7つの目標のそれぞれに、自己評価と、実行して確かめた根拠が1行ずつある | |

## セルフチェック

- [ ] 手順1で、件数が8・12・6であることを確かめてから、操作を呼んだ。
- [ ] `JUCHU_INQUIRY_JSON('J00001')`のJSONと、存在しない受注番号がSQLのNULLになることを確かめた。
- [ ] `LOW_STOCK`が2行(`P00002`・`P00005`)を返し、`LOWALERT`が`count`2・180文字のJSONを返すことを確かめた。
- [ ] `JUCHU_REGISTER`の二重登録が`SQLSTATE 75001`で断られ、明細が2件・ヘッダーが1件のままであることを確かめた。
- [ ] `JUHTTPSV`を5つの郵便番号で呼び、`APILOG`と`ZIPCHECK`・`ZIPCHKLOG`の判定が、期待どおりであることを確かめた。実通信をしていない。
- [ ] `EXPORT_LOWSTOCK`でJSONを書き、`ls -l`で180バイト、`IFS_READ_UTF8`で同じ内容を確かめた。相対パスがホームに書かれることを確かめた。
- [ ] 昇格の予行で、複製の確認を済ませてから元を消し、戻した。
- [ ] `TXCKM`に4行を登録し、新しいジョブで`TXCHECK LESSON('10-04') LIB(<自分のユーザー名>2)`を1回だけ実行して、4件PASS・failed 0を確かめた。
- [ ] 3つの操作の設計書を、11節すべて書き、確かめていない項目に「未検証」と書いた。
- [ ] 第10部の7つの目標の振り返りを書いた。
- [ ] 片付けで、ルーチン・ビュー・表・`JUHTTPSV`・受注`J09901`・`TXCKM`の`10-04`の行・複製・IFSのファイルを消し、確認の問い合わせで、`SYSROUTINES`が0件、件数が8・12・6であることを確かめた。

## 片付け

このレッスンで作ったものを、次の順で削除します。**`ZAISRV`・`JUCSRV`は、消しません**(昇格の予行で作り直したものが、`<自分のユーザー名>2`に残ります。08-08で昇格した、あなたの本番役のものです。10-03の`makei`が`<自分のユーザー名>B`に作った`ZAISRV`は、10-03の片付けで消えています)。`TXCKM`・`TXCHECK`のような共有の道具・`JUCHUM`・`JUCHUD`・`ZAIKOM`・`SHOHIM`も消しません。

1. **(SSH) 受注`J09901`の行を消し、件数を確かめます。**

   ```sh
   db2 "DELETE FROM <自分のユーザー名>2.JUCHUD WHERE JUNO IN ('J09901', 'J09902', 'J09903')"
   db2 "DELETE FROM <自分のユーザー名>2.JUCHUM WHERE JUNO IN ('J09901', 'J09902', 'J09903')"
   db2 "SELECT (SELECT COUNT(*) FROM <自分のユーザー名>2.JUCHUM) AS M, (SELECT COUNT(*) FROM <自分のユーザー名>2.JUCHUD) AS D, (SELECT COUNT(*) FROM <自分のユーザー名>2.ZAIKOM) AS Z FROM SYSIBM.SYSDUMMY1"
   ```

   期待される結果(検証): `8`・`12`・`6`。

2. **(SSH) ビューを、依存の逆順に消します。** `ZIPCHKLOG`が`APIZIP`を使い、`EXPORT_LOWSTOCK`が`LOWALERT`を使うので、使う側から消します。

   ```sh
   db2 "DROP VIEW <自分のユーザー名>2.ZIPCHKLOG"
   db2 "DROP VIEW <自分のユーザー名>2.ZIPCHECK"
   db2 "DROP VIEW <自分のユーザー名>2.APIZIP"
   db2 "DROP SPECIFIC PROCEDURE <自分のユーザー名>2.EXPLOWJSN"
   db2 "DROP VIEW <自分のユーザー名>2.LOWALERT"
   ```

3. **(SSH) 09-04のルーチンを、`SPECIFIC`名で消します。** `SPECIFIC`名も、ライブラリーで修飾します(しないと`SQL0455`。09-04)。

   ```sh
   db2 "DROP SPECIFIC PROCEDURE <自分のユーザー名>2.JUCHUREGST"
   db2 "DROP SPECIFIC PROCEDURE <自分のユーザー名>2.LOWSTOCKRS"
   db2 "DROP SPECIFIC FUNCTION <自分のユーザー名>2.LOWSTOCKT"
   db2 "DROP SPECIFIC FUNCTION <自分のユーザー名>2.JUCHUINQJS"
   db2 "DROP SPECIFIC FUNCTION <自分のユーザー名>2.GETSTOCKQT"
   db2 "DROP SPECIFIC FUNCTION <自分のユーザー名>2.CNTCUSTORD"
   db2 "DROP SPECIFIC FUNCTION <自分のユーザー名>2.GETCUSTNM"
   ```

   期待される結果(検証): それぞれ`DB20000I`(成功)。演習(e)で作ったビューがあれば、それも`DROP VIEW`します。

4. **(SSH) 表・プログラム・`TXCKM`の行を消します。**

   ```sh
   system "RUNSQL SQL('DROP TABLE <自分のユーザー名>2/APILOG') COMMIT(*NONE)"
   system "RUNSQL SQL('DROP TABLE <自分のユーザー名>2/APIMOCK') COMMIT(*NONE)"
   system "RUNSQL SQL('DROP TABLE <自分のユーザー名>2/APICFG') COMMIT(*NONE)"
   system "DLTPGM PGM(<自分のユーザー名>2/JUHTTPSV)"
   system "RMVM FILE(<自分のユーザー名>2/QRPGLESRC) MBR(JUHTTPSV)"
   system "RUNSQL SQL('DELETE FROM <自分のユーザー名>2/TXCKM WHERE LESSON = ''10-04''') COMMIT(*NONE)"
   ```

5. **(SSH) 昇格の予行の複製を消します。** **本体(`ZAISRV`・`JUCSRV`)が`<自分のユーザー名>2`にあることを確かめてから**、複製を消します(`&&`で、確認が成功したときだけ消します)。

   ```sh
   system "CHKOBJ OBJ(<自分のユーザー名>2/ZAISRV) OBJTYPE(*SRVPGM)" && system "DLTSRVPGM SRVPGM(<自分のユーザー名>B/ZAISRVP)"
   system "CHKOBJ OBJ(<自分のユーザー名>2/JUCSRV) OBJTYPE(*SRVPGM)" && system "DLTSRVPGM SRVPGM(<自分のユーザー名>B/JUCSRVP)"
   ```

6. **(SSH) IFSのテスト・ファイルを消します。**

   ```sh
   rm -f $HOME/p1004lit.txt $HOME/work/lowstock.json $HOME/work/l3000.txt $HOME/work/l20000.txt
   ```

   (`$HOME/work`ディレクトリーを、このレッスンのために作った場合は、中身が空であることを確かめてから、`rmdir $HOME/work`で消します。09-02の`w.json`など、ほかの用途で使っていれば、残します。)

7. **(SSH) 確認します。** 検証の最後の照会と同じ形です。

   ```sh
   db2 "SELECT COUNT(*) AS ROUTINES_LEFT FROM QSYS2.SYSROUTINES WHERE SPECIFIC_SCHEMA = '<自分のユーザー名>2' AND SPECIFIC_NAME IN ('JUCHUINQJS', 'LOWSTOCKT', 'LOWSTOCKRS', 'JUCHUREGST', 'EXPLOWJSN', 'GETSTOCKQT', 'CNTCUSTORD', 'GETCUSTNM')"
   db2 "SELECT OBJNAME, OBJTYPE FROM TABLE(QSYS2.OBJECT_STATISTICS('<自分のユーザー名>2', '*ALL')) X WHERE OBJNAME IN ('LOWALERT', 'ZIPCHECK', 'ZIPCHKLOG', 'APIZIP', 'APIMOCK', 'APILOG', 'APICFG', 'JUHTTPSV') ORDER BY OBJNAME"
   db2 "SELECT OBJNAME, OBJTYPE FROM TABLE(QSYS2.OBJECT_STATISTICS('<自分のユーザー名>B', '*ALL')) X WHERE OBJNAME IN ('ZAISRVP', 'JUCSRVP') ORDER BY OBJNAME"
   db2 "SELECT COUNT(*) AS TXCKM_1004_LEFT FROM <自分のユーザー名>2.TXCKM WHERE LESSON = '10-04'"
   ```

   期待される結果(検証): 1つ目が`0`、2つ目と3つ目が0行、4つ目が`0`。`ZAISRV`・`JUCSRV`が`*SRVPGM`として残っていることは、次で確かめます(作成日時は、昇格の予行で新しくなっています)。

   ```sh
   db2 "SELECT OBJNAME, OBJTYPE FROM TABLE(QSYS2.OBJECT_STATISTICS('<自分のユーザー名>2', '*ALL')) X WHERE OBJNAME IN ('ZAISRV', 'JUCSRV') ORDER BY OBJNAME"
   ```

8. **スプール・ファイル。** `RUNSQLSTM ... OUTPUT(*PRINT)`は、実行リストのスプール・ファイルを作ります(コンパイル・リストも残るかもしれません)。5250の`WRKSPLF`で見て、不要なら`4`(削除)を入力します。**`CHGCURLIB`を打った場合**は、サインオフで元に戻ります(そのジョブの間だけの変更)。

**第10部全体の片付けの一覧は、[扉ページ](index.md)の「片付け」の表にあります。** 削除の手順は、各レッスンの「片付け」が正で、表は点検用の索引です。第10部全体の最後に、次を確かめます。

- `JUCHUM`・`JUCHUD`・`ZAIKOM`が8・12・6件(または、あなたが10-01〜10-03のあとに決めた基準の値)に戻っている。
- `QSYS2.SYSROUTINES`に、あなたのライブラリーの、このレッスンのルーチンが残っていない(上の手順7の1つ目)。
- 各レッスンの`TXCKM`の行(`10-01`〜`10-04`)を、共有の道具は残して、レッスンごとの行だけ消したか(消すかどうかは、扉の一覧に従う)。

**この片付けのうち、`WRKSPLF`での削除・`rmdir`・演習(e)のビューの削除・手順5の`&&`による条件付きの削除・`RMVM`のSSHからの実行は、学習者環境では未試行です**(未検証(2026-09-30時点))。

## まとめ

| 英語 | 日本語 |
|---|---|
| Idempotent | 冪等(同じ呼び出しを繰り返しても、結果や副作用が変わらない) |
| Test evidence | テスト証拠(いつ・何で・どの結果を確かめたかの記録) |
| SQL path | SQLパス(ルーチンの名前を探す、スキーマの順序。`DFTRDBCOL`とは別) |
| Default schema | 既定のスキーマ(`DFTRDBCOL`が決める、表などの既定の置き場) |
| Promotion | 昇格(開発から本番役へ、オブジェクトを移す。ここでは、複製・削除・戻しの予行) |
| Rollback | 切り戻し(直前の状態に戻す。複製から戻す) |
| Retrospective | 振り返り(何ができ、何が確かめられていないかを、根拠と一緒に書く) |

- 新しいメッセージ ID: なし(`SQL7951`・`SQL7989`・`SQL7997`・`SQL0204`・`CPF2105`・`CPF4174`を、このレッスンの意味で)。
- 決まり: ビューやルーチンの中では、ルーチンを修飾して呼ぶか、問い合わせを書き写す(`DFTRDBCOL`はSQLパスではない)。ソースにライブラリー名を書き込まない。複製の確認を済ませてから、元を消す。`TXCHECK`は、新しいジョブで1回だけ。近い実験の結果を、確かめたものそのものと書かない。
- 次は、この教材の最後です。第9部・第10部で確かめられなかったこと(V3・未実施)は、各レッスンの実機メモに書いています。前のレッスンは[10-03 近代化と開発基盤](10-03-modernization-devbase.md)です。全体の位置づけは[ロードマップ](../roadmap.md)を参照してください。

### 第10部全体の振り返り(7つの目標)

第10部は、この教材の7つの目標([ロードマップ](../roadmap.md)の目標の表)を、1つの題材(サンプル商事の受注・在庫システム)で通しで使う仕上げです。各目標を、第10部のどのレッスンで使ったかを、次の表に整理します。**各レッスンの手順の詳細は、それぞれのレッスンにあります。** 右の2列は、あなたが書きます(演習(d))。

| 目標 | 第10部で使ったレッスン | そこで自分がしたこと(要約) | 自己評価 | 根拠(実行して確かめたこと・1行) |
|---|---|---|---|---|
| 1 基礎的なコマンド群を使える | [10-01](10-01-preparation-incident.md) | 準備(`TXLEGACY`・`TXRESET`・修正の適用)で旧システムを既知の12行に戻した | | |
| 2 CLプログラミングができる | [10-01](10-01-preparation-incident.md) | ジョブ・ログの末尾から失敗した文・項目を読み、`HEX()`で原因のバイトを特定し、`SBMJOB`で再投入した | | |
| 3 簡単なRPG IIIプログラムを作成できる | [10-02](10-02-maintenance-tokyusn.md) | `JU0300`に与信超過の印を付け、印が付く行・付かない行を出力で確認した | | |
| 4 既存のRPG IIIソースを読み・保守できる | [10-02](10-02-maintenance-tokyusn.md) | 影響調査表・改修記録・移送手順書を書き、前後を比べた | | |
| 5 RPG IV(完全自由形式)を主力言語として使える | [10-03](10-03-modernization-devbase.md) | 旧システムのプログラムを、`**FREE`・SQL・`ZAISRV`で置き換え、旧版と出力を比べた | | |
| 6 現代的なプログラミング手法を活用できる | [10-03](10-03-modernization-devbase.md) | git・`makei`・lint・テストを、1つのコマンドで回せる形にした | | |
| 7 API化・APIからのデータ取得(環境が許す範囲で) | このレッスン(10-04) | 3つの操作の設計書を書き、接着部品を動かし、昇格の予行と`TXCHECK`を行った | | |

**自己評価の段階と、各目標の基準は、[第10部の扉](index.md)の「評価」の節の評価表に従います。** ここで段階の名前や基準を作り直さず、扉の表の基準を1行ずつ読み、自分の根拠と照らしてください。根拠が書けない目標は、その目標を確かめていないということで、次に何をすればよいかが分かる点です(設計書の「11. 次のステップ」と同じ考え方です)。

第10部で使った道具の確認範囲についての注意を、1つだけ書きます。**`TXCHECK`は、オブジェクトが存在するか(と型)しか確かめられません。** 中身の正しさや版は判定できないので、第10部の各レッスンの採点表は、`TXCHECK`のほかに、実行結果の照合(スプール・件数・`EXCEPT`など)を必ず求めています。

## 実機メモ

- **確認日: 2026-09-30。バッチ`part10-04-checkpoint`(2回の接続。1回目は接着部品の作成と、`LOWALERT`が失敗した最初の版の確認。2回目は、書き写した版の`LOWALERT`の確認と、ほかの項目の再確認)、PUB400、IBM i 7.5(V7R5M0)。** 検証は、著者の検証用ライブラリー(1つのライブラリーの中にルーチン・モックの表・`TXCKM`などを置く)で行い、バックアップだけを別のライブラリーに置きました。学習者の`<自分のユーザー名>2`そのものでの再現は、個別には確認していません(未検証(2026-09-30時点))。検証の記録は、[プローブ記録](../probes.md)の「第10部」の節にあります。
- **V2で確認できたこと**:
  - `JUCHU_INQUIRY_JSON('J00001')`が、有効なJSONを返し、`JSON_TABLE`で読み戻すと明細2行(`P00001`が数量2、`P00003`が数量5)。存在しない受注番号(`ZZZZZZ`)は、SQLのNULL。
  - `LOW_STOCK()`が2行(`P00002` 在庫3・発注点5、`P00005` 在庫12・発注点50)。
  - **ビューの中で`LOW_STOCK()`を無修飾で呼ぶ最初の版は、`RUNSQLSTM`(`NAMING(*SQL)`・`DFTRDBCOL`)で`SQL0204`(`LOW_STOCK in *LIBL type *N not found`)になった**。SQLパスに開発ライブラリーが入っていなかった(`DFTRDBCOL`はSQLパスではない)。ライブラリーを付けた版は`db2`から作れ、`{"alert":"LOW_STOCK","count":2,"items":[...]}`(180文字)を返した。
  - 問い合わせを書き写した現在の`LOWALERT`(配布の版)が、`RUNSQLSTM`で`SQL7951`・重大度00で作れ、同じ180文字のJSON(`count`が2、`P00002`・`P00005`)を、バッチ・ジョブ(CLプログラム)と`db2`の両方から返した。`JSON_TABLE`で読み戻すと2件。
  - `JUCHU_REGISTER`(`J09901`、1つのテキスト・リテラル)が登録でき(ヘッダー1行・明細2行)、`JUCHU_INQUIRY_JSON`で往復できた。二重登録は`SQLSTATE 75001`(`NATIVE ERROR CODE -438`)で断られ、明細2件・ヘッダー1件のまま。
  - `JUHTTPSV`のモック5件(`1000001`が`OK`・200・148、`9999999`が`OK`・200・46、`9999504`が`HTTPERR`・504、`9999404`が`HTTPERR`・404、`1234567`が`NOMOCK`・`SQLST`02000)。`ZIPCHECK`が`FOUND`・`NOTFOUND`・`HTTPERR`・`HTTPERR`、`ZIPCHKLOG`が同じ結果と`NOMOCK`。どちらのビューも`RUNSQLSTM`でエラーなく作れた。`parse-zip.sql`の末尾の`SELECT`単独文は`SQL0084`(既知、無害)。
  - `QSYS2.IFS_WRITE_UTF8`: リテラルの`LINE`、変数(ビューの列の値)、スカラーの副問い合わせのいずれも書けた(180バイト)。相対パス(`p1004lit.txt`、21バイト)は、ジョブのホーム・ディレクトリーに書かれた。`REPEAT('A', 3000)`・`REPEAT('A', 20000)`が、3000バイト・20000バイトで全部書けた。`IFS_READ_UTF8`の読み戻しは1行(`LINE_NUMBER`が1、長さ180)で同じ内容。`SQL PL`のプロシージャー(`EXPORT_LOWSTOCK`)の中で、名前つき引数の`IFS_WRITE_UTF8`の呼び出しが受け付けられた(`SQL7989`)。`RUNSQL`(システム命名)の`CREATE TABLE AS`で、`IFS_READ_UTF8`の結果を表に入れられた。
  - 昇格の予行: `ZAISRV`・`JUCSRV`を、複製(`ZAISRVP`・`JUCSRVP`)・削除・戻しでき、両方が`*SRVPGM`として存在。作成日時が新しくなった(中の`*MODULE`の日時は変わらず)。古い複製の`DLTSRVPGM`は、無ければ`CPF2105`。
  - `TXCHECK LESSON('10-04')`: `TXCHKRUN`経由の1回で、4件PASS・`0000000004 passed,`・`0000000000 failed.`。
  - 片付け後: `SYSROUTINES`の該当ルーチンが0件、`JUCHUM`・`JUCHUD`・`ZAIKOM`が8・12・6件、`J099`の行なし、`TXCKM`の`10-04`の行なし、`<自分のユーザー名>B`の複製なし(どちらの接続でも確認)。
- **確認の範囲に関する注意**:
  - **上の実行は、CLプログラム(バッチ・ジョブ)と、SSHの`db2`・`system`から行いました。** 5250の対話式ジョブでの実行は、確認していません。
  - **ファイルは、検証の道具が置いたコピー(CCSID 273のタグ)で`RUNSQLSTM SRCSTMF`を実行しました。** `git clone`したままのタグのファイルでの実行は、確認していません。`JUHTTPSV`のソース・メンバーも、道具が書きました(`CPYFRMSTMF`の形は確認していません)。
  - **`LOWALERT`の空のときの出力(`{"count":0,"items":null}`)は、`WHERE 1 = 0`を付けた、`LOW_STOCK()`を呼ぶ複製で確かめた値です。** 書き写した現在のビューそのものを、0件で実行した結果ではありません。
  - `IFS_WRITE_UTF8`の`LINE`が、20000バイトを超える長さの場合は確かめていません。
  - 検証の道具の側の雑音(コンパイル・リストの回収失敗、存在しない複製の事前削除の`CPF2105`、存在しない表の`DROP`の`SQL0204`)は、関数の振る舞いではありません。
- **未検証(2026-09-30時点)**:
  - 学習者の環境での、`SRCSTMF`での作成、`.sql`のタグ(`git clone`したまま)、`CPYFRMSTMF`でのソース取り込み、5250の対話式ジョブでの`CRTSQLRPGI`・`CALL`・`CRTDUPOBJ`、5250のコマンド行に直接打つ`TXCHECK`、同じジョブでの2回目の`TXCHECK`(既知の`CPF4174`は08-08・09-07で確認)。
  - `<自分のユーザー名>1`から`<自分のユーザー名>2`への複製による昇格(08-08で確認した形。このレッスンの検証では行っていない)。昇格の予行のあと、`LANGUAGE RPGLE`で登録した関数(`GETCUSTNM`など)を呼ぶこと(サービス・プログラムの作り直しで、登録が影響を受けるかどうか。`SQL7909`)。
  - `LOWALERT`ビューそのものの0件のときの出力。`SET PATH`でSQLパスを足す方法。`LINE`が20000バイトを超える場合。権限・同時実行。受注の明細が4000文字を超える場合の`JUCHU_INQUIRY_JSON`。ACS・VS Codeからの呼び出し(V3)。
  - `CPYTOIMPF`による代替(`RCDDLM(*CR)`が要る。実演したことがない)。
  - 片付けの操作(`WRKSPLF`での削除、`rmdir`、演習(e)のビューの削除、片付け手順5の`&&`による条件付きの削除、`RMVM`のSSHからの実行)は、学習者環境では未試行。
  - `db2`から打つ形の`SELECT`(手順4・6の`JUCHU_INQUIRY_JSON`・`LOW_STOCK`・`APILOG`・`ZIPCHECK`・`ZIPCHKLOG`・`APICFG`)は、値を検証で表に取り込んで読んだもので、その`db2`の形そのものは実行していません。`$HOME/work`のパス・`mkdir -p`、`IFS_WRITE_UTF8`が存在しないディレクトリーで失敗すること、`QRPGLESRC`・`<自分のユーザー名>B`が無い場合の作成、昇格の予行の失敗時の復旧操作も、確かめていません。
  - 手順10のサインオフ・サインオンし直して、5250で`TXCHECK`を打つ形、`CPYFRMSTMF`がメンバーを作るかどうか。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
