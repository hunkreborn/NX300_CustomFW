# CT3 strace probe v1.2

Copie somente `autoexec.sh` para a raiz do SD, substituindo o autoexec da v1.1.

Esta sonda localiza a thread `shell_di_camera_app`, anexa o `strace` que já
existe no firmware e captura os `write()` feitos por essa thread ao
`/dev/console`. Em seguida lê `0340`, `0342` e `3404`.

Ela não usa `regw`, não troca modo e não modifica o rootfs. O `strace` é
desanexado automaticamente após cerca de três segundos.

Depois do teste, envie:

```text
CT3_STRACE_V1_2.LOG
CT3_REGISTER_TRACE_V1_2.LOG
```
