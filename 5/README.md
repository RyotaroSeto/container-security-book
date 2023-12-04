# 第5章 コンテナランタイムをセキュアに運用する

## 5.1 ケーパビリティの制限
### 不要なケーパビリティを削除する
Docker等のコンテナランタイムは、デフォルトでセキュアになるよう、いくつかケーパビリティが付与されていないが、攻撃可能になってしまうケーパビリティが付与されていることがあるため運用上必要なければ削除するべき。

- `-cap-drop`オプションで指定したケーパビリティを削除できる
```bash
docker run --rm -it --cap-drop=NET_RAW ubuntu:20.04 bash
```

### [Dockerが特権モードのプロセスにデフォルトで与える権限](https://postd.cc/secure-your-containers-with-this-one-weird-trick/)
chown, dac_override, fowner, fsetid, kill, setgid, setuid, setpcap, net_bind_service, net_raw, sys_chroot, mknod, audit_write, setfcap

## 5.2 システムコールの制限
### Seccompによるシステムコールの制限
- Dockerなどはコンテナからのシステムコールの発行をSeccompで制限している。そのためデフォルトのSeccompプロファイルを使用していれば、ホスト側へのエスケープの可能性は低い
- DockerではSeccompプロファイルをカスタマイズできるため、呼び出しを禁止するシステムコールを追加することで、より強固なコンテナとして実行でき、攻撃を防げる
### ファイルレスマルウェアを例にシステムコールの制限
- ファイルレスマルウェアとは?
  - マルウェアの本体であるペイロードをティスク上に書き込まず、メモリ上にだけ展開することで、フォレンジックを困難にする特性
  - このようなマルウェアはメモリ上にペイロードを展開してコードを実行する際に`memfd_create`というシステムコールが使われることがある。
  - アプリケーションが`memfd_create`システムコールを呼び出していない場合、これを禁止することで、攻撃を防げる
### Seccompプロファイルを自動生成する
- Seccompプロファイルを独自で作成するには、コンテナで実行するアプリケーションが呼び出しているシステムコールを把握する必要がある。
  - これにはstraceやeBPFを使用したアプローチがあるがdocker-slimを使用したSeccompプロファイルを自動生成方法を紹介する
```bash
docker-slim build --copy-meta-artifacts artifacts nginx-latest
```

## 5.3 ファイルアクセスの制限

## 5.4 リソースの制限
