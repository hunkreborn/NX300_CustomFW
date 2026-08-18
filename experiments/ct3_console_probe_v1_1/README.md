# CT3 console probe v1.1

Copie somente `autoexec.sh` para a raiz do SD, substituindo no cartão a sonda
v1 anterior. Esta versão continua somente leitura e serve para descobrir onde
o processo `di-camera-app` grava a resposta de `st cap cis regr`.

Após ligar a câmera, aguarde aproximadamente 20 segundos e desligue-a
normalmente. Envie estes arquivos do cartão:

```text
CT3_CONSOLE_V1_1.LOG
CT3_DLOG_BEFORE_V1_1.LOG
CT3_DLOG_AFTER_V1_1.LOG
```

A sonda lê somente os registradores `0340`, `0342` e `3404`. Não há `regw`,
troca de modo, reset, parada de stream ou modificação do rootfs.
