# part05-txmigr-to2(連結A)の期待値(手計算、実機未確認)

**この設計は2名の批評担当の指摘(2026-09-27)を受けて全面的に書き直した版。**
書き直しの理由・根拠は `manifest.json` の description 本文に詳しいので、ここでは
「実機に接続したあと、`VFYLOG`/`collect` をどう読むか」だけを整理する。

## この接続(A)だけでは確認できないこと

- **`TXMIGR TO(2)` そのものは、この接続では一度も呼ばれない。** `TXMIGR`の
  呼び出し・その後の`JUCHUL1`再作成の試み・`JU0300`の実行は、すべて
  次の接続 `verify/part05-txmigr-to2b` の役目である。この接続(A)は
  「`TXMIGR`が始める前の状態」——`CHGPF`だけを手作業で適用し、`CPF4131`が
  実際に起きることを確認するところまで——を作って終わる。
- `RJU0900B`(`JU0900C`経由の`ZA0500`呼び出し)は、05-13チケット1の
  バグ(`MINQTY`桁数不一致、`ZA0500`側で`RPG0907`)を必ず踏む
  (`part05-ju0900c-baseline`で確認済み)。**この接続の主役は
  `PROBEB`(新設のRUNPROBE)であり、`RJU0900B`はあくまで「この呼び出し
  連鎖(JU0900C→ZA0500共有ODP経由)自体がハングしないこと」の追加確認
  にすぎない。** `RJU0900B`単独の結果から`CPF4131`の有無を断定しようと
  しないこと(`JU0900C`自身の`MONMSG(CPF0000)`が`CPF4131`を汎用メッセージ
  に握りつぶし、`GOTO`/`RETURN`せず`ZA0500`へフォールスルーするため)。

## 読む前に必ず確認すること(ゲート、2026-09-27追加、advisor再指摘)

**`VFYLOG`に`TXSETUP: done. DBVER=1.`という行が実際にあることを、
以下のどの読み方よりも先に確認すること。** `tools/qclsrc/txsetup.clp`
自身の`FAILSAFE`ラベルは`SNDPGMMSG ... MSGTYPE(*COMP)`のあと`GOTO
CMDLBL(TXEND)`で**正常に**終わる(`*ESCAPE`を投げ直さない)ため、
`RUNSETUP`ステップ自身が`VFYLOG`で`FAILED`と出ることは無い。つまり
`TXSETUP`が途中で止まっていても、この接続の他のステップは(`JUCHUM`/
`JUCHUL1`が未構築のまま)何ごともなかったかのように進んでしまう
——`PRECLEAN`(下記参照)がこの接続を再実行に対して安全にする一方、
`TXSETUP`自身の`BUILD`処理そのものが何らかの理由で失敗した場合は、
このゲート文言が無ければ気づけない。

## 各ステップの期待値

0. **`PRECLEAN`(新設、2026-09-27追加、advisor指摘)**: `RUNSETUP`より前に
   `&LIB2/JUCHUL1`・`&LIB2/JUCHUM`を`DLTF`で先に削除する(どちらも
   `MONMSG CPF0000`——初回の接続なら両方とも「オブジェクトが見つからない」
   で無害に失敗するのが正常)。`tools/qclsrc/txsetup.clp`のLOADPF/LOADLF
   サブルーチンは、`CHKOBJ`で対象が**既に存在する場合は`CRTPF`/`CRTLF`を
   スキップする**設計になっている(そのファイル自身のコメント:「学習者が
   02-02で手作業で作ったファイルを上書きしない」)——`RUNSETUP`が渡す
   `FORCE(*YES)`は`TXSETUP`が`BUILD`処理へ進むかどうかを制御するだけで、
   個々のオブジェクトを再作成するかどうかには関係しない。**つまり
   `PRECLEAN`が無いと、この接続を(何らかの理由で)再実行した場合や、
   `&LIB2`が本当に空のライブラリーで無かった場合、`JUCHUM`/`JUCHUL1`が
   既に`v2`(`JUDLV`あり)の形のまま残ってしまう可能性があり、その場合
   `JU0900C`/`ZA0500`/`JU0300`/`RUNPROBE`はこの接続の前提(古い様式を
   焼き込む)に反して最初から新しい様式でコンパイルされてしまう。**
   `PRECLEAN`により、この接続は`JUCHUM`/`JUCHUL1`の形については自分自身の
   再実行に対して安全になっている。**ただし`TXSTATE`(`DBVER`)は
   `PRECLEAN`の対象外のまま**(2026-09-27追加、advisor再指摘)——この
   接続一式(A→B)を一度最後まで通した後にAだけを再実行した場合、
   `&LIB2/TXSTATE`は`verify/part05-txmigr-to2b`の`CHGDBVER`が残した
   `DBVER=2`のままであり、`STATUS0`は下記1番が予想する
   `DBVER=0000000001`ではなく`DBVER=0000000002`を返すはず。この
   食い違いに気づいたら、Aの再実行である可能性をまず疑うこと(本当の
   バグではない——この設計はこのギャップを未対応のまま残している)。
