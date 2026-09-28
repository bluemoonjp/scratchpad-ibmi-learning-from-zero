# 06-11b RPG IV の保守画面(追加・変更・削除、排他制御込み)

> 所要時間: 90分(長め)/ 前提レッスン: 06-11 / 目標番号: 5 / 観測方法: 画面そのもの / 道具: SSH(`CPYFRMSTMF` でのソース取り込み)、5250(コンパイル・実行、画面確認)/ 同時接続数: 5250×1(演習で別セッションからのロック競合を試す場合は5250×2)/ 作る・変えるオブジェクト: `<USER>1/D0611BA`(DSPF)・`<USER>1/F0611BA`(RPG)。演習は共有テーブル`SHOHIM`(商品マスター、6件)の中身も書き換える(要`TXRESET`)/ DBVER: 1 / 依存するプローブ: P43(ロック診断、`part06-p43-lockdiag`で実機確認済み——非対話SBMJOB代替によるV2確認、2セッションの5250自体(演習5)はV3のまま) / PTF 依存: なし / 容量の目安: わずか

## ゴール

- `CHAIN` を「更新目的」で開き(`usage(*update : *delete : *output)`)、排他ロックの「掴む→確認→書く→離す」という手順を実装できる。
- `chain(e)` + `%error`/`%status` で、「他のセッションがロック中」と「該当行が無い」を正しく区別できる。
- 一覧から選んだ行を、追加(`write`)・変更(`update`)・削除(`delete`、確認画面つき)できる保守画面を書ける。

## ウォームアップ

<details><summary>前回の復習(06-11)</summary>

1. サブファイルの「load-all」方式と「ページ単位」方式は、何が違いますか?
2. `%EOF`/`%FOUND` をサブファイルに対して使うとき、実際に渡す引数は何の名前ですか?(レコード様式名ではありません)

答え: 1. load-allは、対象の全件を最初に一度で読み込んでサブファイルへ流し込む単純な方式です。ページ単位は、その発展形として、画面1ページぶん(RPG側の定数`PAGESIZE`で指定した件数)だけをその都度読み込みます。件数が多いときの負荷を抑えるための最適化です(`SFLPAG`はDDS側で画面に見せる件数を決めるだけの別の値で、06-11の演習2が指摘するとおり`PAGESIZE`とはたまたま同じ数字になっているだけです)。 2. 表示装置ファイルの名前です(サブファイルのレコード様式名ではありません)。これを取り違えると `RNF0391`/`RNF0394`(「Parameter ... is not valid for built-in function %EOF/%FOUND」)になります。

</details>

## なぜ学ぶか

**06-11の一覧画面は、読み取り専用でした。** `CHAIN`・`READC` で読むだけで、データベースの中身は一切書き換えません。ここで初めて、対話画面から実際にデータベースを追加・変更・削除します。04-09(`R0409A`、`ZAHIK3`)で学んだ「`CHAIN` してから `UPDAT` する、その前後はロックで守る」という考え方を、画面版として組み立て直します。

画面版ならではの新しい事情があります。**04-09はロックを取ってから書き込むまでの間、プログラムが自分で計算するだけでした(一瞬です)。この画面では、ロックを取ってから書き込むまでの間に、`EXFMT` で人間の入力を待ちます。** その間、他のセッションが同じ行を触ろうとしたらどうなるか——これがこのレッスンの中心の問いです。

## 新出

- 中核概念:
  1. 保守画面は、06-11の一覧(読み取り専用)と違い、`CHAIN` を更新目的(`usage` に `*update`/`*delete` を含める)で開く必要がある。
  2. 排他ロックは「掴む(`CHAIN`)→確認(`%error`/`%status`)→書く(`update`/`delete`)→(書かなかった場合は明示的に)離す(`unlock`)」という手順が必須(04-09の`CHAIN`→`UPDAT`パターンの画面版)。
  3. 削除は物理的にレコードが消える不可逆操作なので、専用の確認画面(F12で取消し)を挟む。
