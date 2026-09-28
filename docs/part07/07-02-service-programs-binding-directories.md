# 07-02 サービス・プログラムとバインディング・ディレクトリー

> 所要時間: 60分 / 前提レッスン: 07-01 / 目標番号: 5 / 観測方法: `DSPJOBLOG`・`DSPSRVPGM` / 道具: SSH(`CPYFRMSTMF` でのソース取り込み)、5250(コンパイル・実行・確認)、SQL(`STRSQL`)/ 同時接続数: 5250×1(SSHでのソース取り込みは都度接続し直します。02-04・05-01・06-04・07-01と同じやり方です)/ 作る・変えるオブジェクト: `<USER>1/JUCSRV`(*MODULE→*SRVPGM)・`<USER>1/JUCSRVBD`(*BNDDIR)・`<USER>1/F0702A`(プログラム)(発展・任意で`<USER>1/D0702A`・`<USER>1/F0702B`も)/ DBVER: 1 / 依存するプローブ: P26(`CRTSRVPGM`・`CRTBNDDIR`等、このレッスンの範囲を確認します。残り(`UPDSRVPGM`・バインダー言語)は07-03で確認します)/ PTF 依存: なし / 容量の目安: わずか

## ゴール

- サービス・プログラム(`*SRVPGM`)が、07-01の`CRTPGM MODULE()`(コピーによる結合)と何が違うか(実行のたびに解決される、参照による結合)を説明できる。
- バインダー・ソース(`QSRVSRC`)がまだ無い段階で`CRTSRVPGM`を実行するとき、`EXPORT(*ALL)`を明記しなければならない理由を説明できる。
- `*BNDDIR`(バインディング・ディレクトリー)を作り、`*LIBL`経由でサービス・プログラムを解決する呼び出し側プログラム(`ctl-opt bnddir`)を書ける(通し例12)。

## ウォームアップ

<details><summary>前回の復習(07-01)</summary>

1. 07-01の`M0701B`(`nomain`モジュール、業務ニックネームJUCUTL)は、なぜ`CRTBNDRPG`単独ではプログラムにできず、`CRTRPGMOD`→`CRTPGM`という2段階のビルドが必須だったのですか?
2. `M0701A`+`M0701B`を結合した`F0701A`の活動化グループを実際に決めたのは、`M0701A`自身の`ctl-opt`でしたか、それとも`CRTPGM`コマンドでしたか?

答え: 1. `nomain`を指定したモジュールは、一次資料(ILE RPG言語リファレンス)により「プログラム・エントリー・モジュールになれない」ため、`CRTBNDRPG`ではプログラムを作れず、`CRTPGM`(またはこの課で扱う`CRTSRVPGM`)で他のモジュールと結合する必要があるからです。 2. `CRTPGM`コマンド自身の`ACTGRP()`パラメーターです。`M0701A`冒頭の`ctl-opt dftactgrp(*no) actgrp(*new);`は`/IF DEFINED(*CRTBNDRPG)`で囲まれており、`CRTRPGMOD`でコンパイルする07-01のビルド経路では最初から実行されませんでした。

</details>

## なぜ学ぶか

07-01は`*MODULE`/`*PGM`/`*SRVPGM`を`.o`/実行ファイル/`.so`にたとえ、`*SRVPGM`を「実行時に別オブジェクトとして存在し続け、`*LIBL`経由で参照として解決される(参照による結合)」とだけ予告して終わりました。この課では、その予告を実際に手を動かして確認します。

06-12(`JUCINQ4`/`F0612A`)は、得意先コードから得意先名を引く`CHAIN TOKUIM`のロジックを、単一のプログラムの中に直接書いていました。もし同じロジックが別のプログラムでも必要になったら、06-05/06-06の`F0605A`/`F0606A`が`calcTaxTotal`/`sendMsg`でそうしていたように、また同じコードを複製することになります。この課では、その同じロジックを`JUCSRV`という新しいサービス・プログラムの手続き`getCustName`として独立させ、新しい比較用クライアント`F0702A`から**動的に**呼び出します。`F0612A`自体は一切編集しません——06-12の模範解答はそのまま残ります。

## 新出

