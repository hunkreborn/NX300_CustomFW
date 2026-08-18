# Samsung NX300 — reanálise de arquitetura e oportunidades

Data: 2026-08-09 21:25:59 -03

## Escopo e método

Revisão independente do ELF completo, bibliotecas, BSP Linux 3.5/DRIMe IV,
configurações do rootfs, material NX500, experimentos e histórico. A câmera foi
consultada somente por `~/.local/bin/nx300-safe`; nenhuma escrita foi feita.

## A. Arquitetura reconstruída

```text
CT3 (CAquilaCt3Driver)
  -> MIPI (`/dev/d4_mipi`)
  -> IPCM/IPCS/PP/B2Y/LDC/resize (`d4_ipcm`, `d4_pp_*`, `d4_bma/bwm/sma`)
  -> CLiveviewPathListMovie{FullHD,HD,VGA,QVGA}
       |-> display LCD/TV: libmm-displayer + DRM/X11
       |-> callback/buffers: capture-fw
       `-> camerasrc -> mm-camcorder -> omx_h264enc/MFC -> mp4mux -> SD
                                  `-> callback/caminho de rede (candidato)
```

Seleção por camada:

- Sensor: `CAquilaCt3Driver::SetMode`, `SetFrameRate`, `SetupFullHdMode`,
  `SetupVideoNormal`, `SetupVideoNormalWide`, `SetupVideo120fps`,
  `SetupVideo240fps`, `SetupVideoFull` programam janela, skipping e timing CT3.
- Caminho DRIMe4: `CLiveviewPathCreator::setPathParameterHDMovie/VGAMovie` e
  classes `CLiveviewPathListMovie*` escolhem nós, tamanhos, resize e buffers.
- UI: `eUI_CAP_MOVIE_SIZE` escolhe resolução/FPS; `UI_Set_Attr_Movie_Size`
  converte resolução em largura/altura, FPS e bitrate e envia atributos ao
  mm-camcorder.
- Camcorder: `camerasrc`, zero-copy NV12, sete buffers; valida resoluções/FPS
  pelas listas de `mmfw_camcorder_dev_video_pri.ini`.
- Encoder: `omx_h264enc` alimenta o MFC DRIMe4; `mp4mux` gera o arquivo.
- Bitrate: `UI_Get_Video_Bit_Rate` classifica resolução, obtém FPS e chama
  `mm_util_movie_video_bit_rate(res_class,fps,quality,3d)`.
- Display: `CDisplayerFactory`, `CDisplayTV`, DRM/XRandR. O tipo é bitmask:
  LCD principal=1, todos LCD=7, TV=8, HDMI=16.
- OSD/vídeo: `UI_Operate_Display_Ctrl_Set`; controles 1..5 = disable, enable,
  OSD-only, video-only e video-off. `CDisplayTV::SetVisible` usa ioctl
  `0x40087438` com `{window,visible}`.
- Wi-Fi: ath6kl SDIO, Wi-Fi Direct/DLNA e bibliotecas `libwifi-*`; o caminho
  Remote Viewfinder ainda precisa ser isolado no smart-wifi-app.
- USB: DWC3 gadget SuperSpeed e gadget Android/Mass Storage existem; UVC,
  RNDIS e ECM não estão habilitados no kernel atual.

## B. Descobertas novas

1. O enum completo contém um modo nativo `1920x810@24` (valor 3). É o candidato
   mais fácil para exposição/rebatismo no menu.
2. A configuração real do camcorder aceita FPS `3,15,24,25,30,50,60,100,120`.
   Portanto, 100/120 não são rejeitados pelo validador genérico.
3. A mesma configuração aceita preview `1920x1080` e `1920x810`, mas não 2K,
   1440p, UHD nem 240 fps.
4. `set_movie_size()` limita explicitamente o índice da UI a `0..7`.
5. `UI_Get_Movie_Frmae_By_Movie_Size` já mapeia 60/30/15/24/60/30/30; PAL
   converte 60->50 e 30->25.
6. O runtime mapeia grandes áreas SMA, inclusive regiões aproximadas de 158 e
   202 MiB. A memória deve ser medida por buffer/layout, não descartada de saída.
7. `eUI_DISPLAY_TYPE` distingue TV=8 de HDMI=16. A conclusão anterior de que
   “8 é HDMI” era simplificada: 8 seleciona `CDisplayTV`, mas o bit 16 existe e
   seus consumidores ainda precisam ser resolvidos.
8. O MFC programa largura/altura diretamente, sem rejeição explícita encontrada,
   mas sua API declara `SUPPORT_1080P`, saída máxima de 3 MiB e políticas de
   clock para classe 1080p. Acima disso continua não comprovado.
9. O pipeline de gravação é `camerasrc` zero-copy NV12 -> `omx_h264enc` ->
   `mp4mux`; há callback de vídeo na API mm-camcorder que pode servir ao Wi-Fi.
