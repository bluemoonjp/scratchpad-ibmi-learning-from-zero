# 07-03 バインダー・ソースと署名

> 所要時間: 60分 / 前提レッスン: 07-02 / 目標番号: 5 / 観測方法: `DSPJOBLOG`・`DSPSRVPGM` / 道具: SSH(`CPYFRMSTMF` でのソース取り込み)、5250(コンパイル・実行・確認)/ 同時接続数: 5250×1(SSHでのソース取り込みは都度接続し直します。02-04・05-01(ルートでは 04-27)と同じやり方です)/ 作る・変えるオブジェクト: `<USER>1/JUCSRV`(更新: 手続きを2回追加)・`<USER>1/QSRVSRC`(新規ソース・ファイル)・`<USER>1/F0703A`(新規)。`<USER>1/F0702A`はこのレッスンの中で1回だけ再コンパイルします / DBVER: 1 / 依存するプローブ: P26, P38 / PTF 依存: なし / 容量の目安: わずか

## ゴール

- `EXPORT(*ALL)`のサービス・プログラムが、エクスポートする手続きの数を変えるたびに、既にバインドされた既存クライアントを壊しうることを、実際に壊して確認できる。
- バインダー・ソース(`QSRVSRC`、`STRPGMEXP`/`EXPORT SYMBOL`/`ENDPGMEXP`)を書き、`PGMLVL(*CURRENT)`と`PGMLVL(*PRV)`で新旧2つのシグネチャーを共存させられる。
- `JUCSRV`に`countCustOrders`を追加し、既存クライアント(`F0702A`)を再コンパイルせずに(一時的に壊れた状態を経て)最終的に動かせる状態へ戻したまま、新しいクライアント(`F0703A`)だけがそれを使えることを確認できる。

## ウォームアップ

<details><summary>前回の復習(07-02)</summary>

1. `*SRVPGM`(サービス・プログラム)が、07-01の`CRTPGM MODULE()`(コピーによる結合)と違う点は何でしたか?
2. `CRTSRVPGM`の`EXPORT`パラメーターの既定値は何で、07-02の時点ではなぜそれをそのまま使えず`EXPORT(*ALL)`を明記しなければならなかったのですか?

答え: 1. コピーではなく**参照による結合**です。呼び出し側(`F0702A`)は`JUCSRV`のコードを自分の中に持たず、`*LIBL`から探して活動化される時点で解決される別オブジェクトへのリンクを持つだけでした(一次資料による)。 2. 既定値は`*SRCFILE`(バインダー・ソースを読む)です。07-02の時点では`QSRVSRC`自体がまだ無かったため、既定のままでは失敗し、`EXPORT(*ALL)`(モジュールがexportした手続きをすべてそのまま公開する)を明記する必要がありました。

</details>

## なぜ学ぶか

07-02の最後、あなたの`JUCSRV`は`getCustName`だけを持つ1手続きの状態で、`F0702A`はそのシグネチャー(1手続き分のエクスポート一覧)にバインドされたまま残っています。07-02の説明はこう予告していました。「この課のように`EXPORT(*ALL)`のままエクスポートする手続きの数自体を変えると話は別です——07-03で、まさにこの`F0702A`を使って、その場合に何が起きるかを実際に確認します。」

このレッスンでは、その予告を実際に実行します。`JUCSRV`に手続きを2回追加し(まず動作確認用の`pingJucsrv`、続いて本題の`countCustOrders`)、`EXPORT(*ALL)`のままだと何が起きるかを実際に壊して確認したうえで、バインダー・ソースというもう1つの`EXPORT`方式に切り替え、同じ追加を既存クライアントを壊さずに行う方法を身につけます。実務のサービス・プログラムは、公開後も機能追加が続くのが普通です。そのたびに全クライアントの再コンパイルを要求するようでは「参照による結合」の利点が失われてしまいます——バインダー・ソースは、この課題への一次資料(ILE Concepts)自身の答えです。

## 新出

- 中核概念:
  1. **シグネチャー**: エクスポートする手続き・データ項目の名前の並びから決まる値。ただし並び方の規則が2つあります。**`EXPORT(*ALL)`は「エクスポートする手続きの数」と「エクスポート名のアルファベット順」**でシグネチャーを計算し、**バインダー言語(明示的な`SIGNATURE`を指定しない場合)は「バインダー・ソースに書いたそのままの順序」**で計算します(いずれも一次資料の規則)。この2つは別物です。
  2. **同じ名前を同じ順序で並べたエクスポート・ブロックは同じシグネチャーになる**(一次資料の規則)。新しい手続きを追加するときは、既存の並びを一切変えず、末尾に追記するだけでよい——ただし「並び」の基準は、上の2つのうちどちらの方式でシグネチャーを計算するかによって変わります。
  3. **`PGMLVL(*CURRENT)`は1つだけ**。過去の互換シグネチャーを保ちたい場合は、`PGMLVL(*PRV)`という追加ブロックを(いくつでも)用意します。
