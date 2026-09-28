# 07-04 活動化グループとILE CL

> 所要時間: 75分(長め)/ 前提レッスン: 07-03 / 目標番号: 5 / 観測方法: `DSPJOBLOG` / 道具: SSH(`CPYFRMSTMF` でのソース取り込み)、5250(コンパイル・実行・確認)/ 同時接続数: 5250×1(SSHでのソース取り込みは1回の接続でまとめて行います)/ 作る・変えるオブジェクト: `<USER>1/F0704A`(RPG)・`<USER>1/JUYAKL`(CLLE)/ DBVER: 1 / 依存するプローブ: なし / PTF 依存: なし / 容量の目安: わずか

## ゴール

- 活動化グループ(`ACTGRP`)がサブプロシージャーのSTATIC変数の生存期間を左右すること、名前付き活動化グループが`*NEW`と違ってプログラムの正常終了で削除されないこと、`RCLACTGRP`でそれを明示的にリセットできることを、`F0704A`の実演から説明できる。
- `CRTBNDCL`の既定活動化グループ(`DFTACTGRP(*YES)`)では`ACTGRP`を指定できない理由と、`DCLPRCOPT`でサービス・プログラムへの束縛を宣言してから`CALLPRC`で手続きを呼ぶ書き方を、`JUYAKL`(`JUYAKC`のILE CL版)として書ける。
- `DCLPRCOPT`の`BNDSRVPGM(*LIBL/...)`が、07-02の`ADDBNDDIRE OBJ((*LIBL/...))`と同じ「実行時に`*LIBL`から解決させる」原則の別の現れであることを説明できる。

## ウォームアップ

<details><summary>前回の復習(07-03)</summary>

1. `JUCSRV`を`EXPORT(*ALL)`のまま3つ目の手続き(`countCustOrders`)を追加して作り直したとき、まだ再コンパイルしていない既存のクライアント(`F0702A`)を`CALL`すると何が起きましたか?
2. その問題を直すために`JUCSRV`へ追加したバインダー・ソース(`QSRVSRC`)は、既存のクライアントのシグネチャーをどうやって壊さずに済ませましたか?

答え: 1. `Program signature violation.`(実際のメッセージID`MCH4431`)で失敗しました。2. `STRPGMEXP PGMLVL(*CURRENT)`ブロックの末尾に新しい手続きを追加する一方、`PGMLVL(*PRV)`という別ブロックとして、追加前と同じ2つのシンボル(`getCustName`・`pingJucsrv`)を同じ順序でそのまま複製しました。`CRTSRVPGM`(`EXPORT(*SRCFILE)`へ切り替え)→`UPDSRVPGM`に切り替えることで、`F0702A`を再コンパイルせずに動作を復旧できました。

</details>

## なぜ学ぶか

07-01は、活動化グループ(`ACTGRP`)を決めるのが`CRTPGM`コマンド自身であることまでは扱いましたが、その効果を実際に目で見て確認することはできていませんでした(演習2として持ち越しです)。07-02・07-03で動かした`F0702A`・`F0703A`は、いずれも`ctl-opt actgrp(*new)`——`CALL`のたび新しい活動化グループが使い捨てられる設定でした。このレッスンでは初めて**名前付き活動化グループ**を使い、`CALL`をまたいで状態(サブプロシージャーのSTATIC変数)が残ること、そして`RCLACTGRP`でそれを明示的にリセットできることを、`F0704A`で実際に手を動かして確認します。

もう一方の柱は、CLプログラム自身がサービス・プログラムの手続きを直接呼ぶことです。第3部の`JUYAKC`(03-13、夜間バッチの骨格)を`JUYAKL`というILE CL版(`CRTBNDCL`)として書き直し、07-02で作った`JUCSRV`の`getCustName`を`CALLPRC`で呼びます。CLから見ても、サービス・プログラムは「実行時に`*LIBL`から解決される」という07-02の原則がそのまま成り立つことを確認します——`ADDBNDDIRE OBJ((*LIBL/JUCSRV *SRVPGM))`で使ったのと同じ`*LIBL`参照の原則を、今度は`DCLPRCOPT BNDSRVPGM(*LIBL/JUCSRV)`という別の構文で適用します。

このレッスンには、実は独立した3つの概念が絡み合っています——①活動化グループとSTATIC変数の生存期間(`RCLACTGRP`を含む、`F0704A`側の柱そのもの)、②`CRTBNDCL`の既定`DFTACTGRP(*YES)`が`ACTGRP`を禁じるという制約、③`DCLPRCOPT`でサービス・プログラムへの結合先を宣言してから`CALLPRC`で呼ぶという構文、の3つです。次の「新出」ではこの3つを別々の項目として扱います。

## 新出

