# 05-09 改修 (2): フィールドの追加とレベル・チェック

> 所要時間: 90分(長め)/ 前提レッスン: 05-08 / 目標番号: 4 / 観測方法: コンパイル・リストとメッセージ ID(`CPF4131`)/ 道具: 5250(PDM/SEU)/ 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1/JUCHUM`(PF)・`<USER>1/JUCHUL1`(LF)・`<USER>1/ZA0500`・`<USER>1/JU0300`(RPG)・`<USER>1/JU0900C`(CL)/ DBVER: 1 → 2 / 依存するプローブ: P19(未実施)/ PTF 依存: なし / 容量の目安: わずか

## ゴール

- `CHGPF SRCFILE(...)` で、既存データを残したまま物理ファイルに項目を追加できる。
- `CPF4131`(様式レベル ID 不一致)が起きる理由と、PF → LF → RPG → CL という正しい再作成・再コンパイルの順序を説明できる。
- `LVLCHK(*NO)` が「解決策ではなく回避」である理由を説明できる。

## ウォームアップ

<details><summary>05-08 の復習</summary>

1. `CMPPFM` は何と何を比較する道具か?
2. ゴールデン・マスターと比較する前に、なぜジョブ日付を固定する必要があるのか?

答え: 1. 2つのソース物理ファイル・メンバー(例: 改修前後の同じプログラムのコンパイル・リストや印刷結果を保存したメンバー)を行単位で比較する。 2. 出力に日付が印字されるプログラムだと、実行日が違うだけで「差分あり」と誤判定されてしまうため。

</details>

## なぜ学ぶか

**保守の9割は「項目を1個足す」ような小さな変更です。** ところが IBM i では、物理ファイルの形が変わると、それを外部記述で使っているすべてのプログラムに影響が及びます。この影響は放置されず、**様式レベル ID という仕組みが実行時に `CPF4131` というエラーで教えてくれます。** これは IBM i の親切な安全装置ですが、「消し方」を知らないと `LVLCHK(*NO)` のような危険な近道に逃げてしまいがちです。このレッスンでは、`JUCHUM`(受注ヘッダー)に `JUDLV`(納期)を1項目足す、という実際の改修を通じて、正しい消し方と、この安全装置が **どこまでしか守ってくれないか** を学びます。

## 新出

- **様式レベル ID(record format level ID)**: コンパイル済みプログラムが、外部記述ファイルの「形」を覚えておくための隠れた識別子。
- **`CHGPF SRCFILE(...)`**: 物理ファイルの形を、DDS ソースから変更する。`CRTPF` と違い、既存データを残す。
- **再コンパイルの正しい順序(PF → LF → DSPF → RPG → CL)**: なぜこの順でないと直らないか。
- (読めればよい) `REFFLD`、`LVLCHK(*NO)`、`DBVER` という本カリキュラム独自の約束事。

## 説明

### 様式レベル ID とは

外部記述ファイル(DDS で定義された物理・論理・表示装置ファイル)には、**レコード様式(record format)ごとに、その「形」(項目の並び・型・長さ)から計算される隠れた識別子**が付いています。これが様式レベル ID です。プログラムを `CRTRPGPGM`・`CRTCLPGM` などでコンパイルするとき、そのプログラムが参照する外部記述ファイルの様式レベル ID が、コンパイル済みプログラムの中に一緒に焼き込まれます。

実行時、プログラムがファイルを `OPEN` すると、**「自分が焼き込んでいる様式レベル ID」と「今実際にそのファイルが持っている様式レベル ID」を比較**します。ファイルの形が変わって様式レベル ID がずれていれば、`CPF4131`(様式レベル ID が一致しない)で実行時エラーになります。これは「たまたま列がずれて変な値を読む」という一番怖い事故を、**実行前に確実に、分かりやすく止めてくれる**仕組みです。

### `CHGPF SRCFILE(...)` — なぜ `CRTPF` ではないのか

`tools/qclsrc/txmigr.clp` の冒頭コメントに、この選択の理由がそのまま書かれています。

> `CHGPF`, not `CRTPF`: `CRTPF` would create a brand new (empty) object. `CHGPF` changes the format in place and keeps the existing data member/rows - this is what actually causes the level-ID mismatch (`CPF4131`) in every program that has not been recompiled yet, which is the whole point of this exercise.

`CRTPF` は「同名の新しいオブジェクトを作り直す」ため、既存の8件の受注データが消えてしまいます。**`CHGPF FILE(lib/JUCHUM) SRCFILE(lib/QDDSSRC) SRCMBR(JUCHUM)` は、データ・メンバーはそのままに、レコード様式だけを新しい DDS ソースの形に変えます。** これは現場の保守で必ず使う技法です。そして「データを残したまま形だけ変える」からこそ、**様式レベル ID がずれた古いプログラムが取り残される**という、この先の展開が起きます。

### `db/v1/juchum.pf` と `db/v2/juchum.pf` の違い

```text
db/v1/juchum.pf                          db/v2/juchum.pf(今回の変更)
     A          R JUCHUR                      A          R JUCHUR
     A            JUNO           6A            A            JUNO           6A
     A            JUTOK          6A            A            JUTOK          6A
     A            JUDATE         8S 0          A            JUDATE         8S 0
     A            JUTAN          6A            A            JUTAN          6A
     A          K JUNO                         A            JUDLV           L
                                                A                                DATFMT(*ISO)
                                                A          K JUNO
