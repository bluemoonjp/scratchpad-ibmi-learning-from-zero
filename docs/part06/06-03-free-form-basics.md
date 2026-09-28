# 06-03 `**FREE` の骨格・データ型・制御構造

> 所要時間: 75分(長め)/ 前提レッスン: 06-01b / 目標番号: 5 / 観測方法: `WRKSPLF` / 道具: 5250(SEU、直接貼り付け)/ 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1/F0603A` / DBVER: 1 / 依存するプローブ: P24・P10(SEUが`**FREE`を扱えないという記述、未実施) / PTF 依存: なし / 容量の目安: わずか

## ゴール

- `**FREE` だけの1行目から始まる、桁位置に縛られない完全自由形式のソースを書ける。
- `dcl-s`/`dcl-c` で `char`/`packed`/`zoned`/`ind` 型を宣言し、`if`/`select`/`dow`/`for` で条件分岐・繰り返しを書ける。
- 04-05(`R0405A`)と同じロジックを、完全自由形式で書き直せる(`F0603A`)。

## ウォームアップ

<details><summary>前回の復習</summary>

1. 固定形式のRPG IVソースの中に、自由形式の計算部分を挟むとき、開始と終了に書くキーワードはそれぞれ何ですか?
2. RPG IIIには一つも存在せず、RPG IVで初めて登場した、`%` で始まる呼び出しの総称は何と呼びますか?

答え: 1. `/FREE`(開始)・`/END-FREE`(終了) 2. BIF(組み込み関数)

</details>

## なぜ学ぶか

**ここから先(第6部・第7部)は、RPG IV の完全自由形式(`**FREE`)が主力言語になります。** 06-01・06-01bで「桁位置が変わり、D仕様書が加わった固定形式RPG IV」を橋渡しとして見てきましたが、この課では**その桁位置そのものを捨てます**。ソースの1行目に `**FREE` とだけ書くと、以降は好きな位置から命令を書ける自由な記述に変わります。

ただし自由になった分、いくつかの規約が変わります。RPG IIIでは「結果フィールドが最初に登場したC仕様書の行」が、そのフィールドの長さ・小数桁数を暗黙に決めていました(04-05の `Z-ADD82 SCORE 30` のように)。**完全自由形式では、使う前に `dcl-s` で型を宣言しておく必要があり、この暗黙の決め方は無くなります。** また `IFxx`/`DOWxx` という書き方自体が、自由形式では使えません(一次資料(ILE RPG言語リファレンス)によれば「使用不可、`IF`/`DOW` オペレーションを使うこと」と明記されています)。変わるのは「標識を意識しなくてよい」という点そのものではなく(04-05のとおり `IFxx` も既に標識番号を書かずに済む書き方でした)、比較の**書き方**です——Factor 1・比較コード(`xx`)・Factor 2という3つに分かれた形が、そのまま1つの真偽値の式(`score >= lowscore`)に変わります。

この課では、04-05で作った `R0405A`(構造化命令とサブルーチン: `IFxx`/`ANDxx`/`DOWxx`/`EXSR`-`BEGSR`-`ENDSR`)と**同じ処理・同じ結果**を、完全自由形式の `F0603A` として書き直します。同じロジックが桁位置無しでどう変わるかを、実際に手を動かして確認してください。

## 新出

- `**FREE` はソース1行目に単独で書く(以降すべてが桁位置に縛られない完全自由形式になる)。
- 型は使う前に `dcl-s` で宣言しておく(RPG IIIの「結果フィールドの初出行で長さが決まる」方式とは逆転している)。
- `select` の `other` は省略できるが、このレッスンでは規約として書く。
- `ctl-opt`(コンパイル時オプション)
- `dcl-s`/`dcl-c`(`inz`・`like` 込み)
- 主な型: `char`・`packed`・`zoned`・`ind`
- `if`/`else`/`select`/`when`/`other`
- `dow`/`for`
- 名前付き `ind`(標識を番号ではなく変数として扱う)

`%` で始まる組み込み関数(BIF)は、この課では一切使いません(06-01b・06-06で扱います)。`dcl-f`(印刷装置ファイルの宣言)・`dcl-ds`(データ構造)・`write` は、印字結果を確認できるようにするための最小限の配管として出てきますが、正式に扱うのは06-04(`dcl-f`)・06-07(`dcl-ds`)なので、ここでは新出に数えません。`exsr`/`endsr`(サブルーチンの呼び出し・終了)は04-05から書き方が変わりません。**`begsr` はオペコード自体は変わりませんが、オペランドの順序が04-05とは逆転しています**——04-05の `PRTOUT BEGSR`(Factor 1にサブルーチン名、その後にオペコード)に対し、自由形式は `begsr prtout;`(オペコードが先、名前が後)です。`if` のFactor1・Factor2から式への転換と同じ「並びが変わる」例の1つなので、ここで数える新出には含めませんが、見た目をそのまま比べると混乱しやすい点として触れておきます。`+=`(複合代入。**`ADD` に代わるもので、`ADD` 自体は `IFxx`/`DOWxx` と同様に自由形式では使えません**)や `*inlr = *on;`(標識番号を使わず `*INLR` へ直接代入)も出てきますが、見ればわかる書き方なのでこれも新出には数えません。

## 説明

### `**FREE`:桁位置から解放された1行目

```text
**FREE
ctl-opt option(*nodebugio);
```

1行目に `**FREE` とだけ書くと、そのメンバー全体が完全自由形式になります(固定形式の桁位置は一切関係なくなります)。コメントは `//` から行末までです。