- 中核概念:
  1. 名前付き活動化グループ(`CRTBNDRPG ... ACTGRP('名前')`)は、`*NEW`(呼び出しのたび新しく作られ、プログラムが戻ると削除される)と違い、**プログラムが正常終了しても削除されません**。同じジョブから同じ名前を指定して`CALL`すると、前回の活動化がそのまま使われ、サブプロシージャーのSTATIC変数は値を保持し続けます。`RCLACTGRP`は、その名前付き活動化グループと静的記憶域を明示的に削除します。
  2. `CRTBNDCL`の既定は`DFTACTGRP(*YES)`で、この既定のままでは`ACTGRP`自体を指定できません。サービス・プログラムの手続きを束縛呼び出しするには`DFTACTGRP(*NO)`が必要です(一次資料からの推論。詳細は下の「説明」)。`JUYAKL`はこれを`CRTBNDCL`コマンド自身にではなく、ソース内の宣言コマンド`DCLPRCOPT`に書きます。
  3. CLソースがサービス・プログラムの手続きを直接呼ぶには、`DCLPRCOPT`の`BNDSRVPGM`パラメーターで結合先を宣言し、`CALLPRC`で呼び出します。`BNDSRVPGM`の対象は`*LIBL`経由で解決でき、07-02の`ADDBNDDIRE`と同じ原則がここでも成り立ちます。
- 構文:
  - `CRTBNDRPG ... ACTGRP('名前')`(名前付き活動化グループ、初出)
  - `RCLACTGRP ACTGRP(名前)`
  - `CRTBNDCL`
  - `DCLPRCOPT DFTACTGRP(*NO) BNDSRVPGM(*LIBL/...)`
  - `CALLPRC PRC('...') PARM(...) RTNVAL(...)`
  - `SUBR`/`ENDSUBR`/`CALLSUBR`

## 説明

### `F0704A`: STATIC変数と活動化グループ

`src/qrpglesrc/f0704s.rpgle`(`F0704A`)は、次の`ctl-opt`で名前付き活動化グループにコンパイルされます。

```rpgle
ctl-opt dftactgrp(*no) actgrp('F0704AG') option(*srcstmt);
```

一次資料(ILE RPG言語リファレンス)によれば、`ACTGRP`キーワードは`*STGMDL`・`*NEW`・`*CALLER`、または引用符付きの活動化グループ名のいずれかを取り、**`CRTBNDRPG`でのみ有効**です。引用符付きで名前を書いた場合、一次資料は「入力したテキストとまったく同じ大文字・小文字になる」「`RCLACTGRP`は小文字を許さない」と説明しています——このファイルが`'f0704ag'`ではなく`'F0704AG'`と大文字で書いているのはこのためです。

中身は、サブプロシージャー内のSTATIC変数だけです。

```rpgle
dcl-proc bumpCounter;
  dcl-pi *n packed(5:0);
  end-pi;

  dcl-s counter packed(5:0) static inz(0);

  counter += 1;
  return counter;
end-proc;
```

一次資料(ILE RPG言語リファレンス)によれば、STATIC変数は「そのプロシージャーを含むプログラム(またはサービス・プログラム)が最初に活動化されたときに初期化され、以後は再初期化されない」ものです。`*inlr = *on`で終了しても、この値は消えません。

呼び出し側の`runCounterDemo`は、**同じ`CALL`の中で**`bumpCounter`を3回呼びます。

```rpgle
for i = 1 to 3;
  v = bumpCounter();
  msgText = 'F0704A: bumpCounter() call #' + %char(i)
              + ' in this invocation returned counter=' + %char(v)
              + ' ...';  // 実際の文字列はここにSTATICキーワードの一次資料参照が続きますが、本文では省略します
  sendToJobLog(msgText);
endfor;
```

これだけなら、STATIC変数がふつうに効いているだけで、活動化グループはまだ関係ありません(1回`CALL`すれば`counter`は1・2・3になります)。**活動化グループが本当に効いてくるのは、別々の`CALL PGM(F0704A)`をまたいだときです。**

### 名前付き活動化グループは`CALL`をまたいで残る

一次資料(ILE Concepts)は、活動化グループの種類によって、プログラムが正常終了したときの扱いが違うと説明しています。

| 活動化グループ | 正常終了(`*INLR=*ON`で`RETURN`)したときの扱い |
|---|---|
| `*NEW`(システム名前付き) | 呼び出しのたびに新しく作られ、プログラムが戻ると**その活動化グループごと削除される** |
| 名前付き(今回の`'F0704AG'`のような) | プログラムが戻っても**削除されない**。次に同じ名前を指定した別の`CALL`が、同じ活動化グループをそのまま使う |

つまり`F0704A`を同じジョブの中で2回`CALL`すると、2回目は1回目と**同じ活動化**の中で動きます。`bumpCounter`のSTATIC変数`counter`は「最初に活動化されたときだけ初期化される」ため、2回目の`CALL`では初期化されず、1回目の続き(4・5・6)から増え続けます。

