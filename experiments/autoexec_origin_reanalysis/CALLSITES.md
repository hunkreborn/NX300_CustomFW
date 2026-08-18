# Cross-references de `start_script` e `stop_script`

## Correspondencia da build — PROVEN

`di-camera-app-nx300-full` possui Build ID
`417516b9d8d751ed807b059e15ce35991c3a01c2`, exatamente igual ao ELF stripped
de `rootdir_3-5` e ao ELF de `imagedev`. Assim, enderecos de `.text` e DWARF
podem ser correlacionados diretamente, sem fingerprint aproximado.

Relocations/PLT:

| Funcao | `R_ARM_JUMP_SLOT` | PLT |
|---|---:|---:|
| `stop_script` | `0x0029cb4c` | `0x0006a860` |
| `start_script` | `0x0029d114` | `0x0006b9b8` |

A busca de branches para esses PLTs encontrou exatamente um call site direto
para cada funcao no binario.

## Caller de `start_script` — PROVEN

- Call site: `0x001c27b0: bl 0x0006b9b8 <start_script@plt>`.
- Funcao real: `UI_Event_Card_Mounted()`.
- Intervalo: `0x001c1de0..0x001c27c4`.
- Fonte DWARF:
  `/home/jk0811.cho/source/TIZEN/packages/di-camera-app/UI/src/EventManager/ui_event_card_manager.cpp`.
- Linha do call: 942.
- Proxima funcao: `UI_Event_Card_Connect(int)` em `0x001c27c4`, linha 947.

Isto corrige definitivamente o rotulo enganoso baseado no simbolo exportado
anterior `UI_Stop_Charger_Timer()`. Ele nao define o intervalo da funcao local
em `0x1c1de0`.

No fim de `UI_Event_Card_Mounted`, numerosos caminhos convergem em
`0x1c27b0`. Uma falha de `UI_Recheck_Card_State()` em `0x1c1f24..0x1c1f30`
salta para `0x1c27b8` e evita o call. Portanto, a formulacao precisa e:
`start_script()` roda no termino dos caminhos normais de montagem/reconhecimento
do cartao; caminhos de erro especificos podem ignora-lo.

## Evento que leva ao caller — STRONG EVIDENCE

1. `UI_Event_Receive_Message_Queue(void*, int, void*)` chama
   `UI_Event_Card_Manager(int)` em `0x0017af94` para a classe/grupo de evento 7.
2. `UI_Event_Card_Manager(int)` chama `UI_Event_Card_Mounted()` em
   `0x001c1558` quando o estado recebido e 2.
3. Existe tambem o caminho assíncrono
   `UI_Set_Callback_Card(int)` -> `g_idle_add(UI_G_Idle_CB_Card, ...)` ->
   `UI_Event_Card_Manager(...)`, colocando o tratamento no main loop Ecore.
4. `UI_Event_Card_Mounted` registra callbacks de storage, consulta
   `CStorageInterface::GetStorageInfo`, chama `UI_Recheck_Card_State` e somente
   depois chega ao `start_script`.

Os valores semanticos exatos de todos os enums de storage nao foram recuperados;
o nome DWARF e o fluxo deixam forte evidencia de que estado 2 representa o
evento montado/aceito relevante.

## Caller de `stop_script` — PROVEN

- Call site: `0x001c1410: bl 0x0006a860 <stop_script@plt>`.
- Funcao: `UI_Close_FileManager()` (`0x001c1228...`).
- Fonte: `ui_event_card_manager.cpp`, linha 247.
- Caller direto de `UI_Close_FileManager`: `UI_Manage_Event_On_Off(...)` em
  `0x00186b48`, fonte
  `ui_state_common_modechange.cpp:3108`.

Antes de `stop_script`, `UI_Close_FileManager` remove callbacks/encerra a
interface de storage e zera seu global. O stop pertence ao fechamento do
gerenciador de arquivo/cartao, nao foi demonstrado como um destructor geral do
processo.

## Contradicao entre imagens — PROVEN/UNKNOWN

| Variante | SHA-256 | Build ID | `libmisc` / calls |
|---|---|---|---|
| `rootdir/usr/bin/di-camera-app-nx300` | `c3932e60...52a7` | `32e258f2...a4f1` | nao depende de `libmisc`; sem `start_script/stop_script` |
| `rootdir_3-5/usr/bin/di-camera-app-nx300` | `f8036f78...bcf` | `417516b9...1c2` | possui os dois calls |
| `imagedev/usr/bin/di-camera-app-nx300` | `f8036f78...bcf` | `417516b9...1c2` | identico a `rootdir_3-5` |
| `di-camera-app-nx300-full` | `ebe6c368...eeb` | `417516b9...1c2` | mesmo codigo + simbolos/DWARF |

O payload de `di_camera_sd_override_v2_1` veio da primeira linha, mas o contexto
desta analise aponta a segunda build como a que contem o mecanismo observado.
Como o guard de PID abortou antes de validar o hash do alvo na camera, a build
real instalada continua **UNKNOWN** nesta analise offline. Usar um payload da
build 32 contra firmware/bibliotecas da build 417 e uma incompatibilidade
potencial e deve ser impedido por um hash guard especifico antes de qualquer
experimento futuro.