- 構文:
  - `STRPGMEXP` / `EXPORT SYMBOL('name')` / `ENDPGMEXP`(バインダー言語の3コマンド。`QSRVSRC`に書く)
  - `PGMLVL(*CURRENT|*PRV)`(`STRPGMEXP`のパラメーター。新旧2つのシグネチャーを共存させる仕組み)
  - `CRTSRVPGM ... EXPORT(*SRCFILE) SRCFILE(...) SRCMBR(...)`
  - `UPDSRVPGM`(既存のサービス・プログラムに、モジュールの新しいエクスポートを反映させる)

## 説明

### なぜ`EXPORT(*ALL)`は壊れやすいか: シグネチャーの仕組み

一次資料(ILE Concepts)によれば、シグネチャーは「エクスポートする手続き・データ項目の名前の並びと、その順序」から決まる値です。ただし、その「順序」の決め方は方式によって違います。**`EXPORT(*ALL)`が計算するシグネチャーは「エクスポートする手続きの数」と「エクスポート名のアルファベット順」で決まる**と一次資料に明記されています。一方、バインダー言語(`STRPGMEXP`/`EXPORT SYMBOL`、明示的な`SIGNATURE`パラメーターを指定しない場合)は「**バインダー・ソースに書いたそのままの順序**」でシグネチャーを計算します——`EXPORT(*ALL)`のアルファベット順とは別の規則です。この違いは、既存の`EXPORT(*ALL)`サービス・プログラムをバインダー・ソースへ移行する際に実際に問題になります(詳しくは後述)。

`EXPORT(*ALL)`は、バインダー・ソースを使わずに、モジュールが今exportしている一覧から(アルファベット順で)この計算を自動でやり直す方式です。つまり`EXPORT(*ALL)`は「今この瞬間の一覧」しか知りません。過去にどんな一覧だったかを覚えておく仕組みが無いため、**モジュールがexportする手続きの数(=エクスポート一覧)が変わるたびに、シグネチャーも変わってしまいます。** 一次資料はさらに、「互換性を壊さずにサービス・プログラムのエクスポートを削除する方法は無い(既存のプログラムやサービス・プログラムがそのエクスポートに依存しているかもしれないため)」とも明記しています。

`F0702A`は07-02の時点で、`getCustName`1つだけのシグネチャーにバインドされました。この後の実演では、まず`pingJucsrv`を追加した段階で`F0702A`を1回だけ束縛し直します。そのうえで`JUCSRV`に`countCustOrders`を追加して`EXPORT(*ALL)`のまま再作成すると、`F0702A`のソースにも実行方法にも一切手を加えていないのに、次に`CALL`したときバインドが壊れます——これがこの課の核心です。

### `pingJucsrv`: 署名の仕組みを実演するためだけの、使い捨ての手続き

最初に追加する`pingJucsrv`は、**常に`*on`を返すだけの、本題ではない手続き**です。実際の`JUCSRV`が提供する機能(得意先名の取得・注文件数の集計)とは何の関係もありません。存在する唯一の理由は、この後`countCustOrders`を追加したときに起こす署名違反の実演で、`F0702A`のシグネチャーにも`PGMLVL(*PRV)`ブロックにも**1つだけでなく複数の名前**を持たせておくことです(1手続きだけのシグネチャーでは、名前の「順序」がそもそも問題にならず、`*PRV`が`EXPORT(*ALL)`のシグネチャーと一致するかどうかを試す余地がありません)。

```rpgle
dcl-proc pingJucsrv export;
  dcl-pi *n ind extproc(*dclcase);
  end-pi;

  return *on;
end-proc;
```

**`pingJucsrv`は`countCustOrders`とは別物です。** 前者は署名の仕組みを実演するためだけの使い捨て、後者はこのレッスンの本題(得意先ごとの注文件数を数える、実際に使う機能)です。名前も役割も戻り値も違う2つの独立した手続きとして、混同しないでください。また、一度`F0702A`がこの手続きを含むシグネチャーにバインドされてしまうと(次の実演の後)、一次資料の「エクスポートを互換性を壊さずに削除する方法は無い」という規則により、**`pingJucsrv`は今後`JUCSRV`から二度と削除できません。** 「使い捨て」はこの手続きの**目的**を指しているのであって、ファイルに残り続ける**期間**の話ではないことに注意してください。

### `countCustOrders`: 「カット&ペーストでは済まない」`JUCHUM`の再配置

`countCustOrders`は、06-12の`F0612A`が持っていた「得意先ごとの注文件数を数える」ロジック(`JUCHUM`を先頭から`READ`し、得意先コードが一致するたびに`orderCnt`を増やす)を移植したものです。ロジックの中身自体はそのまま使えます。

```rpgle
dcl-proc countCustOrders export;
  dcl-pi *n zoned(5:0) extproc(*dclcase);
    custCode char(6) const;
  end-pi;

  dcl-s orderCnt zoned(5:0) inz(0);

  close juchum;
  open  juchum;

  read juchum;
  dow not %eof(juchum);
    if jutok = custCode;
      orderCnt += 1;
    endif;
    read juchum;
  enddo;

  close juchum;

  return orderCnt;
end-proc;
```

