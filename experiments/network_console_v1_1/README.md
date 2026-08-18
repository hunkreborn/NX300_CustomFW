# NX300 temporary network console v1.1

Copie estes dois arquivos para a raiz do SD:

```text
autoexec.sh
nx300_shell.sh
```

A v1 abriu corretamente TCP 22/23, mas a conexão fechou quando `telnetd`
executou `/bin/sh` com argumentos destinados a um programa de login. Esta
versão usa um wrapper que ignora os argumentos e inicia `/bin/sh -i`.

Depois de reiniciar e conectar o Wi-Fi:

```bash
telnet 192.168.68.100 23
```

O cartão receberá `NX300_NETWORK_CONSOLE_V1_1.LOG` e, quando houver tentativa
de login, `NX300_SHELL_SESSIONS.LOG`.

As portas 22 e 23 continuam oferecendo Telnet root sem senha. Remova os dois
scripts e reinicie a câmera ao terminar.
