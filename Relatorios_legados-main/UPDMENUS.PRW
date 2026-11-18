#include "totvs.ch"

/*/{Protheus.doc} UPDMENUS
Automação 2.0 para Gestão e Diagnóstico de Relatórios Legados no Protheus.
- Respeita rigorosamente a declaração real de cada fonte legado disponibilizado pela TOTVS:
  * 333 relatórios declarados como "Function U_<RELATORIO>C()" (ex.: matr180_CUSTOM.prx -> Function U_MATR180C())
    são Funções Protheus e exigem obrigatoriamente I_TYPE = '1' (evitando o erro Help: NO_IX).
  * 2 relatórios declarados como "User Function <RELATORIO>C()" (FINR150_CUSTOM.PRX e FINR865_CUSTOM.PRW)
    são User Functions e exigem I_TYPE = '3'.
- Verifica no RPO via GetFuncArray() se a função legada está compilada antes de alterar o menu.
- Evita e repara automaticamente os erros Help: NO_IX ("Função de usuário não está compilada no repositório")
  e Help: NOFUNCW ("Opção não disponível no Protheus Called By __EXECUTE").
- Gera log automático na pasta \logs do pacote (ou na pasta temporária do usuário),
  informando na tela o caminho exato onde o arquivo foi salvo.
@type function
@author Consultoria / Caetano Ferreira - Automação 2.0 (Padrão TOTVS)
@since 05/11/2026
@return logical, Indica se a operação foi concluída sem erros
/*/
User Function UPDMENUS() as logical
	Local lRet     := .T. as logical
	Local aRotinas := {}  as array

	aRotinas := GetRotinas()

	If FWAlertYesNo( ;
		"AUTOMAÇÃO 2.0 - RELATÓRIOS LEGADOS PROTHEUS" + CRLF + CRLF + ;
		"Deseja executar primeiro o DIAGNÓSTICO DE ERROS (Help: NO_IX / Help: NOFUNCW)?" + CRLF + CRLF + ;
		"[SIM] = Executar Diagnóstico (auditar se há erro NO_IX ou NOFUNCW nos menus)" + CRLF + ;
		"[NÃO] = Ir direto para a Atualização / Reparo Automático dos Menus", ;
		"Automação 2.0 - Relatórios Legados" )
		lRet := ExecDiagMenu(aRotinas, .T.)
	Else
		lRet := ExecUpdMenu(aRotinas)
	EndIf

Return lRet

/*/{Protheus.doc} DIAGMENUS
Atalho direto para execução exclusiva do Diagnóstico de Relatórios Legados (auditoria
de Help: NO_IX e Help: NOFUNCW nas tabelas MPMENU_FUNCTION e MPMENU_ITEM).
@type function
@author Consultoria / Caetano Ferreira - Automação 2.0 (Padrão TOTVS)
@since 05/11/2026
@return logical, Retorna .T. se nenhum erro NO_IX / NOFUNCW persistir no menu
/*/
User Function DIAGMENUS() as logical
	Local lRet     := .T. as logical
	Local aRotinas := {}  as array

	aRotinas := GetRotinas()
	lRet     := ExecDiagMenu(aRotinas, .T.)

Return lRet

/*/{Protheus.doc} ExecUpdMenu
Executa a atualização inteligente dos menus nas tabelas MPMENU_FUNCTION e MPMENU_ITEM,
aplicando o I_TYPE exato de acordo com o código-fonte legado disponibilizado pela TOTVS
('1' para Function U_*C() e '3' para User Function *C()), reparando menus que estavam
com I_TYPE incorreto (Help: NO_IX) e revertendo apontamentos Órfãos sem RPO (Help: NOFUNCW).
@type function
@author Consultoria / Caetano Ferreira - Automação 2.0 (Padrão TOTVS)
@since 05/11/2026
@param aRotinas, array, Matriz de relatórios legados { cRotPadrao, cRotCustom, cTpFonte }
@return logical, Indica se todos os comandos SQL foram executados sem erro
/*/
Static Function ExecUpdMenu(aRotinas as array) as logical
	Local lRet        := .T. as logical
	Local nI          := 0   as numeric
	Local nTotal      := 0   as numeric
	Local nAtivUser   := 0   as numeric
	Local nAtivFull   := 0   as numeric
	Local nSemRpo     := 0   as numeric
	Local nErros      := 0   as numeric
	Local cRotPadrao  := ""  as character
	Local cRotCustom  := ""  as character
	Local cTpFonte    := ""  as character
	Local cTpMenu     := ""  as character
	Local cStatusRpo  := ""  as character
	Local cArqFonte   := ""  as character
	Local cErro       := ""  as character
	Local cMsg        := ""  as character
	Local cLogTxt     := ""  as character
	Local cDetAtiv    := ""  as character
	Local cDetSemRpo  := ""  as character
	Local cDetErros   := ""  as character
	Local cArqLog     := ""  as character

	If !FWAlertYesNo( ;
		"Confirma a Atualização e Reparo Automático dos Menus no banco de dados?" + CRLF + CRLF + ;
		"1. Fontes legados declarados como 'Function U_*C()' (333 relatórios, ex: MATR180) -> atualiza para U_*C com I_TYPE = '1' (elimina erro Help: NO_IX)." + CRLF + ;
		"2. Fontes legados declarados como 'User Function *C()' (FINR150 e FINR865) -> atualiza para U_*C com I_TYPE = '3'." + CRLF + ;
		"3. Fontes ausentes no RPO -> mantém/restaura função padrão com I_TYPE = '1' (elimina erro Help: NOFUNCW).", ;
		"Confirmar Atualização 2.0" )
		Return .F.
	EndIf

	nTotal := Len(aRotinas)

	For nI := 1 To nTotal
		cRotPadrao := Upper(AllTrim(aRotinas[nI][1]))
		cRotCustom := AllTrim(aRotinas[nI][2])
		cTpFonte   := AllTrim(aRotinas[nI][3])
		cTpMenu    := ""
		cStatusRpo := ""
		cArqFonte  := ""
		cErro      := ""

		If ChkFuncRpo(cRotCustom, cTpFonte, @cTpMenu, @cStatusRpo, @cArqFonte)
			If UpdRotMenu(cRotPadrao, cRotCustom, cTpMenu, @cErro)
				If cTpMenu == "3"
					nAtivUser++
				Else
					nAtivFull++
				EndIf
				cDetAtiv += "  [ATIVADO] " + cRotPadrao + " -> " + cRotCustom + " | " + cStatusRpo + " | Fonte: " + cArqFonte + CRLF
				FWLogMsg("INFO", , "UPDMENUS", "UPDMENUS", "", "01", ;
					"[UPDMENUS] Ativado: " + cRotPadrao + " -> " + cRotCustom + " | " + cStatusRpo, 0, 0, {})
			Else
				nErros++
				lRet := .F.
				cDetErros += "  [ERRO SQL] " + cRotPadrao + " -> " + cRotCustom + " | " + cErro + CRLF
				FWLogMsg("ERROR", , "UPDMENUS", "UPDMENUS", "", "02", ;
					"[UPDMENUS] ERRO SQL ao ativar " + cRotPadrao + " -> " + cRotCustom + " | " + cErro, 0, 0, {})
			EndIf
		Else
			nSemRpo++
			If UpdRotMenu(cRotCustom, cRotPadrao, "1", @cErro)
				cDetSemRpo += "  [PADRAO MANTIDO/RESTAURADO] " + cRotPadrao + " (" + cRotCustom + " ausente no RPO)" + CRLF
			Else
				nErros++
				lRet := .F.
				cDetErros += "  [ERRO SQL] Falha ao restaurar " + cRotCustom + " -> " + cRotPadrao + " | " + cErro + CRLF
				FWLogMsg("ERROR", , "UPDMENUS", "UPDMENUS", "", "04", ;
					"[UPDMENUS] ERRO SQL ao restaurar " + cRotCustom + " -> " + cRotPadrao + " | " + cErro, 0, 0, {})
			EndIf
		EndIf
	Next nI

	cMsg := "ATUALIZAÇÃO 2.0 CONCLUÍDA!" + CRLF + CRLF
	cMsg += "Total de relatórios avaliados: " + cValToChar(nTotal) + CRLF
	cMsg += "- Ativados como Function Protheus (Function U_*C / I_TYPE='1'): " + cValToChar(nAtivFull) + CRLF
	cMsg += "- Ativados como User Function (User Function *C / I_TYPE='3'): " + cValToChar(nAtivUser) + CRLF
	cMsg += "- Ausentes no RPO (mantidos/restaurados sem erro NOFUNCW): " + cValToChar(nSemRpo) + CRLF
	cMsg += "- Falhas de execução SQL: " + cValToChar(nErros)

	cLogTxt += "================================================================================" + CRLF
	cLogTxt += " LOG DE ATUALIZAÇÃO DE MENUS - RELATÓRIOS LEGADOS PROTHEUS" + CRLF
	cLogTxt += " Data/Hora: " + DToC(Date()) + " - " + Time() + CRLF
	cLogTxt += "================================================================================" + CRLF + CRLF
	cLogTxt += cMsg + CRLF + CRLF

	If !Empty(cDetAtiv)
		cLogTxt += "--------------------------------------------------------------------------------" + CRLF
		cLogTxt += " RELATÓRIOS ATIVADOS NO MENU (" + cValToChar(nAtivFull + nAtivUser) + ")" + CRLF
		cLogTxt += "--------------------------------------------------------------------------------" + CRLF
		cLogTxt += cDetAtiv + CRLF
	EndIf

	If !Empty(cDetErros)
		cLogTxt += "--------------------------------------------------------------------------------" + CRLF
		cLogTxt += " ERROS DE BANCO DE DADOS (" + cValToChar(nErros) + ")" + CRLF
		cLogTxt += "--------------------------------------------------------------------------------" + CRLF
		cLogTxt += cDetErros + CRLF
	EndIf

	If !Empty(cDetSemRpo)
		cLogTxt += "--------------------------------------------------------------------------------" + CRLF
		cLogTxt += " RELATÓRIOS AUSENTES NO RPO - MANTIDOS NO PADRÃO (" + cValToChar(nSemRpo) + ")" + CRLF
		cLogTxt += "--------------------------------------------------------------------------------" + CRLF
		cLogTxt += cDetSemRpo + CRLF
	EndIf

	cArqLog := SaveLogMenu("log_atualizacao_menus", cLogTxt)
	cMsg    += CRLF + CRLF + "Log salvo em:" + CRLF + cArqLog

	If nErros == 0
		If (nAtivFull + nAtivUser) > 0
			If FWAlertYesNo(cMsg + CRLF + CRLF + "Deseja abrir o arquivo de log agora?", "Sucesso!")
				OpenLogMenu(cArqLog, cLogTxt)
			EndIf
		Else
			FWAlertWarning(cMsg + CRLF + CRLF + ;
				"Nenhum relatório legado (U_*C) foi encontrado compilado no RPO atual." + CRLF + ;
				"Aplique primeiro o patch tttm120-full.ptm (ou os fontes desejados) e execute novamente.", ;
				"Aviso!")
		EndIf
	Else
		If FWAlertYesNo(cMsg + CRLF + CRLF + "Deseja abrir o arquivo de log agora?", "Erro!")
			OpenLogMenu(cArqLog, cLogTxt)
		EndIf
	EndIf