ただし、そのまま移植するだけでは済みません。`F0612A`は「1回`CALL`すれば1回集計して終わり」の帳票プログラムでしたが、`countCustOrders`は`*SRVPGM`の手続きなので、**同じ活動化グループの中で何度でも呼ばれます。** `JUCHUM`はこのモジュールのグローバル・ファイル(手続きの外、モジュール直下で宣言したファイル)で、一次資料(ILE RPG言語リファレンス)によれば、グローバル・ファイルは(`nomain`モジュールの中では)暗黙にクローズされることが無く、**最後に`READ`した位置のまま、活動化グループが生きている限りずっと開いたまま**になります。ということは、素朴に`read`/`dow`/`read`のループだけを移植すると、1回目の呼び出しで`JUCHUM`は終端(`%eof`)まで読み進み、2回目の呼び出しでは**何も読まないうちから`%eof`が真**になり、常に`0`を返してしまいます。

そこで、読み取りループの前に`close juchum; open juchum;`を置き、呼ばれるたびに読み込み位置を強制的に先頭へ巻き戻します。`close`は「まだ開いていないファイルへの`close`はエラーにならない」ため初回呼び出しでも安全で、`open`の前に必ず`close`を挟むのは「既に開いているファイルへの`open`はエラーになる」ためです(いずれも一次資料・ILE RPG言語リファレンスの`CLOSE`/`OPEN`の説明による)。

```rpgle
dcl-f juchum usage(*input) usropn;
```

`JUCHUM`を`usropn`付きで宣言しているのは、`TOKUIM`(`usropn`無し)と違って、**モジュール初期化の時点では開かせないため**です。一次資料(ILE RPG言語リファレンス)によれば、`usropn`の無いグローバル・ファイルはモジュール初期化時に暗黙にオープンされます。`usropn`を付けるとこの自動オープンが起きなくなり、`countCustOrders`が実際に呼ばれるまで`JUCHUM`は開かれないままになります(06-04で見たとおり(一次資料による)、手動で`CLOSE`したファイルは`usropn`の有無にかかわらずそのまま`OPEN`し直せるはずなので、`close juchum; open juchum;`という並び自体は、初回の呼び出しでもそのまま安全に使えると考えられます。実際、`F0703A`の1回目の呼び出しが実機で正しい件数を返している以上、この初回の`close`/`open`が問題なく機能していること自体はV2で確認できています)。

この`close`/`open`の組は、06-04の`F0604A`が`EXFMT`ループの中で毎回`JUCHUM`を巻き戻していたのと同じ発想です。違うのは、06-04では画面プログラム自身がループの中で巻き戻していたのに対し、ここでは**サービス・プログラムの手続き自身が、呼ばれるたびに自分で巻き戻す責任を持つ**という点です——呼び出し側(`F0703A`)はこの事情を一切知らなくてよい、というのがサービス・プログラムに機能を切り出す利点でもあります。

### バインダー・ソース(`QSRVSRC`): `STRPGMEXP`/`EXPORT SYMBOL`/`ENDPGMEXP`

`QSRVSRC`に置くバインダー・ソースは、次の3つのコマンドの並びだけでできています。

```text
STRPGMEXP PGMLVL(*CURRENT)

   EXPORT SYMBOL('getCustName')
   EXPORT SYMBOL('pingJucsrv')
   EXPORT SYMBOL('countCustOrders')

ENDPGMEXP

STRPGMEXP PGMLVL(*PRV)

   EXPORT SYMBOL('getCustName')
   EXPORT SYMBOL('pingJucsrv')

ENDPGMEXP
```

`PGMLVL(*CURRENT)`のブロックが、今`JUCSRV`が公開する最新のシグネチャー(3手続き、モジュールの宣言順と同じ順序)です。`PGMLVL(*PRV)`のブロックは、`F0702A`が今バインドされている`EXPORT(*ALL)`のシグネチャー(`getCustName`・`pingJucsrv`の2手続き)を再現するためのものです。`EXPORT SYMBOL`の名前が引用符付き・小文字混じりなのは、`jucsrv.rpgle`側の各手続きが`extproc(*dclcase)`(07-02既習)でこの綴りを外部名として固定しているのと対応させるためです。

**注意: `PGMLVL(*CURRENT)`の並び(`getCustName`・`pingJucsrv`・`countCustOrders`、モジュールの宣言順)は、アルファベット順ではありません**(アルファベット順なら`countCustOrders`が先頭に来るはずです)。バインダー言語は「書いた順序」でシグネチャーを計算するので、この並びのまま**新規に**`CRTSRVPGM`する分には何の問題もありません。ただし、もし`EXPORT(*ALL)`で運用していた既存のサービス・プログラムを、この3手続きの並びのままバインダー・ソースに切り替えようとした場合は話が別です。`EXPORT(*ALL)`側はアルファベット順(`countCustOrders`・`getCustName`・`pingJucsrv`)でシグネチャーを計算していたはずなので、宣言順で書いた`*CURRENT`ブロックとは**一致しません**。この食い違いは、実機メモに記録した1回目の接続で実際に確認されています(次の実演自体は、2手続き→3手続きへの数の変化による`MCH4431`を別の形で示します)。`PGMLVL(*PRV)`ブロック(`getCustName`・`pingJucsrv`の2つだけ)がこの後うまく機能するのは、この2つの名前を書いた順序(`getCustName`・`pingJucsrv`)が、モジュールの宣言順であると同時に、`EXPORT(*ALL)`が使うアルファベット順(`g` < `p`)とも一致しているからです——**宣言順とアルファベット順が一致しない場合は、名前が2つであっても一致しません。**

