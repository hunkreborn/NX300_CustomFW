# Samsung NX300 Reverse Engineering — Findings

> Caderno técnico cumulativo (append-only). Não apagar nem substituir entradas.
> Toda correção deve ser acrescentada como uma nova entrada datada.

## 2026-08-09 10:15:26 -03 — Bitrate de vídeo

### Escopo

Análise de `UI_Get_Video_Bit_Rate` no aplicativo da câmera e da implementação
importada `mm_util_movie_video_bit_rate`. Nenhum artefato original foi modificado.

### Artefatos e hashes

```text
ebe6c3680a89d912ccb57ecaeff721283855b9ffa3263c4ecf488571a00b5eeb  di-camera-app-nx300-full
eb455f202c57f1e79558eadc3cb035d9d714f076847c7ea7cb4c12366554830d  TIZEN/project/NX300/imagedev/usr/lib/libmmutil_movie.so.0.0.0
```

`di-camera-app-nx300-full` foi identificado como ELF 32-bit little-endian ARM,
EABI5, dinamicamente ligado, não stripped e contendo DWARF. Build ID:

```text
417516b9d8d751ed807b059e15ce35991c3a01c2
```

### Símbolos e endereços

| Símbolo | Artefato | Endereço | Tamanho |
|---|---|---:|---:|
| `UI_Get_Video_Bit_Rate(eUI_CAP_MOVIE_SIZE)` | aplicativo | `0x001adf5c` | `0x18c` / 396 bytes |
| `UI_Get_Movie_Frmae_By_Movie_Size(eUI_CAP_MOVIE_SIZE, bool)` | aplicativo | `0x001b3f7c` | `0x178` / 376 bytes |
| `mm_util_movie_video_bit_rate@plt` | aplicativo | `0x0006a9ec` | PLT |
| `mm_util_movie_video_bit_rate` | `libmmutil_movie.so.0.0.0` | `0x00000888` | `0x208` / 520 bytes |

O aplicativo declara dependência direta de `libmmutil_movie.so.0` e usa RPATH
`/usr/lib`.

### Comandos de reprodução

```bash
file di-camera-app-nx300-full
readelf -h di-camera-app-nx300-full
readelf -Ws di-camera-app-nx300-full
readelf -d di-camera-app-nx300-full
arm-linux-gnueabi-objdump -d -C \
  --start-address=0x1adf5c --stop-address=0x1ae0e8 \
  di-camera-app-nx300-full
arm-linux-gnueabi-objdump -d -C \
  --start-address=0x1b3f7c --stop-address=0x1b40f4 \
  di-camera-app-nx300-full
arm-linux-gnueabi-objdump -d \
  --start-address=0x888 --stop-address=0xa90 \
  TIZEN/project/NX300/imagedev/usr/lib/libmmutil_movie.so.0.0.0
arm-linux-gnueabi-objdump -s \
  --start-address=0x164c --stop-address=0x1664 \
  TIZEN/project/NX300/imagedev/usr/lib/libmmutil_movie.so.0.0.0
sha256sum di-camera-app-nx300-full \
  TIZEN/project/NX300/imagedev/usr/lib/libmmutil_movie.so.0.0.0
```

### Enums relevantes da UI

```cpp
enum eUI_CAP_MOVIE_SIZE {
    eUI_CAP_MOVIE_SIZE_1920_1080_60F = 0,
    eUI_CAP_MOVIE_SIZE_1920_1080_30F = 1,
    eUI_CAP_MOVIE_SIZE_1920_1080_15F = 2,
    eUI_CAP_MOVIE_SIZE_1920_810_24F  = 3,
    eUI_CAP_MOVIE_SIZE_1280_720_60F  = 4,
    eUI_CAP_MOVIE_SIZE_1280_720_30F  = 5,
    eUI_CAP_MOVIE_SIZE_640_480_30F   = 6,
    eUI_CAP_MOVIE_SIZE_320_240_30F   = 7,
    eUI_CAP_MOVIE_SIZE_MAX           = 8
};

enum eUI_CAP_MOV_QUALITY {
    eUI_CAP_MOV_QUALITY_NORMAL = 0,
    eUI_CAP_MOV_QUALITY_HIGH   = 1,
    eUI_CAP_MOV_QUALITY_MAX    = 2
};

enum eUI_CAP_3D_REC_MODE {
    eUI_CAP_3D_REC_MODE_SIDE_BY_SIDE  = 0,
    eUI_CAP_3D_REC_MODE_FRAME_PACKING = 1,
    eUI_CAP_3D_REC_MODE_MAX           = 2
};
```

Itens acessados pela função:

```text
UI_Get_Value(36)  = eUI_CAPTURE_INFO_SMART_FILTER
UI_Get_Value(82)  = eUI_CAPTURE_INFO_MOV_QUALITY
UI_Get_Value(195) = eUI_CAPTURE_INFO_3D_REC_MODE
UI_Get_Value(928) = eUI_COMMON_INFO_VIDEO_OUT
UI_Get_State(48)  = eUI_CAPTURE_LIVIEVIEW_BACKUP_MODE
```

Observação: `LIVIEVIEW` e `Frmae` são grafias presentes nos símbolos originais.

### Enums da biblioteca

```c
typedef enum {
    MM_UTIL_MOVIE_QUALITY_LOW    = 0,
    MM_UTIL_MOVIE_QUALITY_NORMAL = 1,
    MM_UTIL_MOVIE_QUALITY_HIGH   = 2
} mm_util_movie_quality;

typedef enum {
    MM_UTIL_MOVIE_QVGA        = 0, /* 320x240 */
    MM_UTIL_MOVIE_VGA         = 1, /* 640x480 */
    MM_UTIL_MOVIE_HD480       = 2, /* 720x480 */
    MM_UTIL_MOVIE_HD720       = 3, /* 1280x720 */
    MM_UTIL_MOVIE_HD1080      = 4, /* 1920x1080 */
    MM_UTIL_MOVIE_CINEMASCOPE = 5  /* 1920x810 */
} mm_util_movie_resolution;

typedef enum {
    MM_UTIL_STEREO_VIDEO_NONE            = 0,
    MM_UTIL_STEREO_VIDEO_SIDE_BY_SIDE    = 1,
    MM_UTIL_STEREO_VIDEO_TOP_BOTTOM      = 2,
    MM_UTIL_STEREO_VIDEO_FRAME_SEQUENCE  = 3,
    MM_UTIL_STEREO_VIDEO_LEFT_RIGHT_VIEW = 4
} mm_util_stereo_video_format;
```

### Lógica de `UI_Get_Video_Bit_Rate`

Assinatura reconstruída:

```cpp
int UI_Get_Video_Bit_Rate(eUI_CAP_MOVIE_SIZE movie_size);
```

Mapeamento de resolução:

| `movie_size` | Resolução passada à biblioteca |
|---:|---|
| 0, 1, 2 | `MM_UTIL_MOVIE_HD1080` (4) |
| 3 | `MM_UTIL_MOVIE_CINEMASCOPE` (5) |
| 4, 5 | `MM_UTIL_MOVIE_HD720` (3) |
| 6 | `MM_UTIL_MOVIE_VGA` (1) |
| 7 ou valor fora do switch | `MM_UTIL_MOVIE_QVGA` (0, valor inicial) |

FPS retornado por `UI_Get_Movie_Frmae_By_Movie_Size(movie_size, false)`:

```text
0 -> 60, 1 -> 30, 2 -> 15, 3 -> 24,
4 -> 60, 5 -> 30, 6 -> 30, default -> 30
```

Se `eUI_COMMON_INFO_VIDEO_OUT == 1`, a conversão PAL é:

```text
60 -> 50
30 -> 25
```

A qualidade passada à biblioteca é `NORMAL` (1) por padrão. Quando
`eUI_CAPTURE_INFO_MOV_QUALITY == eUI_CAP_MOV_QUALITY_HIGH` (1), passa a ser
`HIGH` (2).

`eUI_CAPTURE_INFO_SMART_FILTER` é lido e guardado numa variável local, mas não
participa de nenhuma decisão nem do retorno. Provável código residual.

O formato é `MM_UTIL_STEREO_VIDEO_NONE` normalmente. Quando
`eUI_CAPTURE_LIVIEVIEW_BACKUP_MODE == 1`:

```cpp
if (UI_Get_Value(eUI_CAPTURE_INFO_3D_REC_MODE) == 1)
    stereo = MM_UTIL_STEREO_VIDEO_LEFT_RIGHT_VIEW; // 4
else
    stereo = MM_UTIL_STEREO_VIDEO_SIDE_BY_SIDE;    // 1
```

Chamada final:

```cpp
return mm_util_movie_video_bit_rate(resolution, fps, quality, stereo);
```

### Implementação de `mm_util_movie_video_bit_rate`

Tabela-base em `.rodata`, endereço virtual `0x164c`:

| Índice | Resolução | Bitrate-base |
|---:|---|---:|
| 0 | QVGA 320x240 | 1.000.000 bit/s |
| 1 | VGA 640x480 | 3.500.000 bit/s |
| 2 | HD480 720x480 | 4.500.000 bit/s |
| 3 | HD720 1280x720 | 9.000.000 bit/s |
| 4 | HD1080 1920x1080 | 15.000.000 bit/s |
| 5 | Cinemascope 1920x810 | 14.000.000 bit/s |

Ordem dos ajustes:

```text
base da resolução -> estéreo -> FPS -> qualidade
```

Multiplicadores de estéreo:

```text
NONE (0)             x 1
formatos 1, 2 ou 3   x 6/5 = 1,2
LEFT_RIGHT_VIEW (4)  x 9/4 = 2,25
```

Multiplicadores de FPS:

```text
12 ou 15 fps  x 3/4
24 ou 25 fps  x 7/8
30 fps        x 1
50 ou 60 fps  x 7/4
outro FPS     x 1, com mensagem de unsupported frame rate
```

Multiplicadores de qualidade:

```text
LOW (0)     x 3/5 = 0,6
NORMAL (1)  x 4/5 = 0,8
HIGH (2)    x 1
```

As contas são inteiras; as divisões por 5 são implementadas com a constante
mágica `0x66666667` e shifts.

Pseudocódigo reconstruído:

```c
int mm_util_movie_video_bit_rate(int resolution, int fps,
                                 int quality, int stereo)
{
    static const int base[6] = {
        1000000, 3500000, 4500000,
        9000000, 15000000, 14000000
    };

    int rate = resolution <= 5 ? base[resolution] : 0;

    if (stereo == MM_UTIL_STEREO_VIDEO_LEFT_RIGHT_VIEW) {
        rate = rate * 9 / 4;
        if (fps > 30)
            printf("current frame rate should be 30 fps");
    } else if (stereo != MM_UTIL_STEREO_VIDEO_NONE) {
        rate = rate * 6 / 5;
    }

    switch (fps) {
    case 12:
    case 15: rate = rate * 3 / 4; break;
    case 24:
    case 25: rate = rate * 7 / 8; break;
    case 30: break;
    case 50:
    case 60: rate = rate * 7 / 4; break;
    default: printf("unsupported frame rate %d", fps); break;
    }

    if (quality == MM_UTIL_MOVIE_QUALITY_LOW)
        rate = rate * 3 / 5;
    else if (quality == MM_UTIL_MOVIE_QUALITY_NORMAL)
        rate = rate * 4 / 5;

    return rate;
}
```

### Bitrates finais usados pela UI, sem 3D, padrão NTSC

| Modo | Qualidade normal | Qualidade alta |
|---|---:|---:|
| 1920x1080 60p | 21.000.000 | 26.250.000 |
| 1920x1080 30p | 12.000.000 | 15.000.000 |
| 1920x1080 15p | 9.000.000 | 11.250.000 |
| 1920x810 24p | 9.800.000 | 12.250.000 |
| 1280x720 60p | 12.600.000 | 15.750.000 |
| 1280x720 30p | 7.200.000 | 9.000.000 |
| 640x480 30p | 2.800.000 | 3.500.000 |
| 320x240 30p | 800.000 | 1.000.000 |

Em PAL, 60 fps passa para 50 fps e permanece na mesma classe de multiplicador.
30 fps passa para 25 fps, mudando o multiplicador de `1` para `7/8`.

### Pontos para continuação

- Localizar todos os chamadores de `UI_Get_Video_Bit_Rate` e descobrir onde o
  valor chega ao encoder/camcorder.