- 中核概念:
  1. **`*SRVPGM`は複数のプログラムから動的に共有されるロジックの置き場所である**(07-01の`CRTPGM MODULE()`によるコピー結合とは違う、参照による結合)。
  2. **`*BNDDIR`(バインディング・ディレクトリー)は、呼び出し側がライブラリー名をソースにハードコードせずに済むようにする、名前の登録簿である**。
  3. **`QSRVSRC`(バインダー・ソース)がまだ無い段階で`CRTSRVPGM`を実行するには、`EXPORT(*ALL)`を明記しなければならない**(既定値は`*SRCFILE`で、バインダー・ソースの実在を前提にしているため)。
- 構文:
  - `CRTRPGMOD`→`CRTSRVPGM ... EXPORT(*ALL)`(サービス・プログラムの作成)
  - `CRTBNDDIR`(バインディング・ディレクトリーの作成)
  - `ADDBNDDIRE ... OBJ((*LIBL/xxx *SRVPGM))`(登録するオブジェクトの追加。`*LIBL`は「実行時のライブラリー・リストから探す」という意味)
  - `dcl-pr ... extproc(*dclcase)`(呼び出し側のプロトタイプ。`JUCSRV`側の`dcl-pi`も同じキーワードを使いますが、`export`・`dcl-pi`自体は07-01の新出のため、ここでは呼び出し側のこの使い方だけを数えます)
  - `ctl-opt bnddir('...')`(呼び出し側で使うバインディング・ディレクトリーの指定)
  - `CRTSRVPGM`・`CRTPGM`の`BNDSRVPGM`(`*LIBL`指定も可。`*BNDDIR`の代わりに個々の`*SRVPGM`を直接列挙するパラメーター。この課の`JUCSRV`/`F0702A`自体は使いません(`*BNDDIR`経由の`ctl-opt bnddir`だけを使います)が、一次資料に載っている名前として構文に数えておきます——読解用です)

## 説明

### `*SRVPGM`とは: コピーによる結合との対比

07-01の`F0701A`は、`CRTPGM MODULE(M0701A M0701B)`で2つのモジュールのコードをそのまま**コピー**して1つの`*PGM`にまとめていました。結合が終われば、`F0701A`は`M0701B`が今も実在するかどうかに関係なく動きます。

サービス・プログラム(`*SRVPGM`)は違います。呼び出し側(`F0702A`)は`JUCSRV`のコードを自分の中にコピーしません。かわりに`JUCSRV`という**別のオブジェクトへのシンボリック・リンク**を持ち、そのリンクは`F0702A`が**活動化(activate)**されるときに、そのときの`*LIBL`から`JUCSRV`を探して物理アドレスへ変換されます(一次資料: `ileconcepts75.txt` 1236-1241行目)。これが07-01が予告した「参照による結合」です(`F0702A`の場合に、この解決が実際に`CALL`のたび起きると考えられる理由は、後述の「`*BNDDIR`と`*LIBL`による解決」節の3段階目で扱います)。この方式のおかげで、`JUCSRV`が公開する手続きの一覧(シグネチャー、07-03で詳しく扱います)さえ変わらなければ、`JUCSRV`の中身だけを差し替えても`F0702A`を再コンパイルする必要はありません。**ただし、この課のように`EXPORT(*ALL)`のままエクスポートする手続きの数自体を変えると話は別です**——07-03で、まさにこの`F0702A`を使って、その場合に何が起きるかを実際に確認します(片付け参照)。

### `JUCSRV`: `nomain`モジュールと`getCustName`

`JUCSRV`は07-01の`M0701B`(JUCUTL)と同じ`nomain`モジュールです。このレッスンの時点では、次の手続き1つだけを持ちます(実際に取り込む`jucsrv.rpgle`は07-03で追加する手続きも同じファイルにまとめて収録していますが、それらは今は書きません——「実演」で詳しく説明します)。

```rpgle
ctl-opt nomain;

dcl-f tokuim keyed usage(*input);

dcl-proc getCustName export;
  dcl-pi *n char(30) extproc(*dclcase);
    custCode char(6) const;
  end-pi;

  chain (custCode) tokuim;
  if %found(tokuim);
    return toknm;
  else;
    return 'NOTFOUND';
  endif;
end-proc;
```

これは04-08(`R0408A`/JUCINQ3)・06-12(`F0612A`)がそれぞれ持っていた「得意先コードを`TOKUIM`に`CHAIN`し、見つかれば得意先名、見つからなければ`'NOTFOUND'`」というロジックと同じ形です。**`TOKNM`は`CHAR(30)`です**(`db/v1/tokuim.pf`で直接確認済み——「20桁」という思い込みがあれば、ここで訂正してください)。

