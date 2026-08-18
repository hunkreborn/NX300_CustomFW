# Samsung NX300 Reverse Engineering — Project Context

> Documento cumulativo (append-only). Não apagar, substituir ou reescrever entradas
> anteriores. Correções e novas conclusões devem ser registradas em uma nova entrada,
> com data, hora e referência à informação anterior.

## Política do caderno

- Fuso horário dos registros: `America/Maceio` (`UTC-03:00`).
- Formato de timestamp: `YYYY-MM-DD HH:MM:SS -03`.
- Os artefatos originais devem permanecer inalterados.
- Resultados temporários de scripts e ferramentas devem ser gravados em `/tmp`.
- `PROJECT_CONTEXT.MD` mantém o panorama, decisões e índice cronológico.
- `findings.md` mantém evidências técnicas, comandos, endereços, enums, hashes e reconstruções.
- Uma informação incorreta não deve ser removida: acrescentar uma errata posterior.

## Objetivo

Realizar engenharia reversa do firmware e do aplicativo proprietário da Samsung
NX300, documentando a arquitetura e o comportamento de boot/recovery, DRIMe IV,
framework de captura, aplicativo da câmera, interface EFL/Edje, vídeo e subsistemas
de serviço/produção.

## Materiais disponíveis

- `di-camera-app-nx300-full`: executável ARM32 do aplicativo da câmera, combinado
  com informações de depuração.
- `Samsung_NX300_Service_manual.pdf`: manual de serviço.
- Árvore `TIZEN/`: BSP, kernel/imagens, rootfs, imagedev, headers, bibliotecas e
  símbolos separados de depuração.
- `build_installguide_nx300/`: material de instalação/build baseado em Scratchbox2.

## Alvos prioritários identificados

- `di-camera-app-nx300` e seus símbolos de depuração.
- `libcapture-fw-slpcam-nx300.so` e variante de debug.
- `libmmutil_movie.so.0.0.0`.
- `libproduction-commands.so`.
- `libfirmware-upgrade.so` e variante de debug.
- `dnloader.bin`, `D4_IPL.bin` e `D4_PNLBL.bin`.
- Recursos EFL/Edje em `/usr/share/edje/di-camera-app-nx300/`.
- Headers DRIMe IV e interfaces de lente presentes em `imagedev`.

## Linha do tempo

### 2026-08-09 10:15:26 -03 — Início do caderno persistente

- Criados `PROJECT_CONTEXT.MD` e `findings.md` com política append-only.
- Consolidada a primeira análise técnica de bitrate de vídeo.
- Reconstruídas `UI_Get_Video_Bit_Rate`,
  `UI_Get_Movie_Frmae_By_Movie_Size` (grafia original do símbolo) e
  `mm_util_movie_video_bit_rate`.
- Confirmada a tabela-base de bitrate, além dos multiplicadores de FPS,
  qualidade e formato estéreo/3D.
- Detalhes e evidências: seção de mesmo timestamp em `findings.md`.

### 2026-08-09 10:23:20 -03 — Triagem de expansão do firmware

- Iniciada análise de cinco trilhas: gravação 4K24, substituição dos serviços
  sociais, HDMI clean, webcam USB/Wi-Fi e uso de Bluetooth.
- A busca específica não encontrou 3840x2160 nem 4096x2160 no pipeline NX300.
- Encontradas limitações explícitas a 1080p no MFC/framebuffer e no HDMI.
- Encontrado um caminho oculto de live view HDMI 1920x1080 com limpeza do OSD,
  controlado por `eUI_CONTROL_INFO_HDMI_LIVEVIEW_DEMO`.
- Confirmada a viabilidade estrutural de USB gadget/UVC mediante novo kernel e
  integração com o pipeline de captura; o gadget webcam não está habilitado no
  kernel original.
- Confirmado que o kernel NX300 não habilita Bluetooth e a placa não apresenta
  integração Bluetooth na definição específica examinada.
- Facebook e Picasa são aplicativos separados no rootfs e podem ser excluídos de
  uma imagem customizada; Flickr não apareceu como pacote independente nesta imagem.
- Telegram Bot API é o candidato mais simples para upload; Instagram oficial é
  significativamente mais restrito e inadequado para substituir diretamente o app.
- Detalhes, evidências e classificação de viabilidade em `findings.md`.

### 2026-08-09 11:10:29 -03 — Triagem de overclock do DRIMe IV e LPDDR2

- Confirmado que o loader principal (`D4_PNLBL`) compila o Cortex-A9 a 700 MHz.
- Confirmado que o mesmo código possui configurações oficiais para 500, 600,
  700 e 800 MHz; o `dnloader` usa 800 MHz.
- CPU a 800 MHz é o primeiro candidato de teste, representando aumento de 14,3%.
- O kernel não habilita CPUFreq para o DRIMe IV; o clock é definido no bootloader
  e herdado pelo kernel.
