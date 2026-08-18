# NX300 temporary network console v1

Copie `autoexec.sh` para a raiz do SD e reinicie a câmera com o Wi-Fi conectado.
O script inicia dois consoles Telnet root sem senha:

```text
TCP 23: Telnet
TCP 22: Telnet (não é SSH)
```

Teste no computador:

```bash
nc -vz 192.168.68.100 22 23
telnet 192.168.68.100 23
```

Se o cliente `telnet` não estiver instalado, a conexão também pode ser testada
com `nc 192.168.68.100 23`, embora a negociação de terminal possa aparecer como
caracteres extras.

Dentro do console, confirme:

```sh
id
uname -a
netstat -lntp
```

## Segurança e remoção

Qualquer dispositivo na mesma rede poderá obter shell root sem autenticação.
Use apenas numa rede local isolada, sem encaminhamento de portas no roteador.

Para remover: apague `autoexec.sh` do cartão e reinicie a câmera. Os daemons não
são instalados no rootfs e desaparecem no reboot.

O arquivo `NX300_NETWORK_CONSOLE.LOG` no cartão registra IPs, listeners e
retornos de inicialização.
