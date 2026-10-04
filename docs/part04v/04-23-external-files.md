# 04-23 外部記述ファイルを読む・更新する(固定形式 RPG IV)

> 所要時間: 120分(長め。2回に分けてかまいません)/ 前提レッスン: 04-22(さらに 02-05 でサンプル・データベースを作ってあること)/ 目標番号: 3 / 観測方法: `WRKSPLF`・`DSPRCDLCK` / 道具: 5250(SEU)または Code for i(04-21 で選んだ方)/ 同時接続数: 5250×1(演習 5 だけ、バッチ・ジョブを1本投入します)/ 作る・変えるオブジェクト: `<USER>1/V0423A`〜`V0423E`・`W0423A`(演習の解答用に `V0423F`)/ DBVER: 1 / 依存するプローブ: なし / PTF 依存: なし / 容量の目安: わずか

## ゴール

- 外部記述ファイル(DDS で定義済みのファイル)を F 仕様書で宣言し、`READ` で順に読み(`04-23-1`)、`CHAIN` でキーを指定して1件読める(`04-23-2`)。
- `KLIST`・`KFLD` で複合キーを作り、2つ以上のキー項目を持つファイルを `CHAIN` で読める(`04-23-3`)。
- 更新用ファイル(F 仕様書17桁目の `U`)・`UPDATE`・レコード・ロックを説明でき、在庫引当 `V0423D` を書ける。ロックを待たされたときの検知方法(エラー標識とファイル状況コード)を読める(`04-23-4`)。

## ウォームアップ

<details><summary>前回の復習(04-22)</summary>

1. `COMP` の結果標識(HI・LO・EQ)は、それぞれ何桁目?
2. 条件標識(その行を実行するかどうかを決める標識)は何桁目に書く?
3. `MOVEL` は左詰め・右詰めのどちら? 結果フィールドの、書き換えなかった部分はどうなる?

答え: 1. HI は71〜72桁目、LO は73〜74桁目、EQ は75〜76桁目。 2. 9桁目(`N` = 否定)と10〜11桁目(標識番号)。 3. 左詰め。書き換えなかった部分には古いデータがそのまま残る。

</details>

## なぜ学ぶか

ここまでのプログラムは、値をプログラムの中に書き込んでいました。**現場の固定形式 RPG IV プログラムの大半は、外部記述ファイル(`TOKUIM` のように、DDS で項目が定義されたファイル)を読み、書き換えます。** このレッスンでは、02-05 で作ったサンプル・データベースを、固定形式 RPG IV で読み(`V0423A`)、キーで引き(`V0423B`・`V0423C`)、書き換え(`V0423D`)、書き換え中に他のジョブから触られたらどうなるかを実験します(`V0423E`・`W0423A`)。

このレッスンの `V0423D`(在庫引当 `ZAHIK3`)は、**第6部の [06-05](../part06/06-05-subprocedures-prototypes.md)・[06-08](../part06/06-08-file-io-dclf.md)・[06-09](../part06/06-09-exception-handling-debugging.md) で、RPG III 版の `R0409A` の代わりに再登場します**(下の「`V0423D` を第6部で使うとき」)。RPG III を学んでいない読者は、第6部のその3レッスンで `R0409A` と書かれている箇所を `V0423D` と読み替えます。

## 新出

- 中核概念(3つ)
  1. 外部記述ファイルの F 仕様書と、`READ`(順に読む。EOF は結果標識の75〜76桁目)・`CHAIN`(キーで1件読む。「見つからない」は71〜72桁目)。
  2. `KLIST`/`KFLD`(複合キー)。
  3. `UPDATE`(読んだレコードを書き換える)とレコード・ロック(更新用ファイルを読むとレコードがロックされる)。
- 構文(5つ): `READ`・`CHAIN`・`KLIST`・`KFLD`・`UPDATE`。
- 読解用(この上限には数えません): `CHAIN` のエラー標識(73〜74桁目)と `INFDS`(ファイル情報データ構造)の `*STATUS`、`CHAIN(N)`(ロックを取らずに読む)、`UNLOCK`、`OVRDBF ... WAITRCD`、`CPF4131`(レベル・チェック)、`*LIBL` の照会メッセージ。

## 説明

### このレッスンのプログラムと、同じ出力になる RPG III 版

| プログラム | やること | 同じ出力になる RPG III 版(別ルート) |
|---|---|---|
| `V0423A` | `TOKUIM` を順に読んで全件印刷 | `R0406A`(04-06) |
| `V0423B` | `TOKUIM` を `'C00001'` で `CHAIN` | `R0407A`(04-07) |
| `V0423C` | `JUCHUD` を `KLIST`(受注番号+明細行番号)で `CHAIN` | なし(このルートで新しく加えたもの) |
| `V0423D` | `ZAIKOM` の在庫引当(`UPDATE`+ロック) | `R0409A`(04-09)。引数なしで、印刷行も同じ |
| `V0423E` | `ZAIKOM` の1件をロックして約30秒保持する(`UPDATE` はしない) | なし(ロック実験用) |
| `W0423A` | 同じ1件を読もうとして、ロック待ちを検知する | なし(ロック実験用) |

**RPG III の知識は前提にしていません。** 右端の列は「第6部でどちらのルートの読者にも同じ数値で比較できる」ための対応表で、読む必要はありません。

### 04-21 の復習: RPG IV の約束事(新しい概念ではありません)

このレッスンのソースは、04-21 で決めた次の約束の上に立っています。

- **`H DFTACTGRP(*YES)`**: このプログラムは、呼ばれると必ず既定の活動化グループ(OPM のプログラムが動くグループ)で動きます。一次資料(`CRTBNDRPG` の `DFTACTGRP` の説明)には、「allows ILE RPG programs to behave like OPM programs in the areas of file sharing, file scoping, and RCLRSC」とあります。この教材のソースは、すべてこの行から始めます(H 仕様書にこの書き方で指定したソースは、実機でコンパイルして Highest Severity 00 でした。**実機で確認(part04v-23run、2026-10-04)**。コンパイル・リストの「Default activation group」は `*YES` でした)。
- **メッセージの ID**: コンパイル時は `RNF` で始まるメッセージ(例: `RNF2120`)、実行時の照会メッセージは `RNQ`、実行時のエスケープ・メッセージは `RNX` で始まります。RPG III(OPM)で見る `RPG0xxx`・`RPG1216`・`QRG` のような ID は、ILE では出ないはずです。
- **コマンド**: `CRTBNDRPG`(RPG IV 用)でコンパイルします。`CRTRPGPGM`(RPG III 用)は使いません。
- **ソース**: メンバー・タイプ `RPGLE`、ソース物理ファイル `QRPGLESRC`(レコード長 112。04-21 で作成済み)に置きます。