- Confirmado que a NX300 já usa `CONFIG_LPDDR2_533MHZ`, o perfil mais rápido
  fornecido pela Samsung nessa árvore (LPDDR2-1066 efetiva).
- Overclock de RAM acima de 533 MHz exigiria PLL, timings, refresh e calibração
  novos; foi classificado como alto risco e baixa prioridade.
- Overclock da CPU não aumenta diretamente o clock do encoder MFC, que possui
  domínio separado e locks próprios de MFC/barramento.
- Evidências, hashes e estratégia de teste recuperável em `findings.md`.

### 2026-08-09 11:23:34 -03 — Comparação inicial NX300 × NX500

- Localizado o material da NX500 em `NX500/`, incluindo o service manual e a
  árvore de kernel DRIMe5.
- O manual identifica sensores fisicamente diferentes: NX500 `VB2`, BSI CMOS
  de 28,2 MP; NX300 `CT3`, CMOS de 20,3 MP.
- Confirmada na NX500 a gravação 4096x2160/24p e 3840x2160/30p (25p PAL).
- Confirmado que o DRIMe5 possui bloco HEVC dedicado, driver, registradores,
  clock próprio e parâmetros de QoS dimensionados explicitamente para UHD30p.
- Confirmados modos DVFS específicos para filme UHD e timings HDMI reais para
  3840x2160 e 4096x2160.
- Encontrado no DRM da NX500 o campo `uhd_clean_mode`: quando ativo, o driver
  deixa de enviar a camada gráfica, mantendo a janela de vídeo. Esse desenho
  reforça a viabilidade de clean HDMI na NX300 pelo caminho oculto já encontrado.
- Conclusão provisória: os registradores HEVC, timings UHD e readout do sensor
  da NX500 não são portáveis ao DRIMe IV/CT3; a arquitetura de separação entre
  vídeo e OSD no HDMI é conhecimento conceitualmente reaproveitável.
- Evidências detalhadas e próximos alvos estão em `findings.md`.

### 2026-08-09 11:36:09 -03 — Início do bring-up experimental 4K/CT3

- Reaberta a trilha 4K como pesquisa de readout, sem pressupor que os presets
  comerciais sejam o limite físico do CT3.
- A biblioteca `libcapture-fw-slpcam-nx300.so` preserva aproximadamente 12 mil
  símbolos dinâmicos e contém o driver completo `CAquilaCt3Driver`.
- Localizadas rotinas de programação direta do sensor, incluindo janela,
  skipping, timing CDS, frame timing, modos FHD/60/120/240 e full-size video.
- Descoberto um modo `SetupVideoFull()` que configura readout 5624x3714,
  12 bits e sem skipping. Isso prova que existe um caminho de vídeo full-size
  no driver e torna indispensável medir seu frame rate/throughput antes de
  concluir sobre 4K24.
- Nenhum binário original foi modificado; desassemblagens temporárias foram
  gravadas somente em `/tmp`.

### 2026-08-09 12:08:00 -03 — Sonda temporária CT3 via autoexec

- Criado `experiments/ct3_4k24_probe_v1/`, sem alterar firmware ou binários
  originais.
- O `autoexec.sh` inicia `ct3_probe.sh` em background e grava os resultados no
  cartão SD.
- A versão v1 é deliberadamente somente leitura: usa `st cap cis info` e
  `st cap cis regr`, sem `regw`, reset, parada de stream ou troca de modo.
- Confirmado por desassemblagem que `regr` converte seu argumento com `atoh()`;
  a lista hexadecimal usada pela sonda está no formato correto.
- Reconstruídos perfis internos de timing nominal para 24, 25, 30, 48, 50,
  60, 100, 120 e aproximadamente 240 fps, além do perfil full-size lento.
- O próximo passo experimental depende dos logs `CT3_PROBE_V1.LOG` e
  `ct3_probe_boot.log` gerados na câmera.

### 2026-08-09 12:24:00 -03 — Resultado da sonda v1 e roteamento do console

- Recebidos os logs reais em `experiments/logs/`.
- A sonda v1 executou integralmente como root, com a aplicação da câmera ativa,
  e encerrou normalmente; o log de boot vazio indica ausência de erro no
  launcher.
- `st` retornou sem texto porque apenas envia comandos por uma fila SysV; a
  resposta é impressa pelo processo `di-camera-app` no stdout dele.
- Criada `experiments/ct3_console_probe_v1_1/autoexec.sh`, ainda somente
  leitura, para mapear os descritores 0/1/2 e capturar o `dlog` antes/depois de
  três leituras de registrador.

### 2026-08-09 12:38:00 -03 — Resultado v1.1 e captura por thread

- Confirmado na câmera que os descritores 1 e 2 do `di-camera-app` apontam para
  `/dev/console`; o descritor 0 aponta para `/dev/null`.
- Os dumps `dlog` antes/depois são byte a byte idênticos, confirmando que os
  `printf()` do parser não passam pelo ring buffer.
- Todos os comandos da v1.1 retornaram `1`, valor de sucesso de
  `shell_sndmsg()` após `msgsnd()`.
