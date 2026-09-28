# 06-08 ファイル入出力(`dcl-f`): 在庫引当 ZAHIK4

> 所要時間: 75分(長め)/ 前提レッスン: 06-07 / 目標番号: 5 / 観測方法: `WRKSPLF`・`DSPJOBLOG`・SQL(`STRSQL`) / 道具: 5250(コンパイル・実行・確認)、SSH(`CPYFRMSTMF` でのソース取り込み)/ 同時接続数: 5250×1(SSHでのソース取り込みは都度接続し直します。02-04・05-01・06-06と同じやり方です)/ 作る・変えるオブジェクト: `<USER>1/F0608A` / DBVER: 1 / 依存するプローブ: なし / PTF 依存: なし / 容量の目安: わずか

## ゴール

- `dcl-f` の `usage`/`keyed` キーワードで、更新・追加・削除ができるファイルを自由形式で宣言できる。
- `likerec` でレコード様式全体を1つのデータ構造として受け取り、`%kds` で(複数キーを想定した)`CHAIN` のキーを組み立てられる。
- 在庫引当(`ZAHIK4`)を `**FREE` で書き、`R0409A`(ZAHIK3、04-09)と同じ業務ロジック(在庫不足なら書かない)になっていることを確認できる。

## ウォームアップ

<details><summary>前回の復習(06-07)</summary>

1. `%LOOKUP` が、RPG III時代の `LOKUP` 命令と比べて、検索に失敗したときの挙動がどう変わりましたか?
2. `qualified` なデータ構造は、RPG III時代には無かったどんな問題を解決するためのものですか?
3. `F0607A` は、`ZAIKOM`をキー付きプライマリー・ファイルにしてRPGサイクルへ任せる代わりに配列+`%LOOKUP` を使ったことで、商品コード順の並びが保証されなくなりました。何という命令でその並びを立て直しましたか?

答え: 1. `LOKUP` は検索に失敗しても結果標識が自動でOFFに戻らないため、毎回 `SETOF` しておく必要がありましたが、`%LOOKUP` は失敗時に自動的に `0` を返します(事前の `SETOF` が不要)。 2. 同じフィールド名を持つ複数のデータ構造を、1つのプログラムの中で名前がぶつからずに扱えるようにする問題です。 3. `SORTA`(配列を並び替える命令)。

</details>

## なぜ学ぶか

**06-07では、`SHOHIM`/`ZAIKOM` を配列に丸ごと読み込み、`%LOOKUP` で突き合わせる方法を扱いました。** この方法は「複数のレコードを一度にまとめて扱う」場面では便利でしたが、代償として、`ZAIKOM`をキー付きプライマリー・ファイルにしてRPGサイクルへ任せていたときにはタダで付いてきた商品コード順の保証を失い、`SORTA` で並びを立て直す必要がありました。

**このレッスンでは、`CHAIN` によるキー・アクセスに一度戻ります。** ただし04-08〜04-09の固定形式(F仕様書15桁目・31桁目)ではなく、`**FREE` の `dcl-f` キーワードで書き直します。題材は `R0409A`(ZAHIK3、04-09)そのものです——在庫を`CHAIN`で読み、数量が足りているか`COMP`で確かめ、足りていれば`UPDAT`で引き当てる、という3段構えのロジックでした。`F0608A`(ZAHIK4)は、この同じ業務ロジックを次の2点で拡張します。

1. **`likerec`**: `CHAIN`で読んだレコードを、個々のフィールドとしてではなく、ZAIKOMのレコード様式(`ZAIKOR`)全体を1つのデータ構造として受け取ります。RPG IIIのI仕様書には無かった発想です。
2. **`%kds`**: キー・フィールドを`KLIST`/`KFLD`のように仕様書で組むのではなく、データ構造から組み立てるBIFです。`ZAIKOM`のキーは`ZASHO`1つだけなので、これ自体は`%kds`を使わなくても書けますが、**複数のキー・フィールドを持つファイルでも同じ書き方が通用することを示すため**、あえてここで導入します。

あわせて、`UPDAT`(更新)だけでなく`WRITE`(追加)・`DELETE`(削除)、そして更新対象を絞り込む`%FIELDS`も扱います。この3つは04-09では出てきませんでした。

## 新出