1. **`STATUS0`**: `TXSTATUS: DBVER=0000000001 in library <lib2>` のはず
   (`TXSETUP`が今しがた`DBVER=1`で構築したばかり)。
2. **`CLNFDJA`(新設、`SNAP0JM`/`SNAP0JL`の直前)**: 各`DSPFD`の出力先
   (`FDJM0`・`FDJL0`)を先に`DLTF`で消す(`MONMSG CPF0000`、初回接続なら
   無害に失敗する)——`DSPFD OUTPUT(*OUTFILE)`のOUTMBR既定動作(既存の
   表がある場合に追記か置換か)を確認しきれなかった(下記参照)ため、
   毎回確実に新規作成させるための予防措置。`SNAP1JM`の前の`CLNFDJB`も
   同じ理由。\
   **`SNAP0JM`/`SNAP0JL`**(新設): `CHGPF`より前の、素の`JUCHUM`/`JUCHUL1`
   構造。`FDJM0`・`FDJL0`が本命の基準値(ベースライン)になる。
   **読み方の注意(2026-09-27訂正、advisor再指摘)**: `DSPFD TYPE(*RCDFMT)
   OUTPUT(*OUTFILE)`が実際にどんな列を返すか(項目名そのものを列挙するのか、
   それとも様式ごとの要約行——レコード長・項目数など——だけを返すのか)は、
   このリポジトリーの一次資料(`work/design/refs/`一式を`QAFDRFMT`・
   `DSPFFD`・"format level"で検索しても該当無し)では確認できていない。
   そのため**「`JUDLV`という文字列が出るかどうか」だけを判定基準にしない
   こと。** `collect`は`SELECT *`にしてあるので、まず返ってきた列を見て、
   (a) 項目名の列があれば`JUDLV`の有無で判定し、(b) レコード長・項目数の
   ような数値列しか無ければ、その数値が`FDJM0`→`FDJM1`(・`FDJL0`→
   `FDJL0B`)で変化しているかどうかで判定すること——どちらの形で
   返ってきても、before/after の2行を突き合わせれば判定できる設計に
   してある。
3. **`RUNCHGPF`**: 成功すれば`JUCHUM`が`db/v2/juchum.pf`の形(`JUDLV`追加)に
   変わり、既存8件のデータはそのまま残るはず。失敗した場合(`RUNCHGPF:
   CHGPF failed.`)、この接続の前提そのものが崩れるので、**この場合は
   `verify/part05-txmigr-to2b`へ進む前に原因を確認すること**(manifest.json
   の「Prerequisite check」参照)。
4. **`STATUS1`**: まだ`TXMIGR`を呼んでいないので`DBVER=0000000001`のまま
   (`TXSTATE`は`RUNCHGPF`が触らない)。
5. **`SNAP1JM`/`SNAP1JL`**(新設): `CHGPF`後の`JUCHUM`・`JUCHUL1`構造。
   `FDJM1`が`FDJM0`と異なるはず(上記2番のとおり、`JUDLV`という項目名の
   有無、またはレコード長/項目数の変化のどちらかで判定)——これが
   「`CHGPF`がJUCHUMの形を本当に変えた」ことの、メッセージ文言に頼らない
   構造的な証拠になる。`FDJL0B`(`JUCHUL1`、`CHGPF`直後・`TXMIGR`より
   前)は**`FDJL0`と一致するのが本命**(`RUNCHGPF`は`JUCHUM`しか触らない
   設計のはず)——ただし`db/v1/juchul1.lf`は`R JUCHUR PFILE(JUCHUM)`
   (独自の項目リストを持たない、様式共有型のLF)なので、`CHGPF`だけで
   `JUCHUL1`側の見え方まで変わってしまう可能性は排除できない
   (advisor指摘、2026-09-27)。`FDJL0B`が`FDJL0`と**異なっていた場合**、
   「`JUCHUL1`は`CHGPF`だけでは変わらない」という、`verify/
   part05-txmigr-to2b`のSNAP2JL読み取りの前提そのものが崩れるので、
   その場合は`part05-txmigr-to2b`側のnotesを、`FDJL0`ではなく`FDJL0B`
   ——さらに言えば「`CHGPF`だけでも変わる」という新しい前提——に
   合わせて読み直すこと。