実務では、サービス・プログラムを最初からバインダー・ソースで作り始めれば、この食い違い自体が起きません。既に`EXPORT(*ALL)`で運用しているサービス・プログラムをバインダー・ソースへ移行する場合は、`*PRV`ブロックを`EXPORT(*ALL)`と同じアルファベット順で書く必要があります。一次資料(ILE Concepts)は、`RTVBNDSRC`コマンドを既存のサービス・プログラムに対して実行すると、「そのサービス・プログラムを再作成・更新するのに適した」バインダー・ソースを生成できると説明しており、手書きより確実にこの移行を行える手段だと考えられますが、`RTVBNDSRC`自体はこのレッスンでは実機確認していません。

いったんバインダー・ソースに切り替えた後、さらに新しい手続きを追加する場合は、一次資料(ILE Concepts)が示す手順——**古い`*CURRENT`のブロックをそのまま複製して`*PRV`にし、新しい手続きは元の`*CURRENT`の末尾にだけ追加する**——を使います(このレッスンでは`*ALL`からの切替そのものが目的のため、この「複製して追記する」手順自体は実演していません)。

### `CRTSRVPGM`と`UPDSRVPGM`

```text
CRTSRVPGM SRVPGM(<自分のユーザー名>1/JUCSRV) MODULE(<自分のユーザー名>1/JUCSRV)
          EXPORT(*SRCFILE) SRCFILE(<自分のユーザー名>1/QSRVSRC) SRCMBR(JUCSRV)
          ACTGRP(*CALLER)
```

このレッスンでは、`EXPORT`方式そのものを`*ALL`から`*SRCFILE`へ切り替えるのに`CRTSRVPGM`(作り直し)を使い、続けて同じ内容で`UPDSRVPGM`も実行して両方が使えることを確認します。

```text
UPDSRVPGM SRVPGM(<自分のユーザー名>1/JUCSRV) MODULE(<自分のユーザー名>1/JUCSRV)
          EXPORT(*SRCFILE) SRCFILE(<自分のユーザー名>1/QSRVSRC) SRCMBR(JUCSRV)
```

`UPDSRVPGM`の`EXPORT`の既定値は`*CURRENT`で、一次資料によれば「現在エクスポートされているものがそのままエクスポートされ続ける。新しいシグネチャーは作られない」という意味です。既定のままでは新しい手続きを拾えないため、ここでも`EXPORT(*SRCFILE) SRCFILE()/SRCMBR()`を明記する必要があります(07-02で`EXPORT(*ALL)`を明記しなければならなかったのと同じ理由の繰り返しです)。一次資料によれば、いったんバインダー・ソースに切り替えた後で新しい手続きを追加するだけなら、この`UPDSRVPGM`だけで足りるはずです。**ただし、この実演では`CRTSRVPGM`で切り替えた直後に同じ内容で`UPDSRVPGM`を実行しているため、確認できているのは構文と完了メッセージだけです。**「`CRTSRVPGM`をやり直さず、`UPDSRVPGM`だけで新しい手続きを追加する」という運用そのものを単独で確認したわけではありません。

## 実演

**この実演の一連の流れ(`pingJucsrv`追加→`F0702A`再バインド→`countCustOrders`追加で署名違反→バインダー・ソースへの切替→`F0702A`無改修確認→`F0703A`成功)は、`part07-03-signature`(確認日2026-09-28)で実機確認済みです。詳細は「実機メモ」を参照してください。**

前提: 07-02の片付けどおり、あなたの`JUCSRV`メンバーは`getCustName`だけを持ち、`F0702A`はそのシグネチャー(1手続き)にバインドされています。

1. SSHで接続し、`~/ibmi-kyozai`を最新にする(`git pull`)。続けて`F0703A`のソースを取り込みます(`JUCSRV`メンバー自体は07-02で取り込み済みのものを、この後の手順で直接編集します)。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/f0703s.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/F0703A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

2. **`pingJucsrv`を書き戻す。** 5250で`<自分のユーザー名>1/QRPGLESRC`の`JUCSRV`メンバーを編集し、`getCustName`の`end-proc;`の後に、上の「説明」節で示した`pingJucsrv`のブロックをそのまま追加してください(`countCustOrders`と`dcl-f juchum ... usropn;`の行は、まだ追加しません)。

3. コンパイルし直します。

   ```text
   CRTRPGMOD MODULE(<自分のユーザー名>1/JUCSRV) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(JUCSRV)
   CRTSRVPGM SRVPGM(<自分のユーザー名>1/JUCSRV) MODULE(<自分のユーザー名>1/JUCSRV) EXPORT(*ALL) ACTGRP(*CALLER)
   ```

   `CRTRPGMOD`はHighest Severity 10(`RNF7534`: 「非サイクル・モジュールでは`TOKUIM`を明示的にクローズすべき」という助言のみ、07-02と同じ)で成功します(V1、実機確認済み)。

   (この時点で、`F0702A`を再コンパイルせずにそのまま`CALL`すると、07-02由来の1手続きシグネチャーと今の2手続きシグネチャーが食い違うため、ここでも`MCH4431`になると予想されますが、この1→2手続きの遷移そのものは実機確認していません。)