`extproc(*dclcase)`は、この手続きの外部呼び出し名(エクスポート名)を、コンパイラーの既定(大文字化)ではなく`dcl-proc`に書いたとおりの大小文字(`getCustName`)に固定するキーワードです。**束縛呼び出しでは、`*PGM`の中の別モジュールを呼ぶ場合でも`*SRVPGM`をまたぐ場合でも、呼ぶ側(インポート)・呼ばれる側(エクスポート)の両方が同じ外部名に合意している必要があります**——バインダーは、指定されたモジュール・サービス・プログラム・バインディング・ディレクトリーの中から、インポート要求に一致するエクスポートを探して結び付けるからです(一次資料: `ileconcepts75.txt` 1214-1217行目)。07-01の`calcTaxTotal`/`sendMsg`が`extproc`無しで済んだのは、この合意が不要だったからではありません。呼ぶ側(`m0701s.rpgle`)・呼ばれる側(`jucutl.rpgle`)の両方が`EXTPROC`を指定しなかったため、**既定のルールにより同じ大文字化名(`CALCTAXTOTAL`・`SENDMSG`)に揃った**だけです(一次資料: `ilerpgref75.txt` 48121-48124行目、`jucutlp.rpgleinc`87-88行目に引用——「`EXTPROC`未指定時の束縛呼び出しの既定エントリー・ポイントは、プロトタイプ名を大文字化したもの」。ここに`*PGM`/`*SRVPGM`の区別はありません)。ここで`getCustName`に`extproc(*dclcase)`が本当に必要な理由は、07-03で追加する`src/qsrvsrc/jucsrv.bnd`(バインダー・ソース)が`EXPORT SYMBOL('getCustName')`と**引用符付きの混在大小文字**で書くためです。一次資料によれば、引用符付きでこの大小文字を指定したエクスポート・シンボルは、**その混在大小文字とまったく同じ綴りの外部名を持つエクスポート**にしか一致せず、コンパイラーの既定(大文字化)のままでは一致しません(詳しい経緯は`jucsrv.rpgle`ヘッダー66-78行目)。`extproc(*dclcase)`で外部名をあらかじめ`getCustName`という綴りに固定しておくのは、このためです。

### `EXPORT(*ALL)`を明記する

`CRTSRVPGM`の`EXPORT`パラメーターの既定値は`*SRCFILE`です。一次資料によれば、`*SRCFILE`は指定した`SRCFILE`/`SRCMBR`にあるバインダー・ソース・メンバーを読んで、公開する手続きの一覧(シグネチャー)を決める方式です。ところがこの課の時点では、`QSRVSRC`というソース・ファイル自体をまだ作っていません。バインダー・ソースが実在しないまま既定値のまま`CRTSRVPGM`を実行すると、当然そのメンバーが見つからずエラーになります(具体的なメッセージIDは、このレッスンではまだ実機で確認していません——推測で書かないという方針上、あえて挙げません)。

そこで、モジュールが`export`した手続きをすべてそのまま公開する`EXPORT(*ALL)`を明記します。

```text
CRTRPGMOD MODULE(<自分のユーザー名>1/JUCSRV) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(JUCSRV)
CRTSRVPGM SRVPGM(<自分のユーザー名>1/JUCSRV) MODULE(<自分のユーザー名>1/JUCSRV) EXPORT(*ALL) ACTGRP(*CALLER)
```

`ACTGRP(*CALLER)`は、このサービス・プログラム自身の活動化グループを新たに作らず、呼び出し元(`F0702A`)が今動いている活動化グループの中でそのまま動く、という指定です。

### `*BNDDIR`と`*LIBL`による解決

呼び出し側のソースに`JUCSRV`が今どのライブラリーにあるかを書かずに済ませるため、バインディング・ディレクトリー(`*BNDDIR`)を作ります。

```text
CRTBNDDIR BNDDIR(<自分のユーザー名>1/JUCSRVBD)
ADDBNDDIRE BNDDIR(<自分のユーザー名>1/JUCSRVBD) OBJ((*LIBL/JUCSRV *SRVPGM))
```

`OBJ((*LIBL/JUCSRV *SRVPGM))`の`*LIBL`は、「今すぐこのライブラリーに決め打ちする」のではなく、「呼び出しが実際に行われるときのジョブの`*LIBL`から`JUCSRV`という名前の`*SRVPGM`を探す」という指定です。この「いつ、何を`*LIBL`から探すか」は、実は1か所ではなく3段階あります。