- 構文:
  - `usage(*update : *delete : *output)`(更新・削除・追加をまとめて許可するファイル宣言)
  - `chain(e)` + `%error`/`%status`(ロック競合を判定する。`e` を付けないと、ロック中の行への`CHAIN`は未監視の例外になる)
  - `update`(`CHAIN`したレコードを書き換える)
  - `delete`(レコードを削除する。`**FREE`では削除する意図を`usage(*delete)`で明示する必要がある)
  - `write`(新しいレコードを追加する)
  - `unlock`(`CHAIN`で掴んだのに`update`/`delete`を行わずに終わる経路で、ロックを明示的に手放す)
- 読解できれば十分な(新出扱いしない)技法: `reloadSfl2`内の`chain rrn2 sfl2;`/`update sfl2;`(相対レコード番号でサブファイルの1行を直接`CHAIN`・`UPDATE`し、`SFLCLR`を使わずに再構築する技法)。`CHAIN`/`UPDATE`という命令自体は上の構文ですでに扱っているので、ここでは「対象がサブファイルで、キーの代わりに相対レコード番号を使う」という応用として読めれば十分です。

## 説明

### `SHOHIM`(商品マスター)を更新目的で開く

06-11の一覧は `dcl-f shohim disk keyed;` のような読み取り専用の宣言で足りました。この画面は追加・変更・削除をするので、宣言に`usage`が要ります。

```rpgle
dcl-f d0611ba workstn sfile(sfl2:rrn2);
dcl-f shohim disk usage(*update : *delete : *output) keyed;

dcl-s rrn2   packed(4:0) inz(0);
dcl-s maxRrn packed(4:0) inz(0);
dcl-s savedShocd char(6);
```

`*update`(`CHAIN`後に`update`できる)・`*delete`(`delete`できる)・`*output`(`write`で追加できる)の3つをまとめて許可しています。一次資料(ILE RPG言語リファレンス)の固定形式↔自由形式対応表(RPG IV自身の固定形式のファイル指定欄についての表)によれば、これはファイル種別`U`(更新)にファイル追加(`A`)が組み合わさった形の自由形式版にあたります(RPG IIIのF仕様書でも同じ`U`をファイル種別欄に置く形に相当しますが、桁位置はRPG IVとは異なります。06-01bで確認したとおりです)。**`delete`を使うには`usage(*delete)`を明示する必要がある**(自由形式では暗黙に許可されません)、という点も一次資料の記述どおりです。

`SHOHIM`側は`db/v1/shohim.pf`のレコード様式名が`SHOHIR`です。**`CHAIN`はファイル名(`shohim`)を対象にします。`write`/`update`はレコード様式名(`shohir`)が必須です**(一次資料: `UPDATE`の説明に「外部記述ファイルではレコード様式名が required」と明記されています)。**`delete`はレコード様式名・ファイル名のどちらを指定しても有効ですが**、このプログラムでは`write`/`update`と揃えてレコード様式名(`shohir`)を使っています。06-11で確認した「`%EOF`/`%FOUND`はファイル名」というルールとは別の使い分けなので混同しないでください。

### 排他ロックの手順: 掴む→確認→書く→離す

04-09の`R0409A`は`CHAIN`(ロックが掛かる)→`UPDAT`(書き込むと自動的にロックが外れる)という単純な流れでした。この画面はさらに、「`CHAIN`したあと`EXFMT`で人の入力を待つ」という時間のかかる区間が挟まります。その間、他のセッションが同じ行を`CHAIN`しようとすると、そちらは行が空くまで待たされる**はずです**(これ自体は一次資料に明記されている一般的な仕様ですが、待たされたあと静かに成功する、という部分は2セッションでの実際の確認記録がまだなく、V3・未確認のままです。待たされる時間の長さはファイル/ジョブのレコード待ち時間の設定によって決まるため、演習5を試すときに一瞬で終わるか少し待たされるかは環境によって変わります)。**待ち時間を超えた場合に`%STATUS(shohim)`が実際に`1218`を返すこと自体は、`part06-p43-lockdiag`で実機確認済みです**(確認日2026-09-28、`docs/probes.md`参照——非対話のSBMJOBによる別ジョブとの競合を、`OVRDBF WAITRCD(5)`で待ち時間を短く切ったうえで検証したもので、実際の5250×2セッションでの対話的な待ち・両方の確認ではありません)。一次資料(ILE RPG言語リファレンス)のCHAIN/UPDATEの説明によれば、`CHAIN`(操作拡張子なし)で更新用ファイルを読むとそのレコードがロックされます。**`UPDATE`または`DELETE`が成功すると自動的に解放される、という部分は、ILE RPG言語リファレンスではなくILE RPGプログラマーズ・ガイドの「Record Locking」節に明記されています。** ロックしたのに`UPDATE`/`DELETE`を行わずに終わる経路(F12でキャンセルした場合など)では、`UNLOCK`で明示的に解放しない限りロックが残ってしまいます。

