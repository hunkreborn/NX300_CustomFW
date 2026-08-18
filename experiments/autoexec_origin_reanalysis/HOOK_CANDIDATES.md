# Candidatos de hook reversivel

Escala: VERY HIGH, HIGH, MEDIUM, LOW, VERY LOW. `Persistencia` descreve o que
seria necessario, nao uma autorizacao para executar.

| Mecanismo | Viabilidade | Risco | Persistencia | Reversibilidade | NAND | Modos/bitrate |
|---|---|---|---|---|---|---|
| Bind de payload enquanto app original roda + relaunch gracioso via AUL | HIGH | MEDIUM | SD + `/tmp` + bind | reboot | nao | HIGH |
| Patch inline/GOT por ptrace no processo atual | HIGH | HIGH | RAM apenas | reboot/restaurar bytes | nao | VERY HIGH |
| Interface factory/shell suportada chamando funcoes existentes | MEDIUM | MEDIUM | SD/`/tmp` | reboot | nao | MEDIUM |
| Plugin/dlopen solicitado pelo app a partir do SD | LOW | MEDIUM | SD | reboot | nao | HIGH se existir |
| `LD_PRELOAD`/`LD_LIBRARY_PATH` antes do primeiro exec | VERY LOW | MEDIUM | exigiria hook pre-launch | reboot se RAM | nao em teoria | VERY HIGH |
| Alterar AIL DB/desktop/preload_list/symlink | HIGH tecnica | HIGH | UBI/rootfs | persistente | sim/UBI | VERY HIGH |
| Bind feito pelo autoexec antes do primeiro exec | VERY LOW | LOW | SD + RAM | reboot | nao | HIGH |
| Boot alternativo/recovery integral pelo SD | UNKNOWN | VERY HIGH | SD/boot path | depende | nao em teoria | VERY HIGH |

## Melhor early hook encontrado

**UNKNOWN para o primeiro exec.** Nao ha mecanismo SD/`/tmp` provado que rode
antes do primeiro `execv` do camera app. O autoexec nao pode cumprir essa funcao
porque nasce dentro de `UI_Event_Card_Mounted()`.

O melhor substituto pratico e um **second-exec hook**:

1. o app original inicia e dispara o autoexec;
2. autoexec valida a build e faz bind de um payload sobre o pathname enquanto o
   processo original continua rodando;
3. o mapping e `/proc/PID/exe` do processo atual permanecem no inode original;
4. uma solicitacao de lifecycle suportada encerra/reabre o app sem `kill`;
5. o proximo `execv` do launchpad resolve o pathname ja sobreposto.

Isso elimina a corrida entre saida e bind, porque Linux permite sobrepor o nome
de um executavel que ja esta mapeado sem trocar as paginas do processo atual.
A incerteza e o relaunch: ainda falta provar qual requisicao AUL encerra e
relanca este app e se o launcher aplica algum cache/preload especial.

## Melhor runtime hook

**Patch de memoria com ptrace**, limitado a bytes previamente verificados e a
uma build/hash exatos. Ele permite alterar diretamente
`UI_Get_Video_Bit_Rate`, `UI_Get_Movie_Frmae_By_Movie_Size` ou call sites sem
reiniciar o app e desaparece no reboot.

Vantagem: nao depende de resolver o primeiro exec. Risco: um tracer anterior ja
congelou temporariamente a camera quando o detach falhou; portanto precisa de
watchdog externo, `__WALL`, restauracao dos bytes originais, detach garantido e
teste inicial em funcao sem efeito. E um candidato tecnicamente forte, mas nao
o primeiro experimento recomendado.

## Mecanismos enfraquecidos

- **LD_PRELOAD:** o launchpad reconhece essa variavel, mas nenhum canal SD
  anterior foi encontrado para defini-la no ambiente do daemon/app.
- **Shared-library bind apos launch:** nao altera objetos ja mapeados; so teria
  efeito no segundo exec ou num `dlopen` futuro. O app nao importa `dlopen`.
- **PATH/symlink:** launchpad usa o caminho absoluto da DB; o PATH nao oferece
  interposicao. Alterar o symlink e persistente.
- **Autoexec bind com PID guard:** o guard torna o objetivo impossivel nessa
  build, pois o PID necessariamente existe antes do call a `start_script`.

## Proximo experimento recomendado

`di_camera_second_exec_stage_v1`, ainda a ser preparado/revisado:

- payload inicialmente byte-identico **a build instalada confirmada**;
- o autoexec, com marcador one-shot, valida hash/build e faz bind mesmo com o
  app vivo;
- nao encerra, mata nem relanca o app;
- registra apenas `stat`/`readlink` de `/proc/$PID/exe`, do pathname bound e do
  payload para provar que o processo atual preservou o inode original;
- rollback: reboot fisico.

Essa primeira etapa valida a propriedade essencial sem assumir o mecanismo de
relaunch. Somente uma v2 posterior, autorizada separadamente, deve testar uma
transicao AUL graciosa.