### F 仕様書: 外部記述ファイルの宣言

```text
     FTOKUIM    IF   E             DISK
     FQSYSPRT   O    F  132        PRINTER
```

1行目が `V0423A` の `TOKUIM`、2行目が印刷装置ファイル `QSYSPRT` です。固定形式 RPG IV の F 仕様書の桁は次のとおりです(04-21 で見た桁表の続きです。一次資料: ILE RPG言語リファレンスの F 仕様書の桁見出しと、実機で動いた `V0601A` の F 仕様書の行)。

| 欄 | 桁 | `TOKUIM` の行 | 意味 |
|---|---|---|---|
| 仕様書の種類 | 6 | `F` | F 仕様書 |
| ファイル名 | 7〜16 | `TOKUIM` | |
| ファイル種別 | 17 | `I` | `I`=入力専用、`U`=更新用、`O`=出力 |
| ファイル指定 | 18 | `F` | `F`=全手続き方式(`READ`・`CHAIN` を自分で書いて読む方式) |
| ファイル形式 | 22 | `E` | `E`=外部記述(DDS で定義済み。項目の型・長さは DDS から自動で取り込まれる) |
| レコード・アドレス型 | 34 | `K`(`V0423B` から) | `K`=キーで読む(`CHAIN` に必要) |
| 装置 | 36〜42 | `DISK` | |
| キーワード | 44〜 | (`W0423A` の `INFDS(ZAINFO)`) | |

`V0423B`・`V0423C`・`V0423D` の F 仕様書は、ここに34桁目の `K` が加わります。`V0423D`・`V0423E`・`W0423A` の `ZAIKOM` は、17桁目が `U` です。

### READ: 順に読む

```text
     C     LOOP          TAG
     C                   READ      TOKUIM                                 99
     C   99              GOTO      ENDLP
     C                   EXCEPT
     C                   GOTO      LOOP
     C     ENDLP         TAG
```

`READ` の Factor 2(36桁目)にファイル名を書き、**ファイルの終わり(EOF)を知らせる結果標識は、75〜76桁目に書きます**(一次資料: `READ` の説明に「You can specify an indicator in positions 75-76 to signal whether an end of file occurred」とあります)。読めている間は標識 `99` は OFF、読むレコードがなくなると ON になります。**`GOTO`(Factor 2 に行き先)と `TAG`(Factor 1 に印)の組み合わせで、EOF まで読み続けるループを自分で作ります**(04-22 の `CABxx` と同じく、古い書き方です。ファイルの読み込みループでは今でもよく見かけます)。

### CHAIN: キーで1件読む

```text
     C     'C00001'      CHAIN     TOKUIM                             99
     C   99              MOVEL     'NOTFOUND'    TOKNM
```

Factor 1(12桁目)に探したいキーの値、Factor 2 にファイル名を書きます。**「見つからなかった」を知らせる結果標識(NR)は、71〜72桁目です**(`READ` の EOF 標識の75〜76桁目とは違う位置です)。見つかれば OFF、見つからなければ ON です。**見つからなかったとき、レコードの項目(`TOKNM` など)は書き換わりません。** 結果標識を必ず確認し、見つからなかった場合の処理を自分で書きます。F 仕様書の34桁目に `K` が無いと、Factor 1 は「キー」ではなく「相対レコード番号」として扱われます(一次資料: `CHAIN` の説明)。

73〜74桁目はエラー標識(ER)、75〜76桁目は空白でなければなりません(一次資料)。ER は「読解用」で、下の「ロックを待たされたとき」で使います。

### KLIST / KFLD: 複合キー

`JUCHUD`(受注明細)は、`JUNO`(受注番号、`6A`)と `JULINE`(明細行番号、`3S 0`)の2つがキーです(`db/v1/juchud.pf`)。2つ以上のキー項目を持つファイルを `CHAIN` するには、キーの値を並べた「キー・リスト」を `KLIST` で作ります。

```text
     DKJUNO            S              6A
     DKLINE            S              3S 0
     C     JKEY          KLIST
     C                   KFLD                    KJUNO
     C                   KFLD                    KLINE
     C     JKEY          CHAIN     JUCHUD                             99
```

- `KLIST` の Factor 1(12桁目)にキー・リストの名前(`JKEY`)を書き、直後の `KFLD` の結果フィールド(50桁目)に、キーを構成する項目を**ファイルのキー定義の順に**並べます(一次資料: 「the first KFLD field following a KLIST operation is associated with the leftmost (high-order) field of the composite key」)。
- `KFLD` の項目は、対応するキーの項目と**長さ・データ型・小数桁数が一致**していなければなりません(一次資料)。`JULINE` が `3S 0`(ゾーン10進、3桁、小数0桁)なので、`KLINE` も `3S 0` と宣言します。名前は一致しなくてかまいません。
- `KLIST` の名前を `CHAIN` の Factor 1 に書きます。`KLIST` は外部記述ファイルでだけ使えます。
- `KLIST`・`KFLD` は**自由形式では使えません**(一次資料の注記は「not allowed - use %KDS」)。第6部の [06-08](../part06/06-08-file-io-dclf.md) の `%kds` が、その後継です。

### UPDATE とレコード・ロック

```text
     FZAIKOM    UF   E           K DISK
     C     PROD          CHAIN     ZAIKOM                             99
     C                   SUB       QTY           ZASU
     C                   UPDATE    ZAIKOR
```

- **17桁目を `U`(更新用)にしたファイルを `CHAIN` や `READ` で読むと、そのレコードはロックされます**(一次資料: `CHAIN` の説明に「If the file is specified as update, all records are locked if the N operation extender is not specified」)。他のジョブは、そのレコードを同時に更新することも、更新用に読むこともできません(待たされます)。
- `UPDATE` の Factor 2 には、**ファイル名ではなくレコード形式名**(`ZAIKOM` の形式は `ZAIKOR`)を書きます(一次資料: 「A record format name is required with an externally described file」)。命令コード欄は26〜35桁目の10桁あるので、`UPDATE` はそのまま6文字で書けます。
- **`UPDATE` の前に、ロック付きの読み取り(`CHAIN`・`READ`)を同じファイルに対して済ませておく必要があります**(一次資料)。読み取りに失敗していたり、ロックなしで読んでいたりすると、`UPDATE` は使えません。
- `SUB QTY ZASU` は「`ZASU` = `ZASU` − `QTY`」(Factor 1 を省略した形)です。**在庫が足りるか(`COMP`)を、更新する前に確かめます。** 足りなければ `UPDATE` を飛ばします。
- `V0423D` は、**最初の `CHAIN` でロックを取り、在庫が足りなくて `SHORT` になった場合も、そのロックを `LR`(プログラムの終わり)まで持ち続けます。** 06-09 の「ロックの実験」は、この性質を使います。「ロックを取らずに先に覗く」書き方(`chain(n)`)は、06-08 の `F0608A` で扱います。