**問題は、`CHAIN`だけでは「該当行が無い」と「他のセッションがロック中」を区別できないことです。** どちらも`%FOUND`はオフのままです。これを区別するのが`chain(e)`(操作拡張子`E`)です。`E`を付けないと、ロック中の行への`CHAIN`は未監視の例外としてプログラムを終了させかねません。`E`を付けると、例外の代わりに`%ERROR`がオンになり、`%STATUS`にファイル状況コードが入ります。ロック競合のときの状況コードは`1218`(レコード・ロック・エラー)です。変更(`OPT '2'`)の実際のコードは次のとおりです。

```rpgle
when opt = '2';
  savedShocd = shocd;
  chain(e) savedShocd shohim;
  if %error and %status(shohim) = 1218;
    statmsg = 'RECORD LOCKED BY ANOTHER SESSION - try again later.';
  elseif %found(shohim);
    modetxt = 'CHANGE';
    exfmt dtlfmt;

    if not *in12;
      shocd = savedShocd;
      update shohir;
      statmsg = 'PRODUCT UPDATED.';
      reloadSfl2();
    else;
      unlock shohim;
      statmsg = 'CHANGE CANCELED.';
    endif;
  else;
    statmsg = 'RECORD NOT FOUND - list refreshed, try again.';
    reloadSfl2();
  endif;
```

3つの分岐が並んでいる点に注意してください。**`%error and %status(shohim) = 1218`(ロック競合)→`%found(shohim)`(見つかった、これから編集)→どちらでもない(見つからない、他が消したか一覧が古い)** の順で確認しています。ロック競合のときは`CHAIN`自体が失敗しているのでロックは何も掴んでおらず、`UNLOCK`は不要です。見つかった場合は`EXFMT`で入力を待ち、F12でキャンセルされたら`UNLOCK`で明示的に手放します(保存した場合は`UPDATE`自体がロックを解放します)。

追加(F6)にも同じ`chain(e)`の型が出てきますが、こちらは「更新のため」ではなく「重複コードが無いことの確認のため」に使っています。

```rpgle
if not *in12;
  chain(e) shocd shohim;
  if %error and %status(shohim) = 1218;
    statmsg = 'DUPLICATE CHECK: RECORD LOCKED BY ANOTHER SESSION.';
  elseif %found(shohim);
    unlock shohim;
    statmsg = 'PRODUCT CODE ALREADY EXISTS - NOT ADDED.';
  else;
    write shohir;
    statmsg = 'PRODUCT ADDED.';
    reloadSfl2();
  endif;
else;
  statmsg = 'ADD CANCELED.';
endif;
```

ここでも「見つかった(＝重複)」場合は、この`CHAIN`が意図せず掴んでしまったロックを`UNLOCK`で必ず手放しています。プログラムがこの行を更新するつもりが無くても、`CHAIN`が実際にレコードを取得した以上、ロックは自動的に掛かってしまう(一次資料の記述どおり)ため、後始末が要ります。

### 削除は確認画面を挟む

削除(`OPT '4'`)は、変更と同じ`chain(e)`判定のあと、`DLTCONFFMT`という専用の確認画面を`EXFMT`します。この画面には入力欄が無く、商品コードと商品名を表示するだけです。**削除の`CHAIN`(とそのロック)は、確認画面を出す前に済ませています。** つまり確認画面が出ている間じゅう、その行は他のセッションからロックされたままです。F12でキャンセルすれば`UNLOCK`、Enterで確定すれば`DELETE`(成功すればロックは自動的に外れます)。

