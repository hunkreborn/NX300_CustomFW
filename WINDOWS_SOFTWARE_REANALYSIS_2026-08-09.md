# Reanálise forense dos programas Windows Samsung — 2026-08-09

## Escopo, método e preservação

Análise estática, sem executar PE/Wine e sem acessar a câmera. Os 15 originais em
`programas_windows/` não foram modificados. Hashes, tipos e metadados estão em
`windows_software_reanalysis_2026-08-09/inventory/`; extrações independentes em
`extracted/`; evidências intermediárias em `reports/` e `strings/`.

Foram usados `file`, SHA-256, 7-Zip, xorriso, cabextract, pefile, strings ASCII e
UTF-16LE, objdump, recursos PE e osslsigncode. O catálogo final contém 1.278 PE
extraídos. A ausência de uma string não é tratada como prova de ausência de uma
função. Timestamps PE são informativos, não datas forenses confiáveis.

## 1. Inventário dos originais

| Pacote | Tamanho | SHA-256 | Tipo/estrutura | Assinatura |
|---|---:|---|---|---|
| Gear 360 ActionDirector 2.0.1619 + Live 1.0.0419 | 693982216 | `78dde0b76e702cc1a2fa9dca094f116cedf41e3eb1d8a8236be01058d6ae6b43` | PE32 InstallShield/CyberLink, payloads 7z | Authenticode CyberLink, digest válido; cadeia antiga não validável localmente |
| iLauncher 2013-04-02 1.0.1.20 | 11570018 | `2d46d1f040e8f7ec1d981646ba97add80182e95e5d2ecfff052c1ede04c2c8d0` | PE32 NSIS | não assinado |
| iLauncher 2014-03-11 1.1.0.7 | 5170560 | `f2b01cc19fb51b7742396186114da9b2db544979320b7c2c24fbbc81ee1fee52` | PE32 NSIS | Samsung/SHA-1, digest válido |
| iLauncher 2014-05-22 1.1.0.12 | 6209568 | `976c3c9b455d587e59c8d77597666d567ced34a5e4cc95a474745c5302939269` | PE32 NSIS | Samsung/SHA-1, digest válido |
| iLauncher 2014-11-13 1.1.0.24 | 6318000 | `e2ec4d53f9a64a22850040e005dee5c7e2cf4e23a68b897815b685330706ffa7` | PE32 NSIS | Samsung/SHA-1, digest válido |
| IntelliStudio 3.0.52.1 ISO (ambas as cópias) | 79865856 cada | `f711e7d2efa4689023f2be33fb2e4b3c3ed254ff1611f158395ee89eb3d64939` | ZIP contendo ISO9660 e CAB | duplicatas exatas |
| PC Auto Backup 1.1.1.18 | 33597554 | `5b5b46e7efb9d6373e3fd6976ee2fa7a70d1bc29f46a80bbfa560c206d15b163` | InstallShield/MSI encapsulado | não assinado |
| PC Auto Backup 1.1.1.21 | 33598057 | `8068519e98528ede0a5ead5fc5c0ce9d4d08f829d283f32f2af585ea46f554bf` | InstallShield/MSI encapsulado | não assinado |
| Samsung DNG Converter 1.0 | ZIP, fonte completa | `583625c39813782483d07ca3222e5ade909f3118f702737a85459d82607cb70c` | ZIP | n/a |
| Samsung DNG Converter 2.0 | ZIP, fonte completa | `bc6ac46dd5604ad4c588f4a86eb749b9975c006044069cbdd15eb5d0ecc89617` | ZIP | n/a |
| Samsung DNG Converter 3.0 | 28548709 | `6873a6acf2202e502aa4033de64b16c65dfbf9aee594de5e133b3def135d75ce` | InstallShield InstallScript | não assinado |
| Samsung Raw Converter 4.0 | 64344184 | `6319751cea1baa8424fb2a5e50887c425487210d16517cc923739ee05f391bd3` | InstallShield | Ichikawa Soft Laboratory, MD5 legado válido |
| Samsung Movie Converter 1.0.0.13 | 35709076 | `265b1d3e8dce556d28ca0bc7c6d3f638f458ba242618d89babe9ce631678b1f9` | NSIS; aplicação .NET + ffmpeg | não assinado |
| Samsung Remote Studio 1.0.1 | 59420042 | `f6e772e0154cad8a37626bc9df69a7ccddc3c1886a5b24bba4bb8c5f86401a33` | NSIS Copy; carving validado | não assinado |