10. O kernel já tem gadget SuperSpeed, mas a webcam depende de UVC novo ou de
    uma função userspace/gadget existente; não há UVC pronto.

## C. Conclusões anteriores confirmadas

- O CT3 possui rotinas reais 120/240 e full-size; não são apenas strings.
- 4K não existe como preset integrado NX300.
- Clean HDMI é arquiteturalmente plausível pela separação de planos.
- O fluxo factory de conexão HDMI conduz a playback, explicando o produto.
- Bluetooth está desabilitado no kernel NX300.
- CPU tem perfil bootloader de 800 MHz; RAM já usa LPDDR2-533.
- Bitrate é política de software e pode ser elevado antes de alterar sensor.

## D. Conclusões corrigidas ou enfraquecidas

- “MFC é rigidamente limitado por um check 1920x1080”: enfraquecida. Há desenho
  e documentação 1080p, mas não foi encontrada rejeição simples de dimensões.
- “8 é a máscara HDMI”: corrigida para TV=8 e HDMI=16. A relação entre ambas
  ainda precisa de xrefs completos.
- “1080p120 é barrado no camcorder”: corrigida. 120 aparece na lista oficial;
  faltam enum/UI, path FullHD e validação de encoder/throughput.
- “240 está disponível ponta a ponta”: não. Existe no CT3, mas falta na lista
  FPS do camcorder e provavelmente requer saída reduzida e caminho QVGA/VGA.
- “4K impossível”: deve ser formulado como baixa viabilidade no MFC original,
  ainda sem medição experimental da falha exata de cada camada.

## E. Contradições

- Driver CT3 oferece 240 fps; configuração pública termina em 120 fps.
- CT3 oferece full-size video; UI/camcorder não oferecem dimensão equivalente.
- HDMI DRM está conectado/ativo, mas a política do app troca para playback.
- Driver MFC aceita campos arbitrários de largura/altura, enquanto a API anuncia
  suporte 1080p e dimensiona buffers/clocks nessa classe.

## F. Símbolos e endereços-chave

- App `UI_Get_Video_Bit_Rate`: `0x001adf5c`
- App `UI_Set_Attr_Movie_Size`: `0x001b2e7c`
- App `UI_Get_Movie_Frmae_By_Movie_Size`: `0x001b3f7c`
- App `set_movie_size`: `0x000f1138`
- App `UI_Operate_Display_Ctrl_Set`: `0x001f3104`
- App `UI_Display_Ctrl_Set_Video_Only`: `0x001f47e4`
- App `UI_Excute_Shell_Cmd`: `0x00152d00`
- App `shell_parser`: `0x00152f40`
- Capture `SetupVideoFull`: `0x002d4a60`
- Capture `SetupVideo120fps`: `0x002d4c28`
- Capture `SetupVideo240fps`: `0x002d4c9c`
- Capture `SetupFullHdMode`: `0x002d468c`
- Capture `ChangeDisplay`: `0x001ee124`
- Capture `ChangeTargetDisplay`: `0x001ee1dc`
- Displayer `CDisplayTV::SetVisible`: `0x000088c0`
- mmutil `mm_util_movie_video_bit_rate`: `0x00000888`

## G. Arquivos e drivers-chave

- `di-camera-app-nx300-full`
- `imagedev/usr/lib/libcapture-fw-slpcam-nx300.so`
- `imagedev/usr/lib/libmm-displayer.so`
- `imagedev/usr/lib/libmmfcamcorder.so.0.0.0`
- `imagedev/usr/lib/libmmutil_movie.so.0.0.0`
- `image/rootdir/usr/etc/mmfw_camcorder*.ini`
- `packages/linux-3.5/drivers/media/video/drime4/mfc5x/`
- `packages/linux-3.5/drivers/gpu/drm/drime4/` e drivers HDMI/DP
- `imagedev/usr/share/edje/di-camera-app-nx300/`
- `image/rootdir/usr/bin/set_usb_debug.sh`

## H. Capacidades ocultas candidatas

- Expor 1920x810@24: alta confiança.
- 1080p100/120 como captura e possivelmente gravação: sensor/camcorder favoráveis,
  encoder ainda crítico.
- 720p100/120: melhor primeiro high-speed gravável.
- 720p240 ou VGA/480p240: CT3 favorável, camcorder e encoder a ampliar.
- Bitrate 40–80 Mbit/s em 1080p: alta viabilidade, dependente do SD.
- Clean HDMI/liveview: alta viabilidade arquitetural, chamada/rota a validar.
- Frame callback Wi-Fi 720/1080: média; latência e encode simultâneo são limites.
- UVC: média com kernel novo, baixa sem alterar kernel.
- Focus peaking: alta via overlay/PP, especialmente como protótipo userspace.
- 2K/1440p: baixa-média; precisa path/buffers e prova MFC.
- 4K24: baixa no MFC original; possível pesquisa via raw/frame dump ou encoder
  externo, não modo de produto ainda.