- Verificar se há limites adicionais ou sobrescritas em
  `libcapture-fw-slpcam-nx300.so` e `libmmfcamcorder.so.0`.
- Mapear semanticamente `eUI_CAPTURE_LIVIEVIEW_BACKUP_MODE`, pois o nome não
  deixa evidente por que ele controla os formatos 3D.
- Verificar se a mensagem que exige 30 fps para `LEFT_RIGHT_VIEW` corresponde
  a uma limitação real ou apenas diagnóstico, já que a função continua a conta.

## 2026-08-09 10:23:20 -03 — Triagem: 4K, HDMI clean, apps sociais e webcam

### Estado desta entrada

Triagem inicial baseada na árvore local. As conclusões marcadas como preliminares
devem ser confirmadas por desassemblagem adicional e, posteriormente, testes em
hardware. Nenhum binário, rootfs ou fonte original foi alterado.

### 1. Gravação 4K24

Não foram encontradas referências relevantes a `3840x2160`, `4096x2160` ou
`2160p` no aplicativo, headers DRIMe IV, drivers específicos do DRIMe IV ou
rootfs. Ocorrências genéricas de `4K`, `3840` e `4096` encontradas no kernel são
tamanhos de página/buffer, constantes de outros drivers ou números não
relacionados a vídeo.

O arquivo abaixo define os framebuffers aceitos pelo codec:

```text
TIZEN/project/NX300/packages/linux-3.5/arch/arm/mach-drime4/dev-mfc.c
```

Perfis presentes:

```text
352x288
640x480
1920x1088 (armazenamento alinhado para 1920x1080)
1280x720
720x480
1920x816 (armazenamento alinhado para 1920x810)
```

O comentário após a tabela diz `TODO: add more format`, mas não é simples
evidência de que o hardware aceite formatos maiores.

Em `mfc_dev.c`, `mfc_fb_init()` seleciona o framebuffer por largura. São aceitas
somente as larguras `352`, `320`, `640`, `720`, `1280` e `1920`; qualquer outra
largura retorna `-EINVAL` com:

```text
fb do not support %d image
```

A API MFC também contém:

```c
#define SUPPORT_1080P 1
#define MAX_ENCODER_OUTPUT_BUFFER_SIZE (1024 * 3072)
```

Conclusão preliminar: criar apenas um enum/menu 4K não produziria 4K. Seria
necessário, no mínimo:

1. confirmar que o sensor oferece readout 3840/4096 a 24 fps;
2. criar configuração de sensor e pipeline IPCM para esse readout;
3. adicionar framebuffer MFC para a resolução;
4. confirmar que o firmware interno do MFC5x aceita macroblocos 4K;
5. redimensionar buffers/CMA e revisar largura de banda e clocks;
6. estender enums, menus, Edje, bitrate e atributos do camcorder.

A evidência atual sugere que o MFC desta geração é um encoder 1080p. Portanto,
4K24 H.264 interno é classificado como **muito improvável** sem substituir o
encoder por hardware externo ou desenvolver um método alternativo de captura.

Uma experiência 4K segura só deve ser considerada depois de mapear as tabelas de
modo do sensor e os limites do firmware MFC. Não se deve adicionar o item à UI
antes disso, pois buffers incompatíveis podem travar o pipeline ou corromper
memória.

### 2. HDMI e possibilidade de clean output

O enum `VideoFormat` em:

```text
TIZEN/project/NX300/imagedev/usr/include/drime4/udd/edid.h
```

vai até 1920x1080p60/50/30/25/24. Não contém nenhum modo HDMI 4K. A maior taxa
de pixel de uso convencional definida é 148,5 MHz; também não há os modos HDMI
2.0 de 297/594 MHz necessários para UHD comum.

Descoberta principal em `UI_Connect_Hdmi()` (`0x001b5ec8`): existe um caminho
oculto controlado por:

```text
UI_Get_Value(1060) = eUI_CONTROL_INFO_HDMI_LIVEVIEW_DEMO
```

Quando esse valor é diferente de zero, o aplicativo executa aproximadamente:

```cpp
putenv(...);
CDisplayerFactory factory;
factory.CreateDisplayer(device_2, 1920, 1080);
UI_Set_Power_Timer(true);
CProductionOSD::GetInstance()->Clean();
UI_Display_Manage(21, 0, 0, 0);
UI_Operate_Display_Ctrl_Set(7, 4);
mm_camcorder_stop(camcorder);
sysmmap_change_opmode(...);
UI_Set_HDMI_3D_Type(3);
UI_Set_Hdmi_Connect();
mm_camcorder_set_attributes(...);
UI_Set_Attr_Movie_Size(eUI_CAP_MOVIE_SIZE_1920_1080_30F /* 1 */);
mm_camcorder_start(camcorder);
```

Este caminho cria explicitamente um displayer 1920x1080, limpa o OSD de
produção e reinicia o camcorder em 1080p30. É evidência forte de que live view
HDMI já existe no firmware, embora possivelmente como demonstração/produção.

Classificação: **HDMI clean 1080 é promissor**. Próximos passos:

- localizar todos os escritores de `eUI_CONTROL_INFO_HDMI_LIVEVIEW_DEMO`;
- identificar a string passada a `putenv` e os nomes de atributos do camcorder;
- reconstruir `UI_Set_Hdmi_Connect`, `UI_Set_X_Crtc_Config_Liveview` e
  `CDisplayerFactory::CreateDisplayer`;
- descobrir se o `CProductionOSD::Clean()` remove somente a camada de produção
  ou todo o OSD da saída;
- testar primeiro por flag/menu de serviço, sem patch permanente.

### 3. Facebook, Picasa e Flickr

Aplicativos separados encontrados no rootfs:

```text
/opt/apps/com.samsung.facebook/bin/facebook
/opt/apps/com.samsung.picasa/bin/picasa
```

Tamanhos aproximados dos diretórios:

```text
Facebook: 3,5 MiB
Picasa:   820 KiB
```

O launcher do Facebook está em:

```text
/opt/share/applications/com.samsung.facebook.desktop
```

Ele registra serviços Tizen de compartilhamento de imagens e vídeos e marca o
pacote como `x-tizen-removable=false`. Isso impede remoção pela UI normal, mas
não impede removê-lo durante a construção de uma imagem customizada. Também há
UGs relacionados ao Facebook em `/opt/ug/lib/`.

Flickr não foi encontrado como pacote independente nesta imagem. A referência
do usuário pode corresponder a outra versão regional do firmware ou a um serviço
embutido no aplicativo Smart Wi-Fi; isso ainda precisa ser pesquisado nos
binários Wi-Fi específicos.

Remover aplicativos exige retirar de forma consistente:

- diretório em `/opt/apps/`;
- `.desktop` em `/opt/share/applications/`;
- UGs/plugins exclusivos;
- registros do banco de aplicações e handlers AppSvc;
- ícones, traduções e entradas no launcher Smart Wi-Fi.

Apagar somente o executável deixaria atalhos e serviços quebrados.

### 4. Telegram Lite e Instagram

Para uma câmera, a opção de menor complexidade é um **uploader baseado em bot do
Telegram**, não um cliente completo. A Bot API usa HTTPS e permite envio de
fotos, documentos e vídeos para chats autorizados. Um uploader pode ter UI local
mínima para configurar token/chat e selecionar arquivos do cartão.

Um cliente Telegram completo usaria MTProto, autenticação de usuário, sessões,
2FA e sincronização; isso é muito mais pesado e arriscado para o Tizen antigo.

Risco técnico imediato: o rootfs contém `libcurl 7.21.3` e uma pilha OpenSSL
antiga. Serviços atuais podem recusar os protocolos/ciphers/CA disponíveis.
Provavelmente será necessário portar uma biblioteca TLS mais nova ou executar um
relay controlado na rede local.

A API oficial atual do Instagram não substitui o antigo aplicativo consumidor:
publicação é voltada a contas profissionais e exige fluxo Meta/OAuth, permissões
e infraestrutura compatíveis. Além das restrições da plataforma, o browser/TLS
antigo da NX300 torna a autenticação moderna problemática.

Classificação:

```text
Telegram Bot uploader: viável, com atualização de TLS ou relay
Telegram cliente completo: baixa prioridade / alta complexidade
Instagram oficial: baixa viabilidade como app autônomo da câmera
Instagram via relay próprio: tecnicamente possível, sujeito às regras da API
```

Referências oficiais consultadas durante a triagem:

```text
https://core.telegram.org/bots/api
https://core.telegram.org/api/obtaining_api_id
https://developers.facebook.com/docs/instagram-platform/content-publishing/
https://developers.facebook.com/docs/instagram-platform/instagram-api-with-instagram-login/
```

### 5. Webcam por USB

O `drime4_defconfig` confirma:

```text
CONFIG_VIDEO_DEV=y
CONFIG_USB_GADGET=y
CONFIG_USB_DRIME4_SS_UDC=y
CONFIG_USB_GADGET_DUALSPEED=y
CONFIG_USB_GADGET_SUPERSPEED=y
CONFIG_USB_FUNCTIONFS=m
CONFIG_USB_FUNCTIONFS_GENERIC=y
# CONFIG_USB_G_WEBCAM is not set
# CONFIG_USB_ETH is not set
# CONFIG_USB_G_NCM is not set
```

Portanto, o hardware/kernel já possui controlador USB device SuperSpeed e
infraestrutura gadget. O gadget UVC/webcam existe no kernel 3.5, mas veio
desabilitado.

Isso torna **UVC por USB a opção de webcam mais promissora**, mas habilitar
`CONFIG_USB_G_WEBCAM` é apenas a camada de transporte. Ainda será preciso:

- obter frames do live view sem conflitar com o `mm_camcorder`;
- decidir entre YUYV/MJPEG/H.264 conforme suporte do host e largura de banda;
- implementar o produtor userspace ou ligação kernel entre IPCM e UVC;
- definir descritores e intervalos reais de frame;
- garantir que o modo USB atual não encerre o camcorder para entrar em PTP/MTP.

Para 1080p48, vídeo não comprimido YUYV requer aproximadamente:

```text
1920 * 1080 * 2 * 48 = 199.065.600 bytes/s (~1,59 Gbit/s)
```

Isso cabe nominalmente em USB 3.x, mas é agressivo para CPU, memória e UVC desta
plataforma. MJPEG ou H.264 é mais realista. O MFC já prova 1080p60 em gravação,
logo 1080p48/50 comprimido deve ser investigado antes de prometer o modo.

### 6. Webcam por Wi-Fi

O aplicativo já contém Remote Viewfinder e callbacks de streaming:

```text
UI_WiFi_Rvf_Construct
UI_Wifi_Rvf_CB_Stream_Start
UI_Wifi_Rvf_CB_Stream_Stop
UI_Wifi_Rvf_Event_Handle
```

Há, portanto, um pipeline de preview por Wi-Fi reutilizável. A resolução e o
codec ainda não foram confirmados. É provável que o Remote Viewfinder original
use preview reduzido, então atingir 1080p48 exigirá trocar a fonte/encoder e o
protocolo, não apenas aumentar uma constante.

Arquiteturas candidatas:

1. RTP/RTSP H.264 sobre Wi-Fi;
2. HTTP/MJPEG para protótipo simples;
3. USB Ethernet/NCM + RTP, combinando baixa complexidade no host com cabo;
4. UVC nativo, preferível para compatibilidade universal.

### 7. Bluetooth

No `drime4_defconfig` específico:

```text
# CONFIG_BT is not set
```

A definição da placa `board-d4-nx300.c` não mostrou integração de controlador
Bluetooth. Bibliotecas Bluetooth presentes no rootfs são componentes genéricos
do Tizen e não comprovam a existência de rádio na câmera.

Mesmo que fosse adicionado um dongle/controlador, Bluetooth clássico 2.x/3.x e
BLE são inadequados para 1080p48 de alta qualidade. O bitrate de vídeo seria
muito superior ao throughput útil. Bluetooth pode servir para controle remoto,
status, disparo ou configuração, mas não é um transporte de webcam razoável.

Classificação: **descartado para vídeo; potencial somente para controle com
hardware adicional**.

### Priorização técnica após a triagem

