/*******************************************************************************
** DSS05.04.9 - Monitoramento de Empregados Desligados com Acessos Ativos     **
**                                                                             **
** Objetivo: Identificar funcionários desligados que ainda possuem acessos    **
**           ativos em sistemas corporativos                                  **
**                                                                             **
** Histórico de Modificações:                                                 **
** Data          Por                Motivo                                     **
** 03/10/2025    Lucas Carmo        Migração para o SAS Viya                   **
** 04/10/2025    Assistente IA      Reorganização e melhoria da legibilidade  **
*******************************************************************************/

/* ============================================================================
   CONFIGURAÇÃO INICIAL E LOGS
   ============================================================================ */

/* Define o caminho do log */
%let caminho_log = /sasdata/Smart_Compliance/c0689689/dss.log;

/* Redireciona o log para o arquivo desejado */
proc printto log="&caminho_log." new;
run;

/* ============================================================================
   INCLUSÃO DE BIBLIOTECAS E MACROS
   ============================================================================ */

/* Limpa e define bibliotecas */
filename CROSS Clear;
filename CROSS filesrvc folderpath="/TECH4ALL/ACDI/Cross/Includes";
%include CROSS ('libnames_sql.sas');
%include CROSS ('chamada_sap.sas');
%sql_libs(BD_ACDI);

/* Inclui programas auxiliares */
filename VSC Clear;
filename VSC filesrvc folderpath="/TECH4ALL/ACDI/Auditoria/DSS05 - Lucas/Programas";
%include VSC ('API_VSC_OK.sas');

/* ============================================================================
   EXECUÇÃO DE SCRIPTS PYTHON
   ============================================================================ */

/* Script LDAP */
filename script Clear;
filename script filesrvc folderpath='/TECH4ALL/ACDI/Auditoria/DSS05 - Lucas/Programas' filename='LDAP_NEW.py';
proc python infile = script;
run;

/* Script Base MDM */
filename basemdm Clear;
filename basemdm filesrvc folderpath='/TECH4ALL/ACDI/Auditoria/DSS05 - Lucas/Programas' filename='BASE_MDM.py';
proc python infile = basemdm;
run;

/* ============================================================================
   CONFIGURAÇÃO DE BIBLIOTECAS DE DADOS
   ============================================================================ */

/* Biblioteca MDM */
libname MDMRH Clear;
LIBNAME MDMRH SQLSVR Datasrc=USAZU1VALEDWRH001 SCHEMA=DWHK USER=AAAIAUDITORIA  
    connection=sharedread DM_UNICODE="utf-16"
    PASSWORD="{SAS002}526FE20D5B3A1C7D1CB9F0261B6886FA1F32FB7B";

/* ============================================================================
   MÓDULO 1: EXTRAÇÃO DE DADOS DO CRM
   ============================================================================ */

%macro extrair_crm();
    /* Configuração de headers para API */
    filename headers TEMP;
    data _null_;
        file headers;
        put "Ocp-Apim-Subscription-Key: 13f17c8875a5426fb7d4c3fa6dae5986";
        put "Ocp-Aim-Trace: true";
    run;

    /* Body da requisição JSON */
    filename json_in temp;
    data _null_;
        file json_in;
        input;
        put _infile_;
        datalines;
    {
    "RequestID":"3"
    }
    run;

    /* Chamada da API */
    filename resp temp;
    proc http
        clear_cache
        url = "https://api-crm-prd.azure-api.net/auditlog/AuditLogRequest"
        headerin=headers
        proxyhost="brvix5secxca001.valenet.valeglobal.net"
        proxyport=8080
        proxyusername="s-ad-sasviya"
        proxypassword="{SAS002}D64DB1551963C44B1B4B7CE12DA7923E3A46924057B436A2"
        method = "POST"
        in=json_in
        out=resp;
    run;

    /* Processamento da resposta */
    libname respD JSON FILEREF=RESP;
    PROC DATASETS LIB= respD;
    QUIT;

    /* Criação da tabela base do CRM */
    PROC SQL;
        CREATE TABLE CRM_TEC_3 AS 
        SELECT 
            FULLNAME AS USERFULLNAME,
            PRIMARYEMAIL AS EMAIL,
            "CRM" AS SYSTEM,
            '' AS LAST_SUCCESSFUL_CONNECT,
            '' AS MATRICULA,
            STATUS          
        FROM respD.VALUEBM_USERS;
    QUIT;

    /* Limpeza e padronização dos dados */
    DATA BASE_CRM;
        FORMAT MATRICULA $200.;
        INFORMAT MATRICULA $200.;
        SET CRM_TEC_3;
        
        /* Filtros de qualidade */
        IF USERFULLNAME='' THEN DELETE;
        IF SUBSTR(COMPRESS(USERFULLNAME),1,1)= '#' THEN DELETE;
        IF SCAN(EMAIL,2,'@') NE 'vale.com' THEN DELETE;
        
        /* Extração da matrícula do email */
        IF SUBSTR(COMPRESS(EMAIL),1,2)= 'C0' THEN
            MATRICULA=SUBSTRN(EMAIL, 1, 8);
        DROP LASTLOGONUTC;
    RUN;

    /* Limpeza de tabelas temporárias */
    PROC DELETE DATA = TESTE ALLDATA ALLDATA1 CRM3 CRM_TEC_3; 
    RUN;