- 中核概念:
  1. `dcl-f`の`usage`/`keyed`キーワードは、RPG IIIのF仕様書15桁目(ファイル・タイプ)・31桁目(`K`)の後継。
  2. `likerec`は「レコード様式全体を1つのデータ構造として受け取る」という、RPG IIIのI仕様書には無かった発想。
  3. `%kds`は、複数のキー・フィールドを配列的に組み立てる、`KLIST`/`KFLD`のBIF版。
- 構文: `dcl-f`(`usage`/`keyed`)、`update`/`write`/`delete`、`chain(n)`、`likerec`、`%kds`、`%fields`。

## 説明

### `dcl-f`の`usage`/`keyed` ―― F仕様書15桁目・31桁目の後継

04-09の`R0409A`は、`ZAIKOM`を次のように宣言していました。

```text
FZAIKOM  UF  E           K        DISK
```

15桁目の`U`(更新用)と31桁目の`K`(キー・アクセス)が、`**FREE`では次のようにキーワードへ変わります。

```rpgle
dcl-f zaikom disk usage(*update : *delete : *output) keyed;
```

`usage`には`*update`(04-09の`U`に相当)に加えて`*delete`・`*output`も指定しています。これは、このレッスンの後半で`DELETE`・`WRITE`も実演するためです(`*delete`が無いと`DELETE`は使えず、`*output`が無いと`WRITE`は使えません)。`keyed`は31桁目の`K`と同じ意味で、`ZAIKOM`は外部記述ファイルなのでパラメーターは付けません。

### `likerec` ―― レコード様式全体を1つのデータ構造として受け取る

```rpgle
// The whole ZAIKOM record as one data structure (likerec is
// automatically QUALIFIED - see header - so subfields are written
// as zaikomRec.zasho, zaikomRec.zasu, zaikomRec.zaupd).
dcl-ds zaikomRec likerec(zaikor);

// Just the key field(s) of ZAIKOM, in DDS key order, for %kds.
dcl-ds zaikomKey likerec(zaikor : *key);
```

`likerec(zaikor)`は、レコード様式`ZAIKOR`(`ZAIKOM`のDDSが定義する様式名)の**全フィールド**を1つのデータ構造として受け取ります。`likerec(zaikor : *key)`は、そのうち**キー・フィールドだけ**(DDSのキー順)を抜き出したデータ構造です。`ZAIKOM`はキーが`ZASHO`1つだけなので、`zaikomKey`は結果として`zasho`という1個のサブフィールドしか持ちません。

**`likerec`で定義したデータ構造は、自動的に`qualified`になります**(06-07で扱った、名前空間の衝突を避ける仕組みそのものです)。そのため`zaikomRec.zasho`・`zaikomRec.zasu`のように、DS名を頭に付けて参照します。`end-ds`を書かない、1行だけの宣言になる点にも注目してください。

### `%kds` ―― 複数キーを組み立てる、`KLIST`のBIF版

```rpgle
zaikomKey.zasho = prod;
...
chain(n) %kds(zaikomKey) zaikor zaikomRec;
...
chain %kds(zaikomKey : 1) zaikor zaikomRec;
```

`%kds(データ構造名)`は、そのデータ構造(`*key`で定義したもの)のサブフィールドを、DDSのキー順に並べたキー・リストとして`CHAIN`(や`SETLL`・`DELETE`など)へ渡します。RPG IIIで複数キー・フィールドを`KLIST`+`KFLD`で組み立てていたのに相当します。`%kds(zaikomKey : 1)`のように、2つ目の引数でキー・フィールドの個数を明示することもできます(省略した1つ目の`chain(n)`はこの個数指定を省略した形で、どちらも同じ1個のキーを渡しています)。**`ZAIKOM`はキーが1個しか無いため、ここでは`%kds`を使わなくても`chain(n) prod zaikor zaikomRec;`のように直接書けます。** それでもあえて`%kds`を使っているのは、キー・フィールドが2つ以上あるファイルで同じ書き方がそのまま通用することを、この1キーのファイルで先に練習しておくためです。

### ロックの取り方を`R0409A`から一歩進める: `chain(n)`による覗き見