| Prioridade | Objetivo | Viabilidade inicial |
|---:|---|---|
| 1 | HDMI clean 1080 | Alta/promissora; caminho oculto já existe |
| 2 | Webcam USB UVC | Média/alta; gadget SS existe, integração falta |
| 3 | Webcam Wi-Fi H.264 | Média; Remote Viewfinder pode ser reutilizado |
| 4 | Telegram Bot uploader | Média/alta após resolver TLS |
| 5 | Remover Facebook/Picasa/serviços obsoletos | Alta em imagem customizada |
| 6 | Instagram | Baixa sem relay e conta/API compatível |
| 7 | 4K24 interno | Muito baixa devido ao MFC 1080p |
| 8 | Vídeo por Bluetooth | Inviável |

## 2026-08-09 11:10:29 -03 — Overclock do DRIMe IV e da memória

### Estado e segurança

Análise estática somente leitura. Nenhum bootloader, kernel ou registrador foi
modificado. Alterações de clock no bootloader são particularmente perigosas:
falha antes do kernel pode impedir boot normal e exigir recuperação por
`dnloader.bin`/opener pad.

### Artefatos e hashes

```text
2edd2e63a2128aebdfa57ae0f0d0bbe1d5a7436baa812b21082a4eec45e617a7  TIZEN/project/NX300/binary/bootloader/D4_PNLBL.bin
b53dccc1fa6b8ef2d3b2dfb5702977c207d04da90a8bddd0fb8f7371d1374071  TIZEN/project/NX300/binary/bootloader/D4_IPL.bin
63375f731f1c218ec74023a323f3d421307f6dd31a3513755a4427cf497de49c  TIZEN/project/NX300/packages/linux-3.5/arch/arm/mach-drime4/clock.c
49e746a809f4a2f92e9141cb6c7a50fd4f0ee329e3f371a2d78553a5da2b01b4  TIZEN/project/NX300/packages/bootloader/usr/init_lpddr2_533M.h
```

### Domínios de clock relevantes

O DRIMe IV possui PLLs distintos:

```text
SYSPLL1  — DDR e derivados de sistema
SYSPLL2  — barramentos/periféricos e derivados
LCDPLL   — display e fontes alternativas
ARMPLL   — Cortex-A9/L2/ACLK do subsistema ARM
AUDPLL   — áudio
```

Portanto, aumentar o Cortex-A9 não aumenta automaticamente DDR, MFC, display ou
pipeline de imagem.

Registradores definidos pelo bootloader:

```text
CLOCK_CTRL_BASE = 0x30120000
SYSPLL1_CON1    = 0x30120030
SYSPLL1_CON2    = 0x30120034
SYSPLL2_CON1    = 0x30120038
SYSPLL2_CON2    = 0x3012003c
LCDPLL_CON1     = 0x30120040
LCDPLL_CON2     = 0x30120044
ARMPLL_CON1     = 0x30120048
ARMPLL_CON2     = 0x3012004c
PLL_LOCK_STS    = 0x30120080
```

Controladores DDR:

```text
LS_DDR_CTRL_BASE = 0x50000000
HS_DDR_CTRL_BASE = 0x50010000
```

### Clock da CPU

`Makefile.pnlbl`, que constrói o loader principal, contém:

```make
DEFS += -DARM_700Mhz
```

`Makefile.dnloader` usa:

```make
DEFS += -DARM_800Mhz
```

O IPL inicial usa 400 MHz, enquanto o loader principal muda para 700 MHz:

```text
D4_IPL:    400 MHz
D4_PNLBL:  700 MHz
dnloader:  800 MHz
```

`board_primitive_api.c` implementa caminhos completos para 500, 600, 700 e
800 MHz. O comentário do código informa que o estado padrão do ARMPLL é 800 MHz.

A tabela de PLL no kernel aceita:

```text
ARMPLL: 500, 600, 700 e 800 MHz (cristal de 24 MHz)
ARMPLL: 400, 500, 600, 700 e 800 MHz (cristal de 27 MHz)
```

Não existe entrada ARMPLL acima de 800 MHz.

O `drime4_defconfig` não habilita `CONFIG_CPU_FREQ`; portanto não há governor ou
interface sysfs normal para subir o clock durante a execução. O kernel apenas
descobre o clock que foi programado pelo loader.

#### Candidato conservador: 700 → 800 MHz

```text
ganho nominal = 800 / 700 - 1 = 14,2857%
```

Este é o único overclock inicialmente recomendável porque:

- usa uma frequência já presente na tabela oficial;
- usa uma configuração já exercida pelo `dnloader` no mesmo SoC;
- não exige inventar parâmetros PLL;
- pode ser obtido pela seleção `ARM_800Mhz` já implementada.

Ainda não foi confirmado se 700 MHz foi escolhido por consumo, temperatura,
binning do silício ou limite do regulador. O fato de o dnloader usar 800 MHz não
prova estabilidade em carga contínua: recovery executa por períodos curtos e com
menos subsistemas ativos.

Não foi localizada até aqui uma tabela explícita de tensão CPU por frequência
para a NX300. Há referência a e-fuse para controle de tensão do core DRIMe IV,
o que sugere calibração/binning individual. Por isso, não é prudente aumentar
tensão antes de reconstruir o controle PMU.

### L2 e barramento ARM

No caminho de 800 MHz, os divisores do bootloader mantêm aproximadamente:

```text
CPU/A9: 800 MHz
L2:     CPU / 2
ACLK:   CPU / 2
CSCLK:  CPU / 2
```

No caminho de 700 MHz, L2 pode operar sem o mesmo divisor usado no ramo de
800 MHz, conforme a programação de `rCPUSYS_CPU_CLKSEL`. Isso precisa ser
validado com cálculo completo do registrador antes de comparar desempenho: o
ganho de CPU não significa necessariamente +14,3% em L2/barramento.

### Memória da NX300

O build da NX300 confirma:

```text
TIZEN/build/config/nx300_config: CONFIG_LPDDR2_533MHZ=y
TIZEN/build/config.h:            #define CONFIG_LPDDR2_533MHZ 1
```

O bootloader fornece perfis completos para:

```text
LPDDR2 400 MHz
LPDDR2 480 MHz
LPDDR2 500 MHz
LPDDR2 533 MHz
DDR3   400 MHz
DDR3   533 MHz
```

A NX300 já usa o perfil LPDDR2 mais alto disponível: 533 MHz de clock,
correspondente a LPDDR2-1066 em taxa efetiva.

O perfil de 533 MHz configura, entre outros:

```text
SYSPLL1/DDR source
PHY DLL
ZQ calibration
read/write latency via mode registers
drive strength
refresh
SDRAM timing 1/2/3
DQ calibration
```

Isso mostra por que alterar apenas o divisor DDR seria inseguro. Acima de
533 MHz seria necessário criar um novo conjunto coerente de timings, recalcular
refresh, verificar o speed grade físico dos chips e validar a janela do PHY.

#### Possibilidade real de overclock da RAM

Não há perfil pronto acima de 533 MHz. `SYSPLL1` no kernel tem frequências de
até 1066 MHz e a DDR pode usar `SYSPLL1 / 2`, produzindo os 533 MHz atuais.
Aumentar `SYSPLL1` também pode afetar outros clocks derivados e não existe uma
entrada documentada acima de 1066 MHz para esse PLL.

Conclusão: **a RAM já está no máximo previsto pela plataforma**. Overclock de
memória não deve ser a primeira modificação.

### Relação com 4K e webcam

CPU 800 MHz pode ajudar em:

- UI e aplicações de rede;
- TLS moderno e uploader Telegram;
- cópias de buffers e protocolos de webcam;
- MJPEG/software auxiliar.

Não remove o limite 1080p do MFC. O driver de encoder trava separadamente MFC e
barramento para conteúdo 1080p, com comentários indicando MFC em 200 MHz e bus
em 400 MHz. Logo, CPU 800 MHz não transforma o encoder em 4K nem aumenta sozinho
a capacidade de H.264.

### Estratégia recomendada de teste

1. Confirmar o procedimento de recovery com `dnloader.bin` antes de qualquer
   flash de bootloader.
2. Construir artefatos modificados em diretório separado; nunca sobrescrever os
   binários originais.
3. Alterar somente `D4_PNLBL` de `ARM_700Mhz` para `ARM_800Mhz`, mantendo DDR
   LPDDR2-533 e todas as demais configurações.
4. Se possível, criar uma variante carregável temporariamente em RAM ou por
   recovery, evitando gravar NAND no primeiro teste.
5. Registrar clock efetivo e temperatura em idle/carga.
6. Executar testes de CPU, memória, captura contínua, vídeo 1080p60, HDMI, USB e
   Wi-Fi por períodos progressivos.
7. Verificar corrupção silenciosa com hashes de buffers/arquivos, não apenas
   ausência de crash.
8. Manter watchdog e caminho de recuperação independentes.

Critérios para abandonar 800 MHz:

```text
PLL sem lock, boot intermitente, kernel panic, erro de captura/MFC,
artefatos de imagem, corrupção de arquivo, falhas Wi-Fi/USB,
temperatura excessiva ou consumo que cause desligamento.
```

### Classificação

| Alteração | Viabilidade | Risco | Ganho esperado |
|---|---|---|---|
| CPU 700→800 MHz | Alta tecnicamente | Médio | Até 14,3% em tarefas CPU-bound |
| Manter CPU em 800 continuamente | A confirmar em hardware | Médio/alto térmico | Depende de throttling/carga |
| CPU acima de 800 MHz | Sem suporte pronto | Alto | Incerto |
| RAM LPDDR2 533→acima | Sem perfil/PLL pronto | Muito alto | Provavelmente pequeno |
| MFC/bus overclock | Ainda não analisado | Alto | Potencial para encoder/webcam, não 4K garantido |

## 2026-08-09 11:23:34 -03 — Comparação NX300 × NX500: UHD, readout e HDMI clean

### Materiais examinados

- `NX500/SM-NX500.pdf` (convertido somente para `/tmp` para busca textual).
- Kernel NX500 em
  `NX500/NX500_opensource_2015_03_04/NX500_kernel/home/songha.choi/osp/NX500/linux-3.5`.
- Nenhum arquivo original da NX300 ou NX500 foi alterado.

### Sensor/readout: não é o mesmo silício

O service manual compara diretamente os dois sensores:

```text
NX500: VB2, BSI CMOS, 28,2 MP efetivos / 30,7 MP totais
NX300: CT3, CMOS,     20,3 MP efetivos / 21,6 MP totais
```

O diagrama da NX500 mostra `VB2_D5_D[0:15]`, clocks e interface sLVDS. O kernel
também possui pinagem específica `GPIO_VB2_D5_*`. Portanto, qualquer tabela de
registradores, binning, crop ou temporização de readout do VB2 não pode ser
copiada para o CT3. Até aqui, o OSS não expôs as tabelas privadas de programação
do sensor; elas provavelmente estão no firmware/biblioteca proprietária de
captura.

### 4K confirmado como pipeline físico do DRIMe5

O manual especifica:

```text
4096x2160: 24 fps
3840x2160: 30 fps NTSC / 25 fps PAL
compressão: HEVC (MJPEG apenas VGA)
limite por clipe UHD: 20 minutos
```

O kernel contém suporte efetivo, não apenas strings de interface:

- `drime5_hdmi.c`: modos `D5_RES_4096_2160p_UD_24Hz` e
  `D5_RES_3840_2160p_UD_25/30Hz`;
- `d5_hdmi.c` e TV/SLCD: tabelas de timing UHD;
- `drime5-ispfreq.c`: estados `MV_UHD`/`MV_UD`, com configuração dedicada de
  ISP, display, barramento e DDR;
- `board-d5_nx500.c`: registra `device_d5_hevc`;
- `dev-d5_hevc.c`: janela física do codec em `0x200f0000..0x200f0dff`;
- `d5_hevc_ioctl.c`: abre o clock `d5_hevc` a 260 MHz;
- `d5_enc_host_ctrl.c`: comentário de dimensionamento `UHD30p @266MHz w/20%
  margin` para os modos de baixa complexidade e all-intra;
- `d5_hevc_type.h`: parâmetros reais de encoder — largura, altura, GOP,
  bitrate, frame rate, QP e endereços dos buffers.

O `probe` inicial configura 200 MHz, enquanto a abertura via ioctl eleva o
codec a 260 MHz. Isso é compatível com a nota de projeto de 266 MHz para UHD30.

### Consequência para 4K na NX300

A NX500 confirma como a Samsung implementou 4K na geração seguinte, mas também
mostra por que isso não é um simples backport:

1. sensor diferente (`VB2` contra `CT3`);
2. entrada física e pinagem próprias;
3. estado de clocks `MV_UHD` inexistente no DRIMe IV;
4. bloco HEVC dedicado inexistente na árvore DRIMe IV;
5. controlador/PHY HDMI DRIMe5 com timings UHD, enquanto o D4 examinado termina
   em 1080p;