### ロックを待たされたとき: エラー標識とファイル状況コード(読解用)

別のジョブがロックしているレコードを読もうとすると、読もうとしたジョブは、ファイルに設定された待ち時間(`WAITRCD`。このリポジトリーの実機では、`TOKUIM` の既定値が60秒でした)だけ待ち、それでもロックが外れなければエラーになります。**エラー標識(`CHAIN` なら73〜74桁目)を指定しておくと、そのエラーでプログラムが止まらず、プログラムの流れの中で処理できます**(標識が無いと、プログラムが止まります。**実機で確認(part04v-23run、2026-10-04)**: エラー標識なしの `CHAIN`(`T423NE`)がロック待ちの時間切れになると、ジョブ・ログに `RNX1218`(`Unable to allocate a record in file ZAIKOM.`)と、照会メッセージ `RNQ1218`(`Unable to allocate a record in file ZAIKOM (R C G D F).` 応答の選択肢 R・C・G・D・F)が出ます。この実行では、照会メッセージに応答 `C`(取り消し)が自動で返り(ジョブ・ログに `C` と記録されました。このジョブの `INQMSGRPY` の値は確認していません。**未検証(2026-10-04時点)**)、続けて `CEE9901`(`Application error.  RNX1218 unmonitored by T423NE at statement 0000000012, instruction X'0000'.`)でプログラムが異常終了しました。12は `CHAIN` の行のステートメント番号です。応答できる対話ジョブなら、`RNQ1218` の照会で止まって応答を待つことになります)。

`W0423A` は、`CHAIN` の73〜74桁目に標識 `97` を指定し、`INFDS(ZAINFO)` で受けた `*STATUS`(ファイル状況コード)を印刷します。

```text
     FZAIKOM    UF   E           K DISK    INFDS(ZAINFO)
     DZAINFO           DS
     D ZASTS             *STATUS
     C     'P00006'      CHAIN     ZAIKOM                             9997
```

- ロックを待ち切れなかったときの状況コードは **`01218`**(一次資料は「record-lock error (status 1218)」と書いています)。実機でも、別のジョブがロックしているレコードに `chain(e)` をかけると `%status` が 1218 を返すことを確認しています(`part06-p43-lockdiag`、確認日 2026-09-28。[probes.md](../probes.md) 参照)。そのときジョブ・ログには `CPF5027`(`Record 120 in use by job or transaction ...`)が記録されました。
- `INFDS` の `*STATUS` は、ファイル操作のたびに更新されます(一次資料)。エラーが無ければ `00000` です。
- 06-09 の `chain(e)` と `%status` は、これを自由形式で書いたものです。`CHAIN(E)` と ER 標識は、**同時には指定できません**(一次資料)。
- **この読み方は、固定形式の `W0423A`・`V0423E` の組でも成り立ちました。実機で確認(part04v-23run、2026-10-04)**: `SBMJOB`(`JOBQ(QGPL/QBATCH)`・`INQMSGRPY(*DFT)`)で投入した `V0423E` が `ZAIKOM` の `P00006`(相対レコード番号343)をロックしている間に、`OVRDBF WAITRCD(5)` の下で `W0423A` を呼ぶと、`P00006  01218  LOCKED` が印刷されました。ロック中の `DSPRCDLCK` は `343  V0423E  <USER>  HELD  UPDATE` を示し、ジョブ・ログには `CPF5027`(`Record 343 in use by job or transaction ...V0423E.`)が出ました(各 `CPF5027` の次の行に応答 `C` が記録されています)。`V0423E` が終わる(約30秒後)と `DSPRCDLCK` は `No record locks found` になり、もう一度 `W0423A` を呼ぶと `P00006  00000  FOUND` でした。`V0423E` の印字行 `V0423E: HELD P00006` は、バッチの出力で、この検証では取っていません。

### 落とし穴 1: ライブラリー・リスト(`*LIBL`)にファイルが無いと、照会メッセージで止まる

F 仕様書にはライブラリー名を書かない(`*LIBL` で探す)ので、**プログラムを実行するジョブのライブラリー・リストに `TOKUIM` の入ったライブラリーが無いと、ファイルを開く時点で失敗します。** 04-06(RPG III 版)では、これが `CPF4101`(`File TOKUIM in library *LIBL not found`)になり、続けて RPG が照会メッセージ(応答を待つメッセージ)を出して、**応答できない非対話ジョブが無期限に止まる**ことを実機で確認しています(`RPG1216`。[probes.md](../probes.md) の「DISK ファイルへの READ が実行時にハングしていた真因」)。

- **ILE RPG(`CRTBNDRPG`)でも、同じ種類の問題が起こるはずです。** ただし、`CPF4101` の次に出る ILE の照会メッセージの具体的な ID は、まだ確認していません(**未検証(2026-10-04時点、V3)**。part04v-23run では、ファイルが `*LIBL` に無い状態を作る手順を入れていません。参考: ロック待ちの時間切れでは、`RNX1218` と照会 `RNQ1218` が実機で出ました。ファイルを開く失敗でも `RNX`・`RNQ` の組になる可能性が高いものの、ID は未確認です)。
- 5250 の対話ジョブなら画面に出るので `C`(取り消し)で応答できます。**バッチ(`SBMJOB`)や SSH 経由のジョブは応答できません。** 教材のルールどおり、`SBMJOB` には `INQMSGRPY(*DFT)` と `LOG(4 00 *SECLVL)` を付けます([付録C](../appendix/c-troubleshooting.md) の「1. 応答なしの照会メッセージ」。検証用ハーネスも、ラッパーの先頭で `CHGJOB INQMSGRPY(*DFT)` を実行しています)。ただし既定の応答は、処理を継続する側とは限りません(付録C)。
- 防ぎ方は、`CALL` の前に `ADDLIBLE <USER>1` を実行する(または `WRKLIBL` で確認する)ことです。**コンパイルするとき**にも、ファイルが `*LIBL` に無いと、コンパイルが `RNF2120`(External descriptions ... not found)で失敗します(検証用ハーネスで実際に起きたメッセージです)。

### 落とし穴 2: ファイルの形が変わると、`CPF4131`(レベル・チェック)で止まる

