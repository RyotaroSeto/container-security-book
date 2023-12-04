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

## 5.3 ファイルアクセスの制限

## 5.4 リソースの制限
