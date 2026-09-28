# 06-07 データ構造と配列: 商品別在庫一覧表を配列で書き直す

> 所要時間: 60分 / 前提レッスン: 06-06 / 目標番号: 5 / 観測方法: `WRKSPLF` / 道具: 5250、SSH / 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1/F0607A`・演習4で作る`<USER>1/F0607B` / DBVER: 1 / 依存するプローブ: P24 / PTF 依存: なし / 容量の目安: わずか

## ゴール

- `qualified`なデータ構造(DS)を、`extname`・`template`・`likeds`を使い分けて宣言できる。
- `dim`(固定長配列)・`dim(*auto)`(可変長配列)で配列を作り、`%LOOKUP`で検索し、`SORTA`で並べ替えられる。
- 04-13(`R0413A`、商品別在庫一覧表)の`CHAIN`方式による低在庫判定を、配列+`%LOOKUP`方式(`F0607A`)がどう置き換えたかを、自分の言葉で説明できる。

## ウォームアップ

<details><summary>前回の復習(06-06)</summary>

1. `%SUBST`を代入先として使うと何ができますか?
2. 式(拡張Factor 2)の中で桁あふれが起きると、`TRUNCNBR`の既定値`*YES`に関係なく、どうなりますか?

答え: 1. 対象の一部分だけを明示的に書き換えられる(`%subst(name2 : 1 : 2) = 'AL';`のような形。ただしこれは一次資料に基づく一般知識で、06-06の`F0606A`自身はこの書き方を実演しておらず未検証です)。 2. `TRUNCNBR`の設定に関係なく、常に実行時エラーになる(式の中の桁あふれは常に実行時エラー)。

</details>

## なぜ学ぶか

**06-05・06-06で既に使っていた`sendMsg`は、実は内部で`qualified`なデータ構造と`likeds`を使っていました。** 06-06では「その意味は06-07で説明します」とだけ書いて先送りにしましたが、ここでようやく詳しく扱います。

もう1つの動機は、04-13(`R0413A`、商品別在庫一覧表)です。あのプログラムは`ZAIKOM`をキー付きのプライマリー・ファイルにして、RPGサイクルに全件処理を任せ、1件ごとに`CHAIN`で`SHOHIM`を引いていました。**しかし、いつでもファイルをプライマリーにしてサイクルに任せられるとは限りません。** 複数のファイルをいったん全部メモリーに読み込んでから突き合わせたい場合や、同じデータを何度も走査したい場合には、**配列にデータ構造(DS)を並べて持ち、`%LOOKUP`で検索する**という、今回のやり方が必要になります。`F0607A`は、04-13の`R0413A`と**まったく同じ業務判定**(在庫が発注点を下回っていたら`LOWSTOCK`)を、この配列方式で再現したプログラムです。

## 新出

- 中核概念:
  1. `qualified`なデータ構造は、RPG III時代には無かった「名前空間を分ける」考え方です。しかも、配列化するデータ構造(`DIM`を付けるもの)は`QUALIFIED`でなければならない、というRPG IV自体の規則でもあります(一次資料・ILE RPG言語リファレンスによる)。
  2. `%LOOKUP`は、RPG IIIの`LOKUP`命令と違い、検索に失敗すると自動的に`0`を返します(`LOKUP`のように、探す前に毎回結果標識を`SETOF`しておく必要がありません。[付録F](../appendix/f-bif-reference.md)の`%LOOKUP`/`LOKUP`の行も参照してください)。
- 構文:
  - `dim`(固定長配列。`DIM(数値)`の形。`%ELEM`は常に宣言時の上限(`prod`なら50)を返すため、実際に使った件数は別変数で数える)
  - `dim(*auto)`(可変長配列。`DIM(*AUTO:上限)`の形。`(*next)`で1件ずつ追記でき、この場合は`%ELEM`が常に「今何件あるか」を返す)
  - `likeds`/`template`/`extname`(データ構造の「型」と「実体」を分ける3点セット。`qualified`なデータ構造の配列は`DS(*).SUBFIELD`という書き方で、全要素から1サブフィールドだけを取り出した列を作れる)
  - `%lookup`(配列検索。見つからなければ`0`を返す。`DS(*).SUBFIELD`で作った列を検索対象にできる)
  - `sorta`(配列の並べ替え。`%SUBARR(配列(*).サブフィールド : 開始位置 : 件数)`で、`DS(*).SUBFIELD`の一部範囲だけを並べ替え対象に絞れる)

**`%ELEM`・`(*next)`は`dim`/`dim(*auto)`の項目に、`DS(*).SUBFIELD`は`likeds`/`template`/`extname`の項目に、`%SUBARR`は`sorta`の項目に、それぞれ含めて数えます**(06-06の日付BIFファミリーと同じ数え方です)。

## 説明

### `R0413A`のロジックを`F0607A`へ移植する

`R0413A`(04-13)と`F0607A`(本レッスン)は、**同じ業務判定**(在庫数量が発注点を下回っていたら`LOWSTOCK`)を、まったく違う仕組みで実現しています。

| `R0413A`(RPG III、04-13) | `F0607A`(`**FREE`、本レッスン) |
|---|---|
| `FZAIKOM IP E K DISK`(`ZAIKOM`をキー付きのプライマリー・ファイルにして、RPGサイクルが全件を自動的に処理する) | `stock`配列に`ZAIKOM`を全件`READ`して読み込む |
| `C ZASHO CHAINSHOHIM 50`(1件ごとに`SHOHIM`を`CHAIN`) | `prod`配列に`SHOHIM`を全件読み込んでおき、`%LOOKUP`で検索する |
| `C ZASU COMP SHOHAT 60`(在庫数量と発注点を比較、標識60) | `sumRow.lowstock = (sumRow.zasu < sumRow.shohat);`(論理値を直接データ構造のサブフィールドへ代入) |
| `O 60 70 'LOWSTOCK'`(標識60でLOWSTOCKを条件付き出力) | `if sumline(i).lowstock; %subst(line:63:8) = 'LOWSTOCK'; endif;` |
| (`ZAIKOM`がキー付きプライマリー・ファイルなので、商品コード順が自動的に付いてくる) | `sorta`で明示的に並べ替えないと、商品コード順は保証されない(下記参照) |

**判定条件そのもの(`ZASU`が`SHOHAT`を**下回る**、`<`)は変えていません。** 変わったのは「`SHOHIM`をどう引くか」「商品コード順をどう保証するか」という、その周りの仕組みだけです。

### `qualified`なデータ構造 ── 名前空間を分ける、しかも配列化には必須

```rpgle
dcl-ds shohimRow extname('SHOHIM' : *input) qualified end-ds;
dcl-ds zaikomRow extname('ZAIKOM' : *input) qualified end-ds;
```

`extname('SHOHIM' : *input)`は、`SHOHIM`のDDS(`db/v1/shohim.pf`)からフィールドの形をそのまま借りてくる書き方です。`R0413A`のF仕様書が`SHOHIM`を宣言していたのと同じ役目です。`extname`のレコード様式名パラメーターは、ファイルのレコード様式がいくつあるかに関係なく常に省略でき、省略した場合はファイルの最初のレコード様式が使われます(一次資料・ILE RPG言語リファレンスによる)。「レコード様式が1つしか無い場合に限って許される」という制約が実際にかかってくるのは、この`extname`の宣言そのものではなく、後述する`read shohim shohimRow;`(レコード様式名ではなくファイル名を指定した`READ`)の方です。ファイル名を指定した入出力操作の結果データ構造は、そのファイルにレコード様式が1つしか無い場合にだけ、`extname`のような(複数様式に対応しない)単純なデータ構造をそのまま使うことが許されます(同じく一次資料による)。`SHOHIM`・`ZAIKOM`はどちらもレコード様式が1つしか無いファイルなので、この条件を満たしています。

`qualified`を付けると、サブフィールドは`shohimRow.shocd`のように必ずデータ構造名を前置きして参照することになり、`SHOHIM`と`ZAIKOM`のフィールド名が(将来DDSが変わって)たまたま衝突しても、名前空間が分かれているので事故になりません。

一次資料・ILE RPG言語リファレンスは、配列化する(`DIM`を付ける)データ構造は`QUALIFIED`でなければならないと明記しています。ただし、この規則は`shohimRow`・`zaikomRow`自身には直接関係しません(この2つには`DIM`を付けていないためです)。**`DIM`が付くのは、このあと出てくる`likeds`で作った`prod`・`stock`・`sumline`の方です。** 同じ一次資料は、「`likeds`で作ったデータ構造は、元になったデータ構造が`qualified`かどうかに関係なく、自動的に`qualified`になる」ことも明記しています。つまり`prod`(`likeds(shohimRow) dim(50)`)は、`shohimRow`が`qualified`かどうかに関わらず、`likeds`を使った時点で自動的に`qualified`になり、`DIM`の規則を満たします。

それでも`shohimRow`・`zaikomRow`自身を明示的に`qualified`にしているのは、`like(shohimRow.shocd)`のように**ドット表記でサブフィールドを参照する**ためです(ドット表記は`qualified`なデータ構造でしか使えません)。まとめると、`qualified`には「名前空間を分ける」「ドット表記を使えるようにする」という2つの効果があり、`DIM`(配列化)そのものは、`likeds`経由なら自動的に満たされる、という関係です。

### `template`・`likeds` ── 「型」と「実体」を分ける

```rpgle
dcl-ds sumRow_t qualified template;
  shocd    like(shohimRow.shocd);
  shonm    like(shohimRow.shonm);
  zasu     like(zaikomRow.zasu);
  shohat   like(shohimRow.shohat);
  lowstock ind;