6. o MFC da NX300 aloca e documenta buffers apenas até a família 1920x1088.

Assim, criar apenas o item 3840x2160/4096x2160 na UI da NX300 produziria um modo
sem suporte nas camadas seguintes. A chance de gravação 4K interna por simples
patch é muito baixa. O que ainda merece investigação é o limite máximo de
readout bruto/crop do CT3, para saber se existe algum modo acima de 1080p que
possa ser enviado externamente ou usado sem o MFC — isso exige localizar a
biblioteca/firmware proprietário do sensor.

### Descoberta transferível: clean HDMI

O DRM da NX500 recebe `uhd_clean_mode` por
`drime5_drm_set_graphic_clone_mode()`. Quando a flag está ativa, o commit de uma
janela gráfica retorna antes de programar a camada, mas a janela de vídeo segue
o caminho normal:

```c
if (win < ctx->grp_default_win) {
    /* video case */
    ...
} else {
    if (g_uhd_clean_mode || g_poweroff_logo_state)
        return;
    /* graphic case */
    ...
}
```

Isso prova que a solução posterior da Samsung para saída limpa consiste em
separar a camada de vídeo da camada gráfica/OSD, e não em gerar um stream novo.
Na NX300 já foi encontrado o controle oculto
`eUI_CONTROL_INFO_HDMI_LIVEVIEW_DEMO`, que limpa `CProductionOSD`, cria saída
1920x1080 e reinicia o camcorder em 1080p30. Os registradores D5 não são
portáveis, mas a política de omitir a camada gráfica é diretamente aplicável à
análise do caminho D4.

### Classificação de reutilização

| Elemento da NX500 | Uso na NX300 |
|---|---|
| Tabelas/readout do sensor VB2 | Não portável; sensor e interface diferem |
| Driver e registradores HEVC D5 | Não portável; bloco físico ausente no D4 |
| Timings HDMI UHD D5 | Não portável diretamente; controlador/PHY diferente |
| Estado DVFS `MV_UHD` | Referência arquitetural; não cria hardware no D4 |
| Separação vídeo/OSD de `uhd_clean_mode` | Fortemente reutilizável como conceito |
| API de largura/altura/GOP/bitrate do HEVC | Útil para entender o pipeline NX500 |
| QoS e escalonamento de clocks por modo | Útil como modelo para 1080p de alta taxa |

### Próximos passos

1. Localizar binários/bibliotecas proprietárias da aplicação e captura NX500,
   se estiverem presentes no pacote ou em firmware adicional.
2. Reconstruir a chamada userspace que preenche `uhd_clean_mode` e comparar com
   `UI_Connect_Hdmi()` da NX300.
3. Procurar no firmware NX300 as tabelas/configuração do sensor `CT3`, incluindo
   modos de crop, binning, clocks e frame rate.
4. Comparar os pipelines FHD60/FHD120 da NX500 com o MFC e IPCM D4 para extrair
   apenas estratégias de buffer/QoS aplicáveis a 1080p48/60.

## 2026-08-09 11:36:09 -03 — CT3: driver e modos reais encontrados

### Biblioteca decisiva

`imagedev/usr/lib/libcapture-fw-slpcam-nx300.so` possui Build ID
`94cefe600aec538e370ab678e11b6db209987788`, tamanho 4.791.660 bytes e cerca de
12.100 símbolos dinâmicos. Apesar de marcada como stripped, preserva nomes C++
suficientes para reconstrução de alto nível.

O arquivo correspondente em `usr/lib/debug` tem somente 1.732 bytes; suas
seções de código/dados são `NOBITS` e ele não contém DWARF utilizável.

### Driver CT3 localizado

O sensor é explicitamente identificado pela string `CIS is CT3` e pela classe
`CAquilaCt3Driver`. O binário ainda contém o caminho fonte original:

```text
/home/andy.yoo/nx300/project/NX300/packages/capture-fw-prod/
ProductNX/Frontend/Sensor/AquilaCt3Driver.cpp
```

Funções prioritárias:

```text
0x002d3fd8  CAquilaCt3Driver::SetMode(...)
0x002d468c  CAquilaCt3Driver::SetupFullHdMode(...)
0x002d4a60  CAquilaCt3Driver::SetupVideoFull()
0x002d54dc  CAquilaCt3Driver::SetupSkipping(...)
0x002d55e4  CAquilaCt3Driver::SetupWindow(...)
0x002d57ec  CAquilaCt3Driver::SetupFrameInfo(...)
0x002d5d60  CAquilaCt3Driver::Setup_CDStiming()
0x002d5ec8  CAquilaCt3Driver::Setup_CDStiming_60FPS()
0x002d6000  CAquilaCt3Driver::Setup_CDStiming_FullSize()
0x002d6380  CAquilaCt3Driver::BeginReadout()
0x002d880c  CAquilaCt3Driver::UpdateFramerateInfo(...)
0x002d8f74  CAquilaCt3Driver::UpdateTgInfo(...)
0x002d94b4  CAquilaCt3Driver::WriteRegister(uint16_t,uint16_t)
0x002d9610  CAquilaCt3Driver::ReadRegister(uint16_t)
```

Há também modos explícitos FHD, FHD60, 120 fps, 240 fps, cinema 10-bit,
movie 10-bit e raw dump. Logo, as configurações de readout não estão ausentes:
estão incorporadas no driver proprietário e podem ser reconstruídas.

### Descoberta: readout full-size em caminho de vídeo

`CAquilaCt3Driver::SetupVideoFull()` seleciona uma fonte full-size, muda o
sensor para 12 bits e executa:

```text
SetupFrameInfo(width,height) usando dimensões do objeto de imagem full-size
SetupWindow(48, 38, 5624, 3714)
SetupSkipping(1, 1, 1, 1)
Setup_CDStiming_FullSize()
EnableStream(true)
```

O retângulo 5624x3714 contém ~20,89 MP, coerente com a área ativa do sensor.
Isso demonstra que o CT3 consegue fornecer readout full-size por um modo
denominado vídeo; ainda não sabemos seu frame rate. Se for aproximadamente
9 fps, o fluxo ativo seria ~188 Mpixel/s; 3840x2160x24 exige ~199 Mpixel/s antes
do blanking. Portanto, medir os clocks e timings desse modo pode decidir se um
crop 4K24 fica próximo da capacidade já utilizada.

### Estrutura do seletor de modos

`SetMode()` possui uma jump table com 16 modos e chama rotinas distintas para
FHD, vídeo normal, burst, 120 fps, 240 fps e full-size video. No nível superior,
`CFrontendServiceNx::videoSetSensorMode()` aceita valores até 14 e monta um
`CSensorModeConfig` com frame rate, lock, proporção, PAF e FastHD antes de chamar
virtualmente o driver.

### Próxima medição necessária

Reconstruir `UpdateTgInfo`, `SetupFrameInfo` e as rotinas de timing para obter:

- HD count por VD;
- tempo de linha e período de frame;
- clock de pixel/serial efetivo;
- frame rate do modo 5624x3714;
- diferenças exatas entre FHD30 e FHD60;
- margem teórica para um crop 3840x2160 a 24 fps.

## 2026-08-09 12:08:00 -03 — Perfis TG e sonda CT3 v1

### Perfis criados por `CAquilaCt3Driver::Create()`

O driver instancia objetos `CSensorTgInfo` e calcula a taxa com clock base de
304.000.000 Hz (253.200.000 Hz no objeto full-size). Os pares de contagem
observados produzem:

```text
3108 x 1631  = 59,9706 fps   (variante: 49,9806)
3108 x 3261  = 29,9945 fps   (variante: 24,9967)
3772 x 1344  = 59,9657 fps   (variante: 49,9962)
3772 x  672  = 119,9313 fps  (variante: 99,9924)
3108 x  408  = 239,7355 fps
3108 x 4076  = 23,9971 fps
3108 x 2038  = 47,9942 fps
6404 x 11078 = 3,5690 fps, usando 253,2 MHz
```

`UpdateTgInfo()` confirma diretamente o mapeamento comercial:

```text
enum 12 -> 23,997 fps (24p)
enum 13 -> 24,997 fps (25p)
enum 14 -> 29,995 fps (30p)
enum 17 -> 49,981 fps (50p)
enum 18 -> 59,971 fps (60p)
```

Os objetos restantes correspondem aos caminhos especiais 48/100/120/240 fps
e full-size. O perfil full-size é somente ~3,57 fps, portanto a comparação
anterior com 9 fps era uma hipótese otimista e não deve ser usada como prova de
largura de banda para 4K24. Ainda assim, os modos rápidos demonstram clock e
taxas de linha muito superiores quando crop/skipping são usados; a questão
central passa a ser construir uma janela 3840x2160 que caiba no orçamento de
linha e no receptor/pipeline D4.

### Interface temporária encontrada

`CAquilaCt3Driver::DebugProcess(int,char**)` está inscrito no console de debug
com o nó `cis`. A hierarquia observada é acessível por `/usr/bin/st cap cis` e
inclui `info`, `regw`, `regr`, `live`, `stop`, `clockoff`, `clockon`, `hwrst` e
outros comandos. O caso `regr` converte o endereço por `atoh()` e chama
`ReadRegister(uint16_t)`; assim, strings como `0340` são hexadecimais.

Foi criado o experimento reversível:

```text
experiments/ct3_4k24_probe_v1/autoexec.sh
experiments/ct3_4k24_probe_v1/ct3_probe.sh
experiments/ct3_4k24_probe_v1/README.md
experiments/ct3_4k24_probe_v1/MANIFEST.sha256
```

A sonda espera 12 segundos pela aplicação, coleta informações e lê os
registradores relevantes de janela/timing. Ela não escreve registradores nem
altera o rootfs. A remoção dos scripts do cartão elimina o teste.

## 2026-08-09 12:24:00 -03 — Execução real da sonda v1

Os arquivos recebidos em `experiments/logs/` mostram:

```text
Linux nx300 3.5.0+ #24 PREEMPT ... armv7l
uid=0(root) gid=0(root)
di-camera-app ativo, PID 267
início 12:05:06 UTC
término 12:05:19 UTC
```

`CT3_PROBE_V1.LOG` contém todos os marcadores e chega ao fim. O arquivo
`ct3_probe_boot.log` tem tamanho zero, coerente com uma execução sem erros do
launcher. Entretanto, nenhum valor aparece após `cis info` ou `cis regr`.

### Causa confirmada

`/usr/bin/st` não é um cliente de requisição/resposta. Para o comando `cap`, ele
chama `shell_sndmsg()`, que usa `msgget(0x8828, ...)` e `msgsnd()` e retorna logo
após enfileirar até dez argumentos. Dentro do processo da câmera,
`shell_thread_func()` bloqueia em `msgrcv()`, reconstrói `argv` e chama o parser
registrado. Assim, os `printf()` de `CAquilaCt3Driver::DebugProcess()` e do
resultado de `ReadRegister()` pertencem ao stdout de `di-camera-app`, não ao
stdout do executável `st` iniciado pelo autoexec.

Isso valida a interface e explica o log vazio; não demonstra falha de leitura.
A sonda `ct3_console_probe_v1_1` coleta `/proc/<pid>/fd`, filas SysV e os ring
buffers `dlog` antes/depois de três comandos para localizar o canal de saída sem
alterar o processo nem escrever no sensor.

## 2026-08-09 12:38:00 -03 — Destino do console confirmado

A sonda v1.1 identificou no PID 267:

```text
fd 0 -> /dev/null
fd 1 -> /dev/console
fd 2 -> /dev/console
fd 3 -> /dev/log_main
fd 4 -> /dev/log_radio
fd 5 -> /dev/log_system
fd 28 -> /dev/hs_spidev.4
```

Os arquivos `CT3_DLOG_BEFORE_V1_1.LOG` e `CT3_DLOG_AFTER_V1_1.LOG` possuem o
mesmo SHA-256:

```text
84a69017aca35460810ae9d04a391c59034a85ddbd1d7505e0a4de2ad7b42443
```

Os retornos de `info` e dos três `regr` foram todos `1`. Pela desmontagem de
`shell_sndmsg()`, esse retorno significa que `msgsnd()` teve sucesso. A fila de
chave decimal 34856 (`0x8828`) aparece ativa e é a mesma chave usada pelo
receptor dentro da aplicação.

