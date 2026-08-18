# NX300 inetd console confirmado

Configuração fornecida e validada na câmera:

```text
21 stream tcp nowait root ftpd   ftpd -w /mnt/mmc/
23 stream tcp nowait root telnet telnetd -i -l /bin/bash
```

- TCP 21 expõe o cartão SD e permite escrita (`ftpd -w`).
- TCP 23 entrega Bash como root via Telnet.
- Não há autenticação nem criptografia. Use apenas em rede isolada.

O `autoexec.sh` validado monta `devpts`, serve o SD por HTTP e inicia o inetd:

```sh
mkdir -p /dev/pts
mount -t devpts none /dev/pts
httpd -h /mnt/mmc
inetd /mnt/mmc/inetd.conf
```

Assim, TCP 80 oferece download HTTP do conteúdo do cartão; TCP 21 oferece FTP
com escrita; TCP 23 oferece o shell Bash root.

Exemplos a partir do computador:

```bash
curl ftp://192.168.68.100/
curl -T ct3_full_probe.sh ftp://192.168.68.100/ct3_full_probe.sh
curl -O ftp://192.168.68.100/CT3_FULL_V1_3_1.LOG
curl -O http://192.168.68.100/CT3_FULL_V1_3_1.LOG
```

Execução pelo Telnet:

```sh
/bin/sh /mnt/mmc/ct3_full_probe.sh
```