`RCLACTGRP ACTGRP(F0704AG)`は、この名前付き活動化グループとその静的記憶域を明示的に削除するコマンドです。一次資料(CLコマンド・リファレンス)によれば、`RCLACTGRP`は名前付きで、かつ「使用中でない」活動化グループだけを対象にでき、その活動化グループに含まれるプログラムの静的記憶域を解放します。**活動化グループの中で今も実行中のプログラムがあると削除できない**ため、`F0704A`自身が自分の活動化グループを自分で`RCLACTGRP`することはできません——`F0704A`が一度呼び出し元に戻ったあと、別のステップとして実行する必要があります。削除後にもう一度`CALL`すると、活動化そのものが新しく作り直されるため、STATIC変数は`0`から数え直され、`counter`は1・2・3に戻ります。

**実機で確認できたのは、この名前付き活動化グループの継続・リセットの部分だけです。** `*NEW`(3回とも独立して1・2・3になるはず)・`*CALLER`(名前付き活動化グループと同様、呼び出し元の活動化グループが生きている限り継続するはず)との対比は、一次資料の記述の組み合わせから導いた**推論**であり、この教材ではまだ実機で確認できていません。実際に`F0704A`と同じソースから`*CALLER`版の比較オブジェクトを作ろうとしたところ、想定していなかった別の壁にぶつかりました——次で説明します。

### `CRTRPGMOD`は`ACTGRP`キーワード自体を拒む

`F0704A`の`ctl-opt`にある`actgrp('F0704AG')`は、一次資料(ILE RPG言語リファレンス)が明記するとおり**`CRTBNDRPG`でのみ有効**なキーワードです。同じソースを`CRTRPGMOD`(モジュールだけを作るコマンド)でコンパイルしようとすると、コンパイラー自身が次のように診断します。

```text
RNF1324: Keywords DFTACTGRP, ACTGRP, or USRPRF are not allowed.
Compilation stopped. Severity 20 errors found in program.
```

警告ではなく、**モジュールの作成そのものが失敗します**。この診断は、実際にこの`F0704A`のソースを`CRTRPGMOD`にかけて実機で確認したものです。つまり「`ACTGRP`は`CRTBNDRPG`専用」という一次資料の記述は、単に無視されるのではなく、**モジュール単独のコンパイル自体を止める**という形で効いています。

同じソースから`CRTRPGMOD`(モジュール化)→`CRTPGM ACTGRP(*CALLER)`という2段構成で`*CALLER`版の比較オブジェクトを作る計画は、この最初の`CRTRPGMOD`の段階でブロックされました。`*CALLER`版を作るには、`ctl-opt`から`actgrp(...)`(および`dftactgrp(*no)`)を取り除いた別コピーのソースが必要で、この教材ではまだ用意していません。前節で「推論」と断ったのは、この事情によるものです。

### 名前付き活動化グループはジョブをまたいで残らない

`RCLACTGRP`を、`F0704A`をまだ一度も`CALL`していない新しいジョブの先頭で試すと、次のメッセージになります。

```text
CPF1653: Activation group F0704AG not found.
```

活動化グループは(名前付きであっても)**ジョブごとに作られる**ため、前のジョブで作った`F0704AG`が、別のジョブから見えることはありません。逆に言えば、**前節の継続・リセットの実演は、同じジョブの中で複数回`CALL`しなければ意味を成しません。** 学習者自身の5250セッションでは、一度サインオンしたらそのまま接続を切らずに、この節の手順をすべて実行してください。

### `CRTBNDCL`の既定活動化グループと`DFTACTGRP`

一次資料(CLコマンド・リファレンス)によれば、`CRTBNDCL`の`DFTACTGRP`パラメーターの既定値は`*YES`です。`DFTACTGRP(*YES)`のときに指定できなくなるのは`ACTGRP`だけです。`STGMDL`は別の話で、`*TERASPACE`だけが`DFTACTGRP(*YES)`と同時に指定できず、既定の`STGMDL(*SNGLVL)`はそのまま使えます。一次資料は、`DFTACTGRP(*YES)`のときにできるプログラムは**単一の`*MODULE`だけ**で構成されなければならないとも明記しています。

正直に書いておくと、この一次資料の`DFTACTGRP`注記が名指ししているのは、`DCLPRCOPT`の`BNDDIR`パラメーターで結合先を指定し、かつそのバインディング・ディレクトリー中のモジュールが`CALLPRC`で参照される手続きをエクスポートしている場合です。`JUYAKL`が実際に使う`BNDSRVPGM`(`BNDDIR`ではなく)を名指しして`DFTACTGRP(*NO)`を要求する記述は、この教材が参照している一次資料の抜粋には見当たりません。ここでは、`BNDSRVPGM`経由で`CALLPRC`によりサービス・プログラムの手続きを束縛呼び出しすると、結果は「単一の`*MODULE`だけ」という制約には収まらなくなるはずだ、という一般的な制約からの**推論**として`DFTACTGRP(*NO)`を必須と扱っています。

`JUYAKL`は、この`DFTACTGRP(*NO)`を`CRTBNDCL`コマンド自身にではなく、ソースの中に書く宣言コマンド`DCLPRCOPT`(Declare Processing Options)に書きます。一次資料は、`DCLPRCOPT`で指定した値が、`CRTBNDCL`コマンド行で指定した値・省略時の既定値の**両方に優先する**と明記しています。そのため`JUYAKL`のコンパイル・コマンド自体には`DFTACTGRP`をあらためて書きません(書いても無害ですが冗長です)。

