================================================================================
 GUIA PRÁTICO — LIBERAÇÃO DE RELATÓRIOS LEGADOS NO PROTHEUS (AUTOMAÇÃO 2.0)
================================================================================

O QUE ESTA AUTOMAÇÃO FAZ:
-------------------------
1. Libera os 339 relatórios clássicos do Protheus (Financeiro, Compras/Estoque/
   Faturamento, Contabilidade, Ativo Fixo, PCO, Licitações e Contratos) que
   foram migrados/bloqueados pelo Smart View.

2. Atualiza automaticamente as tabelas de menu no banco de dados
   (MPMENU_FUNCTION e MPMENU_ITEM), respeitando rigorosamente a declaração real
   de cada fonte legado disponibilizado pela TOTVS (*_CUSTOM.PRW / *_CUSTOM.PRX):

   - 333 relatórios declarados como "Function U_<RELATORIO>C()" (ex.:
     matr180_CUSTOM.prx -> Function U_MATR180C()) -> configura I_TYPE = '1'
     (Função Protheus), eliminando o erro "Help: NO_IX".

   - 2 relatórios declarados como "User Function <RELATORIO>C()"
     (FINR150_CUSTOM.PRX e FINR865_CUSTOM.PRW) -> configura I_TYPE = '3'
     (User Function).

3. Diagnostica e repara automaticamente os erros:
     - "Help: NO_IX - Função de usuário não está compilada no repositório"
     - "Help: NOFUNCW - Opção não disponível no Protheus (Called By __EXECUTE)"

4. Salva o log completo da execução e do diagnóstico na pasta \logs deste
   pacote e informa na tela o caminho exato onde o arquivo foi gravado.

================================================================================
 ESTRUTURA DESTA PASTA
================================================================================
  - Pacote Full\tttm120-full.ptm -> Pacote 1 (Patch oficial com os relatórios)
  - UPDMENUS.PRW                 -> Pacote 2 (Fonte da Automação 2.0 e Diagnóstico)
  - logs\                        -> Pasta onde os logs de execução são salvos
  - readme.txt                   -> Este manual passo a passo

================================================================================
 PASSO A PASSO DE EXECUÇÃO (DO ZERO ATÉ FUNCIONAR NO PROTHEUS)
================================================================================

PASSO 1 — APLICAR O PACOTE DE RELATÓRIOS NO RPO
-----------------------------------------------
  1. No VS Code (TOTVS Developer Studio), conecte no servidor Protheus.
  2. Aplique o patch "Pacote Full\tttm120-full.ptm" no RPO do ambiente.


PASSO 2 — COMPILAR A AUTOMAÇÃO DE MENUS (UPDMENUS.PRW)
------------------------------------------------------
  1. No VS Code (TOTVS Developer Studio), selecione o arquivo "UPDMENUS.PRW"
     desta pasta.
  2. Compile o fonte "UPDMENUS.PRW" no RPO do ambiente Protheus.


PASSO 3 — EXECUTAR A ATUALIZAÇÃO AUTOMÁTICA DOS MENUS NO PROTHEUS
-----------------------------------------------------------------
  1. Abra o SmartClient / WebApp do Protheus.
  2. Na tela inicial de programa (ou via execução de fórmula/menu), execute:
       U_UPDMENUS
  3. O sistema perguntará se deseja rodar primeiro o Diagnóstico:
     - Clique em [NÃO] para ir direto à Atualização / Reparo Automático dos
       Menus, ou
     - Clique em [SIM] para ver antes o Diagnóstico e em seguida confirmar o
       reparo automático.
  4. Confirme clicando em [SIM] na tela "Confirmar Atualização 2.0".
  5. O que a rotina fará sozinha no banco de dados:
     - Para cada relatório que EXISTIR compilado no RPO:
       * Atualiza (ou confirma) o nome da função em MPMENU_FUNCTION
         (ex.: MATR180 -> U_MATR180C).
       * Ajusta o tipo em MPMENU_ITEM exatamente conforme o fonte legado TOTVS:
         -> I_TYPE = '1' (Function Protheus) para os relatórios declarados como
            "Function U_<RELATORIO>C()" (ex.: MATR180, FINR490, CTBR*, ATFR*...).
         -> I_TYPE = '3' (User Function) para os relatórios declarados como
            "User Function <RELATORIO>C()" (FINR150 e FINR865).
     - Para cada relatório que NÃO existir no RPO:
       * Mantém ou restaura o nome original (ex.: FINR471 com I_TYPE = '1'),
         impedindo que o menu apresente o erro "Help: NOFUNCW".


PASSO 4 — VALIDAR O DIAGNÓSTICO E CONFERIR O LOG
------------------------------------------------
  1. Sempre que quiser auditar o ambiente para garantir que NENHUM relatório
     continua com os erros "Help: NO_IX" ou "Help: NOFUNCW", execute no
     SmartClient:
       U_DIAGMENUS
     (ou execute U_UPDMENUS e clique em [SIM] na primeira pergunta).
  2. A rotina mostrará na tela o resumo completo:
     - Quantos relatórios estão [OK] Reparados e Ativos;
     - Se existe algum relatório com [ERRO] Help: NO_IX / NOFUNCW;
     - Se existe algum relatório compilado no RPO que ainda não foi ativado.
  3. Onde fica o arquivo de Log:
     - O arquivo .txt detalhado é salvo automaticamente dentro da subpasta:
         ...\Relatorios_legados-main\logs\
       (ou na pasta temporária da estação caso a pasta não esteja em Downloads).
     - Ao final da execução, a tela informa o CAMINHO EXATO onde o log foi salvo
       e pergunta: "Deseja abrir o arquivo de log agora?" — basta clicar em
       [SIM] para visualizá-lo imediatamente no Bloco de Notas.
================================================================================
