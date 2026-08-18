# CT3 live/read synchronization v1.4.2

Igual à v1.4.1, mas o `strace` não usa filtro de syscalls. Isso inclui a
`msgget()` que estava em andamento no momento da anexação e evita deslocar os
retornos no rastreador ARM antigo.

O ensaio lê somente `0340`, `0342` e `3404`, com `cis stop`, trap e watchdog.

Arquivos resultantes:

```text
CT3_LIVE_READ_SYNC_V1_4_2.LOG
CT3_LIVE_READ_SYNC_TRACE_V1_4_2.LOG
```