Return lRet

/*/{Protheus.doc} ExecDiagMenu
Executa o Diagnóstico cruzando as tabelas de menu (MPMENU_FUNCTION e MPMENU_ITEM)
com o RPO (GetFuncArray) e com o mapeamento oficial dos fontes legados da TOTVS,
identificando se os erros Help: NO_IX ou Help: NOFUNCW ainda persistem ou foram reparados.
@type function
@author Consultoria / Automação 2.0 (Padrão TOTVS)
@since 05/11/2026
@param aRotinas, array, Matriz de relatórios legados { cRotPadrao, cRotCustom, cTpFonte }
@param lAskRepair, logical, Indica se deve oferecer reparo imediato caso encontre erros
@return logical, Retorna .T. se zero erros NO_IX / NOFUNCW forem encontrados
/*/
Static Function ExecDiagMenu(aRotinas as array, lAskRepair as logical) as logical
	Local lSemErros   := .T. as logical
	Local jMapaMenu   := Nil as json
	Local nI          := 0   as numeric
	Local nTotal      := 0   as numeric
	Local nReparados  := 0   as numeric
	Local nErroMenu   := 0   as numeric
	Local nFaltaMenu  := 0   as numeric
	Local nPadraoOk   := 0   as numeric
	Local cRotPadrao  := ""  as character
	Local cRotCustom  := ""  as character
	Local cTpFonte    := ""  as character
	Local cKeyCustom  := ""  as character
	Local cTpEsperado := ""  as character
	Local cTpBanco    := ""  as character
	Local cStatusRpo  := ""  as character
	Local cArqFonte   := ""  as character
	Local cLaudo      := ""  as character
	Local cListaOk    := ""  as character
	Local cListaErros := ""  as character
	Local cListaPende := ""  as character
	Local cArqLog     := ""  as character
	Local cResumo     := ""  as character
	Local lTemRpo     := .F. as logical
	Local lNoMenuCust := .F. as logical

	jMapaMenu := GetMapaMenu()
	nTotal    := Len(aRotinas)

	cLaudo += "================================================================================" + CRLF
	cLaudo += " DIAGNÓSTICO DE RELATÓRIOS LEGADOS PROTHEUS (AUDITORIA HELP: NO_IX / NOFUNCW)" + CRLF
	cLaudo += " Data/Hora: " + DToC(Date()) + " - " + Time() + CRLF
	cLaudo += "================================================================================" + CRLF + CRLF

	For nI := 1 To nTotal
		cRotPadrao  := Upper(AllTrim(aRotinas[nI][1]))
		cRotCustom  := AllTrim(aRotinas[nI][2])
		cTpFonte    := AllTrim(aRotinas[nI][3])
		cKeyCustom  := Upper(cRotCustom)
		cTpEsperado := ""
		cStatusRpo  := ""
		cArqFonte   := ""

		lTemRpo     := ChkFuncRpo(cRotCustom, cTpFonte, @cTpEsperado, @cStatusRpo, @cArqFonte)
		lNoMenuCust := jMapaMenu:HasProperty(cKeyCustom)

		If lNoMenuCust
			cTpBanco := AllTrim(jMapaMenu[cKeyCustom])
			If !lTemRpo
				// ERRO CRÍTICO: Menu aponta para U_*C, mas a função NÃO existe no RPO -> Gera Help: NOFUNCW / NO_IX!
				nErroMenu++
				lSemErros   := .F.
				cListaErros += "  [X] " + cRotPadrao + " -> Menu chama " + cRotCustom + " (I_TYPE='" + cTpBanco + "'), mas NÃO EXISTE NO RPO!" + CRLF
				cListaErros += "      Como resolver: Aplique o patch tttm120-full.ptm no RPO," + CRLF
				cListaErros += "                     ou execute a atualização do U_UPDMENUS para restaurar o menu padrão." + CRLF
			ElseIf cTpBanco <> cTpEsperado
				// ERRO DE TIPO: I_TYPE no MPMENU_ITEM diverge da declaração do fonte legado da TOTVS -> Gera Help: NO_IX!
				nErroMenu++
				lSemErros   := .F.
				cListaErros += "  [X] " + cRotPadrao + " (" + cRotCustom + ") -> Tipo no Menu (I_TYPE='" + cTpBanco + "') diverge do fonte legado TOTVS (" + cStatusRpo + ") -> Gera Help: NO_IX!" + CRLF
				cListaErros += "      Como resolver: Execute a atualização do U_UPDMENUS para ajustar I_TYPE='" + cTpEsperado + "'." + CRLF
			Else
				// REPARADO E FUNCIONANDO!
				nReparados++
				cListaOk += "  [OK] " + cRotPadrao + " -> " + cRotCustom + " | " + cStatusRpo + " | Fonte: " + cArqFonte + CRLF
			EndIf
		Else
			If lTemRpo
				// Fonte/PTM já está compilado no RPO, mas o menu ainda aponta para a rotina padrão
				nFaltaMenu++
				cListaPende += "  [!] " + cRotPadrao + " -> JÁ compilado no RPO (" + cStatusRpo + "), mas o menu ainda chama " + cRotPadrao + "." + CRLF
			Else
				// Mantido no padrão TOTVS e sem apontamento Órfão
				nPadraoOk++
			EndIf
		EndIf
	Next nI

	cResumo := "RESULTADO DO DIAGNÓSTICO (AUDITORIA HELP: NO_IX / NOFUNCW)" + CRLF + CRLF
	cResumo += "Total de relatórios auditados: " + cValToChar(nTotal) + CRLF
	cResumo += "1. [OK] Reparados e Ativos (RPO + Menu sincronizados): " + cValToChar(nReparados) + CRLF
	cResumo += "2. [ERRO] Com falha 'Help: NO_IX / NOFUNCW' ativa no menu: " + cValToChar(nErroMenu) + CRLF
	cResumo += "3. [AVISO] Compilados no RPO, aguardando atualizar Menu: " + cValToChar(nFaltaMenu) + CRLF
	cResumo += "4. [INFO] No padrão TOTVS (sem apontamento Órfão): " + cValToChar(nPadraoOk) + CRLF

	cLaudo += cResumo + CRLF
	cLaudo += "--------------------------------------------------------------------------------" + CRLF
	cLaudo += " 1. FALHAS DETECTADAS (HELP: NO_IX / HELP: NOFUNCW)" + CRLF
	cLaudo += "--------------------------------------------------------------------------------" + CRLF
	If nErroMenu == 0
		cLaudo += "  Nenhuma falha NO_IX ou NOFUNCW encontrada! Os menus estão 100% de acordo" + CRLF
		cLaudo += "  com os fontes dos relatórios legados disponibilizados pela TOTVS." + CRLF + CRLF
	Else
		cLaudo += cListaErros + CRLF
	EndIf

	If nFaltaMenu > 0
		cLaudo += "--------------------------------------------------------------------------------" + CRLF
		cLaudo += " 2. RELATÓRIOS JÁ COMPILADOS NO RPO AGUARDANDO ATUALIZAR MENU (" + cValToChar(nFaltaMenu) + ")" + CRLF
		cLaudo += "--------------------------------------------------------------------------------" + CRLF
		cLaudo += cListaPende + CRLF
	EndIf

	If nReparados > 0
		cLaudo += "--------------------------------------------------------------------------------" + CRLF
		cLaudo += " 3. RELATÓRIOS REPARADOS E ATIVOS NO MENU (" + cValToChar(nReparados) + ")" + CRLF
		cLaudo += "--------------------------------------------------------------------------------" + CRLF
		cListaOk += ""
		cLaudo += cListaOk + CRLF
	EndIf

	cArqLog := SaveLogMenu("log_diagnostico_menus", cLaudo)

	FWLogMsg("INFO", , "UPDMENUS", "DIAGMENUS", "", "01", ;
		"[DIAGMENUS] Log salvo em: " + cArqLog + " | Reparados: " + cValToChar(nReparados) + " | Erros: " + cValToChar(nErroMenu), 0, 0, {})

	If nErroMenu == 0 .And. nFaltaMenu == 0
		If FWAlertYesNo(cResumo + CRLF + ;
			"Status: Nenhum erro 'Help: NO_IX' ou 'Help: NOFUNCW' encontrado!" + CRLF + CRLF + ;
			"Log salvo em:" + CRLF + cArqLog + CRLF + CRLF + ;
			"Deseja abrir o arquivo de log agora?", "Diagnóstico OK!")
			OpenLogMenu(cArqLog, cLaudo)
		EndIf
	Else
		If lAskRepair
			If FWAlertYesNo(cResumo + CRLF + ;
				"Log salvo em:" + CRLF + cArqLog + CRLF + CRLF + ;
				"Deseja executar AGORA a Atualização / Reparo Automático dos Menus para corrigir as pendências?", ;
				"Pendências Encontradas no Diagnóstico" )
				lSemErros := ExecUpdMenu(aRotinas)
			Else
				OpenLogMenu(cArqLog, cLaudo)
			EndIf
		Else
			FWAlertWarning(cResumo + CRLF + "Log salvo em:" + CRLF + cArqLog, "Resultado do Diagnóstico")
		EndIf
	EndIf