O rootfs contém `/usr/bin/strace`. Como `shell_thread_func()` chama
`prctl(PR_SET_NAME, "shell_di_camera_app")`, a sonda v1.2 pode anexar somente a
essa thread e capturar os `write()` dos resultados ao console, evitando tanto o
reinício da aplicação quanto interferência nas outras aproximadamente 70
threads.

## 2026-08-09 12:48:00 -03 — Primeira telemetria real do sensor CT3

A v1.2 encontrou `shell_di_camera` no TID 310 e capturou integralmente o
relatório `cis info` e três leituras. O estado observado foi:

```text
modo                   eSensorModeLiveview
tempo de exposição     32,633 ms
ganho de vídeo          x8
frame rate solicitado   30 fps
frame rate calculado    29,982830 fps
HD count/VD             1344
clock/HD                3772
VD time                 16676,21 us
HD time                 12,40 us
m_uiHdCount             2630
formato                  NTSC
```

O próprio driver imprimiu também todos os perfis calculados, confirmando os
valores obtidos estaticamente para 24/25/30/50/60/100/120/240 e 3,569 fps.

### Registradores reais em live view

```text
0x0340 = 0x0A80 (2688)
0x0342 = 0x0EBC (3772)
0x3404 = 0x0005
```

`0x0342` coincide exatamente com `clock/HD=3772`. `0x0340=2688` é duas vezes
o `HD count/VD=1344`, indicando que o registrador físico e a contagem lógica do
TG diferem por um fator de dois nesse modo. Isso corrige a interpretação
preliminar: `0x0340/0x0342` são contagens de frame/linha, não simplesmente
largura e altura de imagem, apesar de `SetupFrameInfo()` receber valores vindos
do objeto de dimensão.

A captura v1.3 amplia a leitura para 66 endereços, incluindo os registradores
padrão `0x0344..0x034E`, `0x0380..0x0386`, `0x0900/0x0901` e toda a família CDS
Samsung `0x3404..0x3492`. Esses valores formarão o snapshot restaurável exigido
antes do primeiro `regw` experimental.

## 2026-08-09 12:58:00 -03 — V1.3 recebida, valores rejeitados

A v1.3 enviou todos os 66 comandos (`rc=1`) e o trace contém 66 ocorrências de
`CIS_READ ADDRES`, provando que o parser os processou. Porém as chamadas foram
decodificadas como `write(15, "CIS_READ ADDRES", 15) = 1`, sem a parte de dados,
e algumas operações `msgrcv` apareceram deslocadas como `write(208, ...)`.

A causa é a anexação no meio do `msgrcv()` bloqueante com essa syscall excluída
do filtro do `strace` antigo. A v1.3.1 inclui explicitamente `msgrcv,write` e
adiciona 100 ms entre comandos. Por integridade experimental, nenhuma string
truncada da v1.3 foi inferida ou incorporada ao mapa de registradores.

## 2026-08-09 13:12:00 -03 — Superfície de acesso remoto

O teste externo encontrou `ECONNREFUSED` em TCP 22 e 23, indicando câmera
alcançável mas nenhum listener. A árvore confirma ausência de `sshd` e
`dropbear`. Logo, abrir TCP 22 por si só não cria SSH.

O BusyBox estático da imagem é 1.18.4 e contém os applets `telnet`, `telnetd` e
`nc`. Existem os links:

```text
/usr/sbin/telnetd -> ../../bin/busybox
/usr/bin/telnet   -> ../../bin/busybox
/usr/bin/nc       -> ../../bin/busybox
```

`/etc/shadow` registra `root::15544:...`, sem hash de senha. Embora
`/etc/securetty` possa restringir login root em pseudo-terminal, `telnetd -l
/bin/sh` executa diretamente o shell e contorna a etapa de login. Isso é útil
para laboratório, mas constitui uma shell root sem autenticação.

O experimento `network_console_v1` inicia dois `telnetd`: TCP 23 e TCP 22. Os
dois falam Telnet; clientes SSH falharão na porta 22. O script não persiste nada
no rootfs. Reiniciar sem o autoexec remove o acesso.

## 2026-08-09 13:52:00 -03 — Validação real dos listeners

O log real confirma inicialização bem-sucedida:

```text
telnetd_23_rc=0
telnetd_22_rc=0
0.0.0.0:23 LISTEN PID 364/telnetd
0.0.0.0:22 LISTEN PID 367/telnetd
```

Antes da inicialização, apenas Xorg escutava em TCP 6000. A listagem de
interfaces continha somente `lo`, demonstrando que o autoexec roda antes da
ativação do Wi-Fi. Isso não invalida o console: bind em `0.0.0.0` abrange
interfaces criadas posteriormente. O teste externo deve ser feito depois de a
câmera conectar à rede sem fio.

## 2026-08-09 14:02:00 -03 — Handshake Telnet e encerramento do login

O teste externo evoluiu de `No route to host` para conexão Telnet completa em
TCP 22 e 23, seguida imediatamente por `Connection closed by foreign host`.
Isso prova simultaneamente que rota, bind e protocolo Telnet estão funcionais;
o encerramento ocorre na criação da sessão.

A hipótese mais forte é que `telnetd` executa o programa indicado por `-l` com
argumentos próprios de login. Ao apontar diretamente para `/bin/sh`, esses
argumentos podem ser interpretados como opções e causar saída imediata. A v1.1
aponta `-l` para um wrapper no SD que não repassa `$@`, configura ambiente e
executa `exec /bin/sh -i`. O wrapper também grava PID, PPID, argumentos recebidos
e UID em `NX300_SHELL_SESSIONS.LOG`, permitindo confirmar a causa.

## 2026-08-09 14:12:00 -03 — Acesso interativo obtido com inetd

Foi confirmada uma sessão remota funcional ao iniciar o serviço através de
`inetd.conf`. Isso elimina a necessidade de substituir o autoexec para cada
ensaio: scripts de pesquisa podem permanecer como arquivos independentes no SD
e ser iniciados por `/bin/sh /mnt/mmc/<script>`.

O acesso não muda o roteamento do console interno do capture framework:
`st cap cis` ainda executa o parser na thread do `di-camera-app`, cujo stdout é
`/dev/console`. Portanto as leituras CT3 continuam usando `strace` anexado à
thread `shell_di_camera`; a vantagem do Telnet é poder iniciar a sonda, conferir
processos e recuperar os arquivos sem reboot.

## 2026-08-09 14:20:00 -03 — Estado de rede da sessão funcional

Telemetria fornecida pelo shell root:

```text
wlan0  192.168.68.100  máscara 255.255.252.0
TCP 21    PID 368/inetd
TCP 23    PID 368/inetd
TCP 80    PID 366/httpd
TCP 6000  PID 232/Xorg
```

O Telnet entrega diretamente `uid=0(root)`. A configuração funcional difere da
sonda standalone: não há listener em 22, enquanto FTP/21 e HTTP/80 estão ativos.
`cat /etc/inetd.conf` não produziu conteúdo, indicando que o PID 368 recebeu
outro arquivo de configuração na linha de comando. A inspeção de
`/proc/368/cmdline`, `cwd` e `fd` é necessária antes de classificar autenticação,
raiz de FTP e persistência do serviço.

## 2026-08-09 14:27:00 -03 — Configuração inetd exata

O arquivo funcional contém:

```text
21 stream tcp nowait root ftpd   ftpd -w /mnt/mmc/
23 stream tcp nowait root telnet telnetd -i -l /bin/bash
```

`telnetd -i` explica a diferença em relação ao ensaio standalone: o daemon trata
o socket herdado do inetd e entrega o PTY ao `/bin/bash`, que permanece
interativo. O serviço roda sob o usuário `root` definido na quinta coluna.

`ftpd -w /mnt/mmc/` torna a raiz FTP o cartão SD e habilita operações de escrita.
Isso cria um ciclo rápido de desenvolvimento:

```text
host --FTP upload--> /mnt/mmc/sonda.sh
host --Telnet------> /bin/sh /mnt/mmc/sonda.sh
host <--FTP download-- logs no SD
```

Não há indicação de autenticação ou TLS nessas linhas. A exposição deve ser
tratada como acesso root/SD para qualquer host capaz de alcançar as portas.

## 2026-08-09 14:31:00 -03 — Sequência de boot do laboratório remoto

O autoexec funcional foi fornecido integralmente:

```sh
#!/bin/sh
mkdir -p /dev/pts
mount -t devpts none /dev/pts
httpd -h /mnt/mmc
inetd /mnt/mmc/inetd.conf
```

A montagem de `devpts` explica por que a solução final mantém um Bash
interativo: o `telnetd -i` recebe o socket do inetd e consegue alocar o PTY. O
`httpd -h /mnt/mmc` adiciona uma terceira rota para baixar logs, via HTTP/80.
HTTP não substitui o FTP para upload nessa configuração; o fluxo de escrita
continua sendo `ftpd -w` em TCP 21.

## 2026-08-09 14:42:00 -03 — Snapshot Wi-Fi/idle

A v1.3.1 resolveu completamente a captura: 66 comandos enviados, 66 linhas
`CIS_READ ADDRESS ... DATA` recebidas. Porém o relatório mostrou:

```text
m_eMode: eSensorModeIdle
Frame rate: 7,495708 fps
0x0100..0x7032: todos os 66 valores iguais a zero
```

O resultado é coerente com o modo Wi-Fi manter o capture framework carregado,
mas o CT3 sem stream ativo. Portanto os zeros são telemetria válida do estado
idle, não uma baseline apropriada para restauração de modo de vídeo.

### Ensaio ativo controlado v1.4

O parser de fábrica oferece `live`, que chama diretamente
`CAquilaCt3Driver::SetupVideoNormal()`, e `stop`, que chama
`DisableStream()`. A v1.4 usa esse par conhecido em vez de escritas inventadas:

```text
anexar strace -> cis live -> info/regr x66 -> cis stop -> info -> desanexar
```

Um watchdog separado envia `cis stop` após 20 segundos, enquanto um trap o
repete em saída normal, interrupção ou término. Esse teste deve revelar o
snapshot factory-live mesmo com a aplicação no modo Wi-Fi.

## 2026-08-09 14:52:00 -03 — Resultado ativo v1.4

O comando de fábrica foi aceito (`live_rc=1`) e o relatório mudou para:

```text
Frame rate calculado: 59,965660 fps
HD count/VD: 1344
clock/HD: 3772
m_uiHdCount: 1343
```

`m_eMode` continuou `eSensorModeIdle` e `m_eFrameRate` apareceu como 0 fps. Isso
é esperado da chamada isolada a `SetupVideoNormal()`: ela programa hardware/TG,
mas não atualiza todo o estado lógico que `SetMode()` manteria.

O strace já estava anexado durante a configuração longa e voltou a deslocar a
decodificação (`write(34, ...) = 983070`, onde 983070 é o msqid). As 66 linhas
foram truncadas em `CIS_READ ADDRES`. A v1.4.1 separa rigorosamente as fases:

```text
cis live -> aguardar -> anexar -> info + 3 regr -> desanexar -> cis stop
```

Somente após validar três valores nesse arranjo a coleta de 66 será repetida.

## 2026-08-09 15:00:00 -03 — V1.4.1 e syscall parcial

Mesmo anexando após `live`, o primeiro registro da v1.4.1 foi:

```text
0, ) = 983070
```

O valor 983070 é o ID conhecido da fila criada com chave `0x8828`, logo essa
linha é o retorno parcial de `msgget()`. Como `msgget` não estava no filtro, a
versão antiga do strace não conheceu a entrada da syscall, deslocou o pareamento
entrada/saída e produziu novamente `write(34, ...) = 983070` após cada `regr`.

A v1.4.2 remove inteiramente `-e trace=...`. Como somente o TID do shell é
rastreado e há três leituras, capturar todas as syscalls é de baixo volume e
elimina a dependência de enumerar syscalls presentes durante a anexação.

## 2026-08-09 10:31 America/Maceio — Limitação do strace isolada no CT3 v1.4.2

