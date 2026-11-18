# README — Automação 2.0 de Relatórios Legados Protheus

## 1. Visão geral

A **Automação 2.0 de Relatórios Legados** tem como objetivo restaurar e automatizar a disponibilização dos relatórios clássicos do TOTVS Protheus que foram migrados ou bloqueados após a implementação do Smart View.

A solução automatiza a atualização das tabelas de menu do Protheus, realiza diagnósticos de inconsistências, corrige configurações de funções e gera logs detalhados para auditoria.

## 2. Funcionalidades

A automação contempla:

- Liberação de **339 relatórios clássicos** do Protheus.
- Atualização automática das tabelas `MPMENU_FUNCTION` e `MPMENU_ITEM`.
- Identificação do tipo correto de função conforme a declaração existente nos fontes disponibilizados pela TOTVS.
- Diagnóstico de funções não compiladas ou opções indisponíveis.
- Reparo automático das inconsistências identificadas.
- Geração de logs detalhados das execuções e diagnósticos.

### Erros tratados

| Erro | Descrição |
|---|---|
| `Help: NO_IX` | Função de usuário não está compilada no repositório. |
| `Help: NOFUNCW` | Opção não disponível no Protheus (`Called By __EXECUTE`). |

## 3. Compatibilidade das funções

A automação respeita a declaração real de cada fonte legado (`*_CUSTOM.PRW` / `*_CUSTOM.PRX`).

| Declaração no fonte | Quantidade | Configuração |
|---|---:|---|
| `Function U_<RELATORIO>C()` | 333 | `I_TYPE = '1'` |
| `User Function <RELATORIO>C()` | 2 | `I_TYPE = '3'` |

**Exemplos:**

- `matr180_CUSTOM.prx` → `Function U_MATR180C()`
- `FINR150_CUSTOM.PRX` → `User Function FINR150C()`
- `FINR865_CUSTOM.PRW` → `User Function FINR865C()`

Essa validação evita configurações incorretas nos menus e reduz a ocorrência de erros durante a execução dos relatórios.

## 4. Estrutura do projeto

```text
Relatorios_legados-main/
│
├── Pacote Full/
│   └── tttm120-full.ptm
│
├── UPDMENUS.PRW
│
├── logs/
│   └── Arquivos de log das execuções
│
└── README.md
```

### Descrição dos arquivos

| Arquivo / Diretório | Finalidade |
|---|---|
| `tttm120-full.ptm` | Pacote oficial contendo os relatórios e fontes necessários. |
| `UPDMENUS.PRW` | Fonte responsável pela atualização automática dos menus e diagnóstico. |
| `logs/` | Diretório destinado ao armazenamento dos logs. |
| `README.md` | Documentação de instalação e utilização. |

## 5. Instalação e configuração

A implantação deve seguir a ordem abaixo.

### Etapa 1 — Aplicar o pacote de relatórios no RPO

1. Abra o VS Code com o TOTVS Developer Studio.
2. Conecte-se ao servidor Protheus.
3. Localize o pacote:

   `Pacote Full\tttm120-full.ptm`

4. Aplique o pacote no RPO do ambiente desejado.

### Etapa 2 — Compilar a automação

1. Localize o arquivo `UPDMENUS.PRW`.
2. Abra o fonte no VS Code / TOTVS Developer Studio.
3. Selecione o ambiente Protheus correspondente.
4. Compile o fonte no RPO.

### Etapa 3 — Executar a atualização automática

1. Acesse o SmartClient ou WebApp do Protheus.
2. Execute a rotina:

   ```advpl
   U_UPDMENUS
   ```

3. O sistema perguntará se deseja executar primeiro o diagnóstico.

   - **SIM:** executa o diagnóstico antes de iniciar o reparo.
   - **NÃO:** direciona diretamente para a atualização e o reparo automático.

4. Na tela `Confirmar Atualização 2.0`, confirme a operação selecionando **SIM**.

### O que acontece durante a execução?

A rotina realiza automaticamente:

- Identificação dos relatórios compilados no RPO.
- Atualização ou confirmação do nome das funções na tabela `MPMENU_FUNCTION`.
- Ajuste do tipo de função na tabela `MPMENU_ITEM`.
- Aplicação do tipo correto conforme a declaração dos fontes legados da TOTVS.
- Tratamento dos relatórios que não estão compilados no RPO, mantendo ou restaurando o nome original da função para evitar configurações que provoquem `Help: NOFUNCW`.

## 6. Diagnóstico e validação

Após a execução, recomenda-se realizar uma validação do ambiente.

Para isso, execute:

```advpl
U_DIAGMENUS
```

Alternativamente, execute `U_UPDMENUS` e selecione **SIM** na primeira pergunta.

### Informações apresentadas pelo diagnóstico

A rotina apresenta um resumo do estado dos relatórios:

- **OK:** relatórios reparados e ativos.
- **ERRO:** relatórios que ainda apresentam `Help: NO_IX` ou `Help: NOFUNCW`.
- **PENDENTE:** relatórios compilados no RPO que ainda não foram ativados no menu.

Essa etapa permite verificar se existem inconsistências remanescentes após a atualização.

## 7. Logs de execução

Todas as execuções e diagnósticos geram arquivos de log em formato `.txt`.

**Local padrão:**

```text
Relatorios_legados-main/
└── logs/
```

Caso a pasta do projeto não esteja localizada em Downloads, o arquivo poderá ser salvo na pasta temporária da estação.

Ao finalizar a execução:

1. O sistema informa o caminho completo do arquivo.
2. É apresentada a pergunta: `Deseja abrir o arquivo de log agora?`
3. Selecione **SIM** para abrir o relatório diretamente no Bloco de Notas.

Os logs permitem acompanhar as operações realizadas, identificar falhas e manter um histórico para análise técnica.

## 8. Fluxo operacional

```text
Aplicar pacote tttm120-full.ptm
              |
              v
Compilar UPDMENUS.PRW
              |
              v
Executar U_UPDMENUS
              |
              v
    Executar diagnóstico?
         /       \
       SIM       NÃO
        |          |
        v          |
 Validar erros     |
        |          |
        +----+-----+
             |
             v
   Confirmar atualização
             |
             v
 Atualizar tabelas de menu
             |
             v
      Gerar logs
             |
             v
 Executar U_DIAGMENUS
             |
             v
     Validar resultado
```

## 9. Recomendações técnicas

- Realize backup do ambiente antes de aplicar pacotes ou executar atualizações.
- Confirme se o pacote foi aplicado corretamente no RPO.
- Verifique se o fonte `UPDMENUS.PRW` foi compilado sem erros.
- Execute a rotina em um ambiente de homologação antes de disponibilizá-la em produção.
- Confira os logs após cada execução.
- Utilize `U_DIAGMENUS` para validar o estado dos relatórios sempre que necessário.

## 10. Resultado esperado

Ao concluir o procedimento, espera-se:

- Os relatórios legados disponíveis conforme sua compilação no RPO.
- As funções corretamente configuradas nas tabelas de menu.
- Redução dos erros `Help: NO_IX` e `Help: NOFUNCW`.
- Menor necessidade de intervenção manual nas configurações dos 339 relatórios.
- Histórico técnico das execuções por meio dos arquivos de log.

---

**Projeto:** Automação 2.0 — Relatórios Legados Protheus  
**Tecnologia:** TOTVS Protheus / ADVPL / SQL Server  
**Finalidade:** Automatização, diagnóstico e correção de menus de relatórios legados.