1. **`F0702A`をコンパイルする時点、その1**: `ctl-opt bnddir('JUCSRVBD')`(次項)は、ライブラリー名を修飾していない非修飾名です。一次資料によれば、ライブラリー名を指定しない場合、`*LIBL`からそのバインディング・ディレクトリー自体を探します——つまり`CRTBNDRPG`を実行する時点で、`<自分のユーザー名>1`が`*LIBL`に入っている必要があります。
2. **`F0702A`をコンパイルする時点、その2**: `JUCSRVBD`(見つかったバインディング・ディレクトリー)自体に登録されているのは、まだ解決されていない`*LIBL/JUCSRV`という参照です。`CRTBNDRPG`はこの参照を実際にたどり、そのときの`*LIBL`から`JUCSRV`を見つけ、`getCustName`がエクスポートされていることを確認し、その時点の`JUCSRV`のエクスポート一覧(07-03で扱う「シグネチャー」)を`F0702A`自身に記録します。ただし記録される**ライブラリー**は、解決済みの具体的なライブラリー名ではなく`*LIBL`という値そのものです——だから演習3の`QSYS2.BOUND_SRVPGM_INFO`は`*LIBL`と表示します。
3. **`F0702A`を`CALL`する時点**: 一次資料(`ileconcepts75.txt` 1236-1241行目)によれば、参照による結合が持つのは`JUCSRV`への**シンボリック・リンク**で、これが物理アドレスに変換されるのは、そのプログラム・オブジェクトが**活動化(activate)**されるときです。そして動的プログラム呼び出し(dynamic program call、`CALL`)がプログラムを活動化するのは「その活動化がまだ存在していない場合」に限られます(同75.txt 5058-5061行目)。`F0702A`は`ctl-opt actgrp(*new)`なので、この課で検証している範囲では、`CALL`のたびに新しい活動化が起き、そのたびに改めてその時点の`*LIBL`から`JUCSRV`を探すと考えられます。ライブラリー名は一切固定されません。**ただし、この`*LIBL`再解決が実際に`CALL`のたび起きること自体を、このレッスンでは実機で独立に確認していません**(一次資料の記述の組み合わせからの推論です。07-01の`ACTGRP(*ENTMOD)`の未確認半分と同じ扱いです)。名前付き活動化グループや`ACTGRP(*CALLER)`のように、活動化が複数回の`CALL`をまたいで維持される構成では、2回目以降の`CALL`では活動化が既に存在するため、この再解決自体が起きない可能性があります(活動化グループの継続/リセットは07-04で扱います)。

### 呼び出し側: `F0702A`

```rpgle
ctl-opt dftactgrp(*no) actgrp(*new) bnddir('JUCSRVBD');

dcl-pr getCustName char(30) extproc(*dclcase);
  custCode char(6) const;
end-pr;

dcl-pi *n;
  cust char(6);
end-pi;

dcl-s custName char(30);

custName = getCustName(cust);
sendToJobLog('F0702A: getCustName(' + cust + ') = '
               + %trimr(custName));
```

`dftactgrp(*no) actgrp(*new)`は、`F0702A`自身が`sendToJobLog`というサブプロシージャー(`dcl-proc`)を持つためです。既定の活動化グループ(`DFTACTGRP(*YES)`)ではサブプロシージャーを定義できません(06-06のウォームアップで復習した`RNF1520`のとおりです)。加えて一次資料によれば、`DFTACTGRP(*YES)`のままでは`BNDDIR`自体を使えません。**07-01の`M0701A`自身の`ctl-opt dftactgrp(*no) actgrp(*new);`は、`/IF DEFINED(*CRTBNDRPG)`で囲まれていたため実際には効いていなかった(活動化グループを決めたのは`CRTPGM`コマンド側でした)ことを思い出してください——ここでの`F0702A`は`CRTBNDRPG`で単独コンパイルするので、今度はこの`ctl-opt`が文字どおり効きます。** `dcl-pr getCustName ... extproc(*dclcase)`は、`JUCSRV`側の`dcl-pi`と同じ外部名に合意するためのプロトタイプです。`sendToJobLog`は06-09で導入したジョブ・ログ出力の技法(`QMHSNDPM`を直接呼ぶ手続き。07-01の`sendMsg`と考え方は同じですが、実装はこの`F0702A`自身が持つ別の手続きです)を前借りしています——中身の説明はここでは省略します。`F0702A`の`dcl-pi`は`JUCINQC`/`F0612A`とまったく同じ形(`CHAR(6)`1個)にしてあり、同じ得意先コードを渡せば両者の出力を照合できます。**ただし`JUCINQ`コマンドのCPP(コマンド処理プログラム)を差し替えるのは06-12で扱う話であり、この課ではもう一度行いません**——`F0702A`はあくまで、`F0612A`の出力と見比べるためだけの、オフラインの比較用プログラムです。