end-ds;
```

`sumRow_t`はどのファイルにも対応しない、手作りの「1行分の集計結果」の形です。`template`を付けると、これはコンパイル時だけの型定義になり、それ自体はストレージ(実際のメモリー領域)を持ちません。各サブフィールドの型・長さは、`like(shohimRow.shocd)`のように、既に`extname`で読み込んだ実際のフィールドから借りているので、桁数をここで手打ちし直す必要がありません(DDSが変われば、再コンパイルするだけで追従します)。

`template`だけでは実体が無いので、実際に使うときは`likeds`で実体化します。

```rpgle
dcl-ds prod    likeds(shohimRow) dim(50);
dcl-ds stock   likeds(zaikomRow) dim(*auto:50);
dcl-ds sumRow  likeds(sumRow_t);
dcl-ds sumline likeds(sumRow_t) dim(*auto:50);
```

`likeds(shohimRow)`は「`shohimRow`と同じ形の実体を作る」という意味です(`sumRow`のように`dim`を付けなければ1件分、`prod`のように`dim`を付ければ配列になります)。`sumRow_t`はファイルに対応しない`template`ですが、同じ`likeds`のやり方で実体化できます(`sumRow`・`sumline`)。

**06-05・06-06で使っていた`sendMsg`も、同じ`template`+`likeds`の組み合わせを使っています。** `src/qrpglesrc/f0606s.rpgle`(06-06)から、関係する部分だけ抜き出すと次のとおりです。

```rpgle
dcl-ds qmhsndpmErrCode template;
  bytesProvided int(10) inz(0);
  bytesAvailable int(10);
  msgId char(7);
  *n char(1);