```rpgle
when opt = '4';
  savedShocd = shocd;
  chain(e) savedShocd shohim;
  if %error and %status(shohim) = 1218;
    statmsg = 'RECORD LOCKED BY ANOTHER SESSION - try again later.';
  elseif %found(shohim);
    exfmt dltconffmt;

    if not *in12;
      delete shohir;
      statmsg = 'PRODUCT DELETED.';
      reloadSfl2();
    else;
      unlock shohim;
      statmsg = 'DELETE CANCELED.';
    endif;
  else;
    statmsg = 'RECORD NOT FOUND - list refreshed, try again.';
    reloadSfl2();
  endif;
```

対応するDDS(`DTLFMT`・`DLTCONFFMT`。ヘッダーの説明コメントは省略しています)は次のとおりです。

```text
....+....1....+....2....+....3....+....4....+....5....+....6....+....7....+....8
     A          R DTLFMT
     A                                      CF12(12)
     A            MODETXT       10A  O  1  2
     A                                  3  2'Code:'
     A            SHOCD          6A  B  3 10
     A                                  5  2'Name:'
     A            SHONM         30A  B  5 10
     A                                  7  2'Unit price:'
     A            SHOTNK         7S 2O  7 15
     A                                  9  2'Reorder point:'
     A            SHOHAT         5S 0B  9 17
     A                                 12  2'Enter=Save   F12=Cancel'
     A          R DLTCONFFMT
     A                                      CF12(12)
     A                                  1  2'Delete this product?'
     A                                  3  2'Code:'
     A            SHOCD          6A  O  3 10
     A                                  5  2'Name:'
     A            SHONM         30A  O  5 10
     A                                  8  2'Enter=Confirm delete   F12=Cancel'
```

`DLTCONFFMT`の`SHOCD`/`SHONM`はどちらも`O`(出力専用)です。表示するだけで編集させないので、次に説明するキー保護の心配自体がありません。

### `SHOCD`(商品コード)のキー保護

`DTLFMT`の`SHOCD`は、38桁目が`B`(入力・出力)です。追加モードでは新しいコードを入力させる必要があるのでこれは自然ですが、**変更モードでも同じ欄が入力可能なままです。** DDS側にはこの2つのモードを条件付ける標識を使っていない(このファイル全体の設計方針、後述)ため、DDSだけでは「変更モードのときだけ`SHOCD`を出力専用にする」ことができません。

その代わり、RPG側で保護しています。変更モードに入る前に選択行のコードを`savedShocd`へ退避し、`UPDATE`の直前に**画面の内容に関わらず**`shocd`をその退避値へ書き戻しています(上のコード例の`shocd = savedShocd;`の行)。つまり変更画面で`SHOCD`欄に別の値を打ってEnterを押しても、実際に更新されるキーは元の値のままです。

### `SHOTNK`(単価)はゾーン10進の出力専用フィールド

`SHOHIM`の`SHOTNK`(単価)は`db/v1/shohim.pf`で`7S 2`(7桁・小数2桁)と宣言されています。DDSの数値型`S`はゾーン10進を表します(`P`のパック10進とは別の型です)。

`DTLFMT`の`SHOTNK`は38桁目が`O`(出力専用)で、`B`(入力可能)の`SHONM`・`SHOHAT`とは違います。編集対象は商品名(`SHONM`)と発注点(`SHOHAT`)だけで、単価はこの画面では変更できません。追加(F6)したばかりの商品の`SHOTNK`は常に`0`です(RPG側の追加分岐が`shotnk = 0;`を代入しています)。これはバグではなく、この画面の意図的な範囲(単価そのものを設定・変更する手段は、このレッスンの画面には無い)です。