- Criada `experiments/ct3_strace_probe_v1_2/autoexec.sh`: ela localiza apenas a
  thread `shell_di_camera_app`, anexa o `strace` existente no firmware e captura
  seus `write()` ao console durante três leituras. Nenhuma escrita no sensor.

### 2026-08-09 12:48:00 -03 — Primeiros valores reais do CT3

- A sonda v1.2 localizou corretamente a thread TID 310 e capturou 31 chamadas
  `write()` sem interferir na aplicação.
- Estado real: `eSensorModeLiveview`, frame efetivo 29,982830 fps, TG atual da
  família 3772×1344 e frame rate nominal 30 fps.
- Leituras confirmadas: `0x0340=0x0A80`, `0x0342=0x0EBC` e
  `0x3404=0x0005`.
- Criada `experiments/ct3_full_register_probe_v1_3/autoexec.sh` para coletar 66
  registradores de stream, formato, janela, skipping/binning e CDS, ainda
  exclusivamente por leitura.

### 2026-08-09 12:58:00 -03 — Correção de sincronização da coleta completa

- A v1.3 entregou os 66 comandos ao parser, mas não capturou seus valores: o
  `strace` 4.x foi anexado durante `msgrcv()` enquanto o filtro continha somente
  `write`, deslocando a decodificação das syscalls.
- Nenhum valor truncado da v1.3 será tratado como dado válido.
- Criada `ct3_full_register_probe_v1_3_1`, incluindo `msgrcv,write` no filtro e
  intervalo de 100 ms entre comandos. Continua somente leitura.

### 2026-08-09 13:12:00 -03 — Console temporário de rede

- Confirmado que não há `sshd` nem `dropbear` na imagem; porta 22 não pode
  oferecer SSH sem adicionar um servidor.
- O BusyBox 1.18.4 contém `telnetd` standalone e o symlink
  `/usr/sbin/telnetd`; `nc` também está disponível.
- O shadow contém `root::`, isto é, conta root sem hash de senha. Para evitar
  limitações de `securetty`, o experimento chama explicitamente `-l /bin/sh`.
- Criado `experiments/network_console_v1/autoexec.sh`, que inicia consoles
  Telnet temporários nas portas 23 e 22. A porta 22 não fala protocolo SSH.
- Risco registrado: ambos oferecem root sem autenticação a qualquer host da
  mesma rede. Remover o autoexec e reiniciar elimina os listeners.

### 2026-08-09 13:52:00 -03 — Console de rede confirmado na câmera

- Recebido `experiments/logs/NX300_NETWORK_CONSOLE.LOG` da execução real.
- Ambos os `telnetd` retornaram zero e permaneceram ativos: PID 364 em TCP 23 e
  PID 367 em TCP 22.
- `netstat` confirmou listeners em `0.0.0.0:22` e `0.0.0.0:23`.
- No momento do autoexec somente `lo` existia; o Wi-Fi ainda não estava ativo.
  Como os listeners usam endereço curinga, eles também aceitarão conexões pela
  interface Wi-Fi assim que ela receber o IP.

### 2026-08-09 14:02:00 -03 — Correção do shell Telnet

- O host inicialmente recebeu `No route to host`, compatível com Wi-Fi ainda
  inativo; depois conectou com sucesso às duas portas.
- Em 22 e 23 o handshake Telnet ocorreu, mas o servidor fechou imediatamente.
  Como os listeners permaneceram válidos, a falha está na execução de
  `/bin/sh` como programa de login, provavelmente devido aos argumentos que
  `telnetd` acrescenta.
- Criado `network_console_v1_1` com `nx300_shell.sh`: o wrapper ignora os
  argumentos, registra a sessão e executa `/bin/sh -i` no PTY do Telnet.

### 2026-08-09 14:12:00 -03 — Sessão remota operacional via inetd

- Usuário confirmou shell remoto online usando uma configuração `inetd.conf`.
- O caminho via inetd resolveu o encerramento de sessão observado no modo
  standalone do `telnetd`.
- O autoexec de rede deve ser preservado. Novas sondas serão copiadas com nomes
  próprios e executadas manualmente em `/mnt/mmc`, evitando substituir o canal
  de acesso ou reiniciar a câmera a cada iteração.
- A configuração exata do `inetd.conf` ainda deve ser incorporada ao repositório
  quando o arquivo usado for copiado para a pasta de experimentos/logs.

### 2026-08-09 14:20:00 -03 — Topologia remota confirmada

- Shell Telnet confirmado como `uid=0(root)` no kernel NX300 3.5.0+ build #24.
- `wlan0` operacional em `192.168.68.100/22`, MAC `20:13:E0:FB:97:02`.
- Listeners observados: TCP 21 e 23 pelo PID 368/inetd, TCP 80 pelo PID
  366/httpd e TCP 6000 pelo PID 232/Xorg.
- `/etc/inetd.conf` está vazio/inexistente para essa execução; o arquivo ativo
  foi passado por outro caminho e será identificado via `/proc/368/cmdline` e
  descritores abertos.