`R0409A`は、在庫が足りるかどうかに関わらず、最初の`CHAIN`でレコードをロックし、`SHORT`のときもそのロックを`*INLR`まで持ち続けていました。`F0608A`は、まず`chain(n)`(**ロックを取らない**`CHAIN`)で在庫を覗き見て`NOTFOUND`/`SHORT`を先に判定し、**本当に更新する直前になって初めて**ロック付きの`CHAIN`を取り直します(この覗き見→再ロックという手順自体は、新出の中核概念としては数えていません。使っている構成要素は`chain(n)`・通常の`CHAIN`・`%kds`のいずれも上の「新出」に挙げた構文そのものであり、ここではその実践的な組み合わせ方(ロック競合の回避パターン)として読んでください)。

```rpgle
chain(n) %kds(zaikomKey) zaikor zaikomRec;

if not %found(zaikom);
  msg = 'NOTFOUND';
elseif zaikomRec.zasu < qty;
  msg = 'SHORT';
else;
  chain %kds(zaikomKey : 1) zaikor zaikomRec;
  if not %found(zaikom);
    msg = 'NOTFOUND';
  elseif zaikomRec.zasu < qty;
    msg = 'SHORT';
  else;
    zaikomRec.zasu -= qty;
    update zaikor zaikomRec;
    msg = 'OK';
  endif;
endif;
```

一次資料(ILE RPG言語リファレンス)によれば、更新用ファイルへの`CHAIN`に`N`という操作拡張子を付けると、レコードにロックをかけずに読み取れます。覗き見の時点で在庫が足りていても、ロックを取り直すまでの間に別のジョブが同じ商品を引き当てるかもしれないため、ロック付きの`CHAIN`のあとにもう一度`zaikomRec.zasu < qty`を確認し直しています。`SUB QTY ZASU`(04-09)に相当する部分は`zaikomRec.zasu -= qty;`、`UPDATZAIKOR`に相当する部分は`update zaikor zaikomRec;`です。

### `R0409A`(固定形式)と`F0608A`(`**FREE`)の対応

| `R0409A`(RPG III、04-09) | `F0608A`(`**FREE`、本レッスン) |
|---|---|
| `FZAIKOM UF E K DISK` | `dcl-f zaikom disk usage(*update:*delete:*output) keyed;` |
| `PROD CHAINZAIKOM 99` | `chain(n) %kds(zaikomKey) zaikor zaikomRec;` / `if not %found(zaikom);` |
| `ZASU COMP QTY 98`(LO) | `elseif zaikomRec.zasu < qty;` |
| `SUB QTY ZASU` / `UPDATZAIKOR` | `zaikomRec.zasu -= qty;` / `update zaikor zaikomRec;` |

### `update`/`write`/`delete`と`%fields` ―― `ZTEST1`での書き込み・削除デモ

`F0608A`は、04-09には無かった`WRITE`・`DELETE`・`%FIELDS`も、実在する6商品(`P00001`〜`P00006`)には一切触れない、使い捨ての商品コード`'ZTEST1'`を使って実演します(`runWriteDeleteDemo`という標識が既定で`*on`になっており、`CALL`するたびに毎回このデモも実行されます)。

```rpgle
dcl-ds zaikomOut likerec(zaikor : *all);
...
if runWriteDeleteDemo;
  zaikomOut.zasho = 'ZTEST1';
  zaikomOut.zasu  = 999;
  zaikomOut.zaupd = 20260926;
  write zaikor zaikomOut;

  zaikomKey.zasho = 'ZTEST1';
  chain %kds(zaikomKey) zaikor zaikomRec;
  if %found(zaikom);
    zaikomRec.zasu = 500;
    update zaikor %fields(zaikomRec.zasu);
  endif;

  delete %kds(zaikomKey) zaikor;
endif;
```

`WRITE`(レコード追加)は、`likerec(zaikor)`ではなく`likerec(zaikor : *all)`という**別の**データ構造(`zaikomOut`)を対象にしています。一次資料(ILE RPG言語リファレンス)によれば、外部記述ファイルへの`WRITE`は原則として`*OUTPUT`または`*ALL`型のデータ構造を要求します(ただし一次資料には例外規定があり、無指定=`*INPUT`型の`likerec`データ構造でも、そのDISKファイルの出力バッファーと入力バッファーのレイアウトが完全に一致していれば`WRITE`に使えます。`ZAIKOM`のような単純な物理ファイルでは実際にこの条件を満たすため、`zaikomRec`でも`WRITE`できた可能性がありますが、本プログラムは入力専用の`zaikomRec`と出力用の`zaikomOut`を分けることで、この例外に依存しない、より明確な設計を選んでいます)。