編集コード(`EDTCDE`)も付けていないため、一覧(`SFL2`)の価格欄には、小数点も桁区切りも付かない生の数字が並ぶ**はず**です。06-04の`ORDDT`(編集コード無しの日付欄)が`00000000`と表示される**はず**だった、というのと同じ理屈です(06-04自身もこの表示はV3・実機未確認のままです)。たとえば商品`P00001`の単価`1580.00`は、`0158000`(7桁、小数点なし)という表示になる**はず**です(実際の画面表示は次の「実演」で述べるとおりV3・未確認です)。発注点(`SHOHAT`、5桁0小数)も同様に、`20`は`00020`と表示される**はず**です。

### DDSに条件付け標識を使わない方針と、`SFLCLR`を使わない再構築

このDDS全体は、06-11の`D0611A`と同じ方針で、条件付け標識(7〜16桁目)を一切使っていません。そのため`SFLDSP`/`SFLDSPCTL`は常時オンで、`MODETXT`(追加中/変更中の表示)のような画面上の切り替えは、DDS側の標識ではなくRPG側で`modetxt = 'ADD';`/`modetxt = 'CHANGE';`のように普通の出力フィールドへ代入する形で実現しています。

サブファイルの再表示にも`SFLCLR`を使いません。追加・変更・削除のたびに呼ばれる`reloadSfl2`は、`SHOHIM`を`CLOSE`/`OPEN`で先頭に巻き戻してから全件を読み直し、相対レコード番号(`RRN2`)ごとに`CHAIN`→見つかれば`UPDATE`・無ければ`WRITE`という形でサブファイルの中身をその場で書き換えます。削除で行数が減った場合は、以前使っていて今は要らなくなった`RRN`について、文字項目(`OPT`/`SHOCD`/`SHONM`)を空白、数値項目(`SHOTNK`/`SHOHAT`)をゼロに戻しています。`SHOTNK`/`SHOHAT`は編集コード無しの数値項目(前述)なので、この行は見た目上完全な空欄にはならず、`0000000`/`00000`という数字が残る**はず**です。

```rpgle
dcl-proc reloadSfl2;
  dcl-pi *n;
  end-pi;

  dcl-s r packed(4:0) inz(0);
  dcl-s fillRrn packed(4:0);

  close shohim;
  open shohim;

  read shohim;
  dow not %eof(shohim);
    r += 1;
    rrn2 = r;
    opt = *blanks;
    chain rrn2 sfl2;
    if %found(d0611ba);
      update sfl2;
    else;
      write sfl2;
    endif;
    read shohim;
  enddo;

  if r < maxRrn;
    fillRrn = r + 1;
    dow fillRrn <= maxRrn;
      chain fillRrn sfl2;
      if %found(d0611ba);
        opt = *blanks;
        shocd = *blanks;
        shonm = *blanks;
        shotnk = 0;
        shohat = 0;
        update sfl2;
      endif;
      fillRrn += 1;
    enddo;
  endif;

  if r > maxRrn;
    maxRrn = r;
  endif;
end-proc;
```

**この`opt = *blanks;`には、見落としやすい副作用があります。** `reloadSfl2`は、呼ばれた時点で存在する全行の`OPT`を無条件に空欄へ戻します。ただし`reloadSfl2`が呼ばれるのは、`UPDATE`/`DELETE`が成功した場合と、`RECORD NOT FOUND`(該当行なし)の場合だけです。**ロック競合(状況コード`1218`)・F12でのキャンセル・不正な`OPT`値(`other`分岐)では`reloadSfl2`を呼ばずに`statmsg`だけ設定して次の`READC`へ進むため、これらの経路では他の行の`OPT`はクリアされません。** つまり、一覧の複数行に`2`や`4`を入れてからEnterを1回押した場合、**最初に処理された行が保存・削除確定・該当なしのいずれかで終われば**他の行の`OPT`も一緒に消えて先頭の1行だけが処理された形になりますが、**最初の行でロック競合やキャンセルが起きた場合は`OPT`が残るため、続けて次の行も同じEnterの流れの中で処理されます。** この一連の動作そのものは、この教材ではV3・実機未確認です。複数行をまとめて処理したいときは、この違いを踏まえたうえで、基本的には1行ずつEnterを押し直すことを勧めます。

## 実演