%mend extrair_crm;

%extrair_crm();

/* ============================================================================
   MÓDULO 2: EXTRAÇÃO DE DADOS DO ESPAIDER
   ============================================================================ */

%macro extrair_espaider();
    /* Configuração de headers */
    filename headers TEMP;
    data _null_;
        file headers;
        put "user: integracaoAPI";
        put "password: 1nt3gr@cao4P1";
        put "token: 4hd4JpQHvZnAjEyquGgOKaoR7KM6Ap1aRGfWGB31twDykX4N6jXD9yq0S2fqzxfzj/6vCUDI6ZWooM1qqiTNbA==";
    run;

    /* Primeira chamada da API */
    filename pam temp;
    proc http url = "https://espaider.com.br/Vale/WCF/Vale/WCFExportacaoDados/WSExportaDados.svc/UserPermissionsReport"
        method = "GET"
        out = pam
        proxyhost="brvix5secxca001.valenet.valeglobal.net"
        proxyport=8080
        proxyusername="s-ad-sasviya"
        proxypassword="{SAS002}D64DB1551963C44B1B4B7CE12DA7923E3A46924057B436A2"
        headerin=headers;
    run;

    /* Processamento da primeira resposta */
    libname respD JSON fileref=pam;
    proc datasets lib=respD;
    quit;

    DATA DADOS_ESPAIDER;
        SET RESPD.USERPERMISSIONREPORT;
    RUN;

    /* Busca próxima página */
    PROC SQL;
        SELECT 'https://espaider.com.br'||SUBSTR(VALUE,21,(LENGTH(VALUE)-20)) INTO :url
        FROM respD.ALLDATA
        WHERE P1 = 'proximaPagina';
    QUIT;

    /* Segunda chamada da API */
    filename pam temp;
    proc http url = "&url"
        method = "GET"
        out = pam
        proxyhost="brvix5secxca001.valenet.valeglobal.net"
        proxyport=8080
        proxyusername="s-ad-sasviya"
        proxypassword="{SAS002}D64DB1551963C44B1B4B7CE12DA7923E3A46924057B436A2"
        headerin=headers;
    run;

    /* Processamento da segunda resposta */
    libname respD JSON fileref=pam;
    proc datasets lib=respD;
    quit;

    DATA DADOS_ESPAIDER;
        SET DADOS_ESPAIDER RESPD.USERPERMISSIONREPORT;
    RUN;

    /* Criação da tabela base do Espaider */
    PROC SQL;
        CREATE TABLE BASE_ESPAIDER AS 
        SELECT UserID AS MATRICULA,
                UserName as USERFULLNAME,
                'ESPAIDER' AS SYSTEM,
                PUT(Ativo, BEST.) as STATUS,
                DATEPART(input(UltimoLogin, anydtdtm19.)) AS LAST_SUCCESSFUL_CONNECT
        FROM DADOS_ESPAIDER
        WHERE NOT (PRXMATCH('~Usuário modelo Fácil|Administrador|Agendamento|NÃO|integracao|test~i',USERFULLNAME))
                AND NOT (PRXMATCH('~ADM|TEST~i',UPCASE(UserID)));
    QUIT;

    /* Limpeza de tabelas temporárias */
    PROC DELETE DATA = ESPAIDER_1 ALLDATA ALLDATA1 DADOS_ESPAIDER; 
    RUN;

    /* Correção de dados invertidos */
    data BASE_ESPAIDER;
        set BASE_ESPAIDER;
        length nome_corrigido $100 matricula_corrigida $30;
        
        /* Validação de matrícula */
        re_matricula = prxparse('/^[A-Z0-9\-_]{6,10}$/i'); 
        is_matricula = prxmatch(re_matricula, strip(USERFULLNAME));
        
        /* Validação de nome */
        is_nome = countw(strip(MATRICULA), ' ') >= 2;
        
        /* Correção se invertido */
        if is_nome and is_matricula then do;
            nome_corrigido = MATRICULA;
            matricula_corrigida = USERFULLNAME;
        end;
        else do;
            nome_corrigido = USERFULLNAME;
            matricula_corrigida = MATRICULA;
        end;
        
        drop re_: USERFULLNAME MATRICULA;
        rename
            nome_corrigido = USERFULLNAME
            matricula_corrigida = MATRICULA;
    run;
%mend extrair_espaider;

%extrair_espaider();

/* ============================================================================
   MÓDULO 3: EXTRAÇÃO DE DADOS DOS SISTEMAS NAUTILUS
   ============================================================================ */