## 実演

1. SSHで接続し、`~/ibmi-kyozai`を最新にする(`git pull`)。

2. ソースを取り込みます。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/jucsrv.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/JUCSRV.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/f0702s.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/F0702A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

3. 5250に戻り、`JUCSRV`メンバーを開いて編集します。**取り込んだばかりの`JUCSRV`は、07-02と07-03の両方の内容をまとめて持っています**(このリポジトリーは、レッスンごとの中間状態を別ファイルとしては持たない、という方針のためです)。このレッスンではまだ次の2か所を書かないので、削除してください。

   - `pingJucsrv`・`countCustOrders`という、2つの`dcl-proc`ブロック丸ごと(どちらも07-03で追加します)。
   - `dcl-f juchum usage(*input) usropn;`の行(07-03で`countCustOrders`と一緒に追加します)。

   削除し終えると、`JUCSRV`メンバーの実行可能な内容は、上の「説明」節で示した`ctl-opt nomain;`・`dcl-f tokuim ...;`・`getCustName`の3ブロックだけになります。**`countCustOrders`(`dcl-proc`ブロック)は消したのに`dcl-f juchum ... usropn;`の行だけ消し忘れる、という組み合わせに注意してください。** `juchum`をオープンする文は`countCustOrders`の中にしかないため、この消し忘れがあると「`USROPN`のファイルなのに、それを明示的にオープンする文がどこにも無い」という状態になり、コンパイルが`RNF7062`(severity 30)で失敗します。これは実際に`part07-03-signature`の1回目の接続で実機発生したエラーと同じ組み合わせです(V1、実機確認済み)。

4. コンパイルします。

   ```text
   CRTRPGMOD MODULE(<自分のユーザー名>1/JUCSRV) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(JUCSRV)
   CRTSRVPGM SRVPGM(<自分のユーザー名>1/JUCSRV) MODULE(<自分のユーザー名>1/JUCSRV) EXPORT(*ALL) ACTGRP(*CALLER)
   ```

   `CRTRPGMOD`はHighest Severity 10で成功するはずです(`RNF7534`: 「非サイクル・モジュールでは`TOKUIM`を明示的にクローズすべき」という助言。警告だけで、モジュール自体は作成されます)。

5. バインディング・ディレクトリーを作ります(`JUCSRVBD`はこの課で初めて作るので、存在確認は不要です)。

   ```text
   CRTBNDDIR BNDDIR(<自分のユーザー名>1/JUCSRVBD)
   ADDBNDDIRE BNDDIR(<自分のユーザー名>1/JUCSRVBD) OBJ((*LIBL/JUCSRV *SRVPGM))
   ```

6. `F0702A`をコンパイルし、実行します。

   ```text
   CRTBNDRPG PGM(<自分のユーザー名>1/F0702A) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(F0702A)
   CALL PGM(<自分のユーザー名>1/F0702A) PARM('C00001')
   DSPJOBLOG
   ```

   次のメッセージが記録されます(`getCustName`をこのとおりの手順で呼び出した結果そのものは複数の接続で実測されています。この課ちょうどの構成——`getCustName`だけを持つ1手続きの`JUCSRV`——での検証状況の詳細は「実機メモ」を参照してください)。

   ```text
   CPF9898:  F0702A: getCustName(C00001) = ACME TRADING CO.
   ```

   **このメッセージ・テキストの内容そのものは、このハーネスの非対話SSH接続がジョブ・ログを直接読み取って確認済み(V2)です。5250で実際に`DSPJOBLOG`の画面を操作してこれを見る部分(表示のされ方など)は対話操作(V3)であり、このレッスンでは実機確認していません**(06-06と同じ扱いです)。

7. `DSPSRVPGM SRVPGM(<自分のユーザー名>1/JUCSRV)`を実行し、エクスポートされている手続きの一覧に`getCustName`が出ることを、自分の目で確認してください(対話的な画面確認なのでV3です)。

