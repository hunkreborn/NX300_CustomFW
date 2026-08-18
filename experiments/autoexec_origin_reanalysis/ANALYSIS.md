# Analise consolidada

## Respostas diretas

1. **Quem chama `start_script`? — PROVEN:** `UI_Event_Card_Mounted()` na build
   417516, em `0x1c27b0`.
2. **Qual funcao contem o endereco? — PROVEN:** intervalo
   `0x1c1de0..0x1c27c4`, confirmado por symtab e DWARF da mesma Build ID.
3. **Quando roda? — STRONG EVIDENCE:** no fluxo normal do evento de cartao
   montado, depois de registrar callbacks, consultar storage e revalidar o
   estado do cartao; pode ser alcançado via message queue ou idle callback.
4. **Como constroi/executa? — PROVEN:** `sprintf("%s/%s", "/mnt/mmc",
   "autoexec.sh")`, `access(R_OK)`, worker detached, `system("chmod u+rx ...")`
   e loop `system(path); sleep(1000); pthread_testcancel()`.
5. **Sincrono? — PROVEN:** assincrono para o app; cada `system` e sincrono
   apenas na thread worker.
6. **Lifecycle exato? — PROVEN/STRONG EVIDENCE:** depois do primeiro exec e
   durante inicializacao/reconhecimento do storage; nao e pre-init nem initrc.
7. **Quando `stop_script`? — PROVEN:** `UI_Close_FileManager`, chamado por
   `UI_Manage_Event_On_Off`; cancela a thread ao fechar/desligar o gerenciador de
   storage.
8. **Hook anterior sem NAND? — UNKNOWN:** nenhum foi encontrado/provado.
9. **Melhor estrategia reversivel? — STRONG EVIDENCE:** staging por bind com o
   processo original vivo e uso de um segundo exec gracioso; se relaunch nao for
   viavel, patch runtime estritamente guardado por hash.

## Root cause

O PID guard do override v2.1 nao perdeu uma corrida pequena. Ele observou a
ordem arquitetural correta: o aplicativo precisa estar vivo, receber o evento
de montagem e chamar `start_script` antes que o autoexec exista. Mover hashes ou
Dropbear depois do bind nao pode corrigir essa causalidade.

Adicionalmente, `libmisc` repete o script. Isso torna obrigatorios marcadores
one-shot/idempotencia para qualquer teste futuro; do contrario, a mesma mutacao
pode ser reaplicada a cada segundo.

## Nova errata de versao

O historico dizia que o chamador do autoexec nao existia no OSS. Isso e falso
para `rootdir_3-5`/`imagedev`: existe implementacao completa em `libmisc.so` e
caller com DWARF. A afirmacao continua verdadeira apenas para a variante
`rootdir` Build 32, que nao depende de `libmisc`.

Nao se pode misturar automaticamente as builds. O hash do payload v2.1
`c393...` e Build 32; o caller estudado e Build 417. A camera nao foi consultada
e o log anterior abortou antes de provar o hash real.

## Limitacoes abertas

- **UNKNOWN:** componente exato que envia ao AUL a primeira requisicao de
  launch do camera app.
- **UNKNOWN:** hash/Build ID da camera real na sessao do experimento anterior.
- **UNKNOWN:** semantica exata do relaunch gracioso AUL para este pacote.
- **UNKNOWN:** se launchpad reutiliza preinitialization de modo que o segundo
  launch nao faca um `execv` novo em todos os cenarios.
- **HYPOTHESIS:** um watchdog independente iniciado pelo autoexec pode
  sobreviver a uma transicao do app e auditar o segundo exec; precisa teste
  controlado.

## Integridade da investigacao

- CAMERA MUTATIONS: **NONE**
- ORIGINAL FILES MODIFIED: **NONE**
- NETWORK/CAMERA ACCESS: **NONE**
- ARM BINARIES EXECUTED: **NONE**