end-ds;

dcl-pr qmhsndpm extpgm;
  ...
  errorCode      likeds(qmhsndpmErrCode);
end-pr;
```

`qmhsndpmErrCode`自体には`qualified`を付けていません(`template`だけです)。それでも`likeds(qmhsndpmErrCode)`で作った`errorCode`(および`sendMsg`内部の同じ形の変数)は、上で説明したとおり自動的に`qualified`になります。**`qualified`を明示していないデータ構造でも、`likeds`で実体化した先は自動的に`qualified`になる**、という同じ規則の実例です。

### `dim`と`dim(*auto)` ── 固定長配列と可変長配列

`prod`(固定長`dim(50)`)と`stock`/`sumline`(可変長`dim(*auto:50)`)は、あえて違う書き方で示されています。

- `prod`は`dim(50)`という**固定長**です。この書き方では、50個の枠のうち実際に何個使ったかを、プログラム自身が別変数(`nProd`)で数え続ける必要があります。`INZ`も`CONST`も指定していないデータ構造は、各サブフィールドの型に関係なく空白で初期化される、と一次資料・ILE RPG言語リファレンスは明記しています。つまり未使用の枠は、`shohat`のような数値サブフィールドであっても**ゼロではなく空白のまま**です。そのため、`%LOOKUP`の探索範囲は`%ELEM(prod)`(常に50)ではなく、実際に読み込んだ件数`nProd`で明示的に絞っています。
- `stock`・`sumline`は`dim(*auto:50)`という**可変長**です。`stock(*next) = zaikomRow;`のように`(*next)`を使うと、配列は自分で今の件数を覚えていて、次の空き枠に追記されます。`%ELEM(stock)`は常に「今何件あるか」を正しく返すので、`prod`のような別カウンターは要りません。50はこの練習用データに対する余裕を持たせた上限にすぎません。

```rpgle
read shohim shohimRow;
dow not %eof(shohim);
  nProd += 1;
  prod(nProd) = shohimRow;
  read shohim shohimRow;
