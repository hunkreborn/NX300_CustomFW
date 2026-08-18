# CT3 live/read synchronization v1.4.1

Teste curto para corrigir a captura após `cis live`. A configuração factory-live
ocorre antes de anexar o `strace`; somente `info` e três leituras são rastreados.
O trace é desanexado antes de `cis stop`.

Envie por FTP, execute pelo Telnet e recupere:

```text
CT3_LIVE_READ_SYNC_V1_4_1.LOG
CT3_LIVE_READ_SYNC_TRACE_V1_4_1.LOG
```

Há limpeza por trap e watchdog de 15 segundos.
