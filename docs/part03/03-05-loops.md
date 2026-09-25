# 03-05 繰り返しと SELECT

> 所要時間: 60分 / 前提レッスン: 03-04 / 目標番号: 2 / 観測方法: `DSPJOBLOG` / 道具: 5250(SEU)/ 同時接続数: 5250×1 / 作る・変えるオブジェクト: `<USER>1/C0305A` / DBVER: 1 / 依存するプローブ: P41 / PTF 依存: なし / 容量の目安: わずか

## ゴール

- `DOWHILE`/`DOUNTIL`/`DOFOR`/`SELECT` で繰り返し・多分岐を書ける。
- 古い書き方の `GOTO` を読める。

## ウォームアップ

<details><summary>前回の復習</summary>

1. CL 単体の `DO`/`ENDDO` は、繰り返しの意味を持つ?
2. `IF` は文? コマンド?

答え: 1. 持たない(まとまりを表すだけ) 2. コマンド

</details>

## なぜ学ぶか

03-04 で見たとおり、`DO` 単体には繰り返しの意味がありません。繰り返しには専用のコマンド(`DOWHILE` など)を使います。また、古い CL のソースでは、繰り返しに `GOTO` が使われていることがあるため、読めるようにしておきます(第5部で本格的に読みます)。

## 新出

- `DOWHILE`・`DOUNTIL`・`DOFOR`
- `SELECT`/`WHEN`/`OTHERWISE`/`ENDSELECT`
- `LEAVE`・`ITERATE`

## 説明

| コマンド | 動作 |
|---|---|
| `DOWHILE` | 条件が真の**間**繰り返す(繰り返す前に判定) |
| `DOUNTIL` | 条件が真に**なるまで**繰り返す(繰り返した後に判定。最低1回は実行される) |
| `DOFOR` | 開始値から終了値まで、変数を増やしながら繰り返す |

`LEAVE` はループを抜け、`ITERATE` は残りをスキップして次の繰り返しに進みます(他の言語の `break`/`continue` に近い働きです)。

`SELECT`/`WHEN`/`OTHERWISE`/`ENDSELECT` は、`IF`/`ELSE` の連鎖より読みやすく多分岐を書けます。

### 無限ループの止め方

繰り返しの条件を書き間違えると、無限ループになることがあります。PUB400 は共有の練習機なので、**`SysReq`(00-03 で学んだキー)を押して `2`(ジョブの終了)を選ぶ**ことで、暴走したジョブを止められます。**この教科書のどの演習も、意図的に長時間ループさせる内容は含みません。** もし想定外にループが止まらなくなったら、慌てずこの方法で止めてください。

## 実演

1. `WRKMBRPDM FILE(<自分のユーザー名>1/QCLSRC)` で `C0305A`(`CLP`)を作る。
2. 次を入力する(`src/qclsrc/c0305s.clp` と同じです。1から10までの合計を `DOFOR` で求めます)。

   ```clp
   PGM
   DCL        VAR(&I) TYPE(*DEC) LEN(5 0) VALUE(0)
   DCL        VAR(&SUM) TYPE(*DEC) LEN(7 0) VALUE(0)
   DCL        VAR(&SUMC) TYPE(*CHAR) LEN(10)

   DOFOR      VAR(&I) FROM(1) TO(10)
      CHGVAR     VAR(&SUM) VALUE(&SUM + &I)
   ENDDO

   CHGVAR     VAR(&SUMC) VALUE(&SUM)
   SNDPGMMSG  MSG('Sum 1..10 = ' *TCAT %TRIM(&SUMC))
   ENDPGM
   ```

3. コンパイル・実行し、`DSPJOBLOG` で合計(`55`)が表示されることを確認する。

## GOTO で書かれた古いスタイル(読解)

古いソースでは、次のように `GOTO` で同じ処理が書かれていることがあります。

```clp
PGM
DCL        VAR(&I) TYPE(*DEC) LEN(5 0) VALUE(1)
DCL        VAR(&SUM) TYPE(*DEC) LEN(7 0) VALUE(0)

LOOP:      IF         COND(&I *GT 10) THEN(GOTO CMDLBL(DONE))
           CHGVAR     VAR(&SUM) VALUE(&SUM + &I)
           CHGVAR     VAR(&I) VALUE(&I + 1)
           GOTO       CMDLBL(LOOP)

DONE:      SNDPGMMSG  MSG('Done')
           ENDPGM
```

`GOTO CMDLBL(ラベル名)` で、指定したラベルの行にジャンプします。`DOFOR`/`DOWHILE` のような専用コマンドがなかった時代の書き方で、条件判定・処理・カウンターの更新・ループの先頭へ戻る、という4つの役割を自分で組み立てる必要があります。第5部で、実際にこのスタイルで書かれた既存コードを読みます。

## 演習

上の `GOTO` 版を、`DOWHILE` を使う形に書き換えてください(`C0305A` と同じ「1から10までの合計」を求める内容にしてください)。

## セルフチェック

- [ ] `DOFOR` で繰り返しを書けた。
- [ ] `DOWHILE`/`DOUNTIL` の違いを説明できる。
- [ ] `GOTO` 版のロジックを読んで理解できた。
- [ ] 無限ループを `SysReq` で止める方法を知っている。

## 片付け

このレッスンで作ったプログラムは、そのまま残してください。

## まとめ

| 英語 | 日本語 |
|---|---|
| Loop | 繰り返し |
| Label | ラベル |

次のレッスン(03-06)では、`MONMSG` によるエラー処理の基本を学びます。

## 実機メモ

- 確認日: 未確認(このセッションでは実施していない、P41)。`DOFOR`/`DOWHILE`/`GOTO` の一般的な仕様は一次資料に基づく。合計値(55)は手計算で検証済み。
