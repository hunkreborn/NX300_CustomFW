# NX300 autoexec origin reanalysis

Data: 2026-08-09 (America/Maceio)

Esta pasta documenta uma reanalise exclusivamente estatica/offline da origem de
`/mnt/mmc/autoexec.sh`, da ordem de boot e das opcoes de interposicao reversivel
do `di-camera-app-nx300`.

Resultado central: na build com Build ID
`417516b9d8d751ed807b059e15ce35991c3a01c2`, o proprio aplicativo chama
`start_script()` no fim do fluxo normal de `UI_Event_Card_Mounted()`. A funcao
de `libmisc.so` cria uma thread detached que executa o script repetidamente,
aproximadamente uma vez por segundo depois de cada retorno do script. Portanto,
o autoexec nao e um hook de boot anterior ao aplicativo.

Arquivos:

- `ANALYSIS.md`: conclusoes consolidadas, limites e resposta aos objetivos.
- `LIBMISC_START_SCRIPT.md`: reconstrucao de `start_script`, worker e
  `stop_script`.
- `CALLSITES.md`: todos os call sites e o contexto DWARF.
- `BOOT_CHAIN.md`: init, X, launchpad, AUL e montagem do cartao.
- `HOOK_CANDIDATES.md`: ranking dos mecanismos reversiveis.
- `COMMANDS_USED.txt`: comandos locais reproduziveis usados na analise.
- `MANIFEST.sha256`: hashes dos artefatos desta pasta.

Desassemblies completos/intermediarios foram mantidos fora do corpus original
em `/tmp/nx300_autoexec_reanalysis/`.

## Garantias

- CAMERA MUTATIONS: **NONE**
- ORIGINAL FILES MODIFIED: **NONE**
- Nenhum binario ARM foi executado.
- Nenhuma conexao de rede ou acesso a camera foi realizado.