`update zaikor %fields(zaikomRec.zasu);`は、`zaikomRec`の**`zasu`サブフィールドだけ**をデータベースへ反映します(`zaupd`は直前の`WRITE`で入れた`20260926`のまま変わりません)。在庫引当の本体ロジック(上の`update zaikor zaikomRec;`)が**データ構造全体**を書き戻すのと対照的に、`%FIELDS`は**特定のフィールドだけ**を書き戻したいときに使います。`DELETE`は、`CHAIN`で読み直さなくても`%kds`を検索引数として直接渡せます(一次資料によれば`%kds`は`CHAIN`・`DELETE`・`READE`・`READPE`・`SETGT`・`SETLL`のどれでも検索引数として使えます)。この一連は、実在する6商品のどれにも触れないため、**それ自体は`TXRESET`が無くても後始末が完結しています**(`ZTEST1`は`WRITE`されたあと同じ実行内で`DELETE`されます)。ただし在庫引当の本体ロジック(`P00001`の`ZASU`を2減らす部分)は`TXRESET`が必要です(下の「片付け」参照)。

## 実演

**この実演で作るオブジェクト(`F0608A`)は、著者による実機コンパイル・実行(V1/V2、下の「実機メモ」参照)まで確認済みです。** `WORKSTN`を使わない、04-09の`R0409A`と同じ「1回`CALL`すれば1回処理して終わり」のバッチ型プログラムなので、`EXFMT`のように実デバイスの応答を待ち続けることはありません。**ただし、手順5の`WRKSPLF`・`DSPJOBLOG`による確認、および演習1・3の`STRSQL`による確認は、学習者自身の5250/SQLセッションでの対話操作(V3)であり、この教材の検証ハーネス(非対話SSH)では確認できません。この「実演」節が示す`ADDPFM`+`CPYFRMSTMF`によるソース取り込み手順そのものも、下の「実機メモ」で述べるとおり検証していません。** 手順5の`CALL`のあと、そのまま`WRKSPLF`で結果を確認してください。

1. SSHで接続し、`~/ibmi-kyozai`を最新にします(`git pull`)。`exit`で5250に戻ります。
2. 5250のコマンド行で、`<自分のユーザー名>1/QRPGLESRC`にメンバーを用意します(`QRPGLESRC`自体は06-01bで新規作成済みのはずです)。

   ```text
   ADDPFM FILE(<自分のユーザー名>1/QRPGLESRC) MBR(F0608A) SRCTYPE(RPGLE) TEXT('File I/O with dcl-f: ZAHIK4')
   ```

3. SSHでもう一度接続し、`src/qrpglesrc/f0608s.rpgle`を取り込みます。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/f0608s.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/F0608A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

4. 5250に戻り、コンパイルします。

   ```text
   CRTBNDRPG PGM(<自分のユーザー名>1/F0608A) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(F0608A)
   ```

   Highest Severity 00になることを確認してください。

5. **この`CALL`の前に、必ず`<自分のユーザー名>1/TXRESET`を実行してください。** `06-05`の`F0605A`も`dcl-pr extpgm`経由で`R0409A`(ZAHIK3)を`CALLP`しており、`ZAIKOM`の`P00001`を同じように45→43へ変えます。`06-05`自身の片付け・セルフチェックが、その演習後の`TXRESET`実行を既に求めているため、指示どおりに進めていれば在庫は45に戻っているはずですが、`F0608A`の既定デモも同じ行を書き換えるので、ここでも実行しておくと数値がずれません。

   ```text
   <自分のユーザー名>1/TXRESET
   CALL PGM(<自分のユーザー名>1/F0608A)
   ```

   `WRKSPLF`で、次の1行が印刷されることを確認してください(在庫45から2個引き当てた場合の値です)。

   ```text
   P00001  0000043  OK
   ```

   **在庫が45以外の値から始まっていた場合は、印字される数値もその分だけ変わります**(引き当て自体は常に「現在の在庫−2」になります)。大事なのは「45→43」という特定の数値そのものではなく、`R0409A`(04-09)が確立した「読んで、確かめて、引き当てる」というパターンが、`likerec`+`%kds`を使ってもそのまま成立していることです。

   `runWriteDeleteDemo`による`ZTEST1`へのWRITE・`%FIELDS`限定UPDATE・DELETEの一連も、この同じ`CALL`の中で実行されています。エラー・メッセージが1件も出ていなければ(`DSPJOBLOG`で確認できます)、この一連も正常に完了しています(印字はされません。設計上、この部分は無言で成功する作りです)。

