# CT3 full register probe v1.3

Copie somente `autoexec.sh` para a raiz do SD, substituindo a v1.2. Ligue a
câmera, aguarde cerca de 25 segundos e desligue normalmente.

Envie:

```text
CT3_FULL_V1_3.LOG
CT3_FULL_REGISTER_TRACE_V1_3.LOG
```

Esta versão captura 66 registradores de identificação, stream, formato,
janela, skipping/binning e timing CDS. Ela executa somente `info` e `regr`; não
há escrita, troca de modo, reset nem alteração do rootfs.