### `ctl-opt`:H仕様書の後継

`ctl-opt` は、RPG IIIのH仕様書に当たる、コンパイル時オプションをキーワードで書く場所です。ここでは `option(*nodebugio)`(入出力仕様書に対するデバッグ用のブレークポイントを生成しないオプション)だけを指定しています。**`dftactgrp(*no)` は06-05の新出概念なので、この課では意図的に使いません。**

### 型は使う前に宣言する: `dcl-s`/`dcl-c`

```text
dcl-c lowscore 80;
dcl-c hiscore 100;

dcl-s score packed(3:0) inz(82);
dcl-s sum packed(5:0) inz(0);
dcl-s sum2 like(sum) inz(0);
dcl-s idx zoned(3:0) inz(1);
dcl-s idx2 like(idx) inz(1);
dcl-s grade char(1) inz(' ');
dcl-s validscore ind inz(*on);
dcl-s sumlabel char(4) inz(' ');
```

`dcl-c` は名前付き定数です。`lowscore`(80)・`hiscore`(100)のように、比較に使う固定値に名前を付けておくと読みやすくなります。

`dcl-s` は変数の宣言です。**名前・型(長さ:小数桁数)・`inz(初期値)` を、使うより前に書いておく必要があります。** 04-05の `Z-ADD82 SCORE 30`(「30」=長さ3・小数桁数0という指定が、`SCORE` という名前の初出行そのもの)とは逆に、ここでは `dcl-s score packed(3:0) inz(82);` と、型を明示してから初期値を与えます。`like(sum)` は「`sum` と同じ型・長さを複製する」書き方で、`sum2` は `sum` と同じ `packed(5:0)` に、`idx2` は `idx` と同じ `zoned(3:0)` になります。

### 主な型: `char`・`packed`・`zoned`・`ind`

- `char(n)`: 文字。`grade char(1)` は1バイトの英数字。
- `packed(桁数:小数桁数)`: パック10進数。
- `zoned(桁数:小数桁数)`: ゾーン10進数(1バイト1桁の従来の数値表現)。
- `ind`: 標識(真偽値)。`*on`/`*off` のどちらかを持つ1バイトの型です。

### 条件分岐: `if`/`else`/`select`/`when`/`other`

04-05の `IFxx`/`ANDxx`/`ELSE`/`ENDIF` に当たる部分です。

04-05(`R0405A`、固定形式RPG III):