6. **`PROBEB`**(新設、この接続の本命。**2026-09-27再訂正**: 最初の
   `src/runprobe.clp`はCLの`MONMSG`の仕組みを誤解しており、`EXEC(SNDPGMMSG
   ...)`だけでは実行が止まらず後続へフォールスルーするため、`CPF4131`が
   起きても3種類のメッセージ+成功メッセージが**すべて**出てしまう欠陥が
   あった——`ju0900c.clp`自身のフォールスルー問題を批評担当が指摘した、
   まさにその同じ仕組みを新設コード側で再現してしまっていた。
   `EXEC(DO) ... GOTO CMDLBL(CLOSE) ... ENDDO`形に修正済み。以下は
   修正後の前提で書いてある): `RUNPROBE`は`CPRUNPROBE`の時点
   (`RUNCHGPF`より前)でコンパイルされているため、古い(`JUDLV`追加前の)
   `JUCHUM`の様式レベルIDを焼き込んでいる。`RUNCHGPF`後に呼ばれるので、
   **`RUNPROBE: CPF4131 CONFIRMED - JUCHUM record format level check
   failed.`という行がVFYLOGに出るのが本命。** これが05-09の核心
   (様式が変わった後、古いプログラムで開くと`CPF4131`が起きる)を、
   `ZA0500`側のチケット1バグから完全に切り離して確認する、この改訂版の
   最大の変更点。
   - もし代わりに`RUNPROBE: JUCHUM empty (RCVF got CPF0864, not CPF4131 -
     format levels agree).`が出た場合: `JUCHUM`が空になっている
     (`RUNSETUP`が失敗した可能性)。
   - もし`RUNPROBE: RCVF failed with something other than CPF4131/CPF0864`
     が出た場合: 予想外のメッセージ。**ただし、これが「`CPF4131`は起きて
     いない」ことの確証にはならない点に注意(2026-09-27追加、advisor
     指摘)**——`CPF4131`が`*DIAG`(診断)として先に出て、そのすぐ後に
     別の`*ESCAPE`が続くような経路だった場合、`MONMSG MSGID(CPF4131)`
     はその`*ESCAPE`を捕まえられず、この3番目の分岐に落ちる可能性が
     否定できない。この行が出た場合は、`VFYLOG`の生のメッセージ本文を
     "level"(様式レベル)という単語で検索し、`CPF4131`らしき記述が
     他に無いかも確認すること。
   - もし`RUNPROBE: RCVF succeeded and read a JUCHUM row - no CPF4131,
     format levels agree.`が出た場合: **本命が外れたことになる。**
     `CHGPF`が実際には様式レベルIDを変えない、または`RUNPROBE`がこの
     接続内で(何らかの理由で)`CHGPF`後に再コンパイルされてしまった
     可能性を疑うこと(`CPRUNPROBE`が`RUNCHGPF`より確実に前に実行される
     設計になっているか、ステップ順を再確認すること)。
7. **`RJU0900B`**(最後のステップ): `part05-ju0900c-baseline`と同じ理由で
   `RPG0907`(`JU0900C: ZA0500 ended abnormally.`)が出るのが本命——ただし
   今回は`DBVER=2`(`JUDLV`追加後)の`JUCHUM`に対してであり、`JUCHUM`の
   様式が変わった直後という点が`part05-ju0900c-baseline`と異なる。万一
   ここで`RPG0907`ではなく`CPF4131`(またはそれに起因する`RPG`側の
   エスケープ)が先に出た場合、それ自体も貴重なデータ(`ZA0500`ではなく
   `JU0900C`自身のRCVFで先に落ちた可能性)なので、正直に記録すること。
   `CHGJOB INQMSGRPY(*DFT)`(ラッパー冒頭で自動設定)が真の安全網。
   **05-09のコラム(ZA0500はプログラム記述なのでJUCHUMの様式変更の
   影響を受けない)を、統計文番号から間接的に読む方法(2026-09-27追加、
   批評担当2の指摘への対応)**: `part05-mch1202-corrupt/expected/
   notes.md`が確立した規則(統合ソースの行番号×100が統計文番号になる、
   `part05-ju0900c-baseline`で実機確認済み)を使うと、`za0500.rpg`の
   81行目(`N90 AVAIL COMP MINQTY`、チケット1のバグの現場)は統計文8100
   のはず。
   - もし`RPG0907`が**統計文8100**を指していれば、`ZA0500`は
     `JUCHUM`を(`CHGPF`で様式が変わった直後にもかかわらず)問題なく
     `OPEN`し、`JUCHUD`との突合せ(`M1/MR`)を経て通常の処理ロジックまで
     到達し、そこで初めてチケット1の既知のバグに当たった、ということに
     なる——`OPEN`時点で様式レベルIDによる差し止めが起きなかった、
     という意味で、05-09のコラムの主張(プログラム記述ファイルには
     様式レベル・チェックが効かない)と**整合する**(ただし`JU0900T`
     のような`MINQTY`不一致を排除した経路で確かめたわけではないので、
     これ単独で「証明した」とは言えない。`part05-mch1202-corrupt`が
     採用した`JU0900T`方式の要否については`remainingRisks`参照)。
   - もし`RPG0907`(または他の10進数データ・エラー)が**統計文8100より
     前**(例えば`OPEN`自体の失敗、または8100より前の文)を指していれば、
     コラムの主張に反する結果なので、正直に記録し、`ZA0500`のF仕様書
     (`FJUCHUM IS F 26 DISK`、宣言レコード長26)と`JUCHUM`の実際の
     レコード長(`JUDLV`追加後、伸びているはず)の不一致が実際にどう
     処理されるかを`work/design/refs/rpg400ref.txt`で再確認すること
     ——同ファイル6292行目付近は「プログラム記述ファイルは実行時にだけ
     存在すればよい(コンパイル時の様式検証はされない)」と述べているが、
     「宣言長より実際のレコードが長い場合に超過バイトが単に無視される」
     という具体的な一次資料の一文はこのリポジトリーでは見つかっていない
     (RPG/400のI仕様書が指定した桁位置だけを読む、という一般的な
     アーキテクチャからの推論にとどまる——`remainingRisks`参照)。