enddo;

read zaikom zaikomRow;
dow not %eof(zaikom);
  stock(*next) = zaikomRow;
  read zaikom zaikomRow;
enddo;
```

`dcl-f shohim disk;`・`dcl-f zaikom disk;`はどちらもキー無し(到着順)で開いており、`R0413A`のような`CHAIN`は一切使わず、単純に先頭から終端まで`READ`して配列へ積み込んでいるだけです。

### `%LOOKUP` ── 配列検索、`CHAIN`の代替

```rpgle
for i = 1 to %elem(stock);
  idx = %lookup(stock(i).zasho : prod(*).shocd : 1 : nProd);

  sumRow.shocd = stock(i).zasho;
  if idx > 0;
    sumRow.shonm  = prod(idx).shonm;
    sumRow.shohat = prod(idx).shohat;
  else;
    sumRow.shonm  = *blanks;
    sumRow.shohat = 0;
  endif;
  sumRow.zasu = stock(i).zasu;

  sumRow.lowstock = (sumRow.zasu < sumRow.shohat);

  sumline(*next) = sumRow;
endfor;
```

`prod(*).shocd`は「`prod`配列の**全要素**の`shocd`サブフィールドだけを取り出した列」という意味の書き方(`DS(*).SUBFIELD`)で、`qualified`なデータ構造の配列だからこそ書けます。`%LOOKUP(検索値 : 配列 : 開始位置 : 件数)`は、見つかった要素番号(見つからなければ`0`)を返します。**中核概念(2)のとおり**、`RPG III`の`LOKUP`命令のように事前に結果標識を`SETOF`しておく必要はなく、`idx > 0`かどうかをそのままチェックするだけで済みます。

**`R0413A`との違いがもう1つあります。** `R0413A`の`CHAIN`失敗時(標識50)は、`SHONM`・`SHOHAT`をクリアしないため、直前の`ZAIKOM`行の値が印字にそのまま残ってしまう罠を持っていました(04-07で学んだ「`CHAIN`が失敗した場合、フィールドは書き換わらない」という性質そのものです)。`F0607A`は`%LOOKUP`が失敗(`idx = 0`)したとき、`sumRow.shonm`/`sumRow.shohat`を明示的に空白・ゼロへクリアしており、この罠を意図的に避けています。**ただし現在のサンプル・データは、`ZAIKOM`の6件全てが`SHOHIM`と一致するため(04-13で確認済みのとおり)、この違いはどちらのプログラムでも実際には発火しません。** 演習5でこの違いを掘り下げます。

### `SORTA` ── 配列の並べ替え

```rpgle
sorta %subarr(sumline(*).shocd : 1 : %elem(sumline));
```

`R0413A`は`ZAIKOM`がキー付きプライマリー・ファイルだったので、商品コード順は何もしなくても保証されていました。`F0607A`はキー付きアクセスを配列+`%LOOKUP`と引き換えにしたため、商品コード順は自動では付いてきません。そこで印字の直前に`SORTA`で並べ替えています。`%SUBARR(配列(*).サブフィールド : 開始位置 : 件数)`は、`sumline`のうち実際に使われている範囲(`%ELEM(sumline)`、`dim(*auto)`なので常に現在の件数)だけを並べ替え対象に絞る書き方です。

## 実演

**この実演で作るオブジェクト(`F0607A`)は、著者による実機コンパイル・実行(V2、下の「実機メモ」参照)まで確認済みです。**

1. SSHで接続し、`~/ibmi-kyozai`が最新であることを確認します(`git pull`)。`exit`で5250に戻ります。
2. 5250のコマンド行で、`<自分のユーザー名>1/QRPGLESRC`にメンバーを用意します。`QRPGLESRC`自体は06-01bで新規作成済みのはずです。まだ無ければ`CRTSRCPF FILE(<自分のユーザー名>1/QRPGLESRC) RCDLEN(112) TEXT('RPG IV free-form source')`を先に実行してください。

   ```text
   ADDPFM FILE(<自分のユーザー名>1/QRPGLESRC) MBR(F0607A) SRCTYPE(RPGLE) TEXT('DS and arrays: low-stock via array + %LOOKUP')
   ```

3. SSHでもう一度接続し、`src/qrpglesrc/f0607s.rpgle`を取り込みます。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/f0607s.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/F0607A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

4. 5250に戻り、コンパイルして実行します。

   ```text
   CRTBNDRPG PGM(<自分のユーザー名>1/F0607A) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(F0607A)
   CALL PGM(<自分のユーザー名>1/F0607A)
   ```

   Highest Severity 00 になることを確認してください。

5. `WRKSPLF`で結果を確認します。**6商品全てが印字され、04-13で確認したのと同じ2商品(`P00002`=OFFICE CHAIR、`P00005`=USB CABLE)にだけ`LOWSTOCK`が付くこと**を確認してください。最後に、`%LOOKUP`を単体で使うボーナス行(`P00002`を検索し、見つかった要素番号`2`を印字する行)も1行追加で印字されます。商品コード・商品名・`LOWSTOCK`の有無はこの実機メモが確認済みの内容そのものです。**在庫数量(`ZASU`)の列は、直前までのレッスンで`ZAIKOM`を書き換える演習(06-05の`callp r0409a();`など)を行った後に`<自分のユーザー名>1/TXRESET`を実行していれば、`db/data/load_v1.sql`の初期値(45・3・250・60・12・22)のまま印字されるはずです**(下の「実機メモ」に、著者の検証環境で実際に確認できた印字内容をそのまま載せています)。

## 演習

1. 低在庫の判定条件を、`sumRow.zasu < sumRow.shohat`(発注点を**下回る**、現状)から`sumRow.zasu <= sumRow.shohat`(発注点**以下**)に変えて再コンパイル・実行し、結果がどう変わるか確認してください(確認後は元に戻してください)。現在のサンプル・データには在庫数量が発注点とちょうど一致する商品が無いため、結果は変わらないはずです。
2. `sorta`の行をコメントアウトして再コンパイル・実行し、印字順が変わるかどうか確認してください。`db/data/load_v1.sql`では`SHOHIM`・`ZAIKOM`とも商品コード順に投入されているため、現在のサンプル・データでは印字順が変わらないかもしれません。それでも`SORTA`が必要な理由(配列+`%LOOKUP`方式は、`R0413A`のように`ZAIKOM`のキー付きプライマリー・ファイルから商品コード順を自動的に受け取れない)を、自分の言葉で説明できるか確認してください。確認後は`sorta`の行を戻してください。
3. `sumRow_t`(および`sumRow`・`sumline`)に`shotnk`(単価、`like(shohimRow.shotnk)`)を追加し、`%LOOKUP`が見つかったときに`sumRow.shotnk = prod(idx).shotnk;`で埋め、印字行にも追加してみてください(04-13自身の演習2「単価も一覧に追加する」と同じ拡張です)。
4. 上の「説明」を閉じて(見ずに)、`R0413A`の低在庫判定ロジックを配列+`%LOOKUP`の形に、自分の記憶だけで書き直してみてください。流れは「`SHOHIM`を配列に読み込む→`ZAIKOM`を配列に読み込む→各`ZAIKOM`行を`%LOOKUP`で`SHOHIM`と突き合わせる→同じ判定(`ZASU < SHOHAT`)→`SORTA`で並べ替えて印字」です。書けたら`F0607B`(`docs/style-guide.md`の「オブジェクトの命名」に定める、学習者用オブジェクトの次の変化字)としてコンパイルし、`P00002`・`P00005`だけに`LOWSTOCK`が付くこと、04-13の`R0413A`・本レッスンの`F0607A`と同じ結果になることを確認してください。
5. (発展)上の「説明」で触れた`%LOOKUP`失敗時の違い(`R0413A`は前の値が残る罠を持つが、`F0607A`は明示的にクリアする)について、現在のサンプル・データではどちらの経路も実際には発火しないことを踏まえたうえで、もし`ZAIKOM`に`SHOHIM`に存在しない商品コードの行が混ざっていたら、`R0413A`と`F0607A`それぞれの印字はどうなるか、自分の言葉で説明してください。**これは未検証の思考実験です**(実際にデータを差し替えて確認したものではありません)。

## セルフチェック

- [ ] `qualified`なデータ構造が「名前空間を分ける」ためのものであり、かつ配列化(`DIM`)には必須であることを説明できる。
- [ ] `extname`・`template`・`likeds`の役割の違い(「型」を借りる・「型」を自作する・「実体」にする)を説明できる。
- [ ] `dim(50)`(固定長)と`dim(*auto:50)`(可変長)の違い(件数を自分で数えるか、`%ELEM`が数えてくれるか)を説明できる。
- [ ] `%LOOKUP`で配列検索を行い、`idx > 0`で成否を判定できた(演習)。
- [ ] `SORTA`が必要な理由(`R0413A`のキー付きプライマリー・ファイルが持っていた「順序の保証」が、配列方式では失われること)を説明できる。
- [ ] `F0607A`を実行し、`P00002`・`P00005`だけに`LOWSTOCK`が付くことを確認した。

## 片付け

作成したプログラム(`F0607A`、演習4で作った`F0607B`)はそのまま残してください。`SHOHIM`・`ZAIKOM`はどちらも読み取り専用のアクセスしかしていないので、上の演習(1〜5)を含め、このレッスンではデータが書き換わることはありません。**`TXRESET`は不要です。**(06-08・06-11bのように共有テーブルを`UPDATE`する演習では、必ず`TXRESET`が必要になりますが、本レッスンの演習はそれには当たりません。)

## まとめ

| 英語 | 日本語 |
|---|---|
| Qualified data structure | 名前空間を分けたデータ構造 |
| Template | 実体を持たない、コンパイル時だけの型 |
| LIKEDS | 既存の型(DSまたはtemplate)から実体を作る |
| Array | 配列 |
| Look up (`%LOOKUP`) | 配列の中から値を探す(見つからなければ`0`) |
| Sort an array (`SORTA`) | 配列を並べ替える |

次のレッスン(06-08)では、`dcl-f`の`usage`/`keyed`と、`likerec`・`%kds`を扱い、在庫引当(`ZAHIK3`)をファイル入出力の観点から自由形式で書き直します。

## 実機メモ

- 確認日: 2026-09-27。**`F0607A`を`part06-0509-procs-files`(1回の接続でCONFIRMED SUCCESS)で実際に`CRTBNDRPG`によりコンパイル(Highest Severity 00)し、`CALL`で実行した。実際に接続の生ログ(runセクション)に現れた印字は次のとおりである(値はそのまま、見出しなどの体裁だけ整えた)。**

  ```text
  P00001    DESK LAMP                           0000043
  P00002    OFFICE CHAIR                        0000003       LOWSTOCK
  P00003    NOTEBOOK PACK                       0000250
  P00004    STAPLER                             0000060
  P00005    USB CABLE                           0000012       LOWSTOCK
  P00006    MONITOR STAND                       0000022
  BONUS: LOOKUP P00002 -> INDEX  2
  ```

  **04-13で確認したのと同じ2商品(`P00002`・`P00005`)だけに`LOWSTOCK`が付き、単体`%LOOKUP`のボーナス行も要素番号`2`を正しく印字している。V2まで確認済み。** 観測は、このハーネスの非対話SSHジョブがプログラム記述の印刷装置ファイル(`QSYSPRT`)の実スプールを作らない制約(`part06-0103-freeform`(2026-09-26)で実機発見済みの制約で、`CPYSPLF`は`CPF3303`で失敗する)のため、`WRKSPLF`ではなく、接続の生ログに直接現れたこのテキストを読んで行った。`WRKSPLF`は対話操作のコマンドで、このハーネスの非対話SSHジョブでは一度も実行していないため、この環境で`WRKSPLF`自体がどう振る舞うかは未検証である。
  - **`P00001`の在庫数量が`0000043`(元の`45`ではない)である点に注意してください。** この接続は06-05〜06-09(`F0605A`〜`F0609A`)を1回でまとめて検証しており、`F0605A`(`callp r0409a();`)が`F0607A`より先に実行され、`ZAIKOM`の`P00001`を45→43に減らしている。`TXRESET`はこの接続の最後(`F0609A`の後)に1回だけ実行されるため、`F0607A`実行の時点ではまだ元に戻っていない。**低在庫の判定(`P00002`・`P00005`だけが該当)には影響しない**(43も45も発注点20を上回るため)。上の「実演」の指示どおり、06-05のあとに`TXRESET`を実行していれば、学習者自身の実行では`P00001`は`0000045`のままになるはずです(この「45」は`db/data/load_v1.sql`の初期値そのものであり、45→43への変化の理由は、06-05の`F0605A`が呼ぶ`R0409A`(04-09)による減算として上記のとおり説明が付きます)。
  - **なお、このハーネスの検証は`CPYFRMSTMF`でソースを直接著者の検証ライブラリーのメンバーへ取り込む経路(`ADDPFM`を介さず`MBROPT(*REPLACE)`で直接取り込み、`STMFCCSID`は指定しない)によるものであり、上の「実演」節が示す、学習者が`ADDPFM`してから`STMFCCSID(1208)`付きで`CPYFRMSTMF`する手順そのものを実行して確認したわけではない(06-06の実機メモが説明しているのと同じ事情です)。** ソース・ファイルの内容自体は同一だが、経路の違いにより、実演の手順そのものをたどった場合の結果は厳密には未検証である。
  - **学習者自身が5250で`CALL`し`WRKSPLF`の画面を実際に操作して確認する部分は、対話操作(V3)であり、このレッスンでは実機未確認のままです。**
- `dim(*auto)`(可変長配列)自体は、`part06-gen-probe`(P24機能梯子、確認日2026-09-26)のrung2で`DIM(*AUTO:10)`が実機確認済みです(2回の代入後、`%ELEM`が正しく`2`を返すことを確認)。`F0607A`自身の`stock`/`sumline`(`dim(*auto:50)`)がある実行(上記`part06-0509-procs-files`)が成功したことも、同じPTFレベルでの`dim(*auto)`の動作を裏付けています。
- 上の印字内容は実際に確認できたものですが、`src/qrpglesrc/f0607s.rpgle`自身のヘッダー・コメントは、この桁位置を`R0413A`のO仕様書に対する見た目上のベストエフォートの再現であり、`R0413A`自身の印字と桁単位まで一致させたものではないと明記しています。両プログラムの桁を並べて比較する検証は行っていません。
- `%LOOKUP`が失敗する経路(検索対象の商品コードが`SHOHIM`に無い場合)は、現在のサンプル・データ(`ZAIKOM`の6件全てが`SHOHIM`と一致する、04-13で確認済みのとおり)では一度も発火しないため、未検証のままです(演習5参照)。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
