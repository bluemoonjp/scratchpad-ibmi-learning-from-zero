# Security

このリポジトリは学習教材(ドキュメントとサンプルソース)であり、稼働しているサービスはありません。

教材の内容(サンプルソースの安全でない書き方、PUB400 上での意図しない挙動を招く手順など)に関する指摘は、通常の [Issue](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/issues) で報告してください。

個人情報(実在のユーザー名、メールアドレス、内部パス等)が本リポジトリに混入していることに気づいた場合は、公開の Issue ではなく GitHub の [Private vulnerability reporting](https://github.com/bluemoonjp/scratchpad-ibmi-learning-from-zero/security/advisories/new) から報告してください。

## 過去のコミットに含まれていた PUB400 のユーザー名(Issue #34)

- 2026-10-05 に、`main` の過去の2つのコミットの差分に、PUB400 のユーザー名(アカウント名。パスワードや鍵ではありません)がライブラリー名の一部として含まれていたことを記録しました。現在のファイルの内容には含まれていません。
- 対応: 履歴を書き換えて、該当の文字列を `<USER>` に置き換え、すべてのブランチを force push します(実施の記録は Issue #34 に残します)。
- 限界: GitHub 上の閉じた Pull Request の `refs/pull/*` や、フォーク・既存のクローンには、古いコミットが残ることがあります。完全に消すには GitHub のサポートへの依頼が要ります。このリポジトリのフォークは、記録の時点で 0 件でした。
- 再発の防止: ドキュメントと検証の結果には、実名を書かず、`<USER>` 系のプレースホルダーを使います(`docs/style-guide.md`)。`verify/` の結果は匿名化してから保存します。