外部記述ファイルを使うプログラムは、コンパイルした時点のファイルの「様式レベル ID」を覚えていて、実行時にファイルを開くとき、今のファイルの様式レベル ID と比べます。**ファイルの項目を足す・変えるなどして ID がずれていると、`CPF4131`(Level check)でファイルを開けません。** このレッスンの6本は、すべて外部記述(F 仕様書22桁目が `E`)なので、この仕組みに守られています。**直す順序は「物理ファイル(PF)→ 論理ファイル(LF)→ プログラム」です(上流を直すたびに、すぐ下流の層が新しくずれるため、依存の順に作り直します)。** 詳しい説明は [05-09](../part05/05-09-add-field-level-check.md)(RPG III ルートの第5部の内容です。読んでいなくても、このレッスンの説明で足ります)にあります。 RPG III(OPM)のプログラムで `CPF4131` を実機で再現した記録は [probes.md](../probes.md) の「`part05-txmigr-to2`(接続A)」にあります。

- **`CRTBNDRPG` で作った ILE プログラムで同じ状況を作った実機記録は、このレッスンにはまだありません**(**未検証(2026-10-04時点、V3)**。part04v-23run では、ファイルの形を変える手順を入れていません)。仕組み(様式レベル ID の比較)はファイル・システム側のものなので、`CPF4131` 自体は同じはずですが、そのあとに RPG が出す照会メッセージの ID は未確認です。
- `LVLCHK(*NO)` で逃げるのは危険です。ずれたまま読んで、**エラーにならず別の位置のデータを読む**事故が起きえます(05-09)。直す順序どおりに作り直してください。

## 実演

準備: 04-21 で作った `<USER>1/QRPGLESRC`(`RCDLEN(112)`)に、メンバーを追加していきます。`TOKUIM`・`JUCHUD`・`ZAIKOM` が `*LIBL`(ライブラリー・リスト)に入っていることを、先に `WRKLIBL` で確認してください(「落とし穴 1」)。ソースの入力・コンパイルの手順(PDM または Code for i、`CRTBNDRPG`)は、04-21 のとおりです。

### V0423A: `TOKUIM` を順に読む(R0406A と同じ出力)

1. メンバー `V0423A`(ソース・タイプ `RPGLE`)を作り、次を桁位置に注意しながら入力します(`src/qrpglesrc/v0423s.rpgle` と同じ内容です)。

   ```text
   ....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
         * V0423A - read TOKUIM sequentially and print each customer.
         * Fixed-form RPG IV port of R0406A (04-06). Prints the same lines.
         * Compile: CRTBNDRPG. File TOKUIM is found through *LIBL.
        H DFTACTGRP(*YES)
        FTOKUIM    IF   E             DISK
        FQSYSPRT   O    F  132        PRINTER
        C     LOOP          TAG
        C                   READ      TOKUIM                                 99
        C   99              GOTO      ENDLP
        C                   EXCEPT
        C                   GOTO      LOOP
        C     ENDLP         TAG
        C                   SETON                                        LR
        OQSYSPRT   E
        O                       TOKCD                6
        O                                            8 '  '
        O                       TOKNM               38
   ```

2. `CRTBNDRPG PGM(<USER>1/V0423A) SRCFILE(<USER>1/QRPGLESRC) SRCMBR(V0423A)` でコンパイルし、`CALL PGM(<USER>1/V0423A)` を実行します。
3. `WRKSPLF` で、次の6件が印刷されたことを確認します(**実機で確認(part04v-23run、2026-10-04)**。コンパイルは Highest Severity 00 で、この6件がそのとおりに印刷されました。RPG III 版 `R0406A` と同じ出力です)。

   ```text
   C00001  ACME TRADING CO
   C00002  NORTH STAR LTD
   C00003  BLUE OCEAN INC
   C00004  GREEN FIELD CO
   C00005  SUNRISE MARKET
   C00006  RIVER SIDE SHOP
   ```

### V0423B: キーで1件読む(R0407A と同じ出力)

1. メンバー `V0423B` を作り、次を入力します(`src/qrpglesrc/v0423bs.rpgle`)。`V0423A` との違いは、`TOKUIM` の F 仕様書の34桁目の `K` と、`READ` ではなく `CHAIN` を使う点です。

   ```text
   ....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
         * V0423B - CHAIN: look up one customer by key (TOKCD).
         * Fixed-form RPG IV port of R0407A (04-07). Prints the same line.
        H DFTACTGRP(*YES)
        FTOKUIM    IF   E           K DISK
        FQSYSPRT   O    F  132        PRINTER
        C     'C00001'      CHAIN     TOKUIM                             99
        C   99              MOVEL     'NOTFOUND'    TOKNM
        C                   EXCEPT
        C                   SETON                                        LR
        OQSYSPRT   E
        O                       TOKCD                6
        O                                            8 '  '
        O                       TOKNM               38
   ```

2. コンパイルして `CALL` し、`C00001  ACME TRADING CO` が印刷されることを確認します(**実機で確認(part04v-23run、2026-10-04)**。コンパイルは Highest Severity 00 でした)。

### V0423C: 複合キーで `CHAIN` する

1. メンバー `V0423C` を作り、次を入力します(`src/qrpglesrc/v0423cs.rpgle`)。受注番号 `J00001` の2行目を引きます。

   ```text
   ....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
         * V0423C - CHAIN with KLIST/KFLD: composite key (JUNO + JULINE).
         * No RPG III counterpart in part 4 (it is new for this route).
         * JUCHUD key is JUNO (6A) then JULINE (3S 0), in this order.
        H DFTACTGRP(*YES)
        FJUCHUD    IF   E           K DISK
        FQSYSPRT   O    F  132        PRINTER
        DKJUNO            S              6A
        DKLINE            S              3S 0
        C     JKEY          KLIST
        C                   KFLD                    KJUNO
        C                   KFLD                    KLINE
        C                   MOVEL     'J00001'      KJUNO
        C                   Z-ADD     2             KLINE
        C     JKEY          CHAIN     JUCHUD                             99
        C   99              MOVEL     'NOTFND'      JUSHO
        C                   EXCEPT
        C                   SETON                                        LR
        OQSYSPRT   E
        O                       JUNO                 6
        O                                            8 '  '
        O                       JULINE              11
        O                                           13 '  '
        O                       JUSHO               19
        O                                           21 '  '
        O                       JUSU                26
   ```