%macro extrair_nautilus();
    /* Nautilus Pelotização */
    LIBNAME NAUPELOT ORACLE PATH=ORAPBR077 SCHEMA=BDINTLIMSDIPE USER=PJSASITSERV 
    PASSWORD="{SAS002}C7678D15282781F412D102A04219BE1557B2E63421A15F0D";

    PROC SQL;
        CREATE TABLE BASE_NAUPELOT AS
            SELECT distinct 
                COMPRESS(DATABASE_NAME) AS MATRICULA,
                'NAUTPELOT' AS SYSTEM,
                'A' AS STATUS,  
                FULL_NAME AS USERFULLNAME,
                DATEPART(MAX_DATE) AS LAST_SUCCESSFUL_CONNECT   
            FROM NAUPELOT.OPERATOR_SAS_IT
            WHERE DATABASE_NAME NOT IN ('IAM_USER','LGF0862','LIMS','LIMS_SYS','PJLIMSBCKG','R0600465','TESTESCHED');
    QUIT;

    /* Nautilus Oman */
    LIBNAME NAUTOMAN ORACLE PATH=ORAPBR078 SCHEMA=BDINTLIMSDIPE USER=PJSASITSERV 
    PASSWORD="{SAS002}C7678D15282781F412D102A04219BE1557B2E63421A15F0D";

    PROC SQL;
        CREATE TABLE BASE_NAUOMAN AS
            SELECT distinct
                COMPRESS(UPCASE(DATABASE_NAME)) AS MATRICULA,
                'NAUTOMAN' AS SYSTEM,
                'A' AS STATUS,  
                FULL_NAME AS USERFULLNAME,
                DATEPART(MAX_DATE) AS LAST_SUCCESSFUL_CONNECT   
            FROM NAUTOMAN.OPERATOR_SAS_IT
            WHERE DATABASE_NAME NOT IN ('LIMS','LIMS_SYS','PJLIMSBCKG','PROC602','PROC930','S-AD-PROC930');
    QUIT;

    /* Nautilus Sul */
    LIBNAME NAUSUL ORACLE PATH=ORAPBR079 SCHEMA=BDINTLIMSDIPE USER=PJSASITSERV 
    PASSWORD="{SAS002}C7678D15282781F412D102A04219BE1557B2E63421A15F0D";

    PROC SQL;
        CREATE TABLE BASE_NAUSUL AS
            SELECT distinct
                COMPRESS(UPCASE(DATABASE_NAME)) AS MATRICULA,
                'NAUTSUL' AS SYSTEM,
                'A' AS STATUS,  
                FULL_NAME AS USERFULLNAME,
                DATEPART(MAX_DATE) AS LAST_SUCCESSFUL_CONNECT   
            FROM NAUSUL.OPERATOR_SAS_IT
            WHERE DATABASE_NAME NOT IN ('LIMS_SYS','R0600284','S-AD-PROC928','background','lims');
    QUIT;

    /* Nautilus Norte */
    LIBNAME NAUNORTE ORACLE PATH=ORAPBR075 SCHEMA=BDINTLIMSDIPE USER=PJSASITSERV 
    PASSWORD="{SAS002}C7678D15282781F412D102A04219BE1557B2E63421A15F0D";

    PROC SQL;
        CREATE TABLE BASE_NAUNORTE AS
            SELECT distinct
                COMPRESS(UPCASE(DATABASE_NAME)) AS MATRICULA,
                'NAUTNORTE' AS SYSTEM,
                'A' AS STATUS,  
                FULL_NAME AS USERFULLNAME,
                DATEPART(MAX_DATE) AS LAST_SUCCESSFUL_CONNECT   
            FROM NAUNORTE.OPERATOR_SAS_IT
            WHERE DATABASE_NAME NOT IN ('EAI_LG20090004_38','EAI_MI20150003_01','LIMS','LIMS_SYS','PJLIMSBCKG','PROC602','PROC927','R0600575','S-AD-PIMS','S-AD-PROC927','usuario_painel');
    QUIT;
%mend extrair_nautilus;

%extrair_nautilus();

/* ============================================================================
   MÓDULO 4: EXTRAÇÃO DE DADOS DO PAM
   ============================================================================ */

%macro extrair_pam();
    /* Configuração de variáveis */
    %let baseUrl=https://y394ab.ps.beyondtrustcloud.com/BeyondTrust/api/public/v3/Auth/SignAppIn;
    %let baseUsers=https://y394ab.ps.beyondtrustcloud.com/BeyondTrust/api/public/v3/Users;
    %let apiUser=S-PAM-SAS-2760001;
    %let apiKey=d8df15cc8488f52ff48d782d0959f10baf1d1ceb8f5be9635597c7fc0ee6aab66d83c01c2fea7430ccaf1ea3323c0d350908e6609688275c28785ff415214147;

    /* Autenticação */
    filename resp temp encoding="utf-8";
    proc http
        url="&baseUrl."
        method="POST"
        out=resp
        proxyhost="&proxyhost."
        proxyport=8080
        proxyusername="&proxyusername."
        proxypassword="&proxypassword."
        webusername="&sn_username."
        webpassword="&sn_password.";
        headers "Authorization"="PS-Auth key=&apiKey.;runas=&apiUser.";
    run;

    /* Busca de usuários */
    filename resp temp;
    proc http
        url="&baseUsers."
        method="GET"
        out=resp
        proxyhost="&proxyhost."
        proxyport=8080
        proxyusername="&proxyusername."
        proxypassword="&proxypassword."
        webusername="&sn_username."
        webpassword="&sn_password.";
    run;

    /* Processamento dos dados */
    libname jsonresp json fileref=resp;

    data users_grouped;
        set jsonresp.alldata;
        retain UserGroup 0;
        if P1='UserID' then UserGroup+1;
    run;

    proc sql;
        create table work.BASE_PAM_1 as
        select 
            upcase(max(case when P1='UserName' then Value end)) as MATRICULA,
            upcase(max(case when P1='FirstName' then Value end)) as FirstName,
            upcase(max(case when P1='LastName' then Value end)) as LastName,
            max(case 
            when P1='IsActive' then 
                 case when lowcase(Value)='true' then 'A'
                      else 'I'
                 end
        end) as STATUS,
            upcase(max(case when P1='EmailAddress' then Value end)) as EmailAddress,
            catx(' ', 
                upcase(max(case when P1='FirstName' then Value end)),
                upcase(max(case when P1='LastName' then Value end))
            ) as UserFullName
        from users_grouped
        group by UserGroup
        order by UserGroup;
    quit;

    /* Limpeza e padronização */
    data BASE_PAM;
        set BASE_PAM_1;
        SYSTEM = 'PAM';
        LAST_SUCCESSFUL_CONNECT = 0;
        
        /* Remove registros com 'dxc' no email */
        if index(lowcase(EmailAddress), 'dxc') = 0;
        drop firstName lastName _NAME_ userGroups userName usuario active;
    run;

    /* Limpeza de tabelas temporárias */
    PROC DELETE DATA = ALLDATA BASE_PAM_1 users_grouped; 
    RUN;
