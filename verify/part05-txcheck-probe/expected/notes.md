# part05-txcheck-probe の期待値

このバッチは`TXCHECK`(`tools/qclsrc/txcheck.clp`)自体が初めて実機コンパイル・
実行されるテストであり、Part 8(08-08)の設計がTXCHECK呼び出しを
`blocked-pending-TXCHECK-verification`としている前提そのものを解消する。

## 手順の要点(`tools/qclsrc/txcheck.clp`を直接読んで確認済み)

- `TXCKM`(マニフェスト表)に自己参照の1行(`TEST01`のレコード様式1、
  `TXCKM`自身が`*FILE`として存在するかを確認する行)をINSERTしてから
  `TXCHECK`を`CALL PGM(&LIB/TXCHECK) PARM('TEST01' '&LIB')`で呼ぶ
  (この段階では`tools/qcmdsrc/`の`*CMD`ラッパーはまだコンパイルされて
  いないため、`CALL PGM`が唯一の正しい呼び方 — Part 6/7/8のTXRESET/
  TXCHECK呼び出しで確立した「`*CMD`経由が正しい」という規約はここには
  適用されない、意図的な例外)。
- `txcheck.clp`のv1スコープは`CHKOBJ`によるオブジェクト存在・型のみの
  確認(データ検査は未実装、ソース冒頭コメントで明記済み)。

## 期待される結果

- `TXCKM`への1行のINSERTが成功する。
- `TXCHECK`のコンパイルがHighest Severity 00で成功する。
- `CALL`により、`TEST01`のマニフェスト行(`TXCKM`が`*FILE`として存在する
  かの`CHKOBJ`)がPASSと判定され、`SNDPGMMSG`で1行のPASSメッセージが
  ジョブ・ログに記録される(`VFYLOG`のダンプに現れる)。
- FAILは想定していない(自己参照先の`TXCKM`は直前のステップで確実に
  作成されているため)。もしFAILが出た場合は`CHKOBJ`のOBJTYPE判定や
  `DCLF`のフィールド読み取りに実装バグがある可能性が高く、
  `txcheck.clp`本体の修正が必要になる。

## この結果がPart 8設計に与える影響

- PASSした場合: `work/design/part08-design-v1.md`の08-08節・§7の
  `part08-08-checkpoint`案の`blocked-pending-TXCHECK-verification`を
  解消できる(`TXCHECK LESSON('08-08') LIB(<USER>2)`を実際に設計へ
  組み込んでよい)。同様にPart 6(06-15)・Part 7(07-05)のチェックポイント
  設計にも反映できる。
- FAILした場合: `txcheck.clp`のバグを修正してから再接続で再検証する
  (このバッチ自体は`draft/part05`にコミット済みの下書きソースを
  対象にしているため、まずはこの1接続の中で複数の修正候補を試せるよう、
  マニフェスト側で候補を用意しておくことが望ましい)。