4. **`F0702A`を、ソースは変えずにもう一度コンパイルします。** `F0702A`は07-02の時点で`getCustName`1つだけの1手続きシグネチャーにバインドされていました。`pingJucsrv`の追加で`JUCSRV`の`EXPORT(*ALL)`シグネチャーは2手続き分に変わったため、ここで束縛し直しておかないと、後のステップ12で`PGMLVL(*PRV)`の2手続き分のシグネチャーが救い出す相手(2手続き分にバインドされた`F0702A`)が存在しないことになります。これが、このレッスンで`F0702A`を触る**唯一**の箇所です。この先は最後まで、`F0702A`を二度と再コンパイルしません。

   ```text
   CRTBNDRPG PGM(<自分のユーザー名>1/F0702A) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(F0702A)
   CALL PGM(<自分のユーザー名>1/F0702A) PARM('C00001')
   ```

   ジョブ・ログに次が記録されます(V2、実機確認済み)。

   ```text
   CPF9898:  F0702A: getCustName(C00001) = ACME TRADING CO.
   ```

   `F0702A`は今、`getCustName`+`pingJucsrv`という2手続きの`EXPORT(*ALL)`シグネチャーにバインドされています。

5. **本題: `countCustOrders`を追加します。** `JUCSRV`メンバーに、`dcl-f tokuim ...;`の次の行として`dcl-f juchum usage(*input) usropn;`を追加し、`pingJucsrv`の`end-proc;`の後に、上の「説明」節で示した`countCustOrders`のブロックをそのまま追加してください。

6. 再コンパイルします(依然`EXPORT(*ALL)`のままです)。

   ```text
   CRTRPGMOD MODULE(<自分のユーザー名>1/JUCSRV) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(JUCSRV)
   CRTSRVPGM SRVPGM(<自分のユーザー名>1/JUCSRV) MODULE(<自分のユーザー名>1/JUCSRV) EXPORT(*ALL) ACTGRP(*CALLER)
   ```

   再びHighest Severity 10(`RNF7534`、`TOKUIM`について)で成功します(V1、実機確認済み)。

7. **`F0702A`を再コンパイルせずに、もう一度`CALL`します。**

   ```text
   CALL PGM(<自分のユーザー名>1/F0702A) PARM('C00001')
   ```

   **これは失敗します(V2、実機確認済み)。**

   ```text
   MCH4431:  Program signature violation.
   CPF0001:  Error found on CALL command.
   ```

   `F0702A`は2手続き分のシグネチャーにバインドされたままですが、`JUCSRV`は今3手続き分のシグネチャーを`EXPORT(*ALL)`(アルファベット順)で計算し直しています。`F0702A`のソースも実行方法も一切変えていないのに、`JUCSRV`側の変更だけでバインドが壊れました——これがこの課の核心です。

8. **`QSRVSRC`を用意します。** まだ無ければ先に作成してください。

   ```text
   CRTSRCPF FILE(<自分のユーザー名>1/QSRVSRC) RCDLEN(112) TEXT('Binder language source')
   ```

9. SSHで再接続し、バインダー・ソースを取り込みます。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qsrvsrc/jucsrv.bnd') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QSRVSRC.FILE/JUCSRV.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

   取り込んだ内容は、上の「説明」節で示したバインダー・ソース(`PGMLVL(*CURRENT)`の3シンボル+`PGMLVL(*PRV)`の2シンボル)そのものです。

10. 5250に戻り、`EXPORT(*SRCFILE)`へ切り替えます。

    ```text
    CRTSRVPGM SRVPGM(<自分のユーザー名>1/JUCSRV) MODULE(<自分のユーザー名>1/JUCSRV)
              EXPORT(*SRCFILE) SRCFILE(<自分のユーザー名>1/QSRVSRC) SRCMBR(JUCSRV)
              ACTGRP(*CALLER)
    ```

11. `UPDSRVPGM`も同じ設定で実行し、構文・完了メッセージを確認します。

    ```text
    UPDSRVPGM SRVPGM(<自分のユーザー名>1/JUCSRV) MODULE(<自分のユーザー名>1/JUCSRV)
              EXPORT(*SRCFILE) SRCFILE(<自分のユーザー名>1/QSRVSRC) SRCMBR(JUCSRV)
    ```

    ジョブ・ログに次が記録されます(V2、実機確認済み)。

    ```text
    CPC5D15:  Service program JUCSRV in <lib> updated.
    ```

12. **`F0702A`を、依然再コンパイルせずに、もう一度`CALL`します。**

    ```text
    CALL PGM(<自分のユーザー名>1/F0702A) PARM('C00001')
    ```

    **今度は成功します(V2、実機確認済み)。**

    ```text
    CPF9898:  F0702A: getCustName(C00001) = ACME TRADING CO.
    ```

    `PGMLVL(*PRV)`ブロックにバインダー・ソースの中で書いた2シンボル(`getCustName`・`pingJucsrv`、宣言順)が、ステップ4の時点で`EXPORT(*ALL)`(アルファベット順)が計算していたシグネチャーと一致しました。`getCustName`・`pingJucsrv`という2つの名前に限っては、宣言順とアルファベット順が一致していたためです。