## 演習

1. `getCustName`を`'C00002'`・`'C00003'`で呼び出し(`CALL PGM(<自分のユーザー名>1/F0702A) PARM('C00002')`のように`F0702A`を経由します)、`NORTH STAR LTD`・`BLUE OCEAN INC`が返ることを確認してください(`db/data/load_v1.sql`の`TOKUIM`データと照合できます)。
2. 存在しない得意先コード`'C99999'`で呼び出し、`'NOTFOUND'`が返ることを確認してください(04-08の`R0408A`・06-12の`F0612A`と同じフォールバックです)。
3. `STRSQL`で次を実行し、`F0702A`が`*LIBL`経由で`JUCSRV`に結び付いていることを確認してください。

   ```sql
   SELECT PROGRAM_NAME, BOUND_SERVICE_PROGRAM_LIBRARY, BOUND_SERVICE_PROGRAM
     FROM QSYS2.BOUND_SRVPGM_INFO
     WHERE PROGRAM_NAME = 'F0702A' AND PROGRAM_LIBRARY = '<自分のユーザー名>1'
   ```

   `PUB400`は共有環境なので、`PROGRAM_LIBRARY`(`F0702A`自身が置かれているライブラリー)で必ず自分の環境に絞り込んでください。`BOUND_SERVICE_PROGRAM_LIBRARY`が`*LIBL`(特定のライブラリー名ではなく、この特殊値そのもの)になっていることに注目してください——これが「説明」節で述べた「実行時に改めて`*LIBL`から探す」参照が、実際にどう記録されているかです。`QRNXIE`・`QRNXUTIL`・`QLEAWI`という3行が一緒に出てきても無視してください(`QSYS`提供のランタイム・サービス・プログラムで、`JUCSRV`とは無関係です)。

4. (発展・任意)**「JUCLST4のJUCSRV版」**: 06-11で作った`D0611A`/`F0611A`(JUCHUMの一覧、`JUCLST4`)は、得意先名を表示していません。`D0611A`/`F0611A`自体は一切編集せず、新しいオブジェクト`D0702A`(DSPF)・`F0702B`(RPG)を作り、`JUCHUM`の一覧に`getCustName`で得意先名(`JUNM`)を付け加えた、同じ形の一覧を作ってみてください。`06-11`の`D0611A`/`F0611A`を先に読み、その`SFL`/`SFLCTL`/`SFL1FTR`の構造をできるだけそのまま流用するのがおすすめです(実際に`src/qddssrc/d0702s.dspf`・`src/qrpglesrc/f0702bs.rpgle`という、その方針で書いた実物がリポジトリーにあります——`06-11`のOPT(5=注文照会)やメッセージ・サブファイルの仕組みは丸ごと省き、`ROLLUP`/`ROLLDOWN`だけで送り読みできる、選択肢の無い一覧にしてあります)。ロード・ループの中で、書く前に1行ずつ`getCustName`を呼びます。

   ```rpgle
   read juchum;
   dow not %eof(juchum);
     rrn1 += 1;
     junm = getCustName(jutok);
     write sfl1;
     read juchum;
   enddo;
   ```

   **この発展演習は、このレッスンの必須の検証には含まれません。** `D0702A`・`F0702B`は、このリポジトリーではまだ実機コンパイルしていません(V1未満・未検証、次回の接続で確認予定)。取り組む場合は、自分でコンパイル(V1: Highest Severityの確認)し、実際の5250セッションで動作を確かめてください(V3)。

## セルフチェック

- [ ] `*SRVPGM`が、07-01の`*PGM`(コピーによる結合)と何が違うかを説明できる。
- [ ] `QSRVSRC`が無い段階で`CRTSRVPGM`を実行するとき、`EXPORT(*ALL)`を明記しなければならない理由を説明できる。
- [ ] `CRTBNDDIR`・`ADDBNDDIRE`で`*BNDDIR`を作り、`ctl-opt bnddir`で呼び出し側から使えた。
- [ ] `*LIBL`が「`F0702A`のコンパイル時(バインディング・ディレクトリー自体を探す/`JUCSRV`を実際に解決してシグネチャーを記録する)」「`F0702A`の`CALL`時(改めて`JUCSRV`を探す)」という複数の段階で使われることを説明できる。
- [ ] `getCustName('C00001')`が`ACME TRADING CO`を返すことを、`F0702A`経由で確認できた(演習1・2で他の得意先コードも試した)。
- [ ] `QSYS2.BOUND_SRVPGM_INFO`で、`F0702A`が`*LIBL`経由で`JUCSRV`に結び付いていることを確認できた。