```text
C           SCORE     IFGE 80
C           SCORE     ANDLE100
C                     MOVEL'A'       GRADE  10
C                     ELSE
C                     MOVEL'B'       GRADE
C                     ENDIF
```

06-03(`F0603A`、完全自由形式):

```text
if score >= lowscore and score <= hiscore;
  grade = 'A';
else;
  grade = 'B';
endif;
```

`IFGE`/`ANDLE` という書き方自体は自由形式では使えず、そのかわり `score >= lowscore and score <= hiscore` という1つの真偽値の式を書きます。`and`/`or` はそのまま式の中で使えます。

`select`/`when`/`other` は、04-05では扱っていない分岐の書き方です。

```text
select;
  when sum < 10;
    sumlabel = 'LOW ';
  when sum <= 20;
    sumlabel = 'MID ';
  other;
    sumlabel = 'HIGH';
endsl;
```

`when` は上から順に評価され、最初に真になったものだけが実行されます。`other` はどれにも当てはまらなかったときの受け皿で、**文法上は省略できますが、このレッスンでは必ず書く規約にします**(想定外の値を黙って素通りさせないため)。

### 繰り返し: `dow`/`for`

04-05の `DOWLE5`/`ENDDO` に当たる部分です。

04-05(`R0405A`):

```text
C           I         DOWLE5
C                     ADD  I         SUM
C                     ADD  1         I
C                     ENDDO
```

06-03(`F0603A`):

```text
dow idx <= 5;
  sum += idx;
  idx += 1;
enddo;
```

`for` は04-05では扱っていない繰り返しです。同じ合計を、もう1つの構造化ループの書き方で求め直しています。

```text
for idx2 = 1 to 5;
  sum2 += idx2;
endfor;
```

### 名前付き標識(`ind`)

```text
dcl-s validscore ind inz(*on);
```

```text
if score < 0 or score > hiscore;
  validscore = *off;
  grade = 'X';
endif;
```

```text
if not validscore;
  sumlabel = 'BAD ';
endif;
```

`ind` 型の変数は、標識を `*IN99` のような番号ではなく、`validscore` という名前で持てます。04-05の演習3(範囲外の点数を `ORxx` で `'X'` にする)を拡張し、範囲外の判定を `validscore` という名前付き標識に記録し、あとで `if not validscore;` として読み返しています。**`*INLR` も標識そのものです**(`*inlr = *on;` で直接代入できます。04-05の `SETON LR` に対応する書き方です)。

### 06-01bで予想したオペコードの答え合わせ

06-01bの演習2は、`V0601A` のオペコード(`MOVEL`・`CHAIN`・`IFEQ`・`READ`・`GOTO`・`TAG`・`SETON`・`EXCEPT`)それぞれが将来 `%BIF` に置き換わるか、オペコードのまま残るかを予想してもらい、「答え合わせは06-03・06-06で行う」としていました。`F0603A` の元になった `R0405A`(04-05)自身が使っているのは、このうち `MOVEL`・`IFGE`/`ANDLE`(`IFEQ` と同じ「比較コード付きの `IF`」系列)・`SETON LR`・`EXCPT` の4つで、`CHAIN`・`READ`・`GOTO`・`TAG` は使っていません。実際にどうなったかというと、`MOVEL'A' GRADE` は `grade = 'A';` という代入式に、`IFGE 80`/`ANDLE 100` は `if score >= lowscore and score <= hiscore;` という1つの真偽値の式に、`SETON LR` は `*inlr = *on;` という直接代入に、`EXCPT`(O仕様書出力)は `dcl-ds outrec` + `write qsysprt outrec` に、それぞれ姿を変えています。**`%BIF` に置き換わったものは実は一つもありません**——`%` は06-01b・06-06の範囲であり、この課で0個だと明言しているとおりです。`CHAIN`・`READ` は06-01bのヒントどおりオペコードのまま残りますが、`R0405A` 自体がこれらを使わないため、その姿は06-04(`F0604A`、`CHAIN`を使う受注照会)で確認できます。`GOTO`/`TAG` も同様に `R0405A` には登場しないため、この課での答え合わせの対象外です。(なお06-01の演習1が空欄のまま残した「3世代対応表」は `R0408A`/`V0601A` 側の行なので、`R0405A` を書き直すこの課ではなく、`R0408A` を書き直す06-04で埋まります。)