## I. Ranking de modificações

| Modificação | Impacto | Viabilidade | Risco | Esforço |
|---|---:|---:|---:|---:|
| Expor 1920x810@24 | médio | muito alta | baixo | baixo |
| Bitrate maior | alto | alta | baixo-médio | baixo |
| Clean HDMI 1080 | alto | alta | médio | médio |
| 720p100/120 | alto | média-alta | médio | médio |
| Focus peaking | alto | média-alta | baixo | médio |
| 1080p100/120 | muito alto | média | médio-alto | alto |
| Wi-Fi 720p H.264 | alto | média | médio | alto |
| 720p240 | alto | baixa-média | alto | alto |
| USB UVC | alto | média com kernel | alto | alto |
| 2K/1440p24 | alto | baixa | alto | muito alto |
| 4K24 interno | muito alto | muito baixa | muito alto | pesquisa |

## J. Dez próximos experimentos

1. **Snapshot de capacidades mm-camcorder.** Comando: `nx300-safe cat` nos três
   INIs e hashes locais. Somente leitura; câmera/rootfs; risco nenhum; rollback N/A.
2. **Traçar seleção 1920x810@24.** Instrumentação temporária em `/tmp` ou SD para
   observar atributos e caminho ao selecionar o valor 3. Alteração RAM/SD; risco
   baixo; rollback encerra processo auxiliar/remove arquivo do SD.
3. **Protótipo UI 1920x810@24.** Patch de cópia local do ELF/Edje, carregado
   temporariamente por mecanismo autorizado. Alteração `/tmp`/SD; risco médio;
   rollback reinicia app/câmera com binário original, sem NAND.
4. **720p120 sem gravação.** Solicitar ao capture-fw modo 120 e medir frames,
   drops e temperatura. Alteração RAM; risco médio; watchdog e retorno a modo normal.
5. **720p120 com encoder.** Atributos `1280x720,120`, bitrate conservador, arquivo
   curto no SD. Alteração RAM+SD; risco médio; parar gravação e apagar teste.
6. **1080p120 dry-run do encoder.** Inicializar atributos sem gravar e coletar
   retorno/log MFC. Alteração RAM; risco médio; destruir handle temporário.
7. **240 fps reduzido.** Primeiro VGA/640x480, depois 720p somente se dimensões
   reais do CT3 confirmarem. Alteração RAM; risco alto; watchdog e restauração.
8. **Clean HDMI.** Manter capture state, `ChangeTargetDisplay` para TV e aplicar
   video-only. Alteração RAM/display; risco médio; restaurar target/LCD ou reiniciar
   somente após autorização.
9. **Callback Wi-Fi.** Registrar callback de frames em processo temporário e medir
   taxa sem rede; depois RTP local. Alteração `/tmp`/RAM; risco baixo-médio; encerrar
   helper.
10. **Sonda MFC 2K/4K isolada.** Programa em `/tmp` abre MFC e tenta apenas init
    2560x1440 e 3840x2160 com buffers limitados, sem sensor. Alteração RAM; risco
    médio; fechar fd/liberar buffers. Isso identifica a camada de falha sem mexer
    no CT3 ou gravar NAND.

## Estratégia para adicionar modos ao menu

Implementar em degraus, cada um preservando fallback:

1. Reaproveitar o valor 3 e expor `1920x810@24` para validar toda a cadeia UI.
2. Criar tabela paralela de modos experimentais, sem aumentar inicialmente o enum
   persistido; mapear um slot existente para 720p120.
3. Patchar `set_movie_size`, tabelas NTSC/PAL, `UI_Get_Resolution`, frame-rate,
   bitrate, enable-bits e recursos Edje/PNG.
4. Acrescentar a resolução/FPS ao INI temporário e garantir que `camerasrc` a aceite.
5. Mapear para `SetupVideo120fps` e um path com resize/buffers compatíveis.
6. Só depois testar MFC e mux; manter modo sensor-only como diagnóstico separado.
7. Para 240/2K/4K, criar novos descriptors somente após provar cada estágio.

## Validação real desta rodada

- `nx300-safe id`: `uid=0(root) gid=0(root)`.
- Kernel: Linux 3.5.0+, ARMv7, build #24.
- PID app: 267.
- Módulos dinâmicos: ath6kl/cfg80211/exfat; os drivers DRIMe4 estão built-in.
- Mapas confirmam capture-fw, mmfcamcorder, mmutil, displayer e grandes SMA.
- INI real confirmou resoluções e FPS descritos acima.
- Nenhuma modificação foi executada.