## 片付け

`JUCSRV`・`JUCSRVBD`・`F0702A`はそのまま残してください。**特に`F0702A`は、このレッスンの後、07-03が来るまで一切さわらず(再コンパイルもせず)そのまま残してください。** 07-03では、`JUCSRV`に新しい手続きを`EXPORT(*ALL)`のまま追加し、このレッスンで作った`F0702A`をあえて壊してから直す、という実演をします——これは事故ではなく、07-03自体の教える要点です。演習4(発展・任意)で`F0702B`も作った場合、`F0702B`も同じ仕組み(`EXPORT(*ALL)`のまま署名が変わると、再バインドしていない既存クライアントは壊れる、という`MCH4431`が実機で確認されている挙動)により、いずれ同じように壊れるはずです(この`F0702B`固有のケースを実際に壊して確認した接続はまだありません——推論です)。07-03の設計は`F0702A`だけを対象にしているため、`F0702B`は自分で同じ手順を踏んで直す必要があります。ファイルの書き込みは行わないため、`TXRESET`は不要です。

## まとめ

| 英語 | 日本語 |
|---|---|
| Service program (`*SRVPGM`) | サービス・プログラム |
| Binding directory (`*BNDDIR`) | バインディング・ディレクトリー |
| Bind by reference | 参照による結合(07-01で予告、この課で実演) |
| Library list (`*LIBL`) | ライブラリー・リスト |
| Signature | シグネチャー(07-03で本格的に扱います) |

次のレッスン(07-03)では、この`JUCSRV`にバインダー・ソースと2つ目の手続きを追加し、`EXPORT(*ALL)`がなぜ壊れやすいかを実際に確認したうえで、`F0702A`を直します。

## 実機メモ

- **確認日: 2026-09-27。接続`part07-0203-srvpgm`(1回接続、CONFIRMED SUCCESS)。** `JUCSRV`(`getCustName`・`pingJucsrv`・`countCustOrders`の3手続き、07-02と07-03の最終状態をまとめたもの)を`EXPORT(*SRCFILE)`(07-03のバインダー・ソース経由)でビルドし、`JUCSRVBD`を新規作成、`F0702A`・`F0703A`の両方から呼び出したところ、次がV2(非対話で実行し、接続の`run`セクションの生テキストで確認)まで確認できました。
  - `JUCSRV`モジュールはHighest Severity 10で作成(`RNF7534`: 「非サイクル・モジュールでは`TOKUIM`を明示的にクローズすべき」という助言。警告のみで作成自体は成功)。
  - `F0702A`は`CALL PGM(F0702A) PARM('C00001')`に対し、接続の生ログに次のとおり記録されました。`CPF9898:  F0702A: getCustName(C00001) = ACME TRADING CO.`
  - `QSYS2.BOUND_SRVPGM_INFO`で、`F0702A`・`F0703A`とも`BOUND_SERVICE_PROGRAM_LIBRARY=*LIBL`・`BOUND_SERVICE_PROGRAM=JUCSRV`と記録されていることを確認(`QRNXIE`/`QRNXUTIL`/`QLEAWI`はQSYS提供のランタイム・サービス・プログラムで無関係)。
