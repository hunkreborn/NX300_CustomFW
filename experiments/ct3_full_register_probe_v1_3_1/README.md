# CT3 full register probe v1.3.1

Substitua o `autoexec.sh` do cartão por este arquivo. A v1.3 anterior recebeu
todos os comandos, mas o `strace` antigo perdeu sincronização por ter sido
anexado durante um `msgrcv()` não incluído no filtro.

Esta correção rastreia `msgrcv,write` e espaça as leituras em 100 ms. Aguarde
aproximadamente 30 segundos antes de desligar a câmera.

Envie:

```text
CT3_FULL_V1_3_1.LOG
CT3_FULL_REGISTER_TRACE_V1_3_1.LOG
```

Continua sendo um teste somente leitura do sensor.