## 実演

1. `<USER>1/QRPGLESRC` は06-01bで新規作成済みのはずです。まだ無ければ作成してください(06-01の `CVTRPGSRC` の変換先である `QRPGLE112` とは別の、手書きソース用のファイルで、同じレコード長112です)。

   ```text
   CRTSRCPF FILE(<USER>1/QRPGLESRC) RCDLEN(112) TEXT('RPG IV free-form source')
   ```

   すでに `QRPGLESRC` がある場合は `CPF5813`(ファイルは既に存在する)が出るだけなので、気にせず次へ進んでください。

2. `WRKMBRPDM FILE(<USER>1/QRPGLESRC)` でメンバー `F0603A`(ソース・タイプ `RPGLE`)を新規作成し、SEUで開いて次を直接貼り付けます(桁位置は一切気にしなくてよい行です。**06-01が扱うとおり、SEUの構文検査は `**FREE` を正しく理解しないと一般に言われています(一次資料の記述による裏付けはなく、この教材ではまだ実機確認していないV3の推測です)。もし的外れな警告が出た場合は、無視してかまいません。**`src/qrpglesrc/f0603s.rpgle` から、コメントを省いたものと同じ内容です)。

   ```text
   **FREE
   ctl-opt option(*nodebugio);

   dcl-f qsysprt printer(23);

   dcl-c lowscore 80;
   dcl-c hiscore 100;

   dcl-s score packed(3:0) inz(82);
   dcl-s sum packed(5:0) inz(0);
   dcl-s sum2 like(sum) inz(0);
   dcl-s idx zoned(3:0) inz(1);
   dcl-s idx2 like(idx) inz(1);
   dcl-s grade char(1) inz(' ');
   dcl-s validscore ind inz(*on);
   dcl-s sumlabel char(4) inz(' ');

   dcl-ds outrec;
     outgrade char(1);
     outfill char(6) inz('  SUM=');
     outsum zoned(5:0);
     outcat char(1) inz(' ');
     outsumlabel char(4);
     outsep char(1) inz(' ');
     outsum2 zoned(5:0);
   end-ds;

   if score >= lowscore and score <= hiscore;
     grade = 'A';
   else;
     grade = 'B';
   endif;

   if score < 0 or score > hiscore;
     validscore = *off;
     grade = 'X';
   endif;

   dow idx <= 5;
     sum += idx;
     idx += 1;
   enddo;

   for idx2 = 1 to 5;
     sum2 += idx2;
   endfor;

   select;
     when sum < 10;
       sumlabel = 'LOW ';
     when sum <= 20;
       sumlabel = 'MID ';
     other;
       sumlabel = 'HIGH';
   endsl;

   if not validscore;
     sumlabel = 'BAD ';
   endif;

   exsr prtout;

   *inlr = *on;

   begsr prtout;
     outgrade = grade;
     outsum = sum;
     outsumlabel = sumlabel;
     outsum2 = sum2;
     write qsysprt outrec;
   endsr;
   ```

   `dcl-f`/`dcl-ds`/`write` は、印字結果を確認できるようにするための配管です(正式には06-04・06-07で扱います)。`score`(82点)を成績(`grade`)に変換し、`1` から `5` までの合計を `dow`(`sum`)と `for`(`sum2`)の両方で独立に求め、`select` で分類しています。**コンパイル・リストにはおそらく `RNF2318`(オーバーフロー標識が未指定のため自動割り当て)・`RNF7031`(`outcat`/`outfill`/`outsep` が参照されていない)に類する情報メッセージ(severity 00)が出ると考えられますが、これは同じパターン(オーバーフロー標識未指定・未参照フィールド)を持つ06-01の `V0601A` で実際に確認されたメッセージ・コードからの類推です。`F0603A` 自身のコンパイル・リストでこの2つのコードそのものを確認したわけではなく、未検証のまま残しています。どちらも実害のない注意である点は変わりません。**