- Artefatos: `experiments/logs/CT3_LIVE_READ_SYNC_V1_4_2.LOG` (SHA-256 `834f53e4e41bb9168233389c8c4b414f461f5df32ba659f364f2412037a6963d`) e `CT3_LIVE_READ_SYNC_TRACE_V1_4_2.LOG` (SHA-256 `20e4953026fd0ba6169eedcdaa64417c26e3cb4444365d4c2968a81a1af06e72`).
- Evidência positiva: o queue payload registra literalmente `cap cis regr 0340`, `0342` e `3404`; cada pedido provoca `write(15, "CIS_READ ADDRES", 15)`.
- Evidência negativa qualificada: a chamada seguinte aparece como `write(34, ) = 983070`/`write(35, ) = 983070`, sem string. O retorno impossível para um write de 34/35 bytes e o padrão repetitivo provam dessincronização do tracer, não leitura vazia.
- Próximo método: v1.4.3 usa o qualificador suportado `strace -e write=all` junto do trace completo, buscando o dump bruto do buffer mesmo quando a representação normal da syscall falha.

## 2026-08-09 10:36 America/Maceio — CT3 v1.4.3 e capturador ptrace v1.5

- Log v1.4.3: SHA-256 `de708fa3582257c89ff6aa665c3077f67f77be35fc61e7a84e33be056547d1fb`.
- Trace v1.4.3: SHA-256 `ac0a92c94fe961e48fe8714287e823329857b2faf6aa0b90fb53b2d7b87bde16`.
- O dump independente reproduziu integralmente os buffers de `cis info`, incluindo 59.965660 fps, 1344 HD/VD, 3772 clocks/HD, VD 1667 e HD 12.40 us. Isso valida a captura de memória quando o strace reconhece a syscall.
- Nenhum dump sucede os writes de resposta de 34/35 bytes, porque o strace os pareia com o msqid 983070. A abordagem strace foi esgotada de forma controlada.
- Novo binário `experiments/ct3_ptrace_write_capture_v1_5/arm_write_capture`: ELF ARM32 little-endian, EABI5, soft-float, estático, Linux >=3.2, Build ID `183f1df8bde9d98f194bb9ecfeab4964f343eae1`, SHA-256 `5c538608aca1abd6d5a58aab376a6e39d1cdec03211f593c8920d0935c691d87`.
- Princípio técnico: em cada syscall-stop com `r7=4`, copiar imediatamente até 4096 bytes de `r1`, comprimento `r2`, via `PTRACE_PEEKDATA`. Os argumentos r1/r2 permanecem utilizáveis independentemente de o stop ser entrada ou saída; duplicatas podem ser removidas na análise.

## 2026-08-09 10:40 America/Maceio — Falha controlada v1.5: wait de thread requer __WALL

- `CT3_PTRACE_V1_5.LOG`: SHA-256 `be3c721ddc009de9041dc0ced680701acd748793a1723ef475392da63e61822b`; `capture_rc=5`, `capture_bytes=0`.
- `CT3_PTRACE_WRITES_V1_5.LOG`: vazio, SHA-256 padrão `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
- Interpretação exata pelo fluxo do programa: attach não retornou erro (senão rc=4); o primeiro wait falhou (rc=5). Para ptrace de TID não-filho, Linux requer `waitpid/wait4` com `__WALL`.
- A v1.5.1 aplica essa flag a todos os waits. Nenhuma conclusão sobre os valores dos registradores pode ser tirada da v1.5 vazia.

## 2026-08-09 10:39 America/Maceio — Resultado inconclusivo da primeira execução v1.5.1

- `CT3_PTRACE_V1_5_1.LOG`: SHA-256 `05989733d0a3502c97e16d8f9e517b3416e007ab2e02a2e3cd7bdd399475740a`.
- As três tentativas registram `camera_pid=`/`shell_tid=` vazios e `shell_tid_missing`; logo nenhuma delas testou a correção `__WALL`.
- Ausência do arquivo de writes é esperada pelo early-exit. Não há evidência de falha do capturador v1.5.1 nem leitura de sensor nesta rodada.

## 2026-08-09 10:44 America/Maceio — Incidente de travamento com ptrace v1.5.1

- A execução que travou não está representada nos arquivos locais: resumo continua idêntico ao anterior (306 bytes; SHA-256 `05989733d0a3502c97e16d8f9e517b3416e007ab2e02a2e3cd7bdd399475740a`) e não há `CT3_PTRACE_WRITES_V1_5_1.LOG`.
- Mecanismo provável: handlers instalados por `signal()` podem usar semântica `SA_RESTART`; SIGTERM apenas seta a flag, `wait4` recomeça e o loop não chega ao detach enquanto não houver novo syscall-stop. O shell thread e o wrapper podem permanecer mutuamente bloqueados.
- Classificação: v1.5.1 insegura para repetição até corrigir término/detach. O incidente não demonstra dano persistente nem alteração de registradores; o ensaio somente invocava `cis live`, leituras e `cis stop`.

## 2026-08-09 10:49 America/Maceio — Recuperação e controles de segurança ptrace v1.5.2

- Estado pós-reboot fornecido pela câmera: `TID=310 NAME=shell_di_camera`, `State: S (sleeping)`, `TracerPid: 0`.
- Isso confirma que o travamento anterior não foi persistente e não deixou tracer após reinicialização.
- v1.5.2: ELF Build ID `dcc794ab7f34ecee3598f3f43bbca9b0b7021115`; SHA-256 `dc1e27c03ddcdbada02623691835cc8bcc878f89eb5a1bf401ed27d34f4274c8`.
- Segurança adicionada em camadas: handler sem restart; SIGSTOP/reap para permitir detach; watchdog independente; TERM seguido de KILL; SIGCONT no PID do app; auditoria final de `TracerPid`.

## 2026-08-09 10:55 America/Maceio — v1.5.2 não iniciada por artefato ausente

- Resumo SHA-256 `d05108c19015d7c48b506850739faf44ded314c460763b7b2941e9e6075c04c6`.
- Conteúdo: `camera_pid=267 shell_tid=310` seguido de `capture_tool_missing`.
- Early-exit ocorre antes do comando `cis live`; resultado seguro e inconclusivo quanto ao capturador.

## 2026-08-09 10:58 America/Maceio — Segurança v1.5.2 validada e causa do capture vazio

- Resumo: SHA-256 `f195d25e93147f8d3df16d6b5febefdd0ad03f53fb542547517ec6e14e44b463`.
- Resultado: `capture_rc=0`, `capture_bytes=0`, `tracer_after=TracerPid: 0`, com live/stop aceitos. A rotina segura de TERM, wait interrompível e detach funcionou no hardware.
- Bug de filtragem: `ARM_r1` é `long` assinado de 32 bits; ponteiros como os observados pelo strace (`0xA...`) tornam-se negativos. A condição rejeitava o buffer antes de `PTRACE_PEEKDATA`.
- Correção: converter r1 para `unsigned long` antes do limite mínimo. Nenhuma mudança na sequência CT3.

## 2026-08-09 11:15 America/Maceio — CT3: frame/line length ativos e clock de 304 MHz

- Resumo v1.5.2 final: SHA-256 `51e4d7516512ec0abc04242b4a63a01b07d2c50127dcb94b7bf12d4bef733cd5`.
- Captura de writes: SHA-256 `f55bd8543e258c52c81cbc0e7ea6d756a5a9143d6934a7f7929e2dcb0346ef26`, 10339 bytes.
- Leituras ASCII duplicadas em entrada/saída, com conteúdo idêntico:
  - `CIS_READ ADDRESS : 340, DATA : a80` → frame length `0x0A80 = 2688` linhas.
  - `CIS_READ ADDRESS : 342, DATA : ebc` → line length `0x0EBC = 3772` clocks.
  - `CIS_READ ADDRESS : 3404, DATA : 5` → registrador de modo `0x0005`.
- Checagem independente: `2688 × 3772 × 29.982830 = 303,999,991.03488`, essencialmente 304 MHz. Também `2688 × 12.40 us = 33.3312 ms`, coerente com ~30 fps.
- Distinção crítica: `cis info` desta rodada mostra `m_eMode=eSensorModeLiveview`, `m_eFrameRate=30fps` e 29.982830 fps, embora a tabela `[Now]` ainda liste o perfil TG NTSC de 59.965660 fps. Portanto estes registradores são baseline do liveview 30p, não a temporização do modo direto 60p solicitado dois segundos antes.

## 2026-08-09 15:19:18 -03 — Reconhecimento live somente leitura da NX300

### Sistema

- Kernel `3.5.0+ #24 PREEMPT`, build Samsung/Tizen de 2014-02-03 com GCC 4.4.1.
- SoC identificado por kernel como `Samsung-DRIMeIV-NX300`; ARMv7 Cortex-A9 (`CPU part 0xc09`, rev 8), NEON e VFPv3.
- RAM total 512092 kB; sem swap. App da câmera: VmSize 671536 kB, RSS 28508 kB, 71 threads.
- Boot: root UBIFS em `ubi0!rootdir`, `mem=512M`, console serial ttyAMA0 115200. A linha contém layout MTD, mas nenhum `/proc/mtd` ou device MTD/UBI foi acessado.

### Pipeline e dispositivos

- `di-camera-app-nx300` abre diretamente `/dev/d4_ipcm`, `/dev/d4_pp_core`, `/dev/d4_pp_ssif`, `/dev/d4_pp_3a`, `/dev/d4_mipi`, `/dev/d4_sma`, `/dev/d4_bma`, `/dev/d4_bwm`, `/dev/lens_comm` e `/dev/fb0`.
- Dispositivos de plataforma incluem `s5p-mfc` (codec), `drime4-drm.0`, `drime4_hdmi.0`, `drime4_cec.0`, `drime4-dwc3`, `usb_mass_storage`, `usb_mode`, `d4_jpeg`, `d4_ipcm`, `d4_ipcs`, `d4_mipi`, `d4_pp_*` e `d4_srp`.
- DRM publica conectores `HDMI-A-1` e `LVDS-1`. Classes V4L2 e UDC vazias sugerem que webcam/capture não são expostos atualmente como interfaces genéricas.

### Software relevante

- Encoder: `/usr/lib/libOMX.SEC.AVC.Encoder.so.0.0.0`, `libSEC_OMX_Venc`, `libsecmfcencapi`, plugin `libgstomx.so` e `libgstsavsench264.so`.
- Captura: `/usr/lib/libcapture-fw-slpcam-nx300.so`, `libcapture-fw-plat.so`, `libd4c.so.0.19`, `libgstcamerasrc.so`, `libgstdrime4filesrc.so`.
- Filme: `libmmfcamcorder.so.0.0.0`, `libmmutil_movie.so.0.0.0`, `libmmfhal`, `libmmfcore`, `libmm-type`.
- HDMI/display: `libhdmi-cec.so`, `libmm-displayer.so`, DRM `card0-HDMI-A-1`.
- Rede/streaming: GStreamer RTP/RTSP/TCP/UDP, `libsoup`, `libcurl`, Wi-Fi/DLNA Samsung, `smart-wifi-app-nx300`, `wfd-server`.
- USB: `mtp-responder`, `usb_setting`, `usb_mass_storage`, `usb_mode`, `drime4-dwc3`; `/sys/class/udc` vazio na sessão observada.
- Bluetooth está presente em userspace (`bluetooth-agent`, `hcitool`, `gatttool`, `rfcomm`, bibliotecas BlueZ), mas nenhum controlador Bluetooth foi confirmado no inventário.

## 2026-08-09 15:35 -03 — Infraestrutura de emulação visual

- `emulator/nx300_emulator`: modelo reprodutível do estado observado no hardware, incluindo `0x0340=0x0A80`, `0x0342=0x0EBC`, `0x3404=0x0005` e cálculo de ~304 MHz.
- `emulator/visual/server.py`: servidor localhost sem dependências externas, com proteção contra path traversal e assets NX300 montados logicamente em `/assets/` somente para leitura.
- `emulator/visual/web/config.json`: ponto simples de edição de cor, modo, bitrate, resolução e labels; CSS/JS fornecem preview 800×480 e reload em até 800 ms.
- Os `.edj` continuam binários. Para fidelidade pixel-perfect será necessário decompilar EDC/grupos ou implementar um renderer Edje compatível; o preview atual permite prototipação imediata sem alegar equivalência completa.

## 2026-08-09 15:44 -03 — Controle de composição e política HDMI