**この実演で作る2つのオブジェクト(`D0611BA`・`F0611BA`)は、著者による実機コンパイル(V1、下の「実機メモ」参照)まで確認済みです。対話的な実行(`EXFMT`で実際に画面が出て、追加・変更・削除やロックが実際に働くところ)は、この教材の検証ハーネス(非対話SSH)では確認できません。学習者自身の5250セッションで確認してください。**

1. SSHで接続し、`~/ibmi-kyozai`を最新にする(`git pull`)。

2. ソースを取り込む(1回の接続でまとめて行います)。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qddssrc/d0611bs.dspf') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QDDSSRC.FILE/D0611BA.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/f0611bs.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/F0611BA.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

3. 5250に戻り、コンパイルする。

   ```text
   CRTDSPF FILE(<自分のユーザー名>1/D0611BA) SRCFILE(<自分のユーザー名>1/QDDSSRC) SRCMBR(D0611BA)
   CRTBNDRPG PGM(<自分のユーザー名>1/F0611BA) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(F0611BA)
   ```

   どちらも Highest Severity 00 になることを確認してください。

4. `CALL PGM(<自分のユーザー名>1/F0611BA)`を実行する。一覧(`SFL2`)に商品6件(`P00001`〜`P00006`)が表示されることを確認してください。

5. 1件を選び`OPT`欄に`2`を入れてEnterを押す。`DTLFMT`が「CHANGE」モードで表示され、商品名または発注点を書き換えて保存(Enter)する。一覧に戻ったとき、変更後の内容が反映されていることを確認する。単価(`SHOTNK`)の欄には入力できないことも確認する。

6. 別の1件の`OPT`欄に`4`を入れてEnterを押す。削除確認画面が出ることを確認し、いったんF12でキャンセルして一覧に戻ることを確認する。もう一度`4`を入れ、今度はEnterで確定し、その行が一覧から消えることを確認する。

7. F6を押し、新しい商品コードで1件追加する。一覧に追加され、単価欄が`0`相当(編集コード無しの生の数字)で表示されることを確認する。

## 演習

1. 変更モードで`SHOCD`欄に別の商品コードを入力してからEnterを押しても、実際に更新されるのは選択した行の元のコードのままであることを確認してください(「説明」の`savedShocd`の技法を根拠に、理由を自分の言葉で説明できるようにしてください)。
2. すでにある商品コード(例: `P00001`)をF6の追加で入力してみてください。`PRODUCT CODE ALREADY EXISTS - NOT ADDED.`というメッセージが出て、追加されないことを確認してください。
3. `STATMSG`はDDSで`40A`(40桁)と宣言されています。`f0611bs.rpgle`が`statmsg`へ代入している文字定数を実際に数えてみてください。`DUPLICATE CHECK: RECORD LOCKED BY ANOTHER SESSION.`(50桁)・`RECORD LOCKED BY ANOTHER SESSION - try again later.`(51桁)・`RECORD NOT FOUND - list refreshed, try again.`(45桁)・`INVALID OPTION - use 2=Change or 4=Delete.`(42桁)の4つは、いずれも40桁を超えています。RPGは代入先より長い文字定数を、収まる範囲(先頭40桁)までで黙って切り詰めます。実際の画面には、たとえば`RECORD LOCKED BY ANOTHER SESSION - try a`のように、末尾が途中で切れた形で表示される**はずです**(実機の画面表示そのものはV3・未確認)。
4. 一覧の2行に`OPT`欄`2`/`4`をそれぞれ入れてから、Enterを1回だけ押してください。「説明」で述べたとおり、**最初に処理された行が保存・削除確定・該当なしのいずれかで終わった場合は**、他の行の`OPT`も一緒に消えて先頭の1行だけが処理された形になる**はず**です。逆に最初の行でロック競合やF12キャンセルが起きた場合は、`OPT`が残ったまま次の行も同じEnterの流れの中で処理される**はず**です。予想してから実際に試してください(V3・未確認)。
5. (発展・V3、このリポジトリーではまだ誰も試していません)もう1つ5250セッションを開けるようなら、片方のセッションで`2`(変更)を選び`DTLFMT`を表示させたまま(=ロックを保持したまま)、もう片方のセッションで同じ商品コードの行を`2`または`4`で操作してみてください。`RECORD LOCKED BY ANOTHER SESSION - try a`(または追加時は`DUPLICATE CHECK: RECORD LOCKED BY ANOTHE`の方。どちらも演習3で確認した、40桁での切り詰めが掛かった形です)が表示される**はず**です(V3・未確認)。**1つのPUB400アカウントで実際に2つの5250セッションを同時に開けるかどうか自体、このリポジトリーではまだ確認していません。**

   うまく2セッション目を開けない場合、`DTLFMT`を表示させたままのセッションは`EXFMT`の入力待ちでブロックされておりコマンド行が使えないため、ロックを保持したまま同じジョブで別のコマンドを動かすには、システム要求(Sys Reqキー)で同じジョブに割り込むか、それが使えなければ`WRKOBJLCK`/`DSPRCDLCK`専用にもう1つ別のジョブ(別セッション、または別のサインオンによる対話ジョブ)を用意する必要があります。そのうえで`WRKOBJLCK OBJ(<自分のユーザー名>1/SHOHIM) OBJTYPE(*FILE)`(ファイル単位のロック一覧)と`DSPRCDLCK`(個々のレコード・ロック)を確認すれば、レコード・ロックが実際に存在することを見られる**はず**です。**この`WRKOBJLCK`/`DSPRCDLCK`の組み合わせがロック保持中に実際にロックを表示することは、`part06-p43-lockdiag`で実機確認済みです**(確認日2026-09-28、`docs/probes.md`参照——`WRKOBJLCK`は`*SHRRD`(オブジェクト)・`*SHRUPD`(メンバー・データ)、`DSPRCDLCK`は該当レコード番号を`HELD`・タイプ`UPDATE`で表示した)。ただし、これは5250の対話セッションではなく非対話のSBMJOBで確認したものであり、この演習5自体(実際に2つの5250セッションを開いての確認)はこのリポジトリーではまだ未確認(V3)のままです。