```text
CRTBNDCL PGM(<自分のユーザー名>1/JUYAKL) SRCFILE(<自分のユーザー名>1/QCLSRC) SRCMBR(JUYAKL)
```

`JUYAKL`は`DCLPRCOPT`でも`CRTBNDCL`コマンド行でも`ACTGRP`を指定していません。一次資料によれば`ACTGRP`の既定値は`*STGMDL`で、既定の`STGMDL(*SNGLVL)`のときは共有の`QILE`活動化グループに割り当てられます——`F0704A`が名前付き活動化グループをわざわざ選んだのとは対照的に、`JUYAKL`はごく単純なバッチ・プログラムなので、隔離を必要とせずこの既定のまま使っています。**ただし、`JUYAKL`が実際に`QILE`で動いたこと自体は、この教材ではまだ実機で確認していません**——ここは一次資料の記述からの推論です。

### `DCLPRCOPT`と`CALLPRC`: CLからサービス・プログラムの手続きを直接呼ぶ

一次資料(CLコマンド・リファレンス)は、`DCLPRCOPT`を`PGM`コマンドより後・他の実行可能なコマンドより前に置くこと、1プログラムにつき1つしか書けないことを明記しています。`DCL`・`DCLF`・`COPYRIGHT`という他の宣言コマンドとはどの順序で混在させてもよいとも明記されており、`DCLPRCOPT`が必ず`PGM`の直後に来なければならないわけではありません。`JUYAKL`は単なる選択として`PGM`の直後に置いています。

```text
             PGM

             DCLPRCOPT  DFTACTGRP(*NO) BNDSRVPGM(*LIBL/JUCSRV)
```

`BNDSRVPGM`の値は「ライブラリー/サービス・プログラム名」という修飾名で、**ライブラリー修飾子として指定できるのは具体的な名前か`*LIBL`だけ**です(`DCLPRCOPT`のもう一方のパラメーターである`BNDDIR`と違い、`BNDSRVPGM`には`*CURLIB`という選択肢がありません)。`*LIBL/JUCSRV`は「実行時のジョブの`*LIBL`から`JUCSRV`という名前のサービス・プログラムを探す」という指定で、07-02の`ADDBNDDIRE OBJ((*LIBL/JUCSRV *SRVPGM))`とまったく同じ原則です。**ライブラリー名をソースにハードコードせず、実行時の`*LIBL`に解決を任せる**という考え方は、RPG側の`ctl-opt bnddir`だけでなく、CL側の`DCLPRCOPT`でも同じように成り立ちます。

呼び出し自体は`CALLPRC`です。

```text
             DCL        VAR(&CUST) TYPE(*CHAR) LEN(6) VALUE('C00001')
             DCL        VAR(&NAME) TYPE(*CHAR) LEN(30)

             CALLPRC    PRC('getCustName') PARM(&CUST) RTNVAL(&NAME)
```

`PRC()`が手続き名、`PARM()`が引数リスト、**`RTNVAL()`が戻り値を受け取るCL変数**です。一次資料には`CALLPRC`の実例を含むページが複数あり、そのうち1つ(ILE RPG言語リファレンスの古い図解例)は戻り値を受け取るパラメーターを`RTNVAR`と表記していますが、CLコマンドそのものを定義しているCLコマンド・リファレンスのパラメーター表と、そこに載っているすべての実例(戻り値を受け取る例はすべて)は**`RTNVAL`**で一致しています。**一次資料同士が食い違うときは、そのコマンドそのものを定義している資料(ここではCLコマンド・リファレンス)を優先してください。** `JUYAKL`は`RTNVAL`を使っており、下の「実機メモ」のとおり実際に動作しています。

`PRC('getCustName')`の大文字・小文字にも注意してください。一次資料は「`PRC`の手続き名は大文字・小文字を区別する」と明記しています。`getCustName`は07-02で`dcl-pi *n char(30) extproc(*dclcase);`として宣言されており、`extproc(*dclcase)`は外部呼び出し名を**`dcl-proc`に書いたとおりの綴り**(コンパイラーの既定である大文字化ではなく)に固定するキーワードでした。つまり`JUCSRV`が実際に公開している名前は、大文字化した`GETCUSTNAME`ではなく、混在大文字小文字の`getCustName`そのものです。一次資料の規則をそのまま当てはめれば、**`CALLPRC`の`PRC()`を`PRC('GETCUSTNAME')`と大文字で書くと、この混在大文字小文字の実際のエクスポート名とは一致せず、結合(バインド)の段階で解決に失敗するはずです**——ただし、この失敗自体をこの教材が実機で再現させたことはまだありません(演習4)。`&CUST`・`&NAME`は、どちらも`DCL`で明示的に宣言した変数であり、`CALLPRC`にリテラルを直接渡していません。これは03-08で確認した「コマンド行から直接`CALL`したときの32バイト・リテラルの罠」と同じ発想の予防策です(`CALLPRC`自身がコマンド行からの`CALL`と同じ罠を持つかどうかまでは確認していませんが、変数を経由しておけば、その心配自体が生じません)。