- Dispatch exato de `eUI_DISP_CTRL`: `1→UI_Display_Ctrl_Set_Disable`, `2→Enable`, `3→OSD_Only`, `4→Video_Only`, `5→Video_Off`.
- `UI_Set_Hdmi_Connect` chama disable para `eUI_DISPLAY_TYPE=-1`, cria displayer com enum Device 2 e dimensões vindas dos itens UI 1052/1053, depois entra na UI de single playback.
- O binário contém chamadas reais `UI_Operate_Display_Ctrl_Set(7,4)` e `UI_Operate_Display_Ctrl_Set(7,3)` em rotinas de captura, logo planos de vídeo e OSD são controláveis separadamente.
- Hipótese forte: clean liveview requer manter o estado de captura, criar/selecionar o TV displayer e aplicar video-only ao target correto, em vez de executar o restante da transição HDMI para playback.
- Teste dinâmico adiado: qualquer chamada dessas funções muda estado/display e está fora da autorização somente leitura vigente.
## 2026-08-09 16:05 -03 — Controle de planos HDMI/TV

- Confirmado por disassembly: `eUI_DISPLAY_TYPE & 8` controla `CDisplayerFactory::Device=2`, isto é, TV/HDMI. A leitura anterior de tipo `7` como HDMI foi corrigida; `7` não contém o bit TV.
- Candidato clean-HDMI de alto nível: `UI_Operate_Display_Ctrl_Set(8, UI_DISP_CTRL_VIDEO_ONLY=4)`.
- Efeito interno de `Video_Only(8)`: TV window 0 visível; TV window 1 depende de `UI_STATE_ITEM 55` e normalmente é ocultada.
- `CDisplayTV::SetVisible` (`libmm-displayer.so` `0x88c0`) usa ioctl `0x40087438` e payload `{ int window; int visible; }`.
- Limitação ainda aberta: visibilidade não cria a rota do liveview. É preciso identificar como `ChangeTargetDisplay`/mensagem 50 associa buffers da captura ao `CDisplayTV`, evitando o fluxo factory `UI_Set_Hdmi_Connect()` que constrói playback.
## 2026-08-09 21:25:59 -03 — Evidências da reanálise de modos de vídeo

- DWARF `eUI_CAP_MOVIE_SIZE`: valores 0..7 = 1080p60, 1080p30, 1080p15,
  1920x810p24, 720p60, 720p30, VGA30, QVGA30; `MAX=8`.
- `set_movie_size(int)` em `0x000f1138` satura índices >=7 em 7.
- `UI_Get_Movie_Frmae_By_Movie_Size` em `0x001b3f7c` devolve 60/30/15/24/60/30/30;
  PAL converte 60->50 e 30->25.
- `/usr/etc/mmfw_camcorder_dev_video_pri.ini` real: preview inclui 1920x1080 e
  1920x810; FPS aceitos `3,15,24,25,30,50,60,100,120`.
- `/usr/etc/mmfw_camcorder.ini`: `camerasrc`, `num-alloc-buf=7`, zero-copy,
  gravação NV12, `omx_h264enc`, `mp4mux`.
- MFC: `SsbSipMfcApi.h` define `SUPPORT_1080P 1`, output máximo 3 MiB e mmap
  nominal 70 MiB; `mfc_enc.c` aplica locks de clock para >=1920 ou >=1080.
- Runtime PID267 carrega todas as bibliotecas do pipeline e mapeia grandes áreas
  `/dev/d4_sma`; módulos DRIMe4 são built-in, ath6kl/cfg80211 são módulos.
- Enum corrigido: `TV=8`, `HDMI=16`; `ALL=0xffffffff`.
- Ranking e dez experimentos detalhados em `REANALYSIS_2026-08-09.md`.
## 2026-08-09 21:34:32 -03 — `di_camera_sd_override_v1`

- Artefatos: `autoexec.sh`, `README.md`, `MANIFEST.sha256` e
  `payload/di-camera-app-nx300`.
- Origem do payload:
  `TIZEN/project/NX300/image/rootdir/usr/bin/di-camera-app-nx300`.
- `cmp` confirmou igualdade byte-a-byte; tamanho 1.115.832; modo 755;
  SHA-256 `c3932e60f75df886ed5484470be91f2d9ca8f3d6e2c9944cdd0060561fe852a7`;
  BuildID `32e258f2d9921ce491d34477d62c64a51d3ba4f1`.
- Hash do autoexec preparado:
  `c6423ee3e613840acfdc21552ebbf04b1992a2bf745b3f9591753da309095f1a`.
- Ordem confirmada no rootfs: desktop `Exec=/usr/bin/di-camera-app`; esse caminho
  é symlink para `di-camera-app-nx300`; `xinitrc` chama `launchpad_run`, que inicia
  o daemon de launchpad. O hook autoexec não foi encontrado no rootfs/bootloader
  público; logs anteriores apenas o colocam cedo, antes da inicialização Wi-Fi.
- Segurança: dois guards `pidof`, hashes antes do mount, cópia somente para
  `/tmp`, bind após todas as pré-condições e verificação dev/inode posterior.
  Se uma pré-condição falha não há bind; se a pós-validação falha, tenta `umount`.
- Não executado na câmera; nenhuma alteração em NAND, processo ou autoexec atual.

## 2026-08-09 22:11:01 -03 — Evidências dos programas Windows Samsung

### Preservação e catálogo

- 15 arquivos originais; hashes em
  `windows_software_reanalysis_2026-08-09/inventory/originals.sha256`.
- IntelliStudio ISO e `ISO(1)` têm o mesmo SHA-256
  `f711e7d2efa4689023f2be33fb2e4b3c3ed254ff1611f158395ee89eb3d64939`.
- Catálogo final: 1.278 PE extraídos, incluindo 867 do pacote Gear360; nenhum PE
  foi executado.

### NX300 no iLauncher — confirmado

- Tabela interna: NX300 `VID=0x04e8`, `PID=0x1397`, presente desde 2013-04-02;
  NX300M `1402`, NX30 `1403`, NX3000 `1409`, NX1 `140b`.
- O firmware upgrader lê `X:\\SYSTEM\\DEVICE.XML` e os XPath BaseModelName,
  CurrentVersion e ProductionPlace; consulta `downloadUrlList.do`, baixa e copia
  o firmware ao volume. Não foi encontrado flash PTP/DFU direto.
- FirmwareUpgrader de março, maio e novembro de 2014 é idêntico, SHA-256
  `b869ab6e08ace79bd917d3b3fd9bbc6c84e8ce0597ea3c748eaaa63d15189579`.

### Samsung Remote Studio — confirmado para NX1, não confirmado para NX300

- Manual exige NX1 firmware 1.31+. Não há dispatch NX300 observado; conversores
  explícitos são NX1 e NX2000.
- `SdiCore.dll` SHA-256 `b6c9503deddf9ea087a30adb918c1465b7ad2d6c06ac88c130a9d2cc51a0c344`,
  209 exports; `SdiMgr.dll` SHA-256
  `bddd407d0a6fe4a3edf2c625b00b213bb1daad87907cb744216f02ea35b46284`,
  276 exports.
- Transporte Windows 7 WPD/IPortableDevice; caminho XP PTP host; SdiMgr importa
  WS2_32/IPHLPAPI/SetupAPI e expõe PTP-IP.
- Liveview: `SdiCore!LiveviewExec` RVA `0x4760`, `LiveviewInfo` `0x4e80`,
  `SdiSetLiveView` `0xe140`; `SdiMgr!PTP_SendLiveview` `0xbdd0/0xbe40` e
  `PTP_SetLiveView` `0xc600`. Conversão YUV420/YUV422; NX1 também JPEG/histograma.
- OpCodes recuperados: `9004` require capture, `9005` capture, `9006` liveview
  info, `9007` liveview data, `9008` focus position, `900a` reset, `900b`
  format, `900d/e` tick, `9010` record status, `9012` enlarge, `9013` movie
  transfer, `9014/15` pause/resume, `9017` liveview, `9018` image transfer,
  `901a` device property, `9022` interval stop, `9023` wakeup, `9025` capture
  count, `9026` touch AF, `9028` tracking stop, `90fe` FW update.
- Layout/direção dos payloads ainda são hipótese até reconstrução completa ou
  captura USB. A lista `srs_ptp_names.txt` contém 137 DPC names.

### Protocolos e correções

- PC Auto Backup NX300: UPnP/DLNA MSCP; descrição em
  `/mnt/mmc/dlna_web_root/SAMSUNGAutoBackupDESC.ini`; X_BACKUP_START/DONE,
  Browse/CreateObject/ImportURI, HTTP POST e GetTransferProgress.
- IntelliStudio 3.0.52.1 é pré-NX300 e não mostrou tether/liveview.
- Gear360 instala `VR360.sys` para USB bulk `04e8:a50c`; strings NX em
  CLPhotoRawDecoder são suporte RAW, não controle remoto.
- Errata: SRS não pode ser chamado de “outra ponta do RVF NX300” com a evidência
  atual. SRS usa PTP/WPD/PTP-IP e é NX1; RVF NX300 permanece uma trilha distinta.
- Errata: modos 4K/1080p120 do manual SRS são NX1; presets 4K do SMC são ffmpeg
  no PC. Nenhum deles prova capacidade 4K/120p no DRIMe IV/NX300.
- Relatório e evidências reproduzíveis em
  `WINDOWS_SOFTWARE_REANALYSIS_2026-08-09.md` e
  `windows_software_reanalysis_2026-08-09/`.

## 2026-08-09 23:45:26 -03 — `start_script`/autoexec reconstruído

### Correspondência ELF/DWARF

- `rootdir_3-5/usr/bin/di-camera-app-nx300` e
  `imagedev/usr/bin/di-camera-app-nx300` são idênticos, SHA-256
  `f8036f78161aa7335df0fb1ee9a50fecd6190faadfcd0768a443e90eea19bfcf`,
  Build ID `417516b9d8d751ed807b059e15ce35991c3a01c2`.
- `di-camera-app-nx300-full` tem a mesma Build ID e fornece symtab/DWARF
  diretamente aplicáveis aos endereços de `.text`.
- `0x1c27b0 -> start_script@plt` pertence inequivocamente à função local
  `UI_Event_Card_Mounted()` (`0x1c1de0..0x1c27c4`), linha fonte 942. O rótulo
  anterior baseado em `UI_Stop_Charger_Timer` era apenas o símbolo exportado
  precedente e fica corrigido por esta errata.

### Implementação de `libmisc.so`

- `libmisc.so` SHA-256
  `188d1c695b06703d2cd52be3d81425dd8978a6934fc2ad8bb94d1d212cee9b59`,
  Build ID `851181f48c36e8f66453868d366fa2f69c1b43c7`.
- `start_script` `0x1398` monta `/mnt/mmc/autoexec.sh`, testa `access(path,4)`,
  protege o slot de thread com mutex e cria worker detached em `0x12c4`.
- Worker: `prctl(PR_SET_NAME,"Script Thread")`, cancelamento assíncrono,
  `system("chmod u+rx /mnt/mmc/autoexec.sh")`, seguido por loop infinito de
  `system(path)`, `misc_sleep(1000)` e `pthread_testcancel`.
- Descoberta crítica: o autoexec é recorrente, não one-shot. Scripts futuros
  precisam de marker/lock e operações idempotentes.
- `stop_script` `0x147c` chama `pthread_cancel`; seu único caller direto no app
  é `UI_Close_FileManager()` em `0x1c1410`. Esta função é chamada por
  `UI_Manage_Event_On_Off` durante teardown do gerenciador de storage.

### Ordem e estratégia

- `UI_Event_Card_Manager(2)` chama `UI_Event_Card_Mounted`; o evento chega pela
  message queue ou por callback idle Ecore depois da consulta/revalidação do
  storage. Logo o app necessariamente precede o autoexec.
- O skip `PID_FIRST_GUARD=267` da v2.1 é consequência causal, não janela de
  corrida: um autoexec chamado por esse app nunca pode bindar antes de seu
  primeiro exec mantendo o guard.
- Build `rootdir` SHA `c3932e...`, Build ID `32e258...`, não tem dependência de
  `libmisc` nem imports `start_script/stop_script`. Misturar seu payload com a
  build 417 deve ser bloqueado; a build da câmera continua desconhecida sem
  leitura adicional.
- Não foi encontrado hook SD anterior em rcS/startx/xinitrc/launchpad. Candidato
  de maior viabilidade sem NAND: bind staged enquanto o app original continua
  mapeado, seguido futuramente de relaunch AUL gracioso para um segundo exec.
- Artefatos completos: `experiments/autoexec_origin_reanalysis/`.
- Análise exclusivamente local; câmera e arquivos originais não foram alterados.

## 2026-08-17 — Evidência Build311: state machine HDMI 3D/liveview