3. コンパイルして実行します。

   ```text
   CRTBNDRPG PGM(<USER>1/F0603A) SRCFILE(<USER>1/QRPGLESRC) SRCMBR(F0603A)
   CALL PGM(<USER>1/F0603A)
   ```

4. `WRKSPLF` で、次の23バイトの行が印刷されることを確認します。

   ```text
   A  SUM=00015 MID  00015
   ```

   (`grade='A'`・`dow` で求めた合計`15`・分類`MID`(4桁固定幅で末尾に空白を1つ含む)・`for` で独立に求めた合計`15`。04-05の `R0405A` と**値**(`A`・`15`)は一致しますが、印字の並びは意図的に違います——04-05の実機メモでは `A             SUM= 00015` という別の並びで印刷したと記録されています。)

## 演習

`F0603A` 自体が04-05(`R0405A`)の書き直しなので、この演習は04-05の3問を、この完全自由形式版でもう一度やってみる形にします。次の3つの期待値は手計算で求めたもので、検証ハーネスでは未確認です。実際にコンパイル・実行して、自分の手元で確認してください。

1. `score` の初期値(`inz(82)`)を `55` に変えて再コンパイル・実行し、次のようになることを確認してください(04-05の演習1に対応)。

   ```text
   B  SUM=00015 MID  00015
   ```

   (`score >= lowscore and score <= hiscore` が偽になり `grade='B'`。`dow`/`for` はどちらも `score` を参照しないので合計は変わりません。)

2. `dow idx <= 5;` を `dow idx <= 10;` に変え(`for idx2 = 1 to 5;` はそのまま)、次のようになることを確認してください(04-05の演習2、`DOWLE5`→`DOWLE10` に対応)。

   ```text
   A  SUM=00055 HIGH 00015
   ```

   (`dow` 側だけ合計が1〜10の`55`になり、`sum <= 20` にも当てはまらず `sumlabel='HIGH'` に変わります。`for` 側の `sum2` は `idx2` を使っていて `dow`/`idx` とは無関係なので `15` のままです。)

3. `score` の初期値を `150`(100より大きい値)に変えて再コンパイル・実行し、次のようになることを確認してください(04-05の演習3、`ORxx` で範囲外を `'X'` にする、に対応)。

   ```text
   X  SUM=00015 BAD  00015
   ```

   (`score > hiscore` が真になり、`validscore` が `*off`・`grade` が `'X'` に。さらに `if not validscore;` で `sumlabel` が `'BAD '` に上書きされます。04-05では `ORxx` を新規に追加する演習でしたが、`F0603A` では最初からこの分岐が書かれているので、この演習は「その分岐を実際に発火させてみる」という位置づけです。)

## セルフチェック

- [ ] `**FREE` を1行目に単独で書き、桁位置を意識せずにソース全体を書けた。
- [ ] `dcl-s`/`dcl-c` で型(`char`/`packed`/`zoned`/`ind`)を、使う前に宣言する順序を守れた。
- [ ] `if`/`else`、`select`/`when`/`other` で条件分岐を書け、`other` を省略せず書く理由を説明できた。
- [ ] `dow`/`for` で繰り返し処理を書き、2つの合計が一致することを確認できた。
- [ ] 名前付き標識(`ind` 型)を宣言し、`*off`/`*on` の代入・`if not ...` での判定に使えた。
- [ ] `F0603A` を実装し、`A  SUM=00015 MID  00015` という印字を確認できた。
- [ ] 04-05(`R0405A`)の演習3問を、この自由形式版でもやり直せた。

## 片付け

作成したプログラムはそのまま残してください。

## まとめ

| 英語 | 日本語 |
|---|---|
| Fully free-form | 完全自由形式 |
| Column position | 桁位置 |
| Named indicator | 名前付き標識 |
| Compound assignment | 複合代入 |