## 演習

1. `ZAHIK4`(`F0608A`)と`ZAHIK3`(`R0409A`、04-09)が、在庫不足の場面で同じ結論(**どちらも書き込まない**)に達することを確認してください。`F0608A`のソースの`dcl-s qty packed(7:0) inz(2);`という行を`inz(999);`に変えて再コンパイル・実行し、`SHORT`と印字され、`ZASU`の値(直前の実演で確認した値)が**変わっていない**ことを`STRSQL`の`SELECT ZASU FROM ZAIKOM WHERE ZASHO='P00001'`で確認してください。並べて比べたい場合は、`R0409A`側も`Z-ADD999`(04-09の演習1と同じ変更)に直しておいてください(04-09の演習は`Z-ADD2`に戻す指示までは求めていないため、そちらの現在の値が`Z-ADD2`のままか`Z-ADD999`のままかは、自分のメンバーを開いて確認してください)——**同じ「在庫が足りなければ書かない」という業務ルールが、固定形式と`**FREE`のどちらでも変わらないことを、自分の目で確かめてください。**
2. `prod`の初期値(`dcl-s prod char(6) inz('P00001');`)を`inz('P99999');`(存在しない商品コード)に変えて再コンパイル・実行し、`NOTFOUND`と印字されることを確認してください(`ZASU`欄はクリア直後の`0000000`のままです)。
3. (発展)`%FIELDS`が本当に`zasu`だけを書き戻し、`zaupd`は素通りさせていることを確認します。次の2箇所を**一時的に**変更してください。
   - `zaikomRec.zasu = 500;`の次の行に、`zaikomRec.zaupd = 20991231;`をもう1行追加する(データベースへ実際に反映されるかどうかを試すための、ダミーの日付です)。
   - `delete %kds(zaikomKey) zaikor;`の行をコメントアウトする(結果を`SELECT`で見られるように、消さずに残しておくためです)。

   再コンパイル・実行し、`STRSQL`で`SELECT * FROM ZAIKOM WHERE ZASHO='ZTEST1'`を実行してください。`ZASU=500`(`%FIELDS`で指定したとおり)は書き換わっているのに対し、`ZAUPD`は追加した`20991231`ではなく`20260926`(`WRITE`のときの値)のままのはずです——これが、`update zaikor %fields(zaikomRec.zasu);`が`zaikomRec`の`zasu`だけをデータベースへ反映し、同じデータ構造の`zaupd`(メモリー上では`20991231`に変わっている)を無視した証拠です。

   確認できたら、**まず`STRSQL`で`DELETE FROM <自分のユーザー名>1/ZAIKOM WHERE ZASHO='ZTEST1'`を実行してこの1行を手作業で消し**、上の2箇所(追加した`zaikomRec.zaupd = 20991231;`の行・`delete`のコメントアウト)を元に戻してから再コンパイル・**再実行**し、同じ`SELECT`が0行になる(`DELETE`オペレーションが効いている)ことを確認してください。**この手作業の削除を省いて先に`delete`の行だけ戻して再実行すると、`ZAIKOM`のキー(`ZASHO`)には一意性制約が無いため、`WRITE`は重複したキーのままもう1行追加されてしまい、`SELECT`は0行になりません。** この演習は検証ハーネスでは確認しておらず、期待値はソースのロジックからの手計算です。実際にコンパイル・実行して、自分の手元で確認してください(なお、この演習の途中で`ZTEST1`の行を消し忘れても、演習5の`TXRESET`が`ZAIKOM`を全件削除してから初期6行を入れ直すため、最終的には残りません)。
