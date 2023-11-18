# 第4章 堅牢なコンテナイメージを作る

## 4.1 コンテナイメージのセキュリティ

### コンテナイメージのセキュリティと脅威
コンテナ運用時のアタックサーフェス(攻撃経路)は以下
- インストールされたソフトウェアやライブラリに既知の脆弱性を悪用した攻撃
- コンテナイメージに格納したクレデンシャルの漏洩
- マルウェアを含むような悪意あるコンテナイメージの使用
- 正規のコンテナイメージの改ざん

## 4.2 コンテナイメージのセキュリティチェック
4.2ではコンテナイメージに含まれるソフトウェアの基地の脆弱性の対応について取り上げる

### コンテナイメージのための脆弱性スキャナ
- コンテナイメージの実態はファイルシステムをレイヤとして保持し、1つにまとめたもの
  - そのため、コンテナイメージを展開してファイルシステムを走査することで、インストールされているソフトウェアやそのバージョンを列挙できる
  - **列挙したソフトウェアの情報を外部の脆弱性データベースと照合することで、コンテナイメージに含まれる既知の脆弱性を洗い出せる**
  - スキャンするツールは以下
    - [Trivy開発者の詳しい記事](https://knqyf263.hatenablog.com/entry/2021/07/29/143500)
    - [Trivy](https://github.com/aquasecurity/trivy)
      - DBなどの事前準備を全て不要にしてとにかく簡単に実行できるよう、RDBは使わず組み込みKVS（BoltDB）を使用
      - 元は日本人の個人開発者が開発したらしい
      - コンテナに含まれるOSパッケージの他にNPMやRubyGemsなどのアプリケーションの依存ライブラリの脆弱性も検出できる
      - DockerfileやKubernetesのマニフェスト、TerraformやCloudFormationなどインフラコードの設定ミスを検出する機能
      - AWSのIAMアクセスキーや各種APIトークンなどを検出する機能
      - スタンドアロン方式とクライアント/サーバー方式の2つの方式で動作させれる
        - スタンドアロン型はサーバなどに接続する必要がなく、ネットワークにも接続していないため、ウイルスや悪意のあるプログラムに感染するリスクが低く、高いセキュリティを担保できる点がメリット。
        - クライアントサーバ型は、クライアント側の端末にアプリケーションをインストールすることでサーバとの通信量を少なくできます。
    - [Clair](https://github.com/quay/clair)
      - クライアント・サーバ型でサーバを事前に準備する必要がありCI/CDのようになるべく状態を持ちたくない環境には不向き
      - コンテナレジストリ向けに作られたもの
      - コンテナレジストリのように大量のイメージをスキャンする上ではClairに大きなアドバンテージがある
      - 各コンテナイメージのメタデータや依存ライブラリをPostgreSQL上で管理
      - 複数のイメージが同じ依存を持つことはザラなので、RDBの参照をうまく使うことで効率的に各イメージの依存性・脆弱性を管理
      - クライアントサーバ型で動作する
      - REST APIを通してスキャンを実行したり、スキャン結果を取得できる
    - [Grype](https://github.com/anchore/grype)
      - クライアントサーバ型で動作する
  - HarborなどのコンテナレジストリやAWSやGCPなどのパプリッククラウドのレジストリにも脆弱性スキャン機能が備わっている
 
### Trivyによるコンテナイメージの脆弱性スキャン
- `-ignore-unfixed`フラグで修正バージョンが出ていない脆弱性を除外できる
- 特定の脆弱性を検出から除外する場合、`.trivyignore`に記載する方法や　Open Policy Agent(OPA)を使う方法ある

### TrivyによるDockerfileのスキャン
**[Dockerfileのセキュリティのベストプラクティス 参考](https://qiita.com/bricolageart/items/b78a68f3003842beeb24)**
1. ベースイメージを最小化する
2. 最小特権ユーザー
3. イメージの検証と署名によりMITM攻撃を軽減する
4. オープンソースの脆弱性を検知、修正、監視する
5. Dockerイメージに機密情報を漏洩しない
6. 不変性のために固定タグを使用する
7. ADDの代わりにCOPYを使用
8. メタデータラベルを使用する
9. 小さくて安全なDockerイメージにマルチステージビルドを使用する
10. linter を使用する

Trivyでは「コンテナの実行ユーザーをroot以外のユーザーにする」などベストプラクティスをポリシーとして定義しており、それを満たしているかチェックしてくれる 
- 実行してみた結果'apt-get'によるインストールでは、イメージサイズを最小化するために'--no-install-recommends'を使うべきである。とでた！
- Dockerfileのスキャンにビルトインポリシーとして[aquasecurity/defsec](https://github.com/aquasecurity/defsec)のポリシーを使用
　　- このビルトインポリシー以外にも独自に定義したカスタムポリシーを利用でき、検知項目を追加できる
- TrivyのポリシーはRego言語で記述する
  - RegoはOpen Policy Agentのポリシーエンジンで利用されている言語で、Policy as Code(ポリシーをコードで管理)という考え方で実践

## 4.3 セキュアなコンテナイメージを作る
### コンテナにクレデンシャルを含めずにビルドする
- クレデンシャルをレイヤに残さない方法として、ここではdocker buildの`-sercret`オプションを使う方法とマルチステージビルドを使った方法を紹介

### docker build --sercretを使った機密データのマウント
- `Buildkit`が採用されdockerコマンド実行時に`DOCKER_BUILDKIT=1`環境変数を設定するか、Dockerデーモンの設定ファイル`/etc/docker/daemon.json`を以下のように設定する
```json
{
  "features": {
    "buildkit": true
  }
}
```

```Dockerfile
FROM alpine

# idに識別のためのIDを、targetにマウント先のファイルパスを指定する　　　　クレデンシャルのファイルがマウントされるため、レイアに残らない
RUN --mount=type=secret,id=mysecret,target=/secret.text
```
```bash
# idにDockerfileで指定したIDを、srcにホスト側にある機密データのファイルパスを指定する
DOCKER_BUILDKIT=1 docker build -t test:latest --sercret id=mysecret,src=$(pwd) secret.text
```

### マルチステージビルドで最終成果打つだけイメージに含める
```Dockerfile
FROM golang:1.16 AS builder
WORKDIR /go/src/github.com/user/repo
COPY app.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o app .

FROM alpine:latest
COPY --from=builder /go/src/github.com./user/repo/app ./
CMD ["./app"]
```

### コンテナイメージへの署名による改ざん対策
- サプライチェーン攻撃への対策の1つに、コンテナイメージへの署名とその検証
　　- コンテナイメージの公開者しか知り得ない秘密鍵を使ってコンテナイメージに署名し、使用者はペアとなる公開鍵で検証を行う(これにより実行する前に改ざんを検知できる)
- Docker Content Trustによる署名と検証
  - Docker Content Trustとはイメージ作成者が特定のイメージタグにデジタル署名し、イメージ利用者がそれを検証できる仕組みのこと
  - Docker Content Trustを使うにはレジストリの他にNotaryと呼ばれるサーバーが必要
  - Notaryでは階層を持つ複数の鍵が必要
    - Root Key
    - Target Key
    - Delegation Key
  - その他いくつもの鍵を作成する必要があるが全てdocker push時に自動で作成される
  - Root KeyやTarget Keyはデフォルトで`~/.docker/trust/private`に保存されるので必ず安全な場所にバックアップをとっておく
  - 次回から同一リポジトリにpushする場合に、Target Keyのパスフレーズが求められる。
  - イメージが署名されているかどうかはdocker trust inspectコマンドで確認できる
  - また、DOCKER_CONTENT_TRUST=1を設定した状態でdocker pullなどを実行すると署名の検証が強制され、イメージに署名がない場合エラーになる
- sigstoreによる署名と検証
  - sigstoreとは開発者がリリースするファイルやバイナリ、コンテナイメージなどに対して安全にかつ容易に署名できる仕組みを提供するオープンソース
  - Cosign
    - コンテナイメージへの署名や検証に使用されるツール
  - Fulcio
    - 一時的な証明書を発行するルート認証局
  - Rekor
    - Transparencyログや署名されたメタデータを記録する
  - 署名のハードルが高い理由の1つに、「秘密鍵を安全に保管し、都度署名を行う」という鍵管理の難しさがある
  - そこでsigstoreは「OpenID Connectによって取得した署名者の認証情報を下に、短時間有効な署名用の鍵を発行して署名できる仕組み」を提供している
  - 用途として、Github ActionsのWorkflowのようにプラグラムでIDトークンを取得できる場合は、人間が認証する必要がなく、プログラマブルに認証できる
  - またsigstoreはKubernetes上にデプロイされるコンテナイメージを検証するPolicy ControllerやGitのcommitにも署名できるような実装を提供している
 
### Dockerfileのベストプラクティス