### `GOTO`+ラベルから`SUBR`/`CALLSUBR`へ

`JUYAKC`(03-13)は、前処理・本処理・後処理・異常処理を`GOTO`とラベルでつないでいました。`JUYAKL`は、この4つのまとまりを`SUBR`/`ENDSUBR`(サブルーチンの定義)と`CALLSUBR`(呼び出し)に書き直しています。

```text
             CALLSUBR   SUBR(FRONT)
             CALLSUBR   SUBR(MAIN)
             CALLSUBR   SUBR(BACK)

             RETURN

FAILED:      CALLSUBR   SUBR(ERRSUBR)

             SUBR       SUBR(FRONT)
             ...
             ENDSUBR
```

**唯一、`GOTO`をそのまま残した箇所が1つだけあります。** プログラム冒頭の`MONMSG MSGID(CPF0000) EXEC(GOTO CMDLBL(FAILED))`です。`FAILED:`ラベル自身の仕事は`CALLSUBR SUBR(ERRSUBR)`を呼ぶことだけなので、実際のエラー処理の中身はサブルーチンの形のままですが、この一次分岐だけは`GOTO`を経由しています。理由は率直に書いておきます——この教材が参照している一次資料の抜粋には`MONMSG`という命令自体の独立した項目がなく、`EXEC()`に`CALLSUBR`を直接指定できるかどうかを確認できていません。確認できるまでは、実績のある`GOTO`+ラベルのままにしてあります。`SUBR`/`ENDSUBR`/`CALLSUBR`自体も、この教材が参照している一次資料には独立した解説ページが見当たりませんが、実機では`CRTBNDCL`が実際にこの形をエラーなくコンパイルし、`CALLSUBR`が正しく各サブルーチンを呼び出して最後まで実行できたことを、後述の「実機メモ」のとおり確認しています。

### 実際のコマンドの落とし穴: `CPYTOIMPF`と`RCDDLM`

`JUYAKL`の`BACK`サブルーチンは、`JUCHUM`をCSVとしてIFSへ書き出します。

```text
             SUBR       SUBR(BACK)

             CHGVAR     VAR(&TOSTMF) VALUE('/home/' *TCAT %TRIM(&USRPRF) +
                          *TCAT '/work/juchum_export.csv')
             CPYTOIMPF  FROMFILE(&LIB/JUCHUM) TOSTMF(&TOSTMF) +
                          MBROPT(*REPLACE) STMFCCSID(1208) RCDDLM(*CR)

             ENDSUBR
```

**`RCDDLM(*CR)`を明記しないと、この`CPYTOIMPF`は失敗します(この教材の検証では2回連続で確実に再現しました)。** 実際に起きるのは次のエラーです。

```text
CPF2845: The copy did not complete for reason code 11.
CPF2817: Copy command ended because of error.
```

**この`CPYTOIMPF`の行自体は、実は`JUYAKC`(03-13)にもまったく同じ形で既に存在していました。** ただし03-13自身の実機メモが明記しているとおり、`JUYAKC`のこの行はこれまで一度も実機で`CALL`されたことがありません。`JUYAKL`で初めてこの行を実際に実行したことで、この**本物のコマンドの落とし穴**が見つかりました。この教材が参照している一次資料(ILE RPG言語リファレンス・ILE Concepts・CLコマンド・リファレンス)には、この症状を直接説明する記述が見当たりません。複数の第三者による実例報告(IBM公式のドキュメント・ページではありません)を確認した結果として、`RCDDLM(*CR)`を明記することで解消しました。一次資料が無い分野であることを隠さず、**実機で実際に2回失敗し、1回成功したこと**——それ自体を根拠として扱ってください(詳細は「実機メモ」参照)。

`JUYAKC`(03-13)自身の`CPYTOIMPF`行は、依然として`RCDDLM`を省略したままです。03-13自身の実機メモは、この行を含めて「未確認」と明記しているため、`JUYAKC`側で実際にこのコマンドを実行したら同じ`CPF2845`が起きるかどうかは、この教材ではまだ実機で確認されていません(起きる可能性が高いと考えられます)。

## 実演

**この実演は、`F0704A`が名前付き活動化グループを使う関係で、途中で接続を切らず、同じジョブの中で最後まで進める必要があります。**

手順5〜8(`F0704A`のコンパイル・3回の`CALL`・`RCLACTGRP`)と手順9〜10(`JUYAKL`のコンパイル・`CALL`)は、それぞれ別の接続で、非対話SSHでの実機確認(V1+V2)まで済んでいます。詳細は下の「実機メモ」を参照してください。ただし両方を同じジョブの中で連続して実行したこと自体は、この教材ではまだ確認していません。5250から実際にサインオンしたまま手順を追う対話的な操作感そのものも、この教材の検証ハーネス(非対話SSH)では確認できないV3の範囲です。

