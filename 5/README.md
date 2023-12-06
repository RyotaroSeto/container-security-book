# 第 5 章 コンテナランタイムをセキュアに運用する

## 5.1 ケーパビリティの制限

### 不要なケーパビリティを削除する

Docker 等のコンテナランタイムは、デフォルトでセキュアになるよう、いくつかケーパビリティが付与されていないが、攻撃可能になってしまうケーパビリティが付与されていることがあるため運用上必要なければ削除するべき。

- `-cap-drop`オプションで指定したケーパビリティを削除できる

```bash
docker run --rm -it --cap-drop=NET_RAW ubuntu:20.04 bash
```

### [Docker が特権モードのプロセスにデフォルトで与える権限](https://postd.cc/secure-your-containers-with-this-one-weird-trick/)

chown, dac_override, fowner, fsetid, kill, setgid, setuid, setpcap, net_bind_service, net_raw, sys_chroot, mknod, audit_write, setfcap

## 5.2 システムコールの制限

### Seccomp によるシステムコールの制限

- Docker などはコンテナからのシステムコールの発行を Seccomp で制限している。そのためデフォルトの Seccomp プロファイルを使用していれば、ホスト側へのエスケープの可能性は低い
- Docker では Seccomp プロファイルをカスタマイズできるため、呼び出しを禁止するシステムコールを追加することで、より強固なコンテナとして実行でき、攻撃を防げる

### ファイルレスマルウェアを例にシステムコールの制限

- ファイルレスマルウェアとは?
  - マルウェアの本体であるペイロードをティスク上に書き込まず、メモリ上にだけ展開することで、フォレンジックを困難にする特性
  - このようなマルウェアはメモリ上にペイロードを展開してコードを実行する際に`memfd_create`というシステムコールが使われることがある。
  - アプリケーションが`memfd_create`システムコールを呼び出していない場合、これを禁止することで、攻撃を防げる

### Seccomp プロファイルを自動生成する

- Seccomp プロファイルを独自で作成するには、コンテナで実行するアプリケーションが呼び出しているシステムコールを把握する必要がある。
  - これには strace や eBPF を使用したアプローチがあるが docker-slim を使用した Seccomp プロファイルを自動生成方法を紹介する

```bash
brew install docker-slim
slim build --copy-meta-artifacts artifacts nginx-latest
```

- また Kubernetes 環境では [Security Profiles Operator(SPO)](https://speakerdeck.com/okepy/try-security-profiles-operator?slide=9)を使うと同様にプロファイルを生成できる
- 厳密に、アプリケーションが呼び出すシステムコールだけに限定したい場合、[libseccomp](https://github.com/seccomp/libseccomp) などのライブラリを使用して、アプリケーション自身で Seccomp を使用するように実装すると良い

## 5.3 ファイルアクセスの制限
### ファイルシステムをread-onlyでマウントしてファイルの改ざんを防止する
- アプリケーションの脆弱性を悪用してファイルを変更して、Webサイトを改ざんする攻撃がある。
  - フィッシングサイトやマルウェアの配信に利用されるだけでなく、不正なファイルを作成して実行されることもある
- 上記のような改ざんをコンテナではルートファイルシステムをread-onlyでマウントして実行できるため、ファイルが改ざんできないように構成されている。
  - 注意点としてread-onlyでマウントしても/devや/sys/fs/cgroup配下などは書き込み可能
```bash
docker run --rm -it --read-only ubuntu:20.04 bash
```
### AppArmorによるファイルアクセス制限
- 多くのコンテナランタイムはAppArmorでコンテナを保護している
- Dockerはデフォルトでdocker-defaultというプロファイルを適用している
- AppArmorもSeccompと同様に独自のプロファイルを適用でき、強固なコンテナを実現できる
## 5.4 リソースの制限
