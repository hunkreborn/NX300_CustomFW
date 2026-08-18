# CT3 factory live probe v1.4

Este é o primeiro ensaio ativo. Ele usa somente comandos já implementados no
console de fábrica do driver CT3:

```text
cis live  -> CAquilaCt3Driver::SetupVideoNormal()
cis regr  -> leitura dos 66 registradores
cis stop  -> CAquilaCt3Driver::DisableStream()
```

Há um `trap` de limpeza e um watchdog independente de 20 segundos; ambos enviam
`cis stop`. Nenhum `regw` arbitrário é usado.

Envie por FTP:

```bash
curl -T ct3_factory_live_probe.sh \
  ftp://192.168.68.100/ct3_factory_live_probe.sh
```

Execute pelo Telnet:

```sh
/bin/sh /mnt/mmc/ct3_factory_live_probe.sh
```

O preview pode piscar ou permanecer escuro durante o teste. Se a câmera não
responder após 30 segundos, desligue-a e remova o script; nada é instalado no
rootfs.

Baixe `CT3_FACTORY_LIVE_V1_4.LOG` e `CT3_FACTORY_LIVE_TRACE_V1_4.LOG`.