1. SSHで接続し、`~/ibmi-kyozai`を最新にする(`git pull`)。

2. ソースを取り込む(1回の接続でまとめて行います)。

   ```sh
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qrpglesrc/f0704s.rpgle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QRPGLESRC.FILE/F0704A.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   system "CPYFRMSTMF FROMSTMF('/home/<自分のユーザー名>/ibmi-kyozai/src/qclsrc/juyakl.clle') TOMBR('/QSYS.LIB/<自分のユーザー名>1.LIB/QCLSRC.FILE/JUYAKL.MBR') MBROPT(*REPLACE) STMFCCSID(1208)"
   ```

   `JUYAKL`の`BACK`サブルーチンは`~/work/juchum_export.csv`へ書き出します。このディレクトリーがまだ無ければ、同じ接続のうちに作っておいてください。

   ```sh
   mkdir -p $HOME/work
   ```

3. 5250に戻り、`JUYAKL`が依存する既存オブジェクトが揃っているか確認します。`JUNODA`(03-06)・`JUMSGF`(03-07)・`JUCSRV`(07-02・07-03)がまだ無ければ、それぞれのレッスンの手順で先に作ってください。

4. **カレント・ライブラリーを確認・設定します。** `JUYAKL`(`JUYAKC`から引き継いだ`RTVJOBA CURLIB(&LIB) CURUSER(&USRPRF)`)は、**ライブラリー・リストではなく「カレント・ライブラリー」という別の属性**を読みます。`ADDLIBLE`でライブラリー・リストに追加しただけではこの属性は変わりません。`JUNODA`・`JUMSGF`・`JUCHUM`を置いたライブラリーが、実際にカレント・ライブラリーになっていることを`DSPJOB`(または`WRKJOB`)で確認し、違っていれば`CHGCURLIB CURLIB(<自分のユーザー名>1)`(または03-11の`SETENV`)で合わせてください。

5. `F0704A`をコンパイルします。

   ```text
   CRTBNDRPG PGM(<自分のユーザー名>1/F0704A) SRCFILE(<自分のユーザー名>1/QRPGLESRC) SRCMBR(F0704A)
   ```

   Highest Severity 00 になることを確認してください。

6. `F0704A`を1回目に`CALL`します。

   ```text
   CALL PGM(<自分のユーザー名>1/F0704A)
   ```

   `DSPJOBLOG`で、`bumpCounter()`が1・2・3を返した(`counter=1`・`counter=2`・`counter=3`)3行の`CPF9898`メッセージを確認してください。

7. **接続を切らず**、もう一度`CALL`します(2回目、同じジョブ)。

   ```text
   CALL PGM(<自分のユーザー名>1/F0704A)
   ```

   今度は`counter=4`・`counter=5`・`counter=6`になるはずです——1回目と**同じ活動化**が使われ、STATIC変数が継続しています。

8. `RCLACTGRP`で活動化グループを削除し、3回目の`CALL`で`counter`が1・2・3に戻ることを確認します。

   ```text
   RCLACTGRP ACTGRP(F0704AG)
   CALL PGM(<自分のユーザー名>1/F0704A)
   ```

9. `JUYAKL`をコンパイルします(`DCLPRCOPT`が`DFTACTGRP`を決めるため、コマンド行に`DFTACTGRP`・`ACTGRP`は書きません)。

   ```text
   CRTBNDCL PGM(<自分のユーザー名>1/JUYAKL) SRCFILE(<自分のユーザー名>1/QCLSRC) SRCMBR(JUYAKL)
   ```

   Highest Severity 00 になることを確認してください。

10. `JUYAKL`を`CALL`します。

    ```text
    CALL PGM(<自分のユーザー名>1/JUYAKL)
    ```

    `DSPJOBLOG`で、`CALLPRC`経由の`getCustName`呼び出しの結果(得意先名)、`CPYTOIMPF`の完了メッセージ、`JUYAKL: done. ...`という完了メッセージを確認してください(具体的な文言は「実機メモ」参照)。

## 演習

1. 一度サインオフし、あらためて新しいセッションで`CALL PGM(<自分のユーザー名>1/F0704A)`を1回だけ実行してください。`counter`が(前のセッションの続きではなく)1・2・3になることを確認してください——名前付き活動化グループも**ジョブをまたいでは残りません**。
2. `JUYAKL`をもう一度`CALL`し、次の受注番号がさらに1つ進むことを確認してください。`FRONT`サブルーチンの採番は、後続の`BACK`サブルーチンが万一失敗しても既に確定しています(03-13の`JUYAKC`と同じ設計です)。
3. `CPYTOIMPF`から`RCDDLM(*CR)`を一時的に外して`JUYAKL`を再コンパイル・実行し、`CPF2845`(reason code 11)が実際に再現することを確認してください。確認できたら`RCDDLM(*CR)`を必ず元に戻してください。
4. (発展)`CALLPRC PRC('getCustName') ...`を、大文字化した`PRC('GETCUSTNAME')`に書き換えて再コンパイルし、何が起きるか確認してください。`getCustName`は`extproc(*dclcase)`で宣言されているため、大文字化した名前では一致せず、コンパイルまたは結合(バインド)の段階で失敗すると予想されます。実際にどんなメッセージIDになるかは、この教材ではまだ確認していません——確認できたら記録しておいてください。
5. (発展)`f0704s.rpgle`をコピーし、`ctl-opt`から`actgrp('F0704AG')`と`dftactgrp(*no)`の両方を取り除いた別ソースを作り、`CRTRPGMOD`→`CRTPGM ACTGRP(*CALLER)`の2段構成でコンパイルしてみてください(`actgrp`だけを取り除いても、`dftactgrp`が単独で同じ`RNF1324`を引き起こすため、`CRTRPGMOD`は依然として失敗します)。同じジョブから複数回`CALL`したとき、名前付き活動化グループのときと同じようにSTATIC変数が継続するかどうかを確認し、記録しておいてください(この教材ではまだ未確認の対比です)。

