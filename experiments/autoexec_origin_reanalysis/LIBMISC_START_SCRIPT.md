# `libmisc.so`: `start_script`, worker e `stop_script`

Binario analisado:
`TIZEN/project/NX300/image/rootdir_3-5/usr/lib/libmisc.so`

- SHA-256: `188d1c695b06703d2cd52be3d81425dd8978a6934fc2ad8bb94d1d212cee9b59`
- Build ID: `851181f48c36e8f66453868d366fa2f69c1b43c7`
- `start_script`: `0x00001398`, 228 bytes
- `stop_script`: `0x0000147c`, 124 bytes
- worker local: `0x000012c4`
- `script_name`: `0x00009a4c`, 21 bytes, valor
  `/mnt/mmc/autoexec.sh\0`

## Fluxo reconstruido

### `start_script()` — PROVEN

```c
int start_script(void)
{
    char path[1024];
    int rc;

    sprintf(path, "%s/%s", "/mnt/mmc", "autoexec.sh");
    if (access(path, R_OK) != 0)
        return -1;

    pthread_mutex_lock(&script_mutex);
    if (script_tid != 0) {
        puts("script thread already use");
        pthread_mutex_unlock(&script_mutex);
        return -1;
    }

    rc = create_thread(&script_tid, script_worker_12c4, NULL);
    if (rc != 0) {
        puts("script thread create error");
        pthread_mutex_unlock(&script_mutex);
        return -1;
    }
    pthread_mutex_unlock(&script_mutex);
    return 0;
}
```

Evidencias:

- `0x13b8..0x13d4`: `sprintf(path, "%s/%s", "/mnt/mmc", "autoexec.sh")`.
- `0x13dc`: `access@plt`, com `r1=4` (`R_OK`).
- `0x13f4`: lock do mutex.
- `0x1404..0x141c`: testa o slot de thread e passa `0x12c4` a
  `create_thread`.
- `create_thread` em `0x0d6c` usa atributo detached e `pthread_create`.

Nao ha `stat`, `open`, validacao de owner/hash ou verificacao de permissao de
execucao. A unica precondicao e legibilidade via `access(..., R_OK)`.

### Worker `0x12c4` — PROVEN

```c
static void *script_worker_12c4(void *unused)
{
    char path[1024];
    char chmod_cmd[1024];

    prctl(PR_SET_NAME, "Script Thread", 0, 0, 0);
    pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, NULL);
    pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS, NULL);

    sprintf(path, "%s/%s", "/mnt/mmc", "autoexec.sh");
    sprintf(chmod_cmd, "chmod u+rx %s", path);
    system(chmod_cmd);

    for (;;) {
        system(path);
        misc_sleep(1000);
        pthread_testcancel();
    }
}
```

Evidencias:

- `0x12e8`: `prctl(15, "Script Thread", ...)`, onde 15 e `PR_SET_NAME`.
- `0x12f4` e `0x1300`: cancel state 0 e cancel type 1.
- `0x1324..0x1348`: composicao do pathname e de `chmod u+rx %s`.
- `0x134c`: primeiro `system`, para o chmod.
- `0x1354`: `system(path)`.
- `0x135c`: `misc_sleep(1000)`.
- `0x1360`: `pthread_testcancel`, seguido do branch de volta a `0x1354`.

Consequencias:

- **PROVEN:** a thread e detached e o aplicativo continua em paralelo.
- **PROVEN:** cada invocacao do script e sincrona somente dentro do worker,
  porque `system()` bloqueia essa thread ate o shell terminar.
- **PROVEN:** apos o retorno do script, ele e chamado novamente apos cerca de
  1000 ms. Nao e um executor one-shot.
- **PROVEN:** `system()` implica `/bin/sh -c`; nao ha `fork/exec/execl` direto
  em `libmisc.so`.
- **INFERENCE:** um script que retorna rapidamente pode repetir mounts, daemons
  ou experimentos indefinidamente; todo autoexec seguro precisa de guard
  idempotente/one-shot.

### `stop_script()` — PROVEN

```c
int stop_script(void)
{
    int rc = 0;
    pthread_mutex_lock(&script_mutex);
    if (script_tid != 0) {
        rc = pthread_cancel(script_tid);       // destroy_thread, 0x0dcc
        script_tid = 0;                        // mesmo se cancel falhar
        if (rc != 0)
            puts("script thread destroy error");
    }
    pthread_mutex_unlock(&script_mutex);
    return 0;
}
```

- `destroy_thread` em `0x0dcc` e um branch direto para `pthread_cancel@plt`.
- Nao ha `pthread_join`, coerente com a criacao detached.
- Cancelamento assincrono pode interromper o worker dentro de `system()`.
- O slot e zerado mesmo quando `pthread_cancel` falha; isso pode permitir uma
  segunda thread enquanto a primeira ainda existe. Essa e uma fragilidade
  teorica da implementacao, nao observada dinamicamente.