- Binário: `live_camera_2026-08-17/di-camera-app-nx300.live`; SHA-256 `68e3f8a62be1092a55f33b881188503f96a6649210f259b60edb97719e75d6d7`; Build ID `3119561d1ec93b05fab09aaed9df83a5936af3b2`.
- `UI_Get_Value` Build311=`0x1842c8`; `UI_Set_Value`=`0x1843e4`; `UI_Hdmi_3D_Liveview`=`0x150828`; `UI_Set_X_Crtc_Config_Liveview`=`0x151f28`; `UI_Set_X_Crtc_Config`=`0x15234c`.
- Xrefs verdadeiros item946: `0x158de4`, `0x158e18`. Não existe setter direto. Semântica DWARF correlacionada: `eUI_COMMON_INFO_3D_HDMI_OUTPUT`, menu persistente `eDB_COMMON_MENU_3D_HDMI_OUTPUT`; 0=SIDE_BY_SIDE, 1=FRAME_PACKING.
- Writers item631: `0x158e0c` escreve 3, `0x158e40` escreve 1, `0x158e50` escreve 0. Semântica: `eUI_PB_INFO_HDMI_3D_TYPE` (OFF=0, SBS=1, TOP_BOTTOM=2, FRAME_PACKING=3). Nenhum writer direto de 2 foi encontrado.
- O writer está no `__xrr_output_select` Build311 `0x157c4c..0x158ea8` (nome por fingerprint exato contra DWARF Build417). Variáveis correlacionadas incluem `tv_possible_size_3d`, `tv_possible_size_3d_sbs`, `tv_possible_size_3d_sbs_pal`, `tv_possible_size_3d_pal` e `tv_frame_packing_index`. A origem prática da capability é a enumeração de modos XRandR/EDID, não um booleano CEC.
- Callers oficiais de entrada `(0)`: `0x1776cc` HDMI Single Half Shutter, `0x177834` HDMI Single Playback, `0x17a334` Folder Half Shutter, `0x17a474` Folder Playback. Todos dependem de 631!=0; Single chama antes `UI_HDMI_Single_Destruct` e `ASLPBDisplay_LowPassFilterCancel`.
- Callers de restauração `(1)`: `0x151698`, `0x15b164`, `0x15b19c`, `0x17dc40`, `0x1e0e50` em disconnect/key/lens/mode-change.
- Entrada oficial: capability ioctl guard; `CESDEMO=1`; display disable; state55=1; key mask; playback teardown; `sysmmap_change_opmode("mov-hdmi")`; CRTC liveview; camera ioctl; mode 28; `UI_Set_HDMI_3D_Type(3)`; liveview start; estado UI 17; MF permitido; display `VIDEO_ONLY`. Saída restaura CRTC/playback e zera estado/tipo 3D.
- `UI_Set_X_Crtc_Config` trata 631==1 especialmente porque seleciona um dos mode IDs SBS guardados (`0x318570/0x318578`); demais tipos usam `0x31856c`.
- O uso de `CESDEMO=1` também no caminho oficial mostra que essa variável isolada não explica o crash de `hdmidemo.adj`. A diferença crítica é a transição completa/guardada da UI, sem stop/set-attributes/start manual do camcorder.
- Relatório: `hdmi_liveview_codex_report.md`. CAMERA MUTATIONS: NONE.

## 2026-08-18 — Checkpoint PR #1: layout local do seletor XRandR

- A correlação formal dos parâmetros mostrou offset de quatro bytes entre `DW_OP_fbreg` Build417 e operandos `[fp,#...]` Build311: `fbreg -932/-936/-940` coincide com `[fp-928/-932/-936]`.
- Aplicando a mesma correção aos locais de `__xrr_output_select`: `[fp-28]=tv_possible_size_3d`, `[fp-32]=tv_possible_size_3d_sbs`, `[fp-36]=tv_possible_size_3d_sbs_pal`, `[fp-40]=tv_possible_size_3d_pal`; inicializações em `0x157ccc/0x157cd4/0x157cdc/0x157ce4`, sets em `0x1581b4/0x157fdc/0x1580e4/0x158208`, testes finais em `0x158d58/0x158d70/0x158d7c/0x158d64`.
- `select_fakemode` corresponde a `[fp-24]`, não a `[fp-28]`; portanto o gate final de 631 é composto exclusivamente pelos quatro candidatos 3D.
- Classificação revisada: XRandR + candidatos 3D PROVEN; origem em EDID STRONG INFERENCE; mapeamento exato de HDMI VSDB para mode name/flag UNKNOWN; participação de CEC no writer path NOT OBSERVED.
- Nenhuma câmera acessada e nenhuma mutação realizada.

## 2026-08-18 — HDMI VSDB -> XRandR e audit do transporte frame-packing

### Producer no kernel/BSP

- `TIZEN/project/NX300/packages/linux-3.5/drivers/gpu/drm/drm_edid.c`: `cea_hdmi_3d_present()` interpreta o HDMI VSDB e reconhece frame packing, top/bottom e SBS-half; `cea_hdmi_patch_mandatory_3d_modes()` anota 1080p30 como frame packing e 1080i50/60 como SBS-half.
- `include/drm/drm_mode.h`: `0x10` é `DRM_MODE_FLAG_INTERLACE`; as flags 3D ocupam bits 14–16. Corrige a hipótese de que o teste `flags & 0x10` do app fosse diretamente uma flag 3D.
- Cadeia de evidência: VSDB -> parser DRM -> modos obrigatórios anotados -> XRandR -> `__xrr_output_select` -> globals/item631. A conversão exata do X server para nomes `1920x1080[f]` ainda é inferência forte.

### Ledger dos globals Build311

- `0x31856c`: zerado `0x157750`; recebe candidata 1080p30 progressiva em `0x1581e4`; se não houver candidata 30p, recebe modo normal fallback em `0x158c00`; lido pelo CRTC liveview em `0x151f78`.
- `0x318570`: recebe 1080i60 SBS em `0x15800c`; usado pelo ramo 631==1 em `0x1523e0/0x15242c`.
- `0x318578`: recebe 1080i50 SBS em `0x158114`; usado no ramo 631==1 em `0x15243c`.
- `0x318574`: recebe segunda variante 30p em `0x158238`; consumidor direto não localizado.

### Tipo 3D e mismatch SBS/frame packing

- `UI_Set_HDMI_3D_Type(int)` Build311 `0x1ede68` implementa switch: 0->estado1, 1->estado2, 2->estado3, 3->estado4, default->estado1. A chamada oficial `0x1509a8/0x1509ac` usa literal 3, provando seleção deliberada de frame packing.
- `UI_Hdmi_3D_Liveview(0)` não usa o valor exato de 631: escolhe sempre `0x31856c` e tipo público 3. O ramo SBS de 631 só é respeitado no CRTC normal/playback.
- Caso-limite PROVEN no controle de fluxo: somente candidatos SBS podem produzir 631!=0 sem candidata 30p; nesse caso `0x31856c` pode ser modo normal fallback enquanto o estado interno é frame packing. Se EDID HDMI 1.4 conforme sempre evita isso é ainda UNKNOWN.

### Preferência e ioctls

- Item946: enum 0=SBS, 1=FRAME_PACKING, 2=MAX. Campo persistido `e_3d_hdmi_output` offset `0x47c`; default em `libprefman.so` é zero. Menu normal aparenta expor apenas 0/1. Nenhum clamp para 2 foi localizado; com candidatas, 631 pode ficar stale.
- DWARF `MMCameraUserDataParam`: 43=`MM_CAMERA_USERDATA_IZOOM`; 66=`MM_CAMERA_USERDATA_3DMOVIEFRAMERATE`. Build311 consulta 43 em `0x150894` e seta 66 em `0x150978`.
- Implicação de segurança: não autorizar teste baseado apenas em 631!=0. Primeiro provar, por inventário read-only, a presença da candidata 1080p30 frame-packing efetivamente usada.
- CAMERA MUTATIONS: NONE.

## 2026-08-18 — Errata: tabela 3D Samsung e classificação real de `0x31856c`

### Comparação exata

- NX300 `drm_edid.c` SHA-256 `f6a9bafd49fa52a3da5c90e711e74a8351f1d3040274dabf1a8f92c299af9940`, linhas 1569–1580: 1080p30 FP e 1080i50/60 SBS.
- Linux oficial v3.5: nenhuma tabela stereo mandatory. Linux oficial v3.13 SHA-256 `55b43f2b034c0ae848d03457bfbacad89efd187270804c95af3164850a7aa5b5`, linhas 2595–2606: 1080p24 FP/TAB, 1080i50/60 SBS e 720p50/60 FP/TAB.
- PROVEN: Samsung mudou 24->30 e removeu outras entradas oficiais; não se deve atribuir 30 Hz ao padrão HDMI 1.4a.
- O patcher Samsung percorre apenas modos já probed, logo anota mas não cria 1080p30. O bitmask do VSDB é reduzido a booleano no caller e não restringe quais formatos da tabela serão aplicados.

### Build311 e transporte de flags

- Refresh: loads `dotClock/hTotal/vTotal` em `0x157e24/0x157e58/0x157e8c`; divisão/arredondamento `0x157e98..0x157eac`; dobra quando `flags&0x10` em `0x157edc..0x157ef4`.
- Nomes aceitos: `1920x1080` e `1920x1080f`, `0x157f20..0x157f84`. Refresh==30 grava mode ID em `0x31856c` em `0x1581e4` sem testar qualquer flag 3D.
- O mesmo modo da primeira iteração 30 Hz também grava `0x318574` em `0x158238`; a interpretação anterior como segunda variante nominal fica corrigida.
- D4DRM SHA `8a23226f...b4fa`: conversores `0x13554/0x13678` copiam integralmente flags DRM para `DisplayModeRec.Flags`. Xorg SHA `a2525423...6c31`: `0x89d00` copia flags para RR e chama `RRModeGet` em `0x89d64`.
- `XRRModeInfo/RandR` usa flags 32-bit. Na rotina do app só há testes `&0x10`; bits 14/15/16 não são testados. Portanto o ABI não os descartou: o app escolheu ignorá-los.
- `1920x1080f` não significa frame packing: o próprio BSP cria modos comuns forced/fake com esse nome em `drm_add_modes_dvi_required()`.

### Cadência da câmera

- `libcapture-fw-slpcam-nx300.so` SHA `48f4f636...07ac`: `convertUserData_3DMOVIEFRAMERATE` `0x1eca8c` e `Set3DFramerate` `0x1e4f2c`; strings enumeram FPS15/FPS30.
- Não há evidência estática de conversão 24->30. O comando Build311 66 passa dados/length nulos; seleção/default exatos continuam UNKNOWN.
- Consequência: sink HDMI 1.4 conforme pode não ter 1080p30, e 1080p30 comum pode satisfazer o app sem capacidade FP. Gate nativo continua bloqueado. CAMERA MUTATIONS: NONE.

## 2026-08-18 — Dispatch do comando 66 e precondição HDMI observacional

### Comando 66 (PROVEN)

- `libcapture-fw-slpcam-nx300.so` SHA `48f4f636...07ac`: mapper `0x1f51f8`, entrada 66 em `0x1f586c`, comando interno `0x01070004`.
- Dispatcher `0x1f3b3c..0x1f3ba4`: comando 66 cria inteiro local 1 e chama `OperateCapture(0x01070004,&value,0)`; comando 61 usa valor 0.
- `OperateCapture` `0x1e6ca4` resolve esse comando como `CCapCmdIf::ChangeMode`; `ChangeMode` `0x1e3218` seleciona frontend virtual `+4` para 0 ou `+8` para 1.
- Errata: o payload nulo não deixa default de cadência desconhecido. Comando 66 significa `ChangeMode(1)` e é separado de `Set3DFramerate`.

### Gate de três camadas (STRONG EVIDENCE)

- EDID: checksum válido, CTA/HDMI VSDB, VIC34 presente e associação explícita de estrutura FRAME_PACKING à posição SVD de VIC34.
- DRM: modo progressivo 1920x1080@30 com `DRM_MODE_FLAG_3D_FRAME_PACKING=0x10000`.
- RandR/Build311: preservar ordem, flags e timings; o primeiro candidato aceito por nome/refresh e gravado em `0x31856c` deve ser o modo progressivo marcado. Duplicata comum anterior reprova o gate.
- As três juntas são suficientes apenas para admitir ensaio físico controlado. Cada uma isolada, 631, `1920x1080f` e HDMI 1.4 são insuficientes.
- CAMERA MUTATIONS: NONE.