13. **新しいクライアント`F0703A`をコンパイルします。** `countCustOrders`自体は`export`付きの`dcl-proc`なので、`EXPORT(*ALL)`だったステップ6の時点でも、モジュールからは既にエクスポートされています。ただし、もしこの時点(ステップ6直後)で`F0703A`をビルドしていたら、そのときの`EXPORT(*ALL)`(アルファベット順)の3手続き分シグネチャーにバインドされていたはずです。ステップ10で切り替える`PGMLVL(*CURRENT)`は宣言順で書いてあり、`EXPORT(*ALL)`のアルファベット順とは一致しないため、その`F0703A`も壊れていたと考えられます。この組み合わせ自体は、`F0703A`という同じオブジェクトでは実機確認していませんが、同じ仕組み(3手続き分の`EXPORT(*ALL)`署名から宣言順の`PGMLVL(*CURRENT)`へ切り替えた際の署名不一致)は、実機メモに記録した1回目の接続で`F0702A`が実際に`MCH4431`で壊れる形で確認されています。そこで、バインダー・ソースへの切替が終わったこのステップ10以降で`F0703A`をビルドします。

    ```text
    CRTBNDRPG PGM(<自分のユーザー名>1/F0703A) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(F0703A)
    CALL PGM(<自分のユーザー名>1/F0703A) PARM('C00001')
    ```

    ジョブ・ログに次が記録されます(V2、実機確認済み。`countCustOrders`を同じ`CALL`の中で2回連続呼び、`JUCHUM`の再配置が正しく効いていることまで確認します)。

    ```text
    CPF9898:  F0703A: countCustOrders(C00001) call 1 = 2.
    CPF9898:  F0703A: countCustOrders(C00001) call 2 = 2.
    CPF9898:  F0703A: MATCH - both calls agree; JUCHUM repositioning is correct..
    ```

    **この2回の呼び出しが同じ`CALL`の中で行われることには理由があります。** `JUCSRV`は`ACTGRP(*CALLER)`(呼び出し元の活動化グループの中で活動化される、上のステップ10で実機確認済み)である一方、`F0703A`自身は`ctl-opt actgrp(*new)`です。もし`CALL PGM(F0703A)`というコマンドを別々に2回実行していたら、`F0703A`自身の活動化グループがそのたびに新しく作られ、`JUCSRV`もそのたびに新しく活動化されてしまうため(一次資料からの推論。07-02の「`*LIBL`再解決」の議論と同じ、未確認のままの領域です)、`close`/`open`による巻き戻しが正しく効いているかどうかにかかわらず、2回目の呼び出しはいつも「初回」と同じ状態から始まってしまい、`JUCHUM`の再配置バグ(演習3)を検出できません。`F0703A`のプログラム本体が**1回の実行の中で**`countCustOrders`を2回呼ぶのは、そのための必須条件です。

## 演習

1. `F0703A`を`'C00002'`・`'C99999'`で呼び出してください(`CALL PGM(<自分のユーザー名>1/F0703A) PARM('C00002')`のように)。`db/data/load_v1.sql`の`JUCHUM`データによれば、`C00002`は1件(`J00002`)、`C99999`は0件のはずです。2回の呼び出しが両方とも一致(`MATCH`)することを確認してください。
2. `DSPSRVPGM SRVPGM(<自分のユーザー名>1/JUCSRV) DETAIL(*SIGNATURE)`を実行し、シグネチャーの値そのものを見てみてください(一次資料・ILE Conceptsが「シグネチャーの値は`DSPSRVPGM DETAIL(*SIGNATURE)`で確認できる」と明記しています)。あわせて`DSPSRVPGM SRVPGM(<自分のユーザー名>1/JUCSRV)`(既定の`DETAIL`)で、公開されている手続き一覧に`getCustName`・`pingJucsrv`・`countCustOrders`の3つが出ることも確認してください。手続き一覧とシグネチャーの値そのものは、同じバインダー・ソースから作った状態の`JUCSRV`について`part07-0203-srvpgm`(確認日2026-09-27)で`OUTPUT(*PRINT)`を使い、接続の生ログ(run section)に出た印刷内容を読んで確認済みです(V2)。ここで5250から対話的に画面を操作して確認する作業そのものはV3です。
3. (発展・実機未確認)`countCustOrders`から`JUCHUM`の再配置が本当に効いているか、あえて壊して確認してみてください。**ただし、`close juchum;`と`open juchum;`の2行だけを消す、という方法は誤りです。** `juchum`は`usropn`付きで宣言されているため、モジュール全体でこの`open`が唯一の明示的な`OPEN`です。この2行だけを消すと、`open`の無い`usropn`ファイルとしてコンパイル自体が`RNF7062`(severity 30)で失敗します(07-02の実演・手順3で説明した組み合わせと同じです)。素朴な移植のバグを本当に再現するには、`dcl-f juchum usage(*input) usropn;`から`usropn`を外し(`tokuim`と同じ、モジュール初期化時に自動でオープンされる普通のグローバル・ファイルに戻し)、`countCustOrders`内の`close juchum;`/`open juchum;`/末尾の`close juchum;`を**すべて**削除して、`read`/`dow`/`read`のループだけを残してください(06-12の`F0612A`の元のロジックそのままの形です)。この状態で再コンパイル・再作成し、`F0703A`をもう一度呼ぶと、2回目の`call 2 =`が`0`になり`MISMATCH`と報告される**はずです**が、この具体的な予測はこのレッスンでは実機確認していません(一次資料からの推論です)。試したら、元の(`usropn`付きの)ソースに戻すのを忘れないでください。