Os campos completos de tamanho, arquitetura, timestamps, versão, imports,
exports, PDBs e seções estão nos TSV/JSON de inventário, evitando duplicar 1.278
linhas neste relatório.

## 2. Samsung Remote Studio / SRS

### Arquitetura e compatibilidade

**Confirmado:** é o componente com controle remoto mais completo. O manual
incluído, porém, exige **NX1 com firmware 1.31 ou posterior**. `SdiMgr.dll` contém
conversores explicitamente denominados NX1 e NX2000 e strings NX200/NX1000/
NX2000; não foi localizada seleção NX300. Portanto, SRS prova uma família de
protocolo Samsung reutilizável, mas não prova compatibilidade direta com NX300.

Arquivos centrais:

| Arquivo | SHA-256 | Evidência |
|---|---|---|
| `SRS.exe` | `5058946496fbd50f1f15688cd15d6bc8392ebc4e926e69222d0230479127e12a` | UI, PDB `C:\Project\NewSRS\src\NewSRS\Release\SRS.pdb` |
| `SdiCore.dll` | `b6c9503deddf9ea087a30adb918c1465b7ad2d6c06ac88c130a9d2cc51a0c344` | 209 exports, transporte WPD/PTP |
| `SdiMgr.dll` | `bddd407d0a6fe4a3edf2c625b00b213bb1daad87907cb744216f02ea35b46284` | 276 exports, PTP-IP, conversão liveview |
| `HttpDll.dll` | `99d252a2a7ae9a227ddc9059efb72861f7035603c68c1a94c13d0c6d7e2aa41f` | WININET auxiliar |

Windows 7 usa `IPortableDevice`/WPD; o caminho XP usa PTP host próprio. Imports
`SETUPAPI`, `WS2_32` e `IPHLPAPI`, além de `ConnectTryPTPIP`, lista de handles
PTP-IP e MACs, mostram que a biblioteca também prevê transporte IP.

### Liveview e controle

**Confirmado:** exports incluem liveview on/off/info/data, captura, touch AF,
posição de foco, tracking AF stop, propriedades, movie pause/resume/transfer,
interval stop, image transfer, firmware update e hidden command. Exemplos:

- `SdiCore!LiveviewExec` RVA `0x4760`; `LiveviewInfo` `0x4e80`;
- `SdiCore!SdiSetLiveView` `0xe140`; `SdiSetFocusPosition` `0x7150`;
- `SdiCore!SdiSetRecordPause` `0xd870`; resume `0xdf00`;
- `SdiMgr!PTP_SendLiveview` RVA `0xbdd0/0xbe40`;
- `SdiMgr!PTP_ControlTouchAF` `0xc380`; `PTP_SetLiveView` `0xc600`;
- `SdiMgr!PTP_ImageTransfer` `0xc4d0`; `PTP_FWUpdate` `0xc210`.

`CLiveviewConverter` aceita YUV420/YUV422; o caminho NX1 também converte JPEG e
histograma. Assim, o liveview chega como buffers de imagem proprietários sobre
PTP/WPD/PTP-IP, e **não há evidência de RTSP/H.264 para SRS**. Resolução/FPS do
liveview não puderam ser fixados apenas estaticamente; são campos de
`RSLiveviewInfo` negociados pelo dispositivo.

### PTP vendor-specific reconstruído

Disassembly de `SdiCore.dll` identifica os seguintes operation codes. Direção
exata e layout de payload ainda precisam de traço USB para validação:

