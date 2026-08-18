# di_camera_sd_override_v2.1

Preparado exclusivamente no workspace; não copiado nem executado na câmera.

## Ordem temporal

1. `devpts`, HTTP e inetd sobem primeiro como recuperação.
2. O primeiro `pidof` ocorre antes de SHA-256, cópia ou Dropbear.
3. O payload original é validado no rootfs, SD e `/tmp`.
4. O segundo `pidof` ocorre imediatamente antes da leitura de uptime e do bind.
5. O bind é validado por hash e dev:inode.
6. Um watcher somente leitura aguarda até aproximadamente 20 segundos pelo app.
7. Só então os artefatos Dropbear são preparados em `/tmp` e o daemon é pedido.

Uma falha normal do override registra `OVERRIDE_RESULT=FAIL` ou `SKIPPED` e não
impede o Dropbear. Se um bind foi aplicado mas sua pós-validação falhou, o script
tenta `umount` e confirma a restauração do dev:inode original. Se isso não puder
ser confirmado, registra `REBOOT_REQUIRED=1`, não prepara Dropbear e não executa
outras operações mutantes.

## Verificação do ELF realmente executado

Depois de um bind validado, o watcher registra PID, destino de `/proc/$PID/exe`,
dev:inode do executável e dev:inode de `/tmp/di-camera-app-nx300` no único log:

```text
/tmp/di_camera_sd_override_v2.log
```

Identidades iguais produzem `EXEC_VERIFY=BOUND_PAYLOAD`; diferentes, falha de
leitura ou timeout produzem `EXEC_VERIFY=ORIGINAL_OR_RACE`. O watcher nunca mata,
reinicia, sinaliza ou anexa ao processo.

## Payload e SD

O payload local `di-camera-app-nx300-test` é cópia byte a byte do original:

```text
c3932e60f75df886ed5484470be91f2d9ca8f3d6e2c9944cdd0060561fe852a7
```

Layout esperado somente quando houver autorização futura:

```text
/mnt/mmc/autoexec.sh
/mnt/mmc/di-camera-app-nx300-test
/mnt/mmc/dropbear-nx300-v3
/mnt/mmc/authorized_keys
/mnt/mmc/nx300_hostkey.b64
/mnt/mmc/inetd.conf
```

Nenhum diretório persistente de experimento é criado no SD. Runtime do payload,
SSH, PID e log permanece em `/tmp`. O bind é a única mudança fora de `/tmp` e é
volátil; rollback suportado é reboot físico.

## Limite de corrida

A árvore OSS ainda não contém o chamador de `/mnt/mmc/autoexec.sh`; portanto a
precedência sobre `launchpad_run` não é formalmente provada. Mover Dropbear para
depois do bind reduz bastante a janela, mas continua existindo um intervalo não
atômico entre o segundo `pidof` e `mount --bind`. Os timestamps e o watcher foram
incluídos para medir o resultado real sem interferir no camera app.