%mend extrair_pam;

%extrair_pam();

/* ============================================================================
   MÓDULO 5: EXTRAÇÃO DE DADOS SAP
   ============================================================================ */

%macro extrair_sap();
    /* CV_SAS_USR02 - Dados de usuários */
    PROC SQL;
        &CONNECT_SAP.;
        CREATE TABLE CV_SAS_USR02 AS
            SELECT  * 
                FROM CONNECTION TO X1 (
                    SELECT 
                        BNAME AS ID,
                        ERDAT,
                        ANAME,
                        SYSTEM,
                        MANDT,
                        TRDAT AS LAST_SUCCESSFUL_CONNECT,
                        LTIME, 
                        UFLAG,
                        USTYP   
                    FROM 
                        "_SYS_BIC"."HIW_PRD.S.SAS/CV_SAS_USR02");
        DISCONNECT FROM X1;
    QUIT;

    /* Processamento e filtros */
    Data CV_SAS_USR02 (rename=(LAST_SUCCESSFUL_CONNECT2=LAST_SUCCESSFUL_CONNECT));
        set CV_SAS_USR02;
        LAST_SUCCESSFUL_CONNECT2=input(LAST_SUCCESSFUL_CONNECT, yymmdd8.);

        /* Identificação de robôs */
        if upcase(USTYP) = 'B' then ROBO = 1;
        else ROBO = 0;

        /* Filtros por sistema e mandante */
        if ((SYSTEM="ECC" and MANDT = 500)
            or( SYSTEM="SRM" and MANDT = 500)
            or( SYSTEM="SOLMAN" and MANDT = 100)
            or(SYSTEM="GRC AC" and MANDT = 300)
            or(SYSTEM="GRC NFe" and MANDT = 400)) and (UFLAG not in ('64','32') 
            or USTYP not= upcase ("a"));
        drop LAST_SUCCESSFUL_CONNECT;
    run;

    /* CV_SAS_USR21 - Dados pessoais */
    PROC SQL;
        &CONNECT_SAP.;
        CREATE TABLE CV_SAS_USR21 AS
            SELECT
                * FROM CONNECTION TO X1 (
            SELECT 
                BNAME AS ID,
                PERSNUMBER,
                SYSTEM
            FROM 
                "_SYS_BIC"."HIW_PRD.S.SAS/CV_SAS_USR21" 
                );
        DISCONNECT FROM X1;
    QUIT;

    /* CV_SAS_ADRP - Dados de endereço */
    PROC SQL;
        &CONNECT_SAP.;
        CREATE TABLE CV_SAS_ADRP AS
            SELECT
                * FROM CONNECTION TO X1 (
            SELECT
                PERSNUMBER,
                SYSTEM
            FROM 
                "_SYS_BIC"."HIW_PRD.S.SAS/CV_SAS_ADRP" 
                );
        DISCONNECT FROM X1;
    QUIT;

    /* CV_SAS_AGR_USERS - Grupos de usuários */
    PROC SQL;
        &CONNECT_SAP.;
        CREATE TABLE CV_SAS_AGR_USERS AS
            SELECT
                * FROM CONNECTION TO X1 (
            SELECT 
                UNAME,
                AGR_NAME,
                FROM_DAT,
                TO_DAT,
                SYSTEM 
            FROM 
                "_SYS_BIC"."HIW_PRD.S.SAS/CV_SAS_AGR_USERS" 
                );
        DISCONNECT FROM X1;
    QUIT;

    /* Junção dos dados SAP */
    proc sql;
        create table SAP_OTHERS as 
            select distinct
                t1.*,
                t2.*,
                t3.*,
                t4.*
            from
                CV_SAS_USR02 t1
            inner join 
                CV_SAS_USR21 as t2 on t1.ID = t2.ID
            left join
                CV_SAS_ADRP as t3 on t2.PERSNUMBER =t3.PERSNUMBER
            left join 
                CV_SAS_AGR_USERS as t4 on t4.UNAME = t1.ID;
    quit;

    /* Formatação do campo ERDAT */
    DATA SAP_OTHERS (rename=(ERDAT2=ERDAT));
        SET SAP_OTHERS;
        ERDAT2=input(ERDAT,yymmdd8.);
        drop ERDAT;
    run;

    /* Consulta aos dados de processo */
    PROC SQL;
        &CONNECT_SAP.;
        CREATE TABLE PROCESSO AS
            SELECT
                * FROM CONNECTION TO X1 ( 
            SELECT
                *
            FROM 
                "SYS"."USERS"
        WHERE USER_DEACTIVATED = 'FALSE'
                );
        DISCONNECT FROM X1;
    QUIT;

    /* Formatação dos dados SAP HANA */
    PROC SQL;
        CREATE TABLE JUNCAO_2 AS 
            SELECT 
                USER_NAME as ID,
                datepart(CREATE_TIME) as ERDAT,
                CREATOR as ANAME,
                'SAP HANA' as SYSTEM,
                USER_ID as PERSNUMBER,
                USER_NAME as NAME_TEXT,
                USERGROUP_NAME as AGR_NAME,
                CREATE_TIME as FROM_DAT,
                VALID_FROM as TO_DAT,
                datepart(LAST_SUCCESSFUL_CONNECT) as   LAST_SUCCESSFUL_CONNECT 
            FROM PROCESSO;
    QUIT;

    /* Formatação dos campos */
    data SAP_HANA (RENAME=( PERSNUMBER2=PERSNUMBER FROM_DAT2=FROM_DAT 
                            TO_DAT2=TO_DAT ));
        SET JUNCAO_2;
        PERSNUMBER2=COMPRESS(PUT(PERSNUMBER,$20.));
        FROM_DAT2=COMPRESS(PUT(FROM_DAT,$20.));
        TO_DAT2=COMPRESS(PUT(TO_DAT,$20.));

        DROP  PERSNUMBER FROM_DAT TO_DAT LAST_SUCCESSFUL_CONNECT;
    RUN;

    /* Formatação dos dados SAP2 */
    DATA SAP2;
        LENGTH  FROM_DAT TO_DAT $20. SYSTEM $10.;
        SET SAP_OTHERS;
    RUN;

    /* Junção dos sistemas SAP */
    data JUNCAO_SISTEMAS (rename=(ERDAT2=ERDAT));
        SET SAP_HANA    
            SAP2;
        ERDAT2=put (ERDAT,ddmmyy10.);
        drop ERDAT;
    RUN;

    /* Remoção de duplicatas */
    proc sort data=JUNCAO_SISTEMAS nodupkey out= BASE_PREP;
        by _all_;
    run;

    /* Criação da tabela final SAP */
    PROC SQL;
        CREATE TABLE BASE_SAP AS
        SELECT DISTINCT     
                SYSTEM,
                ROBO,
                COMPRESS(PUT(UFLAG, BEST.)) AS STATUS,
                ID AS MATRICULA,
                '' AS USERFULLNAME,
                LAST_SUCCESSFUL_CONNECT
        FROM BASE_PREP;
    QUIT;

    /* Limpeza de tabelas temporárias */
    PROC DELETE DATA = CV_SAS_USR02 CV_SAS_USR21 CV_SAS_ADRP CV_SAS_AGR_USERS 
                  SAP_OTHERS PROCESSO JUNCAO_2 SAP_HANNA SAP2 JUNCAO_SISTEMAS BASE_PREP; 
    RUN;