| Opcode | Semântica de alta confiança |
|---:|---|
| `0x9004` | require capture |
| `0x9005` | capture |
| `0x9006` | liveview info |
| `0x9007` | liveview data/exec |
| `0x9008` | get/set focus position |
| `0x900a` | reset device |
| `0x900b` | format device |
| `0x900d/0x900e` | get/set tick |
| `0x9010` | record status |
| `0x9012` | enlarged display |
| `0x9013` | movie transfer/complete |
| `0x9014/0x9015` | record pause/resume |
| `0x9017` | set liveview |
| `0x9018` | image transfer |
| `0x901a` | set device property |
| `0x9022` | interval capture stop |
| `0x9023` | display-save wakeup |
| `0x9025` | capture count |
| `0x9026` | touch AF |
| `0x9028` | tracking AF stop |
| `0x90fe` | firmware update |

O binário contém 137 nomes de DPC, preservados em `reports/srs_ptp_names.txt`,
incluindo movie quality/multi-motion/state/record time, focus peaking, HDMI,
Bluetooth e Wi-Fi. Esses nomes são evidência da SDK NX1; os códigos precisam ser
extraídos da jump table em `SdiCore` e comparados com os DPC aceitos pela NX300.

O manual lista modos NX1 4096×2160p24, 3840×2160p30/24/23.98,
1920×1080p120/60/30/24/23.98 e slow motion 0,25/0,5. **Isto não é evidência de
capacidade DRIMe IV/NX300**; é uma referência útil de semântica e UI Samsung.

## 3. iLauncher e atualização

**Confirmado:** todas as quatro versões reconhecem NX300. A tabela interna dá
Samsung VID `04e8`, NX300 PID `1397`; NX300M `1402`, NX30 `1403`, NX3000 `1409`
e NX1 `140b`. NX300 já aparece em abril de 2013.

A detecção usa SetupAPI e identificadores USB/USBSTOR. Não foi encontrado flash
PTP/DFU: o firmware upgrader lê a câmera como volume montado, abre
`X:\SYSTEM\DEVICE.XML`, consulta:

- `/SDP/Device/BaseModelName/@value`;
- `/SDP/Device/FirmwareUpdate/CurrentVersion/@value`;
- `/SDP/Device/FirmwareUpdate/ProductionPlace/@value`.

Consulta o endpoint histórico
`samsungimaging.com/common/support/firmware/downloadUrlList.do?prd_mdl_name=%s&loc=%s`
(e variante samsung.com), interpreta `FirmwareInfo/FWVersion/DownloadURL`, baixa
e copia o arquivo para o armazenamento. A aplicação então orienta o usuário a
executar “Body Firmware” na câmera. Não há evidência de `dnloader` nem escrita
direta em NAND.

Comparação: firmwareUpgrader de março/maio/novembro é byte a byte idêntico
(`b869ab6e...`). Março adiciona downloader PC Auto Backup; maio adiciona DNG e
Lightroom; novembro adiciona COMMON e Samsung Movie Converter. Em novembro a
entrada NX300 habilita `manual_download`, `dng_converter`, `movie_converter` e
PowerMediaPlayer. Isso é evolução do catálogo/downloader, não do protocolo USB.

## 4. PC Auto Backup

Os dois launchers InstallShield contêm MSI, mas a edição de avaliação do wrapper
impede extração não executada por ferramentas disponíveis. A diferença é apenas
503 bytes no instalador e versões 1.1.1.18/1.1.1.21; não se conclui identidade do
payload. A outra ponta da NX300, porém, está documentada pelos headers e XML do
rootfs.

**Confirmado:** protocolo UPnP/DLNA MSCP, para backup de arquivos, não liveview.
A câmera descobre o DMS do PC, lê
`/mnt/mmc/dlna_web_root/SAMSUNGAutoBackupDESC.ini`, guarda UDN/friendlyName/MAC/
WOL, chama `X_BACKUP_START`, usa Browse/CreateObject, obtém `ImportURI`, envia o
arquivo por HTTP POST, acompanha `GetTransferProgress` e encerra com
`X_BACKUP_DONE`. Há retry, resume/offset, overwrite, pause, wake-on-LAN e pedido
de desligamento. Headers incluem `contentFeatures.dlna.org`,
`transferMode.dlna.org` e User-Agent `SEC_DSC_Samsung User-Agent DLNADOC/1.50`.