## セルフチェック

- [ ] 名前付き活動化グループが`*NEW`と違ってプログラムの正常終了で削除されないことを、`F0704A`を同じジョブから複数回`CALL`して確認できた。
- [ ] `RCLACTGRP`で名前付き活動化グループの静的記憶域をリセットできることを確認できた。
- [ ] 名前付き活動化グループがジョブをまたいでは残らないことを確認できた。
- [ ] `CRTBNDCL`の既定活動化グループ(`DFTACTGRP(*YES)`)ではなぜ`ACTGRP`を書けないか、`DCLPRCOPT`がその制約をどう回避するかを説明できる。
- [ ] `DCLPRCOPT`の`BNDSRVPGM`と`CALLPRC`の`RTNVAL`(`RTNVAR`ではない)を使って、CLからサービス・プログラムの手続きを呼べた。
- [ ] `CPYTOIMPF`でストリーム・ファイルへエクスポートするとき、`RCDDLM(*CR)`が無いと何が起きるかを説明できる。

## 片付け

`F0704A`・`JUYAKL`はそのまま残してください。ただし`F0704A`が使う名前付き活動化グループ`F0704AG`は、サインオンしたままにしておくと、次にこのプログラムを試したときも`counter`が前回の続きから始まります。今回の実演の効果をリセットしたい場合は`RCLACTGRP ACTGRP(F0704AG)`を実行してください(対象がすでに無ければ`CPF1653`が出ますが、実害はありません)。`JUCHUM`・`TOKUIM`は読み取り専用のアクセスしかしていないため`TXRESET`は不要ですが、`JUNODA`の値は`JUYAKL`を`CALL`するたびに1つずつ進みます。

## まとめ

| 英語 | 日本語 |
|---|---|
| Activation group | 活動化グループ |
| Named activation group | 名前付き活動化グループ |
| Reclaim Activation Group (`RCLACTGRP`) | 活動化グループの解放 |
| Static storage | 静的記憶域 |
| Declare Processing Options (`DCLPRCOPT`) | 処理オプションの宣言 |
| Call Bound Procedure (`CALLPRC`) | 束縛された手続きの呼び出し |

次のレッスン(07-05)は、第7部のチェックポイントです。`F0608A`(06-08、ZAHIK4)の在庫引当ロジックを、`get`・`reserve`・`release`という3つの手続きを持つ新しいサービス・プログラム`ZAISRV`として設計・公開します。

## 実機メモ

- **確認日: 2026-09-27。接続`part07-04-actgrp-cl`(3回接続)。以下はいずれも非対話SSHで実行し、接続自身の`run`セクションの生テキストを直接読んで確認した(V1+V2)。**
  - `F0704A`は3回の接続すべてで`CRTBNDRPG`がHighest Severity 00になり、`CALL PGM(F0704A)`直後の`bumpCounter()`が同一呼び出し内で1・2・3を返すことを確認した(このメッセージ自体は`sendToJobLog`経由で送られており、実際のテキストにはSTATICキーワードの説明句が続きます)。これはSTATIC変数がふつうに効いている部分の確認であり、活動化グループをまたぐ継続・リセットの確認は下記`part07-04b-actgrp`で行っている。
  - `DIAGCURLIB`(このレッスンの検証のためだけに用意した診断プログラム)で、`RTVJOBA CURLIB`の返す値を確認したところ、`DIAGCURLIB: RTVJOBA CURLIB returned [<USER>1  ]`だった。ところがこの接続が`F0704A`・`JUNODA`・`JUMSGF`・`JUYAKL`を実際に作成していたのは、`ADDLIBLE`でライブラリー・リストに追加した**別の**ライブラリーだった。つまり`ADDLIBLE`でライブラリー・リストに対象ライブラリーを追加しただけでは、`RTVJOBA CURLIB`が読む「カレント・ライブラリー」という属性はそのライブラリーに変わらないことが実機で分かった。この後、明示的な`CHGCURLIB`でカレント・ライブラリーを実際の対象ライブラリーへ合わせてから残りの手順を実行したところ、`JUNODA`・`JUMSGF`まわりの処理は正しく動作した。
  - `JUYAKL`の`CALLPRC`は成功し、`getCustName(C00001)`から得意先名(`ACME TRADING CO`、前後に`*BCAT`由来の空白を含む)を取得できたことを確認した。`DCLPRCOPT BNDSRVPGM`経由の`CALLPRC`が実際に動くことを、ここで初めて確認した。
  - `BACK`サブルーチンの`CPYTOIMPF`で実際にバグを発見・修正した。1回目の接続では`RCDDLM`を省略したままで、`CPF2845`(reason code 11)・`CPF2817`で毎回失敗した。2回目の接続では「IFSの書き出し先ディレクトリーが無いのでは」という仮説のもとディレクトリーを作成するステップを足して再実行したが、まったく同じ失敗が再現し、この仮説は誤りだったと分かった。複数の第三者による実例報告(一次資料ではない)を確認し、`RCDDLM(*CR)`を追加したところ、3回目の接続で解消し、`JUCHUM`の全レコードがコピーされたことを示す完了メッセージと、`JUYAKL`自身の完了メッセージ(次の受注番号を報告するもの)が両方とも記録された。
  - 1・2回目の接続での`CPYTOIMPF`失敗は、`JUYAKL`自身の`ERRSUBR`(`SNDPGMMSG MSGID(JUM0001) MSGF(&LIB/JUMSGF) MSGTYPE(*ESCAPE)`)で正しく捕捉され、ハングせず接続そのものは正常に完了した——エラー処理の経路自体も、この2回の失敗によって実地で確認できたことになる。
