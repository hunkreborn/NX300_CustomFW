# Cadeia de boot e ponto do autoexec

## Cadeia reconstruida

```text
kernel / init
  -> /etc/init.d/rcS e runlevel
     -> xserver -> /usr/bin/startx
        -> xinit /usr/etc/X11/xinitrc -- Xorg
           -> launchpad_run (se /tmp/alaunch ainda nao existe)
              -> launchpad_preloading_preinitializing_daemon
              -> ac_daemon
           -> enlightenment_start -profile samsung
              -> requisicao AUL/launchpad do camera app (origem inicial exata desconhecida)
                 -> execv do caminho consultado no AIL/.app_info.db
                    -> /usr/bin/di-camera-app-nx300
                       -> evento de cartao montado
                          -> UI_Event_Card_Mounted
                             -> libmisc:start_script
                                -> thread detached
                                   -> system("/mnt/mmc/autoexec.sh")
```

## Componentes confirmados

- **PROVEN:** `xinitrc` inicia `launchpad_run` antes de
  `enlightenment_start`.
- **PROVEN:** `launchpad_run` cria `/tmp/alaunch` modo 1777 e inicia os dois
  daemons em background.
- **PROVEN:** o launchpad contem `execv`, consulta AIL e a propriedade
  `AIL_PROP_EXEC_STR`, e possui rotinas internas nomeadas por strings
  `_get_app_info_from_db_by_pkgname`, `__prepare_exec`, `__real_launch`,
  `__preload_exec` e `__normal_fork_exec`.
- **PROVEN:** `.app_info.db` registra
  `com.samsung.di-camera-app-nx300` com exec e `x_slp_exe_path` iguais a
  `/usr/bin/di-camera-app-nx300`.
- **PROVEN:** o desktop declara `Exec=/usr/bin/di-camera-app`; esse caminho e
  symlink relativo para `di-camera-app-nx300`.
- **PROVEN:** `/opt/share/preload_list.txt` contem apenas bibliotecas de
  appcore/Ecore; nenhum caminho no SD.
- **PROVEN:** `/opt/share/preexec_list.txt` aponta `user-prepare.so` em
  `/usr/lib`, tambem fora do SD.

## Quem solicita o primeiro launch — UNKNOWN

A configuracao startup do Enlightenment presente em
`/opt/home_org/root/.e/e/applications/startup/.order` esta vazia. Nenhum arquivo
textual no corpus liga diretamente Enlightenment ao app; a requisicao pode vir
de estado/config Eet, de um modulo proprietario ou de logica AUL. O processo
observado com PPid 1 e compativel com fork/preinitialization e reparenting do
launchpad, mas isso isoladamente nao identifica o solicitante.

Esta lacuna nao altera a ordem do autoexec: o call esta dentro do processo do
app e depois do evento de storage, portanto necessariamente posterior ao
primeiro exec.

## Cartao e aliases

- **PROVEN:** `rootdir` e `rootdir_3-5` contem `sdcard -> /mnt/mmc`.
- **PROVEN:** `libmisc` usa diretamente `/mnt/mmc/autoexec.sh`.
- **PROVEN:** `usr/scripts/alt.sh` copia a si mesmo para
  `/sdcard/autoexec.sh`; `format.sh` trata `/sdcard/` como mountpoint do cartao.
- **INFERENCE:** `alt.sh` e evidencia de teste/fabrica que consome a feature,
  nao e o componente que a dispara no boot comum.

## Busca por hook anterior controlado pelo SD

Nos scripts `rcS`, xserver, startx, xinitrc e launchpad_run nao foi encontrada
nenhuma execucao/source de arquivo em `/mnt/mmc` ou `/sdcard` antes do launchpad.
O unico `LD_LIBRARY_PATH` de boot encontrado e `/usr/lib:./lib`, sem SD.

- **STRONG EVIDENCE:** nao existe hook SD textual, documentado no corpus, antes
  do primeiro exec do app.
- **UNKNOWN:** codigo de bootloader/initramfs, configuracoes Eet ou interfaces
  de factory podem conter um hook nao textual; nenhum foi provado nesta rodada.
- **PROVEN:** editar `.app_info.db`, init, desktop, preload/preexec ou o symlink
  tocaria rootfs/UBI/NAND ou areas persistentes e viola a preferencia zero NAND.