Isto é implementável em Linux com SSDP/UPnP + servidor HTTP, e útil para upload/
backup/Telegram, mas não fornece frames nem controles de exposição.

## 5. IntelliStudio 3.0.52.1

As duas cópias são duplicatas exatas. ISO/CAB incluem `iStudio.exe`, `iInit.exe`,
`FnA.dll`, `WebShare.dll`, codecs DirectShow H.264/AAC/MJPEG e mux MP4.
`iStudio.exe` SHA-256 `e0f5010b...`, PDB
`D:\samsung_project\Intelli-studio 3.0\Main\iStudio\Release\iStudio.pdb`.

`iInit` usa SetupAPI/USBSTOR para achar armazenamento Samsung. IntelliStudio
importa, edita, converte e publica mídia; contém firmware downloader e APIs web
Facebook/Flickr/YouTube/Picasa/Twitter antigas. Modelos visíveis incluem NX10,
NX100 e NX11, mas **não NX300** (release de 2011). Não foram encontrados remote
control/liveview/PTP vendor-specific. Componentes `WebShare`, `iInit`, runtime e
skin reaparecem no pacote SMV/iLauncher por ancestralidade de código, não como
SDK de câmera remota.

## 6. Samsung Movie Converter / SMC

`Samsung Movie Converter.exe` (`6c5399ca9940...`) é .NET e chama ffmpeg/ffprobe.
PDB aponta para `D:\2015\SMC\Encoder\HEVC_UI\...`. Presets incluem 4096×2160,
3840×2160, 2560×1440, 1920×1080 e 1280×720; a linha ffmpeg usa
`libx264 -preset veryfast -level:v 5.1`.

**Correção importante:** esses são perfis de transcodificação no PC. Não
descrevem `UI_Get_Video_Bit_Rate`, `mm_util_movie_video_bit_rate`, CT3 ou o MFC
da NX300, e portanto não elevam a viabilidade de 2K/4K na câmera.

## 7. RAW e DNG

DNG Converter 1/2 fornecem fonte C++ completa. V1 se identifica como conversor
NX3000; V2 despacha explicitamente NX3000/NX1, não NX300. Para NX3000 aparecem
área ativa `(18,64)-(3714,5600)`, crop 5472×3648; NX1 usa 6480×4320. O parser
também revela tabelas/chaves de ofuscação SRW, úteis para ferramentas RAW, mas
nenhuma configuração CT3/NX300.

Samsung Raw Converter 4.0 é software Ichikawa/SILKYPIX rebatizado e pré-NX300.
DNG 3.0 permaneceu em InstallShield não extraído sem execução. Não foi atribuída
a ele evidência não observada.

## 8. Gear 360 ActionDirector / Live

O pacote é majoritariamente CyberLink: 867 PE, editores, codecs, stitch 360 e
live broadcast. O driver Samsung `VR360.sys` usa interface bulk USB
`USB\VID_04E8&PID_A50C`, classe `{8E68B867-6DBA-44C9-A368-C528987EFD20}`.
`G360Live.exe` (`871f408b...`) é um cliente específico Gear 360; o nome de fonte
é `Projects\LiveStraming`. Strings NX1/NX500/NX3000 encontradas no pacote vêm de
`CLPhotoRawDecoder`/dcraw para decodificação fotográfica, não de uma tabela de
controle de câmera. Não há NX300 nessa lista observada nem componente compartilhado
com a SDK SRS. O driver bulk/protocolo Gear 360 não deve ser transplantado para
o USB mass-storage/PTP da NX300 sem evidência adicional.

## 9. Componentes compartilhados

- iLauncher 2013 inclui a linhagem IntelliStudio/SMV (`WebShare`, `iInit`, codecs,
  skins); várias runtimes MSVC e `skin_fna.dll` são idênticas.
- FirmwareUpgrader 2014 é idêntico nas três releases posteriores.
- DNG 1/2 compartilham grande parte de Qt/KDE/Adobe DNG SDK, mas o código Samsung
  evolui de NX3000 para NX3000+NX1.