次のレッスン(06-04)では、`R0408A`(JUCINQ3)と同じ受注照会ロジックを、新しく設計する画面(DSPF)と組み合わせて完全自由形式で書き直します。

## 実機メモ

- 確認日: 2026-09-26(接続 `part06-0103-freeform`、`<USER>2`(著者の検証用ライブラリー)で、1回の接続でV0601B・F0603Aの両方を確認)。**`F0603A` を `CRTBNDRPG` で実際にコンパイルしたところ Highest Severity 00 で成功し(V1)、`CALL` で実行して印刷内容が `A  SUM=00015 MID  00015` になることを、接続結果の`run`セクションの生テキストを直接読んで確認した(V2)。** `WRKSPLF`/`DSPSPLF` で確認したものではない——このハーネスの非対話SSHジョブは印刷装置ファイル(`QSYSPRT`)への出力に対して実スプール・ファイルを作らないため、同じ接続内の `CPYSPLF FILE(QSYSPRT) ...` ステップ(スプール・ファイルへ捕捉する目的の手順)は `CPF3303`(スプール・ファイルが見つからない)で失敗している。この失敗は無害で、印刷内容自体は`run`セクションに直接現れていた。**5250で実際に対話的に `CALL`・`WRKSPLF` する場合は、この制約は当てはまらず、本物のスプール・ファイルができるはずである**(対話操作でしか確かめられないV3で、この接続では検証していない。この制約は非対話の検証ハーネス固有のものであり、実機の一般的な挙動についての主張ではない)。
- **`src/qrpglesrc/f0603s.rpgle` 自身のヘッダー・コメントは、以前は「hardware-UNTESTED」「TODO: verify - hand-written, not yet compiled」という記述だったが、上記の実機確認(V1/V2)に合わせて修正済み**(コードそのもの(実行部)は無変更)。
- 依存プローブP24(機能段階の梯子)のうち、`**FREE` 自体(rung1)は `part06-gen-probe`(確認日2026-09-26)で、コンパイル成功だけでなく実行結果(メッセージ送出)まで確認済み(V1/V2相当)。それ以外にこの課が使う構文(`ctl-opt`・`dcl-s`/`dcl-c`・`char`/`packed`/`zoned`/`ind`・`if`/`select`/`dow`/`for`・名前付き`ind`)は、P24の梯子には含まれない——P24のrung2〜11は `DIM(*AUTO)`・`FOR-EACH`/`%LIST`/`IN`・`%SPLIT`/`%UPPER`・`SND-MSG`/`ON-EXCP`・`%CONCAT`・`WHEN-IS`・`DCL-ENUM`・`CONST`・`%HIVAL`・`%DATE(*YYMD)` であり、いずれもこの課の構文と一致しない。**ただし `F0603A` 自身がこの接続でHighest Severity 00でコンパイル・実行に成功しており(上記V1/V2)、その実機上でPTFの壁(rung12、`ASSERT-T`/`ASSERT-F`)に触れていないことは直接確認できている。**
- 演習3問(`score` の初期値を `55`・`dow` の上限だけ `10`・`score` の初期値を `150` にする)の期待値は、手計算のみで確認したものであり、検証ハーネスでは未実行(次の接続機会での確認が望ましい)。
- **実演手順(SEUで開いて直接貼り付ける操作そのもの)は対話操作であり、V3(このハーネスの非対話SSHでは検証できない範囲)である。** 今回の検証ハーネス自身はheredoc経由の別の転送手段でソースを送っており(ハーネス固有の事情)、SEUでの入力・貼り付け自体はこの接続では検証していない。git clone後にCLONEDIR配下のファイルをCCSID1208へ`CPYTOSTMF`し、`CPYFRMSTMF`で取り込む後半の変換経路は `part05-txlegacy-exec` で確認済み(ただしgit clone自体の実行はこの接続では検証していない——CLONEDIR相当のファイル配置をハーネスの`file`ステップで代用している)。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