```

差分は `JUDLV`(納期、`L` = DATE 型)を末尾に1項目追加しただけです。`DATFMT(*ISO)` は日付の外部表現形式を指定する DDS のフィールド・レベル・キーワードです(省略時の既定値も `*ISO` なので、実は無くても同じ意味になります)。**紛らわしい点として**、`CVTOPT` という名前自体は実在します——ただし DDS のフィールド・キーワードとしてではなく、05-04 で読んだとおり `CRTRPGPGM`/`CRTBNDRPG` の**コンパイル・オプション**(`*NONE`/`*DATETIME`/`*VARCHAR`/`*GRAPHIC`)としてです。「DDS 用の別の `CVTOPT`」があるわけではなく、05-04 のものと**まったく同じ**唯一の `CVTOPT` が、たまたまこの DDS の図には出てくるべきでない場所に書かれていた、というだけです(なお、この `CVTOPT` の既定値 `*NONE` は「外部記述ファイルの DATE/TIME/TIMESTAMP 型フィールドを無視し、そのプログラムからは一切アクセスできない」という意味でした——`JUCHUM` を外部記述で読む `JU0300` を将来 `CVTOPT` を指定せずに再コンパイルすると、`JUDLV` がまるごと見えなくなる、という05-04 と05-09 をつなぐ実例です)。同様に `ALWNULL` は DDS のフィールド・キーワードとして存在しますが**値を取らず**、裸の `ALWNULL` だけで「NULL を許す」の意味になります(何も書かなければ既定で「NULL を許さない」になり、`JUDLV` はまさにこの既定のままにしています)。

**`db/v2/juchum.pf` を実際に確認すると、`JUDLV` は `REFFLD` を使わず、この場でそのまま(インライン)定義されています。** `REFFLD` は「別のファイルの項目定義を、名前を指定して再利用する」DDS キーワードで、`REFFLD(項目名 参照先ファイル名)` のように書きますが、**今回のソースには実例が無い**ので、構文を暗記するより「そういうキーワードがある」と知っておく程度で十分です。

### 正しい再コンパイルの順序: PF → LF → (DSPF) → RPG → CL

一般原則はこうです。**あるファイルの様式レベル ID が変わったら、それを直接・間接に参照しているすべての層を、依存の下流に向かって順に作り直す。** 上流を作り直すと、そのすぐ下流の層から見て様式レベル ID がまた変わるので、**1つ上の層を直すたびに、次の層が新しく「ずれる」**という連鎖が起きます。だから物理ファイル(PF)→論理ファイル(LF)→表示装置ファイル(DSPF、あれば)→ RPG → CL、という**依存の順番どおりに**進める必要があります。順序を飛ばすと、直したつもりの層のすぐ下流で新しい `CPF4131` が発生するだけです。

`JUCHUM` を使う実際の依存関係を、`05-07` の `DSPDBR` の手法で辿ると、次のようになります(このレッスンで実際に確認する対象)。

```text
JUCHUM (PF)
  └─ JUCHUL1 (LF, PFILE(JUCHUM))        … db/v1/juchul1.lf
       └─ JU0300 (RPG)                  … FJUCHUL1 IP E K DISK (外部記述)