- **確認日: 2026-09-27(接続`part07-04b-actgrp`。接続結果の生ログに埋め込まれたPUB400のシステム時計は`26-09-28`——確認日とPUB400のシステム時計の間で日付境界をまたいでいます)。** 名前付き活動化グループの継続・リセットを、同一ジョブ内の次の5段階で確認した。
  1. `RCLACTGRP ACTGRP(F0704AG)`(冒頭、念のため): `CPF1653: Activation group F0704AG not found.`——新しいジョブでは名前付き活動化グループもまだ存在せず、ジョブをまたいで残らないことを確認した。
  2. `CALL PGM(F0704A)`(1回目): `counter`が1・2・3。
  3. `CALL PGM(F0704A)`(2回目、同一ジョブ、`RCLACTGRP`なし): `counter`が4・5・6——**継続**を確認した。
  4. `RCLACTGRP ACTGRP(F0704AG)`: `Activation group F0704AG deleted.`
  5. `CALL PGM(F0704A)`(3回目): `counter`が1・2・3に戻る——**リセット**を確認した。
  - `*CALLER`比較版(`F0704AC`)は、別の理由でブロックされた。同一ソースを`CRTRPGMOD`(モジュールのみ)にかけたところ、`RNF1324: Keywords DFTACTGRP, ACTGRP, or USRPRF are not allowed.`(Severity 20、`Compilation stopped.`)で失敗した——`ctl-opt`の`actgrp('F0704AG')`(および`dftactgrp(*no)`)は`CRTBNDRPG`専用のキーワードで、`CRTRPGMOD`はこれを拒む。`*CALLER`比較オブジェクトを作るには`ctl-opt`からこれらを除いた別コピーのソースが必要で、この教材ではまだ用意していない。`*NEW`・`*CALLER`との対比は、本文に書いたとおり一次資料からの推論のままである。
  - 上記2つの接続は、いずれも**(V1+V2)**(非対話SSHで実行し、接続自身の`run`セクションの生テキストを直接読んで確認)である——`*CALLER`比較版の`CRTRPGMOD`/`RNF1324`はコンパイル結果だけを見ているV1、`F0704A`の`bumpCounter`・`RCLACTGRP`の各段階はいずれも実行結果まで確認したV2である。`RCLACTGRP`を5250の対話的なコマンド行から実行したときの見え方や、学習者自身のサインオン・セッションでの継続・リセットの確認は、この教材の検証ハーネス(非対話SSH)では確認できない**V3**の範囲であり、実機では未確認のままである。
- **`src/qclsrc/juyakl.clle`自身のヘッダー・コメントには食い違いがある。** `RTVJOBA`の`USER()`→`CURUSER()`修正を、あたかもこのファイルで新しく行ったかのように書いているが、`src/qclsrc/juyakc.clp`(03-13)自身が、[付録C](../appendix/c-troubleshooting.md)3節・`part03-rtvjoba-fix`(確認日2026-09-26)で既に`CURUSER`へ修正済みである。`JUYAKL`が`JUYAKC`と実際に違うのは、`GOTO`+ラベルから`SUBR`/`CALLSUBR`への再構成、`DCLPRCOPT`+`CALLPRC`の追加、`CPYTOIMPF`への`RCDDLM(*CR)`の3点である。ソース自身の食い違いの指摘のみ残す(07-02が別のソースの食い違いを指摘したのと同じ扱いである)。
- 食い違いに気づいたら [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で教えてください。