- A porta 22 não está mais aberta nessa configuração; o acesso funcional é
  Telnet/23. FTP/21 poderá simplificar a transferência dos logs se sua raiz e
  permissões forem confirmadas.

### 2026-08-09 14:27:00 -03 — inetd.conf funcional preservado

- Recebida a configuração exata: FTP/21 executa `ftpd -w /mnt/mmc/`; Telnet/23
  executa `telnetd -i -l /bin/bash`.
- Criado `experiments/network_console_inetd/inetd.conf` com o conteúdo validado.
- O FTP permite leitura e escrita diretamente no SD, possibilitando upload de
  sondas e download de logs sem retirar o cartão.
- O Bash é iniciado como root via Telnet, sem autenticação. FTP e Telnet não são
  criptografados; a câmera deve permanecer numa rede isolada.

### 2026-08-09 14:31:00 -03 — autoexec de rede funcional preservado

- Recebido e salvo exatamente em `experiments/network_console_inetd/autoexec.sh`.
- O script cria `/dev/pts`, monta `devpts`, inicia `httpd -h /mnt/mmc` e chama
  `inetd /mnt/mmc/inetd.conf`.
- Serviços resultantes: HTTP/80 para leitura do SD, FTP/21 com escrita no SD e
  Telnet/23 com Bash root.
- A montagem de `devpts` é o componente que fornece o pseudo-terminal necessário
  para a sessão Telnet interativa.

### 2026-08-09 14:42:00 -03 — V1.3.1 íntegra, porém CT3 em idle

- A coleta corrigida retornou 66/66 respostas sem corrupção.
- `cis info` mostrou `eSensorModeIdle`, frame calculado 7,495708 fps; todos os 66
  registradores retornaram zero. Isso indica sensor/stream inativo no modo Wi-Fi
  e invalida o conjunto como snapshot de live view.
- Criada `ct3_factory_live_probe_v1_4`, primeiro ensaio ativo controlado: chama
  o comando de fábrica `cis live`, lê a tabela e chama `cis stop`.
- A v1.4 possui trap de limpeza e watchdog independente de 20 segundos; não usa
  `regw` arbitrário nem modifica o rootfs.

### 2026-08-09 14:52:00 -03 — Factory live aceito; trace v1.4 desalinhado

- `cis live` retornou sucesso e mudou o TG calculado de 7,495708 para
  59,965660 fps, com `m_uiHdCount=1343`; o campo lógico `m_eMode` permaneceu
  Idle porque a chamada direta a `SetupVideoNormal()` não passa por `SetMode()`.
- Os 66 `regr` foram processados, mas o strace anexado antes de `live` ficou uma
  syscall deslocado e truncou os dados. Nenhum valor foi aceito.
- Criada v1.4.1 curta: `live` ocorre antes da anexação; somente `info` e
  0x0340/0x0342/0x3404 são rastreados; o trace é removido antes de `stop`.

### 2026-08-09 15:00:00 -03 — msgget identificada como origem do deslocamento

- A v1.4.1 ainda começou com uma syscall parcial cujo retorno foi 983070, o
  mesmo msqid observado para a fila do shell; trata-se de `msgget()` em andamento
  no momento da anexação.
- Como o filtro continha somente `msgrcv,write`, o strace ARM antigo atribuiu o
  retorno de `msgget` à syscall seguinte e truncou novamente os três resultados.
- Criada v1.4.2 sem qualquer filtro de syscall, limitada à mesma thread e a três
  registradores, preservando trap/watchdog/stop.

## 2026-08-09 10:31 America/Maceio — CT3 v1.4.2 recebido e v1.4.3 preparado

- Recebidos `CT3_LIVE_READ_SYNC_V1_4_2.LOG` e `CT3_LIVE_READ_SYNC_TRACE_V1_4_2.LOG` em `experiments/logs`.
- O teste executou integralmente (`live_rc=1`, `stop_rc=1`) e o trace tem 3569 bytes.
- Confirmado no `msgrcv` que os três comandos chegaram ao thread `shell_di_camera`: `regr 0340`, `regr 0342` e `regr 3404`.
- O perfil ativo reportou 59.965660 fps, 1344 linhas por VD, 3772 clocks por HD e `m_uiHdCount=1343`.
- O `strace` ARM antigo perde a sincronização/formatação no segundo `write` de cada resposta: captura `CIS_READ ADDRES`, mas omite o buffer seguinte que contém endereço/dado. Portanto `read_results=0` não significa falha do sensor.
- O binário local de `strace` anuncia suporte a `-e write=all`. Criada a experiência temporária v1.4.3 para obter dump hexadecimal independente dos buffers escritos, sem alterar firmware original.

## 2026-08-09 10:36 America/Maceio — CT3 v1.4.3 confirma bug e v1.5 elimina dependência do strace