## collect の読み方

- 1本目(`COUNT(*)`/`MIN(JUDLV)`): `N=8`のはず(`CHGPF`はデータを消さない)。
  **`MINDLV`について訂正(2026-09-27、advisor指摘)**: 「`JUDLV`は
  `NULL`になるはず」という最初の想定は誤り——`db/v2/juchum.pf`の
  `JUDLV`は`ALWNULL`を指定していない(既定でNULLを許さない)ので、
  `CHGPF`は既存の8行それぞれに`JUDLV`の**何らかの既定値**(日付型
  `L`・`DATFMT(*ISO)`の既定値、具体的にどんな値になるかはこの接続の
  結果を見るまで未確認)を埋めるはずである。`MINDLV`が`NULL`なら
  それ自体が想定外の結果として記録すること(`ALWNULL`の解釈を誤って
  いたか、`CHGPF`が実際には項目を追加できていない可能性)。
- 2〜5本目(`FDJM0`/`FDJM1`/`FDJL0`/`FDJL0B`の`SELECT *`): 上記2・5参照。
- 6本目(`OBJECT_STATISTICS`): **この接続だけでは何も証明しない
  (2026-09-27訂正、批評担当1の指摘どおり単発スナップショットは比較対象が
  無い)。** `verify/part05-txmigr-to2b`が接続を終えたあと、この接続の
  値と`part05-txmigr-to2b`側の同じクエリーの値を並べて比較すること。
  特に`JUCHUL1`の`OBJCREATED`が、`part05-txmigr-to2b`の`SNAP2JL`
  (`TXMIGR`直後、手動修正の前)の内容とどう対応するかを見ること
  (`OBJCREATED`だけで判断せず、`SNAP*JL`の構造的な証拠と併せて読むこと
  ——`part05-txmigr-to2b`側は手動`DLTF`/`CRTLF`も行うため、`OBJCREATED`
  だけでは`TXMIGR`自身の効果と手動修正の効果を区別できない)。

## この接続後に &LIB2 へ残る状態

`JUCHUM`は`db/v2/juchum.pf`の形(`JUDLV`追加済み)、既存8件のデータは
そのまま。`JUCHUL1`はまだ**変更前**(`db/v1/juchul1.lf`のまま、`TXMIGR`も
手動`DLTF`/`CRTLF`もまだ実行していない)。`JU0900C`/`ZA0500`/`JU0300`/
`RUNPROBE`はいずれも**古い(CHGPF前の)JUCHUM/JUCHUL1の様式レベルIDを
焼き込んだまま**——`verify/part05-txmigr-to2b`の前提そのもの。
`TXSTATE`はまだ`DBVER=1`のまま。

この設計時点(2026-09-27)で同じセッション中に存在する
`verify/part05-promote-rollback`(同じく`library2:"*B"`)は`JUCHUM`/
`JUCHUL1`/`JU0300`/`JU0900C`/`ZA0500`/`RUNPROBE`のいずれにも触れない
(`TK0100D`/`TK0100`/`TXPRSAVF`のみ)ので、この接続の前提には影響しない
——ただし`verify/part05-txmigr-to2b`のTXMIGR呼び出し(全*PGM再コンパイル)
には影響しうる(そちらのdescription/notes参照)。