%mend extrair_sap;

%extrair_sap();

/* ============================================================================
   MÓDULO 6: CONSOLIDAÇÃO E ANÁLISE DOS DADOS
   ============================================================================ */

%macro consolidar_dados();
    /* Junção das bases de sistemas */
    DATA BASE_SYSTEMAS;
        length SYSTEM $30 STATUS $24 MATRICULA $50 MATRICULA_ORIGINAL $50 PRIMEIRO $50;
        format SYSTEM $50.;
        format STATUS $50.;
        SET 
            BASE_ESPAIDER
            BASE_NAUNORTE
            BASE_NAUSUL
            BASE_NAUOMAN
            BASE_NAUPELOT
            BASE_PAM 
            BASE_VSC
            BASE_SAP
            BASE_MDM;
        
        IF MATRICULA NE '';
        MATRICULA_ORIGINAL = MATRICULA;
        MATRICULA = UPCASE(MATRICULA);

        /* Padronização de matrícula */
        if substr(MATRICULA, 1, 2) = 'C0' then 
            MATRICULA = MATRICULA;
        else if length(MATRICULA) > 6 then 
            MATRICULA = substr(MATRICULA, length(MATRICULA) - 5);
        else 
            MATRICULA = MATRICULA;

        /* Limpeza de nomes */
        if prxmatch('/^A[\-–—]/', USERFULLNAME) then 
            USERFULLNAME = substr(USERFULLNAME, 3);

        USERFULLNAME = compress(USERFULLNAME, , 'kw');
        USERFULLNAME = strip(upcase(USERFULLNAME));

        PRIMEIRO = scan(strip(USERFULLNAME), 1);

        /* Correção de caracteres corrompidos */
        PRIMEIRO = prxchange('s/Ã¡/A/i', -1, PRIMEIRO);
        PRIMEIRO = prxchange('s/Ã©/E/i', -1, PRIMEIRO);
        PRIMEIRO = prxchange('s/Ã­/I/i', -1, PRIMEIRO);
        PRIMEIRO = prxchange('s/Ã³/O/i', -1, PRIMEIRO);
        PRIMEIRO = prxchange('s/Ãº/U/i', -1, PRIMEIRO);

        /* Conversão para maiúsculas e remoção de acentos */
        PRIMEIRO = ktranslate(
                     upcase(PRIMEIRO),
                     'AAAAAACEEEEIIIINOOOOOUUUUY',
                     'ÁÀÂÃÄÅÇÉÈÊËÍÌÎÏÑÓÒÔÕÖÚÙÛÜÝ'
                   );
    RUN;

    /* Separação entre funcionários Vale e terceiros */
    proc sql;
        create table BASE_SYSTEMAS_TERCEIROS as
        select *,
               substr(MATRICULA_ORIGINAL, 1, length(MATRICULA_ORIGINAL) - 1) as MATRICULA_SEM_ULTIMO
        from BASE_SYSTEMAS
        where upcase(MATRICULA_ORIGINAL) like 'C0%'
           or upcase(USERFULLNAME) like '%CONTR%'
           or (EMAIL is not null and upcase(strip(EMAIL)) not like '%@VALE%')
           or (index(MATRICULA_ORIGINAL, '@') > 0 and upcase(MATRICULA_ORIGINAL) not like '%@VALE%');
    quit;

    proc sql;
        create table BASE_SYSTEMAS_VALE as
        select *,
               substr(MATRICULA_ORIGINAL, 1, length(MATRICULA_ORIGINAL) - 1) as MATRICULA_SEM_ULTIMO
        from BASE_SYSTEMAS
        where not (
            upcase(MATRICULA_ORIGINAL) like 'C0%'
            or upcase(USERFULLNAME) like '%CONTR%'
        )
        or index(upcase(MATRICULA_ORIGINAL), '@VALE') > 0;
    quit;