4. 演習1・2で書き換えた`qty`・`prod`の初期値を、それぞれ`2`・`'P00001'`に**必ず戻して**再コンパイルしておいてください。
5. **最後に、必ず`<自分のユーザー名>1/TXRESET`を実行し、`ZAIKOM`を初期状態(`P00001`=45)に戻してください。** `F0608A`は04-09の`R0409A`と**同じ`ZAIKOM`テーブル**を書き換えます。06-15・07-05のチェックポイント(および06-07の演習を後からもう一度やり直す場合)は、いずれも`ZAIKOM`が既知の値であることを前提にしているため、リセットを忘れると、それらの照合結果が狂います。

## セルフチェック

- [ ] `dcl-f`の`usage`/`keyed`キーワードで、更新・追加・削除ができるファイルを宣言できる。
- [ ] `likerec(様式名)`でレコード様式全体を、`likerec(様式名 : *key)`でキー・フィールドだけを、それぞれ1つのデータ構造として受け取れる。
- [ ] `%kds`でキー・リストを組み立て、`CHAIN`・`DELETE`の検索引数として渡せる。
- [ ] `chain(n)`(ロックなし)と通常の`CHAIN`(ロックあり)を使い分ける理由を説明できる。
- [ ] `update`(データ構造全体)と`update ... %fields(...)`(特定フィールドのみ)の違いを説明できる。
- [ ] `F0608A`を実装し、`R0409A`(04-09)と同じ「在庫不足なら書かない」結論になることを確認できた(演習1)。
- [ ] **演習の最後に`TXRESET`を実行し、`ZAIKOM`を初期状態に戻した。**

## 片付け

`F0608A`はそのまま残してください。**ただし、演習でデータを変更した場合は、必ず`<自分のユーザー名>1/TXRESET`を実行してから片付けを終えてください。** `F0608A`は04-09の`R0409A`と同じ`ZAIKOM`テーブルを書き換えます。06-15・07-05のチェックポイント(および06-07の演習を後からもう一度やり直す場合)は、`ZAIKOM`が既知の値(`P00001`=45を含む6行)であることに依存しているため、リセット漏れはそれらの照合を狂わせます。`ZTEST1`という商品コードは、デモの`WRITE`直後に同じ`CALL`内で`DELETE`されるため、通常はデータベースに残りません(演習3で一時的にコメントアウトした場合を除きますが、`TXRESET`は`ZAIKOM`を全件削除してから初期6行を入れ直すため、消し忘れてもここで一緒に消えます)。

## まとめ

| 英語 | 日本語 |
|---|---|
| Like record format (`LIKEREC`) | レコード様式全体を型として複製するキーワード |
| Key list built from a data structure (`%KDS`) | データ構造からキー・リストを組み立てる組み込み関数 |
| No-lock read (`CHAIN(N)`) | ロックを取らない読み取り |
| Field selector (`%FIELDS`) | 更新対象のフィールドを限定する指定 |

次のレッスン(06-09)では、例外処理(`monitor`/`on-error`)とデバッグを扱います。

## 実機メモ