6. 演習をひととおり終えたら、必ず`<自分のユーザー名>1/TXRESET`を実行し、`SHOHIM`を初期状態(6件)に戻してください。

## セルフチェック

- [ ] `usage(*update : *delete : *output)`が、追加・変更・削除それぞれのどの操作に対応するか説明できる。
- [ ] 排他ロックの「掴む→確認→書く→離す」の手順と、`chain(e)`+`%error`/`%status(1218)`が「ロック競合」と「該当行が無い」をどう区別するか説明できる。
- [ ] 削除確認画面(`DLTCONFFMT`)を挟む理由と、キャンセル時に`UNLOCK`が必要な理由を説明できる。
- [ ] `SHOTNK`が`DTLFMT`で出力専用(`O`)である理由と、この画面で編集対象になるのが`SHONM`/`SHOHAT`に限られる理由を説明できる。
- [ ] 追加・変更・削除の3操作を実際に5250で確認した(V3)。
- [ ] 演習後、`TXRESET`で`SHOHIM`を元に戻した。

## 片付け

`D0611BA`・`F0611BA`はそのまま残してください。**ただし演習は共有テーブル`SHOHIM`(商品マスター)の中身を直接書き換えます。** `SHOHIM`は04-13(商品別在庫一覧表)・06-07の演習・06-15のチェックポイントが、いずれも初期値(`P00001`〜`P00006`、`db/data/load_v1.sql`のとおりの商品名・単価・発注点)を前提にしています。演習で追加・変更・削除を試したら、他のどのレッスンより先に**必ず**`<自分のユーザー名>1/TXRESET`を実行し、`SHOHIM`を初期状態へ戻してください。QTEMP上に複製を作って作業する代替手段はこのレッスンでは使いません(演習5のロック競合確認は、別セッションから同じ行が見えている必要があり、ジョブ固有のQTEMPでは成立しないためです)。共有`SHOHIM`を直接操作し、終わったら必ず`TXRESET`で戻す、というのがこの画面の安全策そのものです。

## まとめ