- A v1.4.3 terminou normalmente, marcou três respostas e gerou trace de 12769 bytes.
- `-e write=all` despejou corretamente todos os writes cujo estado o strace reconheceu, confirmando suporte funcional ao recurso.
- Nas três respostas `regr`, o primeiro write contém `CIS_READ ADDRES`, mas o write de 34/35 bytes seguinte continua associado incorretamente ao retorno 983070 e não recebe dump. Logo o problema está na máquina de estados entrada/saída do strace, abaixo da formatação textual.
- Criada v1.5 com capturador ARM EABI5 estático próprio. Ele observa syscall-stops, identifica `r7=4` (`write`) e lê diretamente o buffer `r1` com tamanho `r2`, sem alternar estados de entrada/saída.
- O wrapper v1.5 mantém o ensaio temporário e somente leitura dos registradores 0x0340, 0x0342 e 0x3404, com `cis stop` no encerramento.

## 2026-08-09 10:40 America/Maceio — Resultado v1.5 e correção __WALL

- A v1.5 retornou `capture_rc=5` e arquivo de captura vazio. No código, retorno 5 só ocorre quando o `PTRACE_ATTACH` foi aceito mas o `waitpid(tid)` inicial falhou.
- Causa: `shell_di_camera` é uma thread de outro thread group e o wait de ptrace precisa de `__WALL`, comportamento já implementado internamente pelo strace.
- Criada v1.5.1 preservando v1.5, usando `wait4(..., options | __WALL, ...)` em todos os waits e redirecionando stderr do capturador ao resumo.

## 2026-08-09 10:39 America/Maceio — v1.5.1 não executada: camera app ausente

- O resumo v1.5.1 contém três inicializações, todas com `camera_pid=` e `shell_tid=` vazios, seguidas de `shell_tid_missing`.
- Não foi criado `CT3_PTRACE_WRITES_V1_5_1.LOG`; o wrapper encerrou antes de `cis live` e antes do ptrace.
- A sessão da câmera precisa ser reiniciada para restaurar `di-camera-app` e seu thread `shell_di_camera`; depois os mesmos artefatos v1.5.1 podem ser reutilizados.

## 2026-08-09 10:44 America/Maceio — Travamento reportado; v1.5.1 suspensa

- Usuário reportou travamento da câmera após repetir v1.5.1.
- Nenhum log novo chegou ao workspace: o resumo local permanece com 306 bytes, SHA-256 `059897...`, horário anterior, e o arquivo `WRITES` está ausente.
- Hipótese de software forte: `signal(SIGTERM, ...)` pode instalar `SA_RESTART`; assim o `wait4` bloqueado é reiniciado, o capturador não alcança `PTRACE_DETACH` e o wrapper fica preso em `wait`, mantendo `shell_di_camera` sob ptrace.
- v1.5.1 não deve ser executada novamente. Recuperação recomendada: power-cycle físico. Próxima versão deverá usar `sigaction` sem `SA_RESTART`, watchdog externo com término forçado e caminho explícito de retomada/detach do TID.

## 2026-08-09 10:49 America/Maceio — Câmera recuperada e v1.5.2 preparada

- Após power-cycle, `shell_di_camera` reapareceu como TID 310, estado sleeping, `TracerPid: 0`; recuperação completa confirmada.
- Criada v1.5.2 com `sigaction` sem `SA_RESTART`, parada explícita antes de detach quando `wait4` é interrompido, watchdog externo de 10 segundos, fallback SIGKILL do tracer, SIGCONT do camera app e registro final de `TracerPid`.
- Binário validado como ARM32 EABI5 estático, Linux >=3.2; script passou `sh -n`.

## 2026-08-09 10:55 America/Maceio — Primeira chamada v1.5.2 sem binário

- Recebido `CT3_PTRACE_V1_5_2.LOG`, 111 bytes, com camera PID 267 e shell TID 310.
- Wrapper encerrou em `capture_tool_missing`; nenhum ptrace, `cis live` ou leitura foi iniciado e não houve arquivo de writes.
- Necessário reenviar/renomear para `/mnt/mmc/arm_write_capture_v1_5_2` e aplicar modo 755 antes de repetir.

## 2026-08-09 10:58 America/Maceio — v1.5.2 encerra limpa; filtro assinado corrigido

- Execução real v1.5.2: `live_rc=1`, `stop_rc=1`, `capture_rc=0`, `TracerPid: 0`; câmera não ficou presa e todas as proteções de encerramento funcionaram.
- Arquivo de writes vazio foi explicado por comparação assinada: `struct pt_regs` usa `long`; endereços userspace NX300 com bit 31 são negativos, falhando em `r1 > 4096`.
- Revisão 2 do binário faz cast `(unsigned long)r1 > 4096UL`. O wrapper e comandos de sensor permanecem idênticos.

## 2026-08-09 11:15 America/Maceio — Primeiras leituras CT3 ativas confirmadas