## セルフチェック

- [ ] `EXPORT(*ALL)`が、モジュールのエクスポート一覧が変わるたびに既存クライアントを壊しうる理由(シグネチャーの再計算)を説明できる。
- [ ] `EXPORT(*ALL)`(アルファベット順)とバインダー言語(書いた順序)とで、シグネチャーの並びの基準が違うことを説明できる。
- [ ] `pingJucsrv`と`countCustOrders`が別物であること、`pingJucsrv`が一度バインドされると二度と削除できない理由を説明できる。
- [ ] `countCustOrders`に`close juchum; open juchum;`が必要な理由(*SRVPGMは活動化グループの寿命いっぱいファイルを開いたままにするため)を、06-04の`CLOSE`/`OPEN`と対比しながら説明できる。
- [ ] `STRPGMEXP PGMLVL(*CURRENT)`/`PGMLVL(*PRV)`/`EXPORT SYMBOL`/`ENDPGMEXP`の構文と、「新しい手続きは既存の並びの末尾にだけ追加する」という規則を説明できる。
- [ ] `F0702A`を1回だけ再コンパイルした後、`JUCSRV`側の変更(`EXPORT(*ALL)`のまま`countCustOrders`追加)で実際に壊れ(`MCH4431`)、バインダー・ソースへの切替(`CRTSRVPGM`→`UPDSRVPGM`)で`F0702A`を再コンパイルせずに直ったことを確認できた。
- [ ] `F0703A`(`countCustOrders`使用)が成功し、2回連続の呼び出しが一致することを確認できた。

## 片付け

`JUCSRV`・`JUCSRVBD`・`QSRVSRC`の`JUCSRV`メンバー・`F0702A`・`F0703A`はそのまま残してください。07-04は`JUYAKL`(ILE CL)から`getCustName`を呼び出すため、`JUCSRV`をそのまま使います。`TOKUIM`・`JUCHUM`はどちらも読み取り専用のアクセスしかしていないので、データが書き換わることはなく、`TXRESET`も不要です。**07-02の演習4(発展・任意)で`F0702B`も作っていた場合**、`F0702B`は`getCustName`だけの1手続きシグネチャーにバインドされたままです。07-02自身が予告していたとおり、`F0702B`をこの課のシグネチャー変更に追随させる作業(壊れているかの確認・再バインド)はこのレッスンの対象外で、まだ行っていません。取り組んだ場合は、自分で`CALL`して壊れているかどうかを確かめ、必要なら再コンパイルしてください。

## まとめ

| 英語 | 日本語 |
|---|---|
| Signature | シグネチャー(エクスポートの名前と順序から決まる、サービス・プログラムの契約) |
| Binder language | バインダー言語(`STRPGMEXP`/`EXPORT SYMBOL`/`ENDPGMEXP`) |
| Program signature violation | プログラム署名違反(`MCH4431`) |
| Update Service Program (`UPDSRVPGM`) | サービス・プログラムの更新(バインダー・ソース切替後にエクスポートを追加する手段) |

次のレッスン(07-04)では、活動化グループを名前付きで選び、ILE CL(`JUYAKL`)から`CALLPRC`で`JUCSRV`の`getCustName`を呼び出します。

## 実機メモ

- **確認日: 2026-09-28。接続`part07-03-signature`。** このレッスンの一連の流れ(`pingJucsrv`追加→`F0702A`再バインド→`EXPORT(*ALL)`のまま`countCustOrders`追加で署名違反→バインダー・ソースへの切替→`F0702A`無改修での復旧→`F0703A`成功)は、2回目の接続でCONFIRMED SUCCESSまで到達しました。接続の生ログ(run section)で実際に確認できた内容は次のとおりです(いずれもV2)。
  - `getCustName`+`pingJucsrv`の2手続き版を`EXPORT(*ALL)`でベースライン化し、`F0702A`を新規コンパイルして束縛したところ、`CALL`が成功(`F0702A: getCustName(C00001) = ACME TRADING CO.`)。
  - 実物の3手続き版(`countCustOrders`込み)を、依然`EXPORT(*ALL)`のまま再構築したところ、**同じ`F0702A`を再コンパイルせずに`CALL`すると`MCH4431: Program signature violation.`(`Error found on CALL command.`を伴う)で失敗した。**
  - `EXPORT(*SRCFILE)`(`PGMLVL(*CURRENT)`=3シンボル・`PGMLVL(*PRV)`=元の2シンボルと同じ順序のバインダー・ソース)へ`CRTSRVPGM`で切り替え、続けて同じ設定で`UPDSRVPGM`も実行(`Service program JUCSRV in <lib> updated.`)したところ、**同じ`F0702A`を依然再コンパイルせずに`CALL`すると成功した**(`F0702A: getCustName(C00001) = ACME TRADING CO.`)。`PGMLVL(*PRV)`の2シンボル署名が、`EXPORT(*ALL)`がこの2手続きに対して計算していた署名と一致したことになります。
  - `F0703A`(新規コンパイル、`countCustOrders`使用)も成功し、同じ`CALL`の中で`countCustOrders(C00001)`を2回連続呼んだ結果は両方とも`2`で一致(`MATCH - both calls agree; JUCHUM repositioning is correct.`)——`JUCHUM`の再配置ロジックが正しく効いていることを確認しました。