JUCHUM (PF) を直接 DCLF/CHAIN するもの
  ├─ JU0900C (CL)                        … DCLF FILE(JUCHUM)
  └─ ZA0500 (RPG)                        … ただしプログラム記述(下記コラム参照)
```

**今回の `JUCHUM` の依存関係には、表示装置ファイル(DSPF)は登場しません。** `TK0100D` は `TOKUIM`/`TANTOM` は使いますが `JUCHUM` の項目は一切含んでいないためです(表示装置ファイルが絡む具体例は 05-10 で `TK0100D`/`TK0100` を使って学びます)。一般原則としての「PF → LF → DSPF → RPG → CL」は覚えておいてください。今回はその中の DSPF の層が単に存在しない、というだけです。

> **コラム: 様式レベル・チェックが効かないプログラムもある**
>
> `ZA0500` の F 仕様書をよく見ると `FJUCHUM IS F      26            DISK` となっており、`TOKUIM`/`JUCHUL1` のような外部記述(19桁目に `E`)ではありません。**`ZA0500` は `JUCHUM` を「プログラム記述」(I 仕様書で桁位置を自分で指定する古い書き方)で読んでいます。** `JUCHUM` をプログラム記述で読むため、DBVER=2移行時に `CPF4131` による自動検知が効かない点が、05-09/05-07を通じての重要な論点になります。
>
> **プログラム記述のファイルには、そもそも様式レベル ID という仕組みがありません。** `JUDLV` は末尾に追加されただけなので、`ZA0500` が読んでいる先頭26バイト(`JUNO`・`JUTOK` など)はズレず、今回はたまたま実害がありません。しかし、もし将来 *既存項目を途中に挿入する・型を変える・削除する* ような変更だったら、`ZA0500` は **`CPF4131` どころか何のエラーも出さないまま**、ズレた位置のバイトを読んでしまいます。**これが、`TXMIGR` が「影響を証明できるプログラムだけ選ぶ」のではなく、あえて「ライブラリー内の `*PGM` を全部再コンパイルする」という乱暴なくらい単純な戦略を採っている理由です**(`txmigr.clp` 冒頭コメントより)。様式レベル・チェックは強力な安全装置ですが、**プログラム記述で読んでいる箇所までは守ってくれません**。だからこそ 05-07 の影響調査(`DSPPGMREF`・`DSPDBR`・`FNDSTRPDM`)が欠かせません。

### `LVLCHK(*NO)` は答えではない

ファイル・オーバーライド(`OVRDBF ... LVLCHK(*NO)`)を使えば、様式レベル・チェックそのものを止めることは**技術的には**できます。しかしこれは「食い違ったままのファイルを、チェックなしで無理やり開かせる」ということです。運が良ければ何も起きませんが、運が悪ければ **`CPF4131` という分かりやすいエラーの代わりに、ズレた位置のデータを静かに誤読する**という、上のコラムの `ZA0500` と同じ事故が起きます。`CPF4131` は「うるさいだけの邪魔者」ではなく、**「壊れたデータを扱う前に必ず止めてくれる命綱」**です。正しい対処は、消し方(このレッスンの内容)を覚えて、面倒でも正しい順序で再作成・再コンパイルすることです。

### `DBVER=2` という約束事

このカリキュラムでは、`db/v1/`・`db/v2/` のようにサンプル DB のバージョンをディレクトリー名で管理し、各ライブラリーに `TXSTATE` という `*DEC(3 0)` のデータ域を持たせて「今そのライブラリーが DBVER いくつの状態か」を記録しています(`tools/qclsrc/txsetup.clp` が `DBVER=1` で作成)。`05-09` はこのカリキュラム全体で最初に `DBVER` が `1` から `2` に上がるレッスンです。`TXSTATUS`(`tools/qclsrc/txstatus.clp`)は、この `TXSTATE` を `RTVDTAARA` で読み、`TXSTATUS: DBVER=nnnnnnnnnn in library <lib>` という形式でメッセージを送ります。

## 実演

**ここから先は未検証です。手順は `tools/qclsrc/txmigr.clp`・`db/v1/juchum.pf`・`db/v2/juchum.pf` の実際のソースに基づいて書いていますが、実機での通し確認はまだ行っていません(実機メモ参照)。**

1. 現在の状態を確認する。

   ```text
   TXSTATUS LIB(<USER>1)
   ```

   `TXSTATUS: DBVER=0000000001 in library <USER>1` と出るはずです(05-08 までは `DBVER=1` のまま)。

2. `db/v1/juchum.pf` と `db/v2/juchum.pf` を見比べる(上の説明のとおり)。差分は `JUDLV` の追加だけであることを確認してください。

3. **`CHGPF` を手作業で行い、`CPF4131` をわざと発生させる。** `TXMIGR` は最後まで一気にやってしまう道具なので、ここでは学習のためにあえて1段目だけを手で行います(`txmigr.clp` の「Step 1」と同じ内容)。

   ```text
   ADDPFM FILE(<USER>1/QDDSSRC) MBR(JUCHUM) SRCTYPE(PF) TEXT('Order master (DBVER=2)')
   ```

   (既に `JUCHUM` メンバーがある場合はこのコマンドは `CPF7306` で失敗しますが問題ありません。`db/v2/juchum.pf` の内容を `<USER>1/QDDSSRC/JUCHUM` メンバーに上書きしてから、次に進んでください。)

   ```text
   CHGPF FILE(<USER>1/JUCHUM) SRCFILE(<USER>1/QDDSSRC) SRCMBR(JUCHUM)
   ```

   これで `<USER>1/JUCHUM` は新しい様式(`JUDLV` あり)になりましたが、既存の8件のデータはそのまま残っています。**この時点では、まだ `JUCHUL1` も、どのプログラムも再作成・再コンパイルしていません。**

4. **`CPF4131` を実際に見る。** `JUCHUM` を外部記述で参照しているプログラム(例: `JU0900C`)を、**同じジョブの中で** `ADDLIBLE` してから呼び出します(無修飾参照を別セッションで呼ぶと `RPG1216` の無期限ハングになるおそれがあることは 04-06 の実機メモで確認済みです。必ず同一ジョブ・ライブラリー修飾を守ってください)。

   ```text
   ADDLIBLE LIB(<USER>1) POSITION(*FIRST)
   CALL PGM(<USER>1/JU0900C) PARM('*TEST' '<USER>1')
   ```

   `JU0900C` は `DCLF FILE(JUCHUM)` しているので、`JUCHUM` を古い様式レベル ID のまま覚えています。ジョブ・ログに `CPF4131`(様式レベル ID が一致しない)が現れるはずです。これが「様式が変わったのに、プログラムが古いままだと実行時に止まる」という、このレッスンの核心です。

5. **正しい順序で直す。** まず論理ファイルを再作成します。`JUCHUL1` は `JUCHUM` の上に作られた論理ファイル(データは持たず、`JUCHUM` へのアクセス経路だけの存在)なので、**削除しても実データは失われません**。

   ```text
   DLTF FILE(<USER>1/JUCHUL1)
   CRTLF FILE(<USER>1/JUCHUL1) SRCFILE(<USER>1/QDDSSRC) SRCMBR(JUCHUL1)
   ```

   `JUCHUL1` 自身の DDS ソース(`PFILE(JUCHUM)` のみ)は一文字も変わっていないのに、**再作成が必要な理由は「元になっている `JUCHUM` の様式レベル ID が変わったから」**です。これが「PF を直したら、その1つ下流の LF も必ず作り直す」の具体例です。

   > **`TXMIGR` 自身の制約(正直な注記)**: `tools/qclsrc/txmigr.clp` もこの手順(論理ファイルの再作成)を自動化しようとしています。以前はヘッダー・コメントに「`DSPDBR` の `*OUTFILE` が返す `WHFILE`/`WHLIB` が、本当に依存論理ファイルの名前を指すのか、`JUCHUM` 自身を指すのか未確認」と書かれていましたが、`part05-legacy-probe`(確認日2026-09-26)で実際に `DSPDBR` の `*OUTFILE` を確認したところ、**そもそも `WHFILE`/`WHLIB` という列は存在せず**、正しい列名は `WHRFI`/`WHRLI`(`DSPDBR` の対象そのもの)と `WHREFI`/`WHRELI`(実際に従属する論理ファイル、常にこちらが `JUCHUL1` のような依存 LF を指す)であることが判明し、`txmigr.clp` も修正済みです。現在の `txmigr.clp` は、**`CRTPF`/`CRTLF` に `REPLACE` パラメーターが無いことを理由に、安全のため `DLTF` をせず `CRTLF` だけを実行する**設計になっています。`CRTLF` に `REPLACE` パラメーターは無いため、`JUCHUL1` が既に存在する今回のような状況では、`TXMIGR` の `CRTLF` はほぼ確実に「オブジェクトが既に存在する」で失敗し、`TXMIGR: could not recreate JUCHUL1.` とだけ表示して次に進むと考えられます(**この失敗自体はまだ実機で確認していません。実機メモ参照**)。**つまり現状の `TXMIGR` は、論理ファイルの再作成を実際には完了できないと考えられます。** 今回はこのレッスンのとおり、`DLTF` → `CRTLF` を手作業で行うのが確実です。

6. RPG を再コンパイルします(`JUCHUL1` を使う `JU0300`、`JUCHUM` を直接使う `ZA0500` の両方)。

   ```text
   CRTRPGPGM PGM(<USER>1/JU0300) SRCFILE(<USER>1/QRPGSRC) SRCMBR(JU0300)
   CRTRPGPGM PGM(<USER>1/ZA0500) SRCFILE(<USER>1/QRPGSRC) SRCMBR(ZA0500)
   ```

7. CL を再コンパイルします(`JUCHUM` を `DCLF` している `JU0900C`)。

   ```text
   CRTCLPGM PGM(<USER>1/JU0900C) SRCFILE(<USER>1/QCLSRC) SRCMBR(JU0900C)
   ```

8. 手順4と同じ呼び出しを、**同一ジョブ**でもう一度行い、今度は `CPF4131` が出ないことを確認します。**ただし、これで `JU0900C`→`ZA0500` の呼び出し全体が「何の問題もなく完全に正常終了する」とは限らない点に注意してください。** `ZA0500` には(`JUCHUM` の様式レベル ID とは無関係の、05-13 チケット1で修正する)別の実バグが残っています。`part05-ju0900c-baseline`(確認日2026-09-27)では、`DBVER=1`(`JUDLV` 追加前)の `JUCHUM` に対して as-shipped の `ZA0500` をこれと同じ呼び出し(`RUNMODE='*TEST'`)で実行したところ、1行目から確実に `RPG0907`(10進データ・エラー)を起こし、`JU0900C: ZA0500 ended abnormally.` というメッセージ付きで(ハングせず)終わりました。この手順は `DBVER=2` に上げた後の呼び出しなので、**この `RPG0907` が `DBVER=2` でも同様に起きるかどうかは、実機ではまだ確認していません**(`JUCHUM` の様式レベル ID とは無関係のバグなので同様に起きると考えられますが、推測にとどまります)。**この手順で確認すべきなのは「`CPF4131` という様式レベル ID のエラーが消えたこと」だけであり、それ以外のメッセージが出ないことではありません**(詳しくは実機メモ参照)。

9. `TXSTATUS` で確認します。

   ```text
   TXSTATUS LIB(<USER>1)
   ```

   **ここで注意**: `txmigr.clp` の最後のメッセージは `TXMIGR: done. DBVER=2. Run TXSTATUS to check; update TXSTATE by hand if this tool did not.` となっており、**`TXMIGR` のソースを実際に読むと、`TXSTATE` を書き換える `CHGDTAARA` の呼び出しがどこにもありません。** つまり、ここまでの手順を終えても `TXSTATUS` はまだ `DBVER=0000000001` のままのはずです。これはバグではなく、**ツール側がまだ実装していない部分**です(この教材自身の未完成点を、正直に見つける良い練習にもなります)。手で仕上げます。

   ```text
   CHGDTAARA DTAARA(<USER>1/TXSTATE) VALUE(2)
   TXSTATUS LIB(<USER>1)
   ```

   `TXSTATUS: DBVER=0000000002 in library <USER>1` と出れば完了です。

## 演習

次の「再作成チェックリスト」は、`JUDLV` 追加後に(架空の)同僚が作った手順書です。**1つ、大事な手順が抜けています。** どれが抜けているか、そしてこのリストどおりに実行した場合、最終的にどのプログラムで・どんな症状(メッセージ ID)が起きるかを答えてください。

```text
□ 1. CHGPF FILE(<USER>1/JUCHUM) SRCFILE(<USER>1/QDDSSRC) SRCMBR(JUCHUM)
□ 2. CRTRPGPGM PGM(<USER>1/ZA0500) SRCFILE(<USER>1/QRPGSRC) SRCMBR(ZA0500)
□ 3. CRTRPGPGM PGM(<USER>1/JU0300) SRCFILE(<USER>1/QRPGSRC) SRCMBR(JU0300)
□ 4. CRTCLPGM PGM(<USER>1/JU0900C) SRCFILE(<USER>1/QCLSRC) SRCMBR(JU0900C)
```

<details><summary>解答</summary>

**抜けているのは「`JUCHUL1`(論理ファイル)の再作成」(`DLTF`+`CRTLF`)です。** `JUCHUM` は直しましたが、その上の `JUCHUL1` を作り直していないため、`JUCHUL1` は「`JUCHUM` の古い様式レベル ID」を前提にしたままの状態(`JUCHUM` の新しい様式レベル ID とは食い違った状態)で残ります。

手順3で `JU0300` を再コンパイルしても、`JU0300` は `JUCHUL1` を外部記述で参照しているので、**コンパイル時に `JUCHUL1`(古いまま)の様式レベル ID を新しく焼き込んでしまいます**。実行時には `JUCHUL1` を `OPEN` した瞬間に、`JUCHUL1` 自身が `JUCHUM` に対して古いままなので、**`JU0300` の実行時に `CPF4131`(あるいは `JUCHUL1` を作り直す作業自体で似た系統のエラー)が再発します。** `ZA0500`・`JU0900C` は `JUCHUL1` を使わないので、この抜けの影響を受けません。

</details>

## セルフチェック

- [ ] 様式レベル ID とは何か、なぜ `CPF4131` が起きるのかを自分の言葉で説明できる。
- [ ] `CHGPF SRCFILE(...)` と `CRTPF` の違い(データを残すかどうか)を説明できる。
- [ ] PF → LF → RPG → CL という順序が必要な理由(1つ上流を直すと、その下流でまた様式レベル ID がズレる)を説明できる。
- [ ] `LVLCHK(*NO)` がなぜ「解決」ではなく「危険な回避」なのかを説明できる。
- [ ] プログラム記述で読んでいるファイルには様式レベル・チェックが効かないことを、`ZA0500` の例で説明できる。

## 片付け

このレッスンで作成・変更したオブジェクト(`<USER>1/JUCHUM`・`JUCHUL1`・`ZA0500`・`JU0300`・`JU0900C`)はそのまま残してください。05-10 でも同じ `<USER>1`(`DBVER=2` の状態)を使います。

## まとめ

| 英語 | 日本語 |
|---|---|
| Record format level ID | 様式レベル ID |
| Level check | レベル・チェック |
| Logical file | 論理ファイル |
| Program-described file | プログラム記述ファイル |

次のレッスン(05-10)では、今度は表示装置ファイル(DSPF)と RPG を実際にそろえて直しながら、この様式レベル ID の考え方を「画面に項目を足す」場面で使います。

## 実機メモ

- **旧システム側の個々のオブジェクト(`za0500.rpg`・`ju0300.rpg`・`ju0900c.clp`)は、コンパイルはV1、`ZA0500`/`JU0900C` の実行(呼び出し)はV2まで確認済みです。** `part05-legacy-probe`(確認日2026-09-26、2回接続、CONFIRMED SUCCESS)で `ZA0500`・`JU0300`(RPG、Highest Severity 00)・`JU0900C`(CL)としてコンパイル成功を確認しました。`part05-txlegacy-exec`(確認日2026-09-27、CONFIRMED SUCCESS)では、`TXLEGACY` 自身がCLONEDIR配下の実ツリーから `CPYFRMSTMF` する本来の仕事を初めて実行し、`FLDREF`・`FLDREFR`・`TK0100D`・`MN0000D`・`TK0100`・`JU0300`・`ZA0500`・`JU0900C`・`MN0000C` を新規に作成し直して `TXLEGACY: done.` まで到達しました(こちらは **TXLEGACY というツール自体** の実行結果一致でV2)。**さらに `part05-ju0900c-baseline`(確認日2026-09-27、CONFIRMED SUCCESS)は、as-shipped(未修正)の `JU0900C` から `ZA0500` への実際の `CALL`(`RUNMODE='*TEST'`)をV2まで確認しています**——ただしこれは05-13チケット1のバグ(`&MINQTY` の桁数不一致)の実測が目的で、1行目で確実に `RPG0907`(10進データ・エラー)が発生し0行印字のまま `JU0900C: ZA0500 ended abnormally.` にエスケープする(ハングはしない)という、このレッスンとは別の話題の結果です。`JU0300` はこの実行確認の対象外で、依然コンパイルのみ(V1)です。**いずれの実行・コンパイルも `db/v1/juchum.pf`(`JUDLV` 追加前、DBVER=1)の様式に対するものです。** このレッスンの核心である「`JUDLV` 追加後(`db/v2/juchum.pf`)への `CHGPF` → `CPF4131` 発生 → `DLTF`/`CRTLF` → 再コンパイルで解消」という一連の流れそのものは、まだ実機で一度も通していません。上記の `RPG0907` は `JUCHUM` の様式(`JUDLV` の有無)とは無関係な `JU0900C`→`ZA0500` 間のパラメーター渡しの不一致が原因なので、`DBVER=2` 移行後も同様に起きると考えられますが、それ自体は未検証です(下記「実演」手順8の注記も参照)。
- **このレッスンの核心の流れ(`CHGPF` による `JUDLV` 追加→`CPF4131` 発生→`TXMIGR TO(2)` による解消)は、2026-09-27に接続A(`part05-txmigr-to2`)・接続B(`part05-txmigr-to2b`)の2回構成でV2まで確認済みです(CONFIRMED SUCCESS)。**
  - 接続A: `TXSETUP LIB(&LIB2)`で`<USER>B`にDBVER=1の全表を新規構築し、`RUNCHGPF`(`db/v2/juchum.pf`への`CHGPF`)を実行(`8 records copied`/`File JUCHUM in library <USER>B changed.`、正常終了)。**旧形式でコンパイル済みの`RUNPROBE`(検証専用ヘルパー)・`JU0900C`が、変更後の`JUCHUM`を開こうとして`CPF4131`(レコード様式レベル・チェック不一致)で失敗することを確認**——このレッスンが教えたい核心の実機再現に、この教材で初めて成功しました。
  - 接続B: `TXMIGR`本体(`TO(2)`による再コンパイル)を実行し、Step 3(`DSPOBJD`+全`*PGM`再コンパイル)で`JU0300`・`JU0900C`・`RUNPROBE`・`ZA0500`が全て成功(Highest Severity 00)。**`RUNPROBE`(TXMIGRによって再コンパイル済み)が`JUCHUM`を再度読むと`CPF4131`が解消することを確認**——TXMIGRのStep 3だけでレベル・チェック不一致が解消することが実機で確定しました。Step 1(`CHGPF`、冪等に再適用)は成功、Step 2(`CRTLF`によるJUCHUL1再構築)は`JUCHUL1`が既に存在するため意図された無害な失敗(既存LFの削除はしない設計どおり)。`TXMIGR: done. DBVER=...update TXSTATE by hand if this tool did not.`という完了メッセージどおり、**`TXSTATE`は自動更新されず、手動更新が必要であることも実機で確認済みです。**
- **`TXMIGR`(`tools/qclsrc/txmigr.clp`)自体は、V1(コンパイル)・実行(Step 1-3の一連の流れ)ともCONFIRMED SUCCESSです。** ただし途中で1件、実在するレッスン内容のバグを発見・修正しました: **`DCLF FILE(QTEMP/TXMDBR)`/`DCLF FILE(QTEMP/TXMPGM)`(実行時にしか存在しないファイルへの直接DCLF)は、そもそもコンパイル時点でこれらのファイルが存在しないと`CRTCLPGM`自体が失敗する**ことが`part05-txmigr-to2b`の意図的な「無防備」コンパイル試行(`CPTXMIGRRW`)で実機確認されました(`Program TXMIGR not created.`、`CPF0801`のみで通常のリストすら出ない)。**実在の学習者がレッスンどおり`CRTCLPGM PGM(TXMIGR)`を試すと同じ理由で必ず失敗する、致命的なレッスン設計上の欠陥でした。** 修正として、IBM提供のモデル・ファイル`QSYS/QADSPDBR`(DSPDBRの既定OUTFILE書式)・`QSYS/QADSPOBJ`(DSPOBJDの既定OUTFILE書式)へDCLFする方式に再設計し(これらは常に実在するためコンパイル時点でQTEMP側の状態に依存しない)、実行時は`OVRDBF`でモデル・ファイルを実際のQTEMPファイルへリダイレクトします。**この再設計も1回目の実装(両方のDCLFとも既定`OPNID(*NONE)`)では`CPD0303`(`*NONE`は1プログラム中1ファイルまで)で失敗し、明示的な`OPNID(D)`/`OPNID(P)`を使う版へさらに修正しています**(`part05-txmigr-compile-check`、CONFIRMED SUCCESS、`Program TXMIGR created ... Maximum error severity 10.`)。詳細は`docs/probes.md`の`part05-txmigr-to2b`・`part05-txmigr-compile-check`記録を参照。
- 依存するプローブ `P19` は、上記の接続A・Bで実質的に解消しました(破壊的操作=`CHGPF`/`TXMIGR TO(2)`実行を`<USER>2`/`<USER>B`という開発役ライブラリーに対して実際に行い、確認済み)。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