- A revisão corrigida v1.5.2 produziu 10339 bytes de captura, encerrou com `capture_rc=0`, `stop_rc=1` e `TracerPid: 0`.
- Respostas inequívocas: `0x0340 = 0x0A80` (2688), `0x0342 = 0x0EBC` (3772), `0x3404 = 0x0005`.
- No instante do `info`, estado coerente com liveview normal: `eSensorModeLiveview`, enum 30 fps, frame rate efetivo 29.982830 fps, VD 16676.21 us, HD 12.40 us e `m_uiHdCount=2630`.
- Produto 2688 × 3772 × 29.982830 = 303999991 clocks/s, confirmando pixel clock efetivo nominal de 304 MHz.
- Apesar de `cis live` retornar 1, o atraso de 2 segundos permitiu ao app restabelecer o liveview 30p antes das leituras. Próxima medição do perfil direto 60p precisa anexar antes do comando e ler imediatamente.

## 2026-08-09 15:19:18 -03 — Inventário remoto somente leitura via nx300-safe

- Acesso remoto passou a obedecer exclusivamente `/home/hunkreborn/.local/bin/nx300-safe`; nenhuma escrita ou alteração foi feita na câmera.
- Confirmado Linux 3.5.0+ PREEMPT ARMv7, Samsung DRIMe IV NX300, CPU ARM Cortex-A9 rev 8 com NEON/VFPv3 e 512092 kB de RAM, sem swap.
- Root `ubi0!rootdir` é UBIFS somente leitura; `/mnt/ubi2` também ro, `/mnt/ubi1` rw e SD `/mnt/mmc` é exFAT rw. Leituras de MTD/UBI proibidas não foram realizadas.
- Processo principal `/usr/bin/di-camera-app-nx300`, PID 267, root, 71 threads, RSS 28508 kB, `TracerPid: 0`.
- Mapa/FDs confirmam acesso direto do app a `/dev/d4_sma`, `d4_bma`, `d4_bwm`, `d4_ipcm`, `d4_pp_core`, `d4_pp_ssif`, `d4_pp_3a`, `d4_mipi`, `lens_comm`, framebuffer, SPI/GPIO/PWM e áudio.
- Plataforma expõe drivers `s5p-mfc`, `drime4-drm`, `drime4_hdmi`, `drime4_cec`, `drime4-dwc3`, `usb_mass_storage`, `usb_mode`, blocos D4 de imagem e Wi-Fi AR6000/ath6kl.
- `/sys/class/drm` contém `card0-HDMI-A-1` e `card0-LVDS-1`; `/sys/class/video4linux` e `/sys/class/udc` estão vazios nesta sessão.
- Bibliotecas-chave vistas em uso ou instaladas: capture-fw NX300, d4c, mmfcamcorder, mmutil_movie, OMX SEC AVC encoder, MFC encoder API, HDMI CEC, GStreamer camera/OMX/H.264/RTP/RTSP/TCP/UDP e pilha Wi-Fi/DLNA.
- Algumas conexões paralelas foram encerradas pelo servidor; comandos faltantes foram repetidos sequencialmente pelo mesmo wrapper, sem tentativa de contorno.

## 2026-08-09 15:35 -03 — Emulador NX300 v0.1 e UI Lab visual

- Criado `emulator/`: digital twin comportamental, explicitamente não cycle-accurate, sem alterar firmware original ou câmera.
- Backend Python simula identidade DRIMe IV/ARMv7, kernel, RAM/mounts, filesystem selecionado, estado HDMI e registradores CT3 medidos; comandos mutantes são bloqueados.
- Criado preview web 800×480 em `emulator/visual`, com telas liveview/menu/playback, OSD, gravação e clean HDMI simulados.
- Hot reload verifica `visual/web/` e a árvore original de imagens NX300; assets originais são somente servidos para leitura.
- Validação: 4 testes unitários aprovados; py_compile aprovado; endpoints `/`, `/config.json` e `/api/version` responderam HTTP 200 em localhost:8300.
- Limite atual: não há `qemu-system-arm` instalado e o DRIMe IV não possui máquina QEMU pronta; MMIO/ioctl/EDJ fiel são camadas futuras.

## 2026-08-09 15:44 -03 — Rota clean HDMI/liveview identificada estaticamente

- `UI_Operate_Display_Ctrl_Set(type, ctrl)` em 0x1f3104 implementa cinco estados: 1 disable, 2 enable, 3 OSD-only, 4 video-only, 5 video-off.
- `UI_Set_Hdmi_Connect()` em 0x1b66b0 começa com `type=-1, ctrl=1`, liga HDMI via XRandR, cria `CDisplayerFactory::Device=2` (TV) e então constrói explicitamente playback (`UI_PB_Set_Display_Size`, `UI_HDMI_Single_Construct`).
- Isso explica o comportamento de fábrica: a política da aplicação troca para playback; não é ausência de HDMI ativo.
- Há diversos chamadores de `UI_Operate_Display_Ctrl_Set(7,4)` dentro do fluxo de captura, provando que o app já usa video-only/clean em algum display durante operações normais.
- Nenhuma função de mudança de display foi invocada na câmera devido às regras read-only.
## 2026-08-09 16:05 -03 — HDMI liveview: máscara TV e visibilidade dos planos

