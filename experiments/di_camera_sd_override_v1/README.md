# di_camera_sd_override_v1

## Objetivo

Provar que `/usr/bin/di-camera-app-nx300` pode ser substituído durante apenas um
boot por um bind mount originado em `/tmp`, sem modificar UBIFS/NAND. O payload
v1 é uma cópia byte-a-byte, sem patches, do executável original do rootfs OSS.

Este pacote foi apenas preparado localmente. Não foi executado na câmera.

## Análise da ordem de boot

O desktop entry executa `/usr/bin/di-camera-app`, symlink para
`di-camera-app-nx300`. O launchpad é iniciado por `/usr/etc/X11/xinitrc`, depois
da inicialização de X, através de `/etc/rc.d/init.d/launchpad_run`.

A árvore OSS não contém o componente que chama `/mnt/mmc/autoexec.sh`. Logs de
experimentos anteriores provam que o hook roda cedo, inclusive antes de Wi-Fi,
mas não provam formalmente que ele sempre termina antes do launchpad. Por isso o
script faz duas verificações de PID e aborta sem bind se o app já estiver ativo.
O primeiro boot do teste é também a confirmação empírica da ordem.

## Layout esperado no SD

Não substitua o autoexec atual ainda. Quando o teste for explicitamente
autorizado, preserve uma cópia dele e disponha os arquivos assim:

```text
/mnt/mmc/autoexec.sh
/mnt/mmc/di_camera_sd_override_v1/payload/di-camera-app-nx300
```

O `autoexec.sh` deste diretório é o candidato de teste, não foi instalado.

## Sequência fail-safe

1. Cria exclusivamente `/tmp/di_camera_sd_override_v1.log`.
2. Aborta se `di-camera-app` já estiver rodando.
3. Verifica SHA-256 do alvo original antes de qualquer mount.
4. Verifica SHA-256 do payload no SD.
5. Copia o payload para `/tmp/di-camera-app-nx300` e aplica modo 755.
6. Verifica novamente hash e identidade dev/inode.
7. Repete o teste de PID imediatamente antes do bind.
8. Executa o bind mount.
9. Confirma hash e que o alvo passou a ter o dev/inode do arquivo em `/tmp`.
10. Se a validação posterior falhar, tenta desmontar imediatamente.

Hash esperado:

```text
c3932e60f75df886ed5484470be91f2d9ca8f3d6e2c9944cdd0060561fe852a7
```

## Log e interpretação

O único log runtime é:

```text
/tmp/di_camera_sd_override_v1.log
```

`RESULT=SUCCESS` e igualdade entre `TARGET_DEV_INODE_AFTER` e `TMP_DEV_INODE`
provam o bind. `RESULT=FAIL` informa a etapa e garante que nenhuma montagem
permaneceu, salvo se aparecer `FAILSAFE_UNMOUNT=FAILED_REBOOT_PHYSICALLY`.

## Rollback

O rollback suportado é desligar e ligar fisicamente a câmera. `/tmp` é volátil e
bind mounts não sobrevivem ao boot. O arquivo original em NAND nunca é escrito.
Para o boot seguinte, restaure/remova o autoexec de teste no SD.

Não usar `kill`, não desmontar UBIFS, não escrever NAND e não substituir o ELF
original.