Return lSemErros

/*/{Protheus.doc} SaveLogMenu
Localiza ou cria automaticamente a pasta \logs dentro de Relatorios_legados-main
(ou em <Temp>\Relatorios_legados-main\logs em qualquer computador de consultor/cliente),
grava o arquivo de log com data/hora e retorna o caminho completo onde foi salvo.
@type function
@author Consultoria / Automação 2.0 (Padrão TOTVS)
@since 05/11/2026
@param cPrefixo, character, Prefixo do nome do arquivo de log
@param cConteudo, character, Conteúdo completo do log a ser gravado
@return character, Caminho completo do arquivo de log gravado
/*/
Static Function SaveLogMenu(cPrefixo as character, cConteudo as character) as character
	Local cArqFinal := ""  as character
	Local cArqSrv   := ""  as character
	Local cDirSrv   := ""  as character
	Local cDirLog   := ""  as character
	Local cTempDir  := ""  as character
	Local cUserProf := ""  as character
	Local cCand0    := ""  as character
	Local cCand1    := ""  as character
	Local cCand2    := ""  as character
	Local cCand3    := ""  as character
	Local cStamp    := ""  as character
	Local cNomeArq  := ""  as character
	Local nPosApp   := 0   as numeric
	Local lCopiado  := .F. as logical

	cStamp   := DToS(Date()) + "_" + StrTran(Time(), ":", "")
	cNomeArq := cPrefixo + "_" + cStamp + ".txt"

	// 1. Grava copia garantida no RootPath do servidor (AppServer local, remoto ou Cloud)
	cDirSrv := "\relatorios_legados_logs"
	If !ExistDir(cDirSrv)
		MakeDir(cDirSrv)
	EndIf
	cArqSrv := cDirSrv + "\" + cNomeArq
	If !MemoWrite(cArqSrv, cConteudo)
		cArqSrv := "\" + cNomeArq
		MemoWrite(cArqSrv, cConteudo)
	EndIf

	// 2. Entrega para a estacao do usuario conforme o tipo de cliente
	If GetRemoteType() == 5
		// WebApp sem WebAgent: dispara download direto no navegador
		CpyS2TW(cArqSrv, .T.)
		cArqFinal := cArqSrv
	Else
		cTempDir := AllTrim(GetTempPath())
		If !Empty(cTempDir) .And. !(Right(cTempDir, 1) $ "\/")
			cTempDir += "\"
		EndIf

		nPosApp := At("\appdata\", Lower(cTempDir))
		If nPosApp > 1
			cUserProf := SubStr(cTempDir, 1, nPosApp - 1)
			cCand0    := cUserProf + "\Downloads\Relatorios_legados-main 2.0\Relatorios_legados-main"
			cCand1    := cUserProf + "\Downloads\Relatorios_legados-main\Relatorios_legados-main"
			cCand2    := cUserProf + "\Downloads\Relatorios_legados-main"
			cCand3    := cUserProf + "\Desktop\Relatorios_legados-main"

			If ExistDir(cCand0)
				cDirLog := cCand0 + "\logs"
			ElseIf ExistDir(cCand1)
				cDirLog := cCand1 + "\logs"
			ElseIf ExistDir(cCand2)
				cDirLog := cCand2 + "\logs"
			ElseIf ExistDir(cCand3)
				cDirLog := cCand3 + "\logs"
			EndIf
		EndIf

		If !Empty(cDirLog)
			If !ExistDir(cDirLog)
				MakeDir(cDirLog)
			EndIf
			cArqFinal := cDirLog + "\" + cNomeArq
			lCopiado  := CpyS2T(cArqSrv, cDirLog + "\", .F.)
			If !lCopiado
				lCopiado := MemoWrite(cArqFinal, cConteudo)
			EndIf
		EndIf

		If !lCopiado .And. !Empty(cTempDir)
			cArqFinal := cTempDir + cNomeArq
			lCopiado  := CpyS2T(cArqSrv, cTempDir, .F.)
			If !lCopiado
				lCopiado := MemoWrite(cArqFinal, cConteudo)
			EndIf
		EndIf

		If !lCopiado
			cArqFinal := cArqSrv
		EndIf
	EndIf

Return cArqFinal

/*/{Protheus.doc} OpenLogMenu
Abre o arquivo de log na estacao (ShellExecute) quando disponivel e, no WebApp sem
WebAgent ou caso o sistema operacional nao consiga abrir o arquivo, exibe o log
diretamente em janela modal dentro do Protheus.
@type function
@author Consultoria / Caetano Ferreira - Automacao 2.0 (Padrao TOTVS)
@since 18/11/2026
@param cArqLog, character, Caminho do arquivo de log gerado
@param cConteudo, character, Conteudo completo do log
/*/
Static Function OpenLogMenu(cArqLog as character, cConteudo as character)
	Local nRetShell := 0 as numeric

	If GetRemoteType() == 5
		ShowLogDlg(cArqLog, cConteudo)
	Else
		nRetShell := ShellExecute("open", cArqLog, "", "", 1)
		If nRetShell <= 32
			ShowLogDlg(cArqLog, cConteudo)
		EndIf
	EndIf

Return

/*/{Protheus.doc} ShowLogDlg
Exibe o conteudo completo do arquivo de log em janela modal nativa do Protheus,
garantindo visualizacao imediata mesmo no WebApp ou em servidores remotos.
@type function
@author Consultoria / Caetano Ferreira - Automacao 2.0 (Padrao TOTVS)
@since 18/11/2026
@param cArqLog, character, Caminho do arquivo de log exibido no titulo
@param cConteudo, character, Conteudo completo do log
/*/
Static Function ShowLogDlg(cArqLog as character, cConteudo as character)
	Local oModal   := Nil as object
	Local oPanel   := Nil as object
	Local oFont    := Nil as object
	Local oMemo    := Nil as object
	Local aTamanho := {}  as array
	Local nAlt     := 0   as numeric
	Local nLarg    := 0   as numeric
	Local cTexto   := ""  as character

	cTexto   := cConteudo
	aTamanho := FwGetDialogSize()
	nAlt     := Int(aTamanho[3] * 0.40)
	nLarg    := Int(aTamanho[4] * 0.45)

	If nAlt < 220
		nAlt := 220
	EndIf
	If nLarg < 320
		nLarg := 320
	EndIf

	oFont  := TFont():New("Courier New", , -12, , .F.)
	oModal := FWDialogModal():New()
	oModal:SetTitle("Log - " + cArqLog)
	oModal:SetSize(nAlt, nLarg)
	oModal:SetEscClose(.T.)
	oModal:EnableFormBar(.T.)
	oModal:CreateDialog()
	oModal:addCloseButton()

	oPanel := oModal:getPanelMain()
	oMemo  := TMultiGet():New(0, 0, {|u| IIF(PCount() > 0, cTexto := u, cTexto)}, oPanel, 100, 100, oFont, .F., , , , .T., , , , , , .T., , , , .F., .T.)
	oMemo:Align := CONTROL_ALIGN_ALLCLIENT

	oModal:Activate()
	oFont:End()

Return

/*/{Protheus.doc} ChkFuncRpo
Verifica no RPO via GetFuncArray se a função legada (U_*C) está compilada e
define o I_TYPE de acordo com a declaração real no fonte legado disponibilizado pela TOTVS:
- '1' = Function Protheus (declarado no fonte legado como "Function U_<RELATORIO>C()", ex.: matr180_CUSTOM.prx)
- '3' = User Function (declarado no fonte legado como "User Function <RELATORIO>C()", ex.: FINR150_CUSTOM.PRX e FINR865_CUSTOM.PRW)
OBS.: O retorno aTipos[1] do GetFuncArray() não deve ser usado para sobrepor o I_TYPE, pois o GetFuncArray
retorna "USER" para qualquer função iniciada por "U_" mesmo quando declarada como "Function U_*C()" no fonte.
@type function
@author Consultoria / Automação 2.0 (Padrão TOTVS)
@since 05/11/2026
@param cRotCustom, character, Nome da função legada (ex.: U_MATR180C)
@param cTpFonte, character, Tipo real mapeado do fonte legado da TOTVS ('1' = Function, '3' = User Function)
@param cTpMenu, character, Retorna por referência o I_TYPE correto ('1' ou '3')
@param cStatusRpo, character, Retorna por referência a descrição do tipo
@param cArqFonte, character, Retorna por referência o nome do fonte no RPO
@return logical, Retorna .T. se a função existir compilada no RPO
/*/
Static Function ChkFuncRpo(cRotCustom as character, cTpFonte as character, cTpMenu as character, cStatusRpo as character, cArqFonte as character) as logical
	Local lExiste   := .F. as logical
	Local aFuncoes  := {}  as array
	Local aTipos    := {}  as array
	Local aArquivos := {}  as array
	Local aLinhas   := {}  as array
	Local aDatas    := {}  as array
	Local aHoras    := {}  as array

	aFuncoes := GetFuncArray(cRotCustom, @aTipos, @aArquivos, @aLinhas, @aDatas, @aHoras)

	If Len(aFuncoes) > 0
		lExiste   := .T.
		cArqFonte := AllTrim(aArquivos[1])
		cTpMenu   := AllTrim(cTpFonte)

		If cTpMenu == "3"
			cStatusRpo := "USER FUNCTION (I_TYPE='3' - User Function no fonte legado)"
		Else
			cTpMenu    := "1"
			cStatusRpo := "FUNCTION PROTHEUS (I_TYPE='1' - Function U_*C no fonte legado)"
		EndIf
	Else
		lExiste    := .F.
		cTpMenu    := "1"
		cStatusRpo := "AUSENTE NO RPO"
		cArqFonte  := ""
	EndIf

Return lExiste

/*/{Protheus.doc} GetMapaMenu
Carrega em uma Única consulta SQL todas as funções cadastradas em MPMENU_FUNCTION
e seu respectivo I_TYPE em MPMENU_ITEM para o diagnóstico rápido em memória.
@type function
@author Consultoria / Automação 2.0 (Padrão TOTVS)
@since 05/11/2026
@return json, Objeto JSON mapeando { NOME_FUNCAO: I_TYPE }
/*/
Static Function GetMapaMenu() as json
	Local jMapa  := JsonObject():New() as json
	Local cQuery := ""                 as character
	Local cAlias := ""                 as character
	Local cFunc  := ""                 as character
	Local cTipo  := ""                 as character

	cQuery += " SELECT "
	cQuery += "     UPPER(RTRIM(MPF.F_FUNCTION)) AS ROT_BANCO, "
	cQuery += "     MAX(MPI.I_TYPE) AS TP_BANCO "
	cQuery += " FROM MPMENU_FUNCTION MPF "
	cQuery += " LEFT JOIN MPMENU_ITEM MPI "
	cQuery += "   ON MPI.I_ID_FUNC = MPF.F_ID "
	cQuery += "  AND MPI.D_E_L_E_T_ = ' ' "
	cQuery += " WHERE MPF.D_E_L_E_T_ = ' ' "
	cQuery += " GROUP BY UPPER(RTRIM(MPF.F_FUNCTION)) "

	cAlias := MPSysOpenQuery(cQuery)

	(cAlias)->(dbGoTop())
	Do While !(cAlias)->(EOF())
		cFunc := Upper(AllTrim((cAlias)->ROT_BANCO))
		cTipo := AllTrim((cAlias)->TP_BANCO)
		If !Empty(cFunc)
			jMapa[cFunc] := cTipo
		EndIf
		(cAlias)->(dbSkip())
	EndDo
	(cAlias)->(dbCloseArea())

Return jMapa

/*/{Protheus.doc} UpdRotMenu
Atualiza de forma transacional a função na tabela MPMENU_FUNCTION (abrangendo tanto registros
que ainda estão com o nome padrão quanto registros que já foram alterados para U_*C) e sincroniza
o campo I_TYPE ('1' = Function Protheus / '3' = User Function) na tabela MPMENU_ITEM.
@type function
@author Consultoria / Automação 2.0 (Padrão TOTVS)
@since 05/11/2026
@param cRotOrig, character, Nome da rotina de origem a substituir
@param cRotDest, character, Nome da rotina de destino a gravar
@param cTpFunc, character, Tipo de chamada ('1' = Function Protheus, '3' = User Function)
@param cErro, character, Mensagem de erro SQL retornada por referência
@return logical, Indica se a atualização transacional foi concluída com sucesso
/*/
Static Function UpdRotMenu(cRotOrig as character, cRotDest as character, cTpFunc as character, cErro as character) as logical
	Local lRet      := .T. as logical
	Local nStatus   := 0   as numeric
	Local cSqlFunc  := ""  as character
	Local cSqlItem  := ""  as character
	Local cOrigUp   := ""  as character
	Local cDestUp   := ""  as character

	cOrigUp := Upper(AllTrim(cRotOrig))
	cDestUp := Upper(AllTrim(cRotDest))

	cSqlFunc += " UPDATE MPMENU_FUNCTION "
	cSqlFunc += " SET F_FUNCTION = " + ValToSql(cRotDest)
	cSqlFunc += " WHERE D_E_L_E_T_ = ' ' "
	cSqlFunc += "   AND (UPPER(RTRIM(F_FUNCTION)) = " + ValToSql(cOrigUp)
	cSqlFunc += "    OR  UPPER(RTRIM(F_FUNCTION)) = " + ValToSql(cDestUp) + ") "

	cSqlItem += " UPDATE MPMENU_ITEM "
	cSqlItem += " SET I_TYPE = " + ValToSql(cTpFunc)
	cSqlItem += " WHERE D_E_L_E_T_ = ' ' "
	cSqlItem += "   AND I_ID_FUNC IN ( "
	cSqlItem += "       SELECT F_ID "
	cSqlItem += "       FROM MPMENU_FUNCTION "
	cSqlItem += "       WHERE D_E_L_E_T_ = ' ' "
	cSqlItem += "         AND (UPPER(RTRIM(F_FUNCTION)) = " + ValToSql(cOrigUp)
	cSqlItem += "          OR  UPPER(RTRIM(F_FUNCTION)) = " + ValToSql(cDestUp) + ") "
	cSqlItem += "   ) "

	Begin Transaction
		nStatus := TCSqlExec(cSqlFunc)
		If nStatus < 0
			cErro := TCSqlError()
			lRet  := .F.
			DisarmTransaction()
		Else
			nStatus := TCSqlExec(cSqlItem)
			If nStatus < 0
				cErro := TCSqlError()
				lRet  := .F.
				DisarmTransaction()
			EndIf
		EndIf
	End Transaction

Return lRet

/*/{Protheus.doc} GetRotinas
Retorna os 339 relatórios legados mapeados de acordo com a declaração exata de cada
código-fonte (*_CUSTOM.PRW / *_CUSTOM.PRX) disponibilizado oficialmente pela TOTVS:
- 3ª coluna = "1": Declarado no fonte legado da TOTVS como "Function U_<RELATORIO>C()" (Função Protheus -> I_TYPE = '1')
- 3ª coluna = "3": Declarado no fonte legado da TOTVS como "User Function <RELATORIO>C()" (User Function -> I_TYPE = '3')
@type function
@author Consultoria / Automação 2.0 (Padrão TOTVS)
@since 05/11/2026
@return array, Matriz { cRotPadrao, cRotCustom, cTpFonte }
/*/
Static Function GetRotinas() as array
	Local aRotinas := {} as array

	// FINANCEIRO (97 relatórios: 95 declarados como Function U_*C -> "1" | 2 declarados como User Function -> "3")
	aAdd(aRotinas, { "FINR490",  "U_FINR490C", "1" })
	aAdd(aRotinas, { "FINR480",  "U_FinR480C", "1" })
	aAdd(aRotinas, { "FINR460",  "U_FinR460C", "1" })
	aAdd(aRotinas, { "FINR600",  "U_FINR600C", "1" })
	aAdd(aRotinas, { "FINR020",  "U_FINR020C", "1" })
	aAdd(aRotinas, { "FINR585",  "U_FINR585C", "1" })
	aAdd(aRotinas, { "FINR820",  "U_FinR820C", "1" })
	aAdd(aRotinas, { "FINR355",  "U_FinR355C", "1" })
	aAdd(aRotinas, { "FINR870",  "U_FINR870C", "1" })
	aAdd(aRotinas, { "FINR195",  "U_FINR195C", "1" })
	aAdd(aRotinas, { "FINR740",  "U_FinR740C", "1" })
	aAdd(aRotinas, { "FINR580",  "U_FinR580C", "1" })
	aAdd(aRotinas, { "FINR590",  "U_FinR590C", "1" })
	aAdd(aRotinas, { "FINR750",  "U_FINR750C", "1" })
	aAdd(aRotinas, { "FINR720",  "U_FINR720C", "1" })
	aAdd(aRotinas, { "FINR450",  "U_FinR450C", "1" })
	aAdd(aRotinas, { "FINR830",  "U_FINR830C", "1" })
	aAdd(aRotinas, { "FINR460A", "U_FINR461C", "1" })
	aAdd(aRotinas, { "FINR290",  "U_FinR290C", "1" })
	aAdd(aRotinas, { "FINR665",  "U_FINR665C", "1" })
	aAdd(aRotinas, { "FINR721",  "U_FINR721C", "1" })
	aAdd(aRotinas, { "FINR677",  "U_FINR677C", "1" })
	aAdd(aRotinas, { "FINR731",  "U_FINR731C", "1" })
	aAdd(aRotinas, { "FINR730",  "U_FINR730C", "1" })
	aAdd(aRotinas, { "FINR775",  "U_FINR775C", "1" })
	aAdd(aRotinas, { "FINR678",  "U_FINR678C", "1" })
	aAdd(aRotinas, { "FINR907",  "U_FINR907C", "1" })
	aAdd(aRotinas, { "FINR905",  "U_FINR905C", "1" })
	aAdd(aRotinas, { "FINR694",  "U_FINR694C", "1" })
	aAdd(aRotinas, { "FINR906",  "U_FINR906C", "1" })
	aAdd(aRotinas, { "FINR405",  "U_FINR405C", "1" })
	aAdd(aRotinas, { "FINR904",  "U_FINR904C", "1" })
	aAdd(aRotinas, { "FINR915",  "U_FINR915C", "1" })
	aAdd(aRotinas, { "FINRSRF",  "U_FINRSRFC", "1" })
	aAdd(aRotinas, { "FINR641",  "U_FINR641C", "1" })
	aAdd(aRotinas, { "FINR321",  "U_FINR321C", "1" })
	aAdd(aRotinas, { "FINR132",  "U_FinR132C", "1" })
	aAdd(aRotinas, { "FINRGPS",  "U_FinrGpsC", "1" })
	aAdd(aRotinas, { "FINR500",  "U_FinR500C", "1" })
	aAdd(aRotinas, { "FINR501",  "U_FinR501C", "1" })
	aAdd(aRotinas, { "FINR502",  "U_FinR502C", "1" })
	aAdd(aRotinas, { "FINR150",  "U_FINR150C", "3" }) // FINR150_CUSTOM.PRX -> User Function FINR150C()
	aAdd(aRotinas, { "FINR470",  "U_FINR470C", "1" })
	aAdd(aRotinas, { "FINR471",  "U_FINR471C", "1" })
	aAdd(aRotinas, { "FINR130",  "U_FINR130C", "1" })
	aAdd(aRotinas, { "FINR190",  "U_FinR190C", "1" })
	aAdd(aRotinas, { "FINR620",  "U_FinR620C", "1" })
	aAdd(aRotinas, { "FINR350",  "U_FinR350C", "1" })
	aAdd(aRotinas, { "FINR530",  "U_FINR530C", "1" })
	aAdd(aRotinas, { "FINR650",  "U_FINR650C", "1" })
	aAdd(aRotinas, { "FINR170",  "U_Finr170C", "1" })
	aAdd(aRotinas, { "FINR340",  "U_FinR340C", "1" })
	aAdd(aRotinas, { "FINR710",  "U_FinR710C", "1" })
	aAdd(aRotinas, { "FINR865",  "U_FINR865C", "3" }) // FINR865_CUSTOM.PRW -> User Function FINR865C()
	aAdd(aRotinas, { "FINR158",  "U_Finr158C", "1" })
	aAdd(aRotinas, { "FINR198",  "U_FINR198C", "1" })
	aAdd(aRotinas, { "FINR140",  "U_Finr140C", "1" })
	aAdd(aRotinas, { "FINR120",  "U_FINR120C", "1" })
	aAdd(aRotinas, { "FINR138",  "U_Finr138C", "1" })
	aAdd(aRotinas, { "FINR855",  "U_Finr855C", "1" })
	aAdd(aRotinas, { "FINR560",  "U_FINR560C", "1" })
	aAdd(aRotinas, { "FINR137",  "U_Finr137C", "1" })
	aAdd(aRotinas, { "FINR330",  "U_FINR330C", "1" })
	aAdd(aRotinas, { "FINR010",  "U_FINR010C", "1" })
	aAdd(aRotinas, { "FINR270",  "U_FINR270C", "1" })
	aAdd(aRotinas, { "FINR610",  "U_FINR610C", "1" })
	aAdd(aRotinas, { "FINR899",  "U_Finr899C", "1" })
	aAdd(aRotinas, { "FINR840",  "U_FINR840C", "1" })
	aAdd(aRotinas, { "FINR320",  "U_FINR320C", "1" })
	aAdd(aRotinas, { "FINR180",  "U_FinR180C", "1" })
	aAdd(aRotinas, { "FINR400",  "U_FinR400C", "1" })
	aAdd(aRotinas, { "FINR770",  "U_FinR770C", "1" })
	aAdd(aRotinas, { "FINR087",  "U_Finr087C", "1" })
	aAdd(aRotinas, { "FINR660",  "U_FINR660C", "1" })
	aAdd(aRotinas, { "FINR520",  "U_FinR520C", "1" })
	aAdd(aRotinas, { "FINR680",  "U_FinR680C", "1" })
	aAdd(aRotinas, { "FINR898",  "U_finr898C", "1" })
	aAdd(aRotinas, { "FINR133",  "U_FINR133C", "1" })
	aAdd(aRotinas, { "FINR940",  "U_FINR940C", "1" })
	aAdd(aRotinas, { "FINR280",  "U_FINR280C", "1" })
	aAdd(aRotinas, { "FINR134",  "U_FINR134C", "1" })
	aAdd(aRotinas, { "FINR801",  "U_Finr801C", "1" })
	aAdd(aRotinas, { "FINR295",  "U_FinR295C", "1" })
	aAdd(aRotinas, { "FINR570",  "U_FINR570C", "1" })
	aAdd(aRotinas, { "FINR300",  "U_FinR300C", "1" })
	aAdd(aRotinas, { "FINR760",  "U_FINR760C", "1" })
	aAdd(aRotinas, { "FINR139",  "U_FINR139C", "1" })
	aAdd(aRotinas, { "FINR860",  "U_FinR860C", "1" })
	aAdd(aRotinas, { "FINR895",  "U_FINR895C", "1" })
	aAdd(aRotinas, { "FINR930",  "U_finr930C", "1" })
	aAdd(aRotinas, { "FINR875",  "U_FINR875C", "1" })
	aAdd(aRotinas, { "FINR540",  "U_FinR540C", "1" })
	aAdd(aRotinas, { "FINR565",  "U_FINR565C", "1" })
	aAdd(aRotinas, { "FINR811",  "U_FINR811C", "1" })
	aAdd(aRotinas, { "FINRPIX",  "U_FINRPIXC", "1" })
	aAdd(aRotinas, { "FINR410",  "U_FinR410C", "1" })
	aAdd(aRotinas, { "FINR127",  "U_FINR127C", "1" })

	// MATERIAIS / COMPRAS / ESTOQUE / FATURAMENTO (93 relatórios: todos declarados como Function U_*C -> "1")
	aAdd(aRotinas, { "MATR005",  "U_MATR005C", "1" })
	aAdd(aRotinas, { "MATR010",  "U_Matr010C", "1" })
	aAdd(aRotinas, { "MATR036",  "U_MATR036C", "1" })
	aAdd(aRotinas, { "MATR103",  "U_Matr103C", "1" })
	aAdd(aRotinas, { "MATR105",  "U_MATR105C", "1" })
	aAdd(aRotinas, { "MATR107",  "U_MATR107C", "1" })
	aAdd(aRotinas, { "MATR115",  "U_MATR115C", "1" })
	aAdd(aRotinas, { "MATR175",  "U_MATR175C", "1" })
	aAdd(aRotinas, { "MATR181",  "U_MATR181C", "1" })
	aAdd(aRotinas, { "MATR220",  "U_MATR220C", "1" })
	aAdd(aRotinas, { "MATR230",  "U_MATR230C", "1" })
	aAdd(aRotinas, { "MATR240",  "U_MATR240C", "1" })
	aAdd(aRotinas, { "MATR242",  "U_MATR242C", "1" })
	aAdd(aRotinas, { "MATR245",  "U_MATR245C", "1" })
	aAdd(aRotinas, { "MATR255",  "U_MATR255C", "1" })
	aAdd(aRotinas, { "MATR260",  "U_MATR260C", "1" })
	aAdd(aRotinas, { "MATR265",  "U_MATR265C", "1" })
	aAdd(aRotinas, { "MATR270",  "U_Matr270C", "1" })
	aAdd(aRotinas, { "MATR272",  "U_MATR272C", "1" })
	aAdd(aRotinas, { "MATR275",  "U_MATR275C", "1" })
	aAdd(aRotinas, { "MATR280",  "U_MATR280C", "1" })
	aAdd(aRotinas, { "MATR282",  "U_MATR282C", "1" })
	aAdd(aRotinas, { "MATR285",  "U_MATR285C", "1" })
	aAdd(aRotinas, { "MATR287",  "U_MATR287C", "1" })
	aAdd(aRotinas, { "MATR290",  "U_MATR290C", "1" })
	aAdd(aRotinas, { "MATR300",  "U_MATR300C", "1" })
	aAdd(aRotinas, { "MATR310",  "U_MATR310C", "1" })
	aAdd(aRotinas, { "MATR311",  "U_MATR311C", "1" })
	aAdd(aRotinas, { "MATR320",  "U_MATR320C", "1" })
	aAdd(aRotinas, { "MATR324",  "U_matr324C", "1" })
	aAdd(aRotinas, { "MATR330",  "U_MATR330C", "1" })
	aAdd(aRotinas, { "MATR331",  "U_MATR331C", "1" })
	aAdd(aRotinas, { "MATR340",  "U_MATR340C", "1" })
	aAdd(aRotinas, { "MATR350",  "U_MATR350C", "1" })
	aAdd(aRotinas, { "MATR360",  "U_Matr360C", "1" })
	aAdd(aRotinas, { "MATR390",  "U_Matr390C", "1" })
	aAdd(aRotinas, { "MATR410",  "U_Matr410C", "1" })
	aAdd(aRotinas, { "MATR420",  "U_Matr420C", "1" })
	aAdd(aRotinas, { "MATR430",  "U_Matr430C", "1" })
	aAdd(aRotinas, { "MATR425",  "U_Matr425C", "1" })
	aAdd(aRotinas, { "MATR435",  "U_MATR435C", "1" })
	aAdd(aRotinas, { "MATR445",  "U_MATR445C", "1" })
	aAdd(aRotinas, { "MATR450",  "U_MATR450C", "1" })
	aAdd(aRotinas, { "MATR480",  "U_Matr480C", "1" })
	aAdd(aRotinas, { "MATR485",  "U_MATR485C", "1" })
	aAdd(aRotinas, { "MATR520",  "U_Matr520C", "1" })
	aAdd(aRotinas, { "MATR551",  "U_Matr551C", "1" })
	aAdd(aRotinas, { "MATR715",  "U_MATR715C", "1" })
	aAdd(aRotinas, { "MATR851",  "U_MATR851C", "1" })
	aAdd(aRotinas, { "MATR870",  "U_MATR870C", "1" })
	aAdd(aRotinas, { "MATR875",  "U_MATR875C", "1" })
	aAdd(aRotinas, { "MATR900",  "U_MATR900C", "1" })
	aAdd(aRotinas, { "MATR902",  "U_MATR902C", "1" })
	aAdd(aRotinas, { "MATR903",  "U_MATR903C", "1" })
	aAdd(aRotinas, { "MATR910",  "U_MATR910C", "1" })
	aAdd(aRotinas, { "MATR958",  "U_Matr958C", "1" })
	aAdd(aRotinas, { "MATR960",  "U_Matr960C", "1" })
	aAdd(aRotinas, { "MATR989",  "U_MATR989C", "1" })
	aAdd(aRotinas, { "COMR040",  "U_COMR040C", "1" })
	aAdd(aRotinas, { "COMR041",  "U_COMR041C", "1" })
	aAdd(aRotinas, { "COMR042",  "U_COMR042C", "1" })
	aAdd(aRotinas, { "COMR043",  "U_COMR043C", "1" })
	aAdd(aRotinas, { "COMR100",  "U_COMR100C", "1" })
	aAdd(aRotinas, { "COMR103",  "U_COMR103C", "1" })
	aAdd(aRotinas, { "MATR015",  "U_Matr015C", "1" })
	aAdd(aRotinas, { "MATR030",  "U_Matr030C", "1" })
	aAdd(aRotinas, { "MATR040",  "U_MATR040C", "1" })
	aAdd(aRotinas, { "MATR080",  "U_Matr080C", "1" })
	aAdd(aRotinas, { "MATR086",  "U_MATR086C", "1" })
	aAdd(aRotinas, { "MATR090",  "U_Matr090C", "1" })
	aAdd(aRotinas, { "MATR091",  "U_MATR091C", "1" })
	aAdd(aRotinas, { "MATR110",  "U_Matr110C", "1" })
	aAdd(aRotinas, { "MATR110A", "U_Matr112C", "1" })
	aAdd(aRotinas, { "MATR110B", "U_Matr113C", "1" })
	aAdd(aRotinas, { "MATR120",  "U_Matr120C", "1" })
	aAdd(aRotinas, { "MATR125",  "U_MATR125C", "1" })
	aAdd(aRotinas, { "MATR126",  "U_Matr126C", "1" })
	aAdd(aRotinas, { "MATR130",  "U_MATR130C", "1" })
	aAdd(aRotinas, { "MATR140",  "U_Matr140C", "1" })
	aAdd(aRotinas, { "MATR150",  "U_Matr150C", "1" })
	aAdd(aRotinas, { "MATR160",  "U_Matr160C", "1" })
	aAdd(aRotinas, { "MATR170",  "U_Matr170C", "1" })
	aAdd(aRotinas, { "MATR180",  "U_MATR180C", "1" }) // matr180_CUSTOM.prx -> Function U_MATR180C()
	aAdd(aRotinas, { "MATR190",  "U_Matr190C", "1" })
	aAdd(aRotinas, { "MATR195",  "U_Matr195C", "1" })
	aAdd(aRotinas, { "MATR200",  "U_Matr200C", "1" })
	aAdd(aRotinas, { "MATR210",  "U_Matr210C", "1" })
	aAdd(aRotinas, { "MATR440",  "U_MATR440C", "1" })
	aAdd(aRotinas, { "MATR441",  "U_MATR441C", "1" })
	aAdd(aRotinas, { "MATR952",  "U_MATR952C", "1" })
	aAdd(aRotinas, { "MATR070",  "U_Matr070C", "1" })
	aAdd(aRotinas, { "MATR081",  "U_MATR081C", "1" })

	// CONTABILIDADE (86 relatórios Únicos: todos declarados como Function U_*C -> "1")
	aAdd(aRotinas, { "CTBR550",  "U_CTBR550C", "1" })
	aAdd(aRotinas, { "CTBR320",  "U_CTBR320C", "1" })
	aAdd(aRotinas, { "CTBR255",  "U_Ctbr255C", "1" })
	aAdd(aRotinas, { "CTBR220",  "U_Ctbr220C", "1" })
	aAdd(aRotinas, { "CTBR116",  "U_CTBR116C", "1" })
	aAdd(aRotinas, { "CTBR650",  "U_Ctbr650C", "1" })
	aAdd(aRotinas, { "CTBR049",  "U_Ctbr049C", "1" })
	aAdd(aRotinas, { "CTBR390",  "U_CTBR390C", "1" })
	aAdd(aRotinas, { "CTBR360",  "U_CtbR360C", "1" })
	aAdd(aRotinas, { "CTBR045",  "U_CTBR045C", "1" })
	aAdd(aRotinas, { "CTBR590",  "U_CTBR590C", "1" })
	aAdd(aRotinas, { "CTBR085",  "U_CTBR085C", "1" })
	aAdd(aRotinas, { "CTBR230",  "U_CTBR230C", "1" })
	aAdd(aRotinas, { "CTBR340",  "U_CTBR340C", "1" })
	aAdd(aRotinas, { "CTBR610",  "U_CtbR610C", "1" })
	aAdd(aRotinas, { "CTBR165",  "U_Ctbr165C", "1" })
	aAdd(aRotinas, { "CTBR700",  "U_Ctbr700C", "1" })
	aAdd(aRotinas, { "CTBR395",  "U_Ctbr395C", "1" })
	aAdd(aRotinas, { "CTBR270",  "U_Ctbr270C", "1" })
	aAdd(aRotinas, { "CTBR076",  "U_CTBR076C", "1" })
	aAdd(aRotinas, { "CTBR520",  "U_CtbR520C", "1" })
	aAdd(aRotinas, { "CTBR301",  "U_CTBR302C", "1" })
	aAdd(aRotinas, { "CTBR750",  "U_CTBR750C", "1" })
	aAdd(aRotinas, { "CTBR240",  "U_CTBR240C", "1" })
	aAdd(aRotinas, { "CTBR370",  "U_CtbR370C", "1" })
	aAdd(aRotinas, { "CTBR015",  "U_CTBR015C", "1" })
	aAdd(aRotinas, { "CTBR303",  "U_CTBR304C", "1" })
	aAdd(aRotinas, { "CTBR119",  "U_CTBR119C", "1" })
	aAdd(aRotinas, { "CTBR304",  "U_CTBR305C", "1" })
	aAdd(aRotinas, { "CTBR290",  "U_Ctbr290C", "1" })
	aAdd(aRotinas, { "CTBR300",  "U_Ctbr300C", "1" })
	aAdd(aRotinas, { "CTBR541",  "U_Ctbr544C", "1" })
	aAdd(aRotinas, { "CTBR570",  "U_CtbR570C", "1" })
	aAdd(aRotinas, { "CTBR310",  "U_Ctbr310C", "1" })
	aAdd(aRotinas, { "CTBR302",  "U_CTBR303C", "1" })
	aAdd(aRotinas, { "CTBR010",  "U_Ctbr010C", "1" })
	aAdd(aRotinas, { "CTBR020",  "U_CTBR020C", "1" })
	aAdd(aRotinas, { "CTBR025",  "U_CTBR025C", "1" })
	aAdd(aRotinas, { "CTBR030",  "U_Ctbr030C", "1" })
	aAdd(aRotinas, { "CTBR041",  "U_Ctbr041C", "1" })
	aAdd(aRotinas, { "CTBR043",  "U_Ctbr043C", "1" })
	aAdd(aRotinas, { "CTBR044",  "U_ctbr044C", "1" })
	aAdd(aRotinas, { "CTBR046",  "U_CTBR046C", "1" })
	aAdd(aRotinas, { "CTBR051",  "U_Ctbr051C", "1" })
	aAdd(aRotinas, { "CTBR060",  "U_CTBR060C", "1" })
	aAdd(aRotinas, { "CTBR065",  "U_Ctbr065C", "1" })
	aAdd(aRotinas, { "CTBR075",  "U_Ctbr075C", "1" })
	aAdd(aRotinas, { "CTBR080",  "U_CTBR080C", "1" })
	aAdd(aRotinas, { "CTBR090",  "U_Ctbr090C", "1" })
	aAdd(aRotinas, { "CTBR095",  "U_CTBR095C", "1" })
	aAdd(aRotinas, { "CTBR100",  "U_Ctbr100C", "1" })
	aAdd(aRotinas, { "CTBR112",  "U_CTBR112C", "1" })
	aAdd(aRotinas, { "CTBR117",  "U_CTBR117C", "1" })
	aAdd(aRotinas, { "CTBR120",  "U_CTBR120C", "1" })
	aAdd(aRotinas, { "CTBR130",  "U_CTBR130C", "1" })
	aAdd(aRotinas, { "CTBR140",  "U_CTBR140C", "1" })
	aAdd(aRotinas, { "CTBR145",  "U_CTBR145C", "1" })
	aAdd(aRotinas, { "CTBR150",  "U_Ctbr150C", "1" })
	aAdd(aRotinas, { "CTBR160",  "U_Ctbr160C", "1" })
	aAdd(aRotinas, { "CTBR170",  "U_CTBR170C", "1" })
	aAdd(aRotinas, { "CTBR180",  "U_CTBR180C", "1" })
	aAdd(aRotinas, { "CTBR185",  "U_CtbR185C", "1" })
	aAdd(aRotinas, { "CTBR190",  "U_CTBR190C", "1" })
	aAdd(aRotinas, { "CTBR200",  "U_CTBR200C", "1" })
	aAdd(aRotinas, { "CTBR210",  "U_CTBR210C", "1" })
	aAdd(aRotinas, { "CTBR245",  "U_CTBR245C", "1" })
	aAdd(aRotinas, { "CTBR250",  "U_CtbR250C", "1" })
	aAdd(aRotinas, { "CTBR260",  "U_Ctbr260C", "1" })
	aAdd(aRotinas, { "CTBR265",  "U_Ctbr265C", "1" })
	aAdd(aRotinas, { "CTBR280",  "U_CTBR280C", "1" })
	aAdd(aRotinas, { "CTBR285",  "U_Ctbr285C", "1" })
	aAdd(aRotinas, { "CTBR295",  "U_Ctbr295C", "1" })
	aAdd(aRotinas, { "CTBR330",  "U_CtbR330C", "1" })
	aAdd(aRotinas, { "CTBR380",  "U_CtbR380C", "1" })
	aAdd(aRotinas, { "CTBR403",  "U_CTBR403C", "1" })
	aAdd(aRotinas, { "CTBR404",  "U_CTBR404C", "1" })
	aAdd(aRotinas, { "CTBR410",  "U_CTBR410C", "1" })
	aAdd(aRotinas, { "CTBR420",  "U_CTBR420C", "1" })
	aAdd(aRotinas, { "CTBR430",  "U_CTBR430C", "1" })
	aAdd(aRotinas, { "CTBR440",  "U_CTBR440C", "1" })
	aAdd(aRotinas, { "CTBR480",  "U_Ctbr480C", "1" })
	aAdd(aRotinas, { "CTBR490",  "U_CTBR490C", "1" })
	aAdd(aRotinas, { "CTBR540",  "U_Ctbr540C", "1" })
	aAdd(aRotinas, { "CTBR542",  "U_Ctbr542C", "1" })
	aAdd(aRotinas, { "CTBR600",  "U_Ctbr600C", "1" })
	aAdd(aRotinas, { "CTBR819",  "U_CTBR819C", "1" })

	// ATIVO FIXO (39 relatórios: todos declarados como Function U_*C -> "1")
	aAdd(aRotinas, { "ATFR326",  "U_ATFR326C", "1" })
	aAdd(aRotinas, { "ATFR101",  "U_ATFR101C", "1" })
	aAdd(aRotinas, { "ATFR300",  "U_ATFR300C", "1" })
	aAdd(aRotinas, { "ATFR325",  "U_ATFR325C", "1" })
	aAdd(aRotinas, { "ATFR434",  "U_ATFR434C", "1" })
	aAdd(aRotinas, { "ATFR095",  "U_ATFR095C", "1" })
	aAdd(aRotinas, { "ATFR450",  "U_ATFR450C", "1" })
	aAdd(aRotinas, { "ATFR280",  "U_ATFR280C", "1" })
	aAdd(aRotinas, { "ATFR470",  "U_ATFR470C", "1" })
	aAdd(aRotinas, { "ATFR310",  "U_ATFR310C", "1" })
	aAdd(aRotinas, { "ATFR431",  "U_ATFR431C", "1" })
	aAdd(aRotinas, { "ATFR433",  "U_ATFR433C", "1" })
	aAdd(aRotinas, { "ATFR490",  "U_ATFR490C", "1" })
	aAdd(aRotinas, { "ATFR471",  "U_ATFR471C", "1" })
	aAdd(aRotinas, { "ATFR110",  "U_ATFR110C", "1" })
	aAdd(aRotinas, { "ATFR070",  "U_ATFR070C", "1" })
	aAdd(aRotinas, { "ATFR010",  "U_AtfR010C", "1" })
	aAdd(aRotinas, { "ATFR120",  "U_ATFR120C", "1" })
	aAdd(aRotinas, { "ATFR080",  "U_Atfr080C", "1" })
	aAdd(aRotinas, { "ATFR150",  "U_ATFR150C", "1" })
	aAdd(aRotinas, { "ATFR130",  "U_ATFR130C", "1" })
	aAdd(aRotinas, { "ATFR030",  "U_ATFR030C", "1" })
	aAdd(aRotinas, { "ATFR072",  "U_ATFR072C", "1" })
	aAdd(aRotinas, { "ATFR100",  "U_ATFR100C", "1" })
	aAdd(aRotinas, { "ATFR033",  "U_ATFR033C", "1" })
	aAdd(aRotinas, { "ATFR210",  "U_ATFR210C", "1" })
	aAdd(aRotinas, { "ATFR180",  "U_ATFR180C", "1" })
	aAdd(aRotinas, { "ATFR073",  "U_ATFR073C", "1" })
	aAdd(aRotinas, { "ATFR190",  "U_ATFR190C", "1" })
	aAdd(aRotinas, { "ATFR260",  "U_ATFR260C", "1" })
	aAdd(aRotinas, { "ATFR090",  "U_ATFR090C", "1" })
	aAdd(aRotinas, { "ATFR200",  "U_ATFR200C", "1" })
	aAdd(aRotinas, { "ATFR270",  "U_ATFR270C", "1" })
	aAdd(aRotinas, { "ATFR320",  "U_ATFR320C", "1" })
	aAdd(aRotinas, { "ATFR432",  "U_ATFR432C", "1" })
	aAdd(aRotinas, { "ATFR350",  "U_ATFR350C", "1" })
	aAdd(aRotinas, { "ATFR250",  "U_ATFR250C", "1" })
	aAdd(aRotinas, { "ATFR074",  "U_ATFR074C", "1" })
	aAdd(aRotinas, { "ATFR170",  "U_ATFR170C", "1" })

	// ORÇAMENTO PCO (13 relatórios: todos declarados como Function U_*C -> "1")
	aAdd(aRotinas, { "PCOR550",  "U_PCOR550C", "1" })
	aAdd(aRotinas, { "PCOR055",  "U_PCOR055C", "1" })
	aAdd(aRotinas, { "PCOR002",  "U_PCOR002C", "1" })
	aAdd(aRotinas, { "PCOR350",  "U_PCOR350C", "1" })
	aAdd(aRotinas, { "PCOR530",  "U_PCOR530C", "1" })
	aAdd(aRotinas, { "PCOR340",  "U_PCOR340C", "1" })
	aAdd(aRotinas, { "PCOR211",  "U_PCOR211C", "1" })
	aAdd(aRotinas, { "PCOR030",  "U_PCOR030C", "1" })
	aAdd(aRotinas, { "PCOR060",  "U_PCOR060C", "1" })
	aAdd(aRotinas, { "PCOR200",  "U_PCOR200C", "1" })
	aAdd(aRotinas, { "PCOR001",  "U_PCOR001C", "1" })
	aAdd(aRotinas, { "PCOR045",  "U_PCOR045C", "1" })
	aAdd(aRotinas, { "PCOR400",  "U_PCOR400C", "1" })

	// GESTÃO DE COMPRAS PÚBLICAS / LICITAÇÕES (4 relatórios: todos declarados como Function U_*C -> "1")
	aAdd(aRotinas, { "GCPR001",  "U_GCPR001C", "1" })
	aAdd(aRotinas, { "GCPR003",  "U_GCPR003C", "1" })
	aAdd(aRotinas, { "GCPR002",  "U_GCPR002C", "1" })
	aAdd(aRotinas, { "GCPR004",  "U_GCPR004C", "1" })

	// GESTÃO DE CONTRATOS (8 relatórios: todos declarados como Function U_*C -> "1")
	aAdd(aRotinas, { "CNTR010",  "U_CNTR010C", "1" })
	aAdd(aRotinas, { "CNTR031",  "U_CNTR031C", "1" })
	aAdd(aRotinas, { "CNTR040",  "U_CNTR040C", "1" })
	aAdd(aRotinas, { "CNTR050",  "U_CNTR050C", "1" })
	aAdd(aRotinas, { "CNTR121",  "U_CNTR121C", "1" })
	aAdd(aRotinas, { "CNTR020",  "U_CNTR020C", "1" })
	aAdd(aRotinas, { "CNTR300",  "U_CNTR300C", "1" })
	aAdd(aRotinas, { "CNTR030",  "U_CNTR030C", "1" })

Return aRotinas