- Análise local, sem acesso nem alteração da câmera.
- `eUI_DISPLAY_TYPE` é usado como máscara: bit `0x01` seleciona `CDisplayerFactory::Device=1`; bit `0x08` seleciona `Device=2` (TV/HDMI).
- Correção da hipótese anterior: para atuar somente no HDMI, o argumento candidato é `8`, não `7`.
- `UI_Display_Ctrl_Set_Video_Only(8)` obtém o displayer TV e chama virtualmente `SetVisible(true, 0)`. Para a janela 1, chama `SetVisible(true,1)` apenas quando `UI_Get_State(55)==1`; caso contrário, `SetVisible(false,1)`.
- `UI_Display_Ctrl_Set_OSD_Only(8)` chama `SetVisible(false,0)` e `SetVisible(false,1)` no TV.
- Em `libmm-displayer.so`, `CDisplayTV::SetVisible(bool,int)` envia ioctl `0x40087438` ao fd armazenado em `this+0x0c`, com payload de dois `int`: índice da janela e flag 0/1.
- O caminho de mais alto nível para um futuro teste controlado é `UI_Operate_Display_Ctrl_Set(8,4)`, mas isso ainda não prova que o pipeline de captura foi vinculado ao TV; `UI_Set_Hdmi_Connect()` continua desviando a aplicação para playback.
## 2026-08-09 21:25:59 -03 — Reanálise completa e foco em novos modos de filme

- Realizada auditoria nova das camadas UI, CT3, capture-fw, mm-camcorder, MFC,
  display/HDMI, Wi-Fi e USB, cruzada com leituras da câmera via `nx300-safe`.
- Descoberto no DWARF o modo `eUI_CAP_MOVIE_SIZE_1920_810_24F`; ele é o melhor
  primeiro candidato para validar modificação do menu de ponta a ponta.
- A configuração real aceita FPS até 120 e inclui 1920x1080/1920x810. Isso torna
  720p120 e 1080p120 candidatos reais, embora o throughput do MFC ainda precise
  de teste.
- 240 fps existe no CT3, mas falta no validador mm-camcorder; 2K/4K também não
  aparecem nas resoluções configuradas.
- A API MFC declara `SUPPORT_1080P` e buffer máximo de saída de 3 MiB. Não foi
  encontrada rejeição direta de dimensões maiores, portanto UHD permanece uma
  hipótese experimental de baixa viabilidade, não uma impossibilidade provada.
- Corrigido o enum de display: TV=8 e HDMI=16.
- Relatório consolidado: `REANALYSIS_2026-08-09.md`.
- Nenhuma escrita ou alteração foi feita na câmera.
## 2026-08-09 21:34:32 -03 — Experimento de override do camera app por bind mount

- Criado localmente `experiments/di_camera_sd_override_v1/`; não foi instalado
  nem executado na câmera e o autoexec vigente não foi alterado.
- Objetivo: sobrepor `/usr/bin/di-camera-app-nx300` por uma cópia em `/tmp`
  durante um único boot, usando `mount --bind`, sem escrever UBIFS/NAND.
- O payload é cópia byte-a-byte do ELF stripped original do rootfs: 1.115.832
  bytes, modo 755, SHA-256
  `c3932e60f75df886ed5484470be91f2d9ca8f3d6e2c9944cdd0060561fe852a7`,
  BuildID `32e258f2d9921ce491d34477d62c64a51d3ba4f1`.
- Boot: o desktop entry chama `/usr/bin/di-camera-app`, symlink para o alvo; o
  launchpad é iniciado em `/usr/etc/X11/xinitrc`, depois de X. O chamador do
  autoexec não existe no OSS, portanto precedência absoluta não foi provada
  estaticamente.
- O autoexec aborta antes do bind se detectar o camera app ativo, verifica os
  três hashes (alvo original, SD e `/tmp`) e repete o teste de PID imediatamente
  antes do mount. Após o bind valida dev/inode e hash; falha posterior tenta
  desmontagem imediata.
- O único log runtime será `/tmp/di_camera_sd_override_v1.log`. Rollback
  documentado: reboot físico; `/tmp` e bind mount são voláteis.

## 2026-08-09 22:11:01 -03 — Reanálise forense dos programas Windows

- Inventariados 15 originais de `programas_windows/`, com SHA-256 e preservação
  integral; as duas cópias do IntelliStudio são duplicatas byte a byte.
- Extração estática produziu catálogo de 1.278 PE sem executar instaladores/Wine.
- iLauncher suporta explicitamente NX300 por USB mass-storage, VID:PID
  `04e8:1397`; lê `SYSTEM/DEVICE.XML`, consulta servidor Samsung e copia firmware
  para o volume, sem evidência de flash PTP/DFU direto.
- Samsung Remote Studio contém a SDK remota mais completa (PTP/WPD/PTP-IP,
  liveview, AF, captura, propriedades e movie), mas o alvo documentado é NX1
  firmware 1.31+; não foi confirmado suporte direto à NX300.