- **このレッスンがちょうど教える構成(`getCustName`だけを持つ1手続きの`JUCSRV`、`EXPORT(*ALL)`、バインダー・ソース無し)そのものを単独で作り直した接続は、まだありません。** 最も近いV2の裏付けは次の2つです。
  - **`part07-03-signature`(確認日2026-09-28。結果ファイルのタイムスタンプ`part07-03-signature-2026-09-28T00-20-11-370Z.json`・`-2026-09-28T00-35-17-377Z.json`、および生ログに埋め込まれたPUB400のシステム時計`26-09-28`で確認済み)の手順1〜2**: `getCustName`・`pingJucsrv`の2手続き版を`EXPORT(*ALL)`でベースライン化し、`F0702A`を新規コンパイルして束縛したところ、`CALL`が成功し`getCustName(C00001) = ACME TRADING CO`が得られました。この時点では`pingJucsrv`(07-03で追加する手続き)も一緒に入っていましたが、`EXPORT(*ALL)`・`ctl-opt bnddir`を使う`F0702A`からの呼び出し、という**この課が教える仕組みの中核**は、ここで実際に動作しています。**ただしこの接続自体は`CRTBNDDIR`/`ADDBNDDIRE`を実行していません**(`part07-03-signature`のマニフェストを確認すると、新規作成・削除しているのは無関係の使い捨て`*BNDDIR`である`TOSSBD`だけで、`JUCSRVBD`はこの接続より前の`part07-0203-srvpgm`接続で既に作成済みのものをそのまま使っています)。`CRTBNDDIR`/`ADDBNDDIRE`による`JUCSRVBD`自体の新規作成が実機で確認されているのは、次の`part07-0203-srvpgm`の方です(その接続の生ログに`CPF9801: Object JUCSRVBD in library <lib> not found.`に続けて`CPC5D02: Binding directory JUCSRVBD created`・`CPD5D0A: Object *LIBL/JUCSRV type *SRVPGM added to binding directory JUCSRVBD`と記録されています)。
  - 上記の`part07-0203-srvpgm`(最終3手続き版、`EXPORT(*SRCFILE)`+バインダー・ソース経由)。
  - この2つを合わせても、「`getCustName`だけを持つ1手続きの`JUCSRV`」という、このレッスンがちょうど教える構成そのもの(手続きが1つだけ、`dcl-f juchum`も無い状態)を、実際にこのとおりコンパイルした接続はまだありません。**個々の要素(`EXPORT(*ALL)`での`CRTSRVPGM`・`CRTBNDDIR`/`ADDBNDDIRE`による`*LIBL`登録・`ctl-opt bnddir`を使う`F0702A`からの`getCustName`呼び出し)はそれぞれV2まで確認済みですが、「手続きが1つだけ」という組み合わせそのもののV1(コンパイルが通ること)確認はまだありません。** 次回接続でこの構成そのものを確認する予定です。
- `src/qrpglesrc/jucsrv.rpgle`・`src/qrpglesrc/f0702s.rpgle`自身のヘッダー・コメントは、今も「STATUS: hardware-UNTESTED」という記述のままですが、これは古い記述です。上記`part07-0203-srvpgm`により、少なくとも最終状態(3手続き)でのV2は確認済みです。ソース自身のヘッダーの書き換えは本レッスンの担当範囲外なので、ここでは食い違いの指摘のみ残します(06-06が同様の食い違いを指摘したのと同じ扱いです)。
- `src/qrpglesrc/f0702s.rpgle`自身のヘッダー・コメントは、ビルド手順を`CRTBNDRPG PGM(<USER>1/F0702A) SRCFILE(<USER>1/QRPGLESRC) SRCMBR(F0702S)`とも記載していますが、これも古い記述です。このレッスン(実演2・6)の手順では、`CPYFRMSTMF`の`TOMBR`も`CRTBNDRPG`の`SRCMBR`も一貫して`F0702A`であり(`M0701A`(07-01)以来のパート+レッスン+連番のメンバー命名規則にも合致します)、`F0702S`というメンバーはこのレッスンの手順では作られないため、そのままでは実行できません。これも本レッスンの担当範囲外なので、食い違いの指摘のみ残します(直前の項目と同じ扱いです)。
- `TOKNM`が`CHAR(30)`であることは、`db/v1/tokuim.pf`を直接読んで確認済みです(当初「20桁」という思い込みがあった場合の訂正です)。
- **演習1・2の`C00002`(→`NORTH STAR LTD`)・`C00003`(→`BLUE OCEAN INC`)・`C99999`(→`NOTFOUND`)は、`db/data/load_v1.sql`の`TOKUIM`データと照合した期待値です**(`C00002`・`C00003`の行、および`C99999`に該当する行が無いことを、いずれもソースを直接読んで確認済みです)。**ただし、これらの入力で`getCustName`/`F0702A`を実際に実機で呼び出して確認した接続はまだありません**(V1・V2とも、この3件については未実施です)。実機メモでV2まで確認済みなのは`C00001`だけです。演習として、学習者自身がこの3件を実際に確認してください。
- **`<USER>1/D0702A`・`<USER>1/F0702B`(演習4、発展・任意)は、V1未満(コンパイル自体をまだこのリポジトリーで実行していません)。** 次回の接続で、少なくともV1(コンパイル確認)まで確認する予定です。取り組む場合は、自分の環境で最初のV1確認者になる前提で臨んでください。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
