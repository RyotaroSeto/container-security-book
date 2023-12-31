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
Dockerなどの多くのコンテナはCPUやメモリのリソース使用量のデフォルト値に制限をかけていないため、Dos攻撃やバグで高負荷になった場合、ホスト側も高負荷になってしまい、他のコンテナに影響を及ぼすため、リソースの使用量を制限する必要がある。

### CPU使用率の制限
- コンテナのCPU使用率を制御するには`--cpus`オプションでCPUコア数を指定する
  - 8コアのCPUを搭載しているホストで、CPU使用率を50%に抑えたい場合は4(4÷8=0.5=50%)を指定する。これにより8コアのうち4コア分までCPUを使用許可がでる
  - `--cpu`オプション以外にも`--cpu-period`と`--cpu-quota`を使用して指定時間あたりの上限を設定できる
```bash
docker run --rm -it --cpus 4 ubuntu bash
```

### メモリ使用量の制限
- 時間経過でメモリ使用量が増加するメモリリークのようなバグ、Dos攻撃によるメモリ使用量を大きく消費などはコンテナのメモリ使用量を制限することで緩和策になる
- メモリ使用量の制限をかけるには`--memory`オプションを指定する
- もし制限をかけたサイズ以上のメモリを使用したら、そのプロセスはOOM Killerによって強制的に終了させられる。
- OOM Killerによってプロセスを強制終了させたくない場合、`--oom-kill-disable`オプションでtrueの指定か、`--oom-score-adj`オプションでoom_score_adjの調整をする
```bash
docker run --rm -it --memory 1G ubuntu
```

### プロセス数の制限
- Fork爆弾のような攻撃により、新規にプロセスを作成できなくなったり、プロセスの生成に時間がかかってしまったりすることがある。
- このような攻撃にはコンテナごとにプロセス数の制限をかけることが対策
- Dockerでは`--pids-limit`オプションでコンテナ内で実行されるプロセス数の上限を設定できる。
```bash
docker run --rm -it --pids-limit 10 --name pids-limit-test ubuntu bash
```

### ストレージ使用量の制限
- コンテナのルートファイルシステムやDockerボリュームは、記憶装置としてホストのストレージや外部のファイルストレージが使用される。
- そのため、サイズの大きいファイルが大量に作成されることによりストレージ容量が圧迫され、ディスクフルになることがある。
- それを防ぐためにコンテナのルートファイルシステムや使用しているボリュームに容量制限を適用するべき
- Dockerでは`--storage-opt`オプションを使うことで、コンテナのルートファイルシステムの容量を制限できる。
- ただし`--storage-opt`オプションは以下の上限を満たす必要がある
  - ストレージドライバがDevice Mapper,btrfs,zfsのいずれがであること
  - ストレージドライバがoverlay2であり/var/lib/docker配下がpquotaをサポートしているXFSでマウントされていること
- 現在しようしているストレージドライバはdocker infoで確認できる
- デフォルトではoverlay2になっている。
- ストレージドライバは/etc/docker/daemon.jsonにて変更できる
```bash
docker run --rm -it --storage-opt size=1G ubuntu bash
```

### cpulimitとulimitを使ったリソース制限
- cgroups以外でリソース制限する方法として`cpulimit`と`ulimit`がある
- `cpulimit`はSIGSTOPとSIGCONTシグナルをぬねにプロセスに送信することで、プロセスのCPU使用量を制御するツール
  - CPUの使用を0.5コア分にしたい場合は以下
```bash
docker run ubuntu cpulimit --limit=50 --include-clildren
```
- メモリ使用量やプロセス数を制限するには`ulimit`を使う
  - VSZ(仮想メモリ)に使用量を1GBに制限するのは以下
```bash
docker run ubuntu sh -c "ulimit -v 1048576;"
```

## 5.5 コンテナ実行ユーザーの変更と権限昇格の防止
### コンテナ実行時のユーザーの変更
- Dockerfile内でUSER命令を使用したり、docker runコマンドに--userオプションを使用したりすることで、ユーザーを変更できる

### User Namespaceの使用
- Linux Namespacesの中にはUser Namespaceと呼ばれるNamespaceがある。
  - これはホスト側のUID/GIDとは別に、Namespace内で独立したUID/GIDを持つことができるように分離できるもの
- User Namespaceに加えてIDマッピングと呼ばれる仕組みを使うことで「ホスト側ではUID 1000で動作しているが、コンテナないではUID 0で動作しているように見せかける」ことができる
  - これによりrootとして動作することが求められるアプリケーションを安全に動かすことができる
- User Namespaceは`unshare`コマンドの-Uフラグで分離できる。また。-rオプションでNamespace内のrootユーザーと実行時のユーザーをマッピングできる

### 非rootユーザーでランタイムを実行する(Rootlessモードを使用する)
- コンテナを非rootで動かす方法を上記で紹介したが、コンテナの実行ユーザーを変更してもDockerデーモンなどのランタイムはrootで動作している
  - ランタイムに脆弱性がある場合、ホスト側のrootを取得される可能性があるため、Dockerにはランタイム自体も非rootで動かすRootlessモードがある
- [Rootlessモードを使用する方法](https://docs.docker.com/engine/security/rootless/)
- Rootlessモードには以下のような制約がある
  - cgroup v2でなければ--cpusや--memory,--pids-limitなどのフラグを使ったリソース制限ができない
  - docker infoコマンドを実行し、Cgroup Driverの値がnoneになっている場合や、Cgroup Versionの値が1の場合は条件を満たしていないことになる
  - AppArmorやCheckpointなどの機能が使用できない
  - 使用できるストレージドライバに制約がある。例えばoverlay2を使うにはUbuntuベースのカーネルか、5.11以上のカーネルを使用する必要あいr
  - Host networkは使用できない

### No New Privilegesによる権限昇格の防止
- コンテナの中にsetuidされたバイナリがある場合、権限昇格する恐れがある
- このような権限昇格を防ぐために、Dockerでは--security-opt=no-new-privilegesというオプションがある
  - これはprctlすすテムコールでPR_SET_NO_NEW_PRIVSフラグを使用し、コンテナで実行するプロセスが新しい特権を取得することを禁止する機能

## 5.6 セキュアなコンテナランタイムの使用
- ホスト側のカーネルを共有していることは変わらないため、カーネルの脆弱性を悪用される恐れがあり、ホストとしての分離レベルは弱いまま
- 以下では軽量で高速なコンテナの特性を維持しつつ、ホストとの分離レベルを強力にするセキュアなランタイム
  - gVisor
  - Sysbox
  - Kata Containers
 
## 5.7 セキュアに運用するためのガイドライン
以下はDockerやLinuxコンテナのセキュリティベストプラクティスをまとめている
- CIS Benchmark
- OWASP Docker Security Cheatsheet
- NIST SP.800-190 Application Container Security