- Reconstruído mapa parcial de opcodes Samsung vendor PTP `0x9004..0x90fe`.
  Liveview SRS usa buffers YUV420/YUV422 e JPEG no caminho NX1, não RTSP/H.264.
- PC Auto Backup foi correlacionado ao lado NX300: SSDP/UPnP/DLNA MSCP,
  CreateObject/ImportURI, HTTP POST e X_BACKUP_START/DONE; é uma rota útil para
  backup/uploader Linux, não liveview.
- IntelliStudio é importador/editor pré-NX300; Gear360 usa driver bulk separado
  `04e8:a50c`; SMC 4K é transcode no PC e não evidência de MFC/CT3 NX300.
- Não foi encontrada a contraparte Windows exata do Remote Viewfinder NX300,
  nem novo bitrate/modo interno ou mecanismo clean HDMI.
- Relatório completo: `WINDOWS_SOFTWARE_REANALYSIS_2026-08-09.md`.
- Nenhum acesso ou alteração foi feito na câmera.

## 2026-08-09 23:45:26 -03 — Origem do autoexec e causalidade do override

- Reanálise integralmente offline confirmou que, na build Build ID
  `417516b9d8d751ed807b059e15ce35991c3a01c2`, o caller de `start_script` em
  `0x001c27b0` é `UI_Event_Card_Mounted()`, fonte DWARF
  `UI/src/EventManager/ui_event_card_manager.cpp:942`.
- `libmisc.so:start_script` valida somente `access(R_OK)` e cria uma thread
  detached. O worker faz `chmod u+rx`, executa o script via `system()` e repete
  a execução aproximadamente uma vez por segundo depois de cada retorno.
- `stop_script` é chamado por `UI_Close_FileManager()` em `0x001c1410`, durante
  o fechamento do gerenciador de storage, e usa `pthread_cancel` sem join.
- Root cause do skip v2.1: não havia uma corrida curta a otimizar. O autoexec é
  iniciado pelo próprio camera app depois do evento de cartão; logo o PID precisa
  existir antes do script.
- Contradição de build: o payload `c3932e...`/Build ID `32e258...` de `rootdir`
  não depende de `libmisc`, enquanto `rootdir_3-5`/`imagedev` é a build 417 que
  contém o mecanismo. O hash da build realmente instalada não foi confirmado
  pelo log, pois o PID guard abortou antes dessa verificação.
- Nenhum hook SD anterior ao primeiro exec foi encontrado nos scripts de init,
  X, launchpad, preload ou preexec. Melhor candidato reversível: fazer bind com
  o processo original ainda vivo e usar futuramente um segundo exec gracioso
  pelo lifecycle AUL; fallback runtime é patch estritamente guardado por ptrace.
- Relatório: `experiments/autoexec_origin_reanalysis/`.
- CAMERA MUTATIONS: NONE. ORIGINAL FILES MODIFIED: NONE.

## 2026-08-17 — Build311: caminho oficial de HDMI liveview

- Fonte autoritativa confirmada: `live_camera_2026-08-17/di-camera-app-nx300.live`, SHA-256 `68e3f8a62be1092a55f33b881188503f96a6649210f259b60edb97719e75d6d7`, Build ID `3119561d1ec93b05fab09aaed9df83a5936af3b2`.
- O item UI 631 foi identificado como `eUI_PB_INFO_HDMI_3D_TYPE`: 0 OFF, 1 SIDE_BY_SIDE, 2 TOP_AND_BOTTOM, 3 FRAME_PACKING. O item 946 é `eUI_COMMON_INFO_3D_HDMI_OUTPUT`: preferência 0 SIDE_BY_SIDE ou 1 FRAME_PACKING.
- O único writer direto de 631 é o seletor local `__xrr_output_select` (`0x157c4c`), que enumera modos XRandR/EDID. Sem candidato 3D escreve 0; com candidato, 946=0 produz 631=1 e 946=1 produz 631=3.
- O caminho oficial entra por `UI_Hdmi_3D_Liveview(0)` em `0x150828`, chamado pelos handlers HDMI Single/Folder de Half Shutter e Playback após destruir a UI de playback. Ele usa `mov-hdmi`, CRTC liveview 1920x1080, inicia o liveview pelo controller normal e termina em display control `VIDEO_ONLY`.
- O caminho não reprograma os atributos `file-format`/`stereo-video-format` nem reinicia o camcorder como `hdmidemo.adj`; entretanto ainda é uma função 3D e requer 631!=0, portanto clean HDMI em sink comum ainda não está provado.
- Próximo teste mais seguro: somente o evento físico nativo em sink que realmente anuncie modos HDMI 3D, com saída/restauração pela própria UI. Nenhuma chamada/injeção manual deve preceder esse teste.
- Relatório completo: `hdmi_liveview_codex_report.md`.
- CAMERA MUTATIONS: NONE.