- SRS não compartilha `SdiCore`/`SdiMgr` com iLauncher, IntelliStudio ou PC Auto
  Backup. Só compartilha runtimes MSVC genéricas.
- Gear360 é CyberLink/Samsung VR360 separado.

Mapa funcional:

| Programa | USB | PTP | Wi-Fi | Liveview | Atualização/transferência |
|---|---|---|---|---|---|
| SRS | WPD/PTP | vendor `0x90xx`, PTP-IP | caminho PTP-IP | sim, buffers YUV/JPEG | captura/movie/image/FW, NX1 |
| iLauncher | USBSTOR | não observado | download HTTP no PC | não | copia firmware para SD/câmera |
| PC Auto Backup | não principal | não | SSDP/UPnP/DLNA/HTTP | não | backup HTTP POST |
| IntelliStudio | USBSTOR/import | não observado | serviços web | não | importação/publicação |
| Gear360 | bulk PID A50C | protocolo próprio não reconstruído | live broadcast específico | Gear360 | edição/stitch |

## 10. Cross-check com firmware NX300

Os símbolos `UI_WiFi_Rvf_Construct`, `UI_Wifi_Rvf_CB_Stream_Start/Stop` e
`UI_Wifi_Rvf_Event_Handle` pertencem ao Remote Viewfinder móvel da NX300. Nenhum
dos programas Windows analisados contém a contraparte nominal RVF. SRS é outra
família: PTP/WPD/PTP-IP, originalmente NX1. Assim, **não encontramos a outra
ponta exata do RVF NX300**.

SRS ainda é valioso para construir um cliente experimental: primeiro consultar
DeviceInfo/OperationsSupported da NX300, sem enviar opcodes mutantes, e comparar
0x9006/0x9007/0x9017 com o firmware. O PC Auto Backup fornece uma rota pronta para
transferir arquivos a um serviço Linux. Nenhum pacote ajuda diretamente clean
HDMI; isso permanece no `libmm-displayer`/DRM/UI da própria câmera.

Também não surgiu novo preset de bitrate da NX300. Modos 4K/1080p120 de SRS são
NX1; presets 4K do SMC são conversão PC. O melhor fundamento para novos modos
continua sendo CT3 + capture-fw + mm-camcorder/MFC locais, documentados em
`REANALYSIS_2026-08-09.md`.

## 11. Conclusões e confiança

### Confirmado

1. iLauncher suporta explicitamente NX300 VID/PID `04e8:1397`.
2. SRS implementa a SDK remota Samsung mais completa, mas seu alvo confirmado é NX1.
3. Há PTP vendor-specific Samsung e liveview por buffer no SRS.
4. PC Auto Backup é UPnP/DLNA/HTTP e pode ser reimplementado em Linux.
5. iLauncher não flasheia diretamente: detecta volume, consulta servidor e copia firmware.
6. IntelliStudio é importador/editor; não há evidência de tether/liveview NX300.
7. Gear360 usa driver bulk dedicado PID A50C, não o transporte NX300.
8. Nenhum programa fornece clean HDMI ou novos parâmetros internos MFC/CT3 NX300.

### Hipóteses abertas

- A NX300 pode implementar um subconjunto ancestral dos opcodes SRS `0x9004–0x9018`.
- PTP-IP do SRS pode compartilhar conceitos, mas não necessariamente framing, com RVF.
- Um receptor Linux/OBS é viável se 0x9006/0x9007 forem aceitos e o layout
  `RSLiveviewInfo` for reconstruído; caso contrário, a rota RVF/GStreamer é melhor.
- PC Auto Backup pode ser transformado em uploader automático Telegram no PC/
  Raspberry Pi sem instalar Telegram na câmera.

### Conclusões antigas enfraquecidas/corrigidas

- “SRS é a outra ponta do RVF NX300”: não sustentado; transportes e alvo diferem.
- “4K no SRS/SMC prova 4K na NX300”: falso; respectivamente NX1 e transcode PC.
- “iLauncher usa PTP/DFU para atualizar”: não observado; o caminho encontrado é mass-storage.

## 12. Dez próximos experimentos