| 英語 | 日本語 |
|---|---|
| Exclusive lock / Record lock | 排他ロック / レコード・ロック |
| Lock conflict | ロック競合 |
| Zoned decimal | ゾーン10進 |
| Confirmation screen | 確認画面 |
| Duplicate check | 重複チェック |

次のレッスン(06-12)では、印刷装置ファイル(PRTF)で帳票を出し、`JUCINQ`コマンドのCPPを初めて差し替えます。

## 実機メモ

- 確認日: 2026-09-26。`part06-screens-compile`という接続(第6部の画面/サブファイル系レッスンをまとめて検証する接続)の1回目で、`D0611BA`(`CRTDSPF`)はHighest Severity 00でコンパイルに成功しました。同じ接続の`F0611BA`(`CRTBNDRPG`)は、このレッスン固有の内容とは無関係な別の実バグ(`%EOF`/`%FOUND`にサブファイルのレコード様式名`sfl2`を渡していた。正しくは表示装置ファイル名`d0611ba`。`RNF0391`/`RNF0394`で確認)で1回目は失敗し、修正後の2回目の接続でHighest Severity 00でのコンパイル成功を確認しました(CONFIRMED SUCCESS)。
- 確認日: 2026-09-27。`part06-decisions-1`という接続で、`SHOTNK`の出力専用化(ゾーン10進、`7S 2O`)と、`chain(e)`+`%error`/`%status(1218)`によるロック競合のエラー処理を追加した版の`D0611BA`・`F0611BA`を再コンパイルし、両方ともHighest Severity 00で成功したことを確認しました。**これらはいずれもV1(コンパイルのみ)です。** 同じ接続の生ログ(Message Summary)には、記録されている個別のメッセージIDが`*RNF7031`(`*IN25`/`*IN26`未参照、情報レベル)の2件だけで、Additional Diagnostic Messagesの節も空でした。つまり、実機コンパイルがHighest Severity 00だったという記録に加えて、上の演習3で述べた文字定数の桁あふれについては、コンパイラーが診断メッセージを一切出していないことを確認済みです(RPGは超過分を黙って先頭40桁に切り詰めるだけで、これ自体はコンパイル時の警告にはなりません)。
- **対話実行(`EXFMT`、F6/2/4による追加・変更・削除)は、この非対話SSHハーネスでは確認できません。すべてV3で、学習者自身の5250セッションでの確認が必要です。** ただし`CHAIN`による実際のロック取得、`WRKOBJLCK`/`DSPRCDLCK`でのロック観察という下地の仕組み自体は、`part06-p43-lockdiag`(確認日2026-09-28)で、非対話のSBMJOBによる別ジョブとの競合を使って実機確認済みです(`docs/probes.md`参照)。`chain(e)`+`%error`+`%status(shohim)=1218`という判定ロジックが実際に別ジョブとの競合を正しく検出すること、`WRKOBJLCK`/`DSPRCDLCK`が保持中のロックを正しく表示することの両方を確認できています。**ロックの解放については、ロックを保持していたジョブが終了した時点で消えることだけを確認しました**——このレッスンの`UNLOCK`(F12キャンセル経路)や`UPDATE`/`DELETE`成功時の自動解放は、P43では検証していません(`T643HOLD`は`chain(e)`のみで`UPDATE`/`UNLOCK`を一切呼ばない設計のため)。
- **2セッションでの排他ロック競合の観測(演習5そのもの)は、このリポジトリーのどのレッスンでも実機で試された記録がまだありません。** さらに、1つのPUB400アカウントで実際に2つの5250セッションを同時に開けるかどうかという前提自体も、まだ確認していません。演習5は学習者にとって(そしてこの教材にとって)初めての試みになります——ただし上記のとおり、演習5が観察しようとしている現象そのもの(別ジョブとの競合が`1218`として検出され、`WRKOBJLCK`/`DSPRCDLCK`に現れること)は、`part06-p43-lockdiag`という非対話の代替経路で既に裏付けが取れています。
- SHOHIMの初期データ(`P00001`〜`P00006`)は`db/data/load_v1.sql`のとおりです。演習でこのデータを書き換えたら、`TXRESET`で元に戻したことを次回接続で確認してください。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
