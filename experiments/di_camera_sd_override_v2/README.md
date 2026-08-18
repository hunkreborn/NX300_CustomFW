# di_camera_sd_override_v2

## Estado e objetivo

Pacote preparado somente no workspace. Não foi copiado nem executado na câmera.
Seu objetivo é provar a sobreposição de `/usr/bin/di-camera-app-nx300` durante
um único boot por um bind mount originado em `/tmp`, sem escrever UBIFS/NAND. O
payload continua byte a byte igual ao ELF original.

## Layout futuro esperado no SD

Esta versão não cria diretório persistente de experimento. Quando houver
autorização explícita para instalação, o layout esperado será:

```text
/mnt/mmc/autoexec.sh
/mnt/mmc/di-camera-app-nx300-test
/mnt/mmc/dropbear-nx300-v3
/mnt/mmc/authorized_keys
/mnt/mmc/nx300_hostkey.b64
/mnt/mmc/inetd.conf
```

O `autoexec.sh` deste pacote é apenas um candidato. O `/mnt/mmc/autoexec.sh`
atual não foi lido, substituído ou alterado nesta preparação.

## Serviços preservados e SSH

As quatro operações existentes permanecem no começo do autoexec: montagem de
devpts, httpd com raiz no SD e inetd usando `/mnt/mmc/inetd.conf`.

O SSH é reconstruído a cada boot exclusivamente em:

```text
/tmp/nxssh
/tmp/nx300_hostkey
/tmp/dropbear.pid
```

`authorized_keys` é copiado para `/tmp/nxssh/authorized_keys`, e a chave host é
decodificada de `/mnt/mmc/nx300_hostkey.b64`. O daemon usa literalmente a
invocação validada anteriormente:

```text
/mnt/mmc/dropbear-nx300-v3 -F -r /tmp/nx300_hostkey -D /tmp/nxssh -p 22 -P /tmp/dropbear.pid -j -k -m
```

Como `-F` mantém o processo em foreground, o autoexec o inicia em background
para poder chegar aos guards e ao bind. Falha na existência/preparação dos três
artefatos SSH aborta antes do bind.

## Guards do override

1. Aborta se o camera app já estiver ativo.
2. Exige hash conhecido do alvo original.
3. Exige o mesmo hash do payload no SD.
4. Copia para `/tmp/di-camera-app-nx300`, aplica 755 e verifica o hash.
5. Registra dev/inode do alvo e do arquivo em `/tmp`.
6. Repete o PID guard imediatamente antes do bind.
7. Faz somente `/tmp/di-camera-app-nx300` →
   `/usr/bin/di-camera-app-nx300`.
8. Confirma hash e igualdade dev/inode após o bind.
9. Se a pós-validação falhar, tenta desmontar o bind imediatamente.

Hash esperado:

```text
c3932e60f75df886ed5484470be91f2d9ca8f3d6e2c9944cdd0060561fe852a7
```

O único log do experimento é `/tmp/di_camera_sd_override_v2.log`.

## Ordem de boot ainda não provada

O desktop entry chama `/usr/bin/di-camera-app`, symlink para o ELF NX300. O
launchpad é iniciado por `/usr/etc/X11/xinitrc` e `launchpad_run`. A árvore OSS
não contém o chamador do hook `/mnt/mmc/autoexec.sh`; logs anteriores mostram o
hook cedo, antes do Wi-Fi, mas não provam que ele sempre termina antes do
launchpad. Os dois PID guards preservados evitam bind depois do início do app.

Existe uma janela de corrida inevitável entre o segundo `pidof` e `mount
--bind`. Eliminá-la exigiria coordenar o launcher, o que está deliberadamente
fora deste experimento. O primeiro boot autorizado continua sendo a validação
empírica da ordem.

## Rollback e limites

Rollback: desligar e ligar fisicamente. `/tmp` e bind mounts são voláteis. Não
matar/reiniciar `di-camera-app`, não escrever NAND/MTD/UBI e não desmontar o
rootfs. O autoexec inicia serviços de rede root; use somente em rede controlada.