%mend consolidar_dados;

%consolidar_dados();

/* ============================================================================
   MÓDULO 7: VALIDAÇÃO E RELATÓRIO FINAL
   ============================================================================ */

%macro gerar_relatorio_final();
    /* Cálculo de datas para validação de usuários novos */
    %let data_inicio_mes_atual = %sysfunc(intnx(month, %sysfunc(today()), 0, b), date9.);
    %let data_fim_mes_atual    = %sysfunc(intnx(month, %sysfunc(today()), 0, e), date9.);

    /* Processamento final com regras de validação */
    data FINAL;
        retain 
            matricula 
            USERFULLNAME 
            SYSTEM
            STATUS_SISTEMA 
            STATUS_MDM 
            STATUS_SAILPOINT 
            STATUS_VALENET
            validacao
            NOME_MDM
            NOME_SAIL
            DATA_CONTRATACAO_MDM
            DATA_CONTRATACAO_NUM
            DATA_ULTIMO_LOGIN_DT
            DATA_CONTRATACAO_VSC
            data_convertida
            tipo
            re_contr 
            re_email;

        /* Inicialização das expressões regulares */
        if _N_ = 1 then do;
            re_contr = prxparse('/CONTR(_|\w)*$/i');
            re_email = prxparse('/VALE/');
        end;

        set FINAL_COM_NOMES2(rename=(
            STATUS_SISTEMA=OLD_STATUS_SISTEMA 
            STATUS_MDM=OLD_STATUS_MDM 
            STATUS_SAILPOINT=OLD_STATUS_SAILPOINT
        ));

        /* Formatação e inicialização de variáveis */
        format data_convertida date9.;
        data_convertida = datepart(DATA_CONTRATACAO_VSC);

        length 
            STATUS_SISTEMA STATUS_MDM STATUS_SAILPOINT validacao USERFULLNAME $30;

        STATUS_SISTEMA = strip(OLD_STATUS_SISTEMA);
        STATUS_MDM = strip(OLD_STATUS_MDM);
        STATUS_SAILPOINT = strip(OLD_STATUS_SAILPOINT);

        /* Preenchimento de campos em branco */
        if missing(STATUS_SISTEMA) or STATUS_SISTEMA = '' or STATUS_SISTEMA = '.' then 
            STATUS_SISTEMA = 'Nao Encontrado';
        if missing(STATUS_MDM) or STATUS_MDM = '' then 
            STATUS_MDM = 'Nao Encontrado';
        if missing(STATUS_SAILPOINT) or STATUS_SAILPOINT = '' then 
            STATUS_SAILPOINT = 'Nao Encontrado';
        if missing(STATUS_VALENET) or STATUS_VALENET = '' then 
            STATUS_VALENET = 'Nao Encontrado';

        /* ========== LÓGICA DE VALIDAÇÃO ========== */

        /* REGRA 0: Usuários técnicos específicos */
        if upcase(matricula) in (
            'S-AD-OBSASPNETUSER',
            'RETORNO_AUTO_CONTROLM_HOM',
            'S-ADSQLDB333',
            'S-AD_RPA_PASA1',
            'S-DB-IAM-INC',
            'S-PAM-PA-ADMSP',
            'S-RPA-CFG',
            'S-RPA-ETAG',
            'S-RPA-KM',
            'S-RPA-VSC1',
            'VALE-CM@ACCENTURE.COM',
            'S-SMELTERSEMTECH',
            '011',
            'AUTOMACAO_CONTROLM_HOM',
            'CTRLM_AUTO_PRD_IN',
            'CTRLM_AUTO_PRD_OUT',
            'SCCM',
            'PROC-PIMS-GEOTECNIA',
            'SECURITYCENTER.USER',
            'SITEMAP.SCHEDULER.USER',
            'USERBI',
            'INTERNAL.REQUEST_TO_CHANGE',
            'USERID',
            'INTEGRACAOSAP',
            'PROC-SAP-DADOS',
            'ADMIN',
            'MONITORING.BMPLANTSYSTEMSAPPS',
            'PROC470',
            'PROC143',
            'SNPROC',
            'SUPERVISOR',
            'LIMSMONITORING',
            'ELK_MONITORING',
            'SISTEMASGEOTECNIA',
            'SISTEL.USER',
            'MASTER',
            'APIMIGUSER',
            'S-PAM-SAS-2760001',
            'S-SCACHE',
            '1'
        ) then do;
            STATUS_SISTEMA = 'Chave de Sistema/Robo';
            STATUS_MDM = 'Chave de Sistema/Robo';
            STATUS_SAILPOINT = 'Chave de Sistema/Robo';
            validacao = 'OK';
        end;

        /* REGRA 1: Usuários técnicos por padrão */
        else if (
            upcase(matricula) =: 'R0' or 
            upcase(matricula) =: 'S-AD-' or 
            upcase(matricula) =: 'PROC-' or 
            upcase(matricula) =: 'HP' or
            upcase(matricula) =: 'ADMINISTRATIVO' or 
            index(upcase(matricula), 'INTEGRAT') > 0 or
            index(upcase(matricula), 'MONITORAMENTO') > 0 or
            index(upcase(matricula), 'IAM-') > 0 or
            ROBO = 1
        ) then do;
            STATUS_SISTEMA = 'Chave de Sistema/Robo';
            STATUS_MDM = 'Chave de Sistema/Robo';
            STATUS_SAILPOINT = 'Chave de Sistema/Robo';
            validacao = 'OK';
        end;

        /* REGRA 2: Nome em branco */
        else if strip(USERFULLNAME) = '' then do;
            STATUS_SISTEMA = 'Chave de Sistema/Robo';
            STATUS_MDM = 'Chave de Sistema/Robo';
            STATUS_SAILPOINT = 'Chave de Sistema/Robo';
            validacao = 'OK';
        end;

        /* REGRA 3: Funcionários Terceiros */
        else if (
            upcase(matricula) =: 'C0' or 
            prxmatch('/CONTR(_|\w)*$/i', upcase(strip(USERFULLNAME))) or 
            tipo = 'TERCEIRO'
        ) then do;
            STATUS_MDM = 'Funcionario Terceiro';
            
            /* Validação para usuários novos */
            if upcase(strip(STATUS_SAILPOINT)) = 'Nao Encontrado' then do;
                if (
                    (not missing(DATA_CONTRATACAO_NUM) and 
                     DATA_CONTRATACAO_NUM >= "&data_inicio_mes_atual"d and 
                     DATA_CONTRATACAO_NUM <= "&data_fim_mes_atual"d) or
                    (not missing(data_convertida) and 
                     data_convertida >= "&data_inicio_mes_atual"d and 
                     data_convertida <= "&data_fim_mes_atual"d)
                ) then do;
                    STATUS_SAILPOINT = 'status MDM';
                    validacao = 'OK';
                    STATUS_MDM = 'Usuario Novo Buscar prox MES';
                end;
                else do;
                    validacao = 'NOOK';
                end;
            end;
            /* Validação normal para terceiros */
            else if (STATUS_SISTEMA = 'I' and STATUS_VALENET = 'I' and STATUS_SAILPOINT = 'I') or
                    (STATUS_SISTEMA = 'A' and STATUS_VALENET = 'A' and STATUS_SAILPOINT = 'A') or
                    (STATUS_SISTEMA = 'I' and STATUS_VALENET = 'I' and STATUS_SAILPOINT = 'A') or 
                    (STATUS_SISTEMA = 'Nao Encontrado' and STATUS_VALENET = 'Nao Encontrado' and STATUS_SAILPOINT = 'I')then do;
                validacao = 'OK';
            end;
            else do;
                validacao = 'NOOK';
            end;
        end;

        /* REGRA 4: Casos normais */
        else do;
            /* Sub-regra 4.1: Funcionários Terceiros identificados pelo STATUS_MDM */
            if upcase(strip(STATUS_MDM)) = 'Funcionario Terceiro' then do;
                if (STATUS_SISTEMA = 'I' and STATUS_VALENET = 'I' and  STATUS_SAILPOINT = 'I') or
                   (STATUS_SISTEMA = 'A' and STATUS_VALENET = 'A' and STATUS_SAILPOINT = 'A') or
                   (STATUS_SISTEMA = 'I' and STATUS_VALENET = 'I' and STATUS_SAILPOINT = 'A') or
                   (STATUS_SISTEMA = 'Nao Encontrado' and STATUS_VALENET = 'Nao Encontrado' and STATUS_SAILPOINT = 'I')then do;
                    validacao = 'OK';
                end;
                else do;
                    validacao = 'NOOK';
                end;
            end;

            /* Sub-regra 4.2: STATUS_MDM não encontrado */
            else if upcase(strip(STATUS_MDM)) in ('Nao Encontrado', '') or missing(STATUS_MDM) then do;
                if upcase(strip(STATUS_SAILPOINT)) not in ('A', 'I') then do;
                    /* Verificar se é usuário novo */
                    if (
                        (not missing(DATA_CONTRATACAO_NUM) and 
                         DATA_CONTRATACAO_NUM >= "&data_inicio_mes_atual"d and 
                         DATA_CONTRATACAO_NUM <= "&data_fim_mes_atual"d) or
                        (not missing(data_convertida) and 
                         data_convertida >= "&data_inicio_mes_atual"d and 
                         data_convertida <= "&data_fim_mes_atual"d)
                    ) then do;
                        STATUS_SAILPOINT = 'status MDM';
                        validacao = 'OK';
                        STATUS_MDM = 'Usuario Novo Buscar prox MES';
                    end;
                    else do;
                        validacao = 'NOOK';
                    end;
                end;
                else do;
                    validacao = 'NOOK';
                end;
            end;

            /* Sub-regra 4.3: Validação normal */
            else do;
                if (STATUS_SISTEMA = 'I' and STATUS_VALENET = 'I' and STATUS_MDM = 'I') or
                   (STATUS_SISTEMA = 'A' and STATUS_VALENET = 'A' and STATUS_MDM = 'A') or
                   (STATUS_SISTEMA = 'I' and STATUS_VALENET = 'I' and STATUS_MDM = 'A') or
                   (STATUS_SISTEMA = 'Nao Encontrado' and STATUS_VALENET = 'Nao Encontrado' and STATUS_MDM = 'I') or
                   (STATUS_SISTEMA = 'I' and STATUS_VALENET = 'I' and STATUS_SAILPOINT = 'I') or
                   (STATUS_SISTEMA = 'I' and STATUS_VALENET = 'I' and STATUS_SAILPOINT = 'A') or
                   (STATUS_SISTEMA = 'Nao Encontrado' and STATUS_VALENET = 'Nao Encontrado' and STATUS_SAILPOINT = 'I') or
                   (STATUS_SISTEMA = 'A'  and STATUS_VALENET = 'A' and STATUS_SAILPOINT = 'A') then do;
                    validacao = 'OK';
                end;
                else do;
                    validacao = 'NOOK';
                end;
            end;
        end;

        /* Limpeza de variáveis temporárias */
        drop LAST_SUCCESSFUL_CONNECT STATUS tipo_usuario 
             OLD_STATUS_SISTEMA OLD_STATUS_MDM OLD_STATUS_SAILPOINT ROBO re_email re_contr;
    run;

    /* Padronização final dos dados */
    data FINAL2;
        length STATUS_SISTEMA_PAD STATUS_MDM_PAD STATUS_SAILPOINT_PAD $40 STATUS_VALENET_PAD $40
               VALIDACAO_PADRONIZADA $10
               SISTEMA_PADRONIZADO $40;
        set FINAL2;

        /* Padronização de STATUS */
        if STATUS_SISTEMA = "A" then STATUS_SISTEMA_PAD = "ATIVO";
        else if STATUS_SISTEMA = "I" then STATUS_SISTEMA_PAD = "INATIVO";
        else STATUS_SISTEMA_PAD = upcase(STATUS_SISTEMA);

        if STATUS_VALENET = "A" then STATUS_VALENET_PAD = "ATIVO";
        else if STATUS_VALENET = "I" then STATUS_VALENET_PAD = "INATIVO";
        else STATUS_VALENET_PAD = upcase(STATUS_VALENET);

        if STATUS_MDM = "A" then STATUS_MDM_PAD = "ATIVO";
        else if STATUS_MDM = "I" then STATUS_MDM_PAD = "INATIVO";
        else STATUS_MDM_PAD = upcase(STATUS_MDM);

        if STATUS_SAILPOINT = "A" then STATUS_SAILPOINT_PAD = "ATIVO";
        else if STATUS_SAILPOINT = "I" then STATUS_SAILPOINT_PAD = "INATIVO";
        else STATUS_SAILPOINT_PAD = upcase(STATUS_SAILPOINT);

        /* Padronização de VALIDAÇÃO */
        if VALIDACAO = "NOOK" then VALIDACAO_PADRONIZADA = "NOT OK";
        else VALIDACAO_PADRONIZADA = VALIDACAO;

        /* Padronização de SISTEMA */
        if SYSTEM = "PAM" then SISTEMA_PADRONIZADO = "PAM BEYONDTRUST";
        else SISTEMA_PADRONIZADO = SYSTEM;
    run;
%mend gerar_relatorio_final;

%gerar_relatorio_final();

/* ============================================================================
   MÓDULO 8: ATUALIZAÇÃO DE HISTÓRICO E DASHBOARD
   ============================================================================ */

/* Atualização da tabela de histórico */
%sql_libs(BD_ACDI);
proc append 
    base = BD_ACDI.DSS050409_HIST 
    data = FINAL2
    force;
run;

/* Promoção das tabelas para o dashboard */
filename DASH Clear;
filename DASH filesrvc folderpath="/TECH4ALL/ACDI/Auditoria/DSS05 - Lucas/Dashboard";
%include DASH ("promote_tables_DSS05.sas");

/* Restauração do log padrão */
proc printto;
run;

/* ============================================================================
   FIM DO PROGRAMA
   ============================================================================ */