- 確認日: 2026-09-27(接続`part06-0509-procs-files`、著者の検証用ライブラリーで06-05〜06-09用の5本を1回の接続でまとめて確認)。**`F0608A`を`CRTBNDRPG`で実際にコンパイル(Highest Severity 00)し(V1)、`CALL`で実行して`P00001  0000041  OK`という行が印字されることを、接続結果の`run`セクションの生テキストを直接読んで確認した(V2)。** この接続のステップ順は「`F0605A`のコンパイル→実行、`F0606A`のコンパイル→実行、`F0607A`のコンパイル→実行、`F0608A`のコンパイル→実行、…、最後に`TXRESET`」で、`F0608A`より**前**に`TXRESET`を挟むステップは無いことを、この接続が実際に使ったマニフェスト自身のステップ一覧で確認済みです。`F0605A`は`dcl-pr extpgm`経由で`R0409A`(ZAHIK3)を`CALLP`し、`P00001`を45→43に減らします(06-05自身の実機メモ・本文が明記している効果です)。そのため`F0608A`が実行された時点で在庫は既に43で、`F0608A`自身の既定デモ(2個引き当て)がそこからさらに減らして`0000041`になった、という説明はマニフェストのステップ順から直接裏付けられています。**なお、この接続の時点では`F0608A`の`runWriteDeleteDemo`標識はまだ既定`*off`で(ソース側の実機修正前)、`ZTEST1`へのWRITE/DELETEデモそのものはこの接続では実行されていません**(下の`part06-08-writedelete`が、`*on`に直したあとの動作を別途確認しています)。**`TXRESET`を先に実行してから`F0608A`を1回だけ実行した場合の正しい値は`0000043`です**(04-09の`R0409A`自身が45→43で確認済みの基準と一致します)。上の「実演」節は、`TXRESET`を先に実行するこの前提で書いてあります。
- 別の接続`part06-08-writedelete`(確認日2026-09-27、同日・別接続、`F0605A`等を経由しない単独の接続)で、`OK`/`SHORT`/`NOTFOUND`の3経路すべてを確認しました(いずれもV2、接続結果の`run`セクションの生テキストを直接読んで確認。`CPYSPLF`はこのハーネスの非対話ジョブでは`CPF3303`で失敗するため使っていません)。
  - `qty`を`999`に変えた使い捨てメンバー(演習1相当): `P00001  0000045  SHORT`(この接続では`F0605A`を経由しておらず、在庫がまだ45のままだった時点での実行)。
  - `prod`を`'P99999'`に変えた使い捨てメンバー(演習2相当): `P99999  0000000  NOTFOUND`。
  - 実際に配布している既定版(`qty=2`・`prod='P00001'`、`runWriteDeleteDemo`は`*on`): `P00001  0000043  OK`(45→43)。
  - `TXRESET`実行後、`SELECT * FROM ZAIKOM ORDER BY ZASHO`で全6行(`P00001`=45・`P00002`=3・`P00003`=250・`P00004`=60・`P00005`=12・`P00006`=22)が初期値に戻っていることも確認しました。
- **`runWriteDeleteDemo`(既定`*on`)による`ZTEST1`へのWRITE・`%FIELDS`限定UPDATE・`%kds`によるDELETEの一連は、`part06-08-writedelete`でエラー・メッセージ0件で完了したこと(V2)まで確認済みです。** ただし、この一連の**途中経過**(`WRITE`直後に`ZASU=999`になっていること、`%FIELDS`更新後に`ZASU=500`・`ZAUPD=20260926`になっていること)を、実行の途中で`SELECT`して直接読み取る確認はどの接続でも行っていません——確認したのは「エラーが出ずに完了した」ことだけで、途中の値そのものはソースのロジックからの推論です。演習3は、この途中経過を読者自身が`DELETE`行を一時的にコメントアウトして確認するためのものです。
- `WRKSPLF`・`DSPSPLF`で確認したものではありません。このハーネスの非対話SSHジョブは、プログラム記述の印刷装置ファイル(`QSYSPRT`)に対して実スプール・ファイルを作らないため、接続結果の`run`セクションに直接現れたテキストを読んで確認しています。**5250で実際に`WRKSPLF`・`DSPJOBLOG`を操作して結果を見る部分、および演習1・3で`STRSQL`を対話的に操作して`SELECT`を実行する部分は、このハーネス(非対話SSH)では検証できないV3です。** 印字される行・`TXRESET`後の`ZAIKOM`全6行の内容は、上記のとおり接続の`run`セクション・SQLの`collect`結果でV2まで確認済みです(ただし`ZTEST1`の途中経過は、直前の項目のとおり確認していません)。5250の画面をこの手順どおりに実際に操作する部分そのものは、読者自身の確認に委ねます。
- **この「実演」節が示す取り込み手順(読者自身が`ADDPFM`でメンバーを用意し、`git clone`済みツリーを`STMFCCSID(1208)`付きの`CPYFRMSTMF`で取り込む経路)そのものは、上記どちらの接続でも検証していません。** 両接続とも、検証ハーネス自身がソースを直接`<USER>2/QRPGLESRC`のメンバーへ書き込む、別の転送経路(ハーネス固有の`file`ステップ)を使っています。ソースの内容自体は(各接続時点の)`src/qrpglesrc/f0608s.rpgle`と同一です(ただし`part06-0509-procs-files`の時点では`runWriteDeleteDemo`がまだ`*off`既定だった、上記のとおりの古い版です)が、`ADDPFM`+`CPYFRMSTMF`という経路そのものをたどった場合の結果は未検証です(06-06自身の実機メモに書かれている制約と同じ状況です)。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