- **1回目の接続では、意図した「2手続きだけの新規ベースライン」を作れませんでした。** 検証専用に用意した使い捨ての2手続きモジュール(このレッスンの本文には登場しない、検証だけのための一時ファイル)で、`countCustOrders`を取り除く際`dcl-f juchum ... usropn;`の行だけ消し忘れるという実バグがあり、07-02の実演・手順3で説明したのと同じ組み合わせ(`open`の無い`usropn`ファイル)で`RNF7062`(severity 30)によりコンパイルが失敗しました。この結果、`JUCSRV`(`*SRVPGM`)はこの使い捨てモジュールではなく、**既存の(以前の接続から残っていた)3手続きのモジュールから`EXPORT(*ALL)`で再作成**され、`F0702A`は最初から3手続き分の(アルファベット順の)シグネチャーにバインドされました。**この`F0702A`は、`EXPORT(*ALL)`のままモジュールを再作成しても壊れませんでしたが、この3手続きをそのまま宣言順で書いた`PGMLVL(*CURRENT)`ブロック(`getCustName`・`pingJucsrv`・`countCustOrders`、本文と同じ内容)へ切り替えた直後に`MCH4431: Program signature violation.`で壊れました。** これは、上の「説明」節で述べた「`EXPORT(*ALL)`はアルファベット順・バインダー言語は書いた順序」という規則どおりの結果です——宣言順(`getCustName`・`pingJucsrv`・`countCustOrders`)とアルファベット順(`countCustOrders`・`getCustName`・`pingJucsrv`)が3つとも一致しないため、同じ3つの名前でも違うシグネチャーになったと考えられます。2回目の接続で使い捨てモジュールの不備を直し、本文どおりの完全なシナリオ(2手続きベースライン→壊す→直す)を意図した順序で確認しました。
- **`F0703A`が`countCustOrders`を同一活動化グループから2回連続呼んで一致する、という結果は2つの接続で確認済みです**: `part07-0203-srvpgm`(確認日2026-09-27、`JUCSRV`の最終状態=3手続き・`EXPORT(*SRCFILE)`から直接検証)と、上記`part07-03-signature`(確認日2026-09-28、`EXPORT(*ALL)`から署名違反を経て切り替えた後の状態から検証)の両方で、`countCustOrders(C00001)`は2回とも`2`を返しています。
- `CRTRPGMOD`は、`pingJucsrv`追加時・`countCustOrders`追加時のいずれも、Highest Severity 10(`RNF7534`: 「非サイクル・モジュールでは`TOKUIM`を明示的にクローズすべき」という助言のみ)で成功すること(V1)を確認済みです(07-02で確認済みの`TOKUIM`分と同じ助言で、`JUCHUM`の方は`countCustOrders`内で明示的に`close`しているため、この助言の対象になっていません)。
- **`countCustOrders`から`close juchum; open juchum;`(および末尾の`close juchum;`)を取り除いた場合に本当に`call 2`が`0`になるか(演習3)は、このレッスンでは実機確認していません。** 一次資料(ILE RPG言語リファレンス)の記述からの推論にとどまります。
- `DSPSRVPGM`(既定の`DETAIL`、手続き一覧)と`DSPSRVPGM DETAIL(*SIGNATURE)`(シグネチャーの値)は、`part07-0203-srvpgm`(確認日2026-09-27)で`OUTPUT(*PRINT)`を使い、同じバインダー・ソースから作った状態の`JUCSRV`について、接続の生ログ(run section)に出た印刷内容を読んで確認済みです(V2)。手続き一覧は`getCustName`・`pingJucsrv`・`countCustOrders`の3件、シグネチャー数は2件でした。演習2で5250から対話的に画面を操作して自分の目で確認する作業そのものはV3です。
- 依存するプローブ`P26`(`CRTSRVPGM`・`CRTBNDDIR`等)のうち、本レッスンの範囲(バインダー言語によるバインダー・ソース作成、`CRTSRVPGM EXPORT(*SRCFILE)`への切替、`UPDSRVPGM`)は上記のとおり実機確認済みです。ただし、上の「説明」節で述べたとおり、「`CRTSRVPGM`をやり直さず`UPDSRVPGM`だけで新しい手続きを追加する」という運用そのものと、`RTVBNDSRC`は単独では確認できていません。`P38`(メッセージIDの系統的な一括採取)は、[付録B](../appendix/b-message-ids.md)自身が明記するとおりこの教材全体でまだ一度も実施されていません(`MCH4431`・`CPC5D15`など個別のメッセージIDはこのレッスン内で確認済みですが、それはP38という網羅的な採取プローブとは別物です)。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
