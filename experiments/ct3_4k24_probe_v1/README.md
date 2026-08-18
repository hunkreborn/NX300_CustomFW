# CT3 4K24 probe v1

Sonda temporária e somente leitura para confirmar o console `st cap cis` e
coletar o estado do sensor CT3 na NX300. Esta versão não usa `regw`, não troca
modo, não para o stream e não modifica o firmware interno.

## Arquivos para o cartão

Copie para a raiz do SD:

```text
autoexec.sh
ct3_probe.sh
```

O mecanismo de autoexec já precisa estar habilitado na câmera. O cartão é
procurado em `/mnt/mmc` e `/sdcard`.

## Resultado esperado

Após iniciar a câmera e aguardar aproximadamente 20 segundos, desligue-a
normalmente e procure no cartão:

```text
CT3_PROBE_V1.LOG
ct3_probe_boot.log
```

Envie ambos os arquivos para análise. Se `CT3_PROBE_V1.LOG` terminar em
`CT3 4K24 PROBE V1 END`, a execução foi concluída.

## Segurança

- A sonda apenas executa `cis info` e `cis regr`.
- Nenhum registrador é escrito.
- Nenhum arquivo do rootfs é substituído.
- Remover os dois scripts do cartão desativa completamente o teste.
- Não use ainda `cis regw`, `cis stop`, `clockoff`, `hwrst` ou comandos de modo.

## Identidade da biblioteca analisada

```text
libcapture-fw-slpcam-nx300.so
Build ID: 94cefe600aec538e370ab678e11b6db209987788
```

Os comandos e registradores desta sonda foram extraídos dessa versão. Se a
câmera usar outra biblioteca, o log será usado primeiro para verificar a
compatibilidade antes de qualquer ensaio ativo.