| # | Objetivo e comando/código | Tipo/local | Risco | Rollback |
|---:|---|---|---|---|
| 1 | Parser Python offline da jump table DPC de `SdiCore.dll`, associando códigos aos 137 nomes | leitura/local | nenhum | apagar artefato gerado |
| 2 | Desmontar funções de cada opcode e documentar parâmetros WPD | leitura/local | nenhum | n/a |
| 3 | Implementar enumerador Linux PTP que execute somente GetDeviceInfo e liste OperationsSupported/DPC da NX300 | leitura/host+USB | baixo, abre sessão | desconectar USB |
| 4 | Comparar lista retornada com `0x9004..0x90fe`, sem invocá-los | leitura/host | nenhum adicional | n/a |
| 5 | Reconstruir `RSLiveviewInfo` por acessos de campo em `LiveviewInfo`/converter | leitura/local | nenhum | n/a |
| 6 | Implementar servidor UPnP Auto Backup compatível em Linux, primeiro só descoberta/descrição | alteração apenas no host | baixo | encerrar processo/apagar diretório |
| 7 | Em laboratório isolado, capturar USB de uma sessão SRS+NX1, se uma NX1 existir | leitura de tráfego/host | baixo | desconectar |
| 8 | Mapear lado NX300 de `UI_Wifi_Rvf_CB_Stream_Start` até sockets/ports/framing | leitura/local | nenhum | n/a |
| 9 | Extrair MSI do PC Auto Backup com ferramenta InstallShield compatível em VM descartável, sem executar custom actions | alteração na VM | baixo | destruir VM |
| 10 | Cruzar presets SMC apenas com arquivos MP4 produzidos pela NX300 (atoms/profile/level), sem inferir encoder | leitura/local | nenhum | n/a |

## 13. Respostas executivas A–R

**A.** Sim: iLauncher suporta explicitamente NX300. **B.** Para NX300, iLauncher
tem a identificação mais inequívoca; para controle remoto Samsung geral, SRS é
mais completo, mas NX1. **C.** Sim, PTP vendor `0x90xx`/PTP-IP no SRS. **D.** Não
a contraparte exata do RVF NX300. **E.** Há liveview para PC no SRS/NX1. **F.**
Buffers YUV420/YUV422 e JPEG NX1; resolução/FPS negociados e ainda não fixados.
**G.** Sim no SRS: exposição via DPC, foco/touch AF, captura e movie pause/resume.
**H.** Sim. **I.** O mapa confirmado está na seção 2. **J.** SSDP/UPnP/DLNA,
CreateObject/ImportURI e HTTP POST. **K.** SetupAPI/USBSTOR `04e8:1397`,
DEVICE.XML, consulta HTTP e cópia ao volume. **L.** Auto Backup é diretamente
implementável; SRS requer completar structs/framing. **M.** SRS ajuda um receptor
OBS futuro se NX300 aceitar o subconjunto; RVF local continua mais promissor.
**N.** Não. **O.** Não para NX300; 4K/120p observados são NX1/PC. **P.** Há
linhagem compartilhada IntelliStudio/iLauncher, mas não uma SDK remota comum.
**Q.** As dez descobertas principais são os oito confirmados, o mapa de opcodes e
a separação SRS≠RVF. **R.** Os dez experimentos estão na seção anterior.

## Artefatos reproduzíveis

- `windows_software_reanalysis_2026-08-09/inventory/originals.sha256`
- `windows_software_reanalysis_2026-08-09/inventory/original_pe.tsv`
- `windows_software_reanalysis_2026-08-09/inventory/extracted_pe.tsv`
- `windows_software_reanalysis_2026-08-09/reports/srs_ptp_names.txt`
- `windows_software_reanalysis_2026-08-09/reports/srs_ptp_name_function.asm`
- `windows_software_reanalysis_2026-08-09/reports/iLauncher_*_device_table.xmlfrag`
- `windows_software_reanalysis_2026-08-09/strings/SdiCore.dll.strings.txt`
- `windows_software_reanalysis_2026-08-09/strings/SdiMgr.dll.strings.txt`