2. コンパイルして `CALL` し、`J00001  002  P00003  00005` が印刷されることを確認します(`db/data/load_v1.sql` の `JUCHUD` に、`J00001` の2行目は商品 `P00003`・数量5と入っています。**実機で確認(part04v-23run、2026-10-04)**。コンパイルは Highest Severity 00 で、`J00001  002  P00003  00005` が印刷されました)。見つからなかったときの `NOTFND` の印刷は、この検証では実行していません(**未検証(2026-10-04時点、V2**。「見つからない」側の動きは `V0423B` の演習 1 と `V0423D` の演習 2 で確認できました)。見つからなかったときは、商品コードの欄に `NOTFND` と印刷されます(`JUSHO` が6桁なので、`'NOTFOUND'` の頭6文字が入ると、`NOTFOU` になってしまうのを避けて、6文字の `'NOTFND'` にしています)。

### V0423D: 在庫引当(R0409A と同じ出力)

**このプログラムは `ZAIKOM` を書き換えます。** 実行の前後に `<USER>1/TXRESET` を実行して、`P00001` の在庫を元の45に戻してください(04-09・06-08 と同じ約束です)。

1. メンバー `V0423D` を作り、次を入力します(`src/qrpglesrc/v0423ds.rpgle`)。

   ```text
   ....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
         * V0423D - ZAHIK3: allocate stock for one product (UPDATE + lock).
         * Fixed-form RPG IV port of R0409A (04-09): same logic, same print
         * line, NO parameters (R0409A has no *ENTRY PLIST either). The
         * single CHAIN locks the record and the lock stays until LR.
        H DFTACTGRP(*YES)
        FZAIKOM    UF   E           K DISK
        FQSYSPRT   O    F  132        PRINTER
        DPROD             S              6A
        DQTY              S              5S 0
        DMSG              S             10A
        C                   MOVEL     'P00001'      PROD
        C                   Z-ADD     2             QTY
        C     PROD          CHAIN     ZAIKOM                             99
        C   99              GOTO      NOTFND
        C     ZASU          COMP      QTY                                  98
        C   98              GOTO      SHORT
        C                   SUB       QTY           ZASU
        C                   UPDATE    ZAIKOR
        C                   MOVEL     'OK'          MSG
        C                   GOTO      ENDPGM
        C     SHORT         TAG
        C                   MOVEL     'SHORT'       MSG
        C                   GOTO      ENDPGM
        C     NOTFND        TAG
        C                   MOVEL     'NOTFOUND'    MSG
        C     ENDPGM        TAG
        C                   EXCEPT
        C                   SETON                                        LR
        OQSYSPRT   E
        O                       PROD                 6
        O                                            8 '  '
        O                       ZASU                15
        O                                           17 '  '
        O                       MSG                 27
   ```

   `D` 行は、標準のフィールドを宣言する D 仕様書です(名前が7桁目から、`S`(スタンドアロン)が24桁目、長さが39桁目に右詰め、データ型が40桁目、小数桁数が41〜42桁目)。`PROD` は6桁の文字、`QTY` は5桁のゾーン10進、`MSG` は10桁の文字です。**このプログラムは引数を1つも受け取りません**(`R0409A` も入口の宣言を持たず、`'P00001'` と数量2をプログラムの中に書いています)。

2. `TXRESET` を実行してから、コンパイルして `CALL` します。`WRKSPLF` で `P00001  0000043  OK`(45−2=43)が印刷されることを確認します(**実機で確認(part04v-23run、2026-10-04)**)。続けて `STRSQL` で `SELECT ZASU FROM ZAIKOM WHERE ZASHO='P00001'` を実行し、`43` になっていることも確認してください(**実機で確認(part04v-23run、2026-10-04)**。コンパイルは Highest Severity 00。`TXRESET` の直後は45、`CALL` の後は43、もう一度 `TXRESET` の後は45に戻りました。`P00001  0000043  OK` が印刷され、第4部の `R0409A`(04-09)と同じ印刷行・同じ在庫の変化です)。
3. 確認したら、もう一度 `<USER>1/TXRESET` を実行します。

#### `V0423D` を第6部で使うとき

06-05 の `F0605A` は、`R0409A` を `dcl-pr r0409a extpgm('R0409A') end-pr;` で呼びます。RPG III を学んでいないルートでは、この行を次のように書き換えます。引数が無いことも同じです。

```text
dcl-pr r0409a extpgm('V0423D') end-pr;
```

(プロトタイプの名前 `r0409a` は、本体の `callp r0409a();` と合わせるため、そのままにしておいても動きます。**実機で確認(part04v-27set、2026-10-04)**。`F0605A` の `extpgm` の行(`dcl-pr r0409a extpgm('V0423D') end-pr;`)だけを書き換えた `F0605R` を `CRTBNDRPG` でコンパイルすると `RNS9304`(重大度00)で、`TXRESET` のあとで `CALL` すると、ジョブ・ログに 06-05 と同じ3行(`F0605A: 1580 at default rate = 1738.00.`・`F0605A: 1580 at rate 1.08 = 1706.40.`・`F0605A: R0409A (ZAHIK3) called via CALLP..`)が出ました。3行目の文字列はソースの中にあるので、呼び先を `V0423D` に変えても `R0409A` のままです。そのほかに、`V0423D` が印刷する `P00001  0000043  OK` の1行が出て、`ZAIKOM` の `P00001` は45から43になりました。06-05 が書いている結果と食い違いはありません)。06-08・06-09 で `R0409A` を比べる箇所も、`V0423D` に読み替えます。06-09 の `STRDBG` を使う演習では、プログラムを `DBGVIEW(*SOURCE)` 付きでコンパイルし直す必要があるかもしれません(**実機で確認(part04v-23run、2026-10-04)**。`CRTBNDRPG` の既定は `Debugging views . . . : *STMT` で、ソースを表示するデバッグ(`*SOURCE`)にはなっていません。06-09 で `STRDBG` のソース表示が要るときは、`DBGVIEW(*SOURCE)` を付けてコンパイルし直します。`STRDBG` そのものは、この検証では実行していません(V3))。

### V0423E と W0423A: ロックの実験(演習 5 で使います)

`V0423E` は `ZAIKOM` の `P00006` を更新用に `CHAIN` してロックし(**`UPDATE` はしないので、データは変わりません**)、`QCMDEXC` で `DLYJOB DLY(30)` を実行して約30秒間ロックを持ち続けます。`QCMDEXC` の呼び出し(`CALL`・`PARM`)は 04-24 で扱います。ここでは、「`CMD` に入れたコマンドを、`CMDLEN` の長さだけ実行する」と読んでください(`QCMDEXC` は、コマンドの文字列とその長さを渡して CL コマンドを実行する、システム提供のプログラムです。`CMDLEN` は `QCMDEXC` が求める `15P 5`、つまり15桁・小数5桁のパック10進です)。

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
      * V0423E - lock holder: lock one ZAIKOM record for about 30 seconds.
      * Read-for-update CHAIN locks P00006. There is NO UPDATE, so the
      * data does not change. QCMDEXC runs DLYJOB to keep the lock.
      * The lock is released when this program ends (LR).
      * Pair program: W0423A tries to read the same record.
     H DFTACTGRP(*YES)
     FZAIKOM    UF   E           K DISK
     FQSYSPRT   O    F  132        PRINTER
     DCMD              S             14A   INZ('DLYJOB DLY(30)')
     DCMDLEN           S             15P 5 INZ(14)
     C     'P00006'      CHAIN     ZAIKOM                             99
     C   99              GOTO      ENDPGM
     C                   EXCEPT
     C                   CALL      'QCMDEXC'
     C                   PARM                    CMD
     C                   PARM                    CMDLEN
     C     ENDPGM        TAG
     C                   SETON                                        LR
     OQSYSPRT   E
     O                                           19 'V0423E: HELD P00006'
```

`W0423A` は同じ `P00006` を `CHAIN` し、結果を `P00006  <状況コード>  <結果>` の形で印刷します。ロックされていれば `LOCKED`(状況コードは `01218` のはず)、読めれば `FOUND`(`00000`)です。

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
      * W0423A - lock tester: try to read ZAIKOM P00006 for update.
      * The CHAIN has an error indicator (97), so a record-lock time-out
      * does not raise an inquiry message. The file status code comes
      * from the file information data structure (*STATUS subfield).
      * 1218 means "record locked by another job" (docs/probes.md).
      * Pair program: V0423E holds the lock.
     H DFTACTGRP(*YES)
     FZAIKOM    UF   E           K DISK    INFDS(ZAINFO)
     FQSYSPRT   O    F  132        PRINTER
     DZAINFO           DS
     D ZASTS             *STATUS
     DMSG              S             10A
     C     'P00006'      CHAIN     ZAIKOM                             9997
     C   97              GOTO      LOCKED
     C   99              GOTO      NOTFND
     C                   MOVEL     'FOUND'       MSG
     C                   GOTO      ENDPGM
     C     LOCKED        TAG
     C                   MOVEL     'LOCKED'      MSG
     C                   GOTO      ENDPGM
     C     NOTFND        TAG
     C                   MOVEL     'NOTFOUND'    MSG
     C     ENDPGM        TAG
     C                   EXCEPT
     C                   SETON                                        LR
     OQSYSPRT   E
     O                                            6 'P00006'
     O                                            8 '  '
     O                       ZASTS               13
     O                                           15 '  '
     O                       MSG                 25
```

実験の手順は、演習 5 にあります。**バッチ・ジョブ(`V0423E`)と、別のジョブ(`W0423A`)の組み合わせは、検証用ハーネスで実機確認しました(上の「ロックを待たされたとき」)。5250 から実際に試して画面で見る部分は、この教材では確認できない対話操作(V3)です。**

## 出力が違うとき

次の5つは、わざと間違えた例です。`V0423A`・`V0423B`・`V0423D` の1か所だけを変えて `CRTBNDRPG` を実行し、コンパイル・リストの Message Summary で、どの行にどのメッセージが付くかを確かめます。**メッセージ ID と重大度は、実機で確認しました(part04v-23run、2026-10-04)。** どの例も `CRTBNDRPG` が `RNS9308`(`Compilation stopped. Severity 30 errors found in program.`)と `RNS9310`(`Compilation failed. Program ... not created`)で止まり、プログラムは作られません。メッセージ ID は、コンパイル・リストの Message Summary(Additional Diagnostic Messages)に付きます。ソースは、この教材の検証用ディレクトリー(`verify/part04v-23run/src/t423n1.rpgle` 〜 `t423n5.rpgle`)にあります。

| 例 | 間違い | 期待する状況 | メッセージ ID・重大度 |
|---|---|---|---|
| `T423N1` | `UPDATE` を、`UPDAT`(5文字の旧い綴り)と書いた | 命令コードとして認識されず、エラーになる | `RNF5014`(重大度30)`Operation code is not valid; specification is ignored.` |
| `T423N2` | `READ` の EOF 標識を、58〜59桁目(古い桁位置)に書いた | 結果フィールド欄に標識の数字が入った形になり、エラーになる | `RNF0262`(重大度20)`Entry not left-adjusted; defaults to left-adjusted.`、`RNF7261`(重大度30)`The Result-Field operand 99 is not valid for the specified operation.`、`RNF7030`(重大度30)`The name or indicator *IN99 is not defined.`(`GOTO` の条件標識 `99` が定義されていない) |
| `T423N3` | `K` を34桁目ではなく31桁目に書いた | 31桁目はキー長の欄の中なので、F 仕様書に注意が付き、さらに `CHAIN` の Factor 1 のキーが相対レコード番号として扱われてエラーになる | F 仕様書の行に `RNF2289`(重大度20)`Key Length specified for external file; defaults to blank.`(F 仕様書そのものは重大度20の注意止まりで、止まりません)。`CHAIN` の行に `RNF7055`(重大度30)`Factor 1 'C00001' is not valid for the specified operation.` |
| `T423N4` | `EXCEPT` を `EXCPT`(5文字の旧い綴り)と書いた | 命令コードとして認識されず、エラーになる | `RNF5014`(重大度30)`Operation code is not valid; specification is ignored.`(`EXCEPT` の出力に対応する計算がない、という `RNF6062`(重大度00)も付く) |
| `T423N5` | `ZAIKOM` の17桁目を `U` ではなく `I`(入力専用)にして、`UPDATE` した | 入力専用のファイルに `UPDATE` はできず、エラーになる | `RNF5198`(重大度30)`File in Factor 2 is not allowed for UPDATE or DELETE operation.` |

実行時の症状は次のとおりです。

| 症状 | 原因の見当 | 対処 |
|---|---|---|
| コンパイルが `RNF2120`(External descriptions ... not found)で失敗する | 使っている外部記述ファイル(`TOKUIM` など)が、コンパイルするジョブのライブラリー・リストに無い | `ADDLIBLE <USER>1` をしてから、もう一度コンパイルする |
| 実行が止まったまま応答がない | ファイルを開く時点の失敗(`CPF4101`・`CPF4131`)の照会メッセージ、またはレコード・ロック待ち | `WRKLIBL` で `*LIBL` を確認する。ロック待ちなら `WRKOBJLCK`・`DSPRCDLCK` で原因のジョブを探す(自分のジョブだけを見ます)。応答できる環境なら `C` で取り消す |
| `CPF4131`(Level check) | ファイルの形が変わったのに、プログラムを作り直していない | 上の「落とし穴 2」の順序(PF → LF → プログラム)で作り直す |
| `V0423D` が `P00001  0000043  OK` ではなく、数値が違う | 在庫が45でない状態から始めた(`TXRESET` を忘れた) | `<USER>1/TXRESET` を実行して、もう一度 `CALL` する |
| `W0423A` が `FOUND` になる | `V0423E` がもう終わっている(約30秒で終わります)、または、まだ始まっていない | `V0423E` を投入した直後に実行する |

## 演習

答えは [`solutions/04-23/`](../../solutions/04-23/) にあります(ソースは見る前に自分で書いてみてください)。

1. (例題を変える)`V0423B` の `'C00001'` を、存在しない `'C99999'` に変えて、再コンパイル・実行してください。**`TOKCD` が空白のまま、`TOKNM` に `NOTFOUND` とだけ印刷される**はずです(`CHAIN` が失敗すると、項目は書き換わらないためです)。ヒント: 変える行は `CHAIN` の1行だけです。答え: [`v0423b-c99999.rpgle`](../../solutions/04-23/v0423b-c99999.rpgle)(**実機で確認(part04v-23run、2026-10-04)**。コンパイルは Highest Severity 00 で、`TOKCD` の位置が空白のまま `NOTFOUND` とだけ印刷されました)。
2. (予想してから試す)`V0423D` の `Z-ADD` の `2` を `999` に変えて、再コンパイル・実行してください。**在庫は書き換わらず**、`P00001  0000045  SHORT`(`TXRESET` 済みなら45のまま)と印刷されるはずです。次に、商品コードを `'P99999'` に変えると、`NOTFOUND` になります。ヒント: `COMP` の LO 標識(73〜74桁目)が `SHORT` への分岐を決めています。答え: [`v0423d-short.rpgle`](../../solutions/04-23/v0423d-short.rpgle)・[`v0423d-notfound.rpgle`](../../solutions/04-23/v0423d-notfound.rpgle)(`P99999` のとき、`ZASU` は書き換わらないので `P99999  0000000  NOTFOUND` になると考えられます。いずれも**実機で確認(part04v-23run、2026-10-04)**。どちらもコンパイルは Highest Severity 00 です。`'999'` では `P00001  0000045  SHORT`(`TXRESET` 済みで45のまま、`ZAIKOM` は変わりません)、`'P99999'` では `P99999  0000000  NOTFOUND` が印刷されました)。実行のたびに `TXRESET` を忘れないでください。
3. (独力で)`JUCHUD` を最初から最後まで読んで、全12行を `V0423C` と同じ形式で印刷する `V0423F` を書いてください。ヒント: `V0423A` の `TOKUIM` を `JUCHUD` に変え、O 仕様書を `V0423C` のものにします。1行目は `J00001  001  P00001  00002` になるはずです。答え: [`v0423f.rpgle`](../../solutions/04-23/v0423f.rpgle)(**実機で確認(part04v-23run、2026-10-04)**。コンパイルは Highest Severity 00 で、全12行が印刷されました。1行目は `J00001  001  P00001  00002`、最後の行は `J00008  002  P00004  00002` です)。
4. (予想してから試す)`V0423C` の `KFLD` の順序を入れ替える(`KLINE` を先に書く)と、どうなりますか。コンパイルするとエラーになるでしょうか。それとも、実行すると何も見つからないでしょうか。ヒント: `KFLD` の項目は、キーの項目と長さ・データ型・小数桁数が一致していなければなりません。答え: [`v0423c-swapped.rpgle`](../../solutions/04-23/v0423c-swapped.rpgle)(**実機で確認(part04v-23run、2026-10-04)**。コンパイル時にエラーになります。`RNF7072`(重大度30)`KFLD at sequence number 16 is NUMERIC but key field is CHAR.`(`KLINE`(数値)が、先頭のキー `JUNO`(文字)に対応してしまうため)。続けて `RNS9308`・`RNS9310` でプログラムは作られません。実行すると `CPD0170`(`Program X423C1 in library ... not found`)になります)。
5. (発展・5250の対話操作。V3)ロックを待たされる様子を観察します。`ZAIKOM` は書き換えません。
   1. `SBMJOB CMD(CALL PGM(<USER>1/V0423E)) JOB(V0423E) JOBQ(QGPL/QBATCH) INQMSGRPY(*DFT) LOG(4 00 *SECLVL)` で、ロックを持つジョブを投入します。`JOBQ(QGPL/QBATCH)` を付けるのは、既定のジョブ待ち行列では、投入したジョブがロックを取る前に終わった(または動き出さなかった)ように見えた実機の記録があるためです([probes.md](../probes.md) の `part06-p43-lockdiag`。真因は未解明)。
   2. すぐに `OVRDBF FILE(ZAIKOM) WAITRCD(5)`(待ち時間を5秒に短縮)を実行します。
   3. `DSPRCDLCK FILE(ZAIKOM) MBR(*FIRST) RCDNBR(*ALL) OUTPUT(*PRINT)` で、`P00006` がロックされていることを確認します。
   4. `CALL PGM(<USER>1/W0423A)` を実行します。約5秒後に `P00006  01218  LOCKED` が印刷されるはずです。
   5. `V0423E` が終わる(約30秒)のを待ってから、もう一度 `W0423A` を実行します。今度は `P00006  00000  FOUND` になるはずです。
   6. `DLTOVR FILE(ZAIKOM)` で待ち時間の上書きを解除します。

   ヒント: 2回目の `W0423A` が `LOCKED` のままなら、`V0423E` がまだ終わっていません。**この手順は、投入したバッチ・ジョブと対話ジョブの競合を想定したものです。5250を2つ開く必要はありません。** 固定形式の `V0423E`・`W0423A` の組は、バッチ同士の形で実機確認しました(**実機で確認(part04v-23run、2026-10-04)**。1回目は `P00006  01218  LOCKED`、`V0423E` の終了後は `P00006  00000  FOUND`。詳しくは「ロックを待たされたとき」)。5250 を使った対話操作の確認は、未検証(2026-10-04時点、V3)です。

## セルフチェック

- [ ] 外部記述ファイルの F 仕様書の桁(17・18・22・34・36〜42)を言える。
- [ ] `READ` の EOF 標識は75〜76桁目、`CHAIN` の「見つからない」標識は71〜72桁目と言える。
- [ ] `V0423A`・`V0423B` を入力・コンパイル・実行し、`R0406A`・`R0407A` と同じ出力になることを確認できた。
- [ ] `KLIST`・`KFLD` で複合キーを作り、`V0423C` が `J00001  002  P00003  00005` を印刷することを確認できた。
- [ ] 更新用ファイルの `CHAIN` がレコードをロックすること、`UPDATE` の前にロック付きの読み取りが要ることを説明できた。
- [ ] `V0423D` が `P00001  0000043  OK` を印刷することを確認し、`TXRESET` で在庫を45に戻せた。
- [ ] `*LIBL` にファイルが無いとき、バッチ・ジョブが止まる理由と、`INQMSGRPY(*DFT)` の役割を説明できた。
- [ ] `CPF4131` が、ファイルの形が変わったときに出る理由を説明できた。

## 片付け

`V0423D` は、第6部(06-05・06-08・06-09)で使うので、そのまま残してください。ほかのプログラムも、演習で作った試験用のものを除いて残してかまいません(`DLTPGM PGM(<USER>1/V0423*)` で総称名で消せますが、`V0423D` も消えるので注意してください)。**データを変えたレッスンの最後には、必ず `<USER>1/TXRESET` を実行して、`ZAIKOM` を元に戻してください。** 演習 5 で `OVRDBF` を実行した場合は、`DLTOVR FILE(ZAIKOM)` も忘れずに。

## まとめ

| 英語 | 日本語 |
|---|---|
| Externally described file | 外部記述ファイル |
| Full procedural file | 全手続き方式のファイル |
| Record address type | レコード・アドレス型 |
| End of file (EOF) | ファイルの終わり |
| Search argument | 検索引数(`CHAIN` のキー) |
| Composite key | 複合キー |
| Key list (`KLIST`) | キー・リスト |
| Update file | 更新用ファイル |
| Record lock | レコード・ロック |
| File information data structure (`INFDS`) | ファイル情報データ構造 |
| Level check | レベル・チェック(様式レベル ID の照合) |
| Record format level identifier | 様式レベル ID |

次のレッスン([04-24](04-24-call-parm-debugging.md))では、`CALL`・`PARM`(プログラムの呼び出しと引数)と、デバッグ・実行時エラーを扱います。第4部Vの全体は[第4部V の索引](index.md)を参照してください。

## 実機メモ

- **実機で確認(part04v-23run、確認日 2026-10-04、PUB400、V7R5M0)。** `V0423A`〜`V0423E`・`W0423A`・演習の答え `X423B1`・`X423D1`・`X423D2`・`X423F`・エラー標識なしの試験用 `T423NE` は、`CRTBNDRPG`(`OPTION(*EVENTF)`)で Highest Severity 00 でコンパイルできました(コンパイル・リストのメッセージはすべて情報レベル 00 の `RNF2318`・`RNF6011`・`RNF7031`・`RNF7066`・`RNF7086` だけです)。`X423C1`(演習 4)と、「出力が違うとき」の `T423N1`〜`T423N5` は、意図どおり重大度30でコンパイルに失敗しました(意図しない失敗はありません)。印刷された行は、`V0423A` の6件、`V0423B` の `C00001  ACME TRADING CO`、`V0423C` の `J00001  002  P00003  00005`、`V0423D` の `P00001  0000043  OK` で、いずれも本文の記述と同じでした。
- **すでに実機確認済みの根拠(V2)**: `V0423A`・`V0423B` の F 仕様書(`TOKUIM`・`QSYSPRT`)・`READ`・`CHAIN`・`GOTO`・`TAG`・`MOVEL`・`SETON`・O 仕様書の行は、`part06-01-cvtrpgsrc`(確認日 2026-09-26)で `CRTBNDRPG`(Highest Severity 00)・`CALL` を実行した `V0601A`(`src/qrpglesrc/v0601s.rpgle`)と、桁位置まで同じ文字列です。**確認済みなのは、これらの行の形までです。** 次の項目は、part04v-23run(2026-10-04)で、実機でコンパイルして動くことを確認しました: `H DFTACTGRP(*YES)`、`KLIST`・`KFLD`・`Z-ADD`・`COMP`(LO 標識)・`SUB`、`UPDATE`、D 仕様書(`S`・`DS`・`INZ`)、`INFDS` と `*STATUS`、`CALL`・`PARM` による `QCMDEXC` の呼び出し(`V0423E` が約30秒ロックを保持)、`CHAIN` の ER 標識(73〜74桁目)。
- **期待する出力の根拠**: RPG III 版(OPM)の `R0406A`・`R0407A`・`R0409A` は、`CRTRPGPGM` で実機コンパイルし、`TOKUIM` の6件、`C00001  ACME TRADING CO`、`P00001  0000043  OK`・`SHORT` を印刷することを確認済みです(確認日 2026-09-25。04-06・04-07・04-09 の実機メモ、[probes.md](../probes.md))。ILE 版(`V0423?`)の同じ出力は、part04v-23run(2026-10-04)で確認しました。`V0423D` は、`TXRESET` の後に `P00001  0000043  OK` を印刷し、在庫が45から43になりました(`R0409A` と同じです)。`QTY=999` の `SHORT` では在庫は45のまま、`P99999` では `P99999  0000000  NOTFOUND` でした。
- **ロックの実機記録(ILE)**: `part06-p43-lockdiag`(確認日 2026-09-28)で、`SBMJOB` で投入した別ジョブが `SHOHIM` のレコードをロックしている間、`CRTBNDRPG` で作った自由形式のプログラム(`chain(e)`)が、`OVRDBF WAITRCD(5)` の下で `%status(shohim)` = 1218 を得て、ジョブ・ログに `CPF5027` が出たことを確認しています。このレッスンのロック実験(`V0423E`・`W0423A`)は、その型を固定形式で作り直したもので、part04v-23run(2026-10-04)で `ZAIKOM` の `P00006` に対して確認しました: ロック中は `WAITRCD(5)` の下で `P00006  01218  LOCKED`、ロック解放後は `P00006  00000  FOUND` でした。`DSPRCDLCK` は、ロック中だけ `343  V0423E  HELD  UPDATE` を示しました。
- **未確認**: (1) ILE で、ファイルを開けないとき(`CPF4101`・`CPF4131`)に、RPG が続けて出す照会メッセージの ID(part04v-23run には、`*LIBL` にファイルが無い状態と様式レベル・チェックの手順を入れていません。V3)。(2) 5250 から実際にロックを待たされる様子と、`STRDBG`(V3)。
- **ER 標識なしのロック時間切れ(確認済み、part04v-23run、2026-10-04)**: `verify/part04v-23run/src/t423ne.rpgle`(`CHAIN` に ER 標識なし)は、別ジョブが `P00006` をロック中に呼ぶと、`RNX1218`(`Unable to allocate a record in file ZAIKOM.`)、`RNQ1218`(`Unable to allocate a record in file ZAIKOM (R C G D F).`)に続けて、照会メッセージへの自動応答 `C`(ジョブ・ログに記録。`INQMSGRPY` の値は未確認)のあと `CEE9901`(`Application error.  RNX1218 unmonitored by T423NE at statement 0000000012`)となり、呼び出しは異常終了しました(ハングはしませんでした)。
- **取得できなかったもの**: 検証用ハーネスの `EVFEVENT` の取り込みは、`CPF2973`(300桁に切り詰め)が出る形でしか動いていません。メッセージ ID は、コンパイル・リストから読みました。
- **一次資料の参照元**: `work/design/refs/ilerpgref75.txt`(ILE RPG言語リファレンス)の `CHAIN`・`READ`・`UPDATE`・`KLIST`・`KFLD` の各項と、F・D・C・O 仕様書の桁見出し。コンパイルのイベント・ファイル(`OPTION(*EVENTF)`)の説明は `cl_commands_75.txt`(`CRTBNDRPG` の「Event File Support」)。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
