PGDMP     5    &                y            EBANK_TEST_SUITE    10.15    10.15 a   �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                       false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                       false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                       false            �           1262    16393    EBANK_TEST_SUITE    DATABASE     �   CREATE DATABASE "EBANK_TEST_SUITE" WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'Portuguese_Brazil.1252' LC_CTYPE = 'Portuguese_Brazil.1252';
 "   DROP DATABASE "EBANK_TEST_SUITE";
             postgres    false                        2615    16397 	   auditoria    SCHEMA        CREATE SCHEMA auditoria;
    DROP SCHEMA auditoria;
             postgres    false                        2615    2200    public    SCHEMA        CREATE SCHEMA public;
    DROP SCHEMA public;
             postgres    false            �           0    0    SCHEMA public    COMMENT     6   COMMENT ON SCHEMA public IS 'standard public schema';
                  postgres    false    3                        3079    12924    plpgsql 	   EXTENSION     ?   CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;
    DROP EXTENSION plpgsql;
                  false            �           0    0    EXTENSION plpgsql    COMMENT     @   COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';
                       false    1            �           1255    16398    before_favorecido()    FUNCTION     [  CREATE FUNCTION public.before_favorecido() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$

BEGIN

    if new.ativo and regexp_replace(regexp_replace(new.cnpj_cpf, '[^0-9]', '', 'g'), '^0+(?!$)', '') <> '0' then

		if (select count(*) from favorecido f where f.cnpj_cpf = new.cnpj_cpf and f.grupo_id = new.grupo_id and f.tipo_favorecido = new.tipo_favorecido and f.id <> new.id and f.ativo = true) > 0 then
		        RAISE EXCEPTION 'Cnpj/Cpf: % Grupo: % Tipo Favorecido: % já existe na base de dados', new.cnpj_cpf, new.grupo_id, new.tipo_favorecido;
		end if;

    end if;

    return new;
END;
$_$;
 *   DROP FUNCTION public.before_favorecido();
       public       postgres    false    3    1            �           1255    16399    before_favorecido_conta()    FUNCTION     1  CREATE FUNCTION public.before_favorecido_conta() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

    if new.principal then
  		if (select count(*) from favorecido_conta where favorecido_id = new.favorecido_id and ativo = true and principal = true and id <> new.id) > 0 then
  			RAISE EXCEPTION 'Favorecido so pode ter uma conta ativa e como principal';
  		end if;
    end if;

    if (select count(*) from favorecido_conta where favorecido_id = new.favorecido_id and banco_id = new.banco_id and agencia = new.agencia and conta = new.conta and dv_conta = new.dv_conta and id <> new.id) > 0 then
		  RAISE EXCEPTION 'Favorecido: % Banco: % Conta: % Agencia: % Conta DV: % já existe na base de dados', new.favorecido_id, new.banco_id, new.conta, new.agencia, new.dv_conta;
    end if;

    return new;
END;
$$;
 0   DROP FUNCTION public.before_favorecido_conta();
       public       postgres    false    1    3            �           1255    16400    before_lote_favorecido()    FUNCTION     X  CREATE FUNCTION public.before_lote_favorecido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  
BEGIN

if new.forma_pagamento_id is null then
	RAISE EXCEPTION 'Forma de Pagamento é obrigatório';
end if;

if new.favorecido_conta_id is null and new.chave_pix_id is null then
	RAISE EXCEPTION 'Conta é obrigatório';
end if;

if (select count(*) from favorecido_conta where id = new.favorecido_conta_id and favorecido_id = new.favorecido_id) = 0 and new.chave_pix_id is null then
	RAISE EXCEPTION 'Favorecido do lote favorecido, diferente do favorecido da conta';
end if;

    return new;
END;
$$;
 /   DROP FUNCTION public.before_lote_favorecido();
       public       postgres    false    3    1            �           1255    16401    create_matview(name, name)    FUNCTION     n  CREATE FUNCTION public.create_matview(name, name) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
 DECLARE
     matview ALIAS FOR $1;
     view_name ALIAS FOR $2;
     entry matviews%ROWTYPE;
 BEGIN
     SELECT * INTO entry FROM matviews WHERE mv_name = matview;
 
     IF FOUND THEN
         RAISE EXCEPTION 'Materialized view ''%'' already exists.',
           matview;
     END IF;
 
     EXECUTE 'REVOKE ALL ON ' || view_name || ' FROM PUBLIC'; 
 
     EXECUTE 'GRANT SELECT ON ' || view_name || ' TO PUBLIC';
 
     EXECUTE 'CREATE TABLE ' || matview || ' AS SELECT * FROM ' || view_name;
 
     EXECUTE 'REVOKE ALL ON ' || matview || ' FROM PUBLIC';
 
     EXECUTE 'GRANT SELECT ON ' || matview || ' TO PUBLIC';
 
     INSERT INTO matviews (mv_name, v_name, last_refresh)
       VALUES (matview, view_name, CURRENT_TIMESTAMP); 
     
     RETURN;
 END
 $_$;
 1   DROP FUNCTION public.create_matview(name, name);
       public       postgres    false    1    3            �           1255    16402    drop_matview(name)    FUNCTION     �  CREATE FUNCTION public.drop_matview(name) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
 DECLARE
     matview ALIAS FOR $1;
     entry matviews%ROWTYPE;
 BEGIN
 
     SELECT * INTO entry FROM matviews WHERE mv_name = matview;
 
     IF NOT FOUND THEN
         RAISE EXCEPTION 'Materialized view % does not exist.', matview;
     END IF;
 
     EXECUTE 'DROP TABLE ' || matview;
     DELETE FROM matviews WHERE mv_name=matview;
 
     RETURN;
 END
 $_$;
 )   DROP FUNCTION public.drop_matview(name);
       public       postgres    false    3    1            �           1255    16403 2   possui_empresas_vinculadas_mesmo_convenio(integer)    FUNCTION     i  CREATE FUNCTION public.possui_empresas_vinculadas_mesmo_convenio(grupo_empresa integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$ 
Declare resto int := 0; 
Begin 

 EXECUTE 'SELECT COUNT(Resto.*) FROM (  
	(SELECT count (ce) from convenio_empresa  ce
	INNER JOIN empresa emp ON emp.id  = ce.empresa_id
	INNER JOIN grupo_empresa ge ON ge.id = emp.grupo_empresa_id
	WHERE ge.id = '|| grupo_empresa ||')  
	EXCEPT 
	(SELECT count (conv) FROM convenio  conv 
	INNER JOIN empresa emp ON emp.id = conv.empresa_id
	INNER JOIN grupo_empresa ge ON ge.id = emp.grupo_empresa_id
	WHERE ge.id = '|| grupo_empresa ||') 
	UNION 
	(SELECT count (conv) FROM convenio  conv 
	INNER JOIN empresa emp ON emp.id = conv.empresa_id
	INNER JOIN grupo_empresa ge ON ge.id = emp.grupo_empresa_id
	WHERE ge.id = '|| grupo_empresa ||')  
	EXCEPT  
	(SELECT count (ce) from convenio_empresa  ce
	INNER JOIN empresa emp ON emp.id  = ce.empresa_id
	INNER JOIN grupo_empresa ge ON ge.id = emp.grupo_empresa_id
	WHERE ge.id = '|| grupo_empresa ||')) Resto' INTO resto; 
IF (resto= 1) 
    THEN RETURN TRUE; 
 ELSE 
    RETURN FALSE; 
 END IF; 

 End; 
$$;
 W   DROP FUNCTION public.possui_empresas_vinculadas_mesmo_convenio(grupo_empresa integer);
       public       postgres    false    1    3            �           1255    16404    refresh_matview(name)    FUNCTION     U  CREATE FUNCTION public.refresh_matview(name) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
 DECLARE 
     matview ALIAS FOR $1;
     entry matviews%ROWTYPE;
 BEGIN
 
     SELECT * INTO entry FROM matviews WHERE mv_name = matview;
 
     IF NOT FOUND THEN
         RAISE EXCEPTION 'Materialized view % does not exist.', matview;
    END IF;

    EXECUTE 'DELETE FROM ' || matview;
    EXECUTE 'INSERT INTO ' || matview
        || ' SELECT * FROM ' || entry.v_name;

    UPDATE matviews
        SET last_refresh=CURRENT_TIMESTAMP
        WHERE mv_name=matview;

    RETURN;
END
$_$;
 ,   DROP FUNCTION public.refresh_matview(name);
       public       postgres    false    3    1            �           1255    16405    remove_zeros_esquerda(text)    FUNCTION     �   CREATE FUNCTION public.remove_zeros_esquerda(text) RETURNS text
    LANGUAGE sql
    AS $_$
SELECT regexp_replace($1, '^0+(?!$)', '', 'g')
$_$;
 2   DROP FUNCTION public.remove_zeros_esquerda(text);
       public       postgres    false    3            �           1255    16406    sem_acentos(text)    FUNCTION     �   CREATE FUNCTION public.sem_acentos(text) RETURNS text
    LANGUAGE sql
    AS $_$
SELECT TRANSLATE($1, 'áéíóúàèìòùãõâêîôôäëïöüçÁÉÍÓÚÀÈÌÒÙÃÕÂÊÎÔÛÄËÏÖÜÇ', 'aeiouaeiouaoaeiooaeioucAEIOUAEIOUAOAEIOOAEIOUC')
$_$;
 (   DROP FUNCTION public.sem_acentos(text);
       public       postgres    false    3            �           1255    16407    somente_letra_e_numero(text)    FUNCTION     �   CREATE FUNCTION public.somente_letra_e_numero(text) RETURNS text
    LANGUAGE sql
    AS $_$
SELECT regexp_replace($1, '[^a-zA-Z0-9]', '', 'g')
$_$;
 3   DROP FUNCTION public.somente_letra_e_numero(text);
       public       postgres    false    3            �           1255    34833    somente_numero(text)    FUNCTION     �   CREATE FUNCTION public.somente_numero(text) RETURNS text
    LANGUAGE sql
    AS $_$
SELECT regexp_replace($1, '[^0-9]', '', 'g')
           $_$;
 +   DROP FUNCTION public.somente_numero(text);
       public       postgres    false    3            �           1255    16408    trg_titulo_retorno()    FUNCTION     �  CREATE FUNCTION public.trg_titulo_retorno() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

	if new.valor_pago is not null and new.data_ocorrencia is not null and new.cod_mov_ret = '06' then
		update titulo set valor_pago = new.valor_pago, data_pagamento = new.data_ocorrencia where id = new.titulo_id;
	end if;

	if new.data_ocorrencia is not null and new.cod_mov_ret = '09' then
		update titulo set data_ocorrencia = new.data_ocorrencia where id = new.titulo_id;
	end if;

	if new.data_ocorrencia is not null and new.cod_mov_ret = '25' then
		update titulo set data_ocorrencia = new.data_ocorrencia where id = new.titulo_id;
	end if;

    return new;
END;
$$;
 +   DROP FUNCTION public.trg_titulo_retorno();
       public       postgres    false    3    1            �            1259    16409    arquivo_aud    TABLE     �  CREATE TABLE auditoria.arquivo_aud (
    id bigint NOT NULL,
    rev bigint,
    revtype smallint,
    tipo_arquivo integer NOT NULL,
    nsa bigint NOT NULL,
    nome character varying NOT NULL,
    quantidade_lote integer,
    quantidade_pagamento integer,
    valor numeric NOT NULL,
    data_criacao timestamp without time zone NOT NULL,
    data_inicial date,
    data_final date,
    checksum character varying(255),
    data_hora_geracao_arquivo timestamp without time zone
);
 "   DROP TABLE auditoria.arquivo_aud;
    	   auditoria         postgres    false    8            �            1259    16415    arquivo_aud_id_seq    SEQUENCE     ~   CREATE SEQUENCE auditoria.arquivo_aud_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE auditoria.arquivo_aud_id_seq;
    	   auditoria       postgres    false    8    197            �           0    0    arquivo_aud_id_seq    SEQUENCE OWNED BY     O   ALTER SEQUENCE auditoria.arquivo_aud_id_seq OWNED BY auditoria.arquivo_aud.id;
         	   auditoria       postgres    false    198            �            1259    16417 	   categoria    TABLE     �   CREATE TABLE auditoria.categoria (
    id integer NOT NULL,
    descricao character varying(100) NOT NULL,
    url character varying(255) NOT NULL,
    menu_log_id bigint NOT NULL,
    ativo boolean DEFAULT true
);
     DROP TABLE auditoria.categoria;
    	   auditoria         postgres    false    8            �            1259    16421    categoria_id_seq    SEQUENCE     �   CREATE SEQUENCE auditoria.categoria_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE auditoria.categoria_id_seq;
    	   auditoria       postgres    false    199    8            �           0    0    categoria_id_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE auditoria.categoria_id_seq OWNED BY auditoria.categoria.id;
         	   auditoria       postgres    false    200            �            1259    16423    cliente_ftp_log_externo    TABLE     _  CREATE TABLE auditoria.cliente_ftp_log_externo (
    id bigint NOT NULL,
    empresa_id integer NOT NULL,
    diretorio_remoto_arquivo character varying NOT NULL,
    diretorio_origem_arquivo character varying NOT NULL,
    diretorio_upload character varying NOT NULL,
    diretorio_upload_final character varying NOT NULL,
    tipo_protocolo character varying NOT NULL,
    tipo_ftp_encryption character varying NOT NULL,
    tipo_transmissao_arquivo character varying NOT NULL,
    nome_arquivo text NOT NULL,
    mensagem text NOT NULL,
    data_log timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
 .   DROP TABLE auditoria.cliente_ftp_log_externo;
    	   auditoria         postgres    false    8            �            1259    16430    cliente_ftp_log_externo_id_seq    SEQUENCE     �   CREATE SEQUENCE auditoria.cliente_ftp_log_externo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 8   DROP SEQUENCE auditoria.cliente_ftp_log_externo_id_seq;
    	   auditoria       postgres    false    8    201            �           0    0    cliente_ftp_log_externo_id_seq    SEQUENCE OWNED BY     g   ALTER SEQUENCE auditoria.cliente_ftp_log_externo_id_seq OWNED BY auditoria.cliente_ftp_log_externo.id;
         	   auditoria       postgres    false    202            �           1259    36184    conta_pagar_aud    TABLE     I  CREATE TABLE auditoria.conta_pagar_aud (
    id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    conta_pagar_id bigint NOT NULL,
    tipo_conta_id bigint NOT NULL,
    favorecido_id bigint,
    nota_fiscal character varying NOT NULL,
    data_vencimento date NOT NULL,
    data_emissao date NOT NULL,
    valor numeric NOT NULL,
    status_conciliacao_anterior character varying NOT NULL,
    ocorrencia character varying NOT NULL,
    data_movimentacao timestamp without time zone NOT NULL,
    usuario_movimentacao_id bigint NOT NULL,
    categoria_auditoria integer NOT NULL
);
 &   DROP TABLE auditoria.conta_pagar_aud;
    	   auditoria         postgres    false    8            �           1259    36182    conta_pagar_aud_id_seq    SEQUENCE     �   CREATE SEQUENCE auditoria.conta_pagar_aud_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE auditoria.conta_pagar_aud_id_seq;
    	   auditoria       postgres    false    8    673            �           0    0    conta_pagar_aud_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE auditoria.conta_pagar_aud_id_seq OWNED BY auditoria.conta_pagar_aud.id;
         	   auditoria       postgres    false    672            �            1259    16432    controle_acesso    TABLE     �   CREATE TABLE auditoria.controle_acesso (
    id integer NOT NULL,
    data_acesso timestamp without time zone NOT NULL,
    usuario_id bigint NOT NULL,
    grupo_empresa_id bigint NOT NULL,
    sub_categoria_id bigint NOT NULL
);
 &   DROP TABLE auditoria.controle_acesso;
    	   auditoria         postgres    false    8            �            1259    16435    controle_acesso_id_seq    SEQUENCE     �   CREATE SEQUENCE auditoria.controle_acesso_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE auditoria.controle_acesso_id_seq;
    	   auditoria       postgres    false    203    8            �           0    0    controle_acesso_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE auditoria.controle_acesso_id_seq OWNED BY auditoria.controle_acesso.id;
         	   auditoria       postgres    false    204            �            1259    16437    empresa_aud    TABLE     �   CREATE TABLE auditoria.empresa_aud (
    id bigint NOT NULL,
    empresa_id bigint,
    acao character varying(50),
    data_acao timestamp without time zone NOT NULL,
    alteracoes character varying(1000),
    usuario_id bigint NOT NULL
);
 "   DROP TABLE auditoria.empresa_aud;
    	   auditoria         postgres    false    8            �            1259    16443    empresa_aud_id_seq    SEQUENCE     ~   CREATE SEQUENCE auditoria.empresa_aud_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE auditoria.empresa_aud_id_seq;
    	   auditoria       postgres    false    205    8            �           0    0    empresa_aud_id_seq    SEQUENCE OWNED BY     O   ALTER SEQUENCE auditoria.empresa_aud_id_seq OWNED BY auditoria.empresa_aud.id;
         	   auditoria       postgres    false    206            �            1259    16445    frequencia_recolhimento_aud    TABLE     �  CREATE TABLE auditoria.frequencia_recolhimento_aud (
    id bigint NOT NULL,
    rev bigint NOT NULL,
    revtype smallint,
    empresa_id bigint NOT NULL,
    loja_id integer NOT NULL,
    transportadora_id integer NOT NULL,
    ativo boolean DEFAULT false,
    tipofrequencia bigint,
    diassemana bigint[],
    datafixa bigint[],
    usuario_id integer,
    data_hora_criacao timestamp without time zone
);
 2   DROP TABLE auditoria.frequencia_recolhimento_aud;
    	   auditoria         postgres    false    8            �            1259    16452    grupo_empresa_log    TABLE       CREATE TABLE auditoria.grupo_empresa_log (
    id bigint NOT NULL,
    grupo_empresa_id bigint,
    descricao character varying(255),
    ativo boolean,
    acao character varying(50),
    data_acao timestamp without time zone NOT NULL,
    usuario_id bigint NOT NULL
);
 (   DROP TABLE auditoria.grupo_empresa_log;
    	   auditoria         postgres    false    8            �            1259    16455    grupo_empresa_log_id_seq    SEQUENCE     �   CREATE SEQUENCE auditoria.grupo_empresa_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE auditoria.grupo_empresa_log_id_seq;
    	   auditoria       postgres    false    8    208            �           0    0    grupo_empresa_log_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE auditoria.grupo_empresa_log_id_seq OWNED BY auditoria.grupo_empresa_log.id;
         	   auditoria       postgres    false    209            �            1259    16457    historico_usuario    TABLE     !  CREATE TABLE auditoria.historico_usuario (
    id bigint NOT NULL,
    usuario_id integer NOT NULL,
    ocorrencia character varying NOT NULL,
    categoria_auditoria integer NOT NULL,
    usuario_ocorrencia_id integer NOT NULL,
    data_ocorrencia timestamp without time zone NOT NULL
);
 (   DROP TABLE auditoria.historico_usuario;
    	   auditoria         postgres    false    8            �            1259    16463    historico_usuario_id_seq    SEQUENCE     �   CREATE SEQUENCE auditoria.historico_usuario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE auditoria.historico_usuario_id_seq;
    	   auditoria       postgres    false    210    8            �           0    0    historico_usuario_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE auditoria.historico_usuario_id_seq OWNED BY auditoria.historico_usuario.id;
         	   auditoria       postgres    false    211            �            1259    16465    log_arquivos_particionados    TABLE     #  CREATE TABLE auditoria.log_arquivos_particionados (
    id integer NOT NULL,
    nome_arquivo_original character varying NOT NULL,
    path_backup character varying NOT NULL,
    nome_arquivos_particionados character varying NOT NULL,
    data_backup timestamp without time zone NOT NULL
);
 1   DROP TABLE auditoria.log_arquivos_particionados;
    	   auditoria         postgres    false    8            �            1259    16471 !   log_arquivos_particionados_id_seq    SEQUENCE     �   CREATE SEQUENCE auditoria.log_arquivos_particionados_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE auditoria.log_arquivos_particionados_id_seq;
    	   auditoria       postgres    false    212    8            �           0    0 !   log_arquivos_particionados_id_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE auditoria.log_arquivos_particionados_id_seq OWNED BY auditoria.log_arquivos_particionados.id;
         	   auditoria       postgres    false    213            �            1259    16473    menu_log    TABLE     �   CREATE TABLE auditoria.menu_log (
    id integer NOT NULL,
    projeto integer NOT NULL,
    descricao character varying(80) NOT NULL,
    url character varying(255),
    ativo boolean DEFAULT true
);
    DROP TABLE auditoria.menu_log;
    	   auditoria         postgres    false    8            �            1259    16477    menu_log_id_seq    SEQUENCE     �   CREATE SEQUENCE auditoria.menu_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE auditoria.menu_log_id_seq;
    	   auditoria       postgres    false    214    8            �           0    0    menu_log_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE auditoria.menu_log_id_seq OWNED BY auditoria.menu_log.id;
         	   auditoria       postgres    false    215            �            1259    16479    sub_categoria    TABLE     �   CREATE TABLE auditoria.sub_categoria (
    id integer NOT NULL,
    descricao character varying(100) NOT NULL,
    url character varying(255) NOT NULL,
    categoria_id bigint NOT NULL,
    ativo boolean DEFAULT true
);
 $   DROP TABLE auditoria.sub_categoria;
    	   auditoria         postgres    false    8            �            1259    16483    sub_categoria_id_seq    SEQUENCE     �   CREATE SEQUENCE auditoria.sub_categoria_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE auditoria.sub_categoria_id_seq;
    	   auditoria       postgres    false    216    8            �           0    0    sub_categoria_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE auditoria.sub_categoria_id_seq OWNED BY auditoria.sub_categoria.id;
         	   auditoria       postgres    false    217            �            1259    16485    titulo_dda_aud    TABLE     I  CREATE TABLE auditoria.titulo_dda_aud (
    id bigint,
    rev bigint,
    revtype smallint,
    data_vencimento date,
    cod_desconto_1 integer,
    data_desconto_1 date,
    valor_desconto_1 numeric,
    cod_juros integer,
    juros_dia numeric,
    baixa_manual boolean,
    data_ocorrencia date,
    autenticacao_pagamento character varying,
    valor_pagamento numeric,
    local_pagamento character varying,
    usuario_alteracao_id bigint,
    data_alteracao date,
    valor_abatimento numeric,
    valor_alterado character varying,
    data_multa date,
    valor_multa numeric,
    nsa integer,
    banco_modificador bigint,
    tipo_inscricao_avalista integer,
    inscricao_avalista character varying,
    nome_avalista character varying,
    valor_titulo numeric,
    numero_documento_cobranca character varying(15),
    cod_desconto_2 integer,
    data_desconto_2 date,
    valor_desconto_2 numeric,
    cod_desconto_3 integer,
    data_desconto_3 date,
    valor_desconto_3 numeric,
    cod_multa integer,
    cod_protesto integer,
    numero_dias_protesto character varying(2),
    data_limite_pagamento date,
    status_conciliacao smallint,
    arquivo_id bigint,
    cod_movimento character varying,
    tipo_inscricao_cedente integer,
    inscricao_cedente character varying,
    nome_cedente character varying,
    status integer
);
 %   DROP TABLE auditoria.titulo_dda_aud;
    	   auditoria         postgres    false    8            �            1259    16491    acesso_conta_auxiliar    TABLE       CREATE TABLE public.acesso_conta_auxiliar (
    id bigint NOT NULL,
    controle_acesso_api_id bigint,
    conta_id bigint NOT NULL,
    conta_id_api character varying(255),
    limite_minimo_saldo numeric(15,2),
    atualizar_saldo_api boolean,
    percentual_minimo numeric(15,2)
);
 )   DROP TABLE public.acesso_conta_auxiliar;
       public         postgres    false    3            �            1259    16494    acesso_conta_auxiliar_id_seq    SEQUENCE     �   CREATE SEQUENCE public.acesso_conta_auxiliar_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.acesso_conta_auxiliar_id_seq;
       public       postgres    false    3            �            1259    16496 &   agendamento_descricao_categoria_global    TABLE     �   CREATE TABLE public.agendamento_descricao_categoria_global (
    id bigint NOT NULL,
    descricao_categoria_configuracao_id bigint,
    empresa_id bigint,
    agendado boolean,
    conta_id bigint
);
 :   DROP TABLE public.agendamento_descricao_categoria_global;
       public         postgres    false    3            �            1259    16499 -   agendamento_descricao_categoria_global_id_seq    SEQUENCE     �   CREATE SEQUENCE public.agendamento_descricao_categoria_global_id_seq
    START WITH 20
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 D   DROP SEQUENCE public.agendamento_descricao_categoria_global_id_seq;
       public       postgres    false    221    3            �           0    0 -   agendamento_descricao_categoria_global_id_seq    SEQUENCE OWNED BY        ALTER SEQUENCE public.agendamento_descricao_categoria_global_id_seq OWNED BY public.agendamento_descricao_categoria_global.id;
            public       postgres    false    222            �            1259    16501    aplicacao_processamento    TABLE     u  CREATE TABLE public.aplicacao_processamento (
    id bigint NOT NULL,
    desc_aplc character varying(60) NOT NULL,
    path character varying(60),
    periodo_rendimento integer NOT NULL,
    saldo_minimo double precision NOT NULL,
    taxa_rendimento double precision NOT NULL,
    taxa_retirada double precision NOT NULL,
    processamento_otimiza_id bigint NOT NULL
);
 +   DROP TABLE public.aplicacao_processamento;
       public         postgres    false    3            �            1259    16504    aplicacao_processamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.aplicacao_processamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 5   DROP SEQUENCE public.aplicacao_processamento_id_seq;
       public       postgres    false    3            �            1259    16506    arquivo_id_seq    SEQUENCE     w   CREATE SEQUENCE public.arquivo_id_seq
    START WITH 8
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE public.arquivo_id_seq;
       public       postgres    false    3            �            1259    16508    arquivo    TABLE     M  CREATE TABLE public.arquivo (
    id bigint DEFAULT nextval('public.arquivo_id_seq'::regclass) NOT NULL,
    tipo_arquivo integer NOT NULL,
    convenio_id bigint NOT NULL,
    nsa bigint NOT NULL,
    nome character varying NOT NULL,
    quantidade_lote integer,
    quantidade_pagamento integer,
    valor numeric NOT NULL,
    data_criacao timestamp without time zone NOT NULL,
    controle_upload_arquivo_id bigint,
    data_inicial date,
    data_final date,
    compromisso_id bigint,
    checksum character varying(255),
    data_hora_geracao_arquivo timestamp without time zone
);
    DROP TABLE public.arquivo;
       public         postgres    false    225    3            �            1259    16515    arrecadacao    TABLE     �  CREATE TABLE public.arrecadacao (
    id bigint NOT NULL,
    data date NOT NULL,
    tarifa double precision NOT NULL,
    valor double precision NOT NULL,
    banco_id bigint NOT NULL,
    forma_pagamento_arrecadacao_id bigint NOT NULL,
    convenio_id bigint,
    valor_liquido double precision NOT NULL,
    data_credito date,
    data_credito_calculada date,
    linha_processada bigint,
    arquivo_processado character varying(255),
    id_cliente character varying(255),
    empresa_id bigint
);
    DROP TABLE public.arrecadacao;
       public         postgres    false    3            �            1259    16521    arrecadacao_001    TABLE     �   CREATE TABLE public.arrecadacao_001 (
    CONSTRAINT arrecadacao_001_empresa_id_check CHECK ((empresa_id = 1))
)
INHERITS (public.arrecadacao);
ALTER TABLE ONLY public.arrecadacao_001 ALTER COLUMN empresa_id SET NOT NULL;
 #   DROP TABLE public.arrecadacao_001;
       public         postgres    false    3    227            �            1259    16528    arrecadacao_debito_automatico    TABLE     �  CREATE TABLE public.arrecadacao_debito_automatico (
    id bigint NOT NULL,
    data date NOT NULL,
    tarifa double precision NOT NULL,
    valor double precision NOT NULL,
    valor_liquido double precision NOT NULL,
    data_credito date,
    banco_id bigint NOT NULL,
    forma_pagamento_arrecadacao_id bigint NOT NULL,
    convenio_id bigint,
    agencia_debito character varying(4),
    conta_debito character varying(7),
    dv_conta_debito character varying(1),
    retorno_debito_id bigint,
    tipo_cliente character varying(1),
    cpf_cnpj character varying(15),
    arquivo_processado character varying(255),
    linha_processada bigint
);
 1   DROP TABLE public.arrecadacao_debito_automatico;
       public         postgres    false    3            �            1259    16531 $   arrecadacao_debito_automatico_id_seq    SEQUENCE     �   CREATE SEQUENCE public.arrecadacao_debito_automatico_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2061584294
    CACHE 1;
 ;   DROP SEQUENCE public.arrecadacao_debito_automatico_id_seq;
       public       postgres    false    3            �            1259    16533    arrecadacao_divergente_contrato    TABLE     �  CREATE TABLE public.arrecadacao_divergente_contrato (
    id bigint NOT NULL,
    data_arrecadacao date NOT NULL,
    valor numeric(13,2) NOT NULL,
    valor_liquido numeric(13,2) NOT NULL,
    tarifa_cobrada numeric(11,4) NOT NULL,
    tarifa_contratada numeric(11,4) NOT NULL,
    diferenca numeric(13,2) NOT NULL,
    empresa_id integer NOT NULL,
    contrato_arrecadadora_id bigint NOT NULL,
    chave_arrecadacao character varying(100) NOT NULL
);
 3   DROP TABLE public.arrecadacao_divergente_contrato;
       public         postgres    false    3            �            1259    16536 '   arrecadacao_divergente_contratoa_id_seq    SEQUENCE     �   CREATE SEQUENCE public.arrecadacao_divergente_contratoa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 >   DROP SEQUENCE public.arrecadacao_divergente_contratoa_id_seq;
       public       postgres    false    3            �            1259    16538    arrecadacao_id_seq    SEQUENCE     �   CREATE SEQUENCE public.arrecadacao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2061584294
    CACHE 1;
 )   DROP SEQUENCE public.arrecadacao_id_seq;
       public       postgres    false    3            �            1259    16540 	   auditoria    TABLE     �   CREATE TABLE public.auditoria (
    id bigint NOT NULL,
    usuario_id integer,
    data_ocorrencia timestamp without time zone NOT NULL,
    ocorrencia character varying NOT NULL,
    categoria integer NOT NULL,
    revision bigint
);
    DROP TABLE public.auditoria;
       public         postgres    false    3            �            1259    16546    auditoria_crud    TABLE     �   CREATE TABLE public.auditoria_crud (
    id bigint NOT NULL,
    "timestamp" timestamp without time zone,
    usuario_id bigint,
    grupo_empresa_id bigint,
    categoria integer
);
 "   DROP TABLE public.auditoria_crud;
       public         postgres    false    3            �            1259    16549    auditoria_crud_id_seq    SEQUENCE     ~   CREATE SEQUENCE public.auditoria_crud_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public.auditoria_crud_id_seq;
       public       postgres    false    3            �            1259    16551    auditoria_id_seq    SEQUENCE     y   CREATE SEQUENCE public.auditoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.auditoria_id_seq;
       public       postgres    false    3            �            1259    16553    auditoria_suite    TABLE     #  CREATE TABLE public.auditoria_suite (
    id bigint NOT NULL,
    usuario_id integer,
    data_ocorrencia timestamp without time zone NOT NULL,
    ocorrencia character varying(5000) NOT NULL,
    categoria integer NOT NULL,
    grupo_empresa_id integer,
    data_auditoria date NOT NULL
);
 #   DROP TABLE public.auditoria_suite;
       public         postgres    false    3            �            1259    16559    auditoria_suite_id_seq    SEQUENCE        CREATE SEQUENCE public.auditoria_suite_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.auditoria_suite_id_seq;
       public       postgres    false    3            �            1259    16561    autorizacao_dependencia    TABLE     �   CREATE TABLE public.autorizacao_dependencia (
    id integer NOT NULL,
    convenio_id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    ordem bigint NOT NULL
);
 +   DROP TABLE public.autorizacao_dependencia;
       public         postgres    false    3            �            1259    16564    autorizacao_dependencia_id_seq    SEQUENCE     �   CREATE SEQUENCE public.autorizacao_dependencia_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 5   DROP SEQUENCE public.autorizacao_dependencia_id_seq;
       public       postgres    false    3    240            �           0    0    autorizacao_dependencia_id_seq    SEQUENCE OWNED BY     a   ALTER SEQUENCE public.autorizacao_dependencia_id_seq OWNED BY public.autorizacao_dependencia.id;
            public       postgres    false    241            �            1259    16566    autorizacao_pag    TABLE     �   CREATE TABLE public.autorizacao_pag (
    id bigint NOT NULL,
    pagamento_id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    valor numeric,
    data_autorizacao date NOT NULL
);
 #   DROP TABLE public.autorizacao_pag;
       public         postgres    false    3            �            1259    16572    autorizacao_pag_id_seq    SEQUENCE        CREATE SEQUENCE public.autorizacao_pag_id_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.autorizacao_pag_id_seq;
       public       postgres    false    3            �            1259    16574    autorizacao_remessa    TABLE     �   CREATE TABLE public.autorizacao_remessa (
    id bigint NOT NULL,
    obrigatorio boolean NOT NULL,
    convenio_id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    valor_maximo numeric,
    valor_diario numeric,
    compromisso_id bigint
);
 '   DROP TABLE public.autorizacao_remessa;
       public         postgres    false    3            �            1259    16580    autorizacao_remessa_id_seq    SEQUENCE     �   CREATE SEQUENCE public.autorizacao_remessa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.autorizacao_remessa_id_seq;
       public       postgres    false    3            �            1259    16582 !   backup_grupo_pagamento_duplicados    TABLE     �   CREATE TABLE public.backup_grupo_pagamento_duplicados (
    pagamento_id bigint,
    data_pagamento date,
    valor numeric,
    tipo_servico_id bigint,
    tipo_grupo smallint,
    forma_pagamento_id bigint
);
 5   DROP TABLE public.backup_grupo_pagamento_duplicados;
       public         postgres    false    3            �            1259    16588    banco    TABLE     �   CREATE TABLE public.banco (
    id bigint NOT NULL,
    descricao character varying(250),
    cod_banco character varying(3) NOT NULL,
    ativo boolean NOT NULL,
    ispb integer
);
    DROP TABLE public.banco;
       public         postgres    false    3            �            1259    16591 	   banco_aud    TABLE     �   CREATE TABLE public.banco_aud (
    id bigint,
    rev bigint NOT NULL,
    revtype smallint,
    descricao character varying(250),
    cod_banco character varying(3),
    ativo boolean
);
    DROP TABLE public.banco_aud;
       public         postgres    false    3            �            1259    16594    banco_id_seq    SEQUENCE     u   CREATE SEQUENCE public.banco_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE public.banco_id_seq;
       public       postgres    false    3            �            1259    16596    banco_suportado_cobranca    TABLE     g   CREATE TABLE public.banco_suportado_cobranca (
    id bigint NOT NULL,
    banco_id bigint NOT NULL
);
 ,   DROP TABLE public.banco_suportado_cobranca;
       public         postgres    false    3            �            1259    16599    banco_suportado_cobranca_id_seq    SEQUENCE     �   CREATE SEQUENCE public.banco_suportado_cobranca_id_seq
    START WITH 8
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 6   DROP SEQUENCE public.banco_suportado_cobranca_id_seq;
       public       postgres    false    3            �            1259    16601    bkp_grupo_lancamento    TABLE     �  CREATE TABLE public.bkp_grupo_lancamento (
    id bigint,
    data date,
    conta_id bigint,
    categoria_lancamento_id bigint,
    tarifa_origem_id bigint,
    tipo_operacao_id bigint,
    qtd_lancamentos integer,
    franquia smallint,
    valor_unitario numeric,
    valor_total numeric,
    conciliado boolean,
    data_conciliacao timestamp without time zone,
    tipo_conciliacao smallint,
    usuario_id bigint,
    descricao character varying(100)
);
 (   DROP TABLE public.bkp_grupo_lancamento;
       public         postgres    false    3            �            1259    16607    boleto    TABLE     �  CREATE TABLE public.boleto (
    id bigint NOT NULL,
    valor_boleto numeric NOT NULL,
    data_vencimento date NOT NULL,
    linha_digitavel character varying NOT NULL,
    tipo_boleto integer NOT NULL,
    segmento integer,
    valor_desconto numeric,
    valor_multa numeric,
    valor_pagar numeric,
    forma_pagamento_id integer,
    banco_id bigint NOT NULL,
    cnpj_cpf_avalista_old character varying(18),
    cnpj_cpf_beneficiario_old character varying(18),
    descricao_avalista_old character varying(255),
    identificacao_contribuinte integer,
    identificador_contribuinte character varying(14),
    identificacao_fgts character varying(16),
    lacre_conectividade_social character varying(9),
    digito_lacre_conectividade_social character varying(2),
    codigo_barras character varying,
    empresa_pagadora_id bigint,
    tipo_beneficiario character varying(1),
    nome_beneficiario character varying,
    inscricao_beneficiario character varying(14),
    tipo_avalista character varying(1),
    nome_avalista character varying,
    inscricao_avalista character varying(14),
    pagamento_id bigint NOT NULL,
    remessa bigint,
    retorno bigint,
    status integer,
    ocorrencia character varying,
    autenticacao character varying,
    valor_efetivado numeric,
    data_efetivado date,
    seu_numero character varying,
    tipo_movimento integer,
    pagar boolean,
    valor_tarifa numeric,
    cod_identificacao_lote character varying,
    aviso character varying
);
    DROP TABLE public.boleto;
       public         postgres    false    3            �            1259    16613    boleto_id_seq    SEQUENCE     v   CREATE SEQUENCE public.boleto_id_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE public.boleto_id_seq;
       public       postgres    false    3            �            1259    16615    boleto_sem_pagamento    TABLE     H  CREATE TABLE public.boleto_sem_pagamento (
    id bigint,
    valor_boleto numeric,
    data_vencimento date,
    linha_digitavel character varying,
    tipo_boleto integer,
    segmento integer,
    valor_desconto numeric,
    valor_multa numeric,
    valor_pagar numeric,
    forma_pagamento_id integer,
    banco_id bigint,
    cnpj_cpf_avalista_old character varying(18),
    cnpj_cpf_beneficiario_old character varying(18),
    descricao_avalista_old character varying(255),
    identificacao_contribuinte integer,
    identificador_contribuinte character varying(14),
    identificacao_fgts character varying(16),
    lacre_conectividade_social character varying(9),
    digito_lacre_conectividade_social character varying(2),
    codigo_barras character varying,
    empresa_pagadora_id bigint,
    tipo_beneficiario character varying(1),
    nome_beneficiario character varying,
    inscricao_beneficiario character varying(14),
    tipo_avalista character varying(1),
    nome_avalista character varying,
    inscricao_avalista character varying(14),
    pagamento_id bigint,
    remessa bigint,
    retorno bigint,
    status integer,
    ocorrencia character varying,
    autenticacao character varying,
    valor_efetivado numeric,
    data_efetivado date,
    seu_numero character varying,
    tipo_movimento integer,
    pagar boolean
);
 (   DROP TABLE public.boleto_sem_pagamento;
       public         postgres    false    3                        1259    16621    card_id_seq    SEQUENCE     t   CREATE SEQUENCE public.card_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 "   DROP SEQUENCE public.card_id_seq;
       public       postgres    false    3                       1259    16623    card    TABLE     }  CREATE TABLE public.card (
    id bigint DEFAULT nextval('public.card_id_seq'::regclass) NOT NULL,
    tipo_card_aviso bigint NOT NULL,
    valor numeric(13,2),
    quantidade bigint,
    grupo_empresa_id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    conta_id bigint,
    data_ultima_atualizacao date NOT NULL,
    hora_ultima_atualizacao time without time zone NOT NULL
);
    DROP TABLE public.card;
       public         postgres    false    256    3                       1259    16627    carteira_cobranca    TABLE     �   CREATE TABLE public.carteira_cobranca (
    id bigint NOT NULL,
    banco_id bigint NOT NULL,
    tipo_modalidade integer NOT NULL,
    descricao character varying(255) NOT NULL,
    codigo character varying(10),
    numero character varying(10)
);
 %   DROP TABLE public.carteira_cobranca;
       public         postgres    false    3                       1259    16630    carteira_cobranca_id_seq    SEQUENCE     �   CREATE SEQUENCE public.carteira_cobranca_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.carteira_cobranca_id_seq;
       public       postgres    false    3                       1259    16632    categoria_lancamento    TABLE     e  CREATE TABLE public.categoria_lancamento (
    id integer NOT NULL,
    descricao character varying(255) NOT NULL,
    concilia boolean NOT NULL,
    data_inclusao timestamp without time zone NOT NULL,
    tipo_conciliacao integer,
    banco_id bigint NOT NULL,
    tipo integer,
    codigo character varying(30),
    tipo_categoria_lancamento_id bigint
);
 (   DROP TABLE public.categoria_lancamento;
       public         postgres    false    3                       1259    16635    categoria_lancamento_new    TABLE     �  CREATE TABLE public.categoria_lancamento_new (
    id integer NOT NULL,
    descricao character varying(255) NOT NULL,
    concilia boolean NOT NULL,
    data_inclusao timestamp without time zone NOT NULL,
    tipo_conciliacao integer,
    banco_id bigint NOT NULL,
    tipo integer,
    codigo character varying(30),
    tipo_categoria_lancamento_id bigint,
    empresa_id integer
);
 ,   DROP TABLE public.categoria_lancamento_new;
       public         postgres    false    3                       1259    16638    categoria_lancamentos_id_seq    SEQUENCE     �   CREATE SEQUENCE public.categoria_lancamentos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.categoria_lancamentos_id_seq;
       public       postgres    false    3                       1259    16640     categoria_lancamentos_new_id_seq    SEQUENCE     �   CREATE SEQUENCE public.categoria_lancamentos_new_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.categoria_lancamentos_new_id_seq;
       public       postgres    false    3                       1259    16642    chave_pix_id_seq    SEQUENCE     z   CREATE SEQUENCE public.chave_pix_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.chave_pix_id_seq;
       public       postgres    false    3            	           1259    16644 	   chave_pix    TABLE     W  CREATE TABLE public.chave_pix (
    id bigint DEFAULT nextval('public.chave_pix_id_seq'::regclass) NOT NULL,
    favorecido_id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    grupo_id bigint NOT NULL,
    chave character varying NOT NULL,
    tipo integer NOT NULL,
    ativo boolean DEFAULT false,
    principal boolean DEFAULT false
);
    DROP TABLE public.chave_pix;
       public         postgres    false    264    3            
           1259    16653    cheque    TABLE     �  CREATE TABLE public.cheque (
    id bigint NOT NULL,
    valor numeric(13,2) NOT NULL,
    numerocheque character varying(34) NOT NULL,
    conta_id bigint NOT NULL,
    data_emissao date NOT NULL,
    favorecido_id bigint,
    observacao character varying(300),
    statuscheque integer NOT NULL,
    data_processamento date,
    lancamento_id bigint,
    favorecido_id_old bigint
);
ALTER TABLE ONLY public.cheque ALTER COLUMN id SET STATISTICS 0;
    DROP TABLE public.cheque;
       public         postgres    false    3                       1259    16656    cheque_id_seq    SEQUENCE     ~   CREATE SEQUENCE public.cheque_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 $   DROP SEQUENCE public.cheque_id_seq;
       public       postgres    false    3                       1259    16658    cidade    TABLE     w   CREATE TABLE public.cidade (
    id bigint NOT NULL,
    descricao character varying,
    estado_id bigint NOT NULL
);
    DROP TABLE public.cidade;
       public         postgres    false    3                       1259    16664    cidade_id_seq    SEQUENCE     v   CREATE SEQUENCE public.cidade_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE public.cidade_id_seq;
       public       postgres    false    3                       1259    16666    cliente_ftp    TABLE     �  CREATE TABLE public.cliente_ftp (
    id integer NOT NULL,
    empresa_id integer NOT NULL,
    usuario character varying(100) NOT NULL,
    senha character varying(100) NOT NULL,
    host character varying(100) NOT NULL,
    porta integer NOT NULL,
    diretorio_origem character varying(100) NOT NULL,
    diretorio_destino character varying(100) NOT NULL,
    tipo_transmissao_arquivo integer NOT NULL,
    tipo_protocolo integer NOT NULL,
    tipo_ftp_encryption integer NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    descricao character varying(100),
    formato_nome_arquivo character varying(100),
    extensao_arquivo integer
);
    DROP TABLE public.cliente_ftp;
       public         postgres    false    3                       1259    16673    cliente_ftp_id_seq    SEQUENCE     �   CREATE SEQUENCE public.cliente_ftp_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.cliente_ftp_id_seq;
       public       postgres    false    270    3            �           0    0    cliente_ftp_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.cliente_ftp_id_seq OWNED BY public.cliente_ftp.id;
            public       postgres    false    271                       1259    16675    cliente_ftp_log    TABLE     j  CREATE TABLE public.cliente_ftp_log (
    id integer NOT NULL,
    cliente_ftp_id integer,
    data_transmissao timestamp without time zone NOT NULL,
    nome_arquivos text,
    erro text,
    observacao character varying(500),
    transmissao_sucesso boolean NOT NULL,
    tratado boolean DEFAULT false NOT NULL,
    resolvido boolean DEFAULT false NOT NULL
);
 #   DROP TABLE public.cliente_ftp_log;
       public         postgres    false    3                       1259    16683    cliente_ftp_log_id_seq    SEQUENCE     �   CREATE SEQUENCE public.cliente_ftp_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.cliente_ftp_log_id_seq;
       public       postgres    false    272    3            �           0    0    cliente_ftp_log_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public.cliente_ftp_log_id_seq OWNED BY public.cliente_ftp_log.id;
            public       postgres    false    273                       1259    16685 
   clientsftp    TABLE     V  CREATE TABLE public.clientsftp (
    id bigint NOT NULL,
    ativo boolean NOT NULL,
    host character varying(40) NOT NULL,
    password character varying(30) NOT NULL,
    porta character varying(7) NOT NULL,
    remotedirectory character varying(50) NOT NULL,
    usuario character varying(30) NOT NULL,
    empresa_id bigint NOT NULL
);
    DROP TABLE public.clientsftp;
       public         postgres    false    3                       1259    16688    clientsftp_id_seq    SEQUENCE     z   CREATE SEQUENCE public.clientsftp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.clientsftp_id_seq;
       public       postgres    false    3                       1259    16690    cobranca_instrucao    TABLE     �  CREATE TABLE public.cobranca_instrucao (
    id bigint NOT NULL,
    desc_perc_um numeric(11,4),
    desc_praz_um integer,
    desc_perc_dois numeric(11,4),
    desc_praz_dois integer,
    desc_perc_tres numeric(11,4),
    desc_praz_tres integer,
    juros_banco boolean,
    juros_perc numeric(11,4),
    multa_perc numeric(11,4),
    multa_dias integer,
    tipo_prazo integer,
    prazo_devolucao integer,
    prazo_protesto integer,
    instrucao_um character varying(25),
    instrucao_dois character varying(25),
    instrucao_tres character varying(25),
    instrucao_quatro character varying(25),
    cobranca_parametro_id bigint NOT NULL
);
 &   DROP TABLE public.cobranca_instrucao;
       public         postgres    false    3                       1259    16693    cobranca_instrucao_id_seq    SEQUENCE     �   CREATE SEQUENCE public.cobranca_instrucao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.cobranca_instrucao_id_seq;
       public       postgres    false    3                       1259    16695    cobranca_parametro    TABLE     >  CREATE TABLE public.cobranca_parametro (
    id bigint NOT NULL,
    numero_remessa integer NOT NULL,
    seu_numero character varying(20) NOT NULL,
    nosso_numero bigint NOT NULL,
    tipo_titulo integer NOT NULL,
    tipo_moeda integer NOT NULL,
    tipo_forma_entrega integer NOT NULL,
    cidade_id bigint,
    estado_id bigint,
    convenio_id bigint NOT NULL,
    layout_cobranca integer NOT NULL,
    carteira_cobranca_id bigint NOT NULL,
    tipo_seu_numero integer NOT NULL,
    apelido character varying(12),
    rateio_credito boolean DEFAULT false NOT NULL
);
 &   DROP TABLE public.cobranca_parametro;
       public         postgres    false    3                       1259    16699    cobranca_parametro_id_seq    SEQUENCE     �   CREATE SEQUENCE public.cobranca_parametro_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.cobranca_parametro_id_seq;
       public       postgres    false    3                       1259    16701    codigo_receita    TABLE     �   CREATE TABLE public.codigo_receita (
    id bigint NOT NULL,
    descricao character varying NOT NULL,
    codigo character varying(4) NOT NULL,
    tipo_codigo_receita character varying
);
 "   DROP TABLE public.codigo_receita;
       public         postgres    false    3                       1259    16707    codigo_receita_id_seq    SEQUENCE     �   CREATE SEQUENCE public.codigo_receita_id_seq
    START WITH 279131
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 ,   DROP SEQUENCE public.codigo_receita_id_seq;
       public       postgres    false    3                       1259    16709    compromisso    TABLE     �  CREATE TABLE public.compromisso (
    id bigint NOT NULL,
    codigo_compromisso character varying(4) NOT NULL,
    parametro_transmissao character varying(2) NOT NULL,
    convenio_id bigint NOT NULL,
    tipo_compromisso_id bigint NOT NULL,
    layout integer,
    empresa_id bigint,
    path character varying(120),
    apelido character varying(20),
    automatico boolean DEFAULT false,
    remessa bigint
);
    DROP TABLE public.compromisso;
       public         postgres    false    3                       1259    16713    compromisso_seq    SEQUENCE     y   CREATE SEQUENCE public.compromisso_seq
    START WITH 29
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE public.compromisso_seq;
       public       postgres    false    3            �           1259    35337    conciliacao_cash    TABLE     q  CREATE TABLE public.conciliacao_cash (
    id bigint NOT NULL,
    faturamento_id bigint NOT NULL,
    loja_id bigint NOT NULL,
    chave_lancamento character varying,
    valor_faturamento numeric NOT NULL,
    saldo_cofre numeric NOT NULL,
    data_faturamento date NOT NULL,
    coleta_carro_forte numeric,
    ajuste_coleta_deposito numeric,
    diferenca_deposito numeric,
    resolvido boolean,
    status_conciliacao integer DEFAULT 0 NOT NULL,
    usuario_id bigint NOT NULL,
    motivo_diferenca character varying,
    falha_recolhimento boolean,
    data_conciliacao date,
    lancamento_auxiliar_cash_id bigint
);
 $   DROP TABLE public.conciliacao_cash;
       public         postgres    false    3            �           1259    35335    conciliacao_cash_id_seq    SEQUENCE     �   CREATE SEQUENCE public.conciliacao_cash_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.conciliacao_cash_id_seq;
       public       postgres    false    3    665            �           0    0    conciliacao_cash_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.conciliacao_cash_id_seq OWNED BY public.conciliacao_cash.id;
            public       postgres    false    664                       1259    16715    conciliacao_cobranca    TABLE     �   CREATE TABLE public.conciliacao_cobranca (
    grupo_titulo_id bigint NOT NULL,
    chave_lancamento character varying(120) NOT NULL
);
 (   DROP TABLE public.conciliacao_cobranca;
       public         postgres    false    3                       1259    16718    conciliacao_financeira    TABLE     2  CREATE TABLE public.conciliacao_financeira (
    id bigint NOT NULL,
    conciliado boolean,
    data_liquidacao date,
    chave_conciliacao character varying NOT NULL,
    convenio_id bigint NOT NULL,
    usuario_id bigint,
    valor numeric,
    tipo_transacao integer,
    data_conciliacao date,
    chave_lancamento character varying,
    origem_conciliacao integer,
    descricao character varying(255) NOT NULL,
    data_liquidacao_original date,
    data_credito date NOT NULL,
    ocorrencia_cobranca_id bigint,
    tipo_conciliacao_financeira bigint
);
 *   DROP TABLE public.conciliacao_financeira;
       public         postgres    false    3                       1259    16724 &   conciliacao_financeira_aux_lanc_id_seq    SEQUENCE     �   CREATE SEQUENCE public.conciliacao_financeira_aux_lanc_id_seq
    START WITH 9
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 =   DROP SEQUENCE public.conciliacao_financeira_aux_lanc_id_seq;
       public       postgres    false    3                       1259    16726 %   conciliacao_financeira_aux_tit_id_seq    SEQUENCE     �   CREATE SEQUENCE public.conciliacao_financeira_aux_tit_id_seq
    START WITH 9
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 <   DROP SEQUENCE public.conciliacao_financeira_aux_tit_id_seq;
       public       postgres    false    3                        1259    16728 *   conciliacao_financeira_auxiliar_lancamento    TABLE       CREATE TABLE public.conciliacao_financeira_auxiliar_lancamento (
    id bigint DEFAULT nextval('public.conciliacao_financeira_aux_lanc_id_seq'::regclass) NOT NULL,
    chave_lancamento character varying,
    conciliacao_financeira_id bigint NOT NULL,
    conciliado boolean
);
 >   DROP TABLE public.conciliacao_financeira_auxiliar_lancamento;
       public         postgres    false    286    3            !           1259    16735 &   conciliacao_financeira_auxiliar_titulo    TABLE       CREATE TABLE public.conciliacao_financeira_auxiliar_titulo (
    id bigint DEFAULT nextval('public.conciliacao_financeira_aux_tit_id_seq'::regclass) NOT NULL,
    titulo_id bigint NOT NULL,
    conciliacao_financeira_id bigint NOT NULL,
    conciliado boolean
);
 :   DROP TABLE public.conciliacao_financeira_auxiliar_titulo;
       public         postgres    false    287    3            "           1259    16739    conciliacao_financeira_id_seq    SEQUENCE     �   CREATE SEQUENCE public.conciliacao_financeira_id_seq
    START WITH 1206
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 4   DROP SEQUENCE public.conciliacao_financeira_id_seq;
       public       postgres    false    3            #           1259    16741    conciliacao_lancamento    TABLE     �   CREATE TABLE public.conciliacao_lancamento (
    grupo_lancamento_id bigint NOT NULL,
    chave_lancamento character varying(120) NOT NULL
);
 *   DROP TABLE public.conciliacao_lancamento;
       public         postgres    false    3            $           1259    16744    conciliacao_numerario    TABLE        CREATE TABLE public.conciliacao_numerario (
    grupo_numerario_id integer,
    chave_lancamento character varying NOT NULL
);
 )   DROP TABLE public.conciliacao_numerario;
       public         postgres    false    3            %           1259    16750    conciliacao_pagamento    TABLE     �   CREATE TABLE public.conciliacao_pagamento (
    grupo_pagamento_id bigint NOT NULL,
    chave_lancamento character varying(120) NOT NULL
);
 )   DROP TABLE public.conciliacao_pagamento;
       public         postgres    false    3            &           1259    16753    configuracao_sistema    TABLE     H  CREATE TABLE public.configuracao_sistema (
    id bigint NOT NULL,
    arquivolog character varying(140) NOT NULL,
    diretoriofalha character varying(140) NOT NULL,
    diretorioleitura character varying(140) NOT NULL,
    diretoriosucesso character varying(140) NOT NULL,
    diretoriotemp character varying(140) NOT NULL
);
 (   DROP TABLE public.configuracao_sistema;
       public         postgres    false    3            '           1259    16759    configuracao_sistema_id_seq    SEQUENCE     �   CREATE SEQUENCE public.configuracao_sistema_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.configuracao_sistema_id_seq;
       public       postgres    false    3            (           1259    16761    conta    TABLE     �  CREATE TABLE public.conta (
    id bigint NOT NULL,
    agencia character varying(20),
    conta character varying(20),
    dv_conta character varying(1),
    dv_agencia character varying(1),
    banco_id bigint NOT NULL,
    convenio_cartao boolean,
    empresa_id bigint NOT NULL,
    operacao character varying(3),
    tiposaldo integer,
    tipoconta bigint,
    justificar_pagamento boolean,
    ativo boolean DEFAULT true NOT NULL
);
    DROP TABLE public.conta;
       public         postgres    false    3            �           0    0    COLUMN conta.tiposaldo    COMMENT     o   COMMENT ON COLUMN public.conta.tiposaldo IS '0: MENSAL - 1: QUINZENAL - 2: SEMANAL - 3: DIARIO - 4: INTRADIA';
            public       postgres    false    296            �           0    0    COLUMN conta.tipoconta    COMMENT     k   COMMENT ON COLUMN public.conta.tipoconta IS '0: CALCAO - 1: INVESTIMENTO - 2: MOVIMENTACAO - 3: POUPANCA';
            public       postgres    false    296            )           1259    16765    conta_id_seq    SEQUENCE     }   CREATE SEQUENCE public.conta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 #   DROP SEQUENCE public.conta_id_seq;
       public       postgres    false    3            *           1259    16767    conta_lancamento    TABLE     {   CREATE TABLE public.conta_lancamento (
    id bigint NOT NULL,
    descricao character varying(30),
    conta_id bigint
);
 $   DROP TABLE public.conta_lancamento;
       public         postgres    false    3            +           1259    16770    conta_lancamento_fluxo_caixa    TABLE     �   CREATE TABLE public.conta_lancamento_fluxo_caixa (
    id bigint NOT NULL,
    descricao character varying(30),
    conta_id bigint
);
 0   DROP TABLE public.conta_lancamento_fluxo_caixa;
       public         postgres    false    3            ,           1259    16773 #   conta_lancamento_fluxo_caixa_id_seq    SEQUENCE     �   CREATE SEQUENCE public.conta_lancamento_fluxo_caixa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 :   DROP SEQUENCE public.conta_lancamento_fluxo_caixa_id_seq;
       public       postgres    false    3            -           1259    16775    conta_lancamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.conta_lancamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.conta_lancamento_id_seq;
       public       postgres    false    3            .           1259    16777    conta_pagar    TABLE     �  CREATE TABLE public.conta_pagar (
    id integer NOT NULL,
    favorecido_id bigint NOT NULL,
    codigo_conta character varying(255) NOT NULL,
    nota_fiscal character varying NOT NULL,
    valor numeric NOT NULL,
    data_emissao date NOT NULL,
    data_pagamento date,
    data_vencimento date NOT NULL,
    valor_desconto numeric DEFAULT 0,
    valor_abatimento numeric DEFAULT 0,
    juros numeric DEFAULT 0,
    valor_multa numeric DEFAULT 0,
    parcela numeric NOT NULL,
    chave_acesso character varying(50),
    tipo_conta_id bigint,
    conciliado_nf boolean DEFAULT false,
    status_conciliacao_dda integer DEFAULT 0,
    titulo_dda_id bigint,
    empresa_id bigint NOT NULL,
    valor_pago numeric,
    convenio_id bigint,
    usuario_conciliou_id bigint,
    data_conciliacao timestamp without time zone,
    tipo_divergencia smallint,
    lote_favorecido_id bigint,
    data_processamento timestamp without time zone,
    controle_upload_arquivo_id bigint
);
    DROP TABLE public.conta_pagar;
       public         postgres    false    3            /           1259    16789    conta_pagar_id_seq    SEQUENCE     �   CREATE SEQUENCE public.conta_pagar_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.conta_pagar_id_seq;
       public       postgres    false    3    302            �           0    0    conta_pagar_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.conta_pagar_id_seq OWNED BY public.conta_pagar.id;
            public       postgres    false    303            0           1259    16791    conta_pagar_log    TABLE       CREATE TABLE public.conta_pagar_log (
    id bigint NOT NULL,
    controle_upload_arquivo_id integer NOT NULL,
    descricao character varying NOT NULL,
    linha_processada integer NOT NULL,
    data_processamento timestamp without time zone NOT NULL,
    conta_pagar_id integer
);
 #   DROP TABLE public.conta_pagar_log;
       public         postgres    false    3            1           1259    16797    conta_pagar_log_id_seq    SEQUENCE        CREATE SEQUENCE public.conta_pagar_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.conta_pagar_log_id_seq;
       public       postgres    false    3    304            �           0    0    conta_pagar_log_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public.conta_pagar_log_id_seq OWNED BY public.conta_pagar_log.id;
            public       postgres    false    305            2           1259    16799    contrato_id_seq    SEQUENCE     y   CREATE SEQUENCE public.contrato_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE public.contrato_id_seq;
       public       postgres    false    3            3           1259    16801    contrato    TABLE     "  CREATE TABLE public.contrato (
    id bigint DEFAULT nextval('public.contrato_id_seq'::regclass) NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    data_inicio date NOT NULL,
    data_fim date NOT NULL,
    banco_id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    convenio_id bigint,
    conta_id bigint NOT NULL,
    compromisso_id bigint,
    tipo_servico_id bigint,
    float_padrao integer,
    float_negociado integer,
    float_tarifa integer,
    tipo_contrato smallint NOT NULL,
    modalidade smallint,
    float_credito numeric,
    forma_tarifacao smallint,
    reprocessar boolean DEFAULT false NOT NULL,
    tarifa_contra_cheque numeric,
    emite_contra_cheque boolean,
    transportadora_id bigint,
    coleta_diaria_por_loja smallint,
    custo_recolhimento integer,
    malote boolean DEFAULT false,
    cofre_inteligente boolean DEFAULT false,
    float_cofre_inteligente integer,
    horario_de_corte time without time zone,
    tipo_conciliacao_cash boolean DEFAULT false,
    tipo_conciliacao_numerario boolean DEFAULT false
);
    DROP TABLE public.contrato;
       public         postgres    false    306    3            4           1259    16812    contrato_arrecadadora    TABLE     �  CREATE TABLE public.contrato_arrecadadora (
    id bigint NOT NULL,
    data_fim timestamp without time zone,
    data_inicio timestamp without time zone,
    descricao character varying(128) NOT NULL,
    percentual boolean,
    tarifa double precision NOT NULL,
    banco_id bigint NOT NULL,
    forma_pagamento_arrecadacao_id bigint NOT NULL,
    ativo boolean,
    empresa_id bigint NOT NULL
);
 )   DROP TABLE public.contrato_arrecadadora;
       public         postgres    false    3            5           1259    16815    contrato_arrecadadora_id_seq    SEQUENCE     �   CREATE SEQUENCE public.contrato_arrecadadora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.contrato_arrecadadora_id_seq;
       public       postgres    false    3            6           1259    16817    contrato_bancario    TABLE     �  CREATE TABLE public.contrato_bancario (
    id bigint NOT NULL,
    banco_id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    conta_id bigint NOT NULL,
    data_inicio date NOT NULL,
    data_fim date NOT NULL,
    tipo_contrato_bancario_id bigint NOT NULL,
    modalidade_contrato_bancario_id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    data_inclusao timestamp(0) without time zone NOT NULL,
    descricao character varying(50) NOT NULL
);
 %   DROP TABLE public.contrato_bancario;
       public         postgres    false    3            7           1259    16820    contrato_bancario_id_seq    SEQUENCE     �   CREATE SEQUENCE public.contrato_bancario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 /   DROP SEQUENCE public.contrato_bancario_id_seq;
       public       postgres    false    3            8           1259    16822    contrato_loja    TABLE     d   CREATE TABLE public.contrato_loja (
    contrato_id bigint NOT NULL,
    loja_id bigint NOT NULL
);
 !   DROP TABLE public.contrato_loja;
       public         postgres    false    3            9           1259    16825    controle_acesso_api    TABLE     j  CREATE TABLE public.controle_acesso_api (
    id bigint NOT NULL,
    usuario character varying(255),
    senha character varying(255),
    secret_key character varying(255),
    client_id character varying(255),
    empresa_id bigint NOT NULL,
    grupo_empresa_id bigint NOT NULL,
    acess_token character varying(500),
    data_acess_token date,
    hora_acess_token time without time zone,
    refresh_token character varying(255),
    data_refresh_token date,
    hora_refresh_token time without time zone,
    tempo_expiracao_acess_token integer,
    tempo_expiracao_refresh_token integer,
    ativo boolean
);
 '   DROP TABLE public.controle_acesso_api;
       public         postgres    false    3            :           1259    16831    controle_acesso_api_id_seq    SEQUENCE     �   CREATE SEQUENCE public.controle_acesso_api_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.controle_acesso_api_id_seq;
       public       postgres    false    3            ;           1259    16833    controle_bloqueio_usuario    TABLE     �   CREATE TABLE public.controle_bloqueio_usuario (
    id bigint NOT NULL,
    usuario_id integer NOT NULL,
    tentativa integer NOT NULL,
    data_bloqueio timestamp without time zone NOT NULL,
    bloqueado boolean NOT NULL,
    login_sucesso boolean
);
 -   DROP TABLE public.controle_bloqueio_usuario;
       public         postgres    false    3            <           1259    16836     controle_bloqueio_usuario_id_seq    SEQUENCE     �   CREATE SEQUENCE public.controle_bloqueio_usuario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.controle_bloqueio_usuario_id_seq;
       public       postgres    false    3            =           1259    16838    controle_card    TABLE     �   CREATE TABLE public.controle_card (
    id bigint NOT NULL,
    usuario_id integer NOT NULL,
    chave_card character varying NOT NULL,
    tab_view integer NOT NULL,
    ativo boolean NOT NULL
);
 !   DROP TABLE public.controle_card;
       public         postgres    false    3            >           1259    16844    controle_card_id_seq    SEQUENCE     }   CREATE SEQUENCE public.controle_card_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.controle_card_id_seq;
       public       postgres    false    3    317            �           0    0    controle_card_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.controle_card_id_seq OWNED BY public.controle_card.id;
            public       postgres    false    318            ?           1259    16846    controle_nsa    TABLE     \  CREATE TABLE public.controle_nsa (
    id bigint NOT NULL,
    empresa_id integer,
    nome_antigo character varying(100) NOT NULL,
    nome_novo character varying(100) NOT NULL,
    nsa bigint NOT NULL,
    tipo_arquivo character varying(100) NOT NULL,
    data_catalogacao timestamp without time zone NOT NULL,
    catalogado boolean NOT NULL
);
     DROP TABLE public.controle_nsa;
       public         postgres    false    3            @           1259    16849    controle_nsa_arrecadacao    TABLE     �   CREATE TABLE public.controle_nsa_arrecadacao (
    id bigint NOT NULL,
    tipoarrecadacao integer NOT NULL,
    nsa bigint NOT NULL,
    banco_id bigint NOT NULL
);
 ,   DROP TABLE public.controle_nsa_arrecadacao;
       public         postgres    false    3            A           1259    16852    controle_nsa_arrecadacao_id_seq    SEQUENCE     �   CREATE SEQUENCE public.controle_nsa_arrecadacao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 6   DROP SEQUENCE public.controle_nsa_arrecadacao_id_seq;
       public       postgres    false    3            B           1259    16854    controle_nsa_id_seq    SEQUENCE     �   CREATE SEQUENCE public.controle_nsa_id_seq
    START WITH 273201
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.controle_nsa_id_seq;
       public       postgres    false    3            C           1259    16856    controle_nsa_optantes_debito    TABLE     �   CREATE TABLE public.controle_nsa_optantes_debito (
    id bigint NOT NULL,
    nsa bigint NOT NULL,
    convenio_id bigint NOT NULL
);
 0   DROP TABLE public.controle_nsa_optantes_debito;
       public         postgres    false    3            D           1259    16859 #   controle_nsa_optantes_debito_id_seq    SEQUENCE     �   CREATE SEQUENCE public.controle_nsa_optantes_debito_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 :   DROP SEQUENCE public.controle_nsa_optantes_debito_id_seq;
       public       postgres    false    3            E           1259    16861    controle_nsa_remessa_id_seq    SEQUENCE     �   CREATE SEQUENCE public.controle_nsa_remessa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.controle_nsa_remessa_id_seq;
       public       postgres    false    3            F           1259    16863    controle_nsa_remessa    TABLE     �   CREATE TABLE public.controle_nsa_remessa (
    id bigint DEFAULT nextval('public.controle_nsa_remessa_id_seq'::regclass) NOT NULL,
    convenio_id bigint,
    empresa_id bigint,
    nsa bigint
);
 (   DROP TABLE public.controle_nsa_remessa;
       public         postgres    false    325    3            G           1259    16867    controle_processamento    TABLE     �   CREATE TABLE public.controle_processamento (
    id bigint NOT NULL,
    data timestamp without time zone NOT NULL,
    grupo_empresa_id integer NOT NULL,
    tipo_processamento integer NOT NULL
);
 *   DROP TABLE public.controle_processamento;
       public         postgres    false    3            H           1259    16870     controle_remessa_optantes_debito    TABLE     �   CREATE TABLE public.controle_remessa_optantes_debito (
    id bigint NOT NULL,
    data date NOT NULL,
    tipo_remessa integer NOT NULL,
    arquivo_id bigint,
    usuario_id bigint NOT NULL
);
 4   DROP TABLE public.controle_remessa_optantes_debito;
       public         postgres    false    3            I           1259    16873 '   controle_remessa_optantes_debito_id_seq    SEQUENCE     �   CREATE SEQUENCE public.controle_remessa_optantes_debito_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 >   DROP SEQUENCE public.controle_remessa_optantes_debito_id_seq;
       public       postgres    false    3            J           1259    16875    controle_senha    TABLE     �   CREATE TABLE public.controle_senha (
    id bigint NOT NULL,
    usuario_id integer NOT NULL,
    senha character varying(100) NOT NULL,
    data timestamp without time zone NOT NULL
);
 "   DROP TABLE public.controle_senha;
       public         postgres    false    3            K           1259    16878    controle_senha_id_seq    SEQUENCE     ~   CREATE SEQUENCE public.controle_senha_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public.controle_senha_id_seq;
       public       postgres    false    3            L           1259    16880    controle_upload_arquivo    TABLE     �  CREATE TABLE public.controle_upload_arquivo (
    id bigint NOT NULL,
    data_upload timestamp without time zone NOT NULL,
    usuario_id bigint NOT NULL,
    nome_arquivo character varying(255) NOT NULL,
    status_upload integer NOT NULL,
    tipo_arquivo integer NOT NULL,
    grupo_empresa_id integer NOT NULL,
    erro character varying(255),
    novo_nome_arquivo character varying(255),
    empresa_id bigint,
    diretorio character varying(255),
    importacao_personalizada_id bigint
);
 +   DROP TABLE public.controle_upload_arquivo;
       public         postgres    false    3            M           1259    16886    controle_upload_arquivo_id_seq    SEQUENCE     �   CREATE SEQUENCE public.controle_upload_arquivo_id_seq
    START WITH 4656
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 5   DROP SEQUENCE public.controle_upload_arquivo_id_seq;
       public       postgres    false    3            N           1259    16888    convenio    TABLE     F  CREATE TABLE public.convenio (
    id bigint NOT NULL,
    codigo_convenio character varying(20) NOT NULL,
    empresa_id bigint NOT NULL,
    tipo_convenio integer NOT NULL,
    layout integer,
    remessa bigint,
    seq_seu_numero bigint,
    banco_id bigint NOT NULL,
    valor_referencia numeric,
    ativo boolean DEFAULT false,
    apelido character varying(100),
    arquivo_pre_autorizado boolean DEFAULT true NOT NULL,
    apelido_transmissao character varying(40),
    path character varying(120),
    automatico boolean DEFAULT false,
    usuario_id integer,
    data_hora_criacao timestamp without time zone,
    usuario_validador integer,
    data_hora_validacao timestamp without time zone,
    copia_retorno_ftp boolean DEFAULT false NOT NULL,
    cliente_ftp_id integer,
    uso_interno boolean DEFAULT false NOT NULL
);
    DROP TABLE public.convenio;
       public         postgres    false    3            O           1259    16899    convenio_aud    TABLE     Y  CREATE TABLE public.convenio_aud (
    id bigint NOT NULL,
    rev bigint NOT NULL,
    revtype smallint,
    codigo_convenio character varying,
    tipo_convenio integer,
    layout integer,
    remessa bigint,
    seq_seu_numero bigint,
    valor_referencia numeric,
    arquivo_pre_autorizado boolean,
    apelido_transmissao character varying(40),
    path character varying(120),
    automatico boolean,
    usuario_id integer,
    data_hora_criacao timestamp without time zone,
    usuario_validador integer,
    data_hora_validacao timestamp without time zone,
    copia_retorno_ftp boolean
);
     DROP TABLE public.convenio_aud;
       public         postgres    false    3            P           1259    16905    convenio_configuracao    TABLE     �   CREATE TABLE public.convenio_configuracao (
    convenio_id bigint NOT NULL,
    cliente_baixa_pagamento_id bigint,
    baixa_pagamento_automatica boolean DEFAULT false,
    incluir_pagamento_remessa boolean DEFAULT false
);
 )   DROP TABLE public.convenio_configuracao;
       public         postgres    false    3            Q           1259    16910    convenio_conta_id_seq    SEQUENCE     �   CREATE SEQUENCE public.convenio_conta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 ,   DROP SEQUENCE public.convenio_conta_id_seq;
       public       postgres    false    3            R           1259    16912    convenio_conta    TABLE     �   CREATE TABLE public.convenio_conta (
    id bigint DEFAULT nextval('public.convenio_conta_id_seq'::regclass) NOT NULL,
    convenio_id bigint NOT NULL,
    conta_id bigint NOT NULL
);
 "   DROP TABLE public.convenio_conta;
       public         postgres    false    337    3            S           1259    16916    convenio_empresa    TABLE     �   CREATE TABLE public.convenio_empresa (
    id bigint NOT NULL,
    convenio_id bigint NOT NULL,
    empresa_id bigint NOT NULL
);
 $   DROP TABLE public.convenio_empresa;
       public         postgres    false    3            T           1259    16919    convenio_empresa_id_seq    SEQUENCE     �   CREATE SEQUENCE public.convenio_empresa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 .   DROP SEQUENCE public.convenio_empresa_id_seq;
       public       postgres    false    3            U           1259    16921    convenio_extrato    TABLE     �   CREATE TABLE public.convenio_extrato (
    id bigint NOT NULL,
    nome_empresa character varying(80) NOT NULL,
    cnpj character varying(18) NOT NULL,
    convenio_id bigint NOT NULL
);
 $   DROP TABLE public.convenio_extrato;
       public         postgres    false    3            V           1259    16924    convenio_extrato_id_seq    SEQUENCE     �   CREATE SEQUENCE public.convenio_extrato_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.convenio_extrato_id_seq;
       public       postgres    false    3            W           1259    16926    convenio_id_seq    SEQUENCE     x   CREATE SEQUENCE public.convenio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE public.convenio_id_seq;
       public       postgres    false    3            X           1259    16928    convenio_pagamento    TABLE     �   CREATE TABLE public.convenio_pagamento (
    id bigint NOT NULL,
    convenio_id bigint NOT NULL,
    path character varying(120),
    apelido character varying(20),
    automatico boolean
);
 &   DROP TABLE public.convenio_pagamento;
       public         postgres    false    3            Y           1259    16931    convenio_pagamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.convenio_pagamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 1566804069
    CACHE 1;
 0   DROP SEQUENCE public.convenio_pagamento_id_seq;
       public       postgres    false    3            Z           1259    16933    credencial_acesso_empresa    TABLE     �  CREATE TABLE public.credencial_acesso_empresa (
    id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    client_id character varying(36) NOT NULL,
    client_secret character varying(16) NOT NULL,
    credencial_base64 character varying(500) NOT NULL,
    data_geracao date NOT NULL,
    hora_geracao time without time zone NOT NULL,
    acess_token character varying(500),
    data_acess_token_geracao date,
    hora_acess_token_geracao time without time zone,
    ativo boolean NOT NULL
);
 -   DROP TABLE public.credencial_acesso_empresa;
       public         postgres    false    3            [           1259    16939     credencial_acesso_empresa_id_seq    SEQUENCE     �   CREATE SEQUENCE public.credencial_acesso_empresa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.credencial_acesso_empresa_id_seq;
       public       postgres    false    3            \           1259    16941    descricao_lancamento    TABLE     %  CREATE TABLE public.descricao_lancamento (
    id bigint NOT NULL,
    descricao character varying(100) NOT NULL,
    banco_id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    categoria_lancamento_id bigint,
    codigo character varying(100) NOT NULL,
    tratado boolean DEFAULT false
);
 (   DROP TABLE public.descricao_lancamento;
       public         postgres    false    3            ]           1259    16945    descricao_lancamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.descricao_lancamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.descricao_lancamento_id_seq;
       public       postgres    false    3            ^           1259    16947    descricao_lancamento_new    TABLE     �  CREATE TABLE public.descricao_lancamento_new (
    id bigint NOT NULL,
    descricao character varying(100) NOT NULL,
    banco_id bigint NOT NULL,
    empresa_id bigint,
    categoria_lancamento_id bigint,
    codigo character varying(100),
    tratado boolean DEFAULT false,
    per_somente_credito boolean DEFAULT true,
    descricao_completa character varying(255),
    lancamento_confidencial boolean DEFAULT false
);
 ,   DROP TABLE public.descricao_lancamento_new;
       public         postgres    false    3            _           1259    16952 >   descricao_lancamento_new_categoria_lancamento_new_configuracao    TABLE     �  CREATE TABLE public.descricao_lancamento_new_categoria_lancamento_new_configuracao (
    id bigint NOT NULL,
    categoria_lancamento_new_id bigint NOT NULL,
    descricao_lancamento_new_id bigint NOT NULL,
    descricao_configuracao text,
    somente_credito boolean DEFAULT false,
    data_edicao date,
    hora_edicao time without time zone,
    motor_agendado boolean DEFAULT false,
    rede_id_conciliador bigint,
    bandeira_id_conciliador bigint,
    usuario_id bigint
);
 R   DROP TABLE public.descricao_lancamento_new_categoria_lancamento_new_configuracao;
       public         postgres    false    3            `           1259    16960 ?   descricao_lancamento_new_categoria_lancamento_new_config_id_seq    SEQUENCE     �   CREATE SEQUENCE public.descricao_lancamento_new_categoria_lancamento_new_config_id_seq
    START WITH 20
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 V   DROP SEQUENCE public.descricao_lancamento_new_categoria_lancamento_new_config_id_seq;
       public       postgres    false    3    351            �           0    0 ?   descricao_lancamento_new_categoria_lancamento_new_config_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.descricao_lancamento_new_categoria_lancamento_new_config_id_seq OWNED BY public.descricao_lancamento_new_categoria_lancamento_new_configuracao.id;
            public       postgres    false    352            a           1259    16962    descricao_lancamento_new_id_seq    SEQUENCE     �   CREATE SEQUENCE public.descricao_lancamento_new_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 6   DROP SEQUENCE public.descricao_lancamento_new_id_seq;
       public       postgres    false    3            b           1259    16964    despesa_processamento    TABLE     �   CREATE TABLE public.despesa_processamento (
    id bigint NOT NULL,
    data date NOT NULL,
    descricao character varying(60),
    valor double precision NOT NULL,
    processamento_otimiza_id bigint NOT NULL
);
 )   DROP TABLE public.despesa_processamento;
       public         postgres    false    3            c           1259    16967    despesa_processamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.despesa_processamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.despesa_processamento_id_seq;
       public       postgres    false    3            �           1259    35572    documentacao    TABLE     �  CREATE TABLE public.documentacao (
    id bigint NOT NULL,
    modulo integer NOT NULL,
    tipo_arquivo integer NOT NULL,
    finalidade integer NOT NULL,
    descricao character varying NOT NULL,
    versao character varying,
    nome_arquivo character varying NOT NULL,
    formato_arquivo character varying NOT NULL,
    arquivo bytea NOT NULL,
    data_cadastro date NOT NULL,
    ativo boolean NOT NULL
);
     DROP TABLE public.documentacao;
       public         postgres    false    3            �           1259    35570    documentacao_id_seq    SEQUENCE     |   CREATE SEQUENCE public.documentacao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.documentacao_id_seq;
       public       postgres    false    3    669            �           0    0    documentacao_id_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public.documentacao_id_seq OWNED BY public.documentacao.id;
            public       postgres    false    668            d           1259    16969    download    TABLE     /  CREATE TABLE public.download (
    id integer NOT NULL,
    usuario_id integer NOT NULL,
    data_geracao timestamp without time zone NOT NULL,
    nome_arquivo character varying(80) NOT NULL,
    quantidade_registros numeric(5,0) NOT NULL,
    tipo_arquivo integer NOT NULL,
    nsa bigint NOT NULL
);
    DROP TABLE public.download;
       public         postgres    false    3            e           1259    16972    download_id_seq    SEQUENCE     x   CREATE SEQUENCE public.download_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE public.download_id_seq;
       public       postgres    false    3            f           1259    16974    email    TABLE     h  CREATE TABLE public.email (
    id bigint NOT NULL,
    data_envio timestamp without time zone NOT NULL,
    titulo character varying(255) NOT NULL,
    corpo text NOT NULL,
    destinatario character varying(500) NOT NULL,
    tipo_email integer NOT NULL,
    enviado boolean NOT NULL,
    reenviado integer NOT NULL,
    grupo_empresa_id integer NOT NULL
);
    DROP TABLE public.email;
       public         postgres    false    3            g           1259    16980    email_id_seq    SEQUENCE     u   CREATE SEQUENCE public.email_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE public.email_id_seq;
       public       postgres    false    3            h           1259    16982    empresa    TABLE       CREATE TABLE public.empresa (
    id bigint NOT NULL,
    razao_social character varying(255) NOT NULL,
    nome_fantasia character varying(70) NOT NULL,
    email character varying(70),
    cnpj character varying(18) NOT NULL,
    telefone character varying(20),
    logradouro character varying(70) NOT NULL,
    complemento character varying(150),
    bairro character varying(255) NOT NULL,
    cep character varying(10) NOT NULL,
    grupo_empresa_id integer NOT NULL,
    ativo boolean NOT NULL,
    estado_id bigint NOT NULL,
    cidade_id bigint NOT NULL,
    numero character varying(6),
    telefone2 character varying(20),
    esfera_atuacao integer,
    status integer DEFAULT 0,
    cocriacao boolean DEFAULT false NOT NULL,
    empresa_matriz_id bigint
);
    DROP TABLE public.empresa;
       public         postgres    false    3            �           0    0    COLUMN empresa.esfera_atuacao    COMMENT     N   COMMENT ON COLUMN public.empresa.esfera_atuacao IS '0 - PUBLICO 1 - PRIVADO';
            public       postgres    false    360            i           1259    16990    empresa_id_empresa_seq    SEQUENCE        CREATE SEQUENCE public.empresa_id_empresa_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.empresa_id_empresa_seq;
       public       postgres    false    3    360            �           0    0    empresa_id_empresa_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.empresa_id_empresa_seq OWNED BY public.empresa.id;
            public       postgres    false    361            j           1259    16992    empresa_id_seq    SEQUENCE     x   CREATE SEQUENCE public.empresa_id_seq
    START WITH 21
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE public.empresa_id_seq;
       public       postgres    false    3            k           1259    16994    empresa_transportadora    TABLE     �   CREATE TABLE public.empresa_transportadora (
    id bigint NOT NULL,
    empresa_id integer NOT NULL,
    transportadora_id integer NOT NULL,
    usuario character varying NOT NULL,
    senha character varying NOT NULL
);
 *   DROP TABLE public.empresa_transportadora;
       public         postgres    false    3            l           1259    17000    empresa_transportadora_id_seq    SEQUENCE     �   CREATE SEQUENCE public.empresa_transportadora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.empresa_transportadora_id_seq;
       public       postgres    false    3    363            �           0    0    empresa_transportadora_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.empresa_transportadora_id_seq OWNED BY public.empresa_transportadora.id;
            public       postgres    false    364            m           1259    17002    emprestimo_processamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.emprestimo_processamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.emprestimo_processamento_id_seq;
       public       postgres    false    3            n           1259    17004    emprestimo_processamento    TABLE     0  CREATE TABLE public.emprestimo_processamento (
    id bigint DEFAULT nextval('public.emprestimo_processamento_id_seq'::regclass) NOT NULL,
    oferta character varying(60) NOT NULL,
    taxa double precision NOT NULL,
    limite double precision NOT NULL,
    processamento_otimiza_id bigint NOT NULL
);
 ,   DROP TABLE public.emprestimo_processamento;
       public         postgres    false    365    3            o           1259    17008    estado    TABLE     u   CREATE TABLE public.estado (
    id bigint NOT NULL,
    descricao character varying,
    uf character varying(2)
);
    DROP TABLE public.estado;
       public         postgres    false    3            p           1259    17014    estado_id_seq    SEQUENCE     v   CREATE SEQUENCE public.estado_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE public.estado_id_seq;
       public       postgres    false    3            q           1259    17016 	   faixa_cep    TABLE     �   CREATE TABLE public.faixa_cep (
    id bigint NOT NULL,
    estado_id bigint NOT NULL,
    faixa_inicial character varying(10) NOT NULL,
    faixa_final character varying(10) NOT NULL
);
    DROP TABLE public.faixa_cep;
       public         postgres    false    3            r           1259    17019    faixa_cep_id_seq    SEQUENCE     y   CREATE SEQUENCE public.faixa_cep_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.faixa_cep_id_seq;
       public       postgres    false    3            s           1259    17021    faixa_nosso_numero_sacado    TABLE     �   CREATE TABLE public.faixa_nosso_numero_sacado (
    id bigint NOT NULL,
    ativo boolean NOT NULL,
    fim bigint NOT NULL,
    inicio bigint NOT NULL,
    sacado_id bigint NOT NULL,
    data_insercao timestamp without time zone
);
 -   DROP TABLE public.faixa_nosso_numero_sacado;
       public         postgres    false    3            t           1259    17024    faixa_nosso_numero_sacado_aud    TABLE     �   CREATE TABLE public.faixa_nosso_numero_sacado_aud (
    id bigint NOT NULL,
    rev bigint NOT NULL,
    revtype smallint,
    data_insercao timestamp without time zone,
    fim bigint,
    inicio bigint
);
 1   DROP TABLE public.faixa_nosso_numero_sacado_aud;
       public         postgres    false    3            u           1259    17027     faixa_nosso_numero_sacado_id_seq    SEQUENCE     �   CREATE SEQUENCE public.faixa_nosso_numero_sacado_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.faixa_nosso_numero_sacado_id_seq;
       public       postgres    false    3            v           1259    17029    faq    TABLE     �   CREATE TABLE public.faq (
    id integer NOT NULL,
    tp_modulo integer NOT NULL,
    pergunta character varying(120) NOT NULL,
    resposta text NOT NULL
);
    DROP TABLE public.faq;
       public         postgres    false    3            w           1259    17035 
   faq_id_seq    SEQUENCE     �   CREATE SEQUENCE public.faq_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 !   DROP SEQUENCE public.faq_id_seq;
       public       postgres    false    3    374            �           0    0 
   faq_id_seq    SEQUENCE OWNED BY     9   ALTER SEQUENCE public.faq_id_seq OWNED BY public.faq.id;
            public       postgres    false    375            x           1259    17037    faturamento    TABLE     �   CREATE TABLE public.faturamento (
    id bigint NOT NULL,
    empresa_id integer NOT NULL,
    loja_id integer NOT NULL,
    valor_faturamento numeric,
    data_faturamento date,
    transportadora_id bigint,
    conciliado boolean DEFAULT false
);
    DROP TABLE public.faturamento;
       public         postgres    false    3            y           1259    17043    faturamento_id_seq    SEQUENCE     {   CREATE SEQUENCE public.faturamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.faturamento_id_seq;
       public       postgres    false    376    3            �           0    0    faturamento_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.faturamento_id_seq OWNED BY public.faturamento.id;
            public       postgres    false    377            z           1259    17045 
   favorecido    TABLE     �  CREATE TABLE public.favorecido (
    id bigint NOT NULL,
    nome character varying(70) NOT NULL,
    email character varying(70),
    cnpj_cpf character varying(18) NOT NULL,
    telefone character varying(20),
    logradouro character varying(70) NOT NULL,
    complemento character varying(255),
    bairro character varying(30) NOT NULL,
    cep character varying(10) NOT NULL,
    grupo_id integer,
    ativo boolean NOT NULL,
    agencia character varying(5),
    dv_agencia character varying(1),
    conta character varying(12),
    dv_conta character varying(1),
    banco_id bigint,
    valor numeric,
    estado_id bigint NOT NULL,
    tipo_favorecido integer NOT NULL,
    pendente_verificacao boolean,
    codigo character varying(30),
    operacao character varying(3),
    cidade_id bigint NOT NULL,
    portal_pagamento boolean NOT NULL,
    dv_agencia_conta character varying(1),
    numero character varying(6),
    tipo_pessoa integer DEFAULT 0
);
    DROP TABLE public.favorecido;
       public         postgres    false    3            {           1259    17052    favorecido_aud    TABLE        CREATE TABLE public.favorecido_aud (
    id bigint NOT NULL,
    rev bigint NOT NULL,
    revtype smallint,
    nome character varying(70),
    email character varying(70),
    cnpj_cpf character varying(18),
    telefone character varying(20),
    logradouro character varying(70),
    complemento character varying(255),
    bairro character varying(30),
    cep character varying(10),
    ativo boolean,
    agencia character varying(5),
    dv_agencia character varying(1),
    conta character varying(12),
    dv_conta character varying(1),
    valor numeric,
    pendente_verificacao boolean,
    codigo character varying(30),
    operacao character varying(3),
    portal_pagamento boolean,
    numero character varying(6),
    tipo_pessoa integer DEFAULT 0
);
 "   DROP TABLE public.favorecido_aud;
       public         postgres    false    3            |           1259    17059    favorecido_conta    TABLE     �  CREATE TABLE public.favorecido_conta (
    id bigint NOT NULL,
    banco_id bigint NOT NULL,
    favorecido_id bigint NOT NULL,
    agencia character varying(5) NOT NULL,
    dv_agencia character varying(1),
    conta character varying(12) NOT NULL,
    dv_conta character varying(1),
    dv_agencia_conta character varying(1),
    operacao character varying(3),
    ativo boolean DEFAULT true NOT NULL,
    principal boolean DEFAULT false NOT NULL,
    favorecido_id_old bigint
);
 $   DROP TABLE public.favorecido_conta;
       public         postgres    false    3            }           1259    17064    favorecido_conta_aud    TABLE     �  CREATE TABLE public.favorecido_conta_aud (
    id bigint,
    rev bigint NOT NULL,
    revtype smallint,
    banco_id bigint,
    favorecido_id bigint,
    agencia character varying(5),
    dv_agencia character varying(1),
    conta character varying(12),
    dv_conta character varying(1),
    dv_agencia_conta character varying(1),
    operacao character varying(3),
    ativo boolean,
    principal boolean,
    favorecido_id_old bigint,
    favorecido_conta_id bigint
);
 (   DROP TABLE public.favorecido_conta_aud;
       public         postgres    false    3            ~           1259    17067    favorecido_conta_id_seq    SEQUENCE     �   CREATE SEQUENCE public.favorecido_conta_id_seq
    START WITH 200
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.favorecido_conta_id_seq;
       public       postgres    false    3                       1259    17069    favorecido_id_seq    SEQUENCE     z   CREATE SEQUENCE public.favorecido_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.favorecido_id_seq;
       public       postgres    false    3            �           1259    17071    feriado    TABLE     �   CREATE TABLE public.feriado (
    id bigint NOT NULL,
    dia integer NOT NULL,
    mes integer NOT NULL,
    ano integer,
    descricao character varying(255) NOT NULL
);
    DROP TABLE public.feriado;
       public         postgres    false    3            �           1259    17074    feriado_id_seq    SEQUENCE     w   CREATE SEQUENCE public.feriado_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE public.feriado_id_seq;
       public       postgres    false    3            �           1259    17076    float    TABLE     �   CREATE TABLE public."float" (
    id bigint NOT NULL,
    valorfloat integer NOT NULL,
    banco_id bigint NOT NULL,
    forma_pagamento_arrecadacao_id bigint NOT NULL
);
    DROP TABLE public."float";
       public         postgres    false    3            �           1259    17079    float_id_seq    SEQUENCE     }   CREATE SEQUENCE public.float_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 #   DROP SEQUENCE public.float_id_seq;
       public       postgres    false    3            �           1259    17081    forma_pagamento    TABLE     �   CREATE TABLE public.forma_pagamento (
    banco_id bigint,
    descricao character varying,
    codigo integer NOT NULL,
    id bigint NOT NULL,
    descricao_resumida character varying,
    tipo_forma_pagamento integer
);
 #   DROP TABLE public.forma_pagamento;
       public         postgres    false    3            �           1259    17087    forma_pagamento_arrecadacao    TABLE     �   CREATE TABLE public.forma_pagamento_arrecadacao (
    id bigint NOT NULL,
    codigo character varying(10) NOT NULL,
    descricao character varying(255) NOT NULL,
    nome character varying(60) NOT NULL
);
 /   DROP TABLE public.forma_pagamento_arrecadacao;
       public         postgres    false    3            �           1259    17090 "   forma_pagamento_arrecadacao_id_seq    SEQUENCE     �   CREATE SEQUENCE public.forma_pagamento_arrecadacao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2061584294
    CACHE 1;
 9   DROP SEQUENCE public.forma_pagamento_arrecadacao_id_seq;
       public       postgres    false    3            �           1259    17092    forma_pagamento_fluxo_caixa    TABLE     �   CREATE TABLE public.forma_pagamento_fluxo_caixa (
    id bigint NOT NULL,
    empresa bytea,
    nome character varying(30) NOT NULL,
    empresa_id bigint
);
 /   DROP TABLE public.forma_pagamento_fluxo_caixa;
       public         postgres    false    3            �           1259    17098 "   forma_pagamento_fluxo_caixa_id_seq    SEQUENCE     �   CREATE SEQUENCE public.forma_pagamento_fluxo_caixa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 9   DROP SEQUENCE public.forma_pagamento_fluxo_caixa_id_seq;
       public       postgres    false    3            �           1259    17100    forma_pagamento_id_seq    SEQUENCE        CREATE SEQUENCE public.forma_pagamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.forma_pagamento_id_seq;
       public       postgres    false    3            �           1259    17102    frequencia_recolhimento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.frequencia_recolhimento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 5   DROP SEQUENCE public.frequencia_recolhimento_id_seq;
       public       postgres    false    3            �           1259    17104    frequencia_recolhimento    TABLE     j  CREATE TABLE public.frequencia_recolhimento (
    id bigint DEFAULT nextval('public.frequencia_recolhimento_id_seq'::regclass) NOT NULL,
    empresa_id bigint NOT NULL,
    loja_id integer NOT NULL,
    transportadora_id integer NOT NULL,
    ativo boolean,
    tipofrequencia bigint,
    usuario_id integer,
    data_hora_criacao timestamp without time zone
);
 +   DROP TABLE public.frequencia_recolhimento;
       public         postgres    false    394    3            �           1259    17108 *   grafico_arrecadacao_forma_pagamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.grafico_arrecadacao_forma_pagamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 A   DROP SEQUENCE public.grafico_arrecadacao_forma_pagamento_id_seq;
       public       postgres    false    3            �           1259    17110 #   grafico_arrecadacao_forma_pagamento    TABLE     `  CREATE TABLE public.grafico_arrecadacao_forma_pagamento (
    id bigint DEFAULT nextval('public.grafico_arrecadacao_forma_pagamento_id_seq'::regclass) NOT NULL,
    data date NOT NULL,
    quantidade bigint NOT NULL,
    valor_arrecadado double precision NOT NULL,
    convenio_id bigint NOT NULL,
    forma_pagamento_arrecadacao_id bigint NOT NULL
);
 7   DROP TABLE public.grafico_arrecadacao_forma_pagamento;
       public         postgres    false    396    3            �           1259    17114    grafico_extrato_bancario_id_seq    SEQUENCE     �   CREATE SEQUENCE public.grafico_extrato_bancario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.grafico_extrato_bancario_id_seq;
       public       postgres    false    3            �           1259    17116    grupo    TABLE     �   CREATE TABLE public.grupo (
    id integer NOT NULL,
    descricao character varying(255) NOT NULL,
    empresa_id bigint NOT NULL,
    tipo_favorecido integer
);
    DROP TABLE public.grupo;
       public         postgres    false    3            �           1259    17119    grupo_autorizacao_convenio    TABLE     �   CREATE TABLE public.grupo_autorizacao_convenio (
    id bigint NOT NULL,
    descricao character varying(30) NOT NULL,
    convenio_id bigint NOT NULL,
    quantidade_autorizacao integer DEFAULT 1,
    ordem integer DEFAULT 1
);
 .   DROP TABLE public.grupo_autorizacao_convenio;
       public         postgres    false    3            �           1259    17124 !   grupo_autorizacao_convenio_id_seq    SEQUENCE     �   CREATE SEQUENCE public.grupo_autorizacao_convenio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 8   DROP SEQUENCE public.grupo_autorizacao_convenio_id_seq;
       public       postgres    false    3            �           1259    17126 "   grupo_autorizacao_convenio_usuario    TABLE     �   CREATE TABLE public.grupo_autorizacao_convenio_usuario (
    usuario_id bigint NOT NULL,
    grupo_autorizacao_convenio_id bigint NOT NULL
);
 6   DROP TABLE public.grupo_autorizacao_convenio_usuario;
       public         postgres    false    3            �           1259    17129    grupo_empresa    TABLE     �   CREATE TABLE public.grupo_empresa (
    id integer NOT NULL,
    descricao character varying(255) NOT NULL,
    ativo boolean
);
 !   DROP TABLE public.grupo_empresa;
       public         postgres    false    3            �           1259    17132    grupo_empresas_id_seq    SEQUENCE     ~   CREATE SEQUENCE public.grupo_empresas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public.grupo_empresas_id_seq;
       public       postgres    false    3            �           1259    17134    grupo_id_seq    SEQUENCE     u   CREATE SEQUENCE public.grupo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE public.grupo_id_seq;
       public       postgres    false    3            �           1259    17136    grupo_lancamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.grupo_lancamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.grupo_lancamento_id_seq;
       public       postgres    false    3            �           1259    17138    grupo_lancamento    TABLE       CREATE TABLE public.grupo_lancamento (
    id bigint DEFAULT nextval('public.grupo_lancamento_id_seq'::regclass) NOT NULL,
    data date NOT NULL,
    conta_id bigint NOT NULL,
    categoria_lancamento_id bigint NOT NULL,
    tarifa_origem_id bigint NOT NULL,
    tipo_operacao_id bigint NOT NULL,
    qtd_lancamentos integer NOT NULL,
    franquia smallint NOT NULL,
    valor_unitario numeric NOT NULL,
    valor_total numeric NOT NULL,
    conciliado boolean DEFAULT false NOT NULL,
    data_conciliacao timestamp without time zone,
    tipo_conciliacao smallint,
    usuario_id bigint,
    descricao character varying(100) NOT NULL
);
 $   DROP TABLE public.grupo_lancamento;
       public         postgres    false    406    3            �           1259    17146    grupo_lancamento_fluxo_caixa    TABLE     �   CREATE TABLE public.grupo_lancamento_fluxo_caixa (
    id bigint NOT NULL,
    nome character varying(255) NOT NULL,
    tipolancamento character varying(255),
    empresa_id bigint,
    tipo_lancamento character varying(255)
);
 0   DROP TABLE public.grupo_lancamento_fluxo_caixa;
       public         postgres    false    3            �           1259    17152 #   grupo_lancamento_fluxo_caixa_id_seq    SEQUENCE     �   CREATE SEQUENCE public.grupo_lancamento_fluxo_caixa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 :   DROP SEQUENCE public.grupo_lancamento_fluxo_caixa_id_seq;
       public       postgres    false    3            �           1259    17154    grupo_numerario    TABLE     @  CREATE TABLE public.grupo_numerario (
    id bigint NOT NULL,
    data_recolhimento date NOT NULL,
    valor_recolhimento numeric NOT NULL,
    empresa_id integer NOT NULL,
    transportadora_id integer NOT NULL,
    contrato_id integer NOT NULL,
    usuario_id integer,
    conciliado boolean DEFAULT false NOT NULL
);
 #   DROP TABLE public.grupo_numerario;
       public         postgres    false    3            �           1259    17161    grupo_numerario_id_seq    SEQUENCE        CREATE SEQUENCE public.grupo_numerario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.grupo_numerario_id_seq;
       public       postgres    false    3    410            �           0    0    grupo_numerario_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public.grupo_numerario_id_seq OWNED BY public.grupo_numerario.id;
            public       postgres    false    411            �           1259    17163    grupo_pagamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.grupo_pagamento_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.grupo_pagamento_id_seq;
       public       postgres    false    3            �           1259    17165    grupo_pagamento    TABLE     �  CREATE TABLE public.grupo_pagamento (
    id bigint DEFAULT nextval('public.grupo_pagamento_id_seq'::regclass) NOT NULL,
    data_pagamento date NOT NULL,
    valor numeric NOT NULL,
    conciliado boolean DEFAULT false NOT NULL,
    tipo_servico_id bigint,
    tipo_grupo smallint NOT NULL,
    forma_pagamento_id bigint,
    pagamento_id bigint NOT NULL,
    data_conciliacao timestamp without time zone,
    tipo_conciliacao smallint,
    usuario_id bigint
);
 #   DROP TABLE public.grupo_pagamento;
       public         postgres    false    412    3            �           1259    17173    grupo_permissao_id_seq    SEQUENCE        CREATE SEQUENCE public.grupo_permissao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.grupo_permissao_id_seq;
       public       postgres    false    3            �           1259    17175    grupo_sacado    TABLE     �   CREATE TABLE public.grupo_sacado (
    id bigint NOT NULL,
    descricao character varying(255) NOT NULL,
    ativo boolean NOT NULL,
    empresa_id bigint NOT NULL
);
     DROP TABLE public.grupo_sacado;
       public         postgres    false    3            �           1259    17178    grupo_sacado_ext    TABLE     m   CREATE TABLE public.grupo_sacado_ext (
    grupo_sacado_id bigint NOT NULL,
    sacado_id bigint NOT NULL
);
 $   DROP TABLE public.grupo_sacado_ext;
       public         postgres    false    3            �           1259    17181    grupo_sacado_id_seq    SEQUENCE     |   CREATE SEQUENCE public.grupo_sacado_id_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.grupo_sacado_id_seq;
       public       postgres    false    3            �           1259    17183    grupo_titulo    TABLE     �  CREATE TABLE public.grupo_titulo (
    id bigint NOT NULL,
    data_liquidacao date,
    data_credito date NOT NULL,
    convenio_id bigint NOT NULL,
    detalhamento character varying(100),
    valor numeric NOT NULL,
    tipo_transacao smallint,
    data_conciliacao timestamp without time zone,
    origem_conciliacao smallint,
    conciliado boolean,
    usuario_id bigint,
    movimento_retorno_cobranca_id bigint NOT NULL
);
     DROP TABLE public.grupo_titulo;
       public         postgres    false    3            �           1259    17189    grupo_titulo_id_seq    SEQUENCE     }   CREATE SEQUENCE public.grupo_titulo_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.grupo_titulo_id_seq;
       public       postgres    false    3            �           1259    17191    grupopermissao    TABLE     |   CREATE TABLE public.grupopermissao (
    id bigint NOT NULL,
    nome character varying(40) NOT NULL,
    modulo integer
);
 "   DROP TABLE public.grupopermissao;
       public         postgres    false    3            �           1259    17194    guia_transporte_valores    TABLE       CREATE TABLE public.guia_transporte_valores (
    id bigint NOT NULL,
    empresa_id integer NOT NULL,
    loja_id integer NOT NULL,
    transportadora_id integer NOT NULL,
    usuario_id integer NOT NULL,
    valor_total numeric NOT NULL,
    data_recolhimento date NOT NULL,
    diretorio_imagem_gtv character varying NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    codigo_gtv character varying NOT NULL,
    quantidade_moeda integer,
    valor_moeda numeric,
    quantidade_cedula integer,
    valor_cedula numeric
);
 +   DROP TABLE public.guia_transporte_valores;
       public         postgres    false    3            �           1259    17200    guia_transporte_valores_id_seq    SEQUENCE     �   CREATE SEQUENCE public.guia_transporte_valores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 5   DROP SEQUENCE public.guia_transporte_valores_id_seq;
       public       postgres    false    421    3            �           0    0    guia_transporte_valores_id_seq    SEQUENCE OWNED BY     a   ALTER SEQUENCE public.guia_transporte_valores_id_seq OWNED BY public.guia_transporte_valores.id;
            public       postgres    false    422            �           1259    17202 (   historico_frequencia_recolhimento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.historico_frequencia_recolhimento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 ?   DROP SEQUENCE public.historico_frequencia_recolhimento_id_seq;
       public       postgres    false    3            �           1259    17204 !   historico_frequencia_recolhimento    TABLE     �  CREATE TABLE public.historico_frequencia_recolhimento (
    id bigint DEFAULT nextval('public.historico_frequencia_recolhimento_id_seq'::regclass) NOT NULL,
    frequencia_recolhimento_id bigint,
    ativo boolean,
    usuario_id integer,
    data_ocorrencia timestamp without time zone NOT NULL,
    ocorrencia character varying NOT NULL,
    categoria_auditoria integer NOT NULL
);
 5   DROP TABLE public.historico_frequencia_recolhimento;
       public         postgres    false    423    3            �           1259    17211    historico_maquineta_id_seq    SEQUENCE     �   CREATE SEQUENCE public.historico_maquineta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.historico_maquineta_id_seq;
       public       postgres    false    3            �           1259    17213    historico_monitoramento    TABLE       CREATE TABLE public.historico_monitoramento (
    id integer NOT NULL,
    usuario_id bigint NOT NULL,
    pagamento_id bigint NOT NULL,
    data_criacao timestamp without time zone NOT NULL,
    status_monitoramento_id bigint NOT NULL,
    descricao character varying(255)
);
 +   DROP TABLE public.historico_monitoramento;
       public         postgres    false    3            �           1259    17216    historico_monitoramento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.historico_monitoramento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 5   DROP SEQUENCE public.historico_monitoramento_id_seq;
       public       postgres    false    426    3            �           0    0    historico_monitoramento_id_seq    SEQUENCE OWNED BY     a   ALTER SEQUENCE public.historico_monitoramento_id_seq OWNED BY public.historico_monitoramento.id;
            public       postgres    false    427            �           1259    17218    historico_optantes_debito    TABLE     K  CREATE TABLE public.historico_optantes_debito (
    id bigint NOT NULL,
    id_cliente character varying(25) NOT NULL,
    data date NOT NULL,
    banco_id bigint NOT NULL,
    agencia character varying(4) NOT NULL,
    conta character varying(7) NOT NULL,
    dv_conta character varying(1) NOT NULL,
    ativo boolean NOT NULL
);
 -   DROP TABLE public.historico_optantes_debito;
       public         postgres    false    3            �           1259    17221     historico_optantes_debito_id_seq    SEQUENCE     �   CREATE SEQUENCE public.historico_optantes_debito_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 7   DROP SEQUENCE public.historico_optantes_debito_id_seq;
       public       postgres    false    3            �           1259    17223    historico_pagamento    TABLE     >  CREATE TABLE public.historico_pagamento (
    id integer NOT NULL,
    usuario_id integer NOT NULL,
    pagamento_id integer NOT NULL,
    tipo_favorecido integer NOT NULL,
    data_ocorrencia timestamp without time zone NOT NULL,
    ocorrencia character varying NOT NULL,
    categoria_auditoria integer NOT NULL
);
 '   DROP TABLE public.historico_pagamento;
       public         postgres    false    3            �           1259    17229    historico_pagamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.historico_pagamento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.historico_pagamento_id_seq;
       public       postgres    false    430    3            �           0    0    historico_pagamento_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.historico_pagamento_id_seq OWNED BY public.historico_pagamento.id;
            public       postgres    false    431            �           1259    17231    historico_upload_favorecido    TABLE     �   CREATE TABLE public.historico_upload_favorecido (
    id integer NOT NULL,
    linha_processada bigint NOT NULL,
    descricao character varying,
    controle_upload_arquivo_id bigint NOT NULL,
    status boolean
);
 /   DROP TABLE public.historico_upload_favorecido;
       public         postgres    false    3            �           1259    17237 "   historico_upload_favorecido_id_seq    SEQUENCE     �   CREATE SEQUENCE public.historico_upload_favorecido_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 9   DROP SEQUENCE public.historico_upload_favorecido_id_seq;
       public       postgres    false    3    432            �           0    0 "   historico_upload_favorecido_id_seq    SEQUENCE OWNED BY     i   ALTER SEQUENCE public.historico_upload_favorecido_id_seq OWNED BY public.historico_upload_favorecido.id;
            public       postgres    false    433            �           1259    17239    historico_upload_sacado    TABLE     �   CREATE TABLE public.historico_upload_sacado (
    id integer NOT NULL,
    linha_processada bigint NOT NULL,
    descricao character varying,
    status boolean,
    controle_upload_arquivo_id bigint NOT NULL
);
 +   DROP TABLE public.historico_upload_sacado;
       public         postgres    false    3            �           1259    17245    historico_upload_sacado_id_seq    SEQUENCE     �   CREATE SEQUENCE public.historico_upload_sacado_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 5   DROP SEQUENCE public.historico_upload_sacado_id_seq;
       public       postgres    false    3    434            �           0    0    historico_upload_sacado_id_seq    SEQUENCE OWNED BY     a   ALTER SEQUENCE public.historico_upload_sacado_id_seq OWNED BY public.historico_upload_sacado.id;
            public       postgres    false    435            �           1259    17247    importacao_personalizada    TABLE     �  CREATE TABLE public.importacao_personalizada (
    id bigint NOT NULL,
    empresa_id integer NOT NULL,
    nome character varying NOT NULL,
    tipo_arquivo character varying NOT NULL,
    tipo_formato_arquivo character varying NOT NULL,
    tipo_importacao_personalizada character varying NOT NULL,
    delimitador character varying,
    inicio_arquivo integer,
    transportadora_id integer
);
 ,   DROP TABLE public.importacao_personalizada;
       public         postgres    false    3            �           1259    17253    importacao_personalizada_campo    TABLE       CREATE TABLE public.importacao_personalizada_campo (
    id bigint NOT NULL,
    importacao_personalizada_id integer NOT NULL,
    nome character varying NOT NULL,
    coluna integer,
    formato character varying,
    inicio integer,
    fim integer,
    agrupar character varying
);
 2   DROP TABLE public.importacao_personalizada_campo;
       public         postgres    false    3            �           1259    17259 %   importacao_personalizada_campo_id_seq    SEQUENCE     �   CREATE SEQUENCE public.importacao_personalizada_campo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 <   DROP SEQUENCE public.importacao_personalizada_campo_id_seq;
       public       postgres    false    3    437            �           0    0 %   importacao_personalizada_campo_id_seq    SEQUENCE OWNED BY     o   ALTER SEQUENCE public.importacao_personalizada_campo_id_seq OWNED BY public.importacao_personalizada_campo.id;
            public       postgres    false    438            �           1259    17261 #   importacao_personalizada_conta_fixo    TABLE       CREATE TABLE public.importacao_personalizada_conta_fixo (
    id bigint NOT NULL,
    importacao_personalizada_id integer NOT NULL,
    linha integer,
    coluna integer,
    posicao_agencia integer,
    posicao_conta integer,
    posicao_digito_conta integer,
    conta_id bigint
);
 7   DROP TABLE public.importacao_personalizada_conta_fixo;
       public         postgres    false    3            �           1259    17264 *   importacao_personalizada_conta_fixo_id_seq    SEQUENCE     �   CREATE SEQUENCE public.importacao_personalizada_conta_fixo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 A   DROP SEQUENCE public.importacao_personalizada_conta_fixo_id_seq;
       public       postgres    false    3    439            �           0    0 *   importacao_personalizada_conta_fixo_id_seq    SEQUENCE OWNED BY     y   ALTER SEQUENCE public.importacao_personalizada_conta_fixo_id_seq OWNED BY public.importacao_personalizada_conta_fixo.id;
            public       postgres    false    440            �           1259    17266    importacao_personalizada_id_seq    SEQUENCE     �   CREATE SEQUENCE public.importacao_personalizada_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.importacao_personalizada_id_seq;
       public       postgres    false    3    436            �           0    0    importacao_personalizada_id_seq    SEQUENCE OWNED BY     c   ALTER SEQUENCE public.importacao_personalizada_id_seq OWNED BY public.importacao_personalizada.id;
            public       postgres    false    441            �           1259    17268 &   importacao_personalizada_ignorar_linha    TABLE     �   CREATE TABLE public.importacao_personalizada_ignorar_linha (
    id bigint NOT NULL,
    importacao_personalizada_id integer NOT NULL,
    valor character varying,
    coluna integer,
    inicio integer,
    fim integer
);
 :   DROP TABLE public.importacao_personalizada_ignorar_linha;
       public         postgres    false    3            �           1259    17274 -   importacao_personalizada_ignorar_linha_id_seq    SEQUENCE     �   CREATE SEQUENCE public.importacao_personalizada_ignorar_linha_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 D   DROP SEQUENCE public.importacao_personalizada_ignorar_linha_id_seq;
       public       postgres    false    3    442            �           0    0 -   importacao_personalizada_ignorar_linha_id_seq    SEQUENCE OWNED BY        ALTER SEQUENCE public.importacao_personalizada_ignorar_linha_id_seq OWNED BY public.importacao_personalizada_ignorar_linha.id;
            public       postgres    false    443            �           1259    17276    item_contrato_bancario    TABLE     �  CREATE TABLE public.item_contrato_bancario (
    id bigint NOT NULL,
    contrato_bancario_id bigint NOT NULL,
    descricao_lancamento_id bigint NOT NULL,
    tarifa_agencia numeric(15,2) NOT NULL,
    tarifa_internet numeric(15,2) NOT NULL,
    tarifa_convenio numeric(15,2) NOT NULL,
    tarifa_auto_atendimento numeric(15,2) NOT NULL,
    franquia integer NOT NULL,
    periodicidade integer NOT NULL
);
 *   DROP TABLE public.item_contrato_bancario;
       public         postgres    false    3            �           0    0 +   COLUMN item_contrato_bancario.periodicidade    COMMENT     �   COMMENT ON COLUMN public.item_contrato_bancario.periodicidade IS '0 - MENSAL 
1 - QUINZENAL 
2 - SEMANAL 
3 - DIARIO 
4 - INTRADIA';
            public       postgres    false    444            �           1259    17279    item_contrato_bancario_id_seq    SEQUENCE     �   CREATE SEQUENCE public.item_contrato_bancario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 4   DROP SEQUENCE public.item_contrato_bancario_id_seq;
       public       postgres    false    3            �           1259    17281 &   item_contrato_bancario_pendente_id_seq    SEQUENCE     �   CREATE SEQUENCE public.item_contrato_bancario_pendente_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 =   DROP SEQUENCE public.item_contrato_bancario_pendente_id_seq;
       public       postgres    false    3            �           1259    17283    item_contrato_bancario_pendente    TABLE     �  CREATE TABLE public.item_contrato_bancario_pendente (
    id bigint DEFAULT nextval('public.item_contrato_bancario_pendente_id_seq'::regclass) NOT NULL,
    descricao character varying NOT NULL,
    periodo date NOT NULL,
    empresa_id bigint NOT NULL,
    banco_id bigint NOT NULL,
    conta_id bigint NOT NULL,
    convenio_id bigint NOT NULL,
    tarifa numeric(17,2) NOT NULL,
    pendente boolean DEFAULT true
);
 3   DROP TABLE public.item_contrato_bancario_pendente;
       public         postgres    false    446    3            �           1259    17291    item_contrato_cesta_servico    TABLE     (  CREATE TABLE public.item_contrato_cesta_servico (
    id bigint NOT NULL,
    tarifa numeric NOT NULL,
    franquia integer NOT NULL,
    periodicidade smallint NOT NULL,
    contrato_id bigint NOT NULL,
    tarifa_origem_id bigint NOT NULL,
    tipo_operacao_cesta_servico_id bigint NOT NULL
);
 /   DROP TABLE public.item_contrato_cesta_servico;
       public         postgres    false    3            �           1259    17297 "   item_contrato_cesta_servico_id_seq    SEQUENCE     �   CREATE SEQUENCE public.item_contrato_cesta_servico_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 9   DROP SEQUENCE public.item_contrato_cesta_servico_id_seq;
       public       postgres    false    3            �           1259    17299 #   item_contrato_cesta_servico_id_seq1    SEQUENCE     �   CREATE SEQUENCE public.item_contrato_cesta_servico_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 :   DROP SEQUENCE public.item_contrato_cesta_servico_id_seq1;
       public       postgres    false    448    3            �           0    0 #   item_contrato_cesta_servico_id_seq1    SEQUENCE OWNED BY     j   ALTER SEQUENCE public.item_contrato_cesta_servico_id_seq1 OWNED BY public.item_contrato_cesta_servico.id;
            public       postgres    false    450            �           1259    17301    item_contrato_cobranca_id_seq    SEQUENCE     �   CREATE SEQUENCE public.item_contrato_cobranca_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.item_contrato_cobranca_id_seq;
       public       postgres    false    3            �           1259    17303    item_contrato_cobranca    TABLE       CREATE TABLE public.item_contrato_cobranca (
    id bigint DEFAULT nextval('public.item_contrato_cobranca_id_seq'::regclass) NOT NULL,
    tarifa numeric NOT NULL,
    movimento_retorno_cobranca_id bigint NOT NULL,
    ocorrencia_cobranca_id bigint,
    contrato_id bigint NOT NULL
);
 *   DROP TABLE public.item_contrato_cobranca;
       public         postgres    false    451    3            �           1259    17310    item_contrato_numerario    TABLE     �   CREATE TABLE public.item_contrato_numerario (
    id integer NOT NULL,
    tarifa numeric,
    franquia integer,
    periodicidade smallint,
    tipo_operacao_numerario_id bigint NOT NULL,
    contrato_id bigint NOT NULL
);
 +   DROP TABLE public.item_contrato_numerario;
       public         postgres    false    3            �           1259    17316    item_contrato_numerario_id_seq    SEQUENCE     �   CREATE SEQUENCE public.item_contrato_numerario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 5   DROP SEQUENCE public.item_contrato_numerario_id_seq;
       public       postgres    false    453    3            �           0    0    item_contrato_numerario_id_seq    SEQUENCE OWNED BY     a   ALTER SEQUENCE public.item_contrato_numerario_id_seq OWNED BY public.item_contrato_numerario.id;
            public       postgres    false    454            �           1259    17318    item_contrato_numerario_loja    TABLE     �   CREATE TABLE public.item_contrato_numerario_loja (
    item_contrato_numerario_id bigint NOT NULL,
    loja_id bigint NOT NULL
);
 0   DROP TABLE public.item_contrato_numerario_loja;
       public         postgres    false    3            �           1259    17321    item_contrato_pagamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.item_contrato_pagamento_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 5   DROP SEQUENCE public.item_contrato_pagamento_id_seq;
       public       postgres    false    3            �           1259    17323    item_contrato_pagamento    TABLE       CREATE TABLE public.item_contrato_pagamento (
    id bigint DEFAULT nextval('public.item_contrato_pagamento_id_seq'::regclass) NOT NULL,
    tarifa_padrao numeric NOT NULL,
    tarifa_negociada numeric NOT NULL,
    contrato_id bigint NOT NULL,
    forma_pagamento_id bigint NOT NULL
);
 +   DROP TABLE public.item_contrato_pagamento;
       public         postgres    false    456    3            �           1259    17330 !   item_grupo_lancamento_fluxo_caixa    TABLE     �   CREATE TABLE public.item_grupo_lancamento_fluxo_caixa (
    id bigint NOT NULL,
    nome character varying(60) NOT NULL,
    grupo_lancamento_id bigint NOT NULL
);
 5   DROP TABLE public.item_grupo_lancamento_fluxo_caixa;
       public         postgres    false    3            �           1259    17333 (   item_grupo_lancamento_fluxo_caixa_id_seq    SEQUENCE     �   CREATE SEQUENCE public.item_grupo_lancamento_fluxo_caixa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ?   DROP SEQUENCE public.item_grupo_lancamento_fluxo_caixa_id_seq;
       public       postgres    false    3            �           1259    34672    lancamento_auxiliar_cash    TABLE     �  CREATE TABLE public.lancamento_auxiliar_cash (
    id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    chave_lancamento character varying NOT NULL,
    valor_lancamento numeric NOT NULL,
    data_lancamento date NOT NULL,
    loja_id bigint NOT NULL,
    descricao_completa character varying(255) NOT NULL,
    categoria_lancamento_id bigint,
    vinculo_categoria_cash_id bigint
);
 ,   DROP TABLE public.lancamento_auxiliar_cash;
       public         postgres    false    3            �           1259    34695    lancamento_auxiliar_cash_id_seq    SEQUENCE     �   CREATE SEQUENCE public.lancamento_auxiliar_cash_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.lancamento_auxiliar_cash_id_seq;
       public       bv_postgres    false    3            �           1259    17335    lancamento_debito    TABLE     �   CREATE TABLE public.lancamento_debito (
    id bigint NOT NULL,
    optantes_debito_id bigint NOT NULL,
    data_vencimento date NOT NULL,
    valor double precision NOT NULL,
    codigo_movimento integer
);
 %   DROP TABLE public.lancamento_debito;
       public         postgres    false    3            �           1259    17338    lancamento_debito_id_seq    SEQUENCE     �   CREATE SEQUENCE public.lancamento_debito_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.lancamento_debito_id_seq;
       public       postgres    false    3            �           1259    17340    lancamento_debito_remessa    TABLE     �   CREATE TABLE public.lancamento_debito_remessa (
    lancamento_debito_id bigint NOT NULL,
    controle_remessa_optantes_debito_id bigint
);
 -   DROP TABLE public.lancamento_debito_remessa;
       public         postgres    false    3            �           1259    17343    lancamento_duplicado_id_seq    SEQUENCE     �   CREATE SEQUENCE public.lancamento_duplicado_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.lancamento_duplicado_id_seq;
       public       postgres    false    3            �           1259    17345    lancamento_duplicado    TABLE     4  CREATE TABLE public.lancamento_duplicado (
    id bigint DEFAULT nextval('public.lancamento_duplicado_id_seq'::regclass) NOT NULL,
    lancamento_id bigint NOT NULL,
    controle_upload_arquivo_id bigint NOT NULL,
    linha_processada bigint,
    data_processamento date NOT NULL,
    tipo_arquivo bigint
);
 (   DROP TABLE public.lancamento_duplicado;
       public         postgres    false    463    3            �           1259    17349    lancamento_fluxo_caixa    TABLE     �  CREATE TABLE public.lancamento_fluxo_caixa (
    id bigint NOT NULL,
    contalancamento bytea,
    data timestamp without time zone NOT NULL,
    descricao character varying(30) NOT NULL,
    pago boolean,
    valor double precision NOT NULL,
    forma_pagamnto_id bigint NOT NULL,
    conta_lancamento_id bigint,
    empresa_id bigint,
    item_grupo_lancamento_id bigint NOT NULL
);
 *   DROP TABLE public.lancamento_fluxo_caixa;
       public         postgres    false    3            �           1259    17355    lancamento_new    TABLE     ?  CREATE TABLE public.lancamento_new (
    convenio_id bigint NOT NULL,
    data_lancamento date NOT NULL,
    valor numeric NOT NULL,
    tipo integer NOT NULL,
    nsa integer,
    descricao_id bigint NOT NULL,
    id bigint NOT NULL,
    nome_arquivo character varying NOT NULL,
    chave_lancamento character varying NOT NULL,
    empresa_id bigint NOT NULL,
    banco_id bigint NOT NULL,
    usuario_logado_id bigint,
    descricao_detalhada character varying(100) NOT NULL,
    campo_identificador character varying(100) NOT NULL,
    conciliado boolean,
    linha_processada bigint,
    hash_conteudo_arquivo character varying(100),
    data_arquivo_geracao character varying(50),
    desabilitado_webservice boolean,
    historico_lancamento character varying(39),
    observacao_motivo character varying(40),
    fitid character varying(25),
    conta_id integer NOT NULL,
    tipo_arquivo integer,
    chave_lancamento_new text,
    status integer,
    data_processamento date DEFAULT CURRENT_DATE,
    editado boolean,
    descricao_detalhada_completa character varying(255)
);
 "   DROP TABLE public.lancamento_new;
       public         postgres    false    3            �           1259    17362    lancamento_new_id_seq    SEQUENCE     ~   CREATE SEQUENCE public.lancamento_new_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public.lancamento_new_id_seq;
       public       postgres    false    3            �           1259    17364    layout_campo    TABLE     �   CREATE TABLE public.layout_campo (
    id bigint NOT NULL,
    fim integer NOT NULL,
    inicio integer NOT NULL,
    nome character varying(60) NOT NULL,
    tipoarrecadacao integer NOT NULL,
    banco_id bigint
);
     DROP TABLE public.layout_campo;
       public         postgres    false    3            �           1259    17367    layout_campo_id_seq    SEQUENCE     �   CREATE SEQUENCE public.layout_campo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2061584294
    CACHE 1;
 *   DROP SEQUENCE public.layout_campo_id_seq;
       public       postgres    false    3            �           1259    17369    layout_campo_pagamento    TABLE     #  CREATE TABLE public.layout_campo_pagamento (
    id bigint NOT NULL,
    fim integer NOT NULL,
    inicio integer NOT NULL,
    nome character varying(60) NOT NULL,
    tipo_arquivo_pagamento_flexivel integer NOT NULL,
    empresa_id integer NOT NULL,
    compromisso_id integer NOT NULL
);
 *   DROP TABLE public.layout_campo_pagamento;
       public         postgres    false    3            �           1259    17372    layout_campo_pagamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.layout_campo_pagamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 4   DROP SEQUENCE public.layout_campo_pagamento_id_seq;
       public       postgres    false    3            �           1259    17374    limite_especial    TABLE     �   CREATE TABLE public.limite_especial (
    id bigint NOT NULL,
    valor numeric,
    convenio_id bigint NOT NULL,
    data_inicial date NOT NULL,
    data_final date NOT NULL,
    data_inclusao date,
    usuario_id bigint NOT NULL
);
 #   DROP TABLE public.limite_especial;
       public         postgres    false    3            �           1259    17380    limite_especial_id_seq    SEQUENCE        CREATE SEQUENCE public.limite_especial_id_seq
    START WITH 9
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.limite_especial_id_seq;
       public       postgres    false    3            �           1259    17382 
   log_acesso    TABLE       CREATE TABLE public.log_acesso (
    id integer NOT NULL,
    usuario_id integer,
    data_acesso timestamp without time zone NOT NULL,
    ip character varying(80),
    browser character varying(250),
    grupo_empresa_id integer,
    usuario_original bigint
);
    DROP TABLE public.log_acesso;
       public         postgres    false    3            �           1259    17385    log_acesso_id_seq    SEQUENCE     z   CREATE SEQUENCE public.log_acesso_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.log_acesso_id_seq;
       public       postgres    false    3            �           1259    17387    log_baixa_ftp    TABLE       CREATE TABLE public.log_baixa_ftp (
    id bigint NOT NULL,
    tipo_protocolo bigint NOT NULL,
    diretorio character varying(255) NOT NULL,
    nome_arquivo character varying(255) NOT NULL,
    mensagem_log text,
    checksum character varying(255) NOT NULL
);
 !   DROP TABLE public.log_baixa_ftp;
       public         postgres    false    3            �           1259    17393    log_baixa_ftp_id_seq    SEQUENCE     }   CREATE SEQUENCE public.log_baixa_ftp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.log_baixa_ftp_id_seq;
       public       postgres    false    3            �           1259    17395    log_erro_catalogador_id_seq    SEQUENCE     �   CREATE SEQUENCE public.log_erro_catalogador_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.log_erro_catalogador_id_seq;
       public       postgres    false    3            �           1259    17397    log_erro_catalogador    TABLE     ;  CREATE TABLE public.log_erro_catalogador (
    id bigint DEFAULT nextval('public.log_erro_catalogador_id_seq'::regclass) NOT NULL,
    data timestamp without time zone NOT NULL,
    nomearquivo character varying(255) NOT NULL,
    erro text NOT NULL,
    diretorio_origem_arquivo character varying(500) NOT NULL
);
 (   DROP TABLE public.log_erro_catalogador;
       public         postgres    false    478    3            �           0    0 4   COLUMN log_erro_catalogador.diretorio_origem_arquivo    COMMENT     �   COMMENT ON COLUMN public.log_erro_catalogador.diretorio_origem_arquivo IS 'Diretório onde estava o arquivo antes da catalogar.';
            public       postgres    false    479            �           1259    17404    log_erro_processador    TABLE     �   CREATE TABLE public.log_erro_processador (
    id integer NOT NULL,
    data timestamp with time zone NOT NULL,
    erro character varying NOT NULL,
    nome_arquivo character varying(255) NOT NULL,
    empresa_id integer,
    processador integer
);
 (   DROP TABLE public.log_erro_processador;
       public         postgres    false    3            �           1259    17410    log_erro_processador_id_seq    SEQUENCE     �   CREATE SEQUENCE public.log_erro_processador_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.log_erro_processador_id_seq;
       public       postgres    false    3            �           1259    17412    loja    TABLE     V  CREATE TABLE public.loja (
    id integer NOT NULL,
    codigo character varying,
    descricao character varying,
    descricao_equivalente character varying,
    empresa_id bigint NOT NULL,
    cnpj character varying(50),
    razao_social character varying(100),
    email character varying(100),
    telefone character varying(50),
    celular character varying(50),
    ativa boolean DEFAULT true,
    cep character varying(50),
    logradouro character varying(100),
    complemento character varying(100),
    bairro character varying(100),
    estado_id bigint,
    cidade_id bigint,
    numero character varying,
    empresa_transportadora_id integer,
    codigo_equipamento character varying,
    valor_segurado numeric,
    gerente_loja character varying,
    gerente_loja_email character varying,
    gerente_loja_celular character varying
);
    DROP TABLE public.loja;
       public         postgres    false    3            �           1259    17419    loja_id_seq    SEQUENCE     �   CREATE SEQUENCE public.loja_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 "   DROP SEQUENCE public.loja_id_seq;
       public       postgres    false    3    482            �           0    0    loja_id_seq    SEQUENCE OWNED BY     ;   ALTER SEQUENCE public.loja_id_seq OWNED BY public.loja.id;
            public       postgres    false    483            �           1259    17421    lojas_com_coleta_excedente    TABLE     W  CREATE TABLE public.lojas_com_coleta_excedente (
    id integer NOT NULL,
    data_recolhimento date NOT NULL,
    descricao character varying NOT NULL,
    data_hora_acao timestamp without time zone,
    status_coleta integer NOT NULL,
    loja_id bigint NOT NULL,
    recolhimento_transportadora_id bigint NOT NULL,
    usuario_id bigint
);
 .   DROP TABLE public.lojas_com_coleta_excedente;
       public         postgres    false    3            �           1259    17427 !   lojas_com_coleta_excedente_id_seq    SEQUENCE     �   CREATE SEQUENCE public.lojas_com_coleta_excedente_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 8   DROP SEQUENCE public.lojas_com_coleta_excedente_id_seq;
       public       postgres    false    3    484            �           0    0 !   lojas_com_coleta_excedente_id_seq    SEQUENCE OWNED BY     g   ALTER SEQUENCE public.lojas_com_coleta_excedente_id_seq OWNED BY public.lojas_com_coleta_excedente.id;
            public       postgres    false    485            �           1259    17429    lote_boleto    TABLE       CREATE TABLE public.lote_boleto (
    id bigint NOT NULL,
    pagamento_id bigint NOT NULL,
    boleto_id bigint NOT NULL,
    valor numeric,
    valor_efetivado numeric,
    data_efetivado date,
    ocorrencia character varying,
    remessa bigint,
    retorno bigint,
    status integer,
    valor_desconto numeric,
    valor_multa numeric,
    autenticacao character varying,
    seu_numero character varying,
    descricao_beneficiario character varying,
    pagar boolean,
    tipo_movimento integer NOT NULL
);
    DROP TABLE public.lote_boleto;
       public         postgres    false    3            �           1259    17435    lote_boleto_id_seq    SEQUENCE     {   CREATE SEQUENCE public.lote_boleto_id_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.lote_boleto_id_seq;
       public       postgres    false    3            �           1259    17437 
   lote_carne    TABLE     �   CREATE TABLE public.lote_carne (
    id bigint NOT NULL,
    titulo_id bigint NOT NULL,
    titulo_associado_id bigint NOT NULL,
    convenio_id bigint NOT NULL
);
    DROP TABLE public.lote_carne;
       public         postgres    false    3            �           1259    17440    lote_carne_id_seq    SEQUENCE     |   CREATE SEQUENCE public.lote_carne_id_seq
    START WITH 114
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.lote_carne_id_seq;
       public       postgres    false    3            �           1259    17442    lote_favorecido    TABLE     �  CREATE TABLE public.lote_favorecido (
    id bigint NOT NULL,
    pagamento_id bigint NOT NULL,
    favorecido_id bigint NOT NULL,
    valor numeric,
    valor_efetivado numeric,
    data_efetivado date,
    ocorrencia character varying,
    remessa bigint,
    retorno bigint,
    status integer,
    pagar boolean,
    num_doc_banco character varying(20),
    forma_pagamento_id bigint,
    agencia character varying(5),
    dv_agencia character varying(1),
    conta character varying(12),
    dv_conta character varying(1),
    banco_id bigint,
    seu_numero character varying,
    autenticacao character varying,
    codigo_complemento_servico character varying(2),
    dv_agencia_conta character varying(1),
    codigo_favorecido character varying(15),
    operacao character varying(3),
    tipo_movimento integer NOT NULL,
    favorecido_conta_id bigint,
    favorecido_id_old bigint,
    valor_tarifa numeric,
    cod_identificacao_lote character varying,
    aviso character varying,
    chave_pix_id bigint
);
 #   DROP TABLE public.lote_favorecido;
       public         postgres    false    3            �           1259    17448    lote_favorecido_aud    TABLE        CREATE TABLE public.lote_favorecido_aud (
    id bigint NOT NULL,
    rev bigint NOT NULL,
    revtype smallint,
    pagamento_id bigint,
    favorecido_id bigint,
    valor numeric,
    seu_numero character varying,
    valor_efetivado numeric,
    num_doc_banco character varying,
    data_efetivado date,
    ocorrencia character varying,
    status integer,
    pagar boolean,
    operacao character varying(3),
    tipo_movimento integer,
    favorecido_conta_id bigint,
    remessa bigint,
    retorno bigint,
    autenticacao character varying,
    codigo_favorecido character varying,
    codigo_complemento_servico character varying,
    valor_tarifa numeric,
    data_tarifa date,
    cod_identificacao_lote character varying,
    aviso character varying
);
 '   DROP TABLE public.lote_favorecido_aud;
       public         postgres    false    3            �           1259    17454    lote_favorecido_id_seq    SEQUENCE        CREATE SEQUENCE public.lote_favorecido_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.lote_favorecido_id_seq;
       public       postgres    false    3            �           1259    17456    lote_pag_aux    TABLE     �   CREATE TABLE public.lote_pag_aux (
    id bigint NOT NULL,
    pagamento_id bigint NOT NULL,
    lote_favorecido_id bigint NOT NULL,
    num_doc_empresa character varying
);
     DROP TABLE public.lote_pag_aux;
       public         postgres    false    3            �           1259    17462    lote_pag_aux_id_seq    SEQUENCE     |   CREATE SEQUENCE public.lote_pag_aux_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.lote_pag_aux_id_seq;
       public       postgres    false    3            �           1259    17464    mensagem_arquivo    TABLE     �  CREATE TABLE public.mensagem_arquivo (
    id bigint NOT NULL,
    mensagem character varying NOT NULL,
    numero_linha bigint,
    nome_registro character varying,
    nome_zona character varying NOT NULL,
    nome_campo character varying NOT NULL,
    inicio_campo bigint NOT NULL,
    fim_campo bigint NOT NULL,
    descricao_campo character varying NOT NULL,
    controle_upload_arquivo_id bigint NOT NULL,
    texto_linha character varying
);
 $   DROP TABLE public.mensagem_arquivo;
       public         postgres    false    3            �           1259    17470    mensagem_arquivo_id_seq    SEQUENCE     �   CREATE SEQUENCE public.mensagem_arquivo_id_seq
    START WITH 4656
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.mensagem_arquivo_id_seq;
       public       postgres    false    3            �           1259    17472    mensagem_titulo    TABLE     �   CREATE TABLE public.mensagem_titulo (
    id bigint NOT NULL,
    ativo boolean NOT NULL,
    mensagem character varying(40) NOT NULL,
    tipo_mensagem_titulo integer NOT NULL,
    empresa_id bigint NOT NULL
);
 #   DROP TABLE public.mensagem_titulo;
       public         postgres    false    3            �           1259    17475    mensagem_titulo_id_seq    SEQUENCE        CREATE SEQUENCE public.mensagem_titulo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.mensagem_titulo_id_seq;
       public       postgres    false    3            �           1259    17477    modalidade_contrato_bancario    TABLE     |   CREATE TABLE public.modalidade_contrato_bancario (
    id bigint NOT NULL,
    descricao character varying(100) NOT NULL
);
 0   DROP TABLE public.modalidade_contrato_bancario;
       public         postgres    false    3            �           1259    17480 #   modalidade_contrato_bancario_id_seq    SEQUENCE     �   CREATE SEQUENCE public.modalidade_contrato_bancario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 :   DROP SEQUENCE public.modalidade_contrato_bancario_id_seq;
       public       postgres    false    3            �           1259    17482    modulo    TABLE     7   CREATE TABLE public.modulo (
    id bigint NOT NULL
);
    DROP TABLE public.modulo;
       public         postgres    false    3            �           1259    17485    modulo_id_seq    SEQUENCE     v   CREATE SEQUENCE public.modulo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE public.modulo_id_seq;
       public       postgres    false    3            �           1259    17487    movimento_pagamento    TABLE     �   CREATE TABLE public.movimento_pagamento (
    id bigint NOT NULL,
    data timestamp without time zone,
    nsa bigint NOT NULL,
    tipo_movimento integer NOT NULL,
    pagamento_id bigint NOT NULL
);
 '   DROP TABLE public.movimento_pagamento;
       public         postgres    false    3            �           1259    17490    movimento_pagamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.movimento_pagamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.movimento_pagamento_id_seq;
       public       postgres    false    3            �           1259    17492    movimento_remessa_cobranca    TABLE     �   CREATE TABLE public.movimento_remessa_cobranca (
    id bigint NOT NULL,
    descricao character varying NOT NULL,
    codigo character varying(2) NOT NULL,
    banco_id bigint NOT NULL,
    tipo_movimento_remessa integer,
    ativo boolean NOT NULL
);
 .   DROP TABLE public.movimento_remessa_cobranca;
       public         postgres    false    3            �           1259    17498 !   movimento_remessa_cobranca_id_seq    SEQUENCE     �   CREATE SEQUENCE public.movimento_remessa_cobranca_id_seq
    START WITH 37
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 8   DROP SEQUENCE public.movimento_remessa_cobranca_id_seq;
       public       postgres    false    3            �           1259    17500    movimento_retorno_cobranca    TABLE       CREATE TABLE public.movimento_retorno_cobranca (
    id bigint NOT NULL,
    descricao character varying NOT NULL,
    codigo character varying(2) NOT NULL,
    tipo_movimento_retorno integer,
    layout integer NOT NULL,
    gera_tarifa boolean DEFAULT false
);
 .   DROP TABLE public.movimento_retorno_cobranca;
       public         postgres    false    3            �           1259    17507 !   movimento_retorno_cobranca_id_seq    SEQUENCE     �   CREATE SEQUENCE public.movimento_retorno_cobranca_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 8   DROP SEQUENCE public.movimento_retorno_cobranca_id_seq;
       public       postgres    false    3            �           1259    17509    notificacao    TABLE       CREATE TABLE public.notificacao (
    id integer NOT NULL,
    data_inicio date NOT NULL,
    data_fim date NOT NULL,
    conteudo text NOT NULL,
    titulo character varying(50) NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    ativo boolean NOT NULL
);
    DROP TABLE public.notificacao;
       public         postgres    false    3            �           1259    17515    notificacao_destinatario    TABLE       CREATE TABLE public.notificacao_destinatario (
    id integer NOT NULL,
    notificacao_id bigint NOT NULL,
    modulo_notificado bigint,
    grupo_empresa_notificado_id bigint,
    empresa_notificado_id bigint,
    perfil_notificado_id bigint,
    usuario_notificado_id bigint
);
 ,   DROP TABLE public.notificacao_destinatario;
       public         postgres    false    3            �           1259    17518    notificacao_destinatario_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notificacao_destinatario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.notificacao_destinatario_id_seq;
       public       postgres    false    510    3            �           0    0    notificacao_destinatario_id_seq    SEQUENCE OWNED BY     c   ALTER SEQUENCE public.notificacao_destinatario_id_seq OWNED BY public.notificacao_destinatario.id;
            public       postgres    false    511                        1259    17520    notificacao_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notificacao_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.notificacao_id_seq;
       public       postgres    false    509    3            �           0    0    notificacao_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.notificacao_id_seq OWNED BY public.notificacao.id;
            public       postgres    false    512                       1259    17522    notificacao_pagamento    TABLE       CREATE TABLE public.notificacao_pagamento (
    id integer NOT NULL,
    banco_id bigint NOT NULL,
    pagamento_id bigint NOT NULL,
    data_envio timestamp without time zone,
    status_pagamento integer NOT NULL,
    tipo_notificacao character varying(100)
);
 )   DROP TABLE public.notificacao_pagamento;
       public         postgres    false    3                       1259    17525    notificacao_pagamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notificacao_pagamento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.notificacao_pagamento_id_seq;
       public       postgres    false    3    513            �           0    0    notificacao_pagamento_id_seq    SEQUENCE OWNED BY     ]   ALTER SEQUENCE public.notificacao_pagamento_id_seq OWNED BY public.notificacao_pagamento.id;
            public       postgres    false    514                       1259    17527    notificacao_usuario    TABLE     �   CREATE TABLE public.notificacao_usuario (
    id bigint NOT NULL,
    notificacao_id bigint,
    usuario_notificado_id bigint NOT NULL,
    data_cadastro timestamp without time zone NOT NULL
);
 '   DROP TABLE public.notificacao_usuario;
       public         postgres    false    3                       1259    17530    notificacao_usuario_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notificacao_usuario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.notificacao_usuario_id_seq;
       public       postgres    false    515    3            �           0    0    notificacao_usuario_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.notificacao_usuario_id_seq OWNED BY public.notificacao_usuario.id;
            public       postgres    false    516                       1259    17532 	   numerario    TABLE     �  CREATE TABLE public.numerario (
    id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    loja_id bigint NOT NULL,
    controle_upload_arquivo_id bigint NOT NULL,
    data date NOT NULL,
    valor numeric(15,2) NOT NULL,
    chave character varying,
    status_conciliacao_recolhimento integer DEFAULT 0,
    data_conciliacao_numerario date,
    tipo_divergencia smallint,
    usuario_conciliou_id bigint,
    grupo_numerario_id integer,
    divergencia character varying
);
    DROP TABLE public.numerario;
       public         postgres    false    3                       1259    17539    numerario_duplicidade    TABLE     �   CREATE TABLE public.numerario_duplicidade (
    id bigint NOT NULL,
    numerario_id bigint NOT NULL,
    controle_upload_arquivo_id bigint NOT NULL
);
 )   DROP TABLE public.numerario_duplicidade;
       public         postgres    false    3                       1259    17542    numerario_duplicidade_id_seq    SEQUENCE     �   CREATE SEQUENCE public.numerario_duplicidade_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.numerario_duplicidade_id_seq;
       public       postgres    false    518    3            �           0    0    numerario_duplicidade_id_seq    SEQUENCE OWNED BY     ]   ALTER SEQUENCE public.numerario_duplicidade_id_seq OWNED BY public.numerario_duplicidade.id;
            public       postgres    false    519                       1259    17544    numerario_id_seq    SEQUENCE     y   CREATE SEQUENCE public.numerario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.numerario_id_seq;
       public       postgres    false    517    3            �           0    0    numerario_id_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.numerario_id_seq OWNED BY public.numerario.id;
            public       postgres    false    520            	           1259    17546    numerario_recolhimento    TABLE     �   CREATE TABLE public.numerario_recolhimento (
    numerario_id bigint NOT NULL,
    recolhimento_transportadora_id bigint NOT NULL
);
 *   DROP TABLE public.numerario_recolhimento;
       public         postgres    false    3            
           1259    17549 
   ocorrencia    TABLE     �   CREATE TABLE public.ocorrencia (
    id bigint NOT NULL,
    descricao character varying NOT NULL,
    codigo character varying(2) NOT NULL,
    banco_id bigint,
    layout integer
);
    DROP TABLE public.ocorrencia;
       public         postgres    false    3                       1259    17555    ocorrencia_cobranca    TABLE     �   CREATE TABLE public.ocorrencia_cobranca (
    id bigint NOT NULL,
    codigo character varying(2) NOT NULL,
    descricao character varying(255) NOT NULL,
    layout integer NOT NULL,
    tipo_movimento_retorno integer NOT NULL
);
 '   DROP TABLE public.ocorrencia_cobranca;
       public         postgres    false    3                       1259    17558    ocorrencia_cobranca_id_seq    SEQUENCE     �   CREATE SEQUENCE public.ocorrencia_cobranca_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.ocorrencia_cobranca_id_seq;
       public       postgres    false    3                       1259    17560    ocorrencia_id_seq    SEQUENCE     z   CREATE SEQUENCE public.ocorrencia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.ocorrencia_id_seq;
       public       postgres    false    3                       1259    17562 *   ocorrencia_retorno_cobranca_detalhe_id_seq    SEQUENCE     �   CREATE SEQUENCE public.ocorrencia_retorno_cobranca_detalhe_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 A   DROP SEQUENCE public.ocorrencia_retorno_cobranca_detalhe_id_seq;
       public       postgres    false    3                       1259    17564 #   ocorrencia_retorno_cobranca_detalhe    TABLE     �   CREATE TABLE public.ocorrencia_retorno_cobranca_detalhe (
    id bigint DEFAULT nextval('public.ocorrencia_retorno_cobranca_detalhe_id_seq'::regclass) NOT NULL,
    ocorrencia_cobranca_id bigint,
    titulo_retorno_id bigint
);
 7   DROP TABLE public.ocorrencia_retorno_cobranca_detalhe;
       public         postgres    false    526    3                       1259    17568    optantes_debito    TABLE     Y  CREATE TABLE public.optantes_debito (
    id bigint NOT NULL,
    id_cliente character varying(25) NOT NULL,
    data date NOT NULL,
    banco_id bigint NOT NULL,
    agencia character varying(4) NOT NULL,
    conta character varying(7) NOT NULL,
    dv_conta character varying(1) NOT NULL,
    ativo boolean NOT NULL,
    convenio_id bigint
);
 #   DROP TABLE public.optantes_debito;
       public         postgres    false    3                       1259    17571    optantes_debito_id_seq    SEQUENCE     �   CREATE SEQUENCE public.optantes_debito_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 -   DROP SEQUENCE public.optantes_debito_id_seq;
       public       postgres    false    3                       1259    17573    optantes_debito_remessa    TABLE     �   CREATE TABLE public.optantes_debito_remessa (
    optantes_debito_id bigint NOT NULL,
    controle_remessa_optantes_debito_id bigint
);
 +   DROP TABLE public.optantes_debito_remessa;
       public         postgres    false    3                       1259    17576 	   pagamento    TABLE     �  CREATE TABLE public.pagamento (
    id bigint NOT NULL,
    status integer,
    tipo_favorecido integer,
    data_criado date NOT NULL,
    data_pagamento date NOT NULL,
    compromisso_id bigint,
    valor_total numeric,
    ocorrencia_retorno character varying,
    web_service_id character varying(20),
    data_upload_remessa date,
    nome_arquivo_remessa character varying,
    nsa_remessa bigint,
    convenio_conta_id bigint NOT NULL,
    justificativa character varying(40),
    cod_identificacao_lote character varying,
    data_tarifa date,
    valor_bruto numeric,
    ativo boolean DEFAULT true NOT NULL,
    nome_arquivo_retorno text,
    comprovante_email_enviado boolean DEFAULT false NOT NULL,
    pix boolean DEFAULT false
);
    DROP TABLE public.pagamento;
       public         postgres    false    3            �           0    0    COLUMN pagamento.valor_total    COMMENT     k   COMMENT ON COLUMN public.pagamento.valor_total IS 'Referente ao valor do pagamento com juros e descontos';
            public       postgres    false    531            �           0    0    COLUMN pagamento.valor_bruto    COMMENT     k   COMMENT ON COLUMN public.pagamento.valor_bruto IS 'Referente ao valor do pagamento sem juros e descontos';
            public       postgres    false    531                       1259    17585    pagamento_arquivo    TABLE     �   CREATE TABLE public.pagamento_arquivo (
    id bigint NOT NULL,
    pagamento_id bigint NOT NULL,
    arquivo_id bigint NOT NULL
);
 %   DROP TABLE public.pagamento_arquivo;
       public         postgres    false    3                       1259    17588    pagamento_arquivo_id_seq    SEQUENCE     �   CREATE SEQUENCE public.pagamento_arquivo_id_seq
    START WITH 149
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 /   DROP SEQUENCE public.pagamento_arquivo_id_seq;
       public       postgres    false    3                       1259    17590    pagamento_aud    TABLE     Q  CREATE TABLE public.pagamento_aud (
    id bigint NOT NULL,
    rev bigint NOT NULL,
    revtype smallint,
    status integer,
    data_criado date,
    data_pagamento date,
    valor_total numeric,
    ocorrencia_retorno character varying,
    data_upload_remessa timestamp without time zone,
    justificativa character varying(40)
);
 !   DROP TABLE public.pagamento_aud;
       public         postgres    false    3                       1259    17596    pagamento_aviso    TABLE     �   CREATE TABLE public.pagamento_aviso (
    id bigint NOT NULL,
    pagamento_id bigint NOT NULL,
    aviso character varying NOT NULL,
    data_aviso timestamp with time zone DEFAULT now() NOT NULL
);
 #   DROP TABLE public.pagamento_aviso;
       public         postgres    false    3                       1259    17603    pagamento_aviso_id_seq    SEQUENCE        CREATE SEQUENCE public.pagamento_aviso_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.pagamento_aviso_id_seq;
       public       postgres    false    3                       1259    17605    pagamento_id_seq    SEQUENCE     y   CREATE SEQUENCE public.pagamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.pagamento_id_seq;
       public       postgres    false    3                       1259    17607    pagamento_tarifa    VIEW       CREATE VIEW public.pagamento_tarifa AS
 SELECT p.id,
    p.status,
    p.tipo_favorecido,
    p.data_pagamento,
    e.id AS empresa_id,
    e.nome_fantasia AS empresa,
    cv.id AS convenio_id,
    cv.codigo_convenio AS convenio,
    c.id AS conta_id,
    c.agencia,
    c.dv_agencia,
    c.conta,
    c.dv_conta,
    p.nsa_remessa,
    p.valor_total,
    p.data_tarifa,
        CASE
            WHEN ((p.tipo_favorecido = 0) OR (p.tipo_favorecido = 1)) THEN ( SELECT sum(l.valor_tarifa) AS sum
               FROM public.lote_favorecido l
              WHERE ((l.pagamento_id = p.id) AND (l.status = 6)))
            WHEN ((p.tipo_favorecido = 2) OR (p.tipo_favorecido = 6)) THEN ( SELECT sum(b.valor_tarifa) AS sum
               FROM public.boleto b
              WHERE ((b.pagamento_id = p.id) AND (b.status = 6)))
            ELSE NULL::numeric
        END AS valor_tarifa
   FROM (((((public.pagamento p
     JOIN public.convenio_conta cc ON ((cc.id = p.convenio_conta_id)))
     JOIN public.conta c ON ((c.id = cc.conta_id)))
     JOIN public.convenio cv ON ((cv.id = cc.convenio_id)))
     JOIN public.empresa e ON ((e.id = cv.empresa_id)))
     CROSS JOIN public.contrato ct)
  WHERE ((p.status = ANY (ARRAY[6, 8])) AND (ct.convenio_id = cv.id) AND (ct.conta_id = c.id));
 #   DROP VIEW public.pagamento_tarifa;
       public       postgres    false    490    490    531    531    531    531    531    531    531    253    253    253    296    296    296    296    296    307    307    334    334    334    338    531    338    338    360    360    490    3                       1259    17612    parametro_autorizacao    TABLE     0  CREATE TABLE public.parametro_autorizacao (
    id bigint NOT NULL,
    convenio_id bigint NOT NULL,
    compromisso_id bigint,
    quantidade_autorizacao integer,
    aut_cruzada boolean,
    aut_grupo boolean,
    certificado_digital boolean DEFAULT false,
    aut_dependencia boolean DEFAULT false
);
 )   DROP TABLE public.parametro_autorizacao;
       public         postgres    false    3                       1259    17617    parametro_autorizacao_id_seq    SEQUENCE     �   CREATE SEQUENCE public.parametro_autorizacao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 3   DROP SEQUENCE public.parametro_autorizacao_id_seq;
       public       postgres    false    3                       1259    17619    pendencia_nsa    TABLE     �   CREATE TABLE public.pendencia_nsa (
    id bigint NOT NULL,
    nsa bigint NOT NULL,
    resolvido boolean NOT NULL,
    compromisso_id bigint NOT NULL,
    convenio_id bigint NOT NULL,
    tipo_arquivo integer NOT NULL
);
 !   DROP TABLE public.pendencia_nsa;
       public         postgres    false    3                       1259    17622    pendencia_nsa_id_seq    SEQUENCE     }   CREATE SEQUENCE public.pendencia_nsa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.pendencia_nsa_id_seq;
       public       postgres    false    3                       1259    17624    perfil    TABLE     |   CREATE TABLE public.perfil (
    id bigint NOT NULL,
    ativo boolean NOT NULL,
    nome character varying(40) NOT NULL
);
    DROP TABLE public.perfil;
       public         postgres    false    3                        1259    17627 
   perfil_aud    TABLE     �   CREATE TABLE public.perfil_aud (
    id bigint,
    rev bigint NOT NULL,
    revtype smallint,
    nome character varying,
    ativo boolean
);
    DROP TABLE public.perfil_aud;
       public         postgres    false    3            !           1259    17633    perfil_id_seq    SEQUENCE     v   CREATE SEQUENCE public.perfil_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE public.perfil_id_seq;
       public       postgres    false    3            "           1259    17635    perfil_permissao    TABLE     k   CREATE TABLE public.perfil_permissao (
    perfil_id bigint NOT NULL,
    permissoes_id bigint NOT NULL
);
 $   DROP TABLE public.perfil_permissao;
       public         postgres    false    3            #           1259    17638 	   permissao    TABLE     �   CREATE TABLE public.permissao (
    id bigint NOT NULL,
    chave character varying(80) NOT NULL,
    descricao character varying(80) NOT NULL,
    grupopermissao_id bigint NOT NULL
);
    DROP TABLE public.permissao;
       public         postgres    false    3            $           1259    17641    permissao_id_seq    SEQUENCE     y   CREATE SEQUENCE public.permissao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.permissao_id_seq;
       public       postgres    false    3            %           1259    17643    permissao_ip    TABLE     r   CREATE TABLE public.permissao_ip (
    id bigint NOT NULL,
    ip character varying(30),
    usuario_id bigint
);
     DROP TABLE public.permissao_ip;
       public         postgres    false    3            &           1259    17646    permissao_ip_seq    SEQUENCE     y   CREATE SEQUENCE public.permissao_ip_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.permissao_ip_seq;
       public       postgres    false    3            �           1259    35394 -   pre_controle_execucao_conciliacao_bancaria_v2    TABLE     �   CREATE TABLE public.pre_controle_execucao_conciliacao_bancaria_v2 (
    id bigint NOT NULL,
    data timestamp without time zone NOT NULL,
    empresa_id bigint NOT NULL,
    valor numeric(11,2) NOT NULL,
    conta_id integer NOT NULL
);
 A   DROP TABLE public.pre_controle_execucao_conciliacao_bancaria_v2;
       public         bv_postgres    false    3            �           1259    35392 4   pre_controle_execucao_conciliacao_bancaria_v2_id_seq    SEQUENCE     �   CREATE SEQUENCE public.pre_controle_execucao_conciliacao_bancaria_v2_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 K   DROP SEQUENCE public.pre_controle_execucao_conciliacao_bancaria_v2_id_seq;
       public       bv_postgres    false    3            '           1259    17648    processamento_otimiza    TABLE     �  CREATE TABLE public.processamento_otimiza (
    id bigint NOT NULL,
    data timestamp without time zone NOT NULL,
    descricao character varying(60),
    nome_arquivo_aplicacoes character varying(30),
    nome_arquivo_despesas character varying(30),
    nome_arquivo_receitas character varying(30),
    empresa_id bigint NOT NULL,
    nome_arquivo_emprestimos character varying(120) NOT NULL
);
 )   DROP TABLE public.processamento_otimiza;
       public         postgres    false    3            (           1259    17651    processamento_otimiza_id_seq    SEQUENCE     �   CREATE SEQUENCE public.processamento_otimiza_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.processamento_otimiza_id_seq;
       public       postgres    false    3            )           1259    17653    produto_bancario    TABLE     �  CREATE TABLE public.produto_bancario (
    id bigint NOT NULL,
    nome character varying(60) NOT NULL,
    periodo integer NOT NULL,
    saldo_minimo double precision NOT NULL,
    taxa_rendimento double precision NOT NULL,
    taxa_retirada double precision NOT NULL,
    banco_id bigint NOT NULL,
    carencia integer,
    descricao character varying(60) NOT NULL,
    quantidade_dias integer NOT NULL,
    taxa_administracao double precision,
    taxa_cdi double precision,
    taxa_performance double precision,
    taxa_retorno double precision NOT NULL,
    taxa_saida double precision NOT NULL,
    valor_inicial double precision,
    empresa_id bigint NOT NULL
);
 $   DROP TABLE public.produto_bancario;
       public         postgres    false    3            *           1259    17656    produto_bancario_id_seq    SEQUENCE     �   CREATE SEQUENCE public.produto_bancario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.produto_bancario_id_seq;
       public       postgres    false    3            +           1259    17658    produto_id_seq    SEQUENCE     y   CREATE SEQUENCE public.produto_id_seq
    START WITH 342
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE public.produto_id_seq;
       public       postgres    false    3            ,           1259    17660    receita_processamento    TABLE     �   CREATE TABLE public.receita_processamento (
    id bigint NOT NULL,
    data date NOT NULL,
    descricao character varying(60),
    valor double precision NOT NULL,
    processamento_otimiza_id bigint NOT NULL
);
 )   DROP TABLE public.receita_processamento;
       public         postgres    false    3            -           1259    17663    receita_processamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.receita_processamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.receita_processamento_id_seq;
       public       postgres    false    3            .           1259    17665    recolhimento_transportadora    TABLE     �  CREATE TABLE public.recolhimento_transportadora (
    id integer NOT NULL,
    data_recolhimento date,
    valor_declarado numeric,
    valor_apurado numeric,
    diferenca_maior numeric,
    diferenca_menor numeric,
    descricao_loja character varying,
    quantidade_cedulas bigint,
    quantidade_moedas bigint,
    valor_moedas numeric,
    empresa_id bigint NOT NULL,
    loja_id bigint,
    controle_upload_arquivo_id bigint,
    codigo_recolhimento character varying NOT NULL,
    status_conciliacao_recolhimento integer DEFAULT 0,
    transportadora_id bigint,
    tratado boolean DEFAULT false,
    tipo_importacao character varying DEFAULT 'VIA_ARQUIVO'::character varying NOT NULL
);
 /   DROP TABLE public.recolhimento_transportadora;
       public         postgres    false    3            /           1259    17674 #   recolhimento_transportadora_analise    TABLE     J  CREATE TABLE public.recolhimento_transportadora_analise (
    id integer NOT NULL,
    controle_upload_arquivo_id bigint,
    empresa_id bigint NOT NULL,
    loja_id bigint,
    transportadora_id bigint,
    data_recolhimento date,
    valor_declarado numeric,
    valor_apurado numeric,
    diferenca_maior numeric,
    diferenca_menor numeric,
    descricao_loja character varying,
    quantidade_cedulas bigint,
    quantidade_moedas bigint,
    valor_moedas numeric,
    codigo_recolhimento character varying NOT NULL,
    tipo_importacao character varying DEFAULT 'VIA_ARQUIVO'::character varying NOT NULL,
    status_analise_recolhimento character varying NOT NULL,
    data_processamento timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    data_alteracao timestamp without time zone,
    usuario_alteracao_id bigint
);
 7   DROP TABLE public.recolhimento_transportadora_analise;
       public         postgres    false    3            0           1259    17682 *   recolhimento_transportadora_analise_id_seq    SEQUENCE     �   CREATE SEQUENCE public.recolhimento_transportadora_analise_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 A   DROP SEQUENCE public.recolhimento_transportadora_analise_id_seq;
       public       postgres    false    3    559            �           0    0 *   recolhimento_transportadora_analise_id_seq    SEQUENCE OWNED BY     y   ALTER SEQUENCE public.recolhimento_transportadora_analise_id_seq OWNED BY public.recolhimento_transportadora_analise.id;
            public       postgres    false    560            1           1259    17684 '   recolhimento_transportadora_duplicidade    TABLE     �   CREATE TABLE public.recolhimento_transportadora_duplicidade (
    id integer NOT NULL,
    recolhimento_transportadora_id bigint NOT NULL,
    controle_upload_arquivo_id bigint NOT NULL
);
 ;   DROP TABLE public.recolhimento_transportadora_duplicidade;
       public         postgres    false    3            2           1259    17687 .   recolhimento_transportadora_duplicidade_id_seq    SEQUENCE     �   CREATE SEQUENCE public.recolhimento_transportadora_duplicidade_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 E   DROP SEQUENCE public.recolhimento_transportadora_duplicidade_id_seq;
       public       postgres    false    3    561            �           0    0 .   recolhimento_transportadora_duplicidade_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.recolhimento_transportadora_duplicidade_id_seq OWNED BY public.recolhimento_transportadora_duplicidade.id;
            public       postgres    false    562            3           1259    17689 "   recolhimento_transportadora_id_seq    SEQUENCE     �   CREATE SEQUENCE public.recolhimento_transportadora_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 9   DROP SEQUENCE public.recolhimento_transportadora_id_seq;
       public       postgres    false    558    3            �           0    0 "   recolhimento_transportadora_id_seq    SEQUENCE OWNED BY     i   ALTER SEQUENCE public.recolhimento_transportadora_id_seq OWNED BY public.recolhimento_transportadora.id;
            public       postgres    false    563            4           1259    17691    release_note_id_seq    SEQUENCE     }   CREATE SEQUENCE public.release_note_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.release_note_id_seq;
       public       postgres    false    3            5           1259    17693    release_note    TABLE     �  CREATE TABLE public.release_note (
    id bigint DEFAULT nextval('public.release_note_id_seq'::regclass) NOT NULL,
    descricao text NOT NULL,
    tipo_projeto integer NOT NULL,
    versao character varying(100) NOT NULL,
    data_criacao timestamp without time zone NOT NULL,
    data_alteracao timestamp without time zone,
    usuario_id bigint NOT NULL,
    ativo boolean DEFAULT false,
    coverage numeric DEFAULT 0
);
     DROP TABLE public.release_note;
       public         postgres    false    564    3            6           1259    17702 #   resumo_processamento_arquivo_id_seq    SEQUENCE     �   CREATE SEQUENCE public.resumo_processamento_arquivo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 :   DROP SEQUENCE public.resumo_processamento_arquivo_id_seq;
       public       postgres    false    3            7           1259    17704    resumo_processamento_arquivo    TABLE     �  CREATE TABLE public.resumo_processamento_arquivo (
    id bigint DEFAULT nextval('public.resumo_processamento_arquivo_id_seq'::regclass) NOT NULL,
    data_hora timestamp without time zone NOT NULL,
    catalogado boolean NOT NULL,
    processado boolean,
    nome_empresa character varying(100),
    nome_arquivo_original character varying(255),
    novo_nome_arquivo character varying(255),
    tamanho_arquivo integer,
    controle_upload_id bigint
);
 0   DROP TABLE public.resumo_processamento_arquivo;
       public         postgres    false    566    3            8           1259    17711    retorno_debito    TABLE     �   CREATE TABLE public.retorno_debito (
    id bigint NOT NULL,
    codigo_retorno character varying(2) NOT NULL,
    descricao character varying(140) NOT NULL
);
 "   DROP TABLE public.retorno_debito;
       public         postgres    false    3            9           1259    17714    retorno_debito_id_seq    SEQUENCE     �   CREATE SEQUENCE public.retorno_debito_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 ,   DROP SEQUENCE public.retorno_debito_id_seq;
       public       postgres    false    3            :           1259    17716    sacado    TABLE     B  CREATE TABLE public.sacado (
    id bigint NOT NULL,
    nome character varying(70) NOT NULL,
    email character varying(70),
    cnpj_cpf character varying(18) NOT NULL,
    logradouro character varying(70) NOT NULL,
    complemento character varying(40),
    bairro character varying(30) NOT NULL,
    cidade_id bigint NOT NULL,
    estado_id bigint NOT NULL,
    cep character varying(10),
    telefone_fixo character varying(20),
    celular character varying(20),
    empresa_id bigint NOT NULL,
    sacador_avalista boolean,
    portal_cobranca boolean,
    email_cobranca boolean,
    email_vencimento boolean,
    email_atualizacao boolean,
    email_protesto boolean,
    dias_vencimento integer,
    dia_vencimento character varying(2),
    valor numeric(11,2),
    convenio_id integer,
    codigo character varying(20)
);
    DROP TABLE public.sacado;
       public         postgres    false    3            ;           1259    17719    sacado_id_seq    SEQUENCE     v   CREATE SEQUENCE public.sacado_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE public.sacado_id_seq;
       public       postgres    false    3            <           1259    17721    saldo_convenio    TABLE     *  CREATE TABLE public.saldo_convenio (
    id bigint NOT NULL,
    convenio_id bigint NOT NULL,
    data timestamp without time zone NOT NULL,
    saldo numeric NOT NULL,
    tipo integer NOT NULL,
    nsa integer NOT NULL,
    empresa_id bigint NOT NULL,
    banco_id bigint NOT NULL,
    nome_arquivo character varying NOT NULL,
    chave_saldo character varying NOT NULL,
    usuario_logado_id bigint,
    tiposaldoinicial integer,
    saldoinicial numeric(15,2),
    datasaldoinicial date,
    conta_id bigint,
    controle_upload_arquivo_id bigint
);
 "   DROP TABLE public.saldo_convenio;
       public         postgres    false    3            =           1259    17727    saldo_convenio_id_seq    SEQUENCE     ~   CREATE SEQUENCE public.saldo_convenio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public.saldo_convenio_id_seq;
       public       postgres    false    3            �           1259    34992    saldo_transito_cash    TABLE     �  CREATE TABLE public.saldo_transito_cash (
    id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    loja_id bigint NOT NULL,
    data_transito date NOT NULL,
    valor_transito numeric NOT NULL,
    valor_total_venda numeric,
    valor_total_coleta_carro_forte numeric,
    valor_total_devolucao numeric,
    valor_total_diferenca_deposito numeric,
    valor_total_ajuste_inversao_pagamento numeric,
    valor_recebido_venda numeric,
    frequencia_recolhimento_id bigint,
    banco_id bigint,
    transportadora_id bigint,
    valor_recebido_venda_banco numeric,
    valor_total_ajuste_coleta_deposito numeric,
    valor_saldo_receber numeric
);
 '   DROP TABLE public.saldo_transito_cash;
       public         postgres    false    3            �           1259    34990    saldo_transito_cash_id_seq    SEQUENCE     �   CREATE SEQUENCE public.saldo_transito_cash_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.saldo_transito_cash_id_seq;
       public       postgres    false    663    3            �           0    0    saldo_transito_cash_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.saldo_transito_cash_id_seq OWNED BY public.saldo_transito_cash.id;
            public       postgres    false    662            >           1259    17729    schema_version    TABLE     �  CREATE TABLE public.schema_version (
    installed_rank integer NOT NULL,
    version character varying(50),
    description character varying(200) NOT NULL,
    type character varying(20) NOT NULL,
    script character varying(1000) NOT NULL,
    checksum integer,
    installed_by character varying(100) NOT NULL,
    installed_on timestamp without time zone DEFAULT now() NOT NULL,
    execution_time integer NOT NULL,
    success boolean NOT NULL
);
 "   DROP TABLE public.schema_version;
       public         postgres    false    3            ?           1259    17736    status_monitoramento    TABLE     u   CREATE TABLE public.status_monitoramento (
    id integer NOT NULL,
    descricao character varying(255) NOT NULL
);
 (   DROP TABLE public.status_monitoramento;
       public         postgres    false    3            @           1259    17739    status_monitoramento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.status_monitoramento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.status_monitoramento_id_seq;
       public       postgres    false    3    575            �           0    0    status_monitoramento_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.status_monitoramento_id_seq OWNED BY public.status_monitoramento.id;
            public       postgres    false    576            A           1259    17741    tarifa_divergente    TABLE     �  CREATE TABLE public.tarifa_divergente (
    id bigint NOT NULL,
    lancamento_id bigint NOT NULL,
    grupo_empresa_id bigint NOT NULL,
    vinculo_tarifa_origem_tipo_operacao_id bigint NOT NULL,
    item_contrato_cesta_servico_id bigint NOT NULL,
    data_lancamento date NOT NULL,
    valor_cobrado numeric NOT NULL,
    valor_tarifa numeric NOT NULL,
    valor_divergente numeric NOT NULL,
    divergente boolean DEFAULT false NOT NULL
);
 %   DROP TABLE public.tarifa_divergente;
       public         postgres    false    3            B           1259    17748    tarifa_divergente_id_seq    SEQUENCE     �   CREATE SEQUENCE public.tarifa_divergente_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.tarifa_divergente_id_seq;
       public       postgres    false    3            C           1259    17750    tarifa_divergente_id_seq1    SEQUENCE     �   CREATE SEQUENCE public.tarifa_divergente_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.tarifa_divergente_id_seq1;
       public       postgres    false    577    3            �           0    0    tarifa_divergente_id_seq1    SEQUENCE OWNED BY     V   ALTER SEQUENCE public.tarifa_divergente_id_seq1 OWNED BY public.tarifa_divergente.id;
            public       postgres    false    579            D           1259    17752    tarifa_origem_id_seq    SEQUENCE     ~   CREATE SEQUENCE public.tarifa_origem_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.tarifa_origem_id_seq;
       public       postgres    false    3            E           1259    17754    tarifa_origem    TABLE     �   CREATE TABLE public.tarifa_origem (
    id bigint DEFAULT nextval('public.tarifa_origem_id_seq'::regclass) NOT NULL,
    banco_id integer,
    descricao character varying NOT NULL
);
 !   DROP TABLE public.tarifa_origem;
       public         postgres    false    580    3            F           1259    17761    tarifa_sem_contrato_id_seq    SEQUENCE     �   CREATE SEQUENCE public.tarifa_sem_contrato_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.tarifa_sem_contrato_id_seq;
       public       postgres    false    3            G           1259    17763    tarifa_sem_contrato    TABLE     �  CREATE TABLE public.tarifa_sem_contrato (
    id bigint DEFAULT nextval('public.tarifa_sem_contrato_id_seq'::regclass) NOT NULL,
    data_inicio date NOT NULL,
    data_fim date NOT NULL,
    empresa_id bigint NOT NULL,
    banco_id bigint NOT NULL,
    conta_id bigint NOT NULL,
    descricao_lancamento_id bigint NOT NULL,
    valor numeric NOT NULL,
    quantidade integer NOT NULL,
    total numeric NOT NULL
);
 '   DROP TABLE public.tarifa_sem_contrato;
       public         postgres    false    582    3            H           1259    17770    tb_data_fixa    TABLE     �   CREATE TABLE public.tb_data_fixa (
    data_fixa_order bigint,
    frequencia_recolhimento_id bigint,
    data_fixa character varying(2) NOT NULL
);
     DROP TABLE public.tb_data_fixa;
       public         postgres    false    3            I           1259    17773    tb_dias_semana    TABLE     �   CREATE TABLE public.tb_dias_semana (
    dias_semana_order bigint,
    frequencia_recolhimento_id bigint,
    dias_semana character varying(15) NOT NULL
);
 "   DROP TABLE public.tb_dias_semana;
       public         postgres    false    3            J           1259    17776    tipo_categoria_lancamento    TABLE     �   CREATE TABLE public.tipo_categoria_lancamento (
    id bigint NOT NULL,
    descricao character varying(200) NOT NULL,
    codigo character(3) NOT NULL,
    tipo_lancamento integer NOT NULL
);
 -   DROP TABLE public.tipo_categoria_lancamento;
       public         postgres    false    3            �           0    0 0   COLUMN tipo_categoria_lancamento.tipo_lancamento    COMMENT     b   COMMENT ON COLUMN public.tipo_categoria_lancamento.tipo_lancamento IS '0 - Débito
1 - Crédito';
            public       postgres    false    586            K           1259    17779     tipo_categoria_lancamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.tipo_categoria_lancamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 7   DROP SEQUENCE public.tipo_categoria_lancamento_id_seq;
       public       postgres    false    3            L           1259    17781    tipo_compromisso    TABLE     �   CREATE TABLE public.tipo_compromisso (
    id bigint NOT NULL,
    codigo character varying(2) NOT NULL,
    descricao character varying(30) NOT NULL,
    banco_id bigint NOT NULL,
    tipo_favorecido integer
);
 $   DROP TABLE public.tipo_compromisso;
       public         postgres    false    3            M           1259    17784    tipo_compromisso_seq    SEQUENCE     }   CREATE SEQUENCE public.tipo_compromisso_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.tipo_compromisso_seq;
       public       postgres    false    3            N           1259    17786    tipo_conta_pagar    TABLE     �   CREATE TABLE public.tipo_conta_pagar (
    id integer NOT NULL,
    descricao character varying,
    codigo smallint,
    empresa_id bigint NOT NULL,
    emite_dda boolean DEFAULT false
);
 $   DROP TABLE public.tipo_conta_pagar;
       public         postgres    false    3            O           1259    17793    tipo_conta_pagar_id_seq    SEQUENCE     �   CREATE SEQUENCE public.tipo_conta_pagar_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.tipo_conta_pagar_id_seq;
       public       postgres    false    590    3            �           0    0    tipo_conta_pagar_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.tipo_conta_pagar_id_seq OWNED BY public.tipo_conta_pagar.id;
            public       postgres    false    591            P           1259    17795    tipo_contrato_bancario    TABLE     v   CREATE TABLE public.tipo_contrato_bancario (
    id bigint NOT NULL,
    descricao character varying(100) NOT NULL
);
 *   DROP TABLE public.tipo_contrato_bancario;
       public         postgres    false    3            Q           1259    17798    tipo_contrato_bancario_id_seq    SEQUENCE     �   CREATE SEQUENCE public.tipo_contrato_bancario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 4   DROP SEQUENCE public.tipo_contrato_bancario_id_seq;
       public       postgres    false    3            R           1259    17800    tipo_identificacao_contribuinte    TABLE     �   CREATE TABLE public.tipo_identificacao_contribuinte (
    id bigint NOT NULL,
    descricao character varying NOT NULL,
    codigo character varying NOT NULL
);
 3   DROP TABLE public.tipo_identificacao_contribuinte;
       public         postgres    false    3            S           1259    17806 &   tipo_identificacao_contribuinte_id_seq    SEQUENCE     �   CREATE SEQUENCE public.tipo_identificacao_contribuinte_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 =   DROP SEQUENCE public.tipo_identificacao_contribuinte_id_seq;
       public       postgres    false    594    3            �           0    0 &   tipo_identificacao_contribuinte_id_seq    SEQUENCE OWNED BY     q   ALTER SEQUENCE public.tipo_identificacao_contribuinte_id_seq OWNED BY public.tipo_identificacao_contribuinte.id;
            public       postgres    false    595            T           1259    17808 "   tipo_operacao_cesta_servico_id_seq    SEQUENCE     �   CREATE SEQUENCE public.tipo_operacao_cesta_servico_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 9   DROP SEQUENCE public.tipo_operacao_cesta_servico_id_seq;
       public       postgres    false    3            U           1259    17810    tipo_operacao_cesta_servico    TABLE     �   CREATE TABLE public.tipo_operacao_cesta_servico (
    id bigint DEFAULT nextval('public.tipo_operacao_cesta_servico_id_seq'::regclass) NOT NULL,
    banco_id integer,
    descricao character varying NOT NULL
);
 /   DROP TABLE public.tipo_operacao_cesta_servico;
       public         postgres    false    596    3            V           1259    17817    tipo_operacao_numerario    TABLE     �   CREATE TABLE public.tipo_operacao_numerario (
    id integer NOT NULL,
    banco_id bigint NOT NULL,
    descricao character varying(100)
);
 +   DROP TABLE public.tipo_operacao_numerario;
       public         postgres    false    3            W           1259    17820    tipo_operacao_numerario_id_seq    SEQUENCE     �   CREATE SEQUENCE public.tipo_operacao_numerario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 5   DROP SEQUENCE public.tipo_operacao_numerario_id_seq;
       public       postgres    false    598    3            �           0    0    tipo_operacao_numerario_id_seq    SEQUENCE OWNED BY     a   ALTER SEQUENCE public.tipo_operacao_numerario_id_seq OWNED BY public.tipo_operacao_numerario.id;
            public       postgres    false    599            X           1259    17822    tipo_servico_id_seq    SEQUENCE     }   CREATE SEQUENCE public.tipo_servico_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.tipo_servico_id_seq;
       public       postgres    false    3            Y           1259    17824    tipo_servico    TABLE     �   CREATE TABLE public.tipo_servico (
    id bigint DEFAULT nextval('public.tipo_servico_id_seq'::regclass) NOT NULL,
    descricao character varying(40) NOT NULL,
    tipo_convenio integer NOT NULL,
    codigo smallint
);
     DROP TABLE public.tipo_servico;
       public         postgres    false    600    3            Z           1259    17828    titulo    TABLE     f  CREATE TABLE public.titulo (
    id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    convenio_id bigint NOT NULL,
    sacado_id bigint NOT NULL,
    tipo_data integer NOT NULL,
    data_vencimento date NOT NULL,
    num_documento character varying NOT NULL,
    tipo_titulo integer NOT NULL,
    aceite boolean,
    nosso_numero character varying NOT NULL,
    layout_cobranca integer NOT NULL,
    tipo_moeda integer NOT NULL,
    valor numeric NOT NULL,
    juros numeric,
    multa numeric,
    desconto_um numeric,
    desconto_dois numeric,
    desconto_tres numeric,
    prazo_desc_um integer,
    prazo_desc_dois integer,
    prazo_desc_tres integer,
    juros_banco boolean,
    dias_multa integer,
    tipo_prazo integer NOT NULL,
    prazo_protesto integer,
    prazo_devolucao integer,
    intrucao_um character varying,
    intrucao_dois character varying,
    intrucao_tres character varying,
    intrucao_quatro character varying,
    data_emissao date,
    status integer NOT NULL,
    sacador_avalista_id bigint,
    numero_remessa integer,
    carne boolean NOT NULL,
    movimentacao integer,
    carteira_cobranca_id bigint NOT NULL,
    parcelas integer,
    instrucao_dois character varying(255),
    instrucao_quatro character varying(255),
    instrucao_tres character varying(255),
    instrucao_um character varying(255),
    chave_titulo_remessa character varying(200),
    tipo_forma_entrega integer,
    valor_abatimento double precision,
    vinculo_sacado_id bigint,
    titulo_serie_id bigint,
    fator_data_vencimento date,
    valor_pago numeric,
    data_pagamento date,
    data_ocorrencia date
);
    DROP TABLE public.titulo;
       public         postgres    false    3            [           1259    17834 
   titulo_aud    TABLE     �  CREATE TABLE public.titulo_aud (
    id bigint NOT NULL,
    rev bigint NOT NULL,
    revtype smallint,
    data_vencimento date,
    desconto_dois double precision,
    prazo_desc_dois integer,
    prazo_desc_tres integer,
    prazo_desc_um integer,
    desconto_tres double precision,
    desconto_um double precision,
    dias_multa integer,
    juros double precision,
    multa double precision,
    nosso_numero character varying(255),
    num_documento character varying(255),
    numero_remessa integer,
    prazo_devolucao integer,
    prazo_protesto integer,
    status integer,
    valor double precision,
    valor_abatimento double precision,
    valor_pago numeric,
    data_pagamento date,
    data_ocorrencia date
);
    DROP TABLE public.titulo_aud;
       public         postgres    false    3            \           1259    17840    titulo_aux_id_seq    SEQUENCE     z   CREATE SEQUENCE public.titulo_aux_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.titulo_aux_id_seq;
       public       postgres    false    3            ]           1259    17842    titulo_auxiliar    TABLE     �  CREATE TABLE public.titulo_auxiliar (
    id bigint NOT NULL,
    data_sem_alter_vencimento timestamp without time zone,
    desc_dois_sem_alter integer,
    prazo_desc_dois_sem_alter_vencimento integer,
    prazo_desc_tres_sem_alter_vencimento integer,
    prazo_desc_um_sem_alter_vencimento integer,
    desc_tres_sem_alter integer,
    desc_um_sem_alter integer,
    dias_multa_sem_alter_vencimento integer,
    valor_sem_alter_vencimento double precision,
    titulo_id bigint NOT NULL,
    nosso_numero_sem_alter character varying,
    num_documento_sem_alter character varying,
    tipo_prazo_sem_alter integer,
    prazo_devolucao_sem_alter integer,
    prazo_protesto_sem_alter integer,
    valor_abatimento_sem_alter numeric,
    data_emissao_sem_alter date,
    multa_sem_alter numeric,
    juros_sem_alter numeric,
    tipo_titulo_sem_alter integer,
    aceite_sem_alter boolean,
    instrucao_um_sem_alter character varying,
    instrucao_dois_sem_alter character varying,
    nome_sacado_sem_alter character varying(70),
    email_sacado_sem_alter character varying(70),
    logradouro_sacado_sem_alter character varying(70),
    telefone_fixo_sacado_sem_alter character varying(20),
    celular_sacado_sem_alter character varying(20),
    complemento_sacado_sem_alter character varying(40),
    bairro_sacado_sem_alter character varying(30),
    estado_sacado_id_sacado bigint,
    cidade_sacado_id_sacado bigint,
    cep_sacado_sem_alter character varying(10)
);
 #   DROP TABLE public.titulo_auxiliar;
       public         postgres    false    3            ^           1259    17848    titulo_auxiliar_id_seq    SEQUENCE        CREATE SEQUENCE public.titulo_auxiliar_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.titulo_auxiliar_id_seq;
       public       postgres    false    3            _           1259    17850 
   titulo_dda    TABLE     }
  CREATE TABLE public.titulo_dda (
    id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    banco_id bigint NOT NULL,
    arquivo_id bigint NOT NULL,
    convenio_conta_id bigint NOT NULL,
    boleto_id bigint,
    cod_movimento character varying(2) NOT NULL,
    codigo_barras character varying(44) NOT NULL,
    status integer,
    nsa integer,
    valor_titulo numeric NOT NULL,
    data_vencimento date NOT NULL,
    data_emissao date NOT NULL,
    cod_juros integer,
    juros_dia numeric,
    cod_desconto_1 integer,
    data_desconto_1 date,
    valor_desconto_1 numeric,
    cod_desconto_2 integer,
    data_desconto_2 date,
    valor_desconto_2 numeric,
    cod_desconto_3 integer,
    data_desconto_3 date,
    valor_desconto_3 numeric,
    cod_multa integer,
    data_multa date,
    valor_multa numeric,
    data_limite_pagamento date,
    valor_abatimento numeric,
    tipo_inscricao_cedente integer NOT NULL,
    inscricao_cedente character varying(15) NOT NULL,
    nome_cedente character varying NOT NULL,
    tipo_inscricao_avalista integer,
    inscricao_avalista character varying(15),
    nome_avalista character varying,
    quantidade_moeda integer NOT NULL,
    cod_moeda integer NOT NULL,
    numero_documento_cobranca character varying(15) NOT NULL,
    agencia_cobranca character varying(5) NOT NULL,
    dv_agencia_cobranca character varying NOT NULL,
    praca_cobranca character varying(10) NOT NULL,
    codigo_carteira character varying NOT NULL,
    especie_titulo character varying(2) NOT NULL,
    cod_protesto integer,
    numero_dias_protesto character varying(2),
    mensagem_1 character varying,
    mensagem_2 character varying,
    baixa_manual boolean,
    data_ocorrencia date,
    autenticacao_pagamento character varying,
    valor_pagamento numeric,
    local_pagamento character varying,
    usuario_alteracao_id bigint,
    data_alteracao date,
    valor_alterado character varying,
    banco_modificador bigint,
    status_conciliacao smallint DEFAULT 0 NOT NULL,
    verificado boolean DEFAULT false,
    CONSTRAINT titulo_dda_valor_abatimento_check CHECK ((valor_abatimento >= (0)::numeric)),
    CONSTRAINT titulo_dda_valor_desconto_1_check CHECK ((valor_desconto_1 >= (0)::numeric)),
    CONSTRAINT titulo_dda_valor_desconto_2_check CHECK ((valor_desconto_2 >= (0)::numeric)),
    CONSTRAINT titulo_dda_valor_desconto_3_check CHECK ((valor_desconto_3 >= (0)::numeric)),
    CONSTRAINT titulo_dda_valor_multa_check CHECK ((valor_multa >= (0)::numeric)),
    CONSTRAINT titulo_dda_valor_pagamento_check CHECK ((valor_pagamento >= (0)::numeric)),
    CONSTRAINT titulo_dda_valor_titulo_check CHECK ((valor_titulo >= (0)::numeric))
);
    DROP TABLE public.titulo_dda;
       public         postgres    false    3            �           0    0 (   COLUMN titulo_dda.tipo_inscricao_cedente    COMMENT     S   COMMENT ON COLUMN public.titulo_dda.tipo_inscricao_cedente IS '1 - CPF, 2 - CNPJ';
            public       postgres    false    607            �           0    0 )   COLUMN titulo_dda.tipo_inscricao_avalista    COMMENT     T   COMMENT ON COLUMN public.titulo_dda.tipo_inscricao_avalista IS '1 - CPF, 2 - CNPJ';
            public       postgres    false    607            �           0    0    COLUMN titulo_dda.baixa_manual    COMMENT     �   COMMENT ON COLUMN public.titulo_dda.baixa_manual IS 'true - caso a baixo no dda tenha sido feito manual, false caso tenha sido feito processador';
            public       postgres    false    607                        0    0 !   COLUMN titulo_dda.data_ocorrencia    COMMENT     ]   COMMENT ON COLUMN public.titulo_dda.data_ocorrencia IS 'Data em que ocorreu a baixa manual';
            public       postgres    false    607                       0    0 (   COLUMN titulo_dda.autenticacao_pagamento    COMMENT     ]   COMMENT ON COLUMN public.titulo_dda.autenticacao_pagamento IS 'Autenticação de pagamento';
            public       postgres    false    607                       0    0 !   COLUMN titulo_dda.valor_pagamento    COMMENT     M   COMMENT ON COLUMN public.titulo_dda.valor_pagamento IS 'Valor do Pagamento';
            public       postgres    false    607                       0    0 !   COLUMN titulo_dda.local_pagamento    COMMENT     V   COMMENT ON COLUMN public.titulo_dda.local_pagamento IS 'Local que houve o pagamento';
            public       postgres    false    607                       0    0 &   COLUMN titulo_dda.usuario_alteracao_id    COMMENT     r   COMMENT ON COLUMN public.titulo_dda.usuario_alteracao_id IS 'Último usuário quem fez movimentação no titulo';
            public       postgres    false    607                       0    0     COLUMN titulo_dda.data_alteracao    COMMENT     q   COMMENT ON COLUMN public.titulo_dda.data_alteracao IS 'Data da última alteração na movimentação no titulo';
            public       postgres    false    607            `           1259    17865    titulo_dda_duplicado    TABLE     �   CREATE TABLE public.titulo_dda_duplicado (
    id bigint NOT NULL,
    titulo_dda_id integer NOT NULL,
    controle_upload_arquivo_id integer NOT NULL,
    linha_processada integer NOT NULL,
    data_processamento timestamp without time zone NOT NULL
);
 (   DROP TABLE public.titulo_dda_duplicado;
       public         postgres    false    3            a           1259    17868    titulo_dda_duplicado_id_seq    SEQUENCE     �   CREATE SEQUENCE public.titulo_dda_duplicado_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.titulo_dda_duplicado_id_seq;
       public       postgres    false    608    3                       0    0    titulo_dda_duplicado_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.titulo_dda_duplicado_id_seq OWNED BY public.titulo_dda_duplicado.id;
            public       postgres    false    609            b           1259    17870    titulo_dda_id_seq    SEQUENCE     z   CREATE SEQUENCE public.titulo_dda_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.titulo_dda_id_seq;
       public       postgres    false    3            c           1259    17872    titulo_id_seq    SEQUENCE     v   CREATE SEQUENCE public.titulo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE public.titulo_id_seq;
       public       postgres    false    3            d           1259    17874    titulo_mensagem    TABLE     o   CREATE TABLE public.titulo_mensagem (
    mensagem_titulo_id bigint NOT NULL,
    titulo_id bigint NOT NULL
);
 #   DROP TABLE public.titulo_mensagem;
       public         postgres    false    3            e           1259    17877    titulo_movimento_remessa    TABLE     <  CREATE TABLE public.titulo_movimento_remessa (
    titulo_id bigint NOT NULL,
    movimento_remessa_cobranca_id bigint NOT NULL,
    enviado boolean NOT NULL,
    data_geracao_instrucao timestamp without time zone NOT NULL,
    arquivo_id bigint,
    usuario_id integer,
    instrucao_realizada character varying
);
 ,   DROP TABLE public.titulo_movimento_remessa;
       public         postgres    false    3            f           1259    17883    titulo_retorno    TABLE     T  CREATE TABLE public.titulo_retorno (
    id bigint NOT NULL,
    titulo_id bigint NOT NULL,
    ocorrencia_ret character varying,
    juros numeric,
    valor_desconto numeric,
    valor_pago numeric,
    valor_liquido numeric,
    data_ocorrencia date,
    data_tarifa date,
    data_credito date,
    cod_mov_ret character varying(2) NOT NULL,
    arquivo_id bigint,
    floating integer,
    ocorrencia_det character varying(255),
    valor_tarifa double precision,
    formapagamento character varying(255),
    forma_pagamento character varying(20),
    nsa bigint,
    id_mov_ret bigint
);
 "   DROP TABLE public.titulo_retorno;
       public         postgres    false    3            g           1259    17889    titulo_retorno_id_seq    SEQUENCE     ~   CREATE SEQUENCE public.titulo_retorno_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public.titulo_retorno_id_seq;
       public       postgres    false    3            h           1259    17891    titulo_serie_id_seq    SEQUENCE     }   CREATE SEQUENCE public.titulo_serie_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.titulo_serie_id_seq;
       public       postgres    false    3            i           1259    17893    titulo_serie    TABLE     �  CREATE TABLE public.titulo_serie (
    id bigint DEFAULT nextval('public.titulo_serie_id_seq'::regclass) NOT NULL,
    data_emissao timestamp without time zone NOT NULL,
    numero_documento character varying(15) NOT NULL,
    quantidade smallint NOT NULL,
    data_vencimento date NOT NULL,
    valor_unitario numeric NOT NULL,
    empresa_id bigint NOT NULL,
    convenio_id bigint NOT NULL,
    pagador_id bigint NOT NULL
);
     DROP TABLE public.titulo_serie;
       public         postgres    false    616    3            j           1259    17900    token    TABLE     �   CREATE TABLE public.token (
    id bigint NOT NULL,
    chave character varying(255) NOT NULL,
    grupo_empresa_id bigint NOT NULL,
    ativo boolean DEFAULT true
);
    DROP TABLE public.token;
       public         postgres    false    3            k           1259    17904    token_id_seq    SEQUENCE     }   CREATE SEQUENCE public.token_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 #   DROP SEQUENCE public.token_id_seq;
       public       postgres    false    3            l           1259    17906 $   tramite_processamento_arquivo_id_seq    SEQUENCE     �   CREATE SEQUENCE public.tramite_processamento_arquivo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.tramite_processamento_arquivo_id_seq;
       public       postgres    false    3            m           1259    17908    tramite_processamento_arquivo    TABLE     �  CREATE TABLE public.tramite_processamento_arquivo (
    id bigint DEFAULT nextval('public.tramite_processamento_arquivo_id_seq'::regclass) NOT NULL,
    inicio_tramite timestamp without time zone NOT NULL,
    fim_tramite timestamp without time zone NOT NULL,
    tipo_tramite character varying(100) NOT NULL,
    status_tramite character varying(100) NOT NULL,
    resumo_processamento_id bigint NOT NULL,
    resumo_tramite text
);
 1   DROP TABLE public.tramite_processamento_arquivo;
       public         postgres    false    620    3            n           1259    17915    transportadora    TABLE     :  CREATE TABLE public.transportadora (
    id integer NOT NULL,
    cnpj character varying(50),
    razao_social character varying(100),
    nome_fantasia character varying(100),
    email character varying(100),
    telefone character varying(50),
    celular character varying(50),
    ativa boolean DEFAULT true,
    cep character varying(50),
    logradouro character varying(100),
    complemento character varying(100),
    bairro character varying(100),
    estado_id bigint,
    cidade_id bigint,
    numero character varying(10),
    url_api character varying
);
 "   DROP TABLE public.transportadora;
       public         postgres    false    3            o           1259    17922    transportadora_id_seq    SEQUENCE     �   CREATE SEQUENCE public.transportadora_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public.transportadora_id_seq;
       public       postgres    false    3    622                       0    0    transportadora_id_seq    SEQUENCE OWNED BY     O   ALTER SEQUENCE public.transportadora_id_seq OWNED BY public.transportadora.id;
            public       postgres    false    623            p           1259    17924    tributo_gps    TABLE     }  CREATE TABLE public.tributo_gps (
    id bigint NOT NULL,
    valor_inss numeric NOT NULL,
    identificador character varying(18) NOT NULL,
    nome_razao_social character varying(70) NOT NULL,
    telefone character varying(20),
    logradouro character varying(70) NOT NULL,
    atualizacao_monetaria numeric,
    forma_pagamento_id integer,
    valor_outras_entidades numeric,
    codigo_receita_id integer,
    pagamento_id integer,
    cidade_id bigint NOT NULL,
    estado_id bigint NOT NULL,
    status integer,
    seu_numero character varying,
    valor_total numeric NOT NULL,
    competencia character varying(6) NOT NULL
);
    DROP TABLE public.tributo_gps;
       public         postgres    false    3            q           1259    17930    tributo_gps_id_seq    SEQUENCE     �   CREATE SEQUENCE public.tributo_gps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 633437444
    CACHE 1;
 )   DROP SEQUENCE public.tributo_gps_id_seq;
       public       postgres    false    3            r           1259    17932    tributo_sem_codigo_barra    TABLE     �  CREATE TABLE public.tributo_sem_codigo_barra (
    id bigint NOT NULL,
    nome_razao_social character varying(100) NOT NULL,
    identificador character varying(50) NOT NULL,
    data_vencimento date,
    observacao text,
    telefone character varying(20),
    endereco character varying(255),
    autenticacao_bancaria character varying(255),
    valor numeric,
    multa numeric,
    juros numeric,
    total numeric,
    status integer,
    competencia character varying(20),
    periodo_apuracao date,
    numero_referencia character varying(100),
    pagamento_id bigint NOT NULL,
    codigo_receita_id bigint,
    tipo_tributo integer,
    seu_numero character varying(50),
    tipo_identificacao_contribuinte_id integer NOT NULL,
    ocorrencia character varying,
    forma_pagamento_id bigint,
    data_pagamento date,
    numero_parcela bigint,
    inscricao_estadual character varying(12),
    divida_ativa numeric(13,2),
    periodo_referencia character varying(6)
);
 ,   DROP TABLE public.tributo_sem_codigo_barra;
       public         postgres    false    3            s           1259    17938    tributo_sem_codigo_barra_id_seq    SEQUENCE     �   CREATE SEQUENCE public.tributo_sem_codigo_barra_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.tributo_sem_codigo_barra_id_seq;
       public       postgres    false    3            t           1259    17940    usuario    TABLE       CREATE TABLE public.usuario (
    nome character varying(100) NOT NULL,
    login character varying(60) NOT NULL,
    senha character varying(100) NOT NULL,
    grupo_empresa_id integer,
    root boolean NOT NULL,
    id bigint NOT NULL,
    ativo boolean,
    altera_senha boolean,
    email character varying(255) DEFAULT ''::character varying NOT NULL,
    notifica_aut_pag boolean,
    cocriacao boolean DEFAULT false NOT NULL,
    cpf character varying(15),
    notifica_boleto_a_vencer boolean DEFAULT false,
    foto bytea
);
    DROP TABLE public.usuario;
       public         postgres    false    3            u           1259    17949    usuario_aud    TABLE     ]  CREATE TABLE public.usuario_aud (
    id bigint NOT NULL,
    rev bigint NOT NULL,
    revtype smallint,
    nome character varying,
    ativo boolean,
    login character varying,
    senha character varying,
    grupo_empresa_id bigint,
    root boolean,
    email character varying,
    notifica_aut_pag boolean,
    cpf character varying(15)
);
    DROP TABLE public.usuario_aud;
       public         postgres    false    3            v           1259    17955    usuario_contas    TABLE     e   CREATE TABLE public.usuario_contas (
    usuario_id bigint NOT NULL,
    conta_id bigint NOT NULL
);
 "   DROP TABLE public.usuario_contas;
       public         postgres    false    3            w           1259    17958    usuario_empresas    TABLE     i   CREATE TABLE public.usuario_empresas (
    usuario_id bigint NOT NULL,
    empresa_id bigint NOT NULL
);
 $   DROP TABLE public.usuario_empresas;
       public         postgres    false    3            x           1259    17961    usuario_favorecido    TABLE     �   CREATE TABLE public.usuario_favorecido (
    id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    favorecido_id bigint NOT NULL,
    data_cadastro timestamp without time zone,
    usuario_cadastro_id bigint NOT NULL,
    favorecido_id_old bigint
);
 &   DROP TABLE public.usuario_favorecido;
       public         postgres    false    3            y           1259    17964    usuario_favorecido_id_seq    SEQUENCE     �   CREATE SEQUENCE public.usuario_favorecido_id_seq
    START WITH 91
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 0   DROP SEQUENCE public.usuario_favorecido_id_seq;
       public       postgres    false    3            z           1259    17966    usuario_id_seq    SEQUENCE     y   CREATE SEQUENCE public.usuario_id_seq
    START WITH 807
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE public.usuario_id_seq;
       public       postgres    false    3            {           1259    17968    usuario_lojas    TABLE     S   CREATE TABLE public.usuario_lojas (
    usuario_id integer,
    loja_id integer
);
 !   DROP TABLE public.usuario_lojas;
       public         postgres    false    3            |           1259    17971    usuario_perfil    TABLE     f   CREATE TABLE public.usuario_perfil (
    usuario_id bigint NOT NULL,
    perfil_id bigint NOT NULL
);
 "   DROP TABLE public.usuario_perfil;
       public         postgres    false    3            }           1259    17974    usuario_perfil_aud    TABLE     �   CREATE TABLE public.usuario_perfil_aud (
    rev bigint NOT NULL,
    revtype smallint,
    usuario_id bigint,
    perfil_id bigint
);
 &   DROP TABLE public.usuario_perfil_aud;
       public         postgres    false    3            ~           1259    17977    usuario_sacado    TABLE     �   CREATE TABLE public.usuario_sacado (
    id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    sacado_id bigint NOT NULL,
    data_cadastro timestamp without time zone,
    usuario_cadastro_id bigint NOT NULL,
    convenio_id bigint
);
 "   DROP TABLE public.usuario_sacado;
       public         postgres    false    3                       1259    17980    usuario_sacado_id_seq    SEQUENCE        CREATE SEQUENCE public.usuario_sacado_id_seq
    START WITH 86
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public.usuario_sacado_id_seq;
       public       postgres    false    3            �           1259    17982    venda    TABLE     �  CREATE TABLE public.venda (
    id bigint NOT NULL,
    empresa_id integer NOT NULL,
    codigo_loja character varying NOT NULL,
    descricao_loja character varying NOT NULL,
    valor_venda numeric NOT NULL,
    data_venda date NOT NULL,
    numero_documento character varying NOT NULL,
    tipo_documento character varying,
    codigo_lancamento character varying,
    descricao_lancamento character varying,
    referencia character varying,
    faturamento_id bigint
);
    DROP TABLE public.venda;
       public         postgres    false    3            �           1259    17988    venda_id_seq    SEQUENCE     u   CREATE SEQUENCE public.venda_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE public.venda_id_seq;
       public       postgres    false    3    640                       0    0    venda_id_seq    SEQUENCE OWNED BY     =   ALTER SEQUENCE public.venda_id_seq OWNED BY public.venda.id;
            public       postgres    false    641            �           1259    17990    verificacao_status    TABLE     �   CREATE TABLE public.verificacao_status (
    id integer NOT NULL,
    status integer NOT NULL,
    descricao character varying(255) NOT NULL
);
 &   DROP TABLE public.verificacao_status;
       public         postgres    false    3            �           1259    17993    verificacao_status_id_seq    SEQUENCE     �   CREATE SEQUENCE public.verificacao_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.verificacao_status_id_seq;
       public       postgres    false    3    642            	           0    0    verificacao_status_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.verificacao_status_id_seq OWNED BY public.verificacao_status.id;
            public       postgres    false    643            �           1259    17995    vinculacao_automatica_categoria    TABLE     �   CREATE TABLE public.vinculacao_automatica_categoria (
    id bigint NOT NULL,
    descricao character varying(255) NOT NULL,
    banco_id bigint NOT NULL,
    categoria_lancamento_id bigint NOT NULL
);
 3   DROP TABLE public.vinculacao_automatica_categoria;
       public         postgres    false    3            �           1259    17998 &   vinculacao_automatica_categoria_id_seq    SEQUENCE     �   CREATE SEQUENCE public.vinculacao_automatica_categoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 =   DROP SEQUENCE public.vinculacao_automatica_categoria_id_seq;
       public       postgres    false    3            �           1259    18000    vinculacao_cnpj_empresa    TABLE     �   CREATE TABLE public.vinculacao_cnpj_empresa (
    id bigint NOT NULL,
    cnpj character varying(18) NOT NULL,
    empresa_id bigint NOT NULL,
    conta_id bigint,
    convenio_id bigint,
    razao_social character varying(70)
);
 +   DROP TABLE public.vinculacao_cnpj_empresa;
       public         postgres    false    3            �           1259    18003    vinculacao_cnpj_empresa_id_seq    SEQUENCE     �   CREATE SEQUENCE public.vinculacao_cnpj_empresa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 5   DROP SEQUENCE public.vinculacao_cnpj_empresa_id_seq;
       public       postgres    false    3            �           1259    35831    vinculo_categoria_cash    TABLE     �   CREATE TABLE public.vinculo_categoria_cash (
    id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    categoria_lancamento_id bigint NOT NULL,
    banco_id bigint NOT NULL,
    tipo_categoria_cash integer NOT NULL,
    ativo boolean NOT NULL
);
 *   DROP TABLE public.vinculo_categoria_cash;
       public         postgres    false    3            �           1259    35851    vinculo_categoria_cash_id_seq    SEQUENCE     �   CREATE SEQUENCE public.vinculo_categoria_cash_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.vinculo_categoria_cash_id_seq;
       public       bv_postgres    false    3            �           1259    18005    vinculo_conciliacao_cobranca    TABLE     �   CREATE TABLE public.vinculo_conciliacao_cobranca (
    id bigint NOT NULL,
    banco_id bigint,
    movimento_retorno_cobranca_id bigint,
    categoria_lancamento_id bigint
);
 0   DROP TABLE public.vinculo_conciliacao_cobranca;
       public         postgres    false    3            �           1259    18008 #   vinculo_conciliacao_cobranca_id_seq    SEQUENCE     �   CREATE SEQUENCE public.vinculo_conciliacao_cobranca_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 :   DROP SEQUENCE public.vinculo_conciliacao_cobranca_id_seq;
       public       postgres    false    3            �           1259    18010 -   vinculo_descricao_ocorrencia_categoria_id_seq    SEQUENCE     �   CREATE SEQUENCE public.vinculo_descricao_ocorrencia_categoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 D   DROP SEQUENCE public.vinculo_descricao_ocorrencia_categoria_id_seq;
       public       postgres    false    3            �           1259    18012 &   vinculo_descricao_ocorrencia_categoria    TABLE       CREATE TABLE public.vinculo_descricao_ocorrencia_categoria (
    id bigint DEFAULT nextval('public.vinculo_descricao_ocorrencia_categoria_id_seq'::regclass) NOT NULL,
    ocorrencia_cobranca_id bigint NOT NULL,
    categoria_lancamento_id bigint,
    banco_id bigint NOT NULL
);
 :   DROP TABLE public.vinculo_descricao_ocorrencia_categoria;
       public         postgres    false    650    3            �           1259    18016 #   vinculo_ocorrencia_pagamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.vinculo_ocorrencia_pagamento_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 :   DROP SEQUENCE public.vinculo_ocorrencia_pagamento_id_seq;
       public       postgres    false    3            �           1259    18018    vinculo_ocorrencia_pagamento    TABLE     )  CREATE TABLE public.vinculo_ocorrencia_pagamento (
    id bigint DEFAULT nextval('public.vinculo_ocorrencia_pagamento_id_seq'::regclass) NOT NULL,
    banco_id bigint NOT NULL,
    tipo_servico_id bigint NOT NULL,
    tipo_vinculo smallint NOT NULL,
    categoria_lancamento_id bigint NOT NULL
);
 0   DROP TABLE public.vinculo_ocorrencia_pagamento;
       public         postgres    false    652    3            �           1259    18022    vinculo_pagamento_lancamento    TABLE     �   CREATE TABLE public.vinculo_pagamento_lancamento (
    id bigint NOT NULL,
    chave_lancamento character varying(200) NOT NULL,
    pagamento_id bigint NOT NULL
);
 0   DROP TABLE public.vinculo_pagamento_lancamento;
       public         postgres    false    3            �           1259    18025 #   vinculo_pagamento_lancamento_id_seq    SEQUENCE     �   CREATE SEQUENCE public.vinculo_pagamento_lancamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2039407152
    CACHE 1;
 :   DROP SEQUENCE public.vinculo_pagamento_lancamento_id_seq;
       public       postgres    false    3            �           1259    18027    vinculo_sacado_id_seq    SEQUENCE        CREATE SEQUENCE public.vinculo_sacado_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public.vinculo_sacado_id_seq;
       public       postgres    false    3            �           1259    18029    vinculo_sacado    TABLE     �  CREATE TABLE public.vinculo_sacado (
    id bigint DEFAULT nextval('public.vinculo_sacado_id_seq'::regclass) NOT NULL,
    apelido character varying(40) NOT NULL,
    empresa_id bigint NOT NULL,
    grupo_empresa_id bigint NOT NULL,
    data_processamento date NOT NULL,
    convenio_id bigint NOT NULL,
    agencia character varying(5),
    dv_agencia character varying(1),
    banco_id bigint,
    sacado_id bigint NOT NULL
);
 "   DROP TABLE public.vinculo_sacado;
       public         postgres    false    656    3            �           1259    18033 &   vinculo_tarifa_origem_tipo_operacao_id    SEQUENCE     �   CREATE SEQUENCE public.vinculo_tarifa_origem_tipo_operacao_id
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 =   DROP SEQUENCE public.vinculo_tarifa_origem_tipo_operacao_id;
       public       postgres    false    3            �           1259    18035 #   vinculo_tarifa_origem_tipo_operacao    TABLE     V  CREATE TABLE public.vinculo_tarifa_origem_tipo_operacao (
    id bigint DEFAULT nextval('public.vinculo_tarifa_origem_tipo_operacao_id'::regclass) NOT NULL,
    banco_id bigint NOT NULL,
    tipo_operacao_id bigint NOT NULL,
    tarifa_origem_id bigint NOT NULL,
    categoria_id bigint NOT NULL,
    tarifa boolean DEFAULT false NOT NULL
);
 7   DROP TABLE public.vinculo_tarifa_origem_tipo_operacao;
       public         postgres    false    658    3            �           2604    18040    arquivo_aud id    DEFAULT     v   ALTER TABLE ONLY auditoria.arquivo_aud ALTER COLUMN id SET DEFAULT nextval('auditoria.arquivo_aud_id_seq'::regclass);
 @   ALTER TABLE auditoria.arquivo_aud ALTER COLUMN id DROP DEFAULT;
    	   auditoria       postgres    false    198    197            �           2604    18041    categoria id    DEFAULT     r   ALTER TABLE ONLY auditoria.categoria ALTER COLUMN id SET DEFAULT nextval('auditoria.categoria_id_seq'::regclass);
 >   ALTER TABLE auditoria.categoria ALTER COLUMN id DROP DEFAULT;
    	   auditoria       postgres    false    200    199            �           2604    18042    cliente_ftp_log_externo id    DEFAULT     �   ALTER TABLE ONLY auditoria.cliente_ftp_log_externo ALTER COLUMN id SET DEFAULT nextval('auditoria.cliente_ftp_log_externo_id_seq'::regclass);
 L   ALTER TABLE auditoria.cliente_ftp_log_externo ALTER COLUMN id DROP DEFAULT;
    	   auditoria       postgres    false    202    201            U           2604    36187    conta_pagar_aud id    DEFAULT     ~   ALTER TABLE ONLY auditoria.conta_pagar_aud ALTER COLUMN id SET DEFAULT nextval('auditoria.conta_pagar_aud_id_seq'::regclass);
 D   ALTER TABLE auditoria.conta_pagar_aud ALTER COLUMN id DROP DEFAULT;
    	   auditoria       postgres    false    673    672    673            �           2604    18043    controle_acesso id    DEFAULT     ~   ALTER TABLE ONLY auditoria.controle_acesso ALTER COLUMN id SET DEFAULT nextval('auditoria.controle_acesso_id_seq'::regclass);
 D   ALTER TABLE auditoria.controle_acesso ALTER COLUMN id DROP DEFAULT;
    	   auditoria       postgres    false    204    203            �           2604    18044    empresa_aud id    DEFAULT     v   ALTER TABLE ONLY auditoria.empresa_aud ALTER COLUMN id SET DEFAULT nextval('auditoria.empresa_aud_id_seq'::regclass);
 @   ALTER TABLE auditoria.empresa_aud ALTER COLUMN id DROP DEFAULT;
    	   auditoria       postgres    false    206    205            �           2604    18045    grupo_empresa_log id    DEFAULT     �   ALTER TABLE ONLY auditoria.grupo_empresa_log ALTER COLUMN id SET DEFAULT nextval('auditoria.grupo_empresa_log_id_seq'::regclass);
 F   ALTER TABLE auditoria.grupo_empresa_log ALTER COLUMN id DROP DEFAULT;
    	   auditoria       postgres    false    209    208            �           2604    18046    historico_usuario id    DEFAULT     �   ALTER TABLE ONLY auditoria.historico_usuario ALTER COLUMN id SET DEFAULT nextval('auditoria.historico_usuario_id_seq'::regclass);
 F   ALTER TABLE auditoria.historico_usuario ALTER COLUMN id DROP DEFAULT;
    	   auditoria       postgres    false    211    210            �           2604    18047    log_arquivos_particionados id    DEFAULT     �   ALTER TABLE ONLY auditoria.log_arquivos_particionados ALTER COLUMN id SET DEFAULT nextval('auditoria.log_arquivos_particionados_id_seq'::regclass);
 O   ALTER TABLE auditoria.log_arquivos_particionados ALTER COLUMN id DROP DEFAULT;
    	   auditoria       postgres    false    213    212            �           2604    18048    menu_log id    DEFAULT     p   ALTER TABLE ONLY auditoria.menu_log ALTER COLUMN id SET DEFAULT nextval('auditoria.menu_log_id_seq'::regclass);
 =   ALTER TABLE auditoria.menu_log ALTER COLUMN id DROP DEFAULT;
    	   auditoria       postgres    false    215    214            �           2604    18049    sub_categoria id    DEFAULT     z   ALTER TABLE ONLY auditoria.sub_categoria ALTER COLUMN id SET DEFAULT nextval('auditoria.sub_categoria_id_seq'::regclass);
 B   ALTER TABLE auditoria.sub_categoria ALTER COLUMN id DROP DEFAULT;
    	   auditoria       postgres    false    217    216            �           2604    18050 )   agendamento_descricao_categoria_global id    DEFAULT     �   ALTER TABLE ONLY public.agendamento_descricao_categoria_global ALTER COLUMN id SET DEFAULT nextval('public.agendamento_descricao_categoria_global_id_seq'::regclass);
 X   ALTER TABLE public.agendamento_descricao_categoria_global ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    222    221            �           2604    18051    autorizacao_dependencia id    DEFAULT     �   ALTER TABLE ONLY public.autorizacao_dependencia ALTER COLUMN id SET DEFAULT nextval('public.autorizacao_dependencia_id_seq'::regclass);
 I   ALTER TABLE public.autorizacao_dependencia ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    241    240            �           2604    18052    cliente_ftp id    DEFAULT     p   ALTER TABLE ONLY public.cliente_ftp ALTER COLUMN id SET DEFAULT nextval('public.cliente_ftp_id_seq'::regclass);
 =   ALTER TABLE public.cliente_ftp ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    271    270            �           2604    18053    cliente_ftp_log id    DEFAULT     x   ALTER TABLE ONLY public.cliente_ftp_log ALTER COLUMN id SET DEFAULT nextval('public.cliente_ftp_log_id_seq'::regclass);
 A   ALTER TABLE public.cliente_ftp_log ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    273    272            R           2604    35340    conciliacao_cash id    DEFAULT     z   ALTER TABLE ONLY public.conciliacao_cash ALTER COLUMN id SET DEFAULT nextval('public.conciliacao_cash_id_seq'::regclass);
 B   ALTER TABLE public.conciliacao_cash ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    665    664    665            �           2604    18054    conta_pagar id    DEFAULT     p   ALTER TABLE ONLY public.conta_pagar ALTER COLUMN id SET DEFAULT nextval('public.conta_pagar_id_seq'::regclass);
 =   ALTER TABLE public.conta_pagar ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    303    302            �           2604    18055    conta_pagar_log id    DEFAULT     x   ALTER TABLE ONLY public.conta_pagar_log ALTER COLUMN id SET DEFAULT nextval('public.conta_pagar_log_id_seq'::regclass);
 A   ALTER TABLE public.conta_pagar_log ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    305    304            �           2604    18056    controle_card id    DEFAULT     t   ALTER TABLE ONLY public.controle_card ALTER COLUMN id SET DEFAULT nextval('public.controle_card_id_seq'::regclass);
 ?   ALTER TABLE public.controle_card ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    318    317            �           2604    18057 A   descricao_lancamento_new_categoria_lancamento_new_configuracao id    DEFAULT     �   ALTER TABLE ONLY public.descricao_lancamento_new_categoria_lancamento_new_configuracao ALTER COLUMN id SET DEFAULT nextval('public.descricao_lancamento_new_categoria_lancamento_new_config_id_seq'::regclass);
 p   ALTER TABLE public.descricao_lancamento_new_categoria_lancamento_new_configuracao ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    352    351            T           2604    35575    documentacao id    DEFAULT     r   ALTER TABLE ONLY public.documentacao ALTER COLUMN id SET DEFAULT nextval('public.documentacao_id_seq'::regclass);
 >   ALTER TABLE public.documentacao ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    669    668    669            �           2604    18058    empresa_transportadora id    DEFAULT     �   ALTER TABLE ONLY public.empresa_transportadora ALTER COLUMN id SET DEFAULT nextval('public.empresa_transportadora_id_seq'::regclass);
 H   ALTER TABLE public.empresa_transportadora ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    364    363            �           2604    18059    faq id    DEFAULT     `   ALTER TABLE ONLY public.faq ALTER COLUMN id SET DEFAULT nextval('public.faq_id_seq'::regclass);
 5   ALTER TABLE public.faq ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    375    374            �           2604    18060    faturamento id    DEFAULT     p   ALTER TABLE ONLY public.faturamento ALTER COLUMN id SET DEFAULT nextval('public.faturamento_id_seq'::regclass);
 =   ALTER TABLE public.faturamento ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    377    376            �           2604    18061    grupo_numerario id    DEFAULT     x   ALTER TABLE ONLY public.grupo_numerario ALTER COLUMN id SET DEFAULT nextval('public.grupo_numerario_id_seq'::regclass);
 A   ALTER TABLE public.grupo_numerario ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    411    410            �           2604    18062    guia_transporte_valores id    DEFAULT     �   ALTER TABLE ONLY public.guia_transporte_valores ALTER COLUMN id SET DEFAULT nextval('public.guia_transporte_valores_id_seq'::regclass);
 I   ALTER TABLE public.guia_transporte_valores ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    422    421            �           2604    18063    historico_monitoramento id    DEFAULT     �   ALTER TABLE ONLY public.historico_monitoramento ALTER COLUMN id SET DEFAULT nextval('public.historico_monitoramento_id_seq'::regclass);
 I   ALTER TABLE public.historico_monitoramento ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    427    426            �           2604    18064    historico_pagamento id    DEFAULT     �   ALTER TABLE ONLY public.historico_pagamento ALTER COLUMN id SET DEFAULT nextval('public.historico_pagamento_id_seq'::regclass);
 E   ALTER TABLE public.historico_pagamento ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    431    430            �           2604    18065    historico_upload_favorecido id    DEFAULT     �   ALTER TABLE ONLY public.historico_upload_favorecido ALTER COLUMN id SET DEFAULT nextval('public.historico_upload_favorecido_id_seq'::regclass);
 M   ALTER TABLE public.historico_upload_favorecido ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    433    432                        2604    18066    historico_upload_sacado id    DEFAULT     �   ALTER TABLE ONLY public.historico_upload_sacado ALTER COLUMN id SET DEFAULT nextval('public.historico_upload_sacado_id_seq'::regclass);
 I   ALTER TABLE public.historico_upload_sacado ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    435    434                       2604    18067    importacao_personalizada id    DEFAULT     �   ALTER TABLE ONLY public.importacao_personalizada ALTER COLUMN id SET DEFAULT nextval('public.importacao_personalizada_id_seq'::regclass);
 J   ALTER TABLE public.importacao_personalizada ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    441    436                       2604    18068 !   importacao_personalizada_campo id    DEFAULT     �   ALTER TABLE ONLY public.importacao_personalizada_campo ALTER COLUMN id SET DEFAULT nextval('public.importacao_personalizada_campo_id_seq'::regclass);
 P   ALTER TABLE public.importacao_personalizada_campo ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    438    437                       2604    18069 &   importacao_personalizada_conta_fixo id    DEFAULT     �   ALTER TABLE ONLY public.importacao_personalizada_conta_fixo ALTER COLUMN id SET DEFAULT nextval('public.importacao_personalizada_conta_fixo_id_seq'::regclass);
 U   ALTER TABLE public.importacao_personalizada_conta_fixo ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    440    439                       2604    18070 )   importacao_personalizada_ignorar_linha id    DEFAULT     �   ALTER TABLE ONLY public.importacao_personalizada_ignorar_linha ALTER COLUMN id SET DEFAULT nextval('public.importacao_personalizada_ignorar_linha_id_seq'::regclass);
 X   ALTER TABLE public.importacao_personalizada_ignorar_linha ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    443    442                       2604    18071    item_contrato_cesta_servico id    DEFAULT     �   ALTER TABLE ONLY public.item_contrato_cesta_servico ALTER COLUMN id SET DEFAULT nextval('public.item_contrato_cesta_servico_id_seq1'::regclass);
 M   ALTER TABLE public.item_contrato_cesta_servico ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    450    448            	           2604    18072    item_contrato_numerario id    DEFAULT     �   ALTER TABLE ONLY public.item_contrato_numerario ALTER COLUMN id SET DEFAULT nextval('public.item_contrato_numerario_id_seq'::regclass);
 I   ALTER TABLE public.item_contrato_numerario ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    454    453                       2604    18073    loja id    DEFAULT     b   ALTER TABLE ONLY public.loja ALTER COLUMN id SET DEFAULT nextval('public.loja_id_seq'::regclass);
 6   ALTER TABLE public.loja ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    483    482                       2604    18074    lojas_com_coleta_excedente id    DEFAULT     �   ALTER TABLE ONLY public.lojas_com_coleta_excedente ALTER COLUMN id SET DEFAULT nextval('public.lojas_com_coleta_excedente_id_seq'::regclass);
 L   ALTER TABLE public.lojas_com_coleta_excedente ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    485    484                       2604    18075    notificacao id    DEFAULT     p   ALTER TABLE ONLY public.notificacao ALTER COLUMN id SET DEFAULT nextval('public.notificacao_id_seq'::regclass);
 =   ALTER TABLE public.notificacao ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    512    509                       2604    18076    notificacao_destinatario id    DEFAULT     �   ALTER TABLE ONLY public.notificacao_destinatario ALTER COLUMN id SET DEFAULT nextval('public.notificacao_destinatario_id_seq'::regclass);
 J   ALTER TABLE public.notificacao_destinatario ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    511    510                       2604    18077    notificacao_pagamento id    DEFAULT     �   ALTER TABLE ONLY public.notificacao_pagamento ALTER COLUMN id SET DEFAULT nextval('public.notificacao_pagamento_id_seq'::regclass);
 G   ALTER TABLE public.notificacao_pagamento ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    514    513                       2604    18078    notificacao_usuario id    DEFAULT     �   ALTER TABLE ONLY public.notificacao_usuario ALTER COLUMN id SET DEFAULT nextval('public.notificacao_usuario_id_seq'::regclass);
 E   ALTER TABLE public.notificacao_usuario ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    516    515                       2604    18079    numerario id    DEFAULT     l   ALTER TABLE ONLY public.numerario ALTER COLUMN id SET DEFAULT nextval('public.numerario_id_seq'::regclass);
 ;   ALTER TABLE public.numerario ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    520    517                       2604    18080    numerario_duplicidade id    DEFAULT     �   ALTER TABLE ONLY public.numerario_duplicidade ALTER COLUMN id SET DEFAULT nextval('public.numerario_duplicidade_id_seq'::regclass);
 G   ALTER TABLE public.numerario_duplicidade ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    519    518            #           2604    18081    recolhimento_transportadora id    DEFAULT     �   ALTER TABLE ONLY public.recolhimento_transportadora ALTER COLUMN id SET DEFAULT nextval('public.recolhimento_transportadora_id_seq'::regclass);
 M   ALTER TABLE public.recolhimento_transportadora ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    563    558            &           2604    18082 &   recolhimento_transportadora_analise id    DEFAULT     �   ALTER TABLE ONLY public.recolhimento_transportadora_analise ALTER COLUMN id SET DEFAULT nextval('public.recolhimento_transportadora_analise_id_seq'::regclass);
 U   ALTER TABLE public.recolhimento_transportadora_analise ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    560    559            '           2604    18083 *   recolhimento_transportadora_duplicidade id    DEFAULT     �   ALTER TABLE ONLY public.recolhimento_transportadora_duplicidade ALTER COLUMN id SET DEFAULT nextval('public.recolhimento_transportadora_duplicidade_id_seq'::regclass);
 Y   ALTER TABLE public.recolhimento_transportadora_duplicidade ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    562    561            Q           2604    34995    saldo_transito_cash id    DEFAULT     �   ALTER TABLE ONLY public.saldo_transito_cash ALTER COLUMN id SET DEFAULT nextval('public.saldo_transito_cash_id_seq'::regclass);
 E   ALTER TABLE public.saldo_transito_cash ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    662    663    663            -           2604    18084    status_monitoramento id    DEFAULT     �   ALTER TABLE ONLY public.status_monitoramento ALTER COLUMN id SET DEFAULT nextval('public.status_monitoramento_id_seq'::regclass);
 F   ALTER TABLE public.status_monitoramento ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    576    575            /           2604    18085    tarifa_divergente id    DEFAULT     }   ALTER TABLE ONLY public.tarifa_divergente ALTER COLUMN id SET DEFAULT nextval('public.tarifa_divergente_id_seq1'::regclass);
 C   ALTER TABLE public.tarifa_divergente ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    579    577            3           2604    18086    tipo_conta_pagar id    DEFAULT     z   ALTER TABLE ONLY public.tipo_conta_pagar ALTER COLUMN id SET DEFAULT nextval('public.tipo_conta_pagar_id_seq'::regclass);
 B   ALTER TABLE public.tipo_conta_pagar ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    591    590            4           2604    18087 "   tipo_identificacao_contribuinte id    DEFAULT     �   ALTER TABLE ONLY public.tipo_identificacao_contribuinte ALTER COLUMN id SET DEFAULT nextval('public.tipo_identificacao_contribuinte_id_seq'::regclass);
 Q   ALTER TABLE public.tipo_identificacao_contribuinte ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    595    594            6           2604    18088    tipo_operacao_numerario id    DEFAULT     �   ALTER TABLE ONLY public.tipo_operacao_numerario ALTER COLUMN id SET DEFAULT nextval('public.tipo_operacao_numerario_id_seq'::regclass);
 I   ALTER TABLE public.tipo_operacao_numerario ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    599    598            A           2604    18089    titulo_dda_duplicado id    DEFAULT     �   ALTER TABLE ONLY public.titulo_dda_duplicado ALTER COLUMN id SET DEFAULT nextval('public.titulo_dda_duplicado_id_seq'::regclass);
 F   ALTER TABLE public.titulo_dda_duplicado ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    609    608            F           2604    18090    transportadora id    DEFAULT     v   ALTER TABLE ONLY public.transportadora ALTER COLUMN id SET DEFAULT nextval('public.transportadora_id_seq'::regclass);
 @   ALTER TABLE public.transportadora ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    623    622            J           2604    18091    venda id    DEFAULT     d   ALTER TABLE ONLY public.venda ALTER COLUMN id SET DEFAULT nextval('public.venda_id_seq'::regclass);
 7   ALTER TABLE public.venda ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    641    640            K           2604    18092    verificacao_status id    DEFAULT     ~   ALTER TABLE ONLY public.verificacao_status ALTER COLUMN id SET DEFAULT nextval('public.verificacao_status_id_seq'::regclass);
 D   ALTER TABLE public.verificacao_status ALTER COLUMN id DROP DEFAULT;
       public       postgres    false    643    642            �          0    16409    arquivo_aud 
   TABLE DATA               �   COPY auditoria.arquivo_aud (id, rev, revtype, tipo_arquivo, nsa, nome, quantidade_lote, quantidade_pagamento, valor, data_criacao, data_inicial, data_final, checksum, data_hora_geracao_arquivo) FROM stdin;
 	   auditoria       postgres    false    197   6�
      �          0    16417 	   categoria 
   TABLE DATA               N   COPY auditoria.categoria (id, descricao, url, menu_log_id, ativo) FROM stdin;
 	   auditoria       postgres    false    199   S�
      �          0    16423    cliente_ftp_log_externo 
   TABLE DATA                 COPY auditoria.cliente_ftp_log_externo (id, empresa_id, diretorio_remoto_arquivo, diretorio_origem_arquivo, diretorio_upload, diretorio_upload_final, tipo_protocolo, tipo_ftp_encryption, tipo_transmissao_arquivo, nome_arquivo, mensagem, data_log) FROM stdin;
 	   auditoria       postgres    false    201   p�
      �          0    36184    conta_pagar_aud 
   TABLE DATA                 COPY auditoria.conta_pagar_aud (id, empresa_id, conta_pagar_id, tipo_conta_id, favorecido_id, nota_fiscal, data_vencimento, data_emissao, valor, status_conciliacao_anterior, ocorrencia, data_movimentacao, usuario_movimentacao_id, categoria_auditoria) FROM stdin;
 	   auditoria       postgres    false    673   ��
      �          0    16432    controle_acesso 
   TABLE DATA               m   COPY auditoria.controle_acesso (id, data_acesso, usuario_id, grupo_empresa_id, sub_categoria_id) FROM stdin;
 	   auditoria       postgres    false    203   ��
      �          0    16437    empresa_aud 
   TABLE DATA               a   COPY auditoria.empresa_aud (id, empresa_id, acao, data_acao, alteracoes, usuario_id) FROM stdin;
 	   auditoria       postgres    false    205   ��
      �          0    16445    frequencia_recolhimento_aud 
   TABLE DATA               �   COPY auditoria.frequencia_recolhimento_aud (id, rev, revtype, empresa_id, loja_id, transportadora_id, ativo, tipofrequencia, diassemana, datafixa, usuario_id, data_hora_criacao) FROM stdin;
 	   auditoria       postgres    false    207   ��
      �          0    16452    grupo_empresa_log 
   TABLE DATA               s   COPY auditoria.grupo_empresa_log (id, grupo_empresa_id, descricao, ativo, acao, data_acao, usuario_id) FROM stdin;
 	   auditoria       postgres    false    208   �
      �          0    16457    historico_usuario 
   TABLE DATA               �   COPY auditoria.historico_usuario (id, usuario_id, ocorrencia, categoria_auditoria, usuario_ocorrencia_id, data_ocorrencia) FROM stdin;
 	   auditoria       postgres    false    210   �
      �          0    16465    log_arquivos_particionados 
   TABLE DATA               �   COPY auditoria.log_arquivos_particionados (id, nome_arquivo_original, path_backup, nome_arquivos_particionados, data_backup) FROM stdin;
 	   auditoria       postgres    false    212   ��
      �          0    16473    menu_log 
   TABLE DATA               I   COPY auditoria.menu_log (id, projeto, descricao, url, ativo) FROM stdin;
 	   auditoria       postgres    false    214   ��
      �          0    16479    sub_categoria 
   TABLE DATA               S   COPY auditoria.sub_categoria (id, descricao, url, categoria_id, ativo) FROM stdin;
 	   auditoria       postgres    false    216   ��
      �          0    16485    titulo_dda_aud 
   TABLE DATA               �  COPY auditoria.titulo_dda_aud (id, rev, revtype, data_vencimento, cod_desconto_1, data_desconto_1, valor_desconto_1, cod_juros, juros_dia, baixa_manual, data_ocorrencia, autenticacao_pagamento, valor_pagamento, local_pagamento, usuario_alteracao_id, data_alteracao, valor_abatimento, valor_alterado, data_multa, valor_multa, nsa, banco_modificador, tipo_inscricao_avalista, inscricao_avalista, nome_avalista, valor_titulo, numero_documento_cobranca, cod_desconto_2, data_desconto_2, valor_desconto_2, cod_desconto_3, data_desconto_3, valor_desconto_3, cod_multa, cod_protesto, numero_dias_protesto, data_limite_pagamento, status_conciliacao, arquivo_id, cod_movimento, tipo_inscricao_cedente, inscricao_cedente, nome_cedente, status) FROM stdin;
 	   auditoria       postgres    false    218   ��
      �          0    16491    acesso_conta_auxiliar 
   TABLE DATA               �   COPY public.acesso_conta_auxiliar (id, controle_acesso_api_id, conta_id, conta_id_api, limite_minimo_saldo, atualizar_saldo_api, percentual_minimo) FROM stdin;
    public       postgres    false    219   �
      �          0    16496 &   agendamento_descricao_categoria_global 
   TABLE DATA               �   COPY public.agendamento_descricao_categoria_global (id, descricao_categoria_configuracao_id, empresa_id, agendado, conta_id) FROM stdin;
    public       postgres    false    221   (�
      �          0    16501    aplicacao_processamento 
   TABLE DATA               �   COPY public.aplicacao_processamento (id, desc_aplc, path, periodo_rendimento, saldo_minimo, taxa_rendimento, taxa_retirada, processamento_otimiza_id) FROM stdin;
    public       postgres    false    223   E�
      �          0    16508    arquivo 
   TABLE DATA               �   COPY public.arquivo (id, tipo_arquivo, convenio_id, nsa, nome, quantidade_lote, quantidade_pagamento, valor, data_criacao, controle_upload_arquivo_id, data_inicial, data_final, compromisso_id, checksum, data_hora_geracao_arquivo) FROM stdin;
    public       postgres    false    226   b�
      �          0    16515    arrecadacao 
   TABLE DATA               �   COPY public.arrecadacao (id, data, tarifa, valor, banco_id, forma_pagamento_arrecadacao_id, convenio_id, valor_liquido, data_credito, data_credito_calculada, linha_processada, arquivo_processado, id_cliente, empresa_id) FROM stdin;
    public       postgres    false    227   �
      �          0    16521    arrecadacao_001 
   TABLE DATA               �   COPY public.arrecadacao_001 (id, data, tarifa, valor, banco_id, forma_pagamento_arrecadacao_id, convenio_id, valor_liquido, data_credito, data_credito_calculada, linha_processada, arquivo_processado, id_cliente, empresa_id) FROM stdin;
    public       postgres    false    228   ��
      �          0    16528    arrecadacao_debito_automatico 
   TABLE DATA               $  COPY public.arrecadacao_debito_automatico (id, data, tarifa, valor, valor_liquido, data_credito, banco_id, forma_pagamento_arrecadacao_id, convenio_id, agencia_debito, conta_debito, dv_conta_debito, retorno_debito_id, tipo_cliente, cpf_cnpj, arquivo_processado, linha_processada) FROM stdin;
    public       postgres    false    229   ��
      �          0    16533    arrecadacao_divergente_contrato 
   TABLE DATA               �   COPY public.arrecadacao_divergente_contrato (id, data_arrecadacao, valor, valor_liquido, tarifa_cobrada, tarifa_contratada, diferenca, empresa_id, contrato_arrecadadora_id, chave_arrecadacao) FROM stdin;
    public       postgres    false    231   ��
                 0    16540 	   auditoria 
   TABLE DATA               e   COPY public.auditoria (id, usuario_id, data_ocorrencia, ocorrencia, categoria, revision) FROM stdin;
    public       postgres    false    234   ��
                0    16546    auditoria_crud 
   TABLE DATA               b   COPY public.auditoria_crud (id, "timestamp", usuario_id, grupo_empresa_id, categoria) FROM stdin;
    public       postgres    false    235   �
                0    16553    auditoria_suite 
   TABLE DATA               �   COPY public.auditoria_suite (id, usuario_id, data_ocorrencia, ocorrencia, categoria, grupo_empresa_id, data_auditoria) FROM stdin;
    public       postgres    false    238   ��
                0    16561    autorizacao_dependencia 
   TABLE DATA               U   COPY public.autorizacao_dependencia (id, convenio_id, usuario_id, ordem) FROM stdin;
    public       postgres    false    240   ��
                0    16566    autorizacao_pag 
   TABLE DATA               `   COPY public.autorizacao_pag (id, pagamento_id, usuario_id, valor, data_autorizacao) FROM stdin;
    public       postgres    false    242   ��
      
          0    16574    autorizacao_remessa 
   TABLE DATA               �   COPY public.autorizacao_remessa (id, obrigatorio, convenio_id, usuario_id, valor_maximo, valor_diario, compromisso_id) FROM stdin;
    public       postgres    false    244   ��
                0    16582 !   backup_grupo_pagamento_duplicados 
   TABLE DATA               �   COPY public.backup_grupo_pagamento_duplicados (pagamento_id, data_pagamento, valor, tipo_servico_id, tipo_grupo, forma_pagamento_id) FROM stdin;
    public       postgres    false    246   "�
                0    16588    banco 
   TABLE DATA               F   COPY public.banco (id, descricao, cod_banco, ativo, ispb) FROM stdin;
    public       postgres    false    247   ?�
                0    16591 	   banco_aud 
   TABLE DATA               R   COPY public.banco_aud (id, rev, revtype, descricao, cod_banco, ativo) FROM stdin;
    public       postgres    false    248   ��
                0    16596    banco_suportado_cobranca 
   TABLE DATA               @   COPY public.banco_suportado_cobranca (id, banco_id) FROM stdin;
    public       postgres    false    250   ��
                0    16601    bkp_grupo_lancamento 
   TABLE DATA               �   COPY public.bkp_grupo_lancamento (id, data, conta_id, categoria_lancamento_id, tarifa_origem_id, tipo_operacao_id, qtd_lancamentos, franquia, valor_unitario, valor_total, conciliado, data_conciliacao, tipo_conciliacao, usuario_id, descricao) FROM stdin;
    public       postgres    false    252   �
                0    16607    boleto 
   TABLE DATA               �  COPY public.boleto (id, valor_boleto, data_vencimento, linha_digitavel, tipo_boleto, segmento, valor_desconto, valor_multa, valor_pagar, forma_pagamento_id, banco_id, cnpj_cpf_avalista_old, cnpj_cpf_beneficiario_old, descricao_avalista_old, identificacao_contribuinte, identificador_contribuinte, identificacao_fgts, lacre_conectividade_social, digito_lacre_conectividade_social, codigo_barras, empresa_pagadora_id, tipo_beneficiario, nome_beneficiario, inscricao_beneficiario, tipo_avalista, nome_avalista, inscricao_avalista, pagamento_id, remessa, retorno, status, ocorrencia, autenticacao, valor_efetivado, data_efetivado, seu_numero, tipo_movimento, pagar, valor_tarifa, cod_identificacao_lote, aviso) FROM stdin;
    public       postgres    false    253   �
                0    16615    boleto_sem_pagamento 
   TABLE DATA               �  COPY public.boleto_sem_pagamento (id, valor_boleto, data_vencimento, linha_digitavel, tipo_boleto, segmento, valor_desconto, valor_multa, valor_pagar, forma_pagamento_id, banco_id, cnpj_cpf_avalista_old, cnpj_cpf_beneficiario_old, descricao_avalista_old, identificacao_contribuinte, identificador_contribuinte, identificacao_fgts, lacre_conectividade_social, digito_lacre_conectividade_social, codigo_barras, empresa_pagadora_id, tipo_beneficiario, nome_beneficiario, inscricao_beneficiario, tipo_avalista, nome_avalista, inscricao_avalista, pagamento_id, remessa, retorno, status, ocorrencia, autenticacao, valor_efetivado, data_efetivado, seu_numero, tipo_movimento, pagar) FROM stdin;
    public       postgres    false    255   ;�
                0    16623    card 
   TABLE DATA               �   COPY public.card (id, tipo_card_aviso, valor, quantidade, grupo_empresa_id, empresa_id, conta_id, data_ultima_atualizacao, hora_ultima_atualizacao) FROM stdin;
    public       postgres    false    257   X�
                0    16627    carteira_cobranca 
   TABLE DATA               e   COPY public.carteira_cobranca (id, banco_id, tipo_modalidade, descricao, codigo, numero) FROM stdin;
    public       postgres    false    258   u�
                0    16632    categoria_lancamento 
   TABLE DATA               �   COPY public.categoria_lancamento (id, descricao, concilia, data_inclusao, tipo_conciliacao, banco_id, tipo, codigo, tipo_categoria_lancamento_id) FROM stdin;
    public       postgres    false    260   ��
                0    16635    categoria_lancamento_new 
   TABLE DATA               �   COPY public.categoria_lancamento_new (id, descricao, concilia, data_inclusao, tipo_conciliacao, banco_id, tipo, codigo, tipo_categoria_lancamento_id, empresa_id) FROM stdin;
    public       postgres    false    261   ��
                0    16644 	   chave_pix 
   TABLE DATA               k   COPY public.chave_pix (id, favorecido_id, empresa_id, grupo_id, chave, tipo, ativo, principal) FROM stdin;
    public       postgres    false    265   ��
                 0    16653    cheque 
   TABLE DATA               �   COPY public.cheque (id, valor, numerocheque, conta_id, data_emissao, favorecido_id, observacao, statuscheque, data_processamento, lancamento_id, favorecido_id_old) FROM stdin;
    public       postgres    false    266   
�
      "          0    16658    cidade 
   TABLE DATA               :   COPY public.cidade (id, descricao, estado_id) FROM stdin;
    public       postgres    false    268   '�
      $          0    16666    cliente_ftp 
   TABLE DATA               �   COPY public.cliente_ftp (id, empresa_id, usuario, senha, host, porta, diretorio_origem, diretorio_destino, tipo_transmissao_arquivo, tipo_protocolo, tipo_ftp_encryption, ativo, descricao, formato_nome_arquivo, extensao_arquivo) FROM stdin;
    public       postgres    false    270   R�
      &          0    16675    cliente_ftp_log 
   TABLE DATA               �   COPY public.cliente_ftp_log (id, cliente_ftp_id, data_transmissao, nome_arquivos, erro, observacao, transmissao_sucesso, tratado, resolvido) FROM stdin;
    public       postgres    false    272   ��
      (          0    16685 
   clientsftp 
   TABLE DATA               l   COPY public.clientsftp (id, ativo, host, password, porta, remotedirectory, usuario, empresa_id) FROM stdin;
    public       postgres    false    274   ��
      *          0    16690    cobranca_instrucao 
   TABLE DATA               A  COPY public.cobranca_instrucao (id, desc_perc_um, desc_praz_um, desc_perc_dois, desc_praz_dois, desc_perc_tres, desc_praz_tres, juros_banco, juros_perc, multa_perc, multa_dias, tipo_prazo, prazo_devolucao, prazo_protesto, instrucao_um, instrucao_dois, instrucao_tres, instrucao_quatro, cobranca_parametro_id) FROM stdin;
    public       postgres    false    276   ��
      ,          0    16695    cobranca_parametro 
   TABLE DATA               �   COPY public.cobranca_parametro (id, numero_remessa, seu_numero, nosso_numero, tipo_titulo, tipo_moeda, tipo_forma_entrega, cidade_id, estado_id, convenio_id, layout_cobranca, carteira_cobranca_id, tipo_seu_numero, apelido, rateio_credito) FROM stdin;
    public       postgres    false    278   .�
      .          0    16701    codigo_receita 
   TABLE DATA               T   COPY public.codigo_receita (id, descricao, codigo, tipo_codigo_receita) FROM stdin;
    public       postgres    false    280   |�
      0          0    16709    compromisso 
   TABLE DATA               �   COPY public.compromisso (id, codigo_compromisso, parametro_transmissao, convenio_id, tipo_compromisso_id, layout, empresa_id, path, apelido, automatico, remessa) FROM stdin;
    public       postgres    false    282   ��
      �          0    35337    conciliacao_cash 
   TABLE DATA               K  COPY public.conciliacao_cash (id, faturamento_id, loja_id, chave_lancamento, valor_faturamento, saldo_cofre, data_faturamento, coleta_carro_forte, ajuste_coleta_deposito, diferenca_deposito, resolvido, status_conciliacao, usuario_id, motivo_diferenca, falha_recolhimento, data_conciliacao, lancamento_auxiliar_cash_id) FROM stdin;
    public       postgres    false    665   ��
      2          0    16715    conciliacao_cobranca 
   TABLE DATA               Q   COPY public.conciliacao_cobranca (grupo_titulo_id, chave_lancamento) FROM stdin;
    public       postgres    false    284   ��
      3          0    16718    conciliacao_financeira 
   TABLE DATA               4  COPY public.conciliacao_financeira (id, conciliado, data_liquidacao, chave_conciliacao, convenio_id, usuario_id, valor, tipo_transacao, data_conciliacao, chave_lancamento, origem_conciliacao, descricao, data_liquidacao_original, data_credito, ocorrencia_cobranca_id, tipo_conciliacao_financeira) FROM stdin;
    public       postgres    false    285   �
      6          0    16728 *   conciliacao_financeira_auxiliar_lancamento 
   TABLE DATA               �   COPY public.conciliacao_financeira_auxiliar_lancamento (id, chave_lancamento, conciliacao_financeira_id, conciliado) FROM stdin;
    public       postgres    false    288   2�
      7          0    16735 &   conciliacao_financeira_auxiliar_titulo 
   TABLE DATA               v   COPY public.conciliacao_financeira_auxiliar_titulo (id, titulo_id, conciliacao_financeira_id, conciliado) FROM stdin;
    public       postgres    false    289   O�
      9          0    16741    conciliacao_lancamento 
   TABLE DATA               W   COPY public.conciliacao_lancamento (grupo_lancamento_id, chave_lancamento) FROM stdin;
    public       postgres    false    291   l�
      :          0    16744    conciliacao_numerario 
   TABLE DATA               U   COPY public.conciliacao_numerario (grupo_numerario_id, chave_lancamento) FROM stdin;
    public       postgres    false    292   ��
      ;          0    16750    conciliacao_pagamento 
   TABLE DATA               U   COPY public.conciliacao_pagamento (grupo_pagamento_id, chave_lancamento) FROM stdin;
    public       postgres    false    293   ��
      <          0    16753    configuracao_sistema 
   TABLE DATA               �   COPY public.configuracao_sistema (id, arquivolog, diretoriofalha, diretorioleitura, diretoriosucesso, diretoriotemp) FROM stdin;
    public       postgres    false    294   ��
      >          0    16761    conta 
   TABLE DATA               �   COPY public.conta (id, agencia, conta, dv_conta, dv_agencia, banco_id, convenio_cartao, empresa_id, operacao, tiposaldo, tipoconta, justificar_pagamento, ativo) FROM stdin;
    public       postgres    false    296   ��
      @          0    16767    conta_lancamento 
   TABLE DATA               C   COPY public.conta_lancamento (id, descricao, conta_id) FROM stdin;
    public       postgres    false    298   V�
      A          0    16770    conta_lancamento_fluxo_caixa 
   TABLE DATA               O   COPY public.conta_lancamento_fluxo_caixa (id, descricao, conta_id) FROM stdin;
    public       postgres    false    299   s�
      D          0    16777    conta_pagar 
   TABLE DATA               �  COPY public.conta_pagar (id, favorecido_id, codigo_conta, nota_fiscal, valor, data_emissao, data_pagamento, data_vencimento, valor_desconto, valor_abatimento, juros, valor_multa, parcela, chave_acesso, tipo_conta_id, conciliado_nf, status_conciliacao_dda, titulo_dda_id, empresa_id, valor_pago, convenio_id, usuario_conciliou_id, data_conciliacao, tipo_divergencia, lote_favorecido_id, data_processamento, controle_upload_arquivo_id) FROM stdin;
    public       postgres    false    302   ��
      F          0    16791    conta_pagar_log 
   TABLE DATA               �   COPY public.conta_pagar_log (id, controle_upload_arquivo_id, descricao, linha_processada, data_processamento, conta_pagar_id) FROM stdin;
    public       postgres    false    304   ��
      I          0    16801    contrato 
   TABLE DATA               �  COPY public.contrato (id, ativo, data_inicio, data_fim, banco_id, empresa_id, convenio_id, conta_id, compromisso_id, tipo_servico_id, float_padrao, float_negociado, float_tarifa, tipo_contrato, modalidade, float_credito, forma_tarifacao, reprocessar, tarifa_contra_cheque, emite_contra_cheque, transportadora_id, coleta_diaria_por_loja, custo_recolhimento, malote, cofre_inteligente, float_cofre_inteligente, horario_de_corte, tipo_conciliacao_cash, tipo_conciliacao_numerario) FROM stdin;
    public       postgres    false    307   ��
      J          0    16812    contrato_arrecadadora 
   TABLE DATA               �   COPY public.contrato_arrecadadora (id, data_fim, data_inicio, descricao, percentual, tarifa, banco_id, forma_pagamento_arrecadacao_id, ativo, empresa_id) FROM stdin;
    public       postgres    false    308   ��
      L          0    16817    contrato_bancario 
   TABLE DATA               �   COPY public.contrato_bancario (id, banco_id, empresa_id, conta_id, data_inicio, data_fim, tipo_contrato_bancario_id, modalidade_contrato_bancario_id, usuario_id, data_inclusao, descricao) FROM stdin;
    public       postgres    false    310   �
      N          0    16822    contrato_loja 
   TABLE DATA               =   COPY public.contrato_loja (contrato_id, loja_id) FROM stdin;
    public       postgres    false    312   !�
      O          0    16825    controle_acesso_api 
   TABLE DATA               !  COPY public.controle_acesso_api (id, usuario, senha, secret_key, client_id, empresa_id, grupo_empresa_id, acess_token, data_acess_token, hora_acess_token, refresh_token, data_refresh_token, hora_refresh_token, tempo_expiracao_acess_token, tempo_expiracao_refresh_token, ativo) FROM stdin;
    public       postgres    false    313   >�
      Q          0    16833    controle_bloqueio_usuario 
   TABLE DATA               w   COPY public.controle_bloqueio_usuario (id, usuario_id, tentativa, data_bloqueio, bloqueado, login_sucesso) FROM stdin;
    public       postgres    false    315   [�
      S          0    16838    controle_card 
   TABLE DATA               T   COPY public.controle_card (id, usuario_id, chave_card, tab_view, ativo) FROM stdin;
    public       postgres    false    317   x�
      U          0    16846    controle_nsa 
   TABLE DATA                  COPY public.controle_nsa (id, empresa_id, nome_antigo, nome_novo, nsa, tipo_arquivo, data_catalogacao, catalogado) FROM stdin;
    public       postgres    false    319   ��
      V          0    16849    controle_nsa_arrecadacao 
   TABLE DATA               V   COPY public.controle_nsa_arrecadacao (id, tipoarrecadacao, nsa, banco_id) FROM stdin;
    public       postgres    false    320   ��
      Y          0    16856    controle_nsa_optantes_debito 
   TABLE DATA               L   COPY public.controle_nsa_optantes_debito (id, nsa, convenio_id) FROM stdin;
    public       postgres    false    323   ��
      \          0    16863    controle_nsa_remessa 
   TABLE DATA               P   COPY public.controle_nsa_remessa (id, convenio_id, empresa_id, nsa) FROM stdin;
    public       postgres    false    326   ��
      ]          0    16867    controle_processamento 
   TABLE DATA               `   COPY public.controle_processamento (id, data, grupo_empresa_id, tipo_processamento) FROM stdin;
    public       postgres    false    327   	�
      ^          0    16870     controle_remessa_optantes_debito 
   TABLE DATA               j   COPY public.controle_remessa_optantes_debito (id, data, tipo_remessa, arquivo_id, usuario_id) FROM stdin;
    public       postgres    false    328   &�
      `          0    16875    controle_senha 
   TABLE DATA               E   COPY public.controle_senha (id, usuario_id, senha, data) FROM stdin;
    public       postgres    false    330   C�
      b          0    16880    controle_upload_arquivo 
   TABLE DATA               �   COPY public.controle_upload_arquivo (id, data_upload, usuario_id, nome_arquivo, status_upload, tipo_arquivo, grupo_empresa_id, erro, novo_nome_arquivo, empresa_id, diretorio, importacao_personalizada_id) FROM stdin;
    public       postgres    false    332   `�
      d          0    16888    convenio 
   TABLE DATA               U  COPY public.convenio (id, codigo_convenio, empresa_id, tipo_convenio, layout, remessa, seq_seu_numero, banco_id, valor_referencia, ativo, apelido, arquivo_pre_autorizado, apelido_transmissao, path, automatico, usuario_id, data_hora_criacao, usuario_validador, data_hora_validacao, copia_retorno_ftp, cliente_ftp_id, uso_interno) FROM stdin;
    public       postgres    false    334   }�
      e          0    16899    convenio_aud 
   TABLE DATA               $  COPY public.convenio_aud (id, rev, revtype, codigo_convenio, tipo_convenio, layout, remessa, seq_seu_numero, valor_referencia, arquivo_pre_autorizado, apelido_transmissao, path, automatico, usuario_id, data_hora_criacao, usuario_validador, data_hora_validacao, copia_retorno_ftp) FROM stdin;
    public       postgres    false    335   m�
      f          0    16905    convenio_configuracao 
   TABLE DATA               �   COPY public.convenio_configuracao (convenio_id, cliente_baixa_pagamento_id, baixa_pagamento_automatica, incluir_pagamento_remessa) FROM stdin;
    public       postgres    false    336    �
      h          0    16912    convenio_conta 
   TABLE DATA               C   COPY public.convenio_conta (id, convenio_id, conta_id) FROM stdin;
    public       postgres    false    338   I�
      i          0    16916    convenio_empresa 
   TABLE DATA               G   COPY public.convenio_empresa (id, convenio_id, empresa_id) FROM stdin;
    public       postgres    false    339   ��
      k          0    16921    convenio_extrato 
   TABLE DATA               O   COPY public.convenio_extrato (id, nome_empresa, cnpj, convenio_id) FROM stdin;
    public       postgres    false    341   ��
      n          0    16928    convenio_pagamento 
   TABLE DATA               X   COPY public.convenio_pagamento (id, convenio_id, path, apelido, automatico) FROM stdin;
    public       postgres    false    344    �
      p          0    16933    credencial_acesso_empresa 
   TABLE DATA               �   COPY public.credencial_acesso_empresa (id, empresa_id, client_id, client_secret, credencial_base64, data_geracao, hora_geracao, acess_token, data_acess_token_geracao, hora_acess_token_geracao, ativo) FROM stdin;
    public       postgres    false    346   =�
      r          0    16941    descricao_lancamento 
   TABLE DATA               }   COPY public.descricao_lancamento (id, descricao, banco_id, empresa_id, categoria_lancamento_id, codigo, tratado) FROM stdin;
    public       postgres    false    348   Z�
      t          0    16947    descricao_lancamento_new 
   TABLE DATA               �   COPY public.descricao_lancamento_new (id, descricao, banco_id, empresa_id, categoria_lancamento_id, codigo, tratado, per_somente_credito, descricao_completa, lancamento_confidencial) FROM stdin;
    public       postgres    false    350   w�
      u          0    16952 >   descricao_lancamento_new_categoria_lancamento_new_configuracao 
   TABLE DATA               #  COPY public.descricao_lancamento_new_categoria_lancamento_new_configuracao (id, categoria_lancamento_new_id, descricao_lancamento_new_id, descricao_configuracao, somente_credito, data_edicao, hora_edicao, motor_agendado, rede_id_conciliador, bandeira_id_conciliador, usuario_id) FROM stdin;
    public       postgres    false    351   ��
      x          0    16964    despesa_processamento 
   TABLE DATA               e   COPY public.despesa_processamento (id, data, descricao, valor, processamento_otimiza_id) FROM stdin;
    public       postgres    false    354   ��
      �          0    35572    documentacao 
   TABLE DATA               �   COPY public.documentacao (id, modulo, tipo_arquivo, finalidade, descricao, versao, nome_arquivo, formato_arquivo, arquivo, data_cadastro, ativo) FROM stdin;
    public       postgres    false    669   ��
      z          0    16969    download 
   TABLE DATA               w   COPY public.download (id, usuario_id, data_geracao, nome_arquivo, quantidade_registros, tipo_arquivo, nsa) FROM stdin;
    public       postgres    false    356   �:      |          0    16974    email 
   TABLE DATA               ~   COPY public.email (id, data_envio, titulo, corpo, destinatario, tipo_email, enviado, reenviado, grupo_empresa_id) FROM stdin;
    public       postgres    false    358   �:      ~          0    16982    empresa 
   TABLE DATA               �   COPY public.empresa (id, razao_social, nome_fantasia, email, cnpj, telefone, logradouro, complemento, bairro, cep, grupo_empresa_id, ativo, estado_id, cidade_id, numero, telefone2, esfera_atuacao, status, cocriacao, empresa_matriz_id) FROM stdin;
    public       postgres    false    360   �:      �          0    16994    empresa_transportadora 
   TABLE DATA               c   COPY public.empresa_transportadora (id, empresa_id, transportadora_id, usuario, senha) FROM stdin;
    public       postgres    false    363   �;      �          0    17004    emprestimo_processamento 
   TABLE DATA               f   COPY public.emprestimo_processamento (id, oferta, taxa, limite, processamento_otimiza_id) FROM stdin;
    public       postgres    false    366   �;      �          0    17008    estado 
   TABLE DATA               3   COPY public.estado (id, descricao, uf) FROM stdin;
    public       postgres    false    367   �;      �          0    17016 	   faixa_cep 
   TABLE DATA               N   COPY public.faixa_cep (id, estado_id, faixa_inicial, faixa_final) FROM stdin;
    public       postgres    false    369   <      �          0    17021    faixa_nosso_numero_sacado 
   TABLE DATA               e   COPY public.faixa_nosso_numero_sacado (id, ativo, fim, inicio, sacado_id, data_insercao) FROM stdin;
    public       postgres    false    371   "<      �          0    17024    faixa_nosso_numero_sacado_aud 
   TABLE DATA               e   COPY public.faixa_nosso_numero_sacado_aud (id, rev, revtype, data_insercao, fim, inicio) FROM stdin;
    public       postgres    false    372   ?<      �          0    17029    faq 
   TABLE DATA               @   COPY public.faq (id, tp_modulo, pergunta, resposta) FROM stdin;
    public       postgres    false    374    D      �          0    17037    faturamento 
   TABLE DATA               �   COPY public.faturamento (id, empresa_id, loja_id, valor_faturamento, data_faturamento, transportadora_id, conciliado) FROM stdin;
    public       postgres    false    376   D      �          0    17045 
   favorecido 
   TABLE DATA               ?  COPY public.favorecido (id, nome, email, cnpj_cpf, telefone, logradouro, complemento, bairro, cep, grupo_id, ativo, agencia, dv_agencia, conta, dv_conta, banco_id, valor, estado_id, tipo_favorecido, pendente_verificacao, codigo, operacao, cidade_id, portal_pagamento, dv_agencia_conta, numero, tipo_pessoa) FROM stdin;
    public       postgres    false    378   :D      �          0    17052    favorecido_aud 
   TABLE DATA                 COPY public.favorecido_aud (id, rev, revtype, nome, email, cnpj_cpf, telefone, logradouro, complemento, bairro, cep, ativo, agencia, dv_agencia, conta, dv_conta, valor, pendente_verificacao, codigo, operacao, portal_pagamento, numero, tipo_pessoa) FROM stdin;
    public       postgres    false    379   WD      �          0    17059    favorecido_conta 
   TABLE DATA               �   COPY public.favorecido_conta (id, banco_id, favorecido_id, agencia, dv_agencia, conta, dv_conta, dv_agencia_conta, operacao, ativo, principal, favorecido_id_old) FROM stdin;
    public       postgres    false    380   tD      �          0    17064    favorecido_conta_aud 
   TABLE DATA               �   COPY public.favorecido_conta_aud (id, rev, revtype, banco_id, favorecido_id, agencia, dv_agencia, conta, dv_conta, dv_agencia_conta, operacao, ativo, principal, favorecido_id_old, favorecido_conta_id) FROM stdin;
    public       postgres    false    381   �D      �          0    17071    feriado 
   TABLE DATA               ?   COPY public.feriado (id, dia, mes, ano, descricao) FROM stdin;
    public       postgres    false    384   �D      �          0    17076    float 
   TABLE DATA               [   COPY public."float" (id, valorfloat, banco_id, forma_pagamento_arrecadacao_id) FROM stdin;
    public       postgres    false    386   �D      �          0    17081    forma_pagamento 
   TABLE DATA               t   COPY public.forma_pagamento (banco_id, descricao, codigo, id, descricao_resumida, tipo_forma_pagamento) FROM stdin;
    public       postgres    false    388   �D      �          0    17087    forma_pagamento_arrecadacao 
   TABLE DATA               R   COPY public.forma_pagamento_arrecadacao (id, codigo, descricao, nome) FROM stdin;
    public       postgres    false    389   E      �          0    17092    forma_pagamento_fluxo_caixa 
   TABLE DATA               T   COPY public.forma_pagamento_fluxo_caixa (id, empresa, nome, empresa_id) FROM stdin;
    public       postgres    false    391   "E      �          0    17104    frequencia_recolhimento 
   TABLE DATA               �   COPY public.frequencia_recolhimento (id, empresa_id, loja_id, transportadora_id, ativo, tipofrequencia, usuario_id, data_hora_criacao) FROM stdin;
    public       postgres    false    395   ?E      �          0    17110 #   grafico_arrecadacao_forma_pagamento 
   TABLE DATA               �   COPY public.grafico_arrecadacao_forma_pagamento (id, data, quantidade, valor_arrecadado, convenio_id, forma_pagamento_arrecadacao_id) FROM stdin;
    public       postgres    false    397   \E      �          0    17116    grupo 
   TABLE DATA               K   COPY public.grupo (id, descricao, empresa_id, tipo_favorecido) FROM stdin;
    public       postgres    false    399   yE      �          0    17119    grupo_autorizacao_convenio 
   TABLE DATA               o   COPY public.grupo_autorizacao_convenio (id, descricao, convenio_id, quantidade_autorizacao, ordem) FROM stdin;
    public       postgres    false    400   �E      �          0    17126 "   grupo_autorizacao_convenio_usuario 
   TABLE DATA               g   COPY public.grupo_autorizacao_convenio_usuario (usuario_id, grupo_autorizacao_convenio_id) FROM stdin;
    public       postgres    false    402   �E      �          0    17129    grupo_empresa 
   TABLE DATA               =   COPY public.grupo_empresa (id, descricao, ativo) FROM stdin;
    public       postgres    false    403   �E      �          0    17138    grupo_lancamento 
   TABLE DATA               �   COPY public.grupo_lancamento (id, data, conta_id, categoria_lancamento_id, tarifa_origem_id, tipo_operacao_id, qtd_lancamentos, franquia, valor_unitario, valor_total, conciliado, data_conciliacao, tipo_conciliacao, usuario_id, descricao) FROM stdin;
    public       postgres    false    407   (F      �          0    17146    grupo_lancamento_fluxo_caixa 
   TABLE DATA               m   COPY public.grupo_lancamento_fluxo_caixa (id, nome, tipolancamento, empresa_id, tipo_lancamento) FROM stdin;
    public       postgres    false    408   EF      �          0    17154    grupo_numerario 
   TABLE DATA               �   COPY public.grupo_numerario (id, data_recolhimento, valor_recolhimento, empresa_id, transportadora_id, contrato_id, usuario_id, conciliado) FROM stdin;
    public       postgres    false    410   bF      �          0    17165    grupo_pagamento 
   TABLE DATA               �   COPY public.grupo_pagamento (id, data_pagamento, valor, conciliado, tipo_servico_id, tipo_grupo, forma_pagamento_id, pagamento_id, data_conciliacao, tipo_conciliacao, usuario_id) FROM stdin;
    public       postgres    false    413   F      �          0    17175    grupo_sacado 
   TABLE DATA               H   COPY public.grupo_sacado (id, descricao, ativo, empresa_id) FROM stdin;
    public       postgres    false    415   �F      �          0    17178    grupo_sacado_ext 
   TABLE DATA               F   COPY public.grupo_sacado_ext (grupo_sacado_id, sacado_id) FROM stdin;
    public       postgres    false    416   �F      �          0    17183    grupo_titulo 
   TABLE DATA               �   COPY public.grupo_titulo (id, data_liquidacao, data_credito, convenio_id, detalhamento, valor, tipo_transacao, data_conciliacao, origem_conciliacao, conciliado, usuario_id, movimento_retorno_cobranca_id) FROM stdin;
    public       postgres    false    418   �F      �          0    17191    grupopermissao 
   TABLE DATA               :   COPY public.grupopermissao (id, nome, modulo) FROM stdin;
    public       postgres    false    420   �F      �          0    17194    guia_transporte_valores 
   TABLE DATA               �   COPY public.guia_transporte_valores (id, empresa_id, loja_id, transportadora_id, usuario_id, valor_total, data_recolhimento, diretorio_imagem_gtv, data_cadastro, codigo_gtv, quantidade_moeda, valor_moeda, quantidade_cedula, valor_cedula) FROM stdin;
    public       postgres    false    421   G      �          0    17204 !   historico_frequencia_recolhimento 
   TABLE DATA               �   COPY public.historico_frequencia_recolhimento (id, frequencia_recolhimento_id, ativo, usuario_id, data_ocorrencia, ocorrencia, categoria_auditoria) FROM stdin;
    public       postgres    false    424   -G      �          0    17213    historico_monitoramento 
   TABLE DATA               �   COPY public.historico_monitoramento (id, usuario_id, pagamento_id, data_criacao, status_monitoramento_id, descricao) FROM stdin;
    public       postgres    false    426   JG      �          0    17218    historico_optantes_debito 
   TABLE DATA               t   COPY public.historico_optantes_debito (id, id_cliente, data, banco_id, agencia, conta, dv_conta, ativo) FROM stdin;
    public       postgres    false    428   gG      �          0    17223    historico_pagamento 
   TABLE DATA               �   COPY public.historico_pagamento (id, usuario_id, pagamento_id, tipo_favorecido, data_ocorrencia, ocorrencia, categoria_auditoria) FROM stdin;
    public       postgres    false    430   �G      �          0    17231    historico_upload_favorecido 
   TABLE DATA               z   COPY public.historico_upload_favorecido (id, linha_processada, descricao, controle_upload_arquivo_id, status) FROM stdin;
    public       postgres    false    432   �G      �          0    17239    historico_upload_sacado 
   TABLE DATA               v   COPY public.historico_upload_sacado (id, linha_processada, descricao, status, controle_upload_arquivo_id) FROM stdin;
    public       postgres    false    434   �G      �          0    17247    importacao_personalizada 
   TABLE DATA               �   COPY public.importacao_personalizada (id, empresa_id, nome, tipo_arquivo, tipo_formato_arquivo, tipo_importacao_personalizada, delimitador, inicio_arquivo, transportadora_id) FROM stdin;
    public       postgres    false    436   �G      �          0    17253    importacao_personalizada_campo 
   TABLE DATA               �   COPY public.importacao_personalizada_campo (id, importacao_personalizada_id, nome, coluna, formato, inicio, fim, agrupar) FROM stdin;
    public       postgres    false    437   �G      �          0    17261 #   importacao_personalizada_conta_fixo 
   TABLE DATA               �   COPY public.importacao_personalizada_conta_fixo (id, importacao_personalizada_id, linha, coluna, posicao_agencia, posicao_conta, posicao_digito_conta, conta_id) FROM stdin;
    public       postgres    false    439   H      �          0    17268 &   importacao_personalizada_ignorar_linha 
   TABLE DATA               }   COPY public.importacao_personalizada_ignorar_linha (id, importacao_personalizada_id, valor, coluna, inicio, fim) FROM stdin;
    public       postgres    false    442   2H      �          0    17276    item_contrato_bancario 
   TABLE DATA               �   COPY public.item_contrato_bancario (id, contrato_bancario_id, descricao_lancamento_id, tarifa_agencia, tarifa_internet, tarifa_convenio, tarifa_auto_atendimento, franquia, periodicidade) FROM stdin;
    public       postgres    false    444   OH      �          0    17283    item_contrato_bancario_pendente 
   TABLE DATA               �   COPY public.item_contrato_bancario_pendente (id, descricao, periodo, empresa_id, banco_id, conta_id, convenio_id, tarifa, pendente) FROM stdin;
    public       postgres    false    447   lH      �          0    17291    item_contrato_cesta_servico 
   TABLE DATA               �   COPY public.item_contrato_cesta_servico (id, tarifa, franquia, periodicidade, contrato_id, tarifa_origem_id, tipo_operacao_cesta_servico_id) FROM stdin;
    public       postgres    false    448   �H      �          0    17303    item_contrato_cobranca 
   TABLE DATA               �   COPY public.item_contrato_cobranca (id, tarifa, movimento_retorno_cobranca_id, ocorrencia_cobranca_id, contrato_id) FROM stdin;
    public       postgres    false    452   �H      �          0    17310    item_contrato_numerario 
   TABLE DATA                  COPY public.item_contrato_numerario (id, tarifa, franquia, periodicidade, tipo_operacao_numerario_id, contrato_id) FROM stdin;
    public       postgres    false    453   �H      �          0    17318    item_contrato_numerario_loja 
   TABLE DATA               [   COPY public.item_contrato_numerario_loja (item_contrato_numerario_id, loja_id) FROM stdin;
    public       postgres    false    455   �H      �          0    17323    item_contrato_pagamento 
   TABLE DATA               w   COPY public.item_contrato_pagamento (id, tarifa_padrao, tarifa_negociada, contrato_id, forma_pagamento_id) FROM stdin;
    public       postgres    false    457   �H      �          0    17330 !   item_grupo_lancamento_fluxo_caixa 
   TABLE DATA               Z   COPY public.item_grupo_lancamento_fluxo_caixa (id, nome, grupo_lancamento_id) FROM stdin;
    public       postgres    false    458   I      �          0    34672    lancamento_auxiliar_cash 
   TABLE DATA               �   COPY public.lancamento_auxiliar_cash (id, empresa_id, chave_lancamento, valor_lancamento, data_lancamento, loja_id, descricao_completa, categoria_lancamento_id, vinculo_categoria_cash_id) FROM stdin;
    public       postgres    false    660   7I      �          0    17335    lancamento_debito 
   TABLE DATA               m   COPY public.lancamento_debito (id, optantes_debito_id, data_vencimento, valor, codigo_movimento) FROM stdin;
    public       postgres    false    460   TI      �          0    17340    lancamento_debito_remessa 
   TABLE DATA               n   COPY public.lancamento_debito_remessa (lancamento_debito_id, controle_remessa_optantes_debito_id) FROM stdin;
    public       postgres    false    462   qI      �          0    17345    lancamento_duplicado 
   TABLE DATA               �   COPY public.lancamento_duplicado (id, lancamento_id, controle_upload_arquivo_id, linha_processada, data_processamento, tipo_arquivo) FROM stdin;
    public       postgres    false    464   �I      �          0    17349    lancamento_fluxo_caixa 
   TABLE DATA               �   COPY public.lancamento_fluxo_caixa (id, contalancamento, data, descricao, pago, valor, forma_pagamnto_id, conta_lancamento_id, empresa_id, item_grupo_lancamento_id) FROM stdin;
    public       postgres    false    465   �I      �          0    17355    lancamento_new 
   TABLE DATA               �  COPY public.lancamento_new (convenio_id, data_lancamento, valor, tipo, nsa, descricao_id, id, nome_arquivo, chave_lancamento, empresa_id, banco_id, usuario_logado_id, descricao_detalhada, campo_identificador, conciliado, linha_processada, hash_conteudo_arquivo, data_arquivo_geracao, desabilitado_webservice, historico_lancamento, observacao_motivo, fitid, conta_id, tipo_arquivo, chave_lancamento_new, status, data_processamento, editado, descricao_detalhada_completa) FROM stdin;
    public       postgres    false    466   �I      �          0    17364    layout_campo 
   TABLE DATA               X   COPY public.layout_campo (id, fim, inicio, nome, tipoarrecadacao, banco_id) FROM stdin;
    public       postgres    false    468   �I      �          0    17369    layout_campo_pagamento 
   TABLE DATA               �   COPY public.layout_campo_pagamento (id, fim, inicio, nome, tipo_arquivo_pagamento_flexivel, empresa_id, compromisso_id) FROM stdin;
    public       postgres    false    470   J      �          0    17374    limite_especial 
   TABLE DATA               v   COPY public.limite_especial (id, valor, convenio_id, data_inicial, data_final, data_inclusao, usuario_id) FROM stdin;
    public       postgres    false    472   J      �          0    17382 
   log_acesso 
   TABLE DATA               r   COPY public.log_acesso (id, usuario_id, data_acesso, ip, browser, grupo_empresa_id, usuario_original) FROM stdin;
    public       postgres    false    474   <J      �          0    17387    log_baixa_ftp 
   TABLE DATA               l   COPY public.log_baixa_ftp (id, tipo_protocolo, diretorio, nome_arquivo, mensagem_log, checksum) FROM stdin;
    public       postgres    false    476   YJ      �          0    17397    log_erro_catalogador 
   TABLE DATA               e   COPY public.log_erro_catalogador (id, data, nomearquivo, erro, diretorio_origem_arquivo) FROM stdin;
    public       postgres    false    479   vJ      �          0    17404    log_erro_processador 
   TABLE DATA               e   COPY public.log_erro_processador (id, data, erro, nome_arquivo, empresa_id, processador) FROM stdin;
    public       postgres    false    480   �J      �          0    17412    loja 
   TABLE DATA               H  COPY public.loja (id, codigo, descricao, descricao_equivalente, empresa_id, cnpj, razao_social, email, telefone, celular, ativa, cep, logradouro, complemento, bairro, estado_id, cidade_id, numero, empresa_transportadora_id, codigo_equipamento, valor_segurado, gerente_loja, gerente_loja_email, gerente_loja_celular) FROM stdin;
    public       postgres    false    482   �J      �          0    17421    lojas_com_coleta_excedente 
   TABLE DATA               �   COPY public.lojas_com_coleta_excedente (id, data_recolhimento, descricao, data_hora_acao, status_coleta, loja_id, recolhimento_transportadora_id, usuario_id) FROM stdin;
    public       postgres    false    484   �J      �          0    17429    lote_boleto 
   TABLE DATA               �   COPY public.lote_boleto (id, pagamento_id, boleto_id, valor, valor_efetivado, data_efetivado, ocorrencia, remessa, retorno, status, valor_desconto, valor_multa, autenticacao, seu_numero, descricao_beneficiario, pagar, tipo_movimento) FROM stdin;
    public       postgres    false    486   �J      �          0    17437 
   lote_carne 
   TABLE DATA               U   COPY public.lote_carne (id, titulo_id, titulo_associado_id, convenio_id) FROM stdin;
    public       postgres    false    488   K                 0    17442    lote_favorecido 
   TABLE DATA               �  COPY public.lote_favorecido (id, pagamento_id, favorecido_id, valor, valor_efetivado, data_efetivado, ocorrencia, remessa, retorno, status, pagar, num_doc_banco, forma_pagamento_id, agencia, dv_agencia, conta, dv_conta, banco_id, seu_numero, autenticacao, codigo_complemento_servico, dv_agencia_conta, codigo_favorecido, operacao, tipo_movimento, favorecido_conta_id, favorecido_id_old, valor_tarifa, cod_identificacao_lote, aviso, chave_pix_id) FROM stdin;
    public       postgres    false    490   $K                0    17448    lote_favorecido_aud 
   TABLE DATA               r  COPY public.lote_favorecido_aud (id, rev, revtype, pagamento_id, favorecido_id, valor, seu_numero, valor_efetivado, num_doc_banco, data_efetivado, ocorrencia, status, pagar, operacao, tipo_movimento, favorecido_conta_id, remessa, retorno, autenticacao, codigo_favorecido, codigo_complemento_servico, valor_tarifa, data_tarifa, cod_identificacao_lote, aviso) FROM stdin;
    public       postgres    false    491   AK                0    17456    lote_pag_aux 
   TABLE DATA               ]   COPY public.lote_pag_aux (id, pagamento_id, lote_favorecido_id, num_doc_empresa) FROM stdin;
    public       postgres    false    493   ^K                0    17464    mensagem_arquivo 
   TABLE DATA               �   COPY public.mensagem_arquivo (id, mensagem, numero_linha, nome_registro, nome_zona, nome_campo, inicio_campo, fim_campo, descricao_campo, controle_upload_arquivo_id, texto_linha) FROM stdin;
    public       postgres    false    495   {K                0    17472    mensagem_titulo 
   TABLE DATA               `   COPY public.mensagem_titulo (id, ativo, mensagem, tipo_mensagem_titulo, empresa_id) FROM stdin;
    public       postgres    false    497   �K      	          0    17477    modalidade_contrato_bancario 
   TABLE DATA               E   COPY public.modalidade_contrato_bancario (id, descricao) FROM stdin;
    public       postgres    false    499   �K                0    17482    modulo 
   TABLE DATA               $   COPY public.modulo (id) FROM stdin;
    public       postgres    false    501   �K                0    17487    movimento_pagamento 
   TABLE DATA               Z   COPY public.movimento_pagamento (id, data, nsa, tipo_movimento, pagamento_id) FROM stdin;
    public       postgres    false    503   �K                0    17492    movimento_remessa_cobranca 
   TABLE DATA               t   COPY public.movimento_remessa_cobranca (id, descricao, codigo, banco_id, tipo_movimento_remessa, ativo) FROM stdin;
    public       postgres    false    505   L                0    17500    movimento_retorno_cobranca 
   TABLE DATA               x   COPY public.movimento_retorno_cobranca (id, descricao, codigo, tipo_movimento_retorno, layout, gera_tarifa) FROM stdin;
    public       postgres    false    507   )L                0    17509    notificacao 
   TABLE DATA               h   COPY public.notificacao (id, data_inicio, data_fim, conteudo, titulo, data_cadastro, ativo) FROM stdin;
    public       postgres    false    509   FL                0    17515    notificacao_destinatario 
   TABLE DATA               �   COPY public.notificacao_destinatario (id, notificacao_id, modulo_notificado, grupo_empresa_notificado_id, empresa_notificado_id, perfil_notificado_id, usuario_notificado_id) FROM stdin;
    public       postgres    false    510   cL                0    17522    notificacao_pagamento 
   TABLE DATA               {   COPY public.notificacao_pagamento (id, banco_id, pagamento_id, data_envio, status_pagamento, tipo_notificacao) FROM stdin;
    public       postgres    false    513   �L                0    17527    notificacao_usuario 
   TABLE DATA               g   COPY public.notificacao_usuario (id, notificacao_id, usuario_notificado_id, data_cadastro) FROM stdin;
    public       postgres    false    515   �L                0    17532 	   numerario 
   TABLE DATA               �   COPY public.numerario (id, empresa_id, loja_id, controle_upload_arquivo_id, data, valor, chave, status_conciliacao_recolhimento, data_conciliacao_numerario, tipo_divergencia, usuario_conciliou_id, grupo_numerario_id, divergencia) FROM stdin;
    public       postgres    false    517   �L                0    17539    numerario_duplicidade 
   TABLE DATA               ]   COPY public.numerario_duplicidade (id, numerario_id, controle_upload_arquivo_id) FROM stdin;
    public       postgres    false    518   �L                0    17546    numerario_recolhimento 
   TABLE DATA               ^   COPY public.numerario_recolhimento (numerario_id, recolhimento_transportadora_id) FROM stdin;
    public       postgres    false    521   �L                 0    17549 
   ocorrencia 
   TABLE DATA               M   COPY public.ocorrencia (id, descricao, codigo, banco_id, layout) FROM stdin;
    public       postgres    false    522   M      !          0    17555    ocorrencia_cobranca 
   TABLE DATA               d   COPY public.ocorrencia_cobranca (id, codigo, descricao, layout, tipo_movimento_retorno) FROM stdin;
    public       postgres    false    523   .M      %          0    17564 #   ocorrencia_retorno_cobranca_detalhe 
   TABLE DATA               l   COPY public.ocorrencia_retorno_cobranca_detalhe (id, ocorrencia_cobranca_id, titulo_retorno_id) FROM stdin;
    public       postgres    false    527   KM      &          0    17568    optantes_debito 
   TABLE DATA               w   COPY public.optantes_debito (id, id_cliente, data, banco_id, agencia, conta, dv_conta, ativo, convenio_id) FROM stdin;
    public       postgres    false    528   hM      (          0    17573    optantes_debito_remessa 
   TABLE DATA               j   COPY public.optantes_debito_remessa (optantes_debito_id, controle_remessa_optantes_debito_id) FROM stdin;
    public       postgres    false    530   �M      )          0    17576 	   pagamento 
   TABLE DATA               g  COPY public.pagamento (id, status, tipo_favorecido, data_criado, data_pagamento, compromisso_id, valor_total, ocorrencia_retorno, web_service_id, data_upload_remessa, nome_arquivo_remessa, nsa_remessa, convenio_conta_id, justificativa, cod_identificacao_lote, data_tarifa, valor_bruto, ativo, nome_arquivo_retorno, comprovante_email_enviado, pix) FROM stdin;
    public       postgres    false    531   �M      *          0    17585    pagamento_arquivo 
   TABLE DATA               I   COPY public.pagamento_arquivo (id, pagamento_id, arquivo_id) FROM stdin;
    public       postgres    false    532   �M      ,          0    17590    pagamento_aud 
   TABLE DATA               �   COPY public.pagamento_aud (id, rev, revtype, status, data_criado, data_pagamento, valor_total, ocorrencia_retorno, data_upload_remessa, justificativa) FROM stdin;
    public       postgres    false    534   �M      -          0    17596    pagamento_aviso 
   TABLE DATA               N   COPY public.pagamento_aviso (id, pagamento_id, aviso, data_aviso) FROM stdin;
    public       postgres    false    535   �M      0          0    17612    parametro_autorizacao 
   TABLE DATA               �   COPY public.parametro_autorizacao (id, convenio_id, compromisso_id, quantidade_autorizacao, aut_cruzada, aut_grupo, certificado_digital, aut_dependencia) FROM stdin;
    public       postgres    false    539   N      2          0    17619    pendencia_nsa 
   TABLE DATA               f   COPY public.pendencia_nsa (id, nsa, resolvido, compromisso_id, convenio_id, tipo_arquivo) FROM stdin;
    public       postgres    false    541   JN      4          0    17624    perfil 
   TABLE DATA               1   COPY public.perfil (id, ativo, nome) FROM stdin;
    public       postgres    false    543   gN      5          0    17627 
   perfil_aud 
   TABLE DATA               C   COPY public.perfil_aud (id, rev, revtype, nome, ativo) FROM stdin;
    public       postgres    false    544   �N      7          0    17635    perfil_permissao 
   TABLE DATA               D   COPY public.perfil_permissao (perfil_id, permissoes_id) FROM stdin;
    public       postgres    false    546   �N      8          0    17638 	   permissao 
   TABLE DATA               L   COPY public.permissao (id, chave, descricao, grupopermissao_id) FROM stdin;
    public       postgres    false    547   �N      :          0    17643    permissao_ip 
   TABLE DATA               :   COPY public.permissao_ip (id, ip, usuario_id) FROM stdin;
    public       postgres    false    549   �N      �          0    35394 -   pre_controle_execucao_conciliacao_bancaria_v2 
   TABLE DATA               n   COPY public.pre_controle_execucao_conciliacao_bancaria_v2 (id, data, empresa_id, valor, conta_id) FROM stdin;
    public       bv_postgres    false    667   �N      <          0    17648    processamento_otimiza 
   TABLE DATA               �   COPY public.processamento_otimiza (id, data, descricao, nome_arquivo_aplicacoes, nome_arquivo_despesas, nome_arquivo_receitas, empresa_id, nome_arquivo_emprestimos) FROM stdin;
    public       postgres    false    551   O      >          0    17653    produto_bancario 
   TABLE DATA                  COPY public.produto_bancario (id, nome, periodo, saldo_minimo, taxa_rendimento, taxa_retirada, banco_id, carencia, descricao, quantidade_dias, taxa_administracao, taxa_cdi, taxa_performance, taxa_retorno, taxa_saida, valor_inicial, empresa_id) FROM stdin;
    public       postgres    false    553   2O      A          0    17660    receita_processamento 
   TABLE DATA               e   COPY public.receita_processamento (id, data, descricao, valor, processamento_otimiza_id) FROM stdin;
    public       postgres    false    556   OO      C          0    17665    recolhimento_transportadora 
   TABLE DATA               g  COPY public.recolhimento_transportadora (id, data_recolhimento, valor_declarado, valor_apurado, diferenca_maior, diferenca_menor, descricao_loja, quantidade_cedulas, quantidade_moedas, valor_moedas, empresa_id, loja_id, controle_upload_arquivo_id, codigo_recolhimento, status_conciliacao_recolhimento, transportadora_id, tratado, tipo_importacao) FROM stdin;
    public       postgres    false    558   lO      D          0    17674 #   recolhimento_transportadora_analise 
   TABLE DATA               �  COPY public.recolhimento_transportadora_analise (id, controle_upload_arquivo_id, empresa_id, loja_id, transportadora_id, data_recolhimento, valor_declarado, valor_apurado, diferenca_maior, diferenca_menor, descricao_loja, quantidade_cedulas, quantidade_moedas, valor_moedas, codigo_recolhimento, tipo_importacao, status_analise_recolhimento, data_processamento, data_alteracao, usuario_alteracao_id) FROM stdin;
    public       postgres    false    559   �O      F          0    17684 '   recolhimento_transportadora_duplicidade 
   TABLE DATA               �   COPY public.recolhimento_transportadora_duplicidade (id, recolhimento_transportadora_id, controle_upload_arquivo_id) FROM stdin;
    public       postgres    false    561   �O      J          0    17693    release_note 
   TABLE DATA               �   COPY public.release_note (id, descricao, tipo_projeto, versao, data_criacao, data_alteracao, usuario_id, ativo, coverage) FROM stdin;
    public       postgres    false    565   �O      L          0    17704    resumo_processamento_arquivo 
   TABLE DATA               �   COPY public.resumo_processamento_arquivo (id, data_hora, catalogado, processado, nome_empresa, nome_arquivo_original, novo_nome_arquivo, tamanho_arquivo, controle_upload_id) FROM stdin;
    public       postgres    false    567   �O      M          0    17711    retorno_debito 
   TABLE DATA               G   COPY public.retorno_debito (id, codigo_retorno, descricao) FROM stdin;
    public       postgres    false    568   �O      O          0    17716    sacado 
   TABLE DATA               @  COPY public.sacado (id, nome, email, cnpj_cpf, logradouro, complemento, bairro, cidade_id, estado_id, cep, telefone_fixo, celular, empresa_id, sacador_avalista, portal_cobranca, email_cobranca, email_vencimento, email_atualizacao, email_protesto, dias_vencimento, dia_vencimento, valor, convenio_id, codigo) FROM stdin;
    public       postgres    false    570   P      Q          0    17721    saldo_convenio 
   TABLE DATA               �   COPY public.saldo_convenio (id, convenio_id, data, saldo, tipo, nsa, empresa_id, banco_id, nome_arquivo, chave_saldo, usuario_logado_id, tiposaldoinicial, saldoinicial, datasaldoinicial, conta_id, controle_upload_arquivo_id) FROM stdin;
    public       postgres    false    572   �P      �          0    34992    saldo_transito_cash 
   TABLE DATA               �  COPY public.saldo_transito_cash (id, empresa_id, loja_id, data_transito, valor_transito, valor_total_venda, valor_total_coleta_carro_forte, valor_total_devolucao, valor_total_diferenca_deposito, valor_total_ajuste_inversao_pagamento, valor_recebido_venda, frequencia_recolhimento_id, banco_id, transportadora_id, valor_recebido_venda_banco, valor_total_ajuste_coleta_deposito, valor_saldo_receber) FROM stdin;
    public       postgres    false    663   �P      S          0    17729    schema_version 
   TABLE DATA               �   COPY public.schema_version (installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) FROM stdin;
    public       postgres    false    574   �P      T          0    17736    status_monitoramento 
   TABLE DATA               =   COPY public.status_monitoramento (id, descricao) FROM stdin;
    public       postgres    false    575   ̂      V          0    17741    tarifa_divergente 
   TABLE DATA               �   COPY public.tarifa_divergente (id, lancamento_id, grupo_empresa_id, vinculo_tarifa_origem_tipo_operacao_id, item_contrato_cesta_servico_id, data_lancamento, valor_cobrado, valor_tarifa, valor_divergente, divergente) FROM stdin;
    public       postgres    false    577   �      Z          0    17754    tarifa_origem 
   TABLE DATA               @   COPY public.tarifa_origem (id, banco_id, descricao) FROM stdin;
    public       postgres    false    581   �      \          0    17763    tarifa_sem_contrato 
   TABLE DATA               �   COPY public.tarifa_sem_contrato (id, data_inicio, data_fim, empresa_id, banco_id, conta_id, descricao_lancamento_id, valor, quantidade, total) FROM stdin;
    public       postgres    false    583   #�      ]          0    17770    tb_data_fixa 
   TABLE DATA               ^   COPY public.tb_data_fixa (data_fixa_order, frequencia_recolhimento_id, data_fixa) FROM stdin;
    public       postgres    false    584   @�      ^          0    17773    tb_dias_semana 
   TABLE DATA               d   COPY public.tb_dias_semana (dias_semana_order, frequencia_recolhimento_id, dias_semana) FROM stdin;
    public       postgres    false    585   ]�      _          0    17776    tipo_categoria_lancamento 
   TABLE DATA               [   COPY public.tipo_categoria_lancamento (id, descricao, codigo, tipo_lancamento) FROM stdin;
    public       postgres    false    586   ��      a          0    17781    tipo_compromisso 
   TABLE DATA               \   COPY public.tipo_compromisso (id, codigo, descricao, banco_id, tipo_favorecido) FROM stdin;
    public       postgres    false    588   ʅ      c          0    17786    tipo_conta_pagar 
   TABLE DATA               X   COPY public.tipo_conta_pagar (id, descricao, codigo, empresa_id, emite_dda) FROM stdin;
    public       postgres    false    590   '�      e          0    17795    tipo_contrato_bancario 
   TABLE DATA               ?   COPY public.tipo_contrato_bancario (id, descricao) FROM stdin;
    public       postgres    false    592   D�      g          0    17800    tipo_identificacao_contribuinte 
   TABLE DATA               P   COPY public.tipo_identificacao_contribuinte (id, descricao, codigo) FROM stdin;
    public       postgres    false    594   a�      j          0    17810    tipo_operacao_cesta_servico 
   TABLE DATA               N   COPY public.tipo_operacao_cesta_servico (id, banco_id, descricao) FROM stdin;
    public       postgres    false    597   �      k          0    17817    tipo_operacao_numerario 
   TABLE DATA               J   COPY public.tipo_operacao_numerario (id, banco_id, descricao) FROM stdin;
    public       postgres    false    598   �      n          0    17824    tipo_servico 
   TABLE DATA               L   COPY public.tipo_servico (id, descricao, tipo_convenio, codigo) FROM stdin;
    public       postgres    false    601   ,�      o          0    17828    titulo 
   TABLE DATA               �  COPY public.titulo (id, empresa_id, convenio_id, sacado_id, tipo_data, data_vencimento, num_documento, tipo_titulo, aceite, nosso_numero, layout_cobranca, tipo_moeda, valor, juros, multa, desconto_um, desconto_dois, desconto_tres, prazo_desc_um, prazo_desc_dois, prazo_desc_tres, juros_banco, dias_multa, tipo_prazo, prazo_protesto, prazo_devolucao, intrucao_um, intrucao_dois, intrucao_tres, intrucao_quatro, data_emissao, status, sacador_avalista_id, numero_remessa, carne, movimentacao, carteira_cobranca_id, parcelas, instrucao_dois, instrucao_quatro, instrucao_tres, instrucao_um, chave_titulo_remessa, tipo_forma_entrega, valor_abatimento, vinculo_sacado_id, titulo_serie_id, fator_data_vencimento, valor_pago, data_pagamento, data_ocorrencia) FROM stdin;
    public       postgres    false    602   I�      p          0    17834 
   titulo_aud 
   TABLE DATA               Y  COPY public.titulo_aud (id, rev, revtype, data_vencimento, desconto_dois, prazo_desc_dois, prazo_desc_tres, prazo_desc_um, desconto_tres, desconto_um, dias_multa, juros, multa, nosso_numero, num_documento, numero_remessa, prazo_devolucao, prazo_protesto, status, valor, valor_abatimento, valor_pago, data_pagamento, data_ocorrencia) FROM stdin;
    public       postgres    false    603   ��      r          0    17842    titulo_auxiliar 
   TABLE DATA               o  COPY public.titulo_auxiliar (id, data_sem_alter_vencimento, desc_dois_sem_alter, prazo_desc_dois_sem_alter_vencimento, prazo_desc_tres_sem_alter_vencimento, prazo_desc_um_sem_alter_vencimento, desc_tres_sem_alter, desc_um_sem_alter, dias_multa_sem_alter_vencimento, valor_sem_alter_vencimento, titulo_id, nosso_numero_sem_alter, num_documento_sem_alter, tipo_prazo_sem_alter, prazo_devolucao_sem_alter, prazo_protesto_sem_alter, valor_abatimento_sem_alter, data_emissao_sem_alter, multa_sem_alter, juros_sem_alter, tipo_titulo_sem_alter, aceite_sem_alter, instrucao_um_sem_alter, instrucao_dois_sem_alter, nome_sacado_sem_alter, email_sacado_sem_alter, logradouro_sacado_sem_alter, telefone_fixo_sacado_sem_alter, celular_sacado_sem_alter, complemento_sacado_sem_alter, bairro_sacado_sem_alter, estado_sacado_id_sacado, cidade_sacado_id_sacado, cep_sacado_sem_alter) FROM stdin;
    public       postgres    false    605   և      t          0    17850 
   titulo_dda 
   TABLE DATA               �  COPY public.titulo_dda (id, empresa_id, banco_id, arquivo_id, convenio_conta_id, boleto_id, cod_movimento, codigo_barras, status, nsa, valor_titulo, data_vencimento, data_emissao, cod_juros, juros_dia, cod_desconto_1, data_desconto_1, valor_desconto_1, cod_desconto_2, data_desconto_2, valor_desconto_2, cod_desconto_3, data_desconto_3, valor_desconto_3, cod_multa, data_multa, valor_multa, data_limite_pagamento, valor_abatimento, tipo_inscricao_cedente, inscricao_cedente, nome_cedente, tipo_inscricao_avalista, inscricao_avalista, nome_avalista, quantidade_moeda, cod_moeda, numero_documento_cobranca, agencia_cobranca, dv_agencia_cobranca, praca_cobranca, codigo_carteira, especie_titulo, cod_protesto, numero_dias_protesto, mensagem_1, mensagem_2, baixa_manual, data_ocorrencia, autenticacao_pagamento, valor_pagamento, local_pagamento, usuario_alteracao_id, data_alteracao, valor_alterado, banco_modificador, status_conciliacao, verificado) FROM stdin;
    public       postgres    false    607   �      u          0    17865    titulo_dda_duplicado 
   TABLE DATA               �   COPY public.titulo_dda_duplicado (id, titulo_dda_id, controle_upload_arquivo_id, linha_processada, data_processamento) FROM stdin;
    public       postgres    false    608   �      y          0    17874    titulo_mensagem 
   TABLE DATA               H   COPY public.titulo_mensagem (mensagem_titulo_id, titulo_id) FROM stdin;
    public       postgres    false    612   -�      z          0    17877    titulo_movimento_remessa 
   TABLE DATA               �   COPY public.titulo_movimento_remessa (titulo_id, movimento_remessa_cobranca_id, enviado, data_geracao_instrucao, arquivo_id, usuario_id, instrucao_realizada) FROM stdin;
    public       postgres    false    613   J�      {          0    17883    titulo_retorno 
   TABLE DATA                 COPY public.titulo_retorno (id, titulo_id, ocorrencia_ret, juros, valor_desconto, valor_pago, valor_liquido, data_ocorrencia, data_tarifa, data_credito, cod_mov_ret, arquivo_id, floating, ocorrencia_det, valor_tarifa, formapagamento, forma_pagamento, nsa, id_mov_ret) FROM stdin;
    public       postgres    false    614   g�      ~          0    17893    titulo_serie 
   TABLE DATA               �   COPY public.titulo_serie (id, data_emissao, numero_documento, quantidade, data_vencimento, valor_unitario, empresa_id, convenio_id, pagador_id) FROM stdin;
    public       postgres    false    617   ��                0    17900    token 
   TABLE DATA               C   COPY public.token (id, chave, grupo_empresa_id, ativo) FROM stdin;
    public       postgres    false    618   ��      �          0    17908    tramite_processamento_arquivo 
   TABLE DATA               �   COPY public.tramite_processamento_arquivo (id, inicio_tramite, fim_tramite, tipo_tramite, status_tramite, resumo_processamento_id, resumo_tramite) FROM stdin;
    public       postgres    false    621   ��      �          0    17915    transportadora 
   TABLE DATA               �   COPY public.transportadora (id, cnpj, razao_social, nome_fantasia, email, telefone, celular, ativa, cep, logradouro, complemento, bairro, estado_id, cidade_id, numero, url_api) FROM stdin;
    public       postgres    false    622   ۈ      �          0    17924    tributo_gps 
   TABLE DATA                 COPY public.tributo_gps (id, valor_inss, identificador, nome_razao_social, telefone, logradouro, atualizacao_monetaria, forma_pagamento_id, valor_outras_entidades, codigo_receita_id, pagamento_id, cidade_id, estado_id, status, seu_numero, valor_total, competencia) FROM stdin;
    public       postgres    false    624   ��      �          0    17932    tributo_sem_codigo_barra 
   TABLE DATA               �  COPY public.tributo_sem_codigo_barra (id, nome_razao_social, identificador, data_vencimento, observacao, telefone, endereco, autenticacao_bancaria, valor, multa, juros, total, status, competencia, periodo_apuracao, numero_referencia, pagamento_id, codigo_receita_id, tipo_tributo, seu_numero, tipo_identificacao_contribuinte_id, ocorrencia, forma_pagamento_id, data_pagamento, numero_parcela, inscricao_estadual, divida_ativa, periodo_referencia) FROM stdin;
    public       postgres    false    626   �      �          0    17940    usuario 
   TABLE DATA               �   COPY public.usuario (nome, login, senha, grupo_empresa_id, root, id, ativo, altera_senha, email, notifica_aut_pag, cocriacao, cpf, notifica_boleto_a_vencer, foto) FROM stdin;
    public       postgres    false    628   2�      �          0    17949    usuario_aud 
   TABLE DATA               �   COPY public.usuario_aud (id, rev, revtype, nome, ativo, login, senha, grupo_empresa_id, root, email, notifica_aut_pag, cpf) FROM stdin;
    public       postgres    false    629   ��      �          0    17955    usuario_contas 
   TABLE DATA               >   COPY public.usuario_contas (usuario_id, conta_id) FROM stdin;
    public       postgres    false    630   щ      �          0    17958    usuario_empresas 
   TABLE DATA               B   COPY public.usuario_empresas (usuario_id, empresa_id) FROM stdin;
    public       postgres    false    631   �      �          0    17961    usuario_favorecido 
   TABLE DATA               �   COPY public.usuario_favorecido (id, usuario_id, favorecido_id, data_cadastro, usuario_cadastro_id, favorecido_id_old) FROM stdin;
    public       postgres    false    632   �      �          0    17968    usuario_lojas 
   TABLE DATA               <   COPY public.usuario_lojas (usuario_id, loja_id) FROM stdin;
    public       postgres    false    635   (�      �          0    17971    usuario_perfil 
   TABLE DATA               ?   COPY public.usuario_perfil (usuario_id, perfil_id) FROM stdin;
    public       postgres    false    636   E�      �          0    17974    usuario_perfil_aud 
   TABLE DATA               Q   COPY public.usuario_perfil_aud (rev, revtype, usuario_id, perfil_id) FROM stdin;
    public       postgres    false    637   b�      �          0    17977    usuario_sacado 
   TABLE DATA               t   COPY public.usuario_sacado (id, usuario_id, sacado_id, data_cadastro, usuario_cadastro_id, convenio_id) FROM stdin;
    public       postgres    false    638   �      �          0    17982    venda 
   TABLE DATA               �   COPY public.venda (id, empresa_id, codigo_loja, descricao_loja, valor_venda, data_venda, numero_documento, tipo_documento, codigo_lancamento, descricao_lancamento, referencia, faturamento_id) FROM stdin;
    public       postgres    false    640   ��      �          0    17990    verificacao_status 
   TABLE DATA               C   COPY public.verificacao_status (id, status, descricao) FROM stdin;
    public       postgres    false    642   ��      �          0    17995    vinculacao_automatica_categoria 
   TABLE DATA               k   COPY public.vinculacao_automatica_categoria (id, descricao, banco_id, categoria_lancamento_id) FROM stdin;
    public       postgres    false    644   ֊      �          0    18000    vinculacao_cnpj_empresa 
   TABLE DATA               l   COPY public.vinculacao_cnpj_empresa (id, cnpj, empresa_id, conta_id, convenio_id, razao_social) FROM stdin;
    public       postgres    false    646   �      �          0    35831    vinculo_categoria_cash 
   TABLE DATA                  COPY public.vinculo_categoria_cash (id, empresa_id, categoria_lancamento_id, banco_id, tipo_categoria_cash, ativo) FROM stdin;
    public       postgres    false    670   �      �          0    18005    vinculo_conciliacao_cobranca 
   TABLE DATA               |   COPY public.vinculo_conciliacao_cobranca (id, banco_id, movimento_retorno_cobranca_id, categoria_lancamento_id) FROM stdin;
    public       postgres    false    648   -�      �          0    18012 &   vinculo_descricao_ocorrencia_categoria 
   TABLE DATA                  COPY public.vinculo_descricao_ocorrencia_categoria (id, ocorrencia_cobranca_id, categoria_lancamento_id, banco_id) FROM stdin;
    public       postgres    false    651   J�      �          0    18018    vinculo_ocorrencia_pagamento 
   TABLE DATA               |   COPY public.vinculo_ocorrencia_pagamento (id, banco_id, tipo_servico_id, tipo_vinculo, categoria_lancamento_id) FROM stdin;
    public       postgres    false    653   g�      �          0    18022    vinculo_pagamento_lancamento 
   TABLE DATA               Z   COPY public.vinculo_pagamento_lancamento (id, chave_lancamento, pagamento_id) FROM stdin;
    public       postgres    false    654   ��      �          0    18029    vinculo_sacado 
   TABLE DATA               �   COPY public.vinculo_sacado (id, apelido, empresa_id, grupo_empresa_id, data_processamento, convenio_id, agencia, dv_agencia, banco_id, sacado_id) FROM stdin;
    public       postgres    false    657   ��      �          0    18035 #   vinculo_tarifa_origem_tipo_operacao 
   TABLE DATA               �   COPY public.vinculo_tarifa_origem_tipo_operacao (id, banco_id, tipo_operacao_id, tarifa_origem_id, categoria_id, tarifa) FROM stdin;
    public       postgres    false    659   ��      
           0    0    arquivo_aud_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('auditoria.arquivo_aud_id_seq', 1, false);
         	   auditoria       postgres    false    198                       0    0    categoria_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('auditoria.categoria_id_seq', 101, true);
         	   auditoria       postgres    false    200                       0    0    cliente_ftp_log_externo_id_seq    SEQUENCE SET     P   SELECT pg_catalog.setval('auditoria.cliente_ftp_log_externo_id_seq', 28, true);
         	   auditoria       postgres    false    202                       0    0    conta_pagar_aud_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('auditoria.conta_pagar_aud_id_seq', 167, true);
         	   auditoria       postgres    false    672                       0    0    controle_acesso_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('auditoria.controle_acesso_id_seq', 68, true);
         	   auditoria       postgres    false    204                       0    0    empresa_aud_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('auditoria.empresa_aud_id_seq', 330, true);
         	   auditoria       postgres    false    206                       0    0    grupo_empresa_log_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('auditoria.grupo_empresa_log_id_seq', 303, true);
         	   auditoria       postgres    false    209                       0    0    historico_usuario_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('auditoria.historico_usuario_id_seq', 1585, true);
         	   auditoria       postgres    false    211                       0    0 !   log_arquivos_particionados_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('auditoria.log_arquivos_particionados_id_seq', 1, false);
         	   auditoria       postgres    false    213                       0    0    menu_log_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('auditoria.menu_log_id_seq', 41, true);
         	   auditoria       postgres    false    215                       0    0    sub_categoria_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('auditoria.sub_categoria_id_seq', 200, true);
         	   auditoria       postgres    false    217                       0    0    acesso_conta_auxiliar_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.acesso_conta_auxiliar_id_seq', 404, true);
            public       postgres    false    220                       0    0 -   agendamento_descricao_categoria_global_id_seq    SEQUENCE SET     ]   SELECT pg_catalog.setval('public.agendamento_descricao_categoria_global_id_seq', 21, false);
            public       postgres    false    222                       0    0    aplicacao_processamento_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.aplicacao_processamento_id_seq', 1, false);
            public       postgres    false    224                       0    0    arquivo_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.arquivo_id_seq', 44782, true);
            public       postgres    false    225                       0    0 $   arrecadacao_debito_automatico_id_seq    SEQUENCE SET     U   SELECT pg_catalog.setval('public.arrecadacao_debito_automatico_id_seq', 3621, true);
            public       postgres    false    230                       0    0 '   arrecadacao_divergente_contratoa_id_seq    SEQUENCE SET     W   SELECT pg_catalog.setval('public.arrecadacao_divergente_contratoa_id_seq', 126, true);
            public       postgres    false    232                       0    0    arrecadacao_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.arrecadacao_id_seq', 13349, true);
            public       postgres    false    233                       0    0    auditoria_crud_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.auditoria_crud_id_seq', 508788, true);
            public       postgres    false    236                       0    0    auditoria_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.auditoria_id_seq', 1, false);
            public       postgres    false    237                       0    0    auditoria_suite_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.auditoria_suite_id_seq', 1, false);
            public       postgres    false    239                       0    0    autorizacao_dependencia_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.autorizacao_dependencia_id_seq', 40, true);
            public       postgres    false    241                        0    0    autorizacao_pag_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.autorizacao_pag_id_seq', 13657, true);
            public       postgres    false    243            !           0    0    autorizacao_remessa_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.autorizacao_remessa_id_seq', 3570, true);
            public       postgres    false    245            "           0    0    banco_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.banco_id_seq', 3960, true);
            public       postgres    false    249            #           0    0    banco_suportado_cobranca_id_seq    SEQUENCE SET     N   SELECT pg_catalog.setval('public.banco_suportado_cobranca_id_seq', 8, false);
            public       postgres    false    251            $           0    0    boleto_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('public.boleto_id_seq', 2853, true);
            public       postgres    false    254            %           0    0    card_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('public.card_id_seq', 1, false);
            public       postgres    false    256            &           0    0    carteira_cobranca_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.carteira_cobranca_id_seq', 3, true);
            public       postgres    false    259            '           0    0    categoria_lancamentos_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.categoria_lancamentos_id_seq', 2908, true);
            public       postgres    false    262            (           0    0     categoria_lancamentos_new_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.categoria_lancamentos_new_id_seq', 49, true);
            public       postgres    false    263            )           0    0    chave_pix_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.chave_pix_id_seq', 116, true);
            public       postgres    false    264            *           0    0    cheque_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('public.cheque_id_seq', 1, false);
            public       postgres    false    267            +           0    0    cidade_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('public.cidade_id_seq', 1, false);
            public       postgres    false    269            ,           0    0    cliente_ftp_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.cliente_ftp_id_seq', 164, true);
            public       postgres    false    271            -           0    0    cliente_ftp_log_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.cliente_ftp_log_id_seq', 1, false);
            public       postgres    false    273            .           0    0    clientsftp_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.clientsftp_id_seq', 1, false);
            public       postgres    false    275            /           0    0    cobranca_instrucao_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.cobranca_instrucao_id_seq', 3821, true);
            public       postgres    false    277            0           0    0    cobranca_parametro_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.cobranca_parametro_id_seq', 3856, true);
            public       postgres    false    279            1           0    0    codigo_receita_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.codigo_receita_id_seq', 279289, true);
            public       postgres    false    281            2           0    0    compromisso_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.compromisso_seq', 2023, true);
            public       postgres    false    283            3           0    0    conciliacao_cash_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.conciliacao_cash_id_seq', 1, false);
            public       postgres    false    664            4           0    0 &   conciliacao_financeira_aux_lanc_id_seq    SEQUENCE SET     U   SELECT pg_catalog.setval('public.conciliacao_financeira_aux_lanc_id_seq', 9, false);
            public       postgres    false    286            5           0    0 %   conciliacao_financeira_aux_tit_id_seq    SEQUENCE SET     T   SELECT pg_catalog.setval('public.conciliacao_financeira_aux_tit_id_seq', 9, false);
            public       postgres    false    287            6           0    0    conciliacao_financeira_id_seq    SEQUENCE SET     N   SELECT pg_catalog.setval('public.conciliacao_financeira_id_seq', 9160, true);
            public       postgres    false    290            7           0    0    configuracao_sistema_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.configuracao_sistema_id_seq', 747, true);
            public       postgres    false    295            8           0    0    conta_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.conta_id_seq', 3597, true);
            public       postgres    false    297            9           0    0 #   conta_lancamento_fluxo_caixa_id_seq    SEQUENCE SET     R   SELECT pg_catalog.setval('public.conta_lancamento_fluxo_caixa_id_seq', 1, false);
            public       postgres    false    300            :           0    0    conta_lancamento_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.conta_lancamento_id_seq', 1, false);
            public       postgres    false    301            ;           0    0    conta_pagar_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.conta_pagar_id_seq', 1, false);
            public       postgres    false    303            <           0    0    conta_pagar_log_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.conta_pagar_log_id_seq', 1, false);
            public       postgres    false    305            =           0    0    contrato_arrecadadora_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.contrato_arrecadadora_id_seq', 241, true);
            public       postgres    false    309            >           0    0    contrato_bancario_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.contrato_bancario_id_seq', 1, false);
            public       postgres    false    311            ?           0    0    contrato_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.contrato_id_seq', 123, true);
            public       postgres    false    306            @           0    0    controle_acesso_api_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.controle_acesso_api_id_seq', 35, true);
            public       postgres    false    314            A           0    0     controle_bloqueio_usuario_id_seq    SEQUENCE SET     R   SELECT pg_catalog.setval('public.controle_bloqueio_usuario_id_seq', 15175, true);
            public       postgres    false    316            B           0    0    controle_card_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.controle_card_id_seq', 34, true);
            public       postgres    false    318            C           0    0    controle_nsa_arrecadacao_id_seq    SEQUENCE SET     P   SELECT pg_catalog.setval('public.controle_nsa_arrecadacao_id_seq', 3608, true);
            public       postgres    false    321            D           0    0    controle_nsa_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.controle_nsa_id_seq', 273826, true);
            public       postgres    false    322            E           0    0 #   controle_nsa_optantes_debito_id_seq    SEQUENCE SET     R   SELECT pg_catalog.setval('public.controle_nsa_optantes_debito_id_seq', 1, false);
            public       postgres    false    324            F           0    0    controle_nsa_remessa_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.controle_nsa_remessa_id_seq', 54, true);
            public       postgres    false    325            G           0    0 '   controle_remessa_optantes_debito_id_seq    SEQUENCE SET     X   SELECT pg_catalog.setval('public.controle_remessa_optantes_debito_id_seq', 1044, true);
            public       postgres    false    329            H           0    0    controle_senha_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.controle_senha_id_seq', 15759, true);
            public       postgres    false    331            I           0    0    controle_upload_arquivo_id_seq    SEQUENCE SET     P   SELECT pg_catalog.setval('public.controle_upload_arquivo_id_seq', 67011, true);
            public       postgres    false    333            J           0    0    convenio_conta_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.convenio_conta_id_seq', 3458, true);
            public       postgres    false    337            K           0    0    convenio_empresa_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.convenio_empresa_id_seq', 373, true);
            public       postgres    false    340            L           0    0    convenio_extrato_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.convenio_extrato_id_seq', 9707, true);
            public       postgres    false    342            M           0    0    convenio_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.convenio_id_seq', 14355, true);
            public       postgres    false    343            N           0    0    convenio_pagamento_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.convenio_pagamento_id_seq', 1, false);
            public       postgres    false    345            O           0    0     credencial_acesso_empresa_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.credencial_acesso_empresa_id_seq', 54, true);
            public       postgres    false    347            P           0    0    descricao_lancamento_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.descricao_lancamento_id_seq', 30892, true);
            public       postgres    false    349            Q           0    0 ?   descricao_lancamento_new_categoria_lancamento_new_config_id_seq    SEQUENCE SET     n   SELECT pg_catalog.setval('public.descricao_lancamento_new_categoria_lancamento_new_config_id_seq', 58, true);
            public       postgres    false    352            R           0    0    descricao_lancamento_new_id_seq    SEQUENCE SET     N   SELECT pg_catalog.setval('public.descricao_lancamento_new_id_seq', 68, true);
            public       postgres    false    353            S           0    0    despesa_processamento_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.despesa_processamento_id_seq', 1, false);
            public       postgres    false    355            T           0    0    documentacao_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.documentacao_id_seq', 17, true);
            public       postgres    false    668            U           0    0    download_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('public.download_id_seq', 1, false);
            public       postgres    false    357            V           0    0    email_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.email_id_seq', 4948, true);
            public       postgres    false    359            W           0    0    empresa_id_empresa_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.empresa_id_empresa_seq', 1, false);
            public       postgres    false    361            X           0    0    empresa_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.empresa_id_seq', 2045, true);
            public       postgres    false    362            Y           0    0    empresa_transportadora_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.empresa_transportadora_id_seq', 84, true);
            public       postgres    false    364            Z           0    0    emprestimo_processamento_id_seq    SEQUENCE SET     N   SELECT pg_catalog.setval('public.emprestimo_processamento_id_seq', 1, false);
            public       postgres    false    365            [           0    0    estado_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('public.estado_id_seq', 1, false);
            public       postgres    false    368            \           0    0    faixa_cep_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.faixa_cep_id_seq', 1, false);
            public       postgres    false    370            ]           0    0     faixa_nosso_numero_sacado_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.faixa_nosso_numero_sacado_id_seq', 71, true);
            public       postgres    false    373            ^           0    0 
   faq_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('public.faq_id_seq', 102, true);
            public       postgres    false    375            _           0    0    faturamento_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.faturamento_id_seq', 1, false);
            public       postgres    false    377            `           0    0    favorecido_conta_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.favorecido_conta_id_seq', 171, true);
            public       postgres    false    382            a           0    0    favorecido_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.favorecido_id_seq', 565578, true);
            public       postgres    false    383            b           0    0    feriado_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.feriado_id_seq', 1992, true);
            public       postgres    false    385            c           0    0    float_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('public.float_id_seq', 706, true);
            public       postgres    false    387            d           0    0 "   forma_pagamento_arrecadacao_id_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public.forma_pagamento_arrecadacao_id_seq', 1, false);
            public       postgres    false    390            e           0    0 "   forma_pagamento_fluxo_caixa_id_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public.forma_pagamento_fluxo_caixa_id_seq', 10, true);
            public       postgres    false    392            f           0    0    forma_pagamento_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.forma_pagamento_id_seq', 37, true);
            public       postgres    false    393            g           0    0    frequencia_recolhimento_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.frequencia_recolhimento_id_seq', 70, true);
            public       postgres    false    394            h           0    0 *   grafico_arrecadacao_forma_pagamento_id_seq    SEQUENCE SET     Z   SELECT pg_catalog.setval('public.grafico_arrecadacao_forma_pagamento_id_seq', 205, true);
            public       postgres    false    396            i           0    0    grafico_extrato_bancario_id_seq    SEQUENCE SET     N   SELECT pg_catalog.setval('public.grafico_extrato_bancario_id_seq', 1, false);
            public       postgres    false    398            j           0    0 !   grupo_autorizacao_convenio_id_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public.grupo_autorizacao_convenio_id_seq', 533, true);
            public       postgres    false    401            k           0    0    grupo_empresas_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.grupo_empresas_id_seq', 1618, true);
            public       postgres    false    404            l           0    0    grupo_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.grupo_id_seq', 6034, true);
            public       postgres    false    405            m           0    0 #   grupo_lancamento_fluxo_caixa_id_seq    SEQUENCE SET     R   SELECT pg_catalog.setval('public.grupo_lancamento_fluxo_caixa_id_seq', 1, false);
            public       postgres    false    409            n           0    0    grupo_lancamento_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.grupo_lancamento_id_seq', 12, true);
            public       postgres    false    406            o           0    0    grupo_numerario_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.grupo_numerario_id_seq', 1, false);
            public       postgres    false    411            p           0    0    grupo_pagamento_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.grupo_pagamento_id_seq', 10, false);
            public       postgres    false    412            q           0    0    grupo_permissao_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.grupo_permissao_id_seq', 7376, true);
            public       postgres    false    414            r           0    0    grupo_sacado_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.grupo_sacado_id_seq', 1364, true);
            public       postgres    false    417            s           0    0    grupo_titulo_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.grupo_titulo_id_seq', 10, false);
            public       postgres    false    419            t           0    0    guia_transporte_valores_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.guia_transporte_valores_id_seq', 61, true);
            public       postgres    false    422            u           0    0 (   historico_frequencia_recolhimento_id_seq    SEQUENCE SET     X   SELECT pg_catalog.setval('public.historico_frequencia_recolhimento_id_seq', 140, true);
            public       postgres    false    423            v           0    0    historico_maquineta_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.historico_maquineta_id_seq', 1, false);
            public       postgres    false    425            w           0    0    historico_monitoramento_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.historico_monitoramento_id_seq', 36, true);
            public       postgres    false    427            x           0    0     historico_optantes_debito_id_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public.historico_optantes_debito_id_seq', 3615, true);
            public       postgres    false    429            y           0    0    historico_pagamento_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.historico_pagamento_id_seq', 2307, true);
            public       postgres    false    431            z           0    0 "   historico_upload_favorecido_id_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public.historico_upload_favorecido_id_seq', 1, false);
            public       postgres    false    433            {           0    0    historico_upload_sacado_id_seq    SEQUENCE SET     N   SELECT pg_catalog.setval('public.historico_upload_sacado_id_seq', 336, true);
            public       postgres    false    435            |           0    0 %   importacao_personalizada_campo_id_seq    SEQUENCE SET     U   SELECT pg_catalog.setval('public.importacao_personalizada_campo_id_seq', 135, true);
            public       postgres    false    438            }           0    0 *   importacao_personalizada_conta_fixo_id_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.importacao_personalizada_conta_fixo_id_seq', 85, true);
            public       postgres    false    440            ~           0    0    importacao_personalizada_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.importacao_personalizada_id_seq', 135, true);
            public       postgres    false    441                       0    0 -   importacao_personalizada_ignorar_linha_id_seq    SEQUENCE SET     ]   SELECT pg_catalog.setval('public.importacao_personalizada_ignorar_linha_id_seq', 135, true);
            public       postgres    false    443            �           0    0    item_contrato_bancario_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.item_contrato_bancario_id_seq', 1, false);
            public       postgres    false    445            �           0    0 &   item_contrato_bancario_pendente_id_seq    SEQUENCE SET     V   SELECT pg_catalog.setval('public.item_contrato_bancario_pendente_id_seq', 10, false);
            public       postgres    false    446            �           0    0 "   item_contrato_cesta_servico_id_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public.item_contrato_cesta_servico_id_seq', 47, true);
            public       postgres    false    449            �           0    0 #   item_contrato_cesta_servico_id_seq1    SEQUENCE SET     R   SELECT pg_catalog.setval('public.item_contrato_cesta_servico_id_seq1', 1, false);
            public       postgres    false    450            �           0    0    item_contrato_cobranca_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.item_contrato_cobranca_id_seq', 47, true);
            public       postgres    false    451            �           0    0    item_contrato_numerario_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.item_contrato_numerario_id_seq', 38, true);
            public       postgres    false    454            �           0    0    item_contrato_pagamento_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.item_contrato_pagamento_id_seq', 85, true);
            public       postgres    false    456            �           0    0 (   item_grupo_lancamento_fluxo_caixa_id_seq    SEQUENCE SET     W   SELECT pg_catalog.setval('public.item_grupo_lancamento_fluxo_caixa_id_seq', 1, false);
            public       postgres    false    459            �           0    0    lancamento_auxiliar_cash_id_seq    SEQUENCE SET     N   SELECT pg_catalog.setval('public.lancamento_auxiliar_cash_id_seq', 1, false);
            public       bv_postgres    false    661            �           0    0    lancamento_debito_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.lancamento_debito_id_seq', 1552, true);
            public       postgres    false    461            �           0    0    lancamento_duplicado_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.lancamento_duplicado_id_seq', 1, false);
            public       postgres    false    463            �           0    0    lancamento_new_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.lancamento_new_id_seq', 67473, true);
            public       postgres    false    467            �           0    0    layout_campo_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.layout_campo_id_seq', 11, true);
            public       postgres    false    469            �           0    0    layout_campo_pagamento_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.layout_campo_pagamento_id_seq', 1, true);
            public       postgres    false    471            �           0    0    limite_especial_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.limite_especial_id_seq', 1377, true);
            public       postgres    false    473            �           0    0    log_acesso_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.log_acesso_id_seq', 1371, true);
            public       postgres    false    475            �           0    0    log_baixa_ftp_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.log_baixa_ftp_id_seq', 1, false);
            public       postgres    false    477            �           0    0    log_erro_catalogador_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.log_erro_catalogador_id_seq', 982, true);
            public       postgres    false    478            �           0    0    log_erro_processador_id_seq    SEQUENCE SET     N   SELECT pg_catalog.setval('public.log_erro_processador_id_seq', 233472, true);
            public       postgres    false    481            �           0    0    loja_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('public.loja_id_seq', 33, true);
            public       postgres    false    483            �           0    0 !   lojas_com_coleta_excedente_id_seq    SEQUENCE SET     P   SELECT pg_catalog.setval('public.lojas_com_coleta_excedente_id_seq', 64, true);
            public       postgres    false    485            �           0    0    lote_boleto_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.lote_boleto_id_seq', 5024, true);
            public       postgres    false    487            �           0    0    lote_carne_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.lote_carne_id_seq', 12101, true);
            public       postgres    false    489            �           0    0    lote_favorecido_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.lote_favorecido_id_seq', 533716, true);
            public       postgres    false    492            �           0    0    lote_pag_aux_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.lote_pag_aux_id_seq', 455641, true);
            public       postgres    false    494            �           0    0    mensagem_arquivo_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.mensagem_arquivo_id_seq', 918603, true);
            public       postgres    false    496            �           0    0    mensagem_titulo_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.mensagem_titulo_id_seq', 88, true);
            public       postgres    false    498            �           0    0 #   modalidade_contrato_bancario_id_seq    SEQUENCE SET     R   SELECT pg_catalog.setval('public.modalidade_contrato_bancario_id_seq', 1, false);
            public       postgres    false    500            �           0    0    modulo_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('public.modulo_id_seq', 1, false);
            public       postgres    false    502            �           0    0    movimento_pagamento_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.movimento_pagamento_id_seq', 1620, true);
            public       postgres    false    504            �           0    0 !   movimento_remessa_cobranca_id_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public.movimento_remessa_cobranca_id_seq', 140, true);
            public       postgres    false    506            �           0    0 !   movimento_retorno_cobranca_id_seq    SEQUENCE SET     P   SELECT pg_catalog.setval('public.movimento_retorno_cobranca_id_seq', 44, true);
            public       postgres    false    508            �           0    0    notificacao_destinatario_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.notificacao_destinatario_id_seq', 102, true);
            public       postgres    false    511            �           0    0    notificacao_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.notificacao_id_seq', 238, true);
            public       postgres    false    512            �           0    0    notificacao_pagamento_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.notificacao_pagamento_id_seq', 1, false);
            public       postgres    false    514            �           0    0    notificacao_usuario_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.notificacao_usuario_id_seq', 34, true);
            public       postgres    false    516            �           0    0    numerario_duplicidade_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.numerario_duplicidade_id_seq', 1, false);
            public       postgres    false    519            �           0    0    numerario_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.numerario_id_seq', 1, false);
            public       postgres    false    520            �           0    0    ocorrencia_cobranca_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.ocorrencia_cobranca_id_seq', 52, true);
            public       postgres    false    524            �           0    0    ocorrencia_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.ocorrencia_id_seq', 35, true);
            public       postgres    false    525            �           0    0 *   ocorrencia_retorno_cobranca_detalhe_id_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.ocorrencia_retorno_cobranca_detalhe_id_seq', 24, true);
            public       postgres    false    526            �           0    0    optantes_debito_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.optantes_debito_id_seq', 4249, true);
            public       postgres    false    529            �           0    0    pagamento_arquivo_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.pagamento_arquivo_id_seq', 40609, true);
            public       postgres    false    533            �           0    0    pagamento_aviso_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.pagamento_aviso_id_seq', 1, false);
            public       postgres    false    536            �           0    0    pagamento_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.pagamento_id_seq', 23205, true);
            public       postgres    false    537            �           0    0    parametro_autorizacao_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.parametro_autorizacao_id_seq', 1, false);
            public       postgres    false    540            �           0    0    pendencia_nsa_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.pendencia_nsa_id_seq', 1, false);
            public       postgres    false    542            �           0    0    perfil_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('public.perfil_id_seq', 5549, true);
            public       postgres    false    545            �           0    0    permissao_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.permissao_id_seq', 1839, true);
            public       postgres    false    548            �           0    0    permissao_ip_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.permissao_ip_seq', 12852, true);
            public       postgres    false    550            �           0    0 4   pre_controle_execucao_conciliacao_bancaria_v2_id_seq    SEQUENCE SET     c   SELECT pg_catalog.setval('public.pre_controle_execucao_conciliacao_bancaria_v2_id_seq', 16, true);
            public       bv_postgres    false    666            �           0    0    processamento_otimiza_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.processamento_otimiza_id_seq', 1, false);
            public       postgres    false    552            �           0    0    produto_bancario_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.produto_bancario_id_seq', 1, false);
            public       postgres    false    554            �           0    0    produto_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.produto_id_seq', 342, false);
            public       postgres    false    555            �           0    0    receita_processamento_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.receita_processamento_id_seq', 1, false);
            public       postgres    false    557            �           0    0 *   recolhimento_transportadora_analise_id_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.recolhimento_transportadora_analise_id_seq', 32, true);
            public       postgres    false    560            �           0    0 .   recolhimento_transportadora_duplicidade_id_seq    SEQUENCE SET     ]   SELECT pg_catalog.setval('public.recolhimento_transportadora_duplicidade_id_seq', 1, false);
            public       postgres    false    562            �           0    0 "   recolhimento_transportadora_id_seq    SEQUENCE SET     R   SELECT pg_catalog.setval('public.recolhimento_transportadora_id_seq', 160, true);
            public       postgres    false    563            �           0    0    release_note_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.release_note_id_seq', 213, true);
            public       postgres    false    564            �           0    0 #   resumo_processamento_arquivo_id_seq    SEQUENCE SET     R   SELECT pg_catalog.setval('public.resumo_processamento_arquivo_id_seq', 1, false);
            public       postgres    false    566            �           0    0    retorno_debito_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.retorno_debito_id_seq', 19, true);
            public       postgres    false    569            �           0    0    sacado_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('public.sacado_id_seq', 4363, true);
            public       postgres    false    571            �           0    0    saldo_convenio_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.saldo_convenio_id_seq', 6228, true);
            public       postgres    false    573            �           0    0    saldo_transito_cash_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.saldo_transito_cash_id_seq', 1, false);
            public       postgres    false    662            �           0    0    status_monitoramento_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.status_monitoramento_id_seq', 4, true);
            public       postgres    false    576            �           0    0    tarifa_divergente_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.tarifa_divergente_id_seq', 10, false);
            public       postgres    false    578            �           0    0    tarifa_divergente_id_seq1    SEQUENCE SET     H   SELECT pg_catalog.setval('public.tarifa_divergente_id_seq1', 1, false);
            public       postgres    false    579            �           0    0    tarifa_origem_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.tarifa_origem_id_seq', 47, true);
            public       postgres    false    580            �           0    0    tarifa_sem_contrato_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.tarifa_sem_contrato_id_seq', 10, false);
            public       postgres    false    582            �           0    0     tipo_categoria_lancamento_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.tipo_categoria_lancamento_id_seq', 49, true);
            public       postgres    false    587            �           0    0    tipo_compromisso_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.tipo_compromisso_seq', 1, false);
            public       postgres    false    589            �           0    0    tipo_conta_pagar_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.tipo_conta_pagar_id_seq', 1, false);
            public       postgres    false    591            �           0    0    tipo_contrato_bancario_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.tipo_contrato_bancario_id_seq', 1, false);
            public       postgres    false    593            �           0    0 &   tipo_identificacao_contribuinte_id_seq    SEQUENCE SET     T   SELECT pg_catalog.setval('public.tipo_identificacao_contribuinte_id_seq', 8, true);
            public       postgres    false    595            �           0    0 "   tipo_operacao_cesta_servico_id_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public.tipo_operacao_cesta_servico_id_seq', 47, true);
            public       postgres    false    596            �           0    0    tipo_operacao_numerario_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.tipo_operacao_numerario_id_seq', 32, true);
            public       postgres    false    599            �           0    0    tipo_servico_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.tipo_servico_id_seq', 16, true);
            public       postgres    false    600            �           0    0    titulo_aux_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.titulo_aux_id_seq', 22, true);
            public       postgres    false    604            �           0    0    titulo_auxiliar_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.titulo_auxiliar_id_seq', 946, true);
            public       postgres    false    606            �           0    0    titulo_dda_duplicado_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.titulo_dda_duplicado_id_seq', 1, false);
            public       postgres    false    609            �           0    0    titulo_dda_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.titulo_dda_id_seq', 1, false);
            public       postgres    false    610            �           0    0    titulo_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.titulo_id_seq', 17661, true);
            public       postgres    false    611            �           0    0    titulo_retorno_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.titulo_retorno_id_seq', 15509, true);
            public       postgres    false    615            �           0    0    titulo_serie_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.titulo_serie_id_seq', 81, true);
            public       postgres    false    616            �           0    0    token_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('public.token_id_seq', 64, true);
            public       postgres    false    619            �           0    0 $   tramite_processamento_arquivo_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.tramite_processamento_arquivo_id_seq', 1, false);
            public       postgres    false    620            �           0    0    transportadora_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.transportadora_id_seq', 33, true);
            public       postgres    false    623            �           0    0    tributo_gps_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.tributo_gps_id_seq', 471, true);
            public       postgres    false    625            �           0    0    tributo_sem_codigo_barra_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.tributo_sem_codigo_barra_id_seq', 113, true);
            public       postgres    false    627            �           0    0    usuario_favorecido_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.usuario_favorecido_id_seq', 1112, true);
            public       postgres    false    633            �           0    0    usuario_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.usuario_id_seq', 13658, true);
            public       postgres    false    634            �           0    0    usuario_sacado_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.usuario_sacado_id_seq', 3336, true);
            public       postgres    false    639            �           0    0    venda_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('public.venda_id_seq', 1, false);
            public       postgres    false    641            �           0    0    verificacao_status_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.verificacao_status_id_seq', 1, false);
            public       postgres    false    643            �           0    0 &   vinculacao_automatica_categoria_id_seq    SEQUENCE SET     V   SELECT pg_catalog.setval('public.vinculacao_automatica_categoria_id_seq', 209, true);
            public       postgres    false    645            �           0    0    vinculacao_cnpj_empresa_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.vinculacao_cnpj_empresa_id_seq', 90, true);
            public       postgres    false    647            �           0    0    vinculo_categoria_cash_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.vinculo_categoria_cash_id_seq', 1, false);
            public       bv_postgres    false    671            �           0    0 #   vinculo_conciliacao_cobranca_id_seq    SEQUENCE SET     R   SELECT pg_catalog.setval('public.vinculo_conciliacao_cobranca_id_seq', 51, true);
            public       postgres    false    649            �           0    0 -   vinculo_descricao_ocorrencia_categoria_id_seq    SEQUENCE SET     \   SELECT pg_catalog.setval('public.vinculo_descricao_ocorrencia_categoria_id_seq', 1, false);
            public       postgres    false    650            �           0    0 #   vinculo_ocorrencia_pagamento_id_seq    SEQUENCE SET     R   SELECT pg_catalog.setval('public.vinculo_ocorrencia_pagamento_id_seq', 47, true);
            public       postgres    false    652            �           0    0 #   vinculo_pagamento_lancamento_id_seq    SEQUENCE SET     R   SELECT pg_catalog.setval('public.vinculo_pagamento_lancamento_id_seq', 1, false);
            public       postgres    false    655            �           0    0    vinculo_sacado_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.vinculo_sacado_id_seq', 52, true);
            public       postgres    false    656            �           0    0 &   vinculo_tarifa_origem_tipo_operacao_id    SEQUENCE SET     U   SELECT pg_catalog.setval('public.vinculo_tarifa_origem_tipo_operacao_id', 47, true);
            public       postgres    false    658            [           2606    18094 4   cliente_ftp_log_externo cliente_ftp_log_externo_pkey 
   CONSTRAINT     u   ALTER TABLE ONLY auditoria.cliente_ftp_log_externo
    ADD CONSTRAINT cliente_ftp_log_externo_pkey PRIMARY KEY (id);
 a   ALTER TABLE ONLY auditoria.cliente_ftp_log_externo DROP CONSTRAINT cliente_ftp_log_externo_pkey;
    	   auditoria         postgres    false    201            x           2606    36192 $   conta_pagar_aud conta_pagar_aud_pkey 
   CONSTRAINT     e   ALTER TABLE ONLY auditoria.conta_pagar_aud
    ADD CONSTRAINT conta_pagar_aud_pkey PRIMARY KEY (id);
 Q   ALTER TABLE ONLY auditoria.conta_pagar_aud DROP CONSTRAINT conta_pagar_aud_pkey;
    	   auditoria         postgres    false    673            W           2606    18096    arquivo_aud pk_arquivo 
   CONSTRAINT     W   ALTER TABLE ONLY auditoria.arquivo_aud
    ADD CONSTRAINT pk_arquivo PRIMARY KEY (id);
 C   ALTER TABLE ONLY auditoria.arquivo_aud DROP CONSTRAINT pk_arquivo;
    	   auditoria         postgres    false    197            Y           2606    18098    categoria pk_categoria 
   CONSTRAINT     W   ALTER TABLE ONLY auditoria.categoria
    ADD CONSTRAINT pk_categoria PRIMARY KEY (id);
 C   ALTER TABLE ONLY auditoria.categoria DROP CONSTRAINT pk_categoria;
    	   auditoria         postgres    false    199            ]           2606    18100 "   controle_acesso pk_controle_acesso 
   CONSTRAINT     c   ALTER TABLE ONLY auditoria.controle_acesso
    ADD CONSTRAINT pk_controle_acesso PRIMARY KEY (id);
 O   ALTER TABLE ONLY auditoria.controle_acesso DROP CONSTRAINT pk_controle_acesso;
    	   auditoria         postgres    false    203            _           2606    18102    empresa_aud pk_empresa_aud 
   CONSTRAINT     [   ALTER TABLE ONLY auditoria.empresa_aud
    ADD CONSTRAINT pk_empresa_aud PRIMARY KEY (id);
 G   ALTER TABLE ONLY auditoria.empresa_aud DROP CONSTRAINT pk_empresa_aud;
    	   auditoria         postgres    false    205            a           2606    18104 &   grupo_empresa_log pk_grupo_empresa_aud 
   CONSTRAINT     g   ALTER TABLE ONLY auditoria.grupo_empresa_log
    ADD CONSTRAINT pk_grupo_empresa_aud PRIMARY KEY (id);
 S   ALTER TABLE ONLY auditoria.grupo_empresa_log DROP CONSTRAINT pk_grupo_empresa_aud;
    	   auditoria         postgres    false    208            c           2606    18106 &   historico_usuario pk_historico_usuario 
   CONSTRAINT     g   ALTER TABLE ONLY auditoria.historico_usuario
    ADD CONSTRAINT pk_historico_usuario PRIMARY KEY (id);
 S   ALTER TABLE ONLY auditoria.historico_usuario DROP CONSTRAINT pk_historico_usuario;
    	   auditoria         postgres    false    210            e           2606    18108    menu_log pk_menu_log 
   CONSTRAINT     U   ALTER TABLE ONLY auditoria.menu_log
    ADD CONSTRAINT pk_menu_log PRIMARY KEY (id);
 A   ALTER TABLE ONLY auditoria.menu_log DROP CONSTRAINT pk_menu_log;
    	   auditoria         postgres    false    214            g           2606    18110    sub_categoria pk_sub_categoria 
   CONSTRAINT     _   ALTER TABLE ONLY auditoria.sub_categoria
    ADD CONSTRAINT pk_sub_categoria PRIMARY KEY (id);
 K   ALTER TABLE ONLY auditoria.sub_categoria DROP CONSTRAINT pk_sub_categoria;
    	   auditoria         postgres    false    216            �           2606    18112 !   ocorrencia_cobranca UK_OCORRENCIA 
   CONSTRAINT     �   ALTER TABLE ONLY public.ocorrencia_cobranca
    ADD CONSTRAINT "UK_OCORRENCIA" UNIQUE (codigo, tipo_movimento_retorno, layout);
 M   ALTER TABLE ONLY public.ocorrencia_cobranca DROP CONSTRAINT "UK_OCORRENCIA";
       public         postgres    false    523    523    523            k           2606    18114 R   agendamento_descricao_categoria_global agendamento_descricao_categoria_global_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.agendamento_descricao_categoria_global
    ADD CONSTRAINT agendamento_descricao_categoria_global_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.agendamento_descricao_categoria_global DROP CONSTRAINT agendamento_descricao_categoria_global_pkey;
       public         postgres    false    221            m           2606    18116 4   aplicacao_processamento aplicacao_processamento_pkey 
   CONSTRAINT     r   ALTER TABLE ONLY public.aplicacao_processamento
    ADD CONSTRAINT aplicacao_processamento_pkey PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.aplicacao_processamento DROP CONSTRAINT aplicacao_processamento_pkey;
       public         postgres    false    223            v           2606    18118 @   arrecadacao_debito_automatico arrecadacao_debito_automatico_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.arrecadacao_debito_automatico
    ADD CONSTRAINT arrecadacao_debito_automatico_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.arrecadacao_debito_automatico DROP CONSTRAINT arrecadacao_debito_automatico_pkey;
       public         postgres    false    229            z           2606    18120 D   arrecadacao_divergente_contrato arrecadacao_divergente_contrato_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.arrecadacao_divergente_contrato
    ADD CONSTRAINT arrecadacao_divergente_contrato_pkey PRIMARY KEY (id);
 n   ALTER TABLE ONLY public.arrecadacao_divergente_contrato DROP CONSTRAINT arrecadacao_divergente_contrato_pkey;
       public         postgres    false    231            q           2606    18122    arrecadacao arrecadacao_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.arrecadacao
    ADD CONSTRAINT arrecadacao_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.arrecadacao DROP CONSTRAINT arrecadacao_pkey;
       public         postgres    false    227            �           2606    18124    banco banco_cod_banco_unique 
   CONSTRAINT     \   ALTER TABLE ONLY public.banco
    ADD CONSTRAINT banco_cod_banco_unique UNIQUE (cod_banco);
 F   ALTER TABLE ONLY public.banco DROP CONSTRAINT banco_cod_banco_unique;
       public         postgres    false    247            �           2606    18126    banco banco_ispb_uk 
   CONSTRAINT     N   ALTER TABLE ONLY public.banco
    ADD CONSTRAINT banco_ispb_uk UNIQUE (ispb);
 =   ALTER TABLE ONLY public.banco DROP CONSTRAINT banco_ispb_uk;
       public         postgres    false    247            �           2606    18128    cheque cheque_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY public.cheque
    ADD CONSTRAINT cheque_pkey PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.cheque DROP CONSTRAINT cheque_pkey;
       public         postgres    false    266            �           2606    18130    clientsftp clientsftp_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.clientsftp
    ADD CONSTRAINT clientsftp_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.clientsftp DROP CONSTRAINT clientsftp_pkey;
       public         postgres    false    274            p           2606    35346 &   conciliacao_cash conciliacao_cash_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.conciliacao_cash
    ADD CONSTRAINT conciliacao_cash_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.conciliacao_cash DROP CONSTRAINT conciliacao_cash_pkey;
       public         postgres    false    665            �           2606    18132 Z   conciliacao_financeira_auxiliar_lancamento conciliacao_financeira_auxiliar_lancamento_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_financeira_auxiliar_lancamento
    ADD CONSTRAINT conciliacao_financeira_auxiliar_lancamento_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.conciliacao_financeira_auxiliar_lancamento DROP CONSTRAINT conciliacao_financeira_auxiliar_lancamento_pkey;
       public         postgres    false    288            �           2606    18134 R   conciliacao_financeira_auxiliar_titulo conciliacao_financeira_auxiliar_titulo_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_financeira_auxiliar_titulo
    ADD CONSTRAINT conciliacao_financeira_auxiliar_titulo_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.conciliacao_financeira_auxiliar_titulo DROP CONSTRAINT conciliacao_financeira_auxiliar_titulo_pkey;
       public         postgres    false    289            �           2606    18136 @   conciliacao_numerario conciliacao_numerario_chave_lancamento_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_numerario
    ADD CONSTRAINT conciliacao_numerario_chave_lancamento_key UNIQUE (chave_lancamento);
 j   ALTER TABLE ONLY public.conciliacao_numerario DROP CONSTRAINT conciliacao_numerario_chave_lancamento_key;
       public         postgres    false    292            �           2606    18138 .   configuracao_sistema configuracao_sistema_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.configuracao_sistema
    ADD CONSTRAINT configuracao_sistema_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.configuracao_sistema DROP CONSTRAINT configuracao_sistema_pkey;
       public         postgres    false    294            �           2606    18140    conta conta_duplicada_key 
   CONSTRAINT     ~   ALTER TABLE ONLY public.conta
    ADD CONSTRAINT conta_duplicada_key UNIQUE (conta, dv_conta, agencia, banco_id, empresa_id);
 C   ALTER TABLE ONLY public.conta DROP CONSTRAINT conta_duplicada_key;
       public         postgres    false    296    296    296    296    296            �           2606    18142 >   conta_lancamento_fluxo_caixa conta_lancamento_fluxo_caixa_pkey 
   CONSTRAINT     |   ALTER TABLE ONLY public.conta_lancamento_fluxo_caixa
    ADD CONSTRAINT conta_lancamento_fluxo_caixa_pkey PRIMARY KEY (id);
 h   ALTER TABLE ONLY public.conta_lancamento_fluxo_caixa DROP CONSTRAINT conta_lancamento_fluxo_caixa_pkey;
       public         postgres    false    299            �           2606    18144 &   conta_lancamento conta_lancamento_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.conta_lancamento
    ADD CONSTRAINT conta_lancamento_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.conta_lancamento DROP CONSTRAINT conta_lancamento_pkey;
       public         postgres    false    298            �           2606    18146 0   contrato_arrecadadora contrato_arrecadadora_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.contrato_arrecadadora
    ADD CONSTRAINT contrato_arrecadadora_pkey PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.contrato_arrecadadora DROP CONSTRAINT contrato_arrecadadora_pkey;
       public         postgres    false    308            �           2606    18148 (   contrato_bancario contrato_bancario_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.contrato_bancario
    ADD CONSTRAINT contrato_bancario_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.contrato_bancario DROP CONSTRAINT contrato_bancario_pkey;
       public         postgres    false    310            �           2606    18150 >   controle_nsa_arrecadacao controle_nsa_arrecadacao_banco_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.controle_nsa_arrecadacao
    ADD CONSTRAINT controle_nsa_arrecadacao_banco_id_key UNIQUE (banco_id, nsa, tipoarrecadacao);
 h   ALTER TABLE ONLY public.controle_nsa_arrecadacao DROP CONSTRAINT controle_nsa_arrecadacao_banco_id_key;
       public         postgres    false    320    320    320            �           2606    18152 6   controle_nsa_arrecadacao controle_nsa_arrecadacao_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.controle_nsa_arrecadacao
    ADD CONSTRAINT controle_nsa_arrecadacao_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.controle_nsa_arrecadacao DROP CONSTRAINT controle_nsa_arrecadacao_pkey;
       public         postgres    false    320            �           2606    18154 I   controle_nsa_optantes_debito controle_nsa_optantes_debito_convenio_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.controle_nsa_optantes_debito
    ADD CONSTRAINT controle_nsa_optantes_debito_convenio_id_key UNIQUE (convenio_id, nsa);
 s   ALTER TABLE ONLY public.controle_nsa_optantes_debito DROP CONSTRAINT controle_nsa_optantes_debito_convenio_id_key;
       public         postgres    false    323    323            �           2606    18156 >   controle_nsa_optantes_debito controle_nsa_optantes_debito_pkey 
   CONSTRAINT     |   ALTER TABLE ONLY public.controle_nsa_optantes_debito
    ADD CONSTRAINT controle_nsa_optantes_debito_pkey PRIMARY KEY (id);
 h   ALTER TABLE ONLY public.controle_nsa_optantes_debito DROP CONSTRAINT controle_nsa_optantes_debito_pkey;
       public         postgres    false    323            �           2606    18158 U   controle_processamento controle_processamento_grupo_empresa_id_tipo_processamento_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.controle_processamento
    ADD CONSTRAINT controle_processamento_grupo_empresa_id_tipo_processamento_key UNIQUE (grupo_empresa_id, tipo_processamento);
    ALTER TABLE ONLY public.controle_processamento DROP CONSTRAINT controle_processamento_grupo_empresa_id_tipo_processamento_key;
       public         postgres    false    327    327            �           2606    18160 2   controle_processamento controle_processamento_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.controle_processamento
    ADD CONSTRAINT controle_processamento_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.controle_processamento DROP CONSTRAINT controle_processamento_pkey;
       public         postgres    false    327            �           2606    18162 F   controle_remessa_optantes_debito controle_remessa_optantes_debito_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.controle_remessa_optantes_debito
    ADD CONSTRAINT controle_remessa_optantes_debito_pkey PRIMARY KEY (id);
 p   ALTER TABLE ONLY public.controle_remessa_optantes_debito DROP CONSTRAINT controle_remessa_optantes_debito_pkey;
       public         postgres    false    328            �           2606    18164 1   parametro_autorizacao convenio_compromisso_unique 
   CONSTRAINT     �   ALTER TABLE ONLY public.parametro_autorizacao
    ADD CONSTRAINT convenio_compromisso_unique UNIQUE (convenio_id, compromisso_id);
 [   ALTER TABLE ONLY public.parametro_autorizacao DROP CONSTRAINT convenio_compromisso_unique;
       public         postgres    false    539    539            �           2606    18166 $   convenio_conta convenio_conta_unique 
   CONSTRAINT     p   ALTER TABLE ONLY public.convenio_conta
    ADD CONSTRAINT convenio_conta_unique UNIQUE (convenio_id, conta_id);
 N   ALTER TABLE ONLY public.convenio_conta DROP CONSTRAINT convenio_conta_unique;
       public         postgres    false    338    338            �           2606    18168 (   convenio_empresa convenio_empresa_unique 
   CONSTRAINT     v   ALTER TABLE ONLY public.convenio_empresa
    ADD CONSTRAINT convenio_empresa_unique UNIQUE (convenio_id, empresa_id);
 R   ALTER TABLE ONLY public.convenio_empresa DROP CONSTRAINT convenio_empresa_unique;
       public         postgres    false    339    339            S           2606    18170 <   vinculacao_automatica_categoria descricao_banco_categoria_pk 
   CONSTRAINT     �   ALTER TABLE ONLY public.vinculacao_automatica_categoria
    ADD CONSTRAINT descricao_banco_categoria_pk UNIQUE (descricao, banco_id, categoria_lancamento_id);
 f   ALTER TABLE ONLY public.vinculacao_automatica_categoria DROP CONSTRAINT descricao_banco_categoria_pk;
       public         postgres    false    644    644    644                       2606    18172 %   descricao_lancamento descricao_codigo 
   CONSTRAINT     �   ALTER TABLE ONLY public.descricao_lancamento
    ADD CONSTRAINT descricao_codigo UNIQUE (codigo, descricao, banco_id, empresa_id);
 O   ALTER TABLE ONLY public.descricao_lancamento DROP CONSTRAINT descricao_codigo;
       public         postgres    false    348    348    348    348                       2606    18174 ~   descricao_lancamento_new_categoria_lancamento_new_configuracao descricao_lancamento_new_categoria_lancamento_new_configur_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.descricao_lancamento_new_categoria_lancamento_new_configuracao
    ADD CONSTRAINT descricao_lancamento_new_categoria_lancamento_new_configur_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.descricao_lancamento_new_categoria_lancamento_new_configuracao DROP CONSTRAINT descricao_lancamento_new_categoria_lancamento_new_configur_pkey;
       public         postgres    false    351                       2606    18176 0   despesa_processamento despesa_processamento_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.despesa_processamento
    ADD CONSTRAINT despesa_processamento_pkey PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.despesa_processamento DROP CONSTRAINT despesa_processamento_pkey;
       public         postgres    false    354            t           2606    35580    documentacao documentacao_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.documentacao
    ADD CONSTRAINT documentacao_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.documentacao DROP CONSTRAINT documentacao_pkey;
       public         postgres    false    669                       2606    18178 2   empresa_transportadora empresa_transportadora_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.empresa_transportadora
    ADD CONSTRAINT empresa_transportadora_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.empresa_transportadora DROP CONSTRAINT empresa_transportadora_pkey;
       public         postgres    false    363                       2606    18180 6   emprestimo_processamento emprestimo_processamento_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.emprestimo_processamento
    ADD CONSTRAINT emprestimo_processamento_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.emprestimo_processamento DROP CONSTRAINT emprestimo_processamento_pkey;
       public         postgres    false    366                        2606    18182 @   faixa_nosso_numero_sacado_aud faixa_nosso_numero_sacado_aud_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.faixa_nosso_numero_sacado_aud
    ADD CONSTRAINT faixa_nosso_numero_sacado_aud_pkey PRIMARY KEY (id, rev);
 j   ALTER TABLE ONLY public.faixa_nosso_numero_sacado_aud DROP CONSTRAINT faixa_nosso_numero_sacado_aud_pkey;
       public         postgres    false    372    372                       2606    18184 8   faixa_nosso_numero_sacado faixa_nosso_numero_sacado_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.faixa_nosso_numero_sacado
    ADD CONSTRAINT faixa_nosso_numero_sacado_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.faixa_nosso_numero_sacado DROP CONSTRAINT faixa_nosso_numero_sacado_pkey;
       public         postgres    false    371            "           2606    18186    faturamento faturamento_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.faturamento
    ADD CONSTRAINT faturamento_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.faturamento DROP CONSTRAINT faturamento_pkey;
       public         postgres    false    376            &           2606    18188 &   favorecido_conta favorecido_conta_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.favorecido_conta
    ADD CONSTRAINT favorecido_conta_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.favorecido_conta DROP CONSTRAINT favorecido_conta_pkey;
       public         postgres    false    380            P           2606    18190    grupo_sacado fk_grupo_sacado 
   CONSTRAINT     Z   ALTER TABLE ONLY public.grupo_sacado
    ADD CONSTRAINT fk_grupo_sacado PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.grupo_sacado DROP CONSTRAINT fk_grupo_sacado;
       public         postgres    false    415            >           2606    18192    usuario fk_usuario 
   CONSTRAINT     P   ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT fk_usuario PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.usuario DROP CONSTRAINT fk_usuario;
       public         postgres    false    628            +           2606    18194    float float_banco_id_key 
   CONSTRAINT     y   ALTER TABLE ONLY public."float"
    ADD CONSTRAINT float_banco_id_key UNIQUE (banco_id, forma_pagamento_arrecadacao_id);
 D   ALTER TABLE ONLY public."float" DROP CONSTRAINT float_banco_id_key;
       public         postgres    false    386    386            -           2606    18196    float float_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY public."float"
    ADD CONSTRAINT float_pkey PRIMARY KEY (id);
 <   ALTER TABLE ONLY public."float" DROP CONSTRAINT float_pkey;
       public         postgres    false    386            1           2606    18198 B   forma_pagamento_arrecadacao forma_pagamento_arrecadacao_codigo_key 
   CONSTRAINT        ALTER TABLE ONLY public.forma_pagamento_arrecadacao
    ADD CONSTRAINT forma_pagamento_arrecadacao_codigo_key UNIQUE (codigo);
 l   ALTER TABLE ONLY public.forma_pagamento_arrecadacao DROP CONSTRAINT forma_pagamento_arrecadacao_codigo_key;
       public         postgres    false    389            3           2606    18200 <   forma_pagamento_arrecadacao forma_pagamento_arrecadacao_pkey 
   CONSTRAINT     z   ALTER TABLE ONLY public.forma_pagamento_arrecadacao
    ADD CONSTRAINT forma_pagamento_arrecadacao_pkey PRIMARY KEY (id);
 f   ALTER TABLE ONLY public.forma_pagamento_arrecadacao DROP CONSTRAINT forma_pagamento_arrecadacao_pkey;
       public         postgres    false    389            5           2606    18202 <   forma_pagamento_fluxo_caixa forma_pagamento_fluxo_caixa_pkey 
   CONSTRAINT     z   ALTER TABLE ONLY public.forma_pagamento_fluxo_caixa
    ADD CONSTRAINT forma_pagamento_fluxo_caixa_pkey PRIMARY KEY (id);
 f   ALTER TABLE ONLY public.forma_pagamento_fluxo_caixa DROP CONSTRAINT forma_pagamento_fluxo_caixa_pkey;
       public         postgres    false    391            7           2606    18204 4   frequencia_recolhimento frequencia_recolhimento_pkey 
   CONSTRAINT     r   ALTER TABLE ONLY public.frequencia_recolhimento
    ADD CONSTRAINT frequencia_recolhimento_pkey PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.frequencia_recolhimento DROP CONSTRAINT frequencia_recolhimento_pkey;
       public         postgres    false    395            :           2606    18206 L   grafico_arrecadacao_forma_pagamento grafico_arrecadacao_forma_pagamento_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.grafico_arrecadacao_forma_pagamento
    ADD CONSTRAINT grafico_arrecadacao_forma_pagamento_pkey PRIMARY KEY (id);
 v   ALTER TABLE ONLY public.grafico_arrecadacao_forma_pagamento DROP CONSTRAINT grafico_arrecadacao_forma_pagamento_pkey;
       public         postgres    false    397            F           2606    18208 >   grupo_lancamento_fluxo_caixa grupo_lancamento_fluxo_caixa_pkey 
   CONSTRAINT     |   ALTER TABLE ONLY public.grupo_lancamento_fluxo_caixa
    ADD CONSTRAINT grupo_lancamento_fluxo_caixa_pkey PRIMARY KEY (id);
 h   ALTER TABLE ONLY public.grupo_lancamento_fluxo_caixa DROP CONSTRAINT grupo_lancamento_fluxo_caixa_pkey;
       public         postgres    false    408            H           2606    18210 $   grupo_numerario grupo_numerario_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.grupo_numerario
    ADD CONSTRAINT grupo_numerario_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.grupo_numerario DROP CONSTRAINT grupo_numerario_pkey;
       public         postgres    false    410            U           2606    18212 "   grupopermissao grupopermissao_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.grupopermissao
    ADD CONSTRAINT grupopermissao_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.grupopermissao DROP CONSTRAINT grupopermissao_pkey;
       public         postgres    false    420            W           2606    18214 H   historico_frequencia_recolhimento historico_frequencia_recolhimento_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.historico_frequencia_recolhimento
    ADD CONSTRAINT historico_frequencia_recolhimento_pkey PRIMARY KEY (id);
 r   ALTER TABLE ONLY public.historico_frequencia_recolhimento DROP CONSTRAINT historico_frequencia_recolhimento_pkey;
       public         postgres    false    424            [           2606    18216 8   historico_optantes_debito historico_optantes_debito_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.historico_optantes_debito
    ADD CONSTRAINT historico_optantes_debito_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.historico_optantes_debito DROP CONSTRAINT historico_optantes_debito_pkey;
       public         postgres    false    428            e           2606    18218 B   importacao_personalizada_campo importacao_personalizada_campo_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.importacao_personalizada_campo
    ADD CONSTRAINT importacao_personalizada_campo_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.importacao_personalizada_campo DROP CONSTRAINT importacao_personalizada_campo_pkey;
       public         postgres    false    437            g           2606    18220 L   importacao_personalizada_conta_fixo importacao_personalizada_conta_fixo_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.importacao_personalizada_conta_fixo
    ADD CONSTRAINT importacao_personalizada_conta_fixo_pkey PRIMARY KEY (id);
 v   ALTER TABLE ONLY public.importacao_personalizada_conta_fixo DROP CONSTRAINT importacao_personalizada_conta_fixo_pkey;
       public         postgres    false    439            i           2606    18222 R   importacao_personalizada_ignorar_linha importacao_personalizada_ignorar_linha_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.importacao_personalizada_ignorar_linha
    ADD CONSTRAINT importacao_personalizada_ignorar_linha_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.importacao_personalizada_ignorar_linha DROP CONSTRAINT importacao_personalizada_ignorar_linha_pkey;
       public         postgres    false    442            c           2606    18224 6   importacao_personalizada importacao_personalizada_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.importacao_personalizada
    ADD CONSTRAINT importacao_personalizada_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.importacao_personalizada DROP CONSTRAINT importacao_personalizada_pkey;
       public         postgres    false    436            k           2606    18226 2   item_contrato_bancario item_contrato_bancario_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.item_contrato_bancario
    ADD CONSTRAINT item_contrato_bancario_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.item_contrato_bancario DROP CONSTRAINT item_contrato_bancario_pkey;
       public         postgres    false    444            {           2606    18228 H   item_grupo_lancamento_fluxo_caixa item_grupo_lancamento_fluxo_caixa_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.item_grupo_lancamento_fluxo_caixa
    ADD CONSTRAINT item_grupo_lancamento_fluxo_caixa_pkey PRIMARY KEY (id);
 r   ALTER TABLE ONLY public.item_grupo_lancamento_fluxo_caixa DROP CONSTRAINT item_grupo_lancamento_fluxo_caixa_pkey;
       public         postgres    false    458            }           2606    18230 (   lancamento_debito lancamento_debito_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.lancamento_debito
    ADD CONSTRAINT lancamento_debito_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.lancamento_debito DROP CONSTRAINT lancamento_debito_pkey;
       public         postgres    false    460            �           2606    18232 2   lancamento_fluxo_caixa lancamento_fluxo_caixa_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.lancamento_fluxo_caixa
    ADD CONSTRAINT lancamento_fluxo_caixa_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.lancamento_fluxo_caixa DROP CONSTRAINT lancamento_fluxo_caixa_pkey;
       public         postgres    false    465            �           2606    18234 "   layout_campo layout_campo_nome_key 
   CONSTRAINT     x   ALTER TABLE ONLY public.layout_campo
    ADD CONSTRAINT layout_campo_nome_key UNIQUE (nome, tipoarrecadacao, banco_id);
 L   ALTER TABLE ONLY public.layout_campo DROP CONSTRAINT layout_campo_nome_key;
       public         postgres    false    468    468    468            �           2606    18236 T   layout_campo_pagamento layout_campo_pagamento_nome_tipo_pagamento_compromisso_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.layout_campo_pagamento
    ADD CONSTRAINT layout_campo_pagamento_nome_tipo_pagamento_compromisso_id_key UNIQUE (nome, tipo_arquivo_pagamento_flexivel, compromisso_id);
 ~   ALTER TABLE ONLY public.layout_campo_pagamento DROP CONSTRAINT layout_campo_pagamento_nome_tipo_pagamento_compromisso_id_key;
       public         postgres    false    470    470    470            �           2606    18238 2   layout_campo_pagamento layout_campo_pagamento_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.layout_campo_pagamento
    ADD CONSTRAINT layout_campo_pagamento_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.layout_campo_pagamento DROP CONSTRAINT layout_campo_pagamento_pkey;
       public         postgres    false    470            �           2606    18240    layout_campo layout_campo_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.layout_campo
    ADD CONSTRAINT layout_campo_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.layout_campo DROP CONSTRAINT layout_campo_pkey;
       public         postgres    false    468            �           2606    18242 $   limite_especial limite_especial_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.limite_especial
    ADD CONSTRAINT limite_especial_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.limite_especial DROP CONSTRAINT limite_especial_pkey;
       public         postgres    false    472            �           2606    18244 .   log_erro_catalogador log_erro_catalogador_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.log_erro_catalogador
    ADD CONSTRAINT log_erro_catalogador_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.log_erro_catalogador DROP CONSTRAINT log_erro_catalogador_pkey;
       public         postgres    false    479            �           2606    18246 0   lote_pag_aux lote_pag_aux_lote_favorecido_unique 
   CONSTRAINT     y   ALTER TABLE ONLY public.lote_pag_aux
    ADD CONSTRAINT lote_pag_aux_lote_favorecido_unique UNIQUE (lote_favorecido_id);
 Z   ALTER TABLE ONLY public.lote_pag_aux DROP CONSTRAINT lote_pag_aux_lote_favorecido_unique;
       public         postgres    false    493            �           2606    18248 $   mensagem_titulo mensagem_titulo_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.mensagem_titulo
    ADD CONSTRAINT mensagem_titulo_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.mensagem_titulo DROP CONSTRAINT mensagem_titulo_pkey;
       public         postgres    false    497            �           2606    18250 >   modalidade_contrato_bancario modalidade_contrato_bancario_pkey 
   CONSTRAINT     |   ALTER TABLE ONLY public.modalidade_contrato_bancario
    ADD CONSTRAINT modalidade_contrato_bancario_pkey PRIMARY KEY (id);
 h   ALTER TABLE ONLY public.modalidade_contrato_bancario DROP CONSTRAINT modalidade_contrato_bancario_pkey;
       public         postgres    false    499            �           2606    18252    modulo modulo_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY public.modulo
    ADD CONSTRAINT modulo_pkey PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.modulo DROP CONSTRAINT modulo_pkey;
       public         postgres    false    501            �           2606    18254 ,   movimento_pagamento movimento_pagamento_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.movimento_pagamento
    ADD CONSTRAINT movimento_pagamento_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.movimento_pagamento DROP CONSTRAINT movimento_pagamento_pkey;
       public         postgres    false    503            �           2606    18256 Z   movimento_retorno_cobranca movimento_retorno_cobranca_codigo_layout_tipo_movimento_re_key1 
   CONSTRAINT     �   ALTER TABLE ONLY public.movimento_retorno_cobranca
    ADD CONSTRAINT movimento_retorno_cobranca_codigo_layout_tipo_movimento_re_key1 UNIQUE (codigo, layout, tipo_movimento_retorno);
 �   ALTER TABLE ONLY public.movimento_retorno_cobranca DROP CONSTRAINT movimento_retorno_cobranca_codigo_layout_tipo_movimento_re_key1;
       public         postgres    false    507    507    507            �           2606    18258 Z   movimento_retorno_cobranca movimento_retorno_cobranca_codigo_layout_tipo_movimento_ret_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.movimento_retorno_cobranca
    ADD CONSTRAINT movimento_retorno_cobranca_codigo_layout_tipo_movimento_ret_key UNIQUE (codigo, layout, tipo_movimento_retorno);
 �   ALTER TABLE ONLY public.movimento_retorno_cobranca DROP CONSTRAINT movimento_retorno_cobranca_codigo_layout_tipo_movimento_ret_key;
       public         postgres    false    507    507    507            �           2606    18260 6   notificacao_destinatario notificacao_destinatario_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.notificacao_destinatario
    ADD CONSTRAINT notificacao_destinatario_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.notificacao_destinatario DROP CONSTRAINT notificacao_destinatario_pkey;
       public         postgres    false    510            �           2606    18262    notificacao notificacao_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.notificacao
    ADD CONSTRAINT notificacao_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.notificacao DROP CONSTRAINT notificacao_pkey;
       public         postgres    false    509            �           2606    18264 ,   notificacao_usuario notificacao_usuario_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.notificacao_usuario
    ADD CONSTRAINT notificacao_usuario_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.notificacao_usuario DROP CONSTRAINT notificacao_usuario_pkey;
       public         postgres    false    515            �           2606    18266 ,   ocorrencia_cobranca ocorrencia_cobranca_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.ocorrencia_cobranca
    ADD CONSTRAINT ocorrencia_cobranca_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.ocorrencia_cobranca DROP CONSTRAINT ocorrencia_cobranca_pkey;
       public         postgres    false    523            �           2606    18268 #   optantes_debito optantes_debito_key 
   CONSTRAINT     d   ALTER TABLE ONLY public.optantes_debito
    ADD CONSTRAINT optantes_debito_key UNIQUE (id_cliente);
 M   ALTER TABLE ONLY public.optantes_debito DROP CONSTRAINT optantes_debito_key;
       public         postgres    false    528            �           2606    18270 $   optantes_debito optantes_debito_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.optantes_debito
    ADD CONSTRAINT optantes_debito_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.optantes_debito DROP CONSTRAINT optantes_debito_pkey;
       public         postgres    false    528            L           2606    18272 '   grupo_pagamento pagamento_duplicado_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.grupo_pagamento
    ADD CONSTRAINT pagamento_duplicado_key UNIQUE (pagamento_id, data_pagamento, valor, tipo_servico_id, tipo_grupo, forma_pagamento_id);
 Q   ALTER TABLE ONLY public.grupo_pagamento DROP CONSTRAINT pagamento_duplicado_key;
       public         postgres    false    413    413    413    413    413    413            �           2606    18274     pendencia_nsa pendencia_nsa_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.pendencia_nsa
    ADD CONSTRAINT pendencia_nsa_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.pendencia_nsa DROP CONSTRAINT pendencia_nsa_pkey;
       public         postgres    false    541            �           2606    18276    perfil perfil_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY public.perfil
    ADD CONSTRAINT perfil_pkey PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.perfil DROP CONSTRAINT perfil_pkey;
       public         postgres    false    543            �           2606    18278    permissao_ip permissao_ip_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.permissao_ip
    ADD CONSTRAINT permissao_ip_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.permissao_ip DROP CONSTRAINT permissao_ip_pkey;
       public         postgres    false    549            �           2606    18280    permissao permissao_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY public.permissao
    ADD CONSTRAINT permissao_pkey PRIMARY KEY (id);
 B   ALTER TABLE ONLY public.permissao DROP CONSTRAINT permissao_pkey;
       public         postgres    false    547            i           2606    18282 .   acesso_conta_auxiliar pk_acesso_conta_auxiliar 
   CONSTRAINT     l   ALTER TABLE ONLY public.acesso_conta_auxiliar
    ADD CONSTRAINT pk_acesso_conta_auxiliar PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.acesso_conta_auxiliar DROP CONSTRAINT pk_acesso_conta_auxiliar;
       public         postgres    false    219            o           2606    18284    arquivo pk_arquivo 
   CONSTRAINT     P   ALTER TABLE ONLY public.arquivo
    ADD CONSTRAINT pk_arquivo PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.arquivo DROP CONSTRAINT pk_arquivo;
       public         postgres    false    226            |           2606    18286    auditoria pk_auditoria 
   CONSTRAINT     T   ALTER TABLE ONLY public.auditoria
    ADD CONSTRAINT pk_auditoria PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.auditoria DROP CONSTRAINT pk_auditoria;
       public         postgres    false    234            �           2606    18288 "   auditoria_suite pk_auditoria_suite 
   CONSTRAINT     `   ALTER TABLE ONLY public.auditoria_suite
    ADD CONSTRAINT pk_auditoria_suite PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.auditoria_suite DROP CONSTRAINT pk_auditoria_suite;
       public         postgres    false    238            �           2606    18290 2   autorizacao_dependencia pk_autorizacao_dependencia 
   CONSTRAINT     p   ALTER TABLE ONLY public.autorizacao_dependencia
    ADD CONSTRAINT pk_autorizacao_dependencia PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.autorizacao_dependencia DROP CONSTRAINT pk_autorizacao_dependencia;
       public         postgres    false    240            �           2606    18292 "   autorizacao_pag pk_autorizacao_pag 
   CONSTRAINT     `   ALTER TABLE ONLY public.autorizacao_pag
    ADD CONSTRAINT pk_autorizacao_pag PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.autorizacao_pag DROP CONSTRAINT pk_autorizacao_pag;
       public         postgres    false    242            �           2606    18294 *   autorizacao_remessa pk_autorizacao_remessa 
   CONSTRAINT     h   ALTER TABLE ONLY public.autorizacao_remessa
    ADD CONSTRAINT pk_autorizacao_remessa PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.autorizacao_remessa DROP CONSTRAINT pk_autorizacao_remessa;
       public         postgres    false    244            �           2606    18296    banco pk_banco 
   CONSTRAINT     L   ALTER TABLE ONLY public.banco
    ADD CONSTRAINT pk_banco PRIMARY KEY (id);
 8   ALTER TABLE ONLY public.banco DROP CONSTRAINT pk_banco;
       public         postgres    false    247            �           2606    18298    boleto pk_boleto 
   CONSTRAINT     N   ALTER TABLE ONLY public.boleto
    ADD CONSTRAINT pk_boleto PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.boleto DROP CONSTRAINT pk_boleto;
       public         postgres    false    253            �           2606    18300 &   carteira_cobranca pk_carteira_cobranca 
   CONSTRAINT     d   ALTER TABLE ONLY public.carteira_cobranca
    ADD CONSTRAINT pk_carteira_cobranca PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.carteira_cobranca DROP CONSTRAINT pk_carteira_cobranca;
       public         postgres    false    258            �           2606    18302 -   categoria_lancamento pk_categoria_lancamentos 
   CONSTRAINT     k   ALTER TABLE ONLY public.categoria_lancamento
    ADD CONSTRAINT pk_categoria_lancamentos PRIMARY KEY (id);
 W   ALTER TABLE ONLY public.categoria_lancamento DROP CONSTRAINT pk_categoria_lancamentos;
       public         postgres    false    260            �           2606    18304 5   categoria_lancamento_new pk_categoria_lancamentos_new 
   CONSTRAINT     s   ALTER TABLE ONLY public.categoria_lancamento_new
    ADD CONSTRAINT pk_categoria_lancamentos_new PRIMARY KEY (id);
 _   ALTER TABLE ONLY public.categoria_lancamento_new DROP CONSTRAINT pk_categoria_lancamentos_new;
       public         postgres    false    261            �           2606    18306    chave_pix pk_chave_pix 
   CONSTRAINT     T   ALTER TABLE ONLY public.chave_pix
    ADD CONSTRAINT pk_chave_pix PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.chave_pix DROP CONSTRAINT pk_chave_pix;
       public         postgres    false    265            �           2606    18308    cidade pk_cidade 
   CONSTRAINT     N   ALTER TABLE ONLY public.cidade
    ADD CONSTRAINT pk_cidade PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.cidade DROP CONSTRAINT pk_cidade;
       public         postgres    false    268            �           2606    18310    cliente_ftp pk_cliente_ftp 
   CONSTRAINT     X   ALTER TABLE ONLY public.cliente_ftp
    ADD CONSTRAINT pk_cliente_ftp PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.cliente_ftp DROP CONSTRAINT pk_cliente_ftp;
       public         postgres    false    270            �           2606    18312 "   cliente_ftp_log pk_cliente_ftp_log 
   CONSTRAINT     `   ALTER TABLE ONLY public.cliente_ftp_log
    ADD CONSTRAINT pk_cliente_ftp_log PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.cliente_ftp_log DROP CONSTRAINT pk_cliente_ftp_log;
       public         postgres    false    272            �           2606    18314 (   cobranca_instrucao pk_cobranca_instrucao 
   CONSTRAINT     f   ALTER TABLE ONLY public.cobranca_instrucao
    ADD CONSTRAINT pk_cobranca_instrucao PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.cobranca_instrucao DROP CONSTRAINT pk_cobranca_instrucao;
       public         postgres    false    276            �           2606    18316 (   cobranca_parametro pk_cobranca_parametro 
   CONSTRAINT     f   ALTER TABLE ONLY public.cobranca_parametro
    ADD CONSTRAINT pk_cobranca_parametro PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.cobranca_parametro DROP CONSTRAINT pk_cobranca_parametro;
       public         postgres    false    278            �           2606    18318 $   codigo_receita pk_codigo_receita_gps 
   CONSTRAINT     b   ALTER TABLE ONLY public.codigo_receita
    ADD CONSTRAINT pk_codigo_receita_gps PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.codigo_receita DROP CONSTRAINT pk_codigo_receita_gps;
       public         postgres    false    280            �           2606    18320    compromisso pk_compromisso 
   CONSTRAINT     X   ALTER TABLE ONLY public.compromisso
    ADD CONSTRAINT pk_compromisso PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.compromisso DROP CONSTRAINT pk_compromisso;
       public         postgres    false    282            �           2606    18322 ,   conciliacao_cobranca pk_conciliacao_cobranca 
   CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_cobranca
    ADD CONSTRAINT pk_conciliacao_cobranca PRIMARY KEY (grupo_titulo_id, chave_lancamento);
 V   ALTER TABLE ONLY public.conciliacao_cobranca DROP CONSTRAINT pk_conciliacao_cobranca;
       public         postgres    false    284    284            �           2606    18324 0   conciliacao_financeira pk_conciliacao_financeiro 
   CONSTRAINT     n   ALTER TABLE ONLY public.conciliacao_financeira
    ADD CONSTRAINT pk_conciliacao_financeiro PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.conciliacao_financeira DROP CONSTRAINT pk_conciliacao_financeiro;
       public         postgres    false    285            �           2606    18326 0   conciliacao_lancamento pk_conciliacao_lancamento 
   CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_lancamento
    ADD CONSTRAINT pk_conciliacao_lancamento PRIMARY KEY (grupo_lancamento_id, chave_lancamento);
 Z   ALTER TABLE ONLY public.conciliacao_lancamento DROP CONSTRAINT pk_conciliacao_lancamento;
       public         postgres    false    291    291            �           2606    18328 .   conciliacao_pagamento pk_conciliacao_pagamento 
   CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_pagamento
    ADD CONSTRAINT pk_conciliacao_pagamento PRIMARY KEY (grupo_pagamento_id, chave_lancamento);
 X   ALTER TABLE ONLY public.conciliacao_pagamento DROP CONSTRAINT pk_conciliacao_pagamento;
       public         postgres    false    293    293            �           2606    18330    conta pk_conta 
   CONSTRAINT     L   ALTER TABLE ONLY public.conta
    ADD CONSTRAINT pk_conta PRIMARY KEY (id);
 8   ALTER TABLE ONLY public.conta DROP CONSTRAINT pk_conta;
       public         postgres    false    296            �           2606    18332    conta_pagar pk_conta_pagar 
   CONSTRAINT     X   ALTER TABLE ONLY public.conta_pagar
    ADD CONSTRAINT pk_conta_pagar PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.conta_pagar DROP CONSTRAINT pk_conta_pagar;
       public         postgres    false    302            �           2606    18334 "   conta_pagar_log pk_conta_pagar_log 
   CONSTRAINT     `   ALTER TABLE ONLY public.conta_pagar_log
    ADD CONSTRAINT pk_conta_pagar_log PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.conta_pagar_log DROP CONSTRAINT pk_conta_pagar_log;
       public         postgres    false    304            �           2606    18336    contrato pk_contrato 
   CONSTRAINT     R   ALTER TABLE ONLY public.contrato
    ADD CONSTRAINT pk_contrato PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.contrato DROP CONSTRAINT pk_contrato;
       public         postgres    false    307            �           2606    18338 *   controle_acesso_api pk_controle_acesso_api 
   CONSTRAINT     h   ALTER TABLE ONLY public.controle_acesso_api
    ADD CONSTRAINT pk_controle_acesso_api PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.controle_acesso_api DROP CONSTRAINT pk_controle_acesso_api;
       public         postgres    false    313            �           2606    18340 6   controle_bloqueio_usuario pk_controle_bloqueio_usuario 
   CONSTRAINT     t   ALTER TABLE ONLY public.controle_bloqueio_usuario
    ADD CONSTRAINT pk_controle_bloqueio_usuario PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.controle_bloqueio_usuario DROP CONSTRAINT pk_controle_bloqueio_usuario;
       public         postgres    false    315            �           2606    18342    controle_nsa pk_controle_nsa 
   CONSTRAINT     Z   ALTER TABLE ONLY public.controle_nsa
    ADD CONSTRAINT pk_controle_nsa PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.controle_nsa DROP CONSTRAINT pk_controle_nsa;
       public         postgres    false    319            �           2606    18344 /   controle_nsa_remessa pk_controle_nsa_remessa_id 
   CONSTRAINT     m   ALTER TABLE ONLY public.controle_nsa_remessa
    ADD CONSTRAINT pk_controle_nsa_remessa_id PRIMARY KEY (id);
 Y   ALTER TABLE ONLY public.controle_nsa_remessa DROP CONSTRAINT pk_controle_nsa_remessa_id;
       public         postgres    false    326            �           2606    18346     controle_senha pk_controle_senha 
   CONSTRAINT     ^   ALTER TABLE ONLY public.controle_senha
    ADD CONSTRAINT pk_controle_senha PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.controle_senha DROP CONSTRAINT pk_controle_senha;
       public         postgres    false    330            �           2606    18348 2   controle_upload_arquivo pk_controle_upload_arquivo 
   CONSTRAINT     p   ALTER TABLE ONLY public.controle_upload_arquivo
    ADD CONSTRAINT pk_controle_upload_arquivo PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.controle_upload_arquivo DROP CONSTRAINT pk_controle_upload_arquivo;
       public         postgres    false    332            �           2606    18350    convenio pk_convenio 
   CONSTRAINT     R   ALTER TABLE ONLY public.convenio
    ADD CONSTRAINT pk_convenio PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.convenio DROP CONSTRAINT pk_convenio;
       public         postgres    false    334            �           2606    18352 .   convenio_configuracao pk_convenio_configuracao 
   CONSTRAINT     u   ALTER TABLE ONLY public.convenio_configuracao
    ADD CONSTRAINT pk_convenio_configuracao PRIMARY KEY (convenio_id);
 X   ALTER TABLE ONLY public.convenio_configuracao DROP CONSTRAINT pk_convenio_configuracao;
       public         postgres    false    336            �           2606    18354     convenio_conta pk_convenio_conta 
   CONSTRAINT     ^   ALTER TABLE ONLY public.convenio_conta
    ADD CONSTRAINT pk_convenio_conta PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.convenio_conta DROP CONSTRAINT pk_convenio_conta;
       public         postgres    false    338            �           2606    18356 $   convenio_empresa pk_convenio_empresa 
   CONSTRAINT     b   ALTER TABLE ONLY public.convenio_empresa
    ADD CONSTRAINT pk_convenio_empresa PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.convenio_empresa DROP CONSTRAINT pk_convenio_empresa;
       public         postgres    false    339                        2606    18358 $   convenio_extrato pk_convenio_extrato 
   CONSTRAINT     b   ALTER TABLE ONLY public.convenio_extrato
    ADD CONSTRAINT pk_convenio_extrato PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.convenio_extrato DROP CONSTRAINT pk_convenio_extrato;
       public         postgres    false    341                       2606    18360 (   convenio_pagamento pk_convenio_pagamento 
   CONSTRAINT     f   ALTER TABLE ONLY public.convenio_pagamento
    ADD CONSTRAINT pk_convenio_pagamento PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.convenio_pagamento DROP CONSTRAINT pk_convenio_pagamento;
       public         postgres    false    344                       2606    18362 6   credencial_acesso_empresa pk_credencial_acesso_empresa 
   CONSTRAINT     t   ALTER TABLE ONLY public.credencial_acesso_empresa
    ADD CONSTRAINT pk_credencial_acesso_empresa PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.credencial_acesso_empresa DROP CONSTRAINT pk_credencial_acesso_empresa;
       public         postgres    false    346            �           2606    18364    card pk_dashboard 
   CONSTRAINT     O   ALTER TABLE ONLY public.card
    ADD CONSTRAINT pk_dashboard PRIMARY KEY (id);
 ;   ALTER TABLE ONLY public.card DROP CONSTRAINT pk_dashboard;
       public         postgres    false    257                       2606    18366 +   descricao_lancamento pk_descrcao_lancamento 
   CONSTRAINT     i   ALTER TABLE ONLY public.descricao_lancamento
    ADD CONSTRAINT pk_descrcao_lancamento PRIMARY KEY (id);
 U   ALTER TABLE ONLY public.descricao_lancamento DROP CONSTRAINT pk_descrcao_lancamento;
       public         postgres    false    348            
           2606    18368 3   descricao_lancamento_new pk_descrcao_lancamento_new 
   CONSTRAINT     q   ALTER TABLE ONLY public.descricao_lancamento_new
    ADD CONSTRAINT pk_descrcao_lancamento_new PRIMARY KEY (id);
 ]   ALTER TABLE ONLY public.descricao_lancamento_new DROP CONSTRAINT pk_descrcao_lancamento_new;
       public         postgres    false    350                       2606    18370    download pk_download 
   CONSTRAINT     R   ALTER TABLE ONLY public.download
    ADD CONSTRAINT pk_download PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.download DROP CONSTRAINT pk_download;
       public         postgres    false    356                       2606    18372    email pk_email 
   CONSTRAINT     L   ALTER TABLE ONLY public.email
    ADD CONSTRAINT pk_email PRIMARY KEY (id);
 8   ALTER TABLE ONLY public.email DROP CONSTRAINT pk_email;
       public         postgres    false    358                       2606    18374    empresa pk_empresa 
   CONSTRAINT     P   ALTER TABLE ONLY public.empresa
    ADD CONSTRAINT pk_empresa PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.empresa DROP CONSTRAINT pk_empresa;
       public         postgres    false    360                       2606    18376    estado pk_estado 
   CONSTRAINT     N   ALTER TABLE ONLY public.estado
    ADD CONSTRAINT pk_estado PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.estado DROP CONSTRAINT pk_estado;
       public         postgres    false    367                       2606    18378    faixa_cep pk_faixa_cep 
   CONSTRAINT     T   ALTER TABLE ONLY public.faixa_cep
    ADD CONSTRAINT pk_faixa_cep PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.faixa_cep DROP CONSTRAINT pk_faixa_cep;
       public         postgres    false    369            $           2606    18380    favorecido pk_favorecido 
   CONSTRAINT     V   ALTER TABLE ONLY public.favorecido
    ADD CONSTRAINT pk_favorecido PRIMARY KEY (id);
 B   ALTER TABLE ONLY public.favorecido DROP CONSTRAINT pk_favorecido;
       public         postgres    false    378            )           2606    18382    feriado pk_feriado 
   CONSTRAINT     P   ALTER TABLE ONLY public.feriado
    ADD CONSTRAINT pk_feriado PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.feriado DROP CONSTRAINT pk_feriado;
       public         postgres    false    384            /           2606    18384 "   forma_pagamento pk_forma_pagamento 
   CONSTRAINT     `   ALTER TABLE ONLY public.forma_pagamento
    ADD CONSTRAINT pk_forma_pagamento PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.forma_pagamento DROP CONSTRAINT pk_forma_pagamento;
       public         postgres    false    388            <           2606    18386    grupo pk_grupo 
   CONSTRAINT     L   ALTER TABLE ONLY public.grupo
    ADD CONSTRAINT pk_grupo PRIMARY KEY (id);
 8   ALTER TABLE ONLY public.grupo DROP CONSTRAINT pk_grupo;
       public         postgres    false    399            >           2606    18388 8   grupo_autorizacao_convenio pk_grupo_autorizacao_convenio 
   CONSTRAINT     v   ALTER TABLE ONLY public.grupo_autorizacao_convenio
    ADD CONSTRAINT pk_grupo_autorizacao_convenio PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.grupo_autorizacao_convenio DROP CONSTRAINT pk_grupo_autorizacao_convenio;
       public         postgres    false    400            @           2606    18390    grupo_empresa pk_grupo_empresa 
   CONSTRAINT     \   ALTER TABLE ONLY public.grupo_empresa
    ADD CONSTRAINT pk_grupo_empresa PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.grupo_empresa DROP CONSTRAINT pk_grupo_empresa;
       public         postgres    false    403            D           2606    18392 $   grupo_lancamento pk_grupo_lancamento 
   CONSTRAINT     b   ALTER TABLE ONLY public.grupo_lancamento
    ADD CONSTRAINT pk_grupo_lancamento PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.grupo_lancamento DROP CONSTRAINT pk_grupo_lancamento;
       public         postgres    false    407            N           2606    18394 "   grupo_pagamento pk_grupo_pagamento 
   CONSTRAINT     `   ALTER TABLE ONLY public.grupo_pagamento
    ADD CONSTRAINT pk_grupo_pagamento PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.grupo_pagamento DROP CONSTRAINT pk_grupo_pagamento;
       public         postgres    false    413            S           2606    18396    grupo_titulo pk_grupo_titulo 
   CONSTRAINT     Z   ALTER TABLE ONLY public.grupo_titulo
    ADD CONSTRAINT pk_grupo_titulo PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.grupo_titulo DROP CONSTRAINT pk_grupo_titulo;
       public         postgres    false    418            Y           2606    18398 2   historico_monitoramento pk_historico_monitoramento 
   CONSTRAINT     p   ALTER TABLE ONLY public.historico_monitoramento
    ADD CONSTRAINT pk_historico_monitoramento PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.historico_monitoramento DROP CONSTRAINT pk_historico_monitoramento;
       public         postgres    false    426            _           2606    18400 :   historico_upload_favorecido pk_historico_upload_favorecido 
   CONSTRAINT     x   ALTER TABLE ONLY public.historico_upload_favorecido
    ADD CONSTRAINT pk_historico_upload_favorecido PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.historico_upload_favorecido DROP CONSTRAINT pk_historico_upload_favorecido;
       public         postgres    false    432            a           2606    18402 2   historico_upload_sacado pk_historico_upload_sacado 
   CONSTRAINT     p   ALTER TABLE ONLY public.historico_upload_sacado
    ADD CONSTRAINT pk_historico_upload_sacado PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.historico_upload_sacado DROP CONSTRAINT pk_historico_upload_sacado;
       public         postgres    false    434            m           2606    18404 B   item_contrato_bancario_pendente pk_item_contrato_bancario_pendente 
   CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_bancario_pendente
    ADD CONSTRAINT pk_item_contrato_bancario_pendente PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.item_contrato_bancario_pendente DROP CONSTRAINT pk_item_contrato_bancario_pendente;
       public         postgres    false    447            o           2606    18406 :   item_contrato_cesta_servico pk_item_contrato_cesta_servico 
   CONSTRAINT     x   ALTER TABLE ONLY public.item_contrato_cesta_servico
    ADD CONSTRAINT pk_item_contrato_cesta_servico PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.item_contrato_cesta_servico DROP CONSTRAINT pk_item_contrato_cesta_servico;
       public         postgres    false    448            s           2606    18408 0   item_contrato_cobranca pk_item_contrato_cobranca 
   CONSTRAINT     n   ALTER TABLE ONLY public.item_contrato_cobranca
    ADD CONSTRAINT pk_item_contrato_cobranca PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.item_contrato_cobranca DROP CONSTRAINT pk_item_contrato_cobranca;
       public         postgres    false    452            u           2606    18410 2   item_contrato_numerario pk_item_contrato_numerario 
   CONSTRAINT     p   ALTER TABLE ONLY public.item_contrato_numerario
    ADD CONSTRAINT pk_item_contrato_numerario PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.item_contrato_numerario DROP CONSTRAINT pk_item_contrato_numerario;
       public         postgres    false    453            y           2606    18412 2   item_contrato_pagamento pk_item_contrato_pagamento 
   CONSTRAINT     p   ALTER TABLE ONLY public.item_contrato_pagamento
    ADD CONSTRAINT pk_item_contrato_pagamento PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.item_contrato_pagamento DROP CONSTRAINT pk_item_contrato_pagamento;
       public         postgres    false    457            l           2606    34679 4   lancamento_auxiliar_cash pk_lancamento_auxiliar_cash 
   CONSTRAINT     r   ALTER TABLE ONLY public.lancamento_auxiliar_cash
    ADD CONSTRAINT pk_lancamento_auxiliar_cash PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.lancamento_auxiliar_cash DROP CONSTRAINT pk_lancamento_auxiliar_cash;
       public         postgres    false    660            �           2606    18414    lancamento_new pk_lancamentos 
   CONSTRAINT     [   ALTER TABLE ONLY public.lancamento_new
    ADD CONSTRAINT pk_lancamentos PRIMARY KEY (id);
 G   ALTER TABLE ONLY public.lancamento_new DROP CONSTRAINT pk_lancamentos;
       public         postgres    false    466            �           2606    18416 .   lancamento_duplicado pk_lancamentos_duplicados 
   CONSTRAINT     l   ALTER TABLE ONLY public.lancamento_duplicado
    ADD CONSTRAINT pk_lancamentos_duplicados PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.lancamento_duplicado DROP CONSTRAINT pk_lancamentos_duplicados;
       public         postgres    false    464            �           2606    18418    log_acesso pk_log_acesso 
   CONSTRAINT     V   ALTER TABLE ONLY public.log_acesso
    ADD CONSTRAINT pk_log_acesso PRIMARY KEY (id);
 B   ALTER TABLE ONLY public.log_acesso DROP CONSTRAINT pk_log_acesso;
       public         postgres    false    474            �           2606    18420    log_baixa_ftp pk_log_baixa_ftp 
   CONSTRAINT     \   ALTER TABLE ONLY public.log_baixa_ftp
    ADD CONSTRAINT pk_log_baixa_ftp PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.log_baixa_ftp DROP CONSTRAINT pk_log_baixa_ftp;
       public         postgres    false    476            �           2606    18422 ,   log_erro_processador pk_log_erro_processador 
   CONSTRAINT     j   ALTER TABLE ONLY public.log_erro_processador
    ADD CONSTRAINT pk_log_erro_processador PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.log_erro_processador DROP CONSTRAINT pk_log_erro_processador;
       public         postgres    false    480            �           2606    18424    loja pk_loja 
   CONSTRAINT     J   ALTER TABLE ONLY public.loja
    ADD CONSTRAINT pk_loja PRIMARY KEY (id);
 6   ALTER TABLE ONLY public.loja DROP CONSTRAINT pk_loja;
       public         postgres    false    482            �           2606    18426    lote_favorecido pk_lote 
   CONSTRAINT     U   ALTER TABLE ONLY public.lote_favorecido
    ADD CONSTRAINT pk_lote PRIMARY KEY (id);
 A   ALTER TABLE ONLY public.lote_favorecido DROP CONSTRAINT pk_lote;
       public         postgres    false    490            �           2606    18428    lote_boleto pk_lote_boleto 
   CONSTRAINT     X   ALTER TABLE ONLY public.lote_boleto
    ADD CONSTRAINT pk_lote_boleto PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.lote_boleto DROP CONSTRAINT pk_lote_boleto;
       public         postgres    false    486            �           2606    18430    lote_carne pk_lote_carne 
   CONSTRAINT     V   ALTER TABLE ONLY public.lote_carne
    ADD CONSTRAINT pk_lote_carne PRIMARY KEY (id);
 B   ALTER TABLE ONLY public.lote_carne DROP CONSTRAINT pk_lote_carne;
       public         postgres    false    488            �           2606    18432    lote_pag_aux pk_lote_pag_aux 
   CONSTRAINT     Z   ALTER TABLE ONLY public.lote_pag_aux
    ADD CONSTRAINT pk_lote_pag_aux PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.lote_pag_aux DROP CONSTRAINT pk_lote_pag_aux;
       public         postgres    false    493            �           2606    18434 $   mensagem_arquivo pk_mensagem_arquivo 
   CONSTRAINT     b   ALTER TABLE ONLY public.mensagem_arquivo
    ADD CONSTRAINT pk_mensagem_arquivo PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.mensagem_arquivo DROP CONSTRAINT pk_mensagem_arquivo;
       public         postgres    false    495            �           2606    18436 8   movimento_remessa_cobranca pk_movimento_remessa_cobranca 
   CONSTRAINT     v   ALTER TABLE ONLY public.movimento_remessa_cobranca
    ADD CONSTRAINT pk_movimento_remessa_cobranca PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.movimento_remessa_cobranca DROP CONSTRAINT pk_movimento_remessa_cobranca;
       public         postgres    false    505            �           2606    18438 8   movimento_retorno_cobranca pk_movimento_retorno_cobranca 
   CONSTRAINT     v   ALTER TABLE ONLY public.movimento_retorno_cobranca
    ADD CONSTRAINT pk_movimento_retorno_cobranca PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.movimento_retorno_cobranca DROP CONSTRAINT pk_movimento_retorno_cobranca;
       public         postgres    false    507            �           2606    18440 /   notificacao_pagamento pk_notificacoes_pagamento 
   CONSTRAINT     m   ALTER TABLE ONLY public.notificacao_pagamento
    ADD CONSTRAINT pk_notificacoes_pagamento PRIMARY KEY (id);
 Y   ALTER TABLE ONLY public.notificacao_pagamento DROP CONSTRAINT pk_notificacoes_pagamento;
       public         postgres    false    513            �           2606    18442    numerario pk_numerario 
   CONSTRAINT     T   ALTER TABLE ONLY public.numerario
    ADD CONSTRAINT pk_numerario PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.numerario DROP CONSTRAINT pk_numerario;
       public         postgres    false    517            �           2606    18444 .   numerario_duplicidade pk_numerario_duplicidade 
   CONSTRAINT     l   ALTER TABLE ONLY public.numerario_duplicidade
    ADD CONSTRAINT pk_numerario_duplicidade PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.numerario_duplicidade DROP CONSTRAINT pk_numerario_duplicidade;
       public         postgres    false    518            �           2606    18446    ocorrencia pk_ocorrencia 
   CONSTRAINT     V   ALTER TABLE ONLY public.ocorrencia
    ADD CONSTRAINT pk_ocorrencia PRIMARY KEY (id);
 B   ALTER TABLE ONLY public.ocorrencia DROP CONSTRAINT pk_ocorrencia;
       public         postgres    false    522            �           2606    18448 M   ocorrencia_retorno_cobranca_detalhe pk_ocorrencia_retorno_cobranca_detalhe_id 
   CONSTRAINT     �   ALTER TABLE ONLY public.ocorrencia_retorno_cobranca_detalhe
    ADD CONSTRAINT pk_ocorrencia_retorno_cobranca_detalhe_id PRIMARY KEY (id);
 w   ALTER TABLE ONLY public.ocorrencia_retorno_cobranca_detalhe DROP CONSTRAINT pk_ocorrencia_retorno_cobranca_detalhe_id;
       public         postgres    false    527            �           2606    18450    pagamento pk_pagamento 
   CONSTRAINT     T   ALTER TABLE ONLY public.pagamento
    ADD CONSTRAINT pk_pagamento PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.pagamento DROP CONSTRAINT pk_pagamento;
       public         postgres    false    531            �           2606    18452 &   pagamento_arquivo pk_pagamento_arquivo 
   CONSTRAINT     d   ALTER TABLE ONLY public.pagamento_arquivo
    ADD CONSTRAINT pk_pagamento_arquivo PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.pagamento_arquivo DROP CONSTRAINT pk_pagamento_arquivo;
       public         postgres    false    532            �           2606    18454 "   pagamento_aviso pk_pagamento_aviso 
   CONSTRAINT     `   ALTER TABLE ONLY public.pagamento_aviso
    ADD CONSTRAINT pk_pagamento_aviso PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.pagamento_aviso DROP CONSTRAINT pk_pagamento_aviso;
       public         postgres    false    535            ]           2606    18456 *   historico_pagamento pk_pagamento_historico 
   CONSTRAINT     h   ALTER TABLE ONLY public.historico_pagamento
    ADD CONSTRAINT pk_pagamento_historico PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.historico_pagamento DROP CONSTRAINT pk_pagamento_historico;
       public         postgres    false    430            �           2606    18458 .   parametro_autorizacao pk_parametro_autorizacao 
   CONSTRAINT     l   ALTER TABLE ONLY public.parametro_autorizacao
    ADD CONSTRAINT pk_parametro_autorizacao PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.parametro_autorizacao DROP CONSTRAINT pk_parametro_autorizacao;
       public         postgres    false    539            r           2606    35398 ^   pre_controle_execucao_conciliacao_bancaria_v2 pk_pre_controle_execucao_conciliacao_bancaria_v2 
   CONSTRAINT     �   ALTER TABLE ONLY public.pre_controle_execucao_conciliacao_bancaria_v2
    ADD CONSTRAINT pk_pre_controle_execucao_conciliacao_bancaria_v2 PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.pre_controle_execucao_conciliacao_bancaria_v2 DROP CONSTRAINT pk_pre_controle_execucao_conciliacao_bancaria_v2;
       public         bv_postgres    false    667            �           2606    18460 :   recolhimento_transportadora pk_recolhimento_transportadora 
   CONSTRAINT     x   ALTER TABLE ONLY public.recolhimento_transportadora
    ADD CONSTRAINT pk_recolhimento_transportadora PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.recolhimento_transportadora DROP CONSTRAINT pk_recolhimento_transportadora;
       public         postgres    false    558            �           2606    18462 J   recolhimento_transportadora_analise pk_recolhimento_transportadora_analise 
   CONSTRAINT     �   ALTER TABLE ONLY public.recolhimento_transportadora_analise
    ADD CONSTRAINT pk_recolhimento_transportadora_analise PRIMARY KEY (id);
 t   ALTER TABLE ONLY public.recolhimento_transportadora_analise DROP CONSTRAINT pk_recolhimento_transportadora_analise;
       public         postgres    false    559            �           2606    18464 R   recolhimento_transportadora_duplicidade pk_recolhimento_transportadora_duplicidade 
   CONSTRAINT     �   ALTER TABLE ONLY public.recolhimento_transportadora_duplicidade
    ADD CONSTRAINT pk_recolhimento_transportadora_duplicidade PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.recolhimento_transportadora_duplicidade DROP CONSTRAINT pk_recolhimento_transportadora_duplicidade;
       public         postgres    false    561            �           2606    18466    release_note pk_release_note 
   CONSTRAINT     Z   ALTER TABLE ONLY public.release_note
    ADD CONSTRAINT pk_release_note PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.release_note DROP CONSTRAINT pk_release_note;
       public         postgres    false    565            �           2606    18468 <   resumo_processamento_arquivo pk_resumo_processamento_arquivo 
   CONSTRAINT     z   ALTER TABLE ONLY public.resumo_processamento_arquivo
    ADD CONSTRAINT pk_resumo_processamento_arquivo PRIMARY KEY (id);
 f   ALTER TABLE ONLY public.resumo_processamento_arquivo DROP CONSTRAINT pk_resumo_processamento_arquivo;
       public         postgres    false    567            �           2606    18470    sacado pk_sacado 
   CONSTRAINT     N   ALTER TABLE ONLY public.sacado
    ADD CONSTRAINT pk_sacado PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.sacado DROP CONSTRAINT pk_sacado;
       public         postgres    false    570            �           2606    18472     saldo_convenio pk_saldo_convenio 
   CONSTRAINT     ^   ALTER TABLE ONLY public.saldo_convenio
    ADD CONSTRAINT pk_saldo_convenio PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.saldo_convenio DROP CONSTRAINT pk_saldo_convenio;
       public         postgres    false    572            �           2606    18474 ,   status_monitoramento pk_status_monitoramento 
   CONSTRAINT     j   ALTER TABLE ONLY public.status_monitoramento
    ADD CONSTRAINT pk_status_monitoramento PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.status_monitoramento DROP CONSTRAINT pk_status_monitoramento;
       public         postgres    false    575                        2606    18476 &   tarifa_divergente pk_tarifa_divergente 
   CONSTRAINT     d   ALTER TABLE ONLY public.tarifa_divergente
    ADD CONSTRAINT pk_tarifa_divergente PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.tarifa_divergente DROP CONSTRAINT pk_tarifa_divergente;
       public         postgres    false    577                       2606    18478    tarifa_origem pk_tarifa_origem 
   CONSTRAINT     \   ALTER TABLE ONLY public.tarifa_origem
    ADD CONSTRAINT pk_tarifa_origem PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.tarifa_origem DROP CONSTRAINT pk_tarifa_origem;
       public         postgres    false    581            	           2606    18480 *   tarifa_sem_contrato pk_tarifa_sem_contrato 
   CONSTRAINT     h   ALTER TABLE ONLY public.tarifa_sem_contrato
    ADD CONSTRAINT pk_tarifa_sem_contrato PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.tarifa_sem_contrato DROP CONSTRAINT pk_tarifa_sem_contrato;
       public         postgres    false    583                       2606    18482 %   tipo_compromisso pk_tipo_commpromisso 
   CONSTRAINT     c   ALTER TABLE ONLY public.tipo_compromisso
    ADD CONSTRAINT pk_tipo_commpromisso PRIMARY KEY (id);
 O   ALTER TABLE ONLY public.tipo_compromisso DROP CONSTRAINT pk_tipo_commpromisso;
       public         postgres    false    588                       2606    18484 $   tipo_conta_pagar pk_tipo_conta_pagar 
   CONSTRAINT     b   ALTER TABLE ONLY public.tipo_conta_pagar
    ADD CONSTRAINT pk_tipo_conta_pagar PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.tipo_conta_pagar DROP CONSTRAINT pk_tipo_conta_pagar;
       public         postgres    false    590                       2606    18486 :   tipo_operacao_cesta_servico pk_tipo_operacao_cesta_servico 
   CONSTRAINT     x   ALTER TABLE ONLY public.tipo_operacao_cesta_servico
    ADD CONSTRAINT pk_tipo_operacao_cesta_servico PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.tipo_operacao_cesta_servico DROP CONSTRAINT pk_tipo_operacao_cesta_servico;
       public         postgres    false    597                       2606    18488 2   tipo_operacao_numerario pk_tipo_operacao_numerario 
   CONSTRAINT     p   ALTER TABLE ONLY public.tipo_operacao_numerario
    ADD CONSTRAINT pk_tipo_operacao_numerario PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.tipo_operacao_numerario DROP CONSTRAINT pk_tipo_operacao_numerario;
       public         postgres    false    598                       2606    18490    tipo_servico pk_tipo_servico 
   CONSTRAINT     Z   ALTER TABLE ONLY public.tipo_servico
    ADD CONSTRAINT pk_tipo_servico PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.tipo_servico DROP CONSTRAINT pk_tipo_servico;
       public         postgres    false    601                       2606    18492    titulo pk_titulo 
   CONSTRAINT     N   ALTER TABLE ONLY public.titulo
    ADD CONSTRAINT pk_titulo PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.titulo DROP CONSTRAINT pk_titulo;
       public         postgres    false    602            ,           2606    18494     titulo_retorno pk_titulo_retorno 
   CONSTRAINT     ^   ALTER TABLE ONLY public.titulo_retorno
    ADD CONSTRAINT pk_titulo_retorno PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.titulo_retorno DROP CONSTRAINT pk_titulo_retorno;
       public         postgres    false    614            0           2606    18496    titulo_serie pk_titulo_serie 
   CONSTRAINT     Z   ALTER TABLE ONLY public.titulo_serie
    ADD CONSTRAINT pk_titulo_serie PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.titulo_serie DROP CONSTRAINT pk_titulo_serie;
       public         postgres    false    617            6           2606    18498 >   tramite_processamento_arquivo pk_tramite_processamento_arquivo 
   CONSTRAINT     |   ALTER TABLE ONLY public.tramite_processamento_arquivo
    ADD CONSTRAINT pk_tramite_processamento_arquivo PRIMARY KEY (id);
 h   ALTER TABLE ONLY public.tramite_processamento_arquivo DROP CONSTRAINT pk_tramite_processamento_arquivo;
       public         postgres    false    621            8           2606    18500     transportadora pk_transportadora 
   CONSTRAINT     ^   ALTER TABLE ONLY public.transportadora
    ADD CONSTRAINT pk_transportadora PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.transportadora DROP CONSTRAINT pk_transportadora;
       public         postgres    false    622            :           2606    18502    tributo_gps pk_tributo_gps 
   CONSTRAINT     X   ALTER TABLE ONLY public.tributo_gps
    ADD CONSTRAINT pk_tributo_gps PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.tributo_gps DROP CONSTRAINT pk_tributo_gps;
       public         postgres    false    624            <           2606    18504 4   tributo_sem_codigo_barra pk_tributo_sem_codigo_barra 
   CONSTRAINT     r   ALTER TABLE ONLY public.tributo_sem_codigo_barra
    ADD CONSTRAINT pk_tributo_sem_codigo_barra PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.tributo_sem_codigo_barra DROP CONSTRAINT pk_tributo_sem_codigo_barra;
       public         postgres    false    626            G           2606    18506 (   usuario_favorecido pk_usuario_favorecido 
   CONSTRAINT     f   ALTER TABLE ONLY public.usuario_favorecido
    ADD CONSTRAINT pk_usuario_favorecido PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.usuario_favorecido DROP CONSTRAINT pk_usuario_favorecido;
       public         postgres    false    632            M           2606    18508     usuario_sacado pk_usuario_sacado 
   CONSTRAINT     ^   ALTER TABLE ONLY public.usuario_sacado
    ADD CONSTRAINT pk_usuario_sacado PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.usuario_sacado DROP CONSTRAINT pk_usuario_sacado;
       public         postgres    false    638            Q           2606    18510 (   verificacao_status pk_verificacao_status 
   CONSTRAINT     f   ALTER TABLE ONLY public.verificacao_status
    ADD CONSTRAINT pk_verificacao_status PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.verificacao_status DROP CONSTRAINT pk_verificacao_status;
       public         postgres    false    642            v           2606    35835 0   vinculo_categoria_cash pk_vinculo_categoria_cash 
   CONSTRAINT     n   ALTER TABLE ONLY public.vinculo_categoria_cash
    ADD CONSTRAINT pk_vinculo_categoria_cash PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.vinculo_categoria_cash DROP CONSTRAINT pk_vinculo_categoria_cash;
       public         postgres    false    670            [           2606    18512 <   vinculo_conciliacao_cobranca pk_vinculo_conciliacao_cobranca 
   CONSTRAINT     z   ALTER TABLE ONLY public.vinculo_conciliacao_cobranca
    ADD CONSTRAINT pk_vinculo_conciliacao_cobranca PRIMARY KEY (id);
 f   ALTER TABLE ONLY public.vinculo_conciliacao_cobranca DROP CONSTRAINT pk_vinculo_conciliacao_cobranca;
       public         postgres    false    648            a           2606    18514 <   vinculo_ocorrencia_pagamento pk_vinculo_ocorrencia_pagamento 
   CONSTRAINT     z   ALTER TABLE ONLY public.vinculo_ocorrencia_pagamento
    ADD CONSTRAINT pk_vinculo_ocorrencia_pagamento PRIMARY KEY (id);
 f   ALTER TABLE ONLY public.vinculo_ocorrencia_pagamento DROP CONSTRAINT pk_vinculo_ocorrencia_pagamento;
       public         postgres    false    653            f           2606    18516     vinculo_sacado pk_vinculo_sacado 
   CONSTRAINT     ^   ALTER TABLE ONLY public.vinculo_sacado
    ADD CONSTRAINT pk_vinculo_sacado PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.vinculo_sacado DROP CONSTRAINT pk_vinculo_sacado;
       public         postgres    false    657            j           2606    18518 J   vinculo_tarifa_origem_tipo_operacao pk_vinculo_tarifa_origem_tipo_operacao 
   CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_tarifa_origem_tipo_operacao
    ADD CONSTRAINT pk_vinculo_tarifa_origem_tipo_operacao PRIMARY KEY (id);
 t   ALTER TABLE ONLY public.vinculo_tarifa_origem_tipo_operacao DROP CONSTRAINT pk_vinculo_tarifa_origem_tipo_operacao;
       public         postgres    false    659            �           2606    18520 0   processamento_otimiza processamento_otimiza_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.processamento_otimiza
    ADD CONSTRAINT processamento_otimiza_pkey PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.processamento_otimiza DROP CONSTRAINT processamento_otimiza_pkey;
       public         postgres    false    551            �           2606    18522 &   produto_bancario produto_bancario_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.produto_bancario
    ADD CONSTRAINT produto_bancario_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.produto_bancario DROP CONSTRAINT produto_bancario_pkey;
       public         postgres    false    553            �           2606    18524 0   receita_processamento receita_processamento_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.receita_processamento
    ADD CONSTRAINT receita_processamento_pkey PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.receita_processamento DROP CONSTRAINT receita_processamento_pkey;
       public         postgres    false    556            �           2606    18526 "   retorno_debito retorno_debito_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.retorno_debito
    ADD CONSTRAINT retorno_debito_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.retorno_debito DROP CONSTRAINT retorno_debito_pkey;
       public         postgres    false    568            n           2606    35000 ,   saldo_transito_cash saldo_transito_cash_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.saldo_transito_cash
    ADD CONSTRAINT saldo_transito_cash_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.saldo_transito_cash DROP CONSTRAINT saldo_transito_cash_pkey;
       public         postgres    false    663            �           2606    18528     schema_version schema_version_pk 
   CONSTRAINT     j   ALTER TABLE ONLY public.schema_version
    ADD CONSTRAINT schema_version_pk PRIMARY KEY (installed_rank);
 J   ALTER TABLE ONLY public.schema_version DROP CONSTRAINT schema_version_pk;
       public         postgres    false    574                       2606    18530 5   tarifa_divergente tarifa_divergente_lancamento_id_key 
   CONSTRAINT     y   ALTER TABLE ONLY public.tarifa_divergente
    ADD CONSTRAINT tarifa_divergente_lancamento_id_key UNIQUE (lancamento_id);
 _   ALTER TABLE ONLY public.tarifa_divergente DROP CONSTRAINT tarifa_divergente_lancamento_id_key;
       public         postgres    false    577            A           2606    18532    usuario tbusr_usrlgn_key 
   CONSTRAINT     T   ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT tbusr_usrlgn_key UNIQUE (login);
 B   ALTER TABLE ONLY public.usuario DROP CONSTRAINT tbusr_usrlgn_key;
       public         postgres    false    628                       2606    18534 8   tipo_categoria_lancamento tipo_categoria_lancamento_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.tipo_categoria_lancamento
    ADD CONSTRAINT tipo_categoria_lancamento_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.tipo_categoria_lancamento DROP CONSTRAINT tipo_categoria_lancamento_pkey;
       public         postgres    false    586                       2606    18536 ;   tipo_contrato_bancario tipo_contrato_bancario_descricao_key 
   CONSTRAINT     {   ALTER TABLE ONLY public.tipo_contrato_bancario
    ADD CONSTRAINT tipo_contrato_bancario_descricao_key UNIQUE (descricao);
 e   ALTER TABLE ONLY public.tipo_contrato_bancario DROP CONSTRAINT tipo_contrato_bancario_descricao_key;
       public         postgres    false    592                       2606    18538 2   tipo_contrato_bancario tipo_contrato_bancario_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.tipo_contrato_bancario
    ADD CONSTRAINT tipo_contrato_bancario_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.tipo_contrato_bancario DROP CONSTRAINT tipo_contrato_bancario_pkey;
       public         postgres    false    592            "           2606    18540    titulo_aud titulo_aud_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY public.titulo_aud
    ADD CONSTRAINT titulo_aud_pkey PRIMARY KEY (id, rev);
 D   ALTER TABLE ONLY public.titulo_aud DROP CONSTRAINT titulo_aud_pkey;
       public         postgres    false    603    603            $           2606    18542 $   titulo_auxiliar titulo_auxiliar_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.titulo_auxiliar
    ADD CONSTRAINT titulo_auxiliar_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.titulo_auxiliar DROP CONSTRAINT titulo_auxiliar_pkey;
       public         postgres    false    605            (           2606    18544 ,   titulo_dda_duplicado titulo_dda_duplicado_pk 
   CONSTRAINT     j   ALTER TABLE ONLY public.titulo_dda_duplicado
    ADD CONSTRAINT titulo_dda_duplicado_pk PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.titulo_dda_duplicado DROP CONSTRAINT titulo_dda_duplicado_pk;
       public         postgres    false    608            &           2606    18546    titulo_dda titulo_dda_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.titulo_dda
    ADD CONSTRAINT titulo_dda_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.titulo_dda DROP CONSTRAINT titulo_dda_pkey;
       public         postgres    false    607            *           2606    18548 $   titulo_mensagem titulo_mensagem_pkey 
   CONSTRAINT     }   ALTER TABLE ONLY public.titulo_mensagem
    ADD CONSTRAINT titulo_mensagem_pkey PRIMARY KEY (titulo_id, mensagem_titulo_id);
 N   ALTER TABLE ONLY public.titulo_mensagem DROP CONSTRAINT titulo_mensagem_pkey;
       public         postgres    false    612    612            2           2606    18550    token token_chave_key 
   CONSTRAINT     Q   ALTER TABLE ONLY public.token
    ADD CONSTRAINT token_chave_key UNIQUE (chave);
 ?   ALTER TABLE ONLY public.token DROP CONSTRAINT token_chave_key;
       public         postgres    false    618            4           2606    18552    token token_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.token
    ADD CONSTRAINT token_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.token DROP CONSTRAINT token_pkey;
       public         postgres    false    618            E           2606    18554 #   usuario_empresas uk_contas_empresas 
   CONSTRAINT     p   ALTER TABLE ONLY public.usuario_empresas
    ADD CONSTRAINT uk_contas_empresas UNIQUE (usuario_id, empresa_id);
 M   ALTER TABLE ONLY public.usuario_empresas DROP CONSTRAINT uk_contas_empresas;
       public         postgres    false    631    631            I           2606    18556    usuario_lojas uk_contas_lojas 
   CONSTRAINT     g   ALTER TABLE ONLY public.usuario_lojas
    ADD CONSTRAINT uk_contas_lojas UNIQUE (usuario_id, loja_id);
 G   ALTER TABLE ONLY public.usuario_lojas DROP CONSTRAINT uk_contas_lojas;
       public         postgres    false    635    635            K           2606    18558    usuario_perfil uk_contas_perfil 
   CONSTRAINT     k   ALTER TABLE ONLY public.usuario_perfil
    ADD CONSTRAINT uk_contas_perfil UNIQUE (usuario_id, perfil_id);
 I   ALTER TABLE ONLY public.usuario_perfil DROP CONSTRAINT uk_contas_perfil;
       public         postgres    false    636    636            C           2606    18560 !   usuario_contas uk_contas_usuarios 
   CONSTRAINT     l   ALTER TABLE ONLY public.usuario_contas
    ADD CONSTRAINT uk_contas_usuarios UNIQUE (usuario_id, conta_id);
 K   ALTER TABLE ONLY public.usuario_contas DROP CONSTRAINT uk_contas_usuarios;
       public         postgres    false    630    630            �           2606    18562    controle_card uk_controle_card 
   CONSTRAINT     k   ALTER TABLE ONLY public.controle_card
    ADD CONSTRAINT uk_controle_card UNIQUE (chave_card, usuario_id);
 H   ALTER TABLE ONLY public.controle_card DROP CONSTRAINT uk_controle_card;
       public         postgres    false    317    317            �           2606    18564 ,   controle_nsa_remessa uk_nsa_convenio_empresa 
   CONSTRAINT        ALTER TABLE ONLY public.controle_nsa_remessa
    ADD CONSTRAINT uk_nsa_convenio_empresa UNIQUE (convenio_id, empresa_id, nsa);
 V   ALTER TABLE ONLY public.controle_nsa_remessa DROP CONSTRAINT uk_nsa_convenio_empresa;
       public         postgres    false    326    326    326            �           2606    18566    numerario uk_numerario_chave 
   CONSTRAINT     X   ALTER TABLE ONLY public.numerario
    ADD CONSTRAINT uk_numerario_chave UNIQUE (chave);
 F   ALTER TABLE ONLY public.numerario DROP CONSTRAINT uk_numerario_chave;
       public         postgres    false    517            �           2606    18568    chave_pix unique_chave_pix 
   CONSTRAINT     {   ALTER TABLE ONLY public.chave_pix
    ADD CONSTRAINT unique_chave_pix UNIQUE (favorecido_id, empresa_id, grupo_id, chave);
 D   ALTER TABLE ONLY public.chave_pix DROP CONSTRAINT unique_chave_pix;
       public         postgres    false    265    265    265    265            W           2606    18570 &   vinculacao_cnpj_empresa unique_cnpj_pk 
   CONSTRAINT     �   ALTER TABLE ONLY public.vinculacao_cnpj_empresa
    ADD CONSTRAINT unique_cnpj_pk UNIQUE (cnpj, empresa_id, conta_id, convenio_id);
 P   ALTER TABLE ONLY public.vinculacao_cnpj_empresa DROP CONSTRAINT unique_cnpj_pk;
       public         postgres    false    646    646    646    646            ]           2606    18572 2   vinculo_descricao_ocorrencia_categoria unique_vdoc 
   CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_descricao_ocorrencia_categoria
    ADD CONSTRAINT unique_vdoc UNIQUE (ocorrencia_cobranca_id, categoria_lancamento_id, banco_id);
 \   ALTER TABLE ONLY public.vinculo_descricao_ocorrencia_categoria DROP CONSTRAINT unique_vdoc;
       public         postgres    false    651    651    651            O           2606    18574    venda venda_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.venda
    ADD CONSTRAINT venda_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.venda DROP CONSTRAINT venda_pkey;
       public         postgres    false    640            U           2606    18576 D   vinculacao_automatica_categoria vinculacao_automatica_categoria_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.vinculacao_automatica_categoria
    ADD CONSTRAINT vinculacao_automatica_categoria_pkey PRIMARY KEY (id);
 n   ALTER TABLE ONLY public.vinculacao_automatica_categoria DROP CONSTRAINT vinculacao_automatica_categoria_pkey;
       public         postgres    false    644            Y           2606    18578 4   vinculacao_cnpj_empresa vinculacao_cnpj_empresa_pkey 
   CONSTRAINT     r   ALTER TABLE ONLY public.vinculacao_cnpj_empresa
    ADD CONSTRAINT vinculacao_cnpj_empresa_pkey PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.vinculacao_cnpj_empresa DROP CONSTRAINT vinculacao_cnpj_empresa_pkey;
       public         postgres    false    646            _           2606    18580 R   vinculo_descricao_ocorrencia_categoria vinculo_descricao_ocorrencia_categoria_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_descricao_ocorrencia_categoria
    ADD CONSTRAINT vinculo_descricao_ocorrencia_categoria_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.vinculo_descricao_ocorrencia_categoria DROP CONSTRAINT vinculo_descricao_ocorrencia_categoria_pkey;
       public         postgres    false    651            d           2606    18582 >   vinculo_pagamento_lancamento vinculo_pagamento_lancamento_pkey 
   CONSTRAINT     |   ALTER TABLE ONLY public.vinculo_pagamento_lancamento
    ADD CONSTRAINT vinculo_pagamento_lancamento_pkey PRIMARY KEY (id);
 h   ALTER TABLE ONLY public.vinculo_pagamento_lancamento DROP CONSTRAINT vinculo_pagamento_lancamento_pkey;
       public         postgres    false    654            }           1259    18583    auditoria_suite_idx_data    INDEX     ^   CREATE INDEX auditoria_suite_idx_data ON public.auditoria_suite USING btree (data_auditoria);
 ,   DROP INDEX public.auditoria_suite_idx_data;
       public         postgres    false    238            ~           1259    18584 #   auditoria_suite_idx_data_ocorrencia    INDEX     j   CREATE INDEX auditoria_suite_idx_data_ocorrencia ON public.auditoria_suite USING btree (data_ocorrencia);
 7   DROP INDEX public.auditoria_suite_idx_data_ocorrencia;
       public         postgres    false    238            �           1259    18585    contrato_empresa_idx    INDEX     O   CREATE INDEX contrato_empresa_idx ON public.contrato USING btree (empresa_id);
 (   DROP INDEX public.contrato_empresa_idx;
       public         postgres    false    307            �           1259    18586    contrato_id_idx    INDEX     B   CREATE INDEX contrato_id_idx ON public.contrato USING btree (id);
 #   DROP INDEX public.contrato_id_idx;
       public         postgres    false    307            �           1259    18587    divergencia_tarifa_id_idx    INDEX     U   CREATE INDEX divergencia_tarifa_id_idx ON public.tarifa_divergente USING btree (id);
 -   DROP INDEX public.divergencia_tarifa_id_idx;
       public         postgres    false    577            �           1259    18588 !   divergencia_tarifa_lancamento_idx    INDEX     h   CREATE INDEX divergencia_tarifa_lancamento_idx ON public.tarifa_divergente USING btree (lancamento_id);
 5   DROP INDEX public.divergencia_tarifa_lancamento_idx;
       public         postgres    false    577            8           1259    18589 '   grafico_arrecadacao_forma_pagamento_idx    INDEX     �   CREATE INDEX grafico_arrecadacao_forma_pagamento_idx ON public.grafico_arrecadacao_forma_pagamento USING btree (convenio_id, forma_pagamento_arrecadacao_id);
 ;   DROP INDEX public.grafico_arrecadacao_forma_pagamento_idx;
       public         postgres    false    397    397            I           1259    18590    grupo_pagamento_id_idx    INDEX     P   CREATE INDEX grupo_pagamento_id_idx ON public.grupo_pagamento USING btree (id);
 *   DROP INDEX public.grupo_pagamento_id_idx;
       public         postgres    false    413            J           1259    18591    grupo_pagamento_pagamento_idx    INDEX     a   CREATE INDEX grupo_pagamento_pagamento_idx ON public.grupo_pagamento USING btree (pagamento_id);
 1   DROP INDEX public.grupo_pagamento_pagamento_idx;
       public         postgres    false    413            r           1259    18592    idx_arrecadacao    INDEX     M   CREATE INDEX idx_arrecadacao ON public.arrecadacao USING btree (empresa_id);
 #   DROP INDEX public.idx_arrecadacao;
       public         postgres    false    227            s           1259    18593 "   idx_arrecadacao_arquivo_processado    INDEX     h   CREATE INDEX idx_arrecadacao_arquivo_processado ON public.arrecadacao USING btree (arquivo_processado);
 6   DROP INDEX public.idx_arrecadacao_arquivo_processado;
       public         postgres    false    227            t           1259    18594 <   idx_arrecadacao_data_banco_id_forma_pagamento_arrecadacao_id    INDEX     �   CREATE INDEX idx_arrecadacao_data_banco_id_forma_pagamento_arrecadacao_id ON public.arrecadacao USING btree (data, banco_id, forma_pagamento_arrecadacao_id);
 P   DROP INDEX public.idx_arrecadacao_data_banco_id_forma_pagamento_arrecadacao_id;
       public         postgres    false    227    227    227            w           1259    18595 4   idx_arrecadacao_debito_automatico_arquivo_processado    INDEX     �   CREATE INDEX idx_arrecadacao_debito_automatico_arquivo_processado ON public.arrecadacao_debito_automatico USING btree (arquivo_processado);
 H   DROP INDEX public.idx_arrecadacao_debito_automatico_arquivo_processado;
       public         postgres    false    229            x           1259    18596 ?   idx_arrecadacao_debito_automatico_data_banco_id_forma_pagamento    INDEX     �   CREATE INDEX idx_arrecadacao_debito_automatico_data_banco_id_forma_pagamento ON public.arrecadacao_debito_automatico USING btree (data, banco_id, forma_pagamento_arrecadacao_id);
 S   DROP INDEX public.idx_arrecadacao_debito_automatico_data_banco_id_forma_pagamento;
       public         postgres    false    229    229    229            �           1259    18597    idx_conciliacao_cobranca_id    INDEX     y   CREATE INDEX idx_conciliacao_cobranca_id ON public.conciliacao_cobranca USING btree (grupo_titulo_id, chave_lancamento);
 /   DROP INDEX public.idx_conciliacao_cobranca_id;
       public         postgres    false    284    284            �           1259    18598    idx_conciliacao_lancamento_id    INDEX     �   CREATE UNIQUE INDEX idx_conciliacao_lancamento_id ON public.conciliacao_lancamento USING btree (grupo_lancamento_id, chave_lancamento);
 1   DROP INDEX public.idx_conciliacao_lancamento_id;
       public         postgres    false    291    291            �           1259    18599    idx_conciliacao_pagamento    INDEX     �   CREATE UNIQUE INDEX idx_conciliacao_pagamento ON public.conciliacao_pagamento USING btree (grupo_pagamento_id, chave_lancamento);
 -   DROP INDEX public.idx_conciliacao_pagamento;
       public         postgres    false    293    293            �           1259    18600    idx_convenio_configuracao    INDEX     i   CREATE UNIQUE INDEX idx_convenio_configuracao ON public.convenio_configuracao USING btree (convenio_id);
 -   DROP INDEX public.idx_convenio_configuracao;
       public         postgres    false    336            A           1259    18601    idx_grupo_lancamento_conta    INDEX     [   CREATE INDEX idx_grupo_lancamento_conta ON public.grupo_lancamento USING btree (conta_id);
 .   DROP INDEX public.idx_grupo_lancamento_conta;
       public         postgres    false    407            B           1259    18602    idx_grupo_lancamento_id    INDEX     Y   CREATE UNIQUE INDEX idx_grupo_lancamento_id ON public.grupo_lancamento USING btree (id);
 +   DROP INDEX public.idx_grupo_lancamento_id;
       public         postgres    false    407            Q           1259    18603    idx_grupo_titulo_convenio    INDEX     Y   CREATE INDEX idx_grupo_titulo_convenio ON public.grupo_titulo USING btree (convenio_id);
 -   DROP INDEX public.idx_grupo_titulo_convenio;
       public         postgres    false    418                       1259    18604    idx_tarifa_sem_contrato_empresa    INDEX     e   CREATE INDEX idx_tarifa_sem_contrato_empresa ON public.tarifa_sem_contrato USING btree (empresa_id);
 3   DROP INDEX public.idx_tarifa_sem_contrato_empresa;
       public         postgres    false    583            -           1259    18605    idx_titulo_serie_empresa    INDEX     W   CREATE INDEX idx_titulo_serie_empresa ON public.titulo_serie USING btree (empresa_id);
 ,   DROP INDEX public.idx_titulo_serie_empresa;
       public         postgres    false    617            .           1259    18606    idx_titulo_serie_id    INDEX     Q   CREATE UNIQUE INDEX idx_titulo_serie_id ON public.titulo_serie USING btree (id);
 '   DROP INDEX public.idx_titulo_serie_id;
       public         postgres    false    617            '           1259    18607    idx_uk_conta    INDEX     }   CREATE UNIQUE INDEX idx_uk_conta ON public.favorecido_conta USING btree (favorecido_id, banco_id, agencia, conta, dv_conta);
     DROP INDEX public.idx_uk_conta;
       public         postgres    false    380    380    380    380    380            ?           1259    18608    idx_usuario_cpf    INDEX     I   CREATE UNIQUE INDEX idx_usuario_cpf ON public.usuario USING btree (cpf);
 #   DROP INDEX public.idx_usuario_cpf;
       public         postgres    false    628            g           1259    18609 -   idx_vinculo_tarifa_origem_tipo_operacao_banco    INDEX     �   CREATE INDEX idx_vinculo_tarifa_origem_tipo_operacao_banco ON public.vinculo_tarifa_origem_tipo_operacao USING btree (banco_id);
 A   DROP INDEX public.idx_vinculo_tarifa_origem_tipo_operacao_banco;
       public         postgres    false    659            h           1259    18610 *   idx_vinculo_tarifa_origem_tipo_operacao_id    INDEX        CREATE UNIQUE INDEX idx_vinculo_tarifa_origem_tipo_operacao_id ON public.vinculo_tarifa_origem_tipo_operacao USING btree (id);
 >   DROP INDEX public.idx_vinculo_tarifa_origem_tipo_operacao_id;
       public         postgres    false    659            p           1259    18611 #   item_contrato_cobranca_contrato_idx    INDEX     m   CREATE INDEX item_contrato_cobranca_contrato_idx ON public.item_contrato_cobranca USING btree (contrato_id);
 7   DROP INDEX public.item_contrato_cobranca_contrato_idx;
       public         postgres    false    452            q           1259    18612    item_contrato_cobranca_id_idx    INDEX     ^   CREATE INDEX item_contrato_cobranca_id_idx ON public.item_contrato_cobranca USING btree (id);
 1   DROP INDEX public.item_contrato_cobranca_id_idx;
       public         postgres    false    452            v           1259    18613 $   item_contrato_pagamento_contrato_idx    INDEX     o   CREATE INDEX item_contrato_pagamento_contrato_idx ON public.item_contrato_pagamento USING btree (contrato_id);
 8   DROP INDEX public.item_contrato_pagamento_contrato_idx;
       public         postgres    false    457            w           1259    18614    item_contrato_pagamento_id_idx    INDEX     `   CREATE INDEX item_contrato_pagamento_id_idx ON public.item_contrato_pagamento USING btree (id);
 2   DROP INDEX public.item_contrato_pagamento_id_idx;
       public         postgres    false    457            ~           1259    18615 0   lancamento_duplicado_controle_upload_arquivo_idx    INDEX     �   CREATE INDEX lancamento_duplicado_controle_upload_arquivo_idx ON public.lancamento_duplicado USING btree (controle_upload_arquivo_id, data_processamento);
 D   DROP INDEX public.lancamento_duplicado_controle_upload_arquivo_idx;
       public         postgres    false    464    464                       1259    18616 &   lancamento_duplicado_lancamento_id_idx    INDEX     p   CREATE INDEX lancamento_duplicado_lancamento_id_idx ON public.lancamento_duplicado USING btree (lancamento_id);
 :   DROP INDEX public.lancamento_duplicado_lancamento_id_idx;
       public         postgres    false    464            �           1259    18617    schema_version_s_idx    INDEX     R   CREATE INDEX schema_version_s_idx ON public.schema_version USING btree (success);
 (   DROP INDEX public.schema_version_s_idx;
       public         postgres    false    574                       1259    18618    tipo_servico_id_idx    INDEX     J   CREATE INDEX tipo_servico_id_idx ON public.tipo_servico USING btree (id);
 '   DROP INDEX public.tipo_servico_id_idx;
       public         postgres    false    601                       1259    18619    uk_tarifa_origem    INDEX     o   CREATE UNIQUE INDEX uk_tarifa_origem ON public.tarifa_origem USING btree (descricao) WHERE (banco_id IS NULL);
 $   DROP INDEX public.uk_tarifa_origem;
       public         postgres    false    581    581                       1259    18620    uk_tarifa_origem_banco    INDEX     �   CREATE UNIQUE INDEX uk_tarifa_origem_banco ON public.tarifa_origem USING btree (descricao, banco_id) WHERE (banco_id IS NOT NULL);
 *   DROP INDEX public.uk_tarifa_origem_banco;
       public         postgres    false    581    581    581                       1259    18621    uk_tipo_operacao_cesta_servico    INDEX     �   CREATE UNIQUE INDEX uk_tipo_operacao_cesta_servico ON public.tipo_operacao_cesta_servico USING btree (descricao) WHERE (banco_id IS NULL);
 2   DROP INDEX public.uk_tipo_operacao_cesta_servico;
       public         postgres    false    597    597                       1259    18622 $   uk_tipo_operacao_cesta_servico_banco    INDEX     �   CREATE UNIQUE INDEX uk_tipo_operacao_cesta_servico_banco ON public.tipo_operacao_cesta_servico USING btree (descricao, banco_id) WHERE (banco_id IS NOT NULL);
 8   DROP INDEX public.uk_tipo_operacao_cesta_servico_banco;
       public         postgres    false    597    597    597                       1259    18623 	   uk_titulo    INDEX     �   CREATE UNIQUE INDEX uk_titulo ON public.titulo USING btree (empresa_id, convenio_id, data_vencimento, valor, num_documento, nosso_numero, numero_remessa);
    DROP INDEX public.uk_titulo;
       public         postgres    false    602    602    602    602    602    602    602                        1259    18624    uk_titulo_chave    INDEX     Y   CREATE UNIQUE INDEX uk_titulo_chave ON public.titulo USING btree (chave_titulo_remessa);
 #   DROP INDEX public.uk_titulo_chave;
       public         postgres    false    602            b           1259    18625 #   vinculo_ocorrencia_pagamento_id_idx    INDEX     j   CREATE INDEX vinculo_ocorrencia_pagamento_id_idx ON public.vinculo_ocorrencia_pagamento USING btree (id);
 7   DROP INDEX public.vinculo_ocorrencia_pagamento_id_idx;
       public         postgres    false    653            ^           2620    18626    favorecido before_favorecido    TRIGGER     �   CREATE TRIGGER before_favorecido BEFORE INSERT OR UPDATE ON public.favorecido FOR EACH ROW EXECUTE PROCEDURE public.before_favorecido();
 5   DROP TRIGGER before_favorecido ON public.favorecido;
       public       postgres    false    674    378            _           2620    18627 &   lote_favorecido before_lote_favorecido    TRIGGER     �   CREATE TRIGGER before_lote_favorecido BEFORE INSERT OR UPDATE ON public.lote_favorecido FOR EACH ROW EXECUTE PROCEDURE public.before_lote_favorecido();
 ?   DROP TRIGGER before_lote_favorecido ON public.lote_favorecido;
       public       postgres    false    677    490            `           2620    18628 !   titulo_retorno trg_titulo_retorno    TRIGGER     �   CREATE TRIGGER trg_titulo_retorno BEFORE INSERT OR UPDATE ON public.titulo_retorno FOR EACH ROW EXECUTE PROCEDURE public.trg_titulo_retorno();
 :   DROP TRIGGER trg_titulo_retorno ON public.titulo_retorno;
       public       postgres    false    697    614            z           2606    18629 ?   cliente_ftp_log_externo cliente_ftp_log_externo_empresa_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.cliente_ftp_log_externo
    ADD CONSTRAINT cliente_ftp_log_externo_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 l   ALTER TABLE ONLY auditoria.cliente_ftp_log_externo DROP CONSTRAINT cliente_ftp_log_externo_empresa_id_fkey;
    	   auditoria       postgres    false    4628    201    360            [           2606    36193 /   conta_pagar_aud conta_pagar_aud_empresa_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.conta_pagar_aud
    ADD CONSTRAINT conta_pagar_aud_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 \   ALTER TABLE ONLY auditoria.conta_pagar_aud DROP CONSTRAINT conta_pagar_aud_empresa_id_fkey;
    	   auditoria       postgres    false    4628    673    360            \           2606    36198 2   conta_pagar_aud conta_pagar_aud_tipo_conta_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.conta_pagar_aud
    ADD CONSTRAINT conta_pagar_aud_tipo_conta_id_fkey FOREIGN KEY (tipo_conta_id) REFERENCES public.tipo_conta_pagar(id);
 _   ALTER TABLE ONLY auditoria.conta_pagar_aud DROP CONSTRAINT conta_pagar_aud_tipo_conta_id_fkey;
    	   auditoria       postgres    false    590    673    4879            ]           2606    36203 <   conta_pagar_aud conta_pagar_aud_usuario_movimentacao_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.conta_pagar_aud
    ADD CONSTRAINT conta_pagar_aud_usuario_movimentacao_id_fkey FOREIGN KEY (usuario_movimentacao_id) REFERENCES public.usuario(id);
 i   ALTER TABLE ONLY auditoria.conta_pagar_aud DROP CONSTRAINT conta_pagar_aud_usuario_movimentacao_id_fkey;
    	   auditoria       postgres    false    4926    673    628            �           2606    18634    sub_categoria fk_categoria    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.sub_categoria
    ADD CONSTRAINT fk_categoria FOREIGN KEY (categoria_id) REFERENCES auditoria.categoria(id);
 G   ALTER TABLE ONLY auditoria.sub_categoria DROP CONSTRAINT fk_categoria;
    	   auditoria       postgres    false    216    4441    199                       2606    18639 >   frequencia_recolhimento_aud fk_frequencia_recolhimento_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.frequencia_recolhimento_aud
    ADD CONSTRAINT fk_frequencia_recolhimento_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 k   ALTER TABLE ONLY auditoria.frequencia_recolhimento_aud DROP CONSTRAINT fk_frequencia_recolhimento_empresa;
    	   auditoria       postgres    false    4628    207    360            �           2606    18644 ;   frequencia_recolhimento_aud fk_frequencia_recolhimento_loja    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.frequencia_recolhimento_aud
    ADD CONSTRAINT fk_frequencia_recolhimento_loja FOREIGN KEY (loja_id) REFERENCES public.loja(id);
 h   ALTER TABLE ONLY auditoria.frequencia_recolhimento_aud DROP CONSTRAINT fk_frequencia_recolhimento_loja;
    	   auditoria       postgres    false    4761    207    482            �           2606    18649 E   frequencia_recolhimento_aud fk_frequencia_recolhimento_transportadora    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.frequencia_recolhimento_aud
    ADD CONSTRAINT fk_frequencia_recolhimento_transportadora FOREIGN KEY (transportadora_id) REFERENCES public.transportadora(id);
 r   ALTER TABLE ONLY auditoria.frequencia_recolhimento_aud DROP CONSTRAINT fk_frequencia_recolhimento_transportadora;
    	   auditoria       postgres    false    622    207    4920            �           2606    18654 A   frequencia_recolhimento_aud fk_frequencia_recolhimento_usuario_id    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.frequencia_recolhimento_aud
    ADD CONSTRAINT fk_frequencia_recolhimento_usuario_id FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 n   ALTER TABLE ONLY auditoria.frequencia_recolhimento_aud DROP CONSTRAINT fk_frequencia_recolhimento_usuario_id;
    	   auditoria       postgres    false    628    4926    207            {           2606    18659     controle_acesso fk_grupo_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.controle_acesso
    ADD CONSTRAINT fk_grupo_empresa FOREIGN KEY (grupo_empresa_id) REFERENCES public.grupo_empresa(id);
 M   ALTER TABLE ONLY auditoria.controle_acesso DROP CONSTRAINT fk_grupo_empresa;
    	   auditoria       postgres    false    403    203    4672            �           2606    18664 .   historico_usuario fk_historico_usuario_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.historico_usuario
    ADD CONSTRAINT fk_historico_usuario_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 [   ALTER TABLE ONLY auditoria.historico_usuario DROP CONSTRAINT fk_historico_usuario_usuario;
    	   auditoria       postgres    false    628    4926    210            �           2606    18669 9   historico_usuario fk_historico_usuario_usuario_ocorrencia    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.historico_usuario
    ADD CONSTRAINT fk_historico_usuario_usuario_ocorrencia FOREIGN KEY (usuario_ocorrencia_id) REFERENCES public.usuario(id);
 f   ALTER TABLE ONLY auditoria.historico_usuario DROP CONSTRAINT fk_historico_usuario_usuario_ocorrencia;
    	   auditoria       postgres    false    628    210    4926            y           2606    18674    categoria fk_menu_log    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.categoria
    ADD CONSTRAINT fk_menu_log FOREIGN KEY (menu_log_id) REFERENCES auditoria.menu_log(id);
 B   ALTER TABLE ONLY auditoria.categoria DROP CONSTRAINT fk_menu_log;
    	   auditoria       postgres    false    199    4453    214            |           2606    18679     controle_acesso fk_sub_categoria    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.controle_acesso
    ADD CONSTRAINT fk_sub_categoria FOREIGN KEY (sub_categoria_id) REFERENCES auditoria.sub_categoria(id);
 M   ALTER TABLE ONLY auditoria.controle_acesso DROP CONSTRAINT fk_sub_categoria;
    	   auditoria       postgres    false    4455    216    203            }           2606    18684    controle_acesso fk_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.controle_acesso
    ADD CONSTRAINT fk_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 G   ALTER TABLE ONLY auditoria.controle_acesso DROP CONSTRAINT fk_usuario;
    	   auditoria       postgres    false    4926    203    628            �           2606    18689    grupo_empresa_log fk_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY auditoria.grupo_empresa_log
    ADD CONSTRAINT fk_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 I   ALTER TABLE ONLY auditoria.grupo_empresa_log DROP CONSTRAINT fk_usuario;
    	   auditoria       postgres    false    628    208    4926            ~           2606    18694    empresa_aud fk_usuario    FK CONSTRAINT     }   ALTER TABLE ONLY auditoria.empresa_aud
    ADD CONSTRAINT fk_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 C   ALTER TABLE ONLY auditoria.empresa_aud DROP CONSTRAINT fk_usuario;
    	   auditoria       postgres    false    205    4926    628            �           2606    18699    conta banco_fk    FK CONSTRAINT     n   ALTER TABLE ONLY public.conta
    ADD CONSTRAINT banco_fk FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 8   ALTER TABLE ONLY public.conta DROP CONSTRAINT banco_fk;
       public       postgres    false    296    247    4492            �           2606    18704 &   boleto boleto_empresa_pagadora_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.boleto
    ADD CONSTRAINT boleto_empresa_pagadora_id_fkey FOREIGN KEY (empresa_pagadora_id) REFERENCES public.empresa(id);
 P   ALTER TABLE ONLY public.boleto DROP CONSTRAINT boleto_empresa_pagadora_id_fkey;
       public       postgres    false    253    4628    360            �           2606    18709    boleto boleto_pagamento_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.boleto
    ADD CONSTRAINT boleto_pagamento_id_fkey FOREIGN KEY (pagamento_id) REFERENCES public.pagamento(id);
 I   ALTER TABLE ONLY public.boleto DROP CONSTRAINT boleto_pagamento_id_fkey;
       public       postgres    false    531    253    4817            �           2606    18714 /   categoria_lancamento categoria_lancamento_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.categoria_lancamento
    ADD CONSTRAINT categoria_lancamento_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 Y   ALTER TABLE ONLY public.categoria_lancamento DROP CONSTRAINT categoria_lancamento_banco;
       public       postgres    false    247    260    4492            �           2606    18719 7   categoria_lancamento_new categoria_lancamento_new_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.categoria_lancamento_new
    ADD CONSTRAINT categoria_lancamento_new_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 a   ALTER TABLE ONLY public.categoria_lancamento_new DROP CONSTRAINT categoria_lancamento_new_banco;
       public       postgres    false    4492    247    261            �           2606    18724 N   categoria_lancamento_new categoria_lancamento_new_tipo_categoria_lancamento_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.categoria_lancamento_new
    ADD CONSTRAINT categoria_lancamento_new_tipo_categoria_lancamento_id FOREIGN KEY (tipo_categoria_lancamento_id) REFERENCES public.tipo_categoria_lancamento(id) ON UPDATE CASCADE ON DELETE RESTRICT;
 x   ALTER TABLE ONLY public.categoria_lancamento_new DROP CONSTRAINT categoria_lancamento_new_tipo_categoria_lancamento_id;
       public       postgres    false    4875    586    261            �           2606    18729 F   categoria_lancamento categoria_lancamento_tipo_categoria_lancamento_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.categoria_lancamento
    ADD CONSTRAINT categoria_lancamento_tipo_categoria_lancamento_id FOREIGN KEY (tipo_categoria_lancamento_id) REFERENCES public.tipo_categoria_lancamento(id) ON UPDATE CASCADE ON DELETE RESTRICT;
 p   ALTER TABLE ONLY public.categoria_lancamento DROP CONSTRAINT categoria_lancamento_tipo_categoria_lancamento_id;
       public       postgres    false    260    586    4875            �           2606    18734 $   cheque cheque_favorecido_id_old_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.cheque
    ADD CONSTRAINT cheque_favorecido_id_old_fkey FOREIGN KEY (favorecido_id_old) REFERENCES public.favorecido(id);
 N   ALTER TABLE ONLY public.cheque DROP CONSTRAINT cheque_favorecido_id_old_fkey;
       public       postgres    false    4644    266    378            R           2606    35347 5   conciliacao_cash conciliacao_cash_faturamento_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_cash
    ADD CONSTRAINT conciliacao_cash_faturamento_id_fkey FOREIGN KEY (faturamento_id) REFERENCES public.faturamento(id);
 _   ALTER TABLE ONLY public.conciliacao_cash DROP CONSTRAINT conciliacao_cash_faturamento_id_fkey;
       public       postgres    false    4642    376    665            U           2606    35382 B   conciliacao_cash conciliacao_cash_lancamento_auxiliar_cash_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_cash
    ADD CONSTRAINT conciliacao_cash_lancamento_auxiliar_cash_id_fkey FOREIGN KEY (lancamento_auxiliar_cash_id) REFERENCES public.lancamento_auxiliar_cash(id);
 l   ALTER TABLE ONLY public.conciliacao_cash DROP CONSTRAINT conciliacao_cash_lancamento_auxiliar_cash_id_fkey;
       public       postgres    false    665    660    4972            S           2606    35352 .   conciliacao_cash conciliacao_cash_loja_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_cash
    ADD CONSTRAINT conciliacao_cash_loja_id_fkey FOREIGN KEY (loja_id) REFERENCES public.loja(id);
 X   ALTER TABLE ONLY public.conciliacao_cash DROP CONSTRAINT conciliacao_cash_loja_id_fkey;
       public       postgres    false    4761    665    482            T           2606    35357 1   conciliacao_cash conciliacao_cash_usuario_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_cash
    ADD CONSTRAINT conciliacao_cash_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 [   ALTER TABLE ONLY public.conciliacao_cash DROP CONSTRAINT conciliacao_cash_usuario_id_fkey;
       public       postgres    false    665    628    4926            �           2606    18739 C   conciliacao_numerario conciliacao_numerario_grupo_numerario_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_numerario
    ADD CONSTRAINT conciliacao_numerario_grupo_numerario_id_fkey FOREIGN KEY (grupo_numerario_id) REFERENCES public.grupo_numerario(id);
 m   ALTER TABLE ONLY public.conciliacao_numerario DROP CONSTRAINT conciliacao_numerario_grupo_numerario_id_fkey;
       public       postgres    false    292    4680    410            �           2606    18744 7   conta_pagar conta_pagar_controle_upload_arquivo_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.conta_pagar
    ADD CONSTRAINT conta_pagar_controle_upload_arquivo_id_fkey FOREIGN KEY (controle_upload_arquivo_id) REFERENCES public.controle_upload_arquivo(id);
 a   ALTER TABLE ONLY public.conta_pagar DROP CONSTRAINT conta_pagar_controle_upload_arquivo_id_fkey;
       public       postgres    false    4593    332    302            �           2606    18749 ,   contrato_bancario contrato_bancario_banco_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.contrato_bancario
    ADD CONSTRAINT contrato_bancario_banco_id FOREIGN KEY (banco_id) REFERENCES public.banco(id) ON UPDATE CASCADE ON DELETE RESTRICT;
 V   ALTER TABLE ONLY public.contrato_bancario DROP CONSTRAINT contrato_bancario_banco_id;
       public       postgres    false    310    247    4492            �           2606    18754 ,   contrato_bancario contrato_bancario_conta_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.contrato_bancario
    ADD CONSTRAINT contrato_bancario_conta_id FOREIGN KEY (conta_id) REFERENCES public.conta(id) ON UPDATE CASCADE ON DELETE RESTRICT;
 V   ALTER TABLE ONLY public.contrato_bancario DROP CONSTRAINT contrato_bancario_conta_id;
       public       postgres    false    4547    296    310            �           2606    18759 .   contrato_bancario contrato_bancario_empresa_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.contrato_bancario
    ADD CONSTRAINT contrato_bancario_empresa_id FOREIGN KEY (empresa_id) REFERENCES public.empresa(id) ON UPDATE CASCADE ON DELETE RESTRICT;
 X   ALTER TABLE ONLY public.contrato_bancario DROP CONSTRAINT contrato_bancario_empresa_id;
       public       postgres    false    4628    360    310            �           2606    18764 C   contrato_bancario contrato_bancario_modalidade_contrato_bancario_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.contrato_bancario
    ADD CONSTRAINT contrato_bancario_modalidade_contrato_bancario_id FOREIGN KEY (modalidade_contrato_bancario_id) REFERENCES public.modalidade_contrato_bancario(id) ON UPDATE CASCADE ON DELETE RESTRICT;
 m   ALTER TABLE ONLY public.contrato_bancario DROP CONSTRAINT contrato_bancario_modalidade_contrato_bancario_id;
       public       postgres    false    499    310    4777            �           2606    18769 =   contrato_bancario contrato_bancario_tipo_contrato_bancario_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.contrato_bancario
    ADD CONSTRAINT contrato_bancario_tipo_contrato_bancario_id FOREIGN KEY (tipo_contrato_bancario_id) REFERENCES public.tipo_contrato_bancario(id) ON UPDATE CASCADE ON DELETE RESTRICT;
 g   ALTER TABLE ONLY public.contrato_bancario DROP CONSTRAINT contrato_bancario_tipo_contrato_bancario_id;
       public       postgres    false    4883    592    310            �           2606    18774 &   controle_card controle_card_usuario_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_card
    ADD CONSTRAINT controle_card_usuario_id FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 P   ALTER TABLE ONLY public.controle_card DROP CONSTRAINT controle_card_usuario_id;
       public       postgres    false    317    628    4926            �           2606    18779 7   controle_upload_arquivo controle_upload_arquivo_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_upload_arquivo
    ADD CONSTRAINT controle_upload_arquivo_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 a   ALTER TABLE ONLY public.controle_upload_arquivo DROP CONSTRAINT controle_upload_arquivo_empresa;
       public       postgres    false    332    4628    360            �           2606    18784 P   controle_upload_arquivo controle_upload_arquivo_importacao_personalizada_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_upload_arquivo
    ADD CONSTRAINT controle_upload_arquivo_importacao_personalizada_id_fkey FOREIGN KEY (importacao_personalizada_id) REFERENCES public.importacao_personalizada(id);
 z   ALTER TABLE ONLY public.controle_upload_arquivo DROP CONSTRAINT controle_upload_arquivo_importacao_personalizada_id_fkey;
       public       postgres    false    4707    436    332                       2606    18789 1   titulo_dda_duplicado controle_upload_arquivo_tdda    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_dda_duplicado
    ADD CONSTRAINT controle_upload_arquivo_tdda FOREIGN KEY (controle_upload_arquivo_id) REFERENCES public.controle_upload_arquivo(id);
 [   ALTER TABLE ONLY public.titulo_dda_duplicado DROP CONSTRAINT controle_upload_arquivo_tdda;
       public       postgres    false    608    332    4593            �           2606    18794    pagamento convenio_conta    FK CONSTRAINT     �   ALTER TABLE ONLY public.pagamento
    ADD CONSTRAINT convenio_conta FOREIGN KEY (convenio_conta_id) REFERENCES public.convenio_conta(id);
 B   ALTER TABLE ONLY public.pagamento DROP CONSTRAINT convenio_conta;
       public       postgres    false    4602    531    338                       2606    18799 &   empresa empresa_empresa_matriz_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.empresa
    ADD CONSTRAINT empresa_empresa_matriz_id_fkey FOREIGN KEY (empresa_matriz_id) REFERENCES public.empresa(id);
 P   ALTER TABLE ONLY public.empresa DROP CONSTRAINT empresa_empresa_matriz_id_fkey;
       public       postgres    false    4628    360    360            �           2606    18804    conta empresa_fk    FK CONSTRAINT     t   ALTER TABLE ONLY public.conta
    ADD CONSTRAINT empresa_fk FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 :   ALTER TABLE ONLY public.conta DROP CONSTRAINT empresa_fk;
       public       postgres    false    4628    360    296            !           2606    18809 =   empresa_transportadora empresa_transportadora_empresa_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.empresa_transportadora
    ADD CONSTRAINT empresa_transportadora_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 g   ALTER TABLE ONLY public.empresa_transportadora DROP CONSTRAINT empresa_transportadora_empresa_id_fkey;
       public       postgres    false    360    4628    363            "           2606    18814 D   empresa_transportadora empresa_transportadora_transportadora_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.empresa_transportadora
    ADD CONSTRAINT empresa_transportadora_transportadora_id_fkey FOREIGN KEY (transportadora_id) REFERENCES public.transportadora(id);
 n   ALTER TABLE ONLY public.empresa_transportadora DROP CONSTRAINT empresa_transportadora_transportadora_id_fkey;
       public       postgres    false    363    4920    622            &           2606    18819 '   faturamento faturamento_empresa_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.faturamento
    ADD CONSTRAINT faturamento_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 Q   ALTER TABLE ONLY public.faturamento DROP CONSTRAINT faturamento_empresa_id_fkey;
       public       postgres    false    376    360    4628            '           2606    18824 $   faturamento faturamento_loja_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.faturamento
    ADD CONSTRAINT faturamento_loja_id_fkey FOREIGN KEY (loja_id) REFERENCES public.loja(id);
 N   ALTER TABLE ONLY public.faturamento DROP CONSTRAINT faturamento_loja_id_fkey;
       public       postgres    false    376    482    4761            ,           2606    18829 /   favorecido_conta favorecido_conta_banco_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.favorecido_conta
    ADD CONSTRAINT favorecido_conta_banco_id_fkey FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 Y   ALTER TABLE ONLY public.favorecido_conta DROP CONSTRAINT favorecido_conta_banco_id_fkey;
       public       postgres    false    4492    380    247            -           2606    18834 4   favorecido_conta favorecido_conta_favorecido_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.favorecido_conta
    ADD CONSTRAINT favorecido_conta_favorecido_id_fkey FOREIGN KEY (favorecido_id) REFERENCES public.favorecido(id);
 ^   ALTER TABLE ONLY public.favorecido_conta DROP CONSTRAINT favorecido_conta_favorecido_id_fkey;
       public       postgres    false    380    4644    378            .           2606    18839 8   favorecido_conta favorecido_conta_favorecido_id_old_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.favorecido_conta
    ADD CONSTRAINT favorecido_conta_favorecido_id_old_fkey FOREIGN KEY (favorecido_id_old) REFERENCES public.favorecido(id);
 b   ALTER TABLE ONLY public.favorecido_conta DROP CONSTRAINT favorecido_conta_favorecido_id_old_fkey;
       public       postgres    false    380    378    4644            �           2606    18844 !   titulo_auxiliar fk10f6f7d9d813efe    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_auxiliar
    ADD CONSTRAINT fk10f6f7d9d813efe FOREIGN KEY (titulo_id) REFERENCES public.titulo(id);
 K   ALTER TABLE ONLY public.titulo_auxiliar DROP CONSTRAINT fk10f6f7d9d813efe;
       public       postgres    false    4894    605    602            u           2606    18849 )   lancamento_fluxo_caixa fk11f72ed6724043bc    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_fluxo_caixa
    ADD CONSTRAINT fk11f72ed6724043bc FOREIGN KEY (conta_lancamento_id) REFERENCES public.conta_lancamento_fluxo_caixa(id);
 S   ALTER TABLE ONLY public.lancamento_fluxo_caixa DROP CONSTRAINT fk11f72ed6724043bc;
       public       postgres    false    299    465    4551            v           2606    18854 )   lancamento_fluxo_caixa fk11f72ed682e0ddb1    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_fluxo_caixa
    ADD CONSTRAINT fk11f72ed682e0ddb1 FOREIGN KEY (item_grupo_lancamento_id) REFERENCES public.item_grupo_lancamento_fluxo_caixa(id);
 S   ALTER TABLE ONLY public.lancamento_fluxo_caixa DROP CONSTRAINT fk11f72ed682e0ddb1;
       public       postgres    false    465    458    4731            �           2606    18859     pendencia_nsa fk18d8aee453edf874    FK CONSTRAINT     �   ALTER TABLE ONLY public.pendencia_nsa
    ADD CONSTRAINT fk18d8aee453edf874 FOREIGN KEY (compromisso_id) REFERENCES public.compromisso(id);
 J   ALTER TABLE ONLY public.pendencia_nsa DROP CONSTRAINT fk18d8aee453edf874;
       public       postgres    false    282    4524    541            �           2606    18864     pendencia_nsa fk18d8aee46b861900    FK CONSTRAINT     �   ALTER TABLE ONLY public.pendencia_nsa
    ADD CONSTRAINT fk18d8aee46b861900 FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 J   ALTER TABLE ONLY public.pendencia_nsa DROP CONSTRAINT fk18d8aee46b861900;
       public       postgres    false    541    334    4595                       2606    18869 (   despesa_processamento fk1d3aa195b0c671df    FK CONSTRAINT     �   ALTER TABLE ONLY public.despesa_processamento
    ADD CONSTRAINT fk1d3aa195b0c671df FOREIGN KEY (processamento_otimiza_id) REFERENCES public.processamento_otimiza(id);
 R   ALTER TABLE ONLY public.despesa_processamento DROP CONSTRAINT fk1d3aa195b0c671df;
       public       postgres    false    354    551    4835            �           2606    18874 *   aplicacao_processamento fk250e7c47b0c671df    FK CONSTRAINT     �   ALTER TABLE ONLY public.aplicacao_processamento
    ADD CONSTRAINT fk250e7c47b0c671df FOREIGN KEY (processamento_otimiza_id) REFERENCES public.processamento_otimiza(id);
 T   ALTER TABLE ONLY public.aplicacao_processamento DROP CONSTRAINT fk250e7c47b0c671df;
       public       postgres    false    223    4835    551            o           2606    18879 4   item_grupo_lancamento_fluxo_caixa fk280f091831646f30    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_grupo_lancamento_fluxo_caixa
    ADD CONSTRAINT fk280f091831646f30 FOREIGN KEY (grupo_lancamento_id) REFERENCES public.grupo_lancamento_fluxo_caixa(id);
 ^   ALTER TABLE ONLY public.item_grupo_lancamento_fluxo_caixa DROP CONSTRAINT fk280f091831646f30;
       public       postgres    false    458    408    4678            �           2606    18884 !   mensagem_titulo fk2b7b4c4d562da34    FK CONSTRAINT     �   ALTER TABLE ONLY public.mensagem_titulo
    ADD CONSTRAINT fk2b7b4c4d562da34 FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 K   ALTER TABLE ONLY public.mensagem_titulo DROP CONSTRAINT fk2b7b4c4d562da34;
       public       postgres    false    360    497    4628            �           2606    18889 &   movimento_pagamento fk3caa12c3ad3b9957    FK CONSTRAINT     �   ALTER TABLE ONLY public.movimento_pagamento
    ADD CONSTRAINT fk3caa12c3ad3b9957 FOREIGN KEY (pagamento_id) REFERENCES public.pagamento(id);
 P   ALTER TABLE ONLY public.movimento_pagamento DROP CONSTRAINT fk3caa12c3ad3b9957;
       public       postgres    false    4817    503    531            /           2606    18894    float fk40d323c8bce1edc    FK CONSTRAINT     y   ALTER TABLE ONLY public."float"
    ADD CONSTRAINT fk40d323c8bce1edc FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 C   ALTER TABLE ONLY public."float" DROP CONSTRAINT fk40d323c8bce1edc;
       public       postgres    false    4492    247    386            0           2606    18899    float fk40d323cbcb09c38    FK CONSTRAINT     �   ALTER TABLE ONLY public."float"
    ADD CONSTRAINT fk40d323cbcb09c38 FOREIGN KEY (forma_pagamento_arrecadacao_id) REFERENCES public.forma_pagamento_arrecadacao(id);
 C   ALTER TABLE ONLY public."float" DROP CONSTRAINT fk40d323cbcb09c38;
       public       postgres    false    389    386    4659            �           2606    18904    clientsftp fk41c3ea5a562da34    FK CONSTRAINT     �   ALTER TABLE ONLY public.clientsftp
    ADD CONSTRAINT fk41c3ea5a562da34 FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 F   ALTER TABLE ONLY public.clientsftp DROP CONSTRAINT fk41c3ea5a562da34;
       public       postgres    false    360    4628    274                       2606    18909 !   usuario_contas fk4229711576a926f4    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_contas
    ADD CONSTRAINT fk4229711576a926f4 FOREIGN KEY (conta_id) REFERENCES public.conta(id);
 K   ALTER TABLE ONLY public.usuario_contas DROP CONSTRAINT fk4229711576a926f4;
       public       postgres    false    4547    296    630                       2606    18914 !   usuario_contas fk42297115b6389c14    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_contas
    ADD CONSTRAINT fk42297115b6389c14 FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 K   ALTER TABLE ONLY public.usuario_contas DROP CONSTRAINT fk42297115b6389c14;
       public       postgres    false    628    4926    630            �           2606    18919 !   auditoria_crud fk44b47d47b6389c14    FK CONSTRAINT     �   ALTER TABLE ONLY public.auditoria_crud
    ADD CONSTRAINT fk44b47d47b6389c14 FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 K   ALTER TABLE ONLY public.auditoria_crud DROP CONSTRAINT fk44b47d47b6389c14;
       public       postgres    false    235    4926    628            3           2606    18924 5   grafico_arrecadacao_forma_pagamento fk45b8a3d6b861900    FK CONSTRAINT     �   ALTER TABLE ONLY public.grafico_arrecadacao_forma_pagamento
    ADD CONSTRAINT fk45b8a3d6b861900 FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 _   ALTER TABLE ONLY public.grafico_arrecadacao_forma_pagamento DROP CONSTRAINT fk45b8a3d6b861900;
       public       postgres    false    4595    397    334            4           2606    18929 5   grafico_arrecadacao_forma_pagamento fk45b8a3d853506ab    FK CONSTRAINT     �   ALTER TABLE ONLY public.grafico_arrecadacao_forma_pagamento
    ADD CONSTRAINT fk45b8a3d853506ab FOREIGN KEY (forma_pagamento_arrecadacao_id) REFERENCES public.forma_pagamento_arrecadacao(id);
 _   ALTER TABLE ONLY public.grafico_arrecadacao_forma_pagamento DROP CONSTRAINT fk45b8a3d853506ab;
       public       postgres    false    4659    389    397            �           2606    18934 #   produto_bancario fk4bb3c7d129331374    FK CONSTRAINT     �   ALTER TABLE ONLY public.produto_bancario
    ADD CONSTRAINT fk4bb3c7d129331374 FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 M   ALTER TABLE ONLY public.produto_bancario DROP CONSTRAINT fk4bb3c7d129331374;
       public       postgres    false    553    247    4492            �           2606    18939 "   produto_bancario fk4bb3c7d1562da34    FK CONSTRAINT     �   ALTER TABLE ONLY public.produto_bancario
    ADD CONSTRAINT fk4bb3c7d1562da34 FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 L   ALTER TABLE ONLY public.produto_bancario DROP CONSTRAINT fk4bb3c7d1562da34;
       public       postgres    false    360    4628    553            !           2606    18944 %   usuario_favorecido fk53450f89b3238f98    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_favorecido
    ADD CONSTRAINT fk53450f89b3238f98 FOREIGN KEY (usuario_cadastro_id) REFERENCES public.usuario(id);
 O   ALTER TABLE ONLY public.usuario_favorecido DROP CONSTRAINT fk53450f89b3238f98;
       public       postgres    false    632    628    4926            �           2606    18949    arrecadacao fk55ea01f2562da34    FK CONSTRAINT     �   ALTER TABLE ONLY public.arrecadacao
    ADD CONSTRAINT fk55ea01f2562da34 FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 G   ALTER TABLE ONLY public.arrecadacao DROP CONSTRAINT fk55ea01f2562da34;
       public       postgres    false    4628    227    360            2           2606    18954 -   forma_pagamento_fluxo_caixa fk5813a3e0562da34    FK CONSTRAINT     �   ALTER TABLE ONLY public.forma_pagamento_fluxo_caixa
    ADD CONSTRAINT fk5813a3e0562da34 FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 W   ALTER TABLE ONLY public.forma_pagamento_fluxo_caixa DROP CONSTRAINT fk5813a3e0562da34;
       public       postgres    false    360    391    4628            *           2606    18959 !   usuario_sacado fk5cac6ae8b3238f98    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_sacado
    ADD CONSTRAINT fk5cac6ae8b3238f98 FOREIGN KEY (usuario_cadastro_id) REFERENCES public.usuario(id);
 K   ALTER TABLE ONLY public.usuario_sacado DROP CONSTRAINT fk5cac6ae8b3238f98;
       public       postgres    false    628    638    4926            �           2606    18964 $   pagamento_arquivo fk6bc34694ce9059c5    FK CONSTRAINT     �   ALTER TABLE ONLY public.pagamento_arquivo
    ADD CONSTRAINT fk6bc34694ce9059c5 FOREIGN KEY (id) REFERENCES public.pagamento_arquivo(id);
 N   ALTER TABLE ONLY public.pagamento_arquivo DROP CONSTRAINT fk6bc34694ce9059c5;
       public       postgres    false    532    532    4819            �           2606    18969 #   conta_lancamento fk7dcf184a76a926f4    FK CONSTRAINT     �   ALTER TABLE ONLY public.conta_lancamento
    ADD CONSTRAINT fk7dcf184a76a926f4 FOREIGN KEY (conta_id) REFERENCES public.conta(id);
 M   ALTER TABLE ONLY public.conta_lancamento DROP CONSTRAINT fk7dcf184a76a926f4;
       public       postgres    false    296    298    4547            w           2606    18974 )   lancamento_fluxo_caixa fk88c90af635c7a893    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_fluxo_caixa
    ADD CONSTRAINT fk88c90af635c7a893 FOREIGN KEY (forma_pagamnto_id) REFERENCES public.forma_pagamento_fluxo_caixa(id);
 S   ALTER TABLE ONLY public.lancamento_fluxo_caixa DROP CONSTRAINT fk88c90af635c7a893;
       public       postgres    false    391    465    4661            x           2606    18979 (   lancamento_fluxo_caixa fk88c90af6562da34    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_fluxo_caixa
    ADD CONSTRAINT fk88c90af6562da34 FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 R   ALTER TABLE ONLY public.lancamento_fluxo_caixa DROP CONSTRAINT fk88c90af6562da34;
       public       postgres    false    360    465    4628            y           2606    18984 )   lancamento_fluxo_caixa fk88c90af657dbd92e    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_fluxo_caixa
    ADD CONSTRAINT fk88c90af657dbd92e FOREIGN KEY (conta_lancamento_id) REFERENCES public.conta_lancamento(id);
 S   ALTER TABLE ONLY public.lancamento_fluxo_caixa DROP CONSTRAINT fk88c90af657dbd92e;
       public       postgres    false    298    465    4549                       2606    18989 !   titulo_mensagem fk9098cbf1cda87f5    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_mensagem
    ADD CONSTRAINT fk9098cbf1cda87f5 FOREIGN KEY (mensagem_titulo_id) REFERENCES public.mensagem_titulo(id);
 K   ALTER TABLE ONLY public.titulo_mensagem DROP CONSTRAINT fk9098cbf1cda87f5;
       public       postgres    false    497    612    4775                       2606    18994 !   titulo_mensagem fk9098cbf1d813efe    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_mensagem
    ADD CONSTRAINT fk9098cbf1d813efe FOREIGN KEY (titulo_id) REFERENCES public.titulo(id);
 K   ALTER TABLE ONLY public.titulo_mensagem DROP CONSTRAINT fk9098cbf1d813efe;
       public       postgres    false    602    612    4894            %           2606    18999 ,   faixa_nosso_numero_sacado fk95c3bea1922a363e    FK CONSTRAINT     �   ALTER TABLE ONLY public.faixa_nosso_numero_sacado
    ADD CONSTRAINT fk95c3bea1922a363e FOREIGN KEY (sacado_id) REFERENCES public.sacado(id);
 V   ALTER TABLE ONLY public.faixa_nosso_numero_sacado DROP CONSTRAINT fk95c3bea1922a363e;
       public       postgres    false    570    371    4853            �           2606    19004 4   acesso_conta_auxiliar fk_acesso_conta_auxiliar_conta    FK CONSTRAINT     �   ALTER TABLE ONLY public.acesso_conta_auxiliar
    ADD CONSTRAINT fk_acesso_conta_auxiliar_conta FOREIGN KEY (conta_id) REFERENCES public.conta(id);
 ^   ALTER TABLE ONLY public.acesso_conta_auxiliar DROP CONSTRAINT fk_acesso_conta_auxiliar_conta;
       public       postgres    false    219    4547    296            �           2606    19009 B   acesso_conta_auxiliar fk_acesso_conta_auxiliar_controle_acesso_api    FK CONSTRAINT     �   ALTER TABLE ONLY public.acesso_conta_auxiliar
    ADD CONSTRAINT fk_acesso_conta_auxiliar_controle_acesso_api FOREIGN KEY (controle_acesso_api_id) REFERENCES public.controle_acesso_api(id);
 l   ALTER TABLE ONLY public.acesso_conta_auxiliar DROP CONSTRAINT fk_acesso_conta_auxiliar_controle_acesso_api;
       public       postgres    false    4565    313    219            �           2606    19014    arquivo fk_arquivo_compromisso    FK CONSTRAINT     �   ALTER TABLE ONLY public.arquivo
    ADD CONSTRAINT fk_arquivo_compromisso FOREIGN KEY (compromisso_id) REFERENCES public.compromisso(id);
 H   ALTER TABLE ONLY public.arquivo DROP CONSTRAINT fk_arquivo_compromisso;
       public       postgres    false    226    282    4524            �           2606    19019 *   arquivo fk_arquivo_controle_upload_arquivo    FK CONSTRAINT     �   ALTER TABLE ONLY public.arquivo
    ADD CONSTRAINT fk_arquivo_controle_upload_arquivo FOREIGN KEY (controle_upload_arquivo_id) REFERENCES public.controle_upload_arquivo(id) ON DELETE CASCADE;
 T   ALTER TABLE ONLY public.arquivo DROP CONSTRAINT fk_arquivo_controle_upload_arquivo;
       public       postgres    false    226    332    4593            �           2606    19024    arquivo fk_arquivo_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.arquivo
    ADD CONSTRAINT fk_arquivo_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 E   ALTER TABLE ONLY public.arquivo DROP CONSTRAINT fk_arquivo_convenio;
       public       postgres    false    226    4595    334            �           2606    19029 #   arrecadacao fk_arrecadacao_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.arrecadacao
    ADD CONSTRAINT fk_arrecadacao_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 M   ALTER TABLE ONLY public.arrecadacao DROP CONSTRAINT fk_arrecadacao_convenio;
       public       postgres    false    334    4595    227            �           2606    19034 D   arrecadacao_debito_automatico fk_arrecadacao_debito_automatico_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.arrecadacao_debito_automatico
    ADD CONSTRAINT fk_arrecadacao_debito_automatico_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 n   ALTER TABLE ONLY public.arrecadacao_debito_automatico DROP CONSTRAINT fk_arrecadacao_debito_automatico_banco;
       public       postgres    false    4492    229    247            �           2606    19039 G   arrecadacao_debito_automatico fk_arrecadacao_debito_automatico_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.arrecadacao_debito_automatico
    ADD CONSTRAINT fk_arrecadacao_debito_automatico_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 q   ALTER TABLE ONLY public.arrecadacao_debito_automatico DROP CONSTRAINT fk_arrecadacao_debito_automatico_convenio;
       public       postgres    false    334    4595    229            �           2606    19044 Z   arrecadacao_debito_automatico fk_arrecadacao_debito_automatico_forma_pagamento_arrecadacao    FK CONSTRAINT     �   ALTER TABLE ONLY public.arrecadacao_debito_automatico
    ADD CONSTRAINT fk_arrecadacao_debito_automatico_forma_pagamento_arrecadacao FOREIGN KEY (forma_pagamento_arrecadacao_id) REFERENCES public.forma_pagamento_arrecadacao(id);
 �   ALTER TABLE ONLY public.arrecadacao_debito_automatico DROP CONSTRAINT fk_arrecadacao_debito_automatico_forma_pagamento_arrecadacao;
       public       postgres    false    229    389    4659            �           2606    19049 M   arrecadacao_debito_automatico fk_arrecadacao_debito_automatico_retorno_debito    FK CONSTRAINT     �   ALTER TABLE ONLY public.arrecadacao_debito_automatico
    ADD CONSTRAINT fk_arrecadacao_debito_automatico_retorno_debito FOREIGN KEY (retorno_debito_id) REFERENCES public.retorno_debito(id);
 w   ALTER TABLE ONLY public.arrecadacao_debito_automatico DROP CONSTRAINT fk_arrecadacao_debito_automatico_retorno_debito;
       public       postgres    false    229    568    4851            �           2606    19054 O   arrecadacao_divergente_contrato fk_arrecadacao_divergente_contrato_arrecadadora    FK CONSTRAINT     �   ALTER TABLE ONLY public.arrecadacao_divergente_contrato
    ADD CONSTRAINT fk_arrecadacao_divergente_contrato_arrecadadora FOREIGN KEY (contrato_arrecadadora_id) REFERENCES public.contrato_arrecadadora(id);
 y   ALTER TABLE ONLY public.arrecadacao_divergente_contrato DROP CONSTRAINT fk_arrecadacao_divergente_contrato_arrecadadora;
       public       postgres    false    308    231    4561            �           2606    19059 A   arrecadacao_divergente_contrato fk_arrecadacao_divergente_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.arrecadacao_divergente_contrato
    ADD CONSTRAINT fk_arrecadacao_divergente_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 k   ALTER TABLE ONLY public.arrecadacao_divergente_contrato DROP CONSTRAINT fk_arrecadacao_divergente_empresa;
       public       postgres    false    4628    360    231            �           2606    19064 .   auditoria_crud fk_auditoria_crud_grupo_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.auditoria_crud
    ADD CONSTRAINT fk_auditoria_crud_grupo_empresa FOREIGN KEY (grupo_empresa_id) REFERENCES public.grupo_empresa(id);
 X   ALTER TABLE ONLY public.auditoria_crud DROP CONSTRAINT fk_auditoria_crud_grupo_empresa;
       public       postgres    false    403    4672    235            �           2606    19069 *   auditoria_suite fk_auditoria_grupo_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.auditoria_suite
    ADD CONSTRAINT fk_auditoria_grupo_empresa FOREIGN KEY (grupo_empresa_id) REFERENCES public.grupo_empresa(id);
 T   ALTER TABLE ONLY public.auditoria_suite DROP CONSTRAINT fk_auditoria_grupo_empresa;
       public       postgres    false    4672    238    403            �           2606    19074    auditoria fk_auditoria_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.auditoria
    ADD CONSTRAINT fk_auditoria_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 H   ALTER TABLE ONLY public.auditoria DROP CONSTRAINT fk_auditoria_usuario;
       public       postgres    false    4926    628    234            �           2606    19079 $   auditoria_suite fk_auditoria_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.auditoria_suite
    ADD CONSTRAINT fk_auditoria_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 N   ALTER TABLE ONLY public.auditoria_suite DROP CONSTRAINT fk_auditoria_usuario;
       public       postgres    false    238    628    4926            �           2606    19084 ;   autorizacao_dependencia fk_autorizacao_dependencia_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.autorizacao_dependencia
    ADD CONSTRAINT fk_autorizacao_dependencia_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 e   ALTER TABLE ONLY public.autorizacao_dependencia DROP CONSTRAINT fk_autorizacao_dependencia_convenio;
       public       postgres    false    240    4595    334            �           2606    19089 :   autorizacao_dependencia fk_autorizacao_dependencia_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.autorizacao_dependencia
    ADD CONSTRAINT fk_autorizacao_dependencia_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 d   ALTER TABLE ONLY public.autorizacao_dependencia DROP CONSTRAINT fk_autorizacao_dependencia_usuario;
       public       postgres    false    240    628    4926            �           2606    19094 *   autorizacao_pag fk_autorizacao_pag_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.autorizacao_pag
    ADD CONSTRAINT fk_autorizacao_pag_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 T   ALTER TABLE ONLY public.autorizacao_pag DROP CONSTRAINT fk_autorizacao_pag_usuario;
       public       postgres    false    242    4926    628            �           2606    19099 3   autorizacao_remessa fk_autorizacao_remessa_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.autorizacao_remessa
    ADD CONSTRAINT fk_autorizacao_remessa_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 ]   ALTER TABLE ONLY public.autorizacao_remessa DROP CONSTRAINT fk_autorizacao_remessa_convenio;
       public       postgres    false    4595    334    244            �           2606    19104 2   autorizacao_remessa fk_autorizacao_remessa_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.autorizacao_remessa
    ADD CONSTRAINT fk_autorizacao_remessa_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 \   ALTER TABLE ONLY public.autorizacao_remessa DROP CONSTRAINT fk_autorizacao_remessa_usuario;
       public       postgres    false    244    628    4926            �           2606    19109 +   autorizacao_pag fk_autrizacao_pag_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.autorizacao_pag
    ADD CONSTRAINT fk_autrizacao_pag_pagamento FOREIGN KEY (pagamento_id) REFERENCES public.pagamento(id);
 U   ALTER TABLE ONLY public.autorizacao_pag DROP CONSTRAINT fk_autrizacao_pag_pagamento;
       public       postgres    false    4817    242    531            �           2606    19114     tipo_operacao_numerario fk_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.tipo_operacao_numerario
    ADD CONSTRAINT fk_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 J   ALTER TABLE ONLY public.tipo_operacao_numerario DROP CONSTRAINT fk_banco;
       public       postgres    false    598    247    4492            �           2606    19119 :   banco_suportado_cobranca fk_banco_suportado_cobranca_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.banco_suportado_cobranca
    ADD CONSTRAINT fk_banco_suportado_cobranca_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 d   ALTER TABLE ONLY public.banco_suportado_cobranca DROP CONSTRAINT fk_banco_suportado_cobranca_banco;
       public       postgres    false    247    4492    250            8           2606    19124 4   vinculo_descricao_ocorrencia_categoria fk_banco_vdoc    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_descricao_ocorrencia_categoria
    ADD CONSTRAINT fk_banco_vdoc FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 ^   ALTER TABLE ONLY public.vinculo_descricao_ocorrencia_categoria DROP CONSTRAINT fk_banco_vdoc;
       public       postgres    false    651    4492    247            �           2606    19129    boleto fk_boleto_banco    FK CONSTRAINT     v   ALTER TABLE ONLY public.boleto
    ADD CONSTRAINT fk_boleto_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 @   ALTER TABLE ONLY public.boleto DROP CONSTRAINT fk_boleto_banco;
       public       postgres    false    247    253    4492            �           2606    19134     boleto fk_boleto_forma_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.boleto
    ADD CONSTRAINT fk_boleto_forma_pagamento FOREIGN KEY (forma_pagamento_id) REFERENCES public.forma_pagamento(id);
 J   ALTER TABLE ONLY public.boleto DROP CONSTRAINT fk_boleto_forma_pagamento;
       public       postgres    false    388    4655    253            �           2606    19139 ,   carteira_cobranca fk_carteira_cobranca_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.carteira_cobranca
    ADD CONSTRAINT fk_carteira_cobranca_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 V   ALTER TABLE ONLY public.carteira_cobranca DROP CONSTRAINT fk_carteira_cobranca_banco;
       public       postgres    false    258    4492    247            �           2606    19144 -   categoria_lancamento_new fk_categoria_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.categoria_lancamento_new
    ADD CONSTRAINT fk_categoria_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 W   ALTER TABLE ONLY public.categoria_lancamento_new DROP CONSTRAINT fk_categoria_empresa;
       public       postgres    false    4628    261    360                       2606    19149 g   descricao_lancamento_new_categoria_lancamento_new_configuracao fk_categoria_lancamento_new_configuracao    FK CONSTRAINT     �   ALTER TABLE ONLY public.descricao_lancamento_new_categoria_lancamento_new_configuracao
    ADD CONSTRAINT fk_categoria_lancamento_new_configuracao FOREIGN KEY (categoria_lancamento_new_id) REFERENCES public.categoria_lancamento_new(id);
 �   ALTER TABLE ONLY public.descricao_lancamento_new_categoria_lancamento_new_configuracao DROP CONSTRAINT fk_categoria_lancamento_new_configuracao;
       public       postgres    false    4502    261    351            �           2606    19154    chave_pix fk_chave_pix_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.chave_pix
    ADD CONSTRAINT fk_chave_pix_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 H   ALTER TABLE ONLY public.chave_pix DROP CONSTRAINT fk_chave_pix_empresa;
       public       postgres    false    360    4628    265            �           2606    19159 !   chave_pix fk_chave_pix_favorecido    FK CONSTRAINT     �   ALTER TABLE ONLY public.chave_pix
    ADD CONSTRAINT fk_chave_pix_favorecido FOREIGN KEY (favorecido_id) REFERENCES public.favorecido(id);
 K   ALTER TABLE ONLY public.chave_pix DROP CONSTRAINT fk_chave_pix_favorecido;
       public       postgres    false    4644    265    378            �           2606    19164    chave_pix fk_chave_pix_grupo    FK CONSTRAINT     |   ALTER TABLE ONLY public.chave_pix
    ADD CONSTRAINT fk_chave_pix_grupo FOREIGN KEY (grupo_id) REFERENCES public.grupo(id);
 F   ALTER TABLE ONLY public.chave_pix DROP CONSTRAINT fk_chave_pix_grupo;
       public       postgres    false    265    399    4668            �           2606    19169    loja fk_cidade    FK CONSTRAINT     p   ALTER TABLE ONLY public.loja
    ADD CONSTRAINT fk_cidade FOREIGN KEY (cidade_id) REFERENCES public.cidade(id);
 8   ALTER TABLE ONLY public.loja DROP CONSTRAINT fk_cidade;
       public       postgres    false    4510    268    482                       2606    19174    transportadora fk_cidade    FK CONSTRAINT     z   ALTER TABLE ONLY public.transportadora
    ADD CONSTRAINT fk_cidade FOREIGN KEY (cidade_id) REFERENCES public.cidade(id);
 B   ALTER TABLE ONLY public.transportadora DROP CONSTRAINT fk_cidade;
       public       postgres    false    268    4510    622            �           2606    19179    cidade fk_cidade_estado    FK CONSTRAINT     y   ALTER TABLE ONLY public.cidade
    ADD CONSTRAINT fk_cidade_estado FOREIGN KEY (estado_id) REFERENCES public.estado(id);
 A   ALTER TABLE ONLY public.cidade DROP CONSTRAINT fk_cidade_estado;
       public       postgres    false    4634    367    268            �           2606    19184 "   cliente_ftp fk_cliente_ftp_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.cliente_ftp
    ADD CONSTRAINT fk_cliente_ftp_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 L   ALTER TABLE ONLY public.cliente_ftp DROP CONSTRAINT fk_cliente_ftp_empresa;
       public       postgres    false    270    4628    360                       2606    19189    convenio fk_cliente_ftp_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.convenio
    ADD CONSTRAINT fk_cliente_ftp_id FOREIGN KEY (cliente_ftp_id) REFERENCES public.cliente_ftp(id);
 D   ALTER TABLE ONLY public.convenio DROP CONSTRAINT fk_cliente_ftp_id;
       public       postgres    false    270    334    4512            �           2606    19194 .   cliente_ftp_log fk_cliente_ftp_log_cliente_ftp    FK CONSTRAINT     �   ALTER TABLE ONLY public.cliente_ftp_log
    ADD CONSTRAINT fk_cliente_ftp_log_cliente_ftp FOREIGN KEY (cliente_ftp_id) REFERENCES public.cliente_ftp(id);
 X   ALTER TABLE ONLY public.cliente_ftp_log DROP CONSTRAINT fk_cliente_ftp_log_cliente_ftp;
       public       postgres    false    272    270    4512            �           2606    19199 ;   cobranca_instrucao fk_cobranca_instrucao_cobranca_parametro    FK CONSTRAINT     �   ALTER TABLE ONLY public.cobranca_instrucao
    ADD CONSTRAINT fk_cobranca_instrucao_cobranca_parametro FOREIGN KEY (cobranca_parametro_id) REFERENCES public.cobranca_parametro(id);
 e   ALTER TABLE ONLY public.cobranca_instrucao DROP CONSTRAINT fk_cobranca_instrucao_cobranca_parametro;
       public       postgres    false    276    278    4520            �           2606    19204 :   cobranca_parametro fk_cobranca_parametro_carteira_cobranca    FK CONSTRAINT     �   ALTER TABLE ONLY public.cobranca_parametro
    ADD CONSTRAINT fk_cobranca_parametro_carteira_cobranca FOREIGN KEY (carteira_cobranca_id) REFERENCES public.carteira_cobranca(id);
 d   ALTER TABLE ONLY public.cobranca_parametro DROP CONSTRAINT fk_cobranca_parametro_carteira_cobranca;
       public       postgres    false    258    4498    278            �           2606    19209 1   cobranca_parametro fk_cobranca_parametro_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.cobranca_parametro
    ADD CONSTRAINT fk_cobranca_parametro_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 [   ALTER TABLE ONLY public.cobranca_parametro DROP CONSTRAINT fk_cobranca_parametro_convenio;
       public       postgres    false    278    4595    334            �           2606    19214 /   cobranca_parametro fk_cobranca_parametro_estado    FK CONSTRAINT     �   ALTER TABLE ONLY public.cobranca_parametro
    ADD CONSTRAINT fk_cobranca_parametro_estado FOREIGN KEY (estado_id) REFERENCES public.estado(id);
 Y   ALTER TABLE ONLY public.cobranca_parametro DROP CONSTRAINT fk_cobranca_parametro_estado;
       public       postgres    false    4634    278    367                       2606    19219 *   tributo_sem_codigo_barra fk_codigo_receita    FK CONSTRAINT     �   ALTER TABLE ONLY public.tributo_sem_codigo_barra
    ADD CONSTRAINT fk_codigo_receita FOREIGN KEY (codigo_receita_id) REFERENCES public.codigo_receita(id);
 T   ALTER TABLE ONLY public.tributo_sem_codigo_barra DROP CONSTRAINT fk_codigo_receita;
       public       postgres    false    626    4522    280            �           2606    19224 "   autorizacao_remessa fk_compromisso    FK CONSTRAINT     �   ALTER TABLE ONLY public.autorizacao_remessa
    ADD CONSTRAINT fk_compromisso FOREIGN KEY (compromisso_id) REFERENCES public.compromisso(id);
 L   ALTER TABLE ONLY public.autorizacao_remessa DROP CONSTRAINT fk_compromisso;
       public       postgres    false    4524    282    244            �           2606    19229 #   compromisso fk_compromisso_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.compromisso
    ADD CONSTRAINT fk_compromisso_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 M   ALTER TABLE ONLY public.compromisso DROP CONSTRAINT fk_compromisso_convenio;
       public       postgres    false    282    4595    334            �           2606    19234 5   conciliacao_financeira_auxiliar_titulo fk_conci_finan    FK CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_financeira_auxiliar_titulo
    ADD CONSTRAINT fk_conci_finan FOREIGN KEY (conciliacao_financeira_id) REFERENCES public.conciliacao_financeira(id);
 _   ALTER TABLE ONLY public.conciliacao_financeira_auxiliar_titulo DROP CONSTRAINT fk_conci_finan;
       public       postgres    false    285    4529    289            �           2606    19239 >   conciliacao_financeira_auxiliar_lancamento fk_conci_finan_lanc    FK CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_financeira_auxiliar_lancamento
    ADD CONSTRAINT fk_conci_finan_lanc FOREIGN KEY (conciliacao_financeira_id) REFERENCES public.conciliacao_financeira(id);
 h   ALTER TABLE ONLY public.conciliacao_financeira_auxiliar_lancamento DROP CONSTRAINT fk_conci_finan_lanc;
       public       postgres    false    4529    288    285            �           2606    19244 9   conciliacao_cobranca fk_conciliacao_cobranca_grupo_titulo    FK CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_cobranca
    ADD CONSTRAINT fk_conciliacao_cobranca_grupo_titulo FOREIGN KEY (grupo_titulo_id) REFERENCES public.grupo_titulo(id);
 c   ALTER TABLE ONLY public.conciliacao_cobranca DROP CONSTRAINT fk_conciliacao_cobranca_grupo_titulo;
       public       postgres    false    418    4691    284            �           2606    19249 9   conciliacao_financeira fk_conciliacao_financeira_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_financeira
    ADD CONSTRAINT fk_conciliacao_financeira_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 c   ALTER TABLE ONLY public.conciliacao_financeira DROP CONSTRAINT fk_conciliacao_financeira_convenio;
       public       postgres    false    285    4595    334            �           2606    19254 8   conciliacao_financeira fk_conciliacao_financeira_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_financeira
    ADD CONSTRAINT fk_conciliacao_financeira_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 b   ALTER TABLE ONLY public.conciliacao_financeira DROP CONSTRAINT fk_conciliacao_financeira_usuario;
       public       postgres    false    285    4926    628            �           2606    19259 A   conciliacao_lancamento fk_conciliacao_lancamento_grupo_lancamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_lancamento
    ADD CONSTRAINT fk_conciliacao_lancamento_grupo_lancamento FOREIGN KEY (grupo_lancamento_id) REFERENCES public.grupo_lancamento(id);
 k   ALTER TABLE ONLY public.conciliacao_lancamento DROP CONSTRAINT fk_conciliacao_lancamento_grupo_lancamento;
       public       postgres    false    291    4676    407            �           2606    19264 >   conciliacao_pagamento fk_conciliacao_pagamento_grupo_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_pagamento
    ADD CONSTRAINT fk_conciliacao_pagamento_grupo_pagamento FOREIGN KEY (grupo_pagamento_id) REFERENCES public.grupo_pagamento(id) ON DELETE CASCADE;
 h   ALTER TABLE ONLY public.conciliacao_pagamento DROP CONSTRAINT fk_conciliacao_pagamento_grupo_pagamento;
       public       postgres    false    293    4686    413            �           2606    19269    card fk_conta    FK CONSTRAINT     m   ALTER TABLE ONLY public.card
    ADD CONSTRAINT fk_conta FOREIGN KEY (conta_id) REFERENCES public.conta(id);
 7   ALTER TABLE ONLY public.card DROP CONSTRAINT fk_conta;
       public       postgres    false    257    296    4547            �           2606    19274 /   agendamento_descricao_categoria_global fk_conta    FK CONSTRAINT     �   ALTER TABLE ONLY public.agendamento_descricao_categoria_global
    ADD CONSTRAINT fk_conta FOREIGN KEY (conta_id) REFERENCES public.conta(id);
 Y   ALTER TABLE ONLY public.agendamento_descricao_categoria_global DROP CONSTRAINT fk_conta;
       public       postgres    false    221    296    4547            W           2606    35404 9   pre_controle_execucao_conciliacao_bancaria_v2 fk_conta_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.pre_controle_execucao_conciliacao_bancaria_v2
    ADD CONSTRAINT fk_conta_id FOREIGN KEY (conta_id) REFERENCES public.conta(id);
 c   ALTER TABLE ONLY public.pre_controle_execucao_conciliacao_bancaria_v2 DROP CONSTRAINT fk_conta_id;
       public       bv_postgres    false    296    667    4547            �           2606    19279 *   conta_pagar fk_conta_pagar_lote_favorecido    FK CONSTRAINT     �   ALTER TABLE ONLY public.conta_pagar
    ADD CONSTRAINT fk_conta_pagar_lote_favorecido FOREIGN KEY (lote_favorecido_id) REFERENCES public.lote_favorecido(id);
 T   ALTER TABLE ONLY public.conta_pagar DROP CONSTRAINT fk_conta_pagar_lote_favorecido;
       public       postgres    false    302    4767    490            i           2606    19284 #   item_contrato_numerario fk_contrato    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_numerario
    ADD CONSTRAINT fk_contrato FOREIGN KEY (contrato_id) REFERENCES public.contrato(id);
 M   ALTER TABLE ONLY public.item_contrato_numerario DROP CONSTRAINT fk_contrato;
       public       postgres    false    4559    307    453            �           2606    19289    contrato_loja fk_contrato    FK CONSTRAINT        ALTER TABLE ONLY public.contrato_loja
    ADD CONSTRAINT fk_contrato FOREIGN KEY (contrato_id) REFERENCES public.contrato(id);
 C   ALTER TABLE ONLY public.contrato_loja DROP CONSTRAINT fk_contrato;
       public       postgres    false    307    312    4559            �           2606    19294    contrato fk_contrato_banco    FK CONSTRAINT     z   ALTER TABLE ONLY public.contrato
    ADD CONSTRAINT fk_contrato_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 D   ALTER TABLE ONLY public.contrato DROP CONSTRAINT fk_contrato_banco;
       public       postgres    false    307    4492    247            �           2606    19299     contrato fk_contrato_compromisso    FK CONSTRAINT     �   ALTER TABLE ONLY public.contrato
    ADD CONSTRAINT fk_contrato_compromisso FOREIGN KEY (compromisso_id) REFERENCES public.compromisso(id);
 J   ALTER TABLE ONLY public.contrato DROP CONSTRAINT fk_contrato_compromisso;
       public       postgres    false    4524    307    282            �           2606    19304    contrato fk_contrato_conta    FK CONSTRAINT     z   ALTER TABLE ONLY public.contrato
    ADD CONSTRAINT fk_contrato_conta FOREIGN KEY (conta_id) REFERENCES public.conta(id);
 D   ALTER TABLE ONLY public.contrato DROP CONSTRAINT fk_contrato_conta;
       public       postgres    false    307    4547    296            �           2606    19309    contrato fk_contrato_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.contrato
    ADD CONSTRAINT fk_contrato_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 G   ALTER TABLE ONLY public.contrato DROP CONSTRAINT fk_contrato_convenio;
       public       postgres    false    4595    334    307            �           2606    19314    contrato fk_contrato_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.contrato
    ADD CONSTRAINT fk_contrato_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 F   ALTER TABLE ONLY public.contrato DROP CONSTRAINT fk_contrato_empresa;
       public       postgres    false    307    4628    360            �           2606    19319 !   contrato fk_contrato_tipo_servico    FK CONSTRAINT     �   ALTER TABLE ONLY public.contrato
    ADD CONSTRAINT fk_contrato_tipo_servico FOREIGN KEY (tipo_servico_id) REFERENCES public.tipo_servico(id);
 K   ALTER TABLE ONLY public.contrato DROP CONSTRAINT fk_contrato_tipo_servico;
       public       postgres    false    4891    307    601            �           2606    19324 2   controle_acesso_api fk_controle_acesso_api_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_acesso_api
    ADD CONSTRAINT fk_controle_acesso_api_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 \   ALTER TABLE ONLY public.controle_acesso_api DROP CONSTRAINT fk_controle_acesso_api_empresa;
       public       postgres    false    4628    313    360                       2606    19329 8   credencial_acesso_empresa fk_controle_acesso_api_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.credencial_acesso_empresa
    ADD CONSTRAINT fk_controle_acesso_api_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 b   ALTER TABLE ONLY public.credencial_acesso_empresa DROP CONSTRAINT fk_controle_acesso_api_empresa;
       public       postgres    false    4628    360    346            �           2606    19334 8   controle_acesso_api fk_controle_acesso_api_grupo_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_acesso_api
    ADD CONSTRAINT fk_controle_acesso_api_grupo_empresa FOREIGN KEY (grupo_empresa_id) REFERENCES public.grupo_empresa(id);
 b   ALTER TABLE ONLY public.controle_acesso_api DROP CONSTRAINT fk_controle_acesso_api_grupo_empresa;
       public       postgres    false    313    403    4672            �           2606    19339 >   controle_bloqueio_usuario fk_controle_bloqueio_usuario_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_bloqueio_usuario
    ADD CONSTRAINT fk_controle_bloqueio_usuario_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 h   ALTER TABLE ONLY public.controle_bloqueio_usuario DROP CONSTRAINT fk_controle_bloqueio_usuario_usuario;
       public       postgres    false    315    4926    628            �           2606    19344 $   controle_nsa fk_controle_nsa_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_nsa
    ADD CONSTRAINT fk_controle_nsa_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 N   ALTER TABLE ONLY public.controle_nsa DROP CONSTRAINT fk_controle_nsa_empresa;
       public       postgres    false    319    4628    360            �           2606    19349 E   controle_nsa_optantes_debito fk_controle_nsa_optantes_debito_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_nsa_optantes_debito
    ADD CONSTRAINT fk_controle_nsa_optantes_debito_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 o   ALTER TABLE ONLY public.controle_nsa_optantes_debito DROP CONSTRAINT fk_controle_nsa_optantes_debito_convenio;
       public       postgres    false    4595    334    323            �           2606    19354 5   controle_nsa_remessa fk_controle_nsa_remessa_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_nsa_remessa
    ADD CONSTRAINT fk_controle_nsa_remessa_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 _   ALTER TABLE ONLY public.controle_nsa_remessa DROP CONSTRAINT fk_controle_nsa_remessa_convenio;
       public       postgres    false    4595    326    334            �           2606    19359 4   controle_nsa_remessa fk_controle_nsa_remessa_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_nsa_remessa
    ADD CONSTRAINT fk_controle_nsa_remessa_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 ^   ALTER TABLE ONLY public.controle_nsa_remessa DROP CONSTRAINT fk_controle_nsa_remessa_empresa;
       public       postgres    false    326    360    4628            �           2606    19364 A   controle_processamento fk_controle_processamento_grupo_empresa_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_processamento
    ADD CONSTRAINT fk_controle_processamento_grupo_empresa_id FOREIGN KEY (grupo_empresa_id) REFERENCES public.empresa(id);
 k   ALTER TABLE ONLY public.controle_processamento DROP CONSTRAINT fk_controle_processamento_grupo_empresa_id;
       public       postgres    false    327    360    4628            �           2606    19369 L   controle_remessa_optantes_debito fk_controle_remessa_optantes_debito_arquivo    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_remessa_optantes_debito
    ADD CONSTRAINT fk_controle_remessa_optantes_debito_arquivo FOREIGN KEY (arquivo_id) REFERENCES public.arquivo(id);
 v   ALTER TABLE ONLY public.controle_remessa_optantes_debito DROP CONSTRAINT fk_controle_remessa_optantes_debito_arquivo;
       public       postgres    false    328    226    4463            �           2606    19374 L   controle_remessa_optantes_debito fk_controle_remessa_optantes_debito_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_remessa_optantes_debito
    ADD CONSTRAINT fk_controle_remessa_optantes_debito_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 v   ALTER TABLE ONLY public.controle_remessa_optantes_debito DROP CONSTRAINT fk_controle_remessa_optantes_debito_usuario;
       public       postgres    false    328    628    4926            �           2606    19379 (   controle_senha fk_controle_senha_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_senha
    ADD CONSTRAINT fk_controle_senha_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 R   ALTER TABLE ONLY public.controle_senha DROP CONSTRAINT fk_controle_senha_usuario;
       public       postgres    false    330    4926    628            �           2606    19384 "   arquivo fk_controle_upload_arquivo    FK CONSTRAINT     �   ALTER TABLE ONLY public.arquivo
    ADD CONSTRAINT fk_controle_upload_arquivo FOREIGN KEY (controle_upload_arquivo_id) REFERENCES public.controle_upload_arquivo(id);
 L   ALTER TABLE ONLY public.arquivo DROP CONSTRAINT fk_controle_upload_arquivo;
       public       postgres    false    4593    226    332            �           2606    19389 7   resumo_processamento_arquivo fk_controle_upload_arquivo    FK CONSTRAINT     �   ALTER TABLE ONLY public.resumo_processamento_arquivo
    ADD CONSTRAINT fk_controle_upload_arquivo FOREIGN KEY (controle_upload_id) REFERENCES public.controle_upload_arquivo(id);
 a   ALTER TABLE ONLY public.resumo_processamento_arquivo DROP CONSTRAINT fk_controle_upload_arquivo;
       public       postgres    false    4593    332    567            X           2606    19394 2   historico_upload_sacado fk_controle_upload_arquivo    FK CONSTRAINT     �   ALTER TABLE ONLY public.historico_upload_sacado
    ADD CONSTRAINT fk_controle_upload_arquivo FOREIGN KEY (controle_upload_arquivo_id) REFERENCES public.controle_upload_arquivo(id);
 \   ALTER TABLE ONLY public.historico_upload_sacado DROP CONSTRAINT fk_controle_upload_arquivo;
       public       postgres    false    434    332    4593            W           2606    19399 6   historico_upload_favorecido fk_controle_upload_arquivo    FK CONSTRAINT     �   ALTER TABLE ONLY public.historico_upload_favorecido
    ADD CONSTRAINT fk_controle_upload_arquivo FOREIGN KEY (controle_upload_arquivo_id) REFERENCES public.controle_upload_arquivo(id);
 `   ALTER TABLE ONLY public.historico_upload_favorecido DROP CONSTRAINT fk_controle_upload_arquivo;
       public       postgres    false    332    4593    432            �           2606    19404 6   recolhimento_transportadora fk_controle_upload_arquivo    FK CONSTRAINT     �   ALTER TABLE ONLY public.recolhimento_transportadora
    ADD CONSTRAINT fk_controle_upload_arquivo FOREIGN KEY (controle_upload_arquivo_id) REFERENCES public.controle_upload_arquivo(id);
 `   ALTER TABLE ONLY public.recolhimento_transportadora DROP CONSTRAINT fk_controle_upload_arquivo;
       public       postgres    false    332    4593    558            �           2606    19409 B   recolhimento_transportadora_duplicidade fk_controle_upload_arquivo    FK CONSTRAINT     �   ALTER TABLE ONLY public.recolhimento_transportadora_duplicidade
    ADD CONSTRAINT fk_controle_upload_arquivo FOREIGN KEY (controle_upload_arquivo_id) REFERENCES public.controle_upload_arquivo(id);
 l   ALTER TABLE ONLY public.recolhimento_transportadora_duplicidade DROP CONSTRAINT fk_controle_upload_arquivo;
       public       postgres    false    4593    332    561                        2606    19414 @   controle_upload_arquivo fk_controle_upload_arquivo_grupo_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_upload_arquivo
    ADD CONSTRAINT fk_controle_upload_arquivo_grupo_empresa FOREIGN KEY (grupo_empresa_id) REFERENCES public.grupo_empresa(id);
 j   ALTER TABLE ONLY public.controle_upload_arquivo DROP CONSTRAINT fk_controle_upload_arquivo_grupo_empresa;
       public       postgres    false    332    403    4672                       2606    19419 :   controle_upload_arquivo fk_controle_upload_arquivo_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_upload_arquivo
    ADD CONSTRAINT fk_controle_upload_arquivo_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 d   ALTER TABLE ONLY public.controle_upload_arquivo DROP CONSTRAINT fk_controle_upload_arquivo_usuario;
       public       postgres    false    332    4926    628            �           2606    19424    conta_pagar fk_convenio    FK CONSTRAINT     }   ALTER TABLE ONLY public.conta_pagar
    ADD CONSTRAINT fk_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 A   ALTER TABLE ONLY public.conta_pagar DROP CONSTRAINT fk_convenio;
       public       postgres    false    4595    302    334            	           2606    19429 7   convenio_configuracao fk_convenio_configuracao_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.convenio_configuracao
    ADD CONSTRAINT fk_convenio_configuracao_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 a   ALTER TABLE ONLY public.convenio_configuracao DROP CONSTRAINT fk_convenio_configuracao_convenio;
       public       postgres    false    4595    334    336            
           2606    19434 &   convenio_conta fk_convenio_conta_conta    FK CONSTRAINT     �   ALTER TABLE ONLY public.convenio_conta
    ADD CONSTRAINT fk_convenio_conta_conta FOREIGN KEY (conta_id) REFERENCES public.conta(id);
 P   ALTER TABLE ONLY public.convenio_conta DROP CONSTRAINT fk_convenio_conta_conta;
       public       postgres    false    338    296    4547                       2606    19439 )   convenio_conta fk_convenio_conta_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.convenio_conta
    ADD CONSTRAINT fk_convenio_conta_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 S   ALTER TABLE ONLY public.convenio_conta DROP CONSTRAINT fk_convenio_conta_convenio;
       public       postgres    false    334    338    4595                       2606    19444    convenio fk_convenio_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.convenio
    ADD CONSTRAINT fk_convenio_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 F   ALTER TABLE ONLY public.convenio DROP CONSTRAINT fk_convenio_empresa;
       public       postgres    false    334    4628    360            �           2606    19449    compromisso fk_convenio_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.compromisso
    ADD CONSTRAINT fk_convenio_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 I   ALTER TABLE ONLY public.compromisso DROP CONSTRAINT fk_convenio_empresa;
       public       postgres    false    360    282    4628                       2606    19454 -   convenio_empresa fk_convenio_empresa_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.convenio_empresa
    ADD CONSTRAINT fk_convenio_empresa_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 W   ALTER TABLE ONLY public.convenio_empresa DROP CONSTRAINT fk_convenio_empresa_convenio;
       public       postgres    false    334    339    4595                       2606    19459 ,   convenio_empresa fk_convenio_empresa_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.convenio_empresa
    ADD CONSTRAINT fk_convenio_empresa_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 V   ALTER TABLE ONLY public.convenio_empresa DROP CONSTRAINT fk_convenio_empresa_empresa;
       public       postgres    false    4628    360    339                       2606    19464 -   convenio_extrato fk_convenio_extrato_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.convenio_extrato
    ADD CONSTRAINT fk_convenio_extrato_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 W   ALTER TABLE ONLY public.convenio_extrato DROP CONSTRAINT fk_convenio_extrato_convenio;
       public       postgres    false    341    334    4595            +           2606    19469    usuario_sacado fk_convenio_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_sacado
    ADD CONSTRAINT fk_convenio_id FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 G   ALTER TABLE ONLY public.usuario_sacado DROP CONSTRAINT fk_convenio_id;
       public       postgres    false    638    4595    334                       2606    19474 1   convenio_pagamento fk_convenio_pagamento_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.convenio_pagamento
    ADD CONSTRAINT fk_convenio_pagamento_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 [   ALTER TABLE ONLY public.convenio_pagamento DROP CONSTRAINT fk_convenio_pagamento_convenio;
       public       postgres    false    4595    344    334            �           2606    19479 &   conta_pagar_log fk_cpl_controle_upload    FK CONSTRAINT     �   ALTER TABLE ONLY public.conta_pagar_log
    ADD CONSTRAINT fk_cpl_controle_upload FOREIGN KEY (controle_upload_arquivo_id) REFERENCES public.controle_upload_arquivo(id);
 P   ALTER TABLE ONLY public.conta_pagar_log DROP CONSTRAINT fk_cpl_controle_upload;
       public       postgres    false    332    304    4593            �           2606    19484    conta_pagar_log fk_cpl_cp    FK CONSTRAINT     �   ALTER TABLE ONLY public.conta_pagar_log
    ADD CONSTRAINT fk_cpl_cp FOREIGN KEY (conta_pagar_id) REFERENCES public.conta_pagar(id);
 C   ALTER TABLE ONLY public.conta_pagar_log DROP CONSTRAINT fk_cpl_cp;
       public       postgres    false    304    4553    302            �           2606    19489 J   agendamento_descricao_categoria_global fk_descricao_categoria_configuracao    FK CONSTRAINT     �   ALTER TABLE ONLY public.agendamento_descricao_categoria_global
    ADD CONSTRAINT fk_descricao_categoria_configuracao FOREIGN KEY (descricao_categoria_configuracao_id) REFERENCES public.descricao_lancamento_new_categoria_lancamento_new_configuracao(id);
 t   ALTER TABLE ONLY public.agendamento_descricao_categoria_global DROP CONSTRAINT fk_descricao_categoria_configuracao;
       public       postgres    false    4620    351    221                       2606    19494 j   descricao_lancamento_new_categoria_lancamento_new_configuracao fk_descricao_categoria_configuracao_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.descricao_lancamento_new_categoria_lancamento_new_configuracao
    ADD CONSTRAINT fk_descricao_categoria_configuracao_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 �   ALTER TABLE ONLY public.descricao_lancamento_new_categoria_lancamento_new_configuracao DROP CONSTRAINT fk_descricao_categoria_configuracao_usuario;
       public       postgres    false    351    628    4926                       2606    19499 2   descricao_lancamento fk_descricao_lancamento_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.descricao_lancamento
    ADD CONSTRAINT fk_descricao_lancamento_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 \   ALTER TABLE ONLY public.descricao_lancamento DROP CONSTRAINT fk_descricao_lancamento_banco;
       public       postgres    false    348    247    4492                       2606    19504 A   descricao_lancamento fk_descricao_lancamento_categoria_lancamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.descricao_lancamento
    ADD CONSTRAINT fk_descricao_lancamento_categoria_lancamento FOREIGN KEY (categoria_lancamento_id) REFERENCES public.categoria_lancamento(id);
 k   ALTER TABLE ONLY public.descricao_lancamento DROP CONSTRAINT fk_descricao_lancamento_categoria_lancamento;
       public       postgres    false    348    260    4500                       2606    19509 4   descricao_lancamento fk_descricao_lancamento_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.descricao_lancamento
    ADD CONSTRAINT fk_descricao_lancamento_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 ^   ALTER TABLE ONLY public.descricao_lancamento DROP CONSTRAINT fk_descricao_lancamento_empresa;
       public       postgres    false    360    348    4628                       2606    19514 :   descricao_lancamento_new fk_descricao_lancamento_new_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.descricao_lancamento_new
    ADD CONSTRAINT fk_descricao_lancamento_new_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 d   ALTER TABLE ONLY public.descricao_lancamento_new DROP CONSTRAINT fk_descricao_lancamento_new_banco;
       public       postgres    false    247    350    4492                       2606    19519 I   descricao_lancamento_new fk_descricao_lancamento_new_categoria_lancamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.descricao_lancamento_new
    ADD CONSTRAINT fk_descricao_lancamento_new_categoria_lancamento FOREIGN KEY (categoria_lancamento_id) REFERENCES public.categoria_lancamento_new(id);
 s   ALTER TABLE ONLY public.descricao_lancamento_new DROP CONSTRAINT fk_descricao_lancamento_new_categoria_lancamento;
       public       postgres    false    350    261    4502                       2606    19524 g   descricao_lancamento_new_categoria_lancamento_new_configuracao fk_descricao_lancamento_new_configuracao    FK CONSTRAINT     �   ALTER TABLE ONLY public.descricao_lancamento_new_categoria_lancamento_new_configuracao
    ADD CONSTRAINT fk_descricao_lancamento_new_configuracao FOREIGN KEY (descricao_lancamento_new_id) REFERENCES public.descricao_lancamento_new(id);
 �   ALTER TABLE ONLY public.descricao_lancamento_new_categoria_lancamento_new_configuracao DROP CONSTRAINT fk_descricao_lancamento_new_configuracao;
       public       postgres    false    351    350    4618                       2606    19529 <   descricao_lancamento_new fk_descricao_lancamento_new_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.descricao_lancamento_new
    ADD CONSTRAINT fk_descricao_lancamento_new_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 f   ALTER TABLE ONLY public.descricao_lancamento_new DROP CONSTRAINT fk_descricao_lancamento_new_empresa;
       public       postgres    false    4628    350    360                       2606    19534    download fk_download_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.download
    ADD CONSTRAINT fk_download_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 F   ALTER TABLE ONLY public.download DROP CONSTRAINT fk_download_usuario;
       public       postgres    false    628    356    4926                       2606    19539    email fk_email_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.email
    ADD CONSTRAINT fk_email_empresa FOREIGN KEY (grupo_empresa_id) REFERENCES public.grupo_empresa(id);
 @   ALTER TABLE ONLY public.email DROP CONSTRAINT fk_email_empresa;
       public       postgres    false    403    358    4672            �           2606    19544    card fk_empresa    FK CONSTRAINT     s   ALTER TABLE ONLY public.card
    ADD CONSTRAINT fk_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 9   ALTER TABLE ONLY public.card DROP CONSTRAINT fk_empresa;
       public       postgres    false    257    360    4628            �           2606    19549    tipo_conta_pagar fk_empresa    FK CONSTRAINT        ALTER TABLE ONLY public.tipo_conta_pagar
    ADD CONSTRAINT fk_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 E   ALTER TABLE ONLY public.tipo_conta_pagar DROP CONSTRAINT fk_empresa;
       public       postgres    false    4628    360    590            �           2606    19554    conta_pagar fk_empresa    FK CONSTRAINT     z   ALTER TABLE ONLY public.conta_pagar
    ADD CONSTRAINT fk_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 @   ALTER TABLE ONLY public.conta_pagar DROP CONSTRAINT fk_empresa;
       public       postgres    false    360    302    4628            �           2606    19559    loja fk_empresa    FK CONSTRAINT     s   ALTER TABLE ONLY public.loja
    ADD CONSTRAINT fk_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 9   ALTER TABLE ONLY public.loja DROP CONSTRAINT fk_empresa;
       public       postgres    false    482    4628    360            �           2606    19564 &   recolhimento_transportadora fk_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.recolhimento_transportadora
    ADD CONSTRAINT fk_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 P   ALTER TABLE ONLY public.recolhimento_transportadora DROP CONSTRAINT fk_empresa;
       public       postgres    false    558    4628    360            �           2606    19569 1   agendamento_descricao_categoria_global fk_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.agendamento_descricao_categoria_global
    ADD CONSTRAINT fk_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 [   ALTER TABLE ONLY public.agendamento_descricao_categoria_global DROP CONSTRAINT fk_empresa;
       public       postgres    false    221    4628    360                       2606    19574    empresa fk_empresa_cidade    FK CONSTRAINT     {   ALTER TABLE ONLY public.empresa
    ADD CONSTRAINT fk_empresa_cidade FOREIGN KEY (cidade_id) REFERENCES public.cidade(id);
 C   ALTER TABLE ONLY public.empresa DROP CONSTRAINT fk_empresa_cidade;
       public       postgres    false    360    4510    268                       2606    19579    empresa fk_empresa_estado    FK CONSTRAINT     {   ALTER TABLE ONLY public.empresa
    ADD CONSTRAINT fk_empresa_estado FOREIGN KEY (estado_id) REFERENCES public.estado(id);
 C   ALTER TABLE ONLY public.empresa DROP CONSTRAINT fk_empresa_estado;
       public       postgres    false    4634    367    360            5           2606    19584    grupo fk_empresa_grupo    FK CONSTRAINT     z   ALTER TABLE ONLY public.grupo
    ADD CONSTRAINT fk_empresa_grupo FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 @   ALTER TABLE ONLY public.grupo DROP CONSTRAINT fk_empresa_grupo;
       public       postgres    false    4628    360    399                        2606    19589     empresa fk_empresa_grupo_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.empresa
    ADD CONSTRAINT fk_empresa_grupo_empresa FOREIGN KEY (grupo_empresa_id) REFERENCES public.grupo_empresa(id);
 J   ALTER TABLE ONLY public.empresa DROP CONSTRAINT fk_empresa_grupo_empresa;
       public       postgres    false    403    360    4672            V           2606    35399 ;   pre_controle_execucao_conciliacao_bancaria_v2 fk_empresa_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.pre_controle_execucao_conciliacao_bancaria_v2
    ADD CONSTRAINT fk_empresa_id FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 e   ALTER TABLE ONLY public.pre_controle_execucao_conciliacao_bancaria_v2 DROP CONSTRAINT fk_empresa_id;
       public       bv_postgres    false    667    360    4628            #           2606    19594 E   emprestimo_processamento fk_emprestimo_processamento_processamento_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.emprestimo_processamento
    ADD CONSTRAINT fk_emprestimo_processamento_processamento_id FOREIGN KEY (processamento_otimiza_id) REFERENCES public.processamento_otimiza(id);
 o   ALTER TABLE ONLY public.emprestimo_processamento DROP CONSTRAINT fk_emprestimo_processamento_processamento_id;
       public       postgres    false    4835    366    551            �           2606    19599    loja fk_estado    FK CONSTRAINT     p   ALTER TABLE ONLY public.loja
    ADD CONSTRAINT fk_estado FOREIGN KEY (estado_id) REFERENCES public.estado(id);
 8   ALTER TABLE ONLY public.loja DROP CONSTRAINT fk_estado;
       public       postgres    false    482    4634    367                       2606    19604    transportadora fk_estado    FK CONSTRAINT     z   ALTER TABLE ONLY public.transportadora
    ADD CONSTRAINT fk_estado FOREIGN KEY (estado_id) REFERENCES public.estado(id);
 B   ALTER TABLE ONLY public.transportadora DROP CONSTRAINT fk_estado;
       public       postgres    false    4634    367    622            $           2606    19609    faixa_cep fk_faixa_cep_estado    FK CONSTRAINT        ALTER TABLE ONLY public.faixa_cep
    ADD CONSTRAINT fk_faixa_cep_estado FOREIGN KEY (estado_id) REFERENCES public.estado(id);
 G   ALTER TABLE ONLY public.faixa_cep DROP CONSTRAINT fk_faixa_cep_estado;
       public       postgres    false    367    369    4634            �           2606    19614    conta_pagar fk_favorecido    FK CONSTRAINT     �   ALTER TABLE ONLY public.conta_pagar
    ADD CONSTRAINT fk_favorecido FOREIGN KEY (favorecido_id) REFERENCES public.favorecido(id);
 C   ALTER TABLE ONLY public.conta_pagar DROP CONSTRAINT fk_favorecido;
       public       postgres    false    4644    378    302            (           2606    19619    favorecido fk_favorecido_banco    FK CONSTRAINT     ~   ALTER TABLE ONLY public.favorecido
    ADD CONSTRAINT fk_favorecido_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 H   ALTER TABLE ONLY public.favorecido DROP CONSTRAINT fk_favorecido_banco;
       public       postgres    false    4492    378    247            )           2606    19624    favorecido fk_favorecido_cidade    FK CONSTRAINT     �   ALTER TABLE ONLY public.favorecido
    ADD CONSTRAINT fk_favorecido_cidade FOREIGN KEY (cidade_id) REFERENCES public.cidade(id);
 I   ALTER TABLE ONLY public.favorecido DROP CONSTRAINT fk_favorecido_cidade;
       public       postgres    false    268    4510    378            *           2606    19629    favorecido fk_favorecido_estado    FK CONSTRAINT     �   ALTER TABLE ONLY public.favorecido
    ADD CONSTRAINT fk_favorecido_estado FOREIGN KEY (estado_id) REFERENCES public.estado(id);
 I   ALTER TABLE ONLY public.favorecido DROP CONSTRAINT fk_favorecido_estado;
       public       postgres    false    367    4634    378            +           2606    19634    favorecido fk_favorecido_grupo    FK CONSTRAINT     ~   ALTER TABLE ONLY public.favorecido
    ADD CONSTRAINT fk_favorecido_grupo FOREIGN KEY (grupo_id) REFERENCES public.grupo(id);
 H   ALTER TABLE ONLY public.favorecido DROP CONSTRAINT fk_favorecido_grupo;
       public       postgres    false    4668    399    378            1           2606    19639 (   forma_pagamento fk_forma_pagamento_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.forma_pagamento
    ADD CONSTRAINT fk_forma_pagamento_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 R   ALTER TABLE ONLY public.forma_pagamento DROP CONSTRAINT fk_forma_pagamento_banco;
       public       postgres    false    247    388    4492            7           2606    19644 @   grupo_autorizacao_convenio_usuario fk_grupo_autorizacao_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_autorizacao_convenio_usuario
    ADD CONSTRAINT fk_grupo_autorizacao_convenio FOREIGN KEY (grupo_autorizacao_convenio_id) REFERENCES public.grupo_autorizacao_convenio(id);
 j   ALTER TABLE ONLY public.grupo_autorizacao_convenio_usuario DROP CONSTRAINT fk_grupo_autorizacao_convenio;
       public       postgres    false    4670    400    402            6           2606    19649 A   grupo_autorizacao_convenio fk_grupo_autorizacao_convenio_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_autorizacao_convenio
    ADD CONSTRAINT fk_grupo_autorizacao_convenio_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 k   ALTER TABLE ONLY public.grupo_autorizacao_convenio DROP CONSTRAINT fk_grupo_autorizacao_convenio_convenio;
       public       postgres    false    400    334    4595            8           2606    19654 H   grupo_autorizacao_convenio_usuario fk_grupo_autorizacao_convenio_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_autorizacao_convenio_usuario
    ADD CONSTRAINT fk_grupo_autorizacao_convenio_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 r   ALTER TABLE ONLY public.grupo_autorizacao_convenio_usuario DROP CONSTRAINT fk_grupo_autorizacao_convenio_usuario;
       public       postgres    false    628    402    4926            �           2606    19659    card fk_grupo_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.card
    ADD CONSTRAINT fk_grupo_empresa FOREIGN KEY (grupo_empresa_id) REFERENCES public.grupo_empresa(id);
 ?   ALTER TABLE ONLY public.card DROP CONSTRAINT fk_grupo_empresa;
       public       postgres    false    403    257    4672            9           2606    19664 9   grupo_lancamento fk_grupo_lancamento_categoria_lancamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_lancamento
    ADD CONSTRAINT fk_grupo_lancamento_categoria_lancamento FOREIGN KEY (categoria_lancamento_id) REFERENCES public.categoria_lancamento_new(id);
 c   ALTER TABLE ONLY public.grupo_lancamento DROP CONSTRAINT fk_grupo_lancamento_categoria_lancamento;
       public       postgres    false    4502    407    261            :           2606    19669 *   grupo_lancamento fk_grupo_lancamento_conta    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_lancamento
    ADD CONSTRAINT fk_grupo_lancamento_conta FOREIGN KEY (conta_id) REFERENCES public.conta(id);
 T   ALTER TABLE ONLY public.grupo_lancamento DROP CONSTRAINT fk_grupo_lancamento_conta;
       public       postgres    false    296    4547    407            ;           2606    19674 2   grupo_lancamento fk_grupo_lancamento_tarifa_origem    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_lancamento
    ADD CONSTRAINT fk_grupo_lancamento_tarifa_origem FOREIGN KEY (tarifa_origem_id) REFERENCES public.tarifa_origem(id);
 \   ALTER TABLE ONLY public.grupo_lancamento DROP CONSTRAINT fk_grupo_lancamento_tarifa_origem;
       public       postgres    false    581    4868    407            <           2606    19679 2   grupo_lancamento fk_grupo_lancamento_tipo_operacao    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_lancamento
    ADD CONSTRAINT fk_grupo_lancamento_tipo_operacao FOREIGN KEY (tipo_operacao_id) REFERENCES public.tipo_operacao_cesta_servico(id);
 \   ALTER TABLE ONLY public.grupo_lancamento DROP CONSTRAINT fk_grupo_lancamento_tipo_operacao;
       public       postgres    false    597    407    4885            =           2606    19684 ,   grupo_lancamento fk_grupo_lancamento_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_lancamento
    ADD CONSTRAINT fk_grupo_lancamento_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 V   ALTER TABLE ONLY public.grupo_lancamento DROP CONSTRAINT fk_grupo_lancamento_usuario;
       public       postgres    false    407    4926    628            C           2606    19689 2   grupo_pagamento fk_grupo_pagamento_forma_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_pagamento
    ADD CONSTRAINT fk_grupo_pagamento_forma_pagamento FOREIGN KEY (forma_pagamento_id) REFERENCES public.forma_pagamento(id);
 \   ALTER TABLE ONLY public.grupo_pagamento DROP CONSTRAINT fk_grupo_pagamento_forma_pagamento;
       public       postgres    false    4655    388    413            D           2606    19694 ,   grupo_pagamento fk_grupo_pagamento_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_pagamento
    ADD CONSTRAINT fk_grupo_pagamento_pagamento FOREIGN KEY (pagamento_id) REFERENCES public.pagamento(id);
 V   ALTER TABLE ONLY public.grupo_pagamento DROP CONSTRAINT fk_grupo_pagamento_pagamento;
       public       postgres    false    413    4817    531            E           2606    19699 /   grupo_pagamento fk_grupo_pagamento_tipo_servico    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_pagamento
    ADD CONSTRAINT fk_grupo_pagamento_tipo_servico FOREIGN KEY (tipo_servico_id) REFERENCES public.tipo_servico(id);
 Y   ALTER TABLE ONLY public.grupo_pagamento DROP CONSTRAINT fk_grupo_pagamento_tipo_servico;
       public       postgres    false    601    413    4891            F           2606    19704 *   grupo_pagamento fk_grupo_pagamento_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_pagamento
    ADD CONSTRAINT fk_grupo_pagamento_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 T   ALTER TABLE ONLY public.grupo_pagamento DROP CONSTRAINT fk_grupo_pagamento_usuario;
       public       postgres    false    413    628    4926            G           2606    19709 $   grupo_sacado fk_grupo_sacado_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_sacado
    ADD CONSTRAINT fk_grupo_sacado_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 N   ALTER TABLE ONLY public.grupo_sacado DROP CONSTRAINT fk_grupo_sacado_empresa;
       public       postgres    false    415    4628    360            H           2606    19714 ,   grupo_sacado_ext fk_grupo_sacado_ext_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_sacado_ext
    ADD CONSTRAINT fk_grupo_sacado_ext_empresa FOREIGN KEY (grupo_sacado_id) REFERENCES public.grupo_sacado(id);
 V   ALTER TABLE ONLY public.grupo_sacado_ext DROP CONSTRAINT fk_grupo_sacado_ext_empresa;
       public       postgres    false    416    4688    415            I           2606    19719 +   grupo_sacado_ext fk_grupo_sacado_ext_sacado    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_sacado_ext
    ADD CONSTRAINT fk_grupo_sacado_ext_sacado FOREIGN KEY (sacado_id) REFERENCES public.sacado(id);
 U   ALTER TABLE ONLY public.grupo_sacado_ext DROP CONSTRAINT fk_grupo_sacado_ext_sacado;
       public       postgres    false    4853    570    416            J           2606    19724 %   grupo_titulo fk_grupo_titulo_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_titulo
    ADD CONSTRAINT fk_grupo_titulo_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 O   ALTER TABLE ONLY public.grupo_titulo DROP CONSTRAINT fk_grupo_titulo_convenio;
       public       postgres    false    334    418    4595            K           2606    19729 .   grupo_titulo fk_grupo_titulo_movimento_retorno    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_titulo
    ADD CONSTRAINT fk_grupo_titulo_movimento_retorno FOREIGN KEY (movimento_retorno_cobranca_id) REFERENCES public.movimento_retorno_cobranca(id);
 X   ALTER TABLE ONLY public.grupo_titulo DROP CONSTRAINT fk_grupo_titulo_movimento_retorno;
       public       postgres    false    4789    418    507            L           2606    19734 $   grupo_titulo fk_grupo_titulo_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_titulo
    ADD CONSTRAINT fk_grupo_titulo_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 N   ALTER TABLE ONLY public.grupo_titulo DROP CONSTRAINT fk_grupo_titulo_usuario;
       public       postgres    false    418    628    4926            Q           2606    19739 <   historico_monitoramento fk_historico_monitoramento_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.historico_monitoramento
    ADD CONSTRAINT fk_historico_monitoramento_pagamento FOREIGN KEY (pagamento_id) REFERENCES public.pagamento(id);
 f   ALTER TABLE ONLY public.historico_monitoramento DROP CONSTRAINT fk_historico_monitoramento_pagamento;
       public       postgres    false    531    4817    426            R           2606    19744 :   historico_monitoramento fk_historico_monitoramento_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.historico_monitoramento
    ADD CONSTRAINT fk_historico_monitoramento_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 d   ALTER TABLE ONLY public.historico_monitoramento DROP CONSTRAINT fk_historico_monitoramento_usuario;
       public       postgres    false    426    4926    628            _           2606    19749 H   item_contrato_bancario_pendente fk_item_contrato_bancario_pendente_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_bancario_pendente
    ADD CONSTRAINT fk_item_contrato_bancario_pendente_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 r   ALTER TABLE ONLY public.item_contrato_bancario_pendente DROP CONSTRAINT fk_item_contrato_bancario_pendente_banco;
       public       postgres    false    247    4492    447            `           2606    19754 H   item_contrato_bancario_pendente fk_item_contrato_bancario_pendente_conta    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_bancario_pendente
    ADD CONSTRAINT fk_item_contrato_bancario_pendente_conta FOREIGN KEY (conta_id) REFERENCES public.conta(id);
 r   ALTER TABLE ONLY public.item_contrato_bancario_pendente DROP CONSTRAINT fk_item_contrato_bancario_pendente_conta;
       public       postgres    false    296    447    4547            a           2606    19759 K   item_contrato_bancario_pendente fk_item_contrato_bancario_pendente_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_bancario_pendente
    ADD CONSTRAINT fk_item_contrato_bancario_pendente_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 u   ALTER TABLE ONLY public.item_contrato_bancario_pendente DROP CONSTRAINT fk_item_contrato_bancario_pendente_convenio;
       public       postgres    false    334    4595    447            b           2606    19764 J   item_contrato_bancario_pendente fk_item_contrato_bancario_pendente_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_bancario_pendente
    ADD CONSTRAINT fk_item_contrato_bancario_pendente_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 t   ALTER TABLE ONLY public.item_contrato_bancario_pendente DROP CONSTRAINT fk_item_contrato_bancario_pendente_empresa;
       public       postgres    false    360    447    4628            c           2606    19769 C   item_contrato_cesta_servico fk_item_contrato_cesta_servico_contrato    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_cesta_servico
    ADD CONSTRAINT fk_item_contrato_cesta_servico_contrato FOREIGN KEY (contrato_id) REFERENCES public.contrato(id);
 m   ALTER TABLE ONLY public.item_contrato_cesta_servico DROP CONSTRAINT fk_item_contrato_cesta_servico_contrato;
       public       postgres    false    307    4559    448            f           2606    19774 9   item_contrato_cobranca fk_item_contrato_cobranca_contrato    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_cobranca
    ADD CONSTRAINT fk_item_contrato_cobranca_contrato FOREIGN KEY (contrato_id) REFERENCES public.contrato(id);
 c   ALTER TABLE ONLY public.item_contrato_cobranca DROP CONSTRAINT fk_item_contrato_cobranca_contrato;
       public       postgres    false    452    4559    307            g           2606    19779 :   item_contrato_cobranca fk_item_contrato_cobranca_movimento    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_cobranca
    ADD CONSTRAINT fk_item_contrato_cobranca_movimento FOREIGN KEY (movimento_retorno_cobranca_id) REFERENCES public.movimento_retorno_cobranca(id);
 d   ALTER TABLE ONLY public.item_contrato_cobranca DROP CONSTRAINT fk_item_contrato_cobranca_movimento;
       public       postgres    false    507    452    4789            h           2606    19784 ;   item_contrato_cobranca fk_item_contrato_cobranca_ocorrencia    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_cobranca
    ADD CONSTRAINT fk_item_contrato_cobranca_ocorrencia FOREIGN KEY (ocorrencia_cobranca_id) REFERENCES public.ocorrencia_cobranca(id);
 e   ALTER TABLE ONLY public.item_contrato_cobranca DROP CONSTRAINT fk_item_contrato_cobranca_ocorrencia;
       public       postgres    false    452    4809    523            k           2606    19789 7   item_contrato_numerario_loja fk_item_contrato_numerario    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_numerario_loja
    ADD CONSTRAINT fk_item_contrato_numerario FOREIGN KEY (item_contrato_numerario_id) REFERENCES public.item_contrato_numerario(id);
 a   ALTER TABLE ONLY public.item_contrato_numerario_loja DROP CONSTRAINT fk_item_contrato_numerario;
       public       postgres    false    4725    453    455            m           2606    19794 ;   item_contrato_pagamento fk_item_contrato_pagamento_contrato    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_pagamento
    ADD CONSTRAINT fk_item_contrato_pagamento_contrato FOREIGN KEY (contrato_id) REFERENCES public.contrato(id);
 e   ALTER TABLE ONLY public.item_contrato_pagamento DROP CONSTRAINT fk_item_contrato_pagamento_contrato;
       public       postgres    false    307    4559    457            n           2606    19799 B   item_contrato_pagamento fk_item_contrato_pagamento_forma_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_pagamento
    ADD CONSTRAINT fk_item_contrato_pagamento_forma_pagamento FOREIGN KEY (forma_pagamento_id) REFERENCES public.forma_pagamento(id);
 l   ALTER TABLE ONLY public.item_contrato_pagamento DROP CONSTRAINT fk_item_contrato_pagamento_forma_pagamento;
       public       postgres    false    388    4655    457            d           2606    19804 H   item_contrato_cesta_servico fk_item_tarifa_origem_cesta_servico_contrato    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_cesta_servico
    ADD CONSTRAINT fk_item_tarifa_origem_cesta_servico_contrato FOREIGN KEY (tarifa_origem_id) REFERENCES public.tarifa_origem(id);
 r   ALTER TABLE ONLY public.item_contrato_cesta_servico DROP CONSTRAINT fk_item_tarifa_origem_cesta_servico_contrato;
       public       postgres    false    448    4868    581            e           2606    19809 V   item_contrato_cesta_servico fk_item_tipo_operacao_cesta_servico_cesta_servico_contrato    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_cesta_servico
    ADD CONSTRAINT fk_item_tipo_operacao_cesta_servico_cesta_servico_contrato FOREIGN KEY (tipo_operacao_cesta_servico_id) REFERENCES public.tipo_operacao_cesta_servico(id);
 �   ALTER TABLE ONLY public.item_contrato_cesta_servico DROP CONSTRAINT fk_item_tipo_operacao_cesta_servico_cesta_servico_contrato;
       public       postgres    false    4885    448    597            H           2606    34680 <   lancamento_auxiliar_cash fk_lancamento_auxiliar_cash_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_auxiliar_cash
    ADD CONSTRAINT fk_lancamento_auxiliar_cash_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 f   ALTER TABLE ONLY public.lancamento_auxiliar_cash DROP CONSTRAINT fk_lancamento_auxiliar_cash_empresa;
       public       postgres    false    360    4628    660            I           2606    34685 9   lancamento_auxiliar_cash fk_lancamento_auxiliar_cash_loja    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_auxiliar_cash
    ADD CONSTRAINT fk_lancamento_auxiliar_cash_loja FOREIGN KEY (loja_id) REFERENCES public.loja(id);
 c   ALTER TABLE ONLY public.lancamento_auxiliar_cash DROP CONSTRAINT fk_lancamento_auxiliar_cash_loja;
       public       postgres    false    482    660    4761            z           2606    19814 "   lancamento_new fk_lancamento_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_new
    ADD CONSTRAINT fk_lancamento_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 L   ALTER TABLE ONLY public.lancamento_new DROP CONSTRAINT fk_lancamento_banco;
       public       postgres    false    466    4492    247            {           2606    19819 %   lancamento_new fk_lancamento_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_new
    ADD CONSTRAINT fk_lancamento_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 O   ALTER TABLE ONLY public.lancamento_new DROP CONSTRAINT fk_lancamento_convenio;
       public       postgres    false    334    466    4595            p           2606    19824 6   lancamento_debito fk_lancamento_debito_optantes_debito    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_debito
    ADD CONSTRAINT fk_lancamento_debito_optantes_debito FOREIGN KEY (optantes_debito_id) REFERENCES public.optantes_debito(id);
 `   ALTER TABLE ONLY public.lancamento_debito DROP CONSTRAINT fk_lancamento_debito_optantes_debito;
       public       postgres    false    4815    460    528            q           2606    19829 W   lancamento_debito_remessa fk_lancamento_debito_remessa_controle_remessa_optantes_debito    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_debito_remessa
    ADD CONSTRAINT fk_lancamento_debito_remessa_controle_remessa_optantes_debito FOREIGN KEY (controle_remessa_optantes_debito_id) REFERENCES public.controle_remessa_optantes_debito(id);
 �   ALTER TABLE ONLY public.lancamento_debito_remessa DROP CONSTRAINT fk_lancamento_debito_remessa_controle_remessa_optantes_debito;
       public       postgres    false    4589    462    328            r           2606    19834 H   lancamento_debito_remessa fk_lancamento_debito_remessa_lancamento_debito    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_debito_remessa
    ADD CONSTRAINT fk_lancamento_debito_remessa_lancamento_debito FOREIGN KEY (lancamento_debito_id) REFERENCES public.lancamento_debito(id);
 r   ALTER TABLE ONLY public.lancamento_debito_remessa DROP CONSTRAINT fk_lancamento_debito_remessa_lancamento_debito;
       public       postgres    false    460    462    4733            |           2606    19839 &   lancamento_new fk_lancamento_descricao    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_new
    ADD CONSTRAINT fk_lancamento_descricao FOREIGN KEY (descricao_id) REFERENCES public.descricao_lancamento_new(id) ON DELETE CASCADE;
 P   ALTER TABLE ONLY public.lancamento_new DROP CONSTRAINT fk_lancamento_descricao;
       public       postgres    false    466    350    4618            }           2606    19844 $   lancamento_new fk_lancamento_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_new
    ADD CONSTRAINT fk_lancamento_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 N   ALTER TABLE ONLY public.lancamento_new DROP CONSTRAINT fk_lancamento_empresa;
       public       postgres    false    466    4628    360            ~           2606    19849 +   lancamento_new fk_lancamento_usuario_logado    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_new
    ADD CONSTRAINT fk_lancamento_usuario_logado FOREIGN KEY (usuario_logado_id) REFERENCES public.usuario(id);
 U   ALTER TABLE ONLY public.lancamento_new DROP CONSTRAINT fk_lancamento_usuario_logado;
       public       postgres    false    4926    466    628                       2606    19854 #   lancamento_new fk_lancamentos_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_new
    ADD CONSTRAINT fk_lancamentos_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 M   ALTER TABLE ONLY public.lancamento_new DROP CONSTRAINT fk_lancamentos_banco;
       public       postgres    false    247    4492    466            �           2606    19859 &   lancamento_new fk_lancamentos_conta_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_new
    ADD CONSTRAINT fk_lancamentos_conta_id FOREIGN KEY (conta_id) REFERENCES public.conta(id);
 P   ALTER TABLE ONLY public.lancamento_new DROP CONSTRAINT fk_lancamentos_conta_id;
       public       postgres    false    296    4547    466            �           2606    19864 &   lancamento_new fk_lancamentos_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_new
    ADD CONSTRAINT fk_lancamentos_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 P   ALTER TABLE ONLY public.lancamento_new DROP CONSTRAINT fk_lancamentos_convenio;
       public       postgres    false    466    334    4595            s           2606    19869 F   lancamento_duplicado fk_lancamentos_duplicados_controle_upload_arquivo    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_duplicado
    ADD CONSTRAINT fk_lancamentos_duplicados_controle_upload_arquivo FOREIGN KEY (controle_upload_arquivo_id) REFERENCES public.controle_upload_arquivo(id) ON DELETE CASCADE;
 p   ALTER TABLE ONLY public.lancamento_duplicado DROP CONSTRAINT fk_lancamentos_duplicados_controle_upload_arquivo;
       public       postgres    false    332    464    4593            t           2606    19874 9   lancamento_duplicado fk_lancamentos_duplicados_lancamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_duplicado
    ADD CONSTRAINT fk_lancamentos_duplicados_lancamento FOREIGN KEY (lancamento_id) REFERENCES public.lancamento_new(id) ON DELETE CASCADE;
 c   ALTER TABLE ONLY public.lancamento_duplicado DROP CONSTRAINT fk_lancamentos_duplicados_lancamento;
       public       postgres    false    466    464    4741            �           2606    19879 %   lancamento_new fk_lancamentos_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_new
    ADD CONSTRAINT fk_lancamentos_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 O   ALTER TABLE ONLY public.lancamento_new DROP CONSTRAINT fk_lancamentos_empresa;
       public       postgres    false    4628    466    360            �           2606    19884 %   lancamento_new fk_lancamentos_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_new
    ADD CONSTRAINT fk_lancamentos_usuario FOREIGN KEY (usuario_logado_id) REFERENCES public.usuario(id);
 O   ALTER TABLE ONLY public.lancamento_new DROP CONSTRAINT fk_lancamentos_usuario;
       public       postgres    false    628    4926    466            �           2606    19889 "   layout_campo fk_layout_campo_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.layout_campo
    ADD CONSTRAINT fk_layout_campo_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 L   ALTER TABLE ONLY public.layout_campo DROP CONSTRAINT fk_layout_campo_banco;
       public       postgres    false    4492    468    247            �           2606    19894 <   layout_campo_pagamento fk_layout_campo_pagamento_compromisso    FK CONSTRAINT     �   ALTER TABLE ONLY public.layout_campo_pagamento
    ADD CONSTRAINT fk_layout_campo_pagamento_compromisso FOREIGN KEY (compromisso_id) REFERENCES public.compromisso(id);
 f   ALTER TABLE ONLY public.layout_campo_pagamento DROP CONSTRAINT fk_layout_campo_pagamento_compromisso;
       public       postgres    false    282    470    4524            �           2606    19899 8   layout_campo_pagamento fk_layout_campo_pagamento_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.layout_campo_pagamento
    ADD CONSTRAINT fk_layout_campo_pagamento_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 b   ALTER TABLE ONLY public.layout_campo_pagamento DROP CONSTRAINT fk_layout_campo_pagamento_empresa;
       public       postgres    false    470    4628    360            �           2606    19904 &   log_acesso fk_log_acesso_grupo_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.log_acesso
    ADD CONSTRAINT fk_log_acesso_grupo_empresa FOREIGN KEY (grupo_empresa_id) REFERENCES public.grupo_empresa(id);
 P   ALTER TABLE ONLY public.log_acesso DROP CONSTRAINT fk_log_acesso_grupo_empresa;
       public       postgres    false    474    4672    403            �           2606    19909     log_acesso fk_log_acesso_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.log_acesso
    ADD CONSTRAINT fk_log_acesso_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 J   ALTER TABLE ONLY public.log_acesso DROP CONSTRAINT fk_log_acesso_usuario;
       public       postgres    false    4926    628    474            �           2606    19914 4   log_erro_processador fk_log_erro_processador_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.log_erro_processador
    ADD CONSTRAINT fk_log_erro_processador_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 ^   ALTER TABLE ONLY public.log_erro_processador DROP CONSTRAINT fk_log_erro_processador_empresa;
       public       postgres    false    4628    480    360            �           2606    19919 #   recolhimento_transportadora fk_loja    FK CONSTRAINT     �   ALTER TABLE ONLY public.recolhimento_transportadora
    ADD CONSTRAINT fk_loja FOREIGN KEY (loja_id) REFERENCES public.loja(id);
 M   ALTER TABLE ONLY public.recolhimento_transportadora DROP CONSTRAINT fk_loja;
       public       postgres    false    558    4761    482            �           2606    19924    contrato_loja fk_loja    FK CONSTRAINT     s   ALTER TABLE ONLY public.contrato_loja
    ADD CONSTRAINT fk_loja FOREIGN KEY (loja_id) REFERENCES public.loja(id);
 ?   ALTER TABLE ONLY public.contrato_loja DROP CONSTRAINT fk_loja;
       public       postgres    false    482    4761    312            l           2606    19929 $   item_contrato_numerario_loja fk_loja    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_numerario_loja
    ADD CONSTRAINT fk_loja FOREIGN KEY (loja_id) REFERENCES public.loja(id);
 N   ALTER TABLE ONLY public.item_contrato_numerario_loja DROP CONSTRAINT fk_loja;
       public       postgres    false    455    482    4761            �           2606    19934 $   lote_carne fk_lote_carne_convenio_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.lote_carne
    ADD CONSTRAINT fk_lote_carne_convenio_id FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 N   ALTER TABLE ONLY public.lote_carne DROP CONSTRAINT fk_lote_carne_convenio_id;
       public       postgres    false    488    334    4595            �           2606    19939 ,   lote_carne fk_lote_carne_titulo_associado_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.lote_carne
    ADD CONSTRAINT fk_lote_carne_titulo_associado_id FOREIGN KEY (titulo_associado_id) REFERENCES public.titulo(id);
 V   ALTER TABLE ONLY public.lote_carne DROP CONSTRAINT fk_lote_carne_titulo_associado_id;
       public       postgres    false    4894    488    602            �           2606    19944 "   lote_carne fk_lote_carne_titulo_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.lote_carne
    ADD CONSTRAINT fk_lote_carne_titulo_id FOREIGN KEY (titulo_id) REFERENCES public.titulo(id);
 L   ALTER TABLE ONLY public.lote_carne DROP CONSTRAINT fk_lote_carne_titulo_id;
       public       postgres    false    4894    602    488            �           2606    19949 "   lote_favorecido fk_lote_favorecido    FK CONSTRAINT     �   ALTER TABLE ONLY public.lote_favorecido
    ADD CONSTRAINT fk_lote_favorecido FOREIGN KEY (favorecido_id) REFERENCES public.favorecido(id);
 L   ALTER TABLE ONLY public.lote_favorecido DROP CONSTRAINT fk_lote_favorecido;
       public       postgres    false    490    4644    378            �           2606    19954 (   lote_favorecido fk_lote_favorecido_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.lote_favorecido
    ADD CONSTRAINT fk_lote_favorecido_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 R   ALTER TABLE ONLY public.lote_favorecido DROP CONSTRAINT fk_lote_favorecido_banco;
       public       postgres    false    4492    490    247            �           2606    19959 ,   lote_favorecido fk_lote_favorecido_chave_pix    FK CONSTRAINT     �   ALTER TABLE ONLY public.lote_favorecido
    ADD CONSTRAINT fk_lote_favorecido_chave_pix FOREIGN KEY (chave_pix_id) REFERENCES public.chave_pix(id);
 V   ALTER TABLE ONLY public.lote_favorecido DROP CONSTRAINT fk_lote_favorecido_chave_pix;
       public       postgres    false    490    4504    265            �           2606    19964 '   lote_favorecido fk_lote_forma_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.lote_favorecido
    ADD CONSTRAINT fk_lote_forma_pagamento FOREIGN KEY (forma_pagamento_id) REFERENCES public.forma_pagamento(id);
 Q   ALTER TABLE ONLY public.lote_favorecido DROP CONSTRAINT fk_lote_forma_pagamento;
       public       postgres    false    4655    388    490            �           2606    19969 '   lote_pag_aux fk_lote_pag_aux_favorecido    FK CONSTRAINT     �   ALTER TABLE ONLY public.lote_pag_aux
    ADD CONSTRAINT fk_lote_pag_aux_favorecido FOREIGN KEY (lote_favorecido_id) REFERENCES public.lote_favorecido(id);
 Q   ALTER TABLE ONLY public.lote_pag_aux DROP CONSTRAINT fk_lote_pag_aux_favorecido;
       public       postgres    false    490    493    4767            �           2606    19974 &   lote_pag_aux fk_lote_pag_aux_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.lote_pag_aux
    ADD CONSTRAINT fk_lote_pag_aux_pagamento FOREIGN KEY (pagamento_id) REFERENCES public.pagamento(id);
 P   ALTER TABLE ONLY public.lote_pag_aux DROP CONSTRAINT fk_lote_pag_aux_pagamento;
       public       postgres    false    493    531    4817            �           2606    19979 !   lote_favorecido fk_lote_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.lote_favorecido
    ADD CONSTRAINT fk_lote_pagamento FOREIGN KEY (pagamento_id) REFERENCES public.pagamento(id);
 K   ALTER TABLE ONLY public.lote_favorecido DROP CONSTRAINT fk_lote_pagamento;
       public       postgres    false    490    531    4817            �           2606    19984 <   mensagem_arquivo fk_mensagem_arquivo_controle_upload_arquivo    FK CONSTRAINT     �   ALTER TABLE ONLY public.mensagem_arquivo
    ADD CONSTRAINT fk_mensagem_arquivo_controle_upload_arquivo FOREIGN KEY (controle_upload_arquivo_id) REFERENCES public.controle_upload_arquivo(id);
 f   ALTER TABLE ONLY public.mensagem_arquivo DROP CONSTRAINT fk_mensagem_arquivo_controle_upload_arquivo;
       public       postgres    false    332    495    4593            �           2606    19989 >   movimento_remessa_cobranca fk_movimento_remessa_cobranca_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.movimento_remessa_cobranca
    ADD CONSTRAINT fk_movimento_remessa_cobranca_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 h   ALTER TABLE ONLY public.movimento_remessa_cobranca DROP CONSTRAINT fk_movimento_remessa_cobranca_banco;
       public       postgres    false    4492    505    247            �           2606    19994 5   notificacao_pagamento fk_notificacoes_pagamento_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.notificacao_pagamento
    ADD CONSTRAINT fk_notificacoes_pagamento_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 _   ALTER TABLE ONLY public.notificacao_pagamento DROP CONSTRAINT fk_notificacoes_pagamento_banco;
       public       postgres    false    513    4492    247            �           2606    19999 9   notificacao_pagamento fk_notificacoes_pagamento_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.notificacao_pagamento
    ADD CONSTRAINT fk_notificacoes_pagamento_pagamento FOREIGN KEY (pagamento_id) REFERENCES public.pagamento(id);
 c   ALTER TABLE ONLY public.notificacao_pagamento DROP CONSTRAINT fk_notificacoes_pagamento_pagamento;
       public       postgres    false    4817    531    513            �           2606    20004    numerario fk_numerario_cua    FK CONSTRAINT     �   ALTER TABLE ONLY public.numerario
    ADD CONSTRAINT fk_numerario_cua FOREIGN KEY (controle_upload_arquivo_id) REFERENCES public.controle_upload_arquivo(id);
 D   ALTER TABLE ONLY public.numerario DROP CONSTRAINT fk_numerario_cua;
       public       postgres    false    332    4593    517            �           2606    20009 *   numerario_duplicidade fk_numerario_dup_cua    FK CONSTRAINT     �   ALTER TABLE ONLY public.numerario_duplicidade
    ADD CONSTRAINT fk_numerario_dup_cua FOREIGN KEY (controle_upload_arquivo_id) REFERENCES public.controle_upload_arquivo(id);
 T   ALTER TABLE ONLY public.numerario_duplicidade DROP CONSTRAINT fk_numerario_dup_cua;
       public       postgres    false    332    518    4593            �           2606    20014 *   numerario_duplicidade fk_numerario_dup_num    FK CONSTRAINT     �   ALTER TABLE ONLY public.numerario_duplicidade
    ADD CONSTRAINT fk_numerario_dup_num FOREIGN KEY (numerario_id) REFERENCES public.numerario(id);
 T   ALTER TABLE ONLY public.numerario_duplicidade DROP CONSTRAINT fk_numerario_dup_num;
       public       postgres    false    517    518    4799            �           2606    20019    numerario fk_numerario_emp    FK CONSTRAINT     ~   ALTER TABLE ONLY public.numerario
    ADD CONSTRAINT fk_numerario_emp FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 D   ALTER TABLE ONLY public.numerario DROP CONSTRAINT fk_numerario_emp;
       public       postgres    false    4628    360    517            �           2606    20024    numerario fk_numerario_loj    FK CONSTRAINT     x   ALTER TABLE ONLY public.numerario
    ADD CONSTRAINT fk_numerario_loj FOREIGN KEY (loja_id) REFERENCES public.loja(id);
 D   ALTER TABLE ONLY public.numerario DROP CONSTRAINT fk_numerario_loj;
       public       postgres    false    517    4761    482            �           2606    20029 :   numerario_recolhimento fk_numerario_recolhimento_numerario    FK CONSTRAINT     �   ALTER TABLE ONLY public.numerario_recolhimento
    ADD CONSTRAINT fk_numerario_recolhimento_numerario FOREIGN KEY (numerario_id) REFERENCES public.numerario(id);
 d   ALTER TABLE ONLY public.numerario_recolhimento DROP CONSTRAINT fk_numerario_recolhimento_numerario;
       public       postgres    false    517    4799    521            �           2606    20034 =   numerario_recolhimento fk_numerario_recolhimento_recolhimento    FK CONSTRAINT     �   ALTER TABLE ONLY public.numerario_recolhimento
    ADD CONSTRAINT fk_numerario_recolhimento_recolhimento FOREIGN KEY (recolhimento_transportadora_id) REFERENCES public.recolhimento_transportadora(id);
 g   ALTER TABLE ONLY public.numerario_recolhimento DROP CONSTRAINT fk_numerario_recolhimento_recolhimento;
       public       postgres    false    521    4841    558            �           2606    20039    ocorrencia fk_ocorrencia_banco    FK CONSTRAINT     ~   ALTER TABLE ONLY public.ocorrencia
    ADD CONSTRAINT fk_ocorrencia_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 H   ALTER TABLE ONLY public.ocorrencia DROP CONSTRAINT fk_ocorrencia_banco;
       public       postgres    false    247    522    4492            �           2606    20044 :   ocorrencia_retorno_cobranca_detalhe fk_ocorrencia_cobranca    FK CONSTRAINT     �   ALTER TABLE ONLY public.ocorrencia_retorno_cobranca_detalhe
    ADD CONSTRAINT fk_ocorrencia_cobranca FOREIGN KEY (ocorrencia_cobranca_id) REFERENCES public.ocorrencia_cobranca(id);
 d   ALTER TABLE ONLY public.ocorrencia_retorno_cobranca_detalhe DROP CONSTRAINT fk_ocorrencia_cobranca;
       public       postgres    false    523    4809    527            �           2606    20049 -   conciliacao_financeira fk_ocorrencia_cobranca    FK CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_financeira
    ADD CONSTRAINT fk_ocorrencia_cobranca FOREIGN KEY (ocorrencia_cobranca_id) REFERENCES public.ocorrencia_cobranca(id);
 W   ALTER TABLE ONLY public.conciliacao_financeira DROP CONSTRAINT fk_ocorrencia_cobranca;
       public       postgres    false    4809    285    523            9           2606    20054 B   vinculo_descricao_ocorrencia_categoria fk_ocorrencia_cobranca_vdoc    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_descricao_ocorrencia_categoria
    ADD CONSTRAINT fk_ocorrencia_cobranca_vdoc FOREIGN KEY (ocorrencia_cobranca_id) REFERENCES public.ocorrencia_cobranca(id);
 l   ALTER TABLE ONLY public.vinculo_descricao_ocorrencia_categoria DROP CONSTRAINT fk_ocorrencia_cobranca_vdoc;
       public       postgres    false    651    523    4809            �           2606    20059 +   optantes_debito fk_optantes_debito_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.optantes_debito
    ADD CONSTRAINT fk_optantes_debito_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 U   ALTER TABLE ONLY public.optantes_debito DROP CONSTRAINT fk_optantes_debito_convenio;
       public       postgres    false    334    4595    528            �           2606    20064 S   optantes_debito_remessa fk_optantes_debito_remessa_controle_remessa_optantes_debito    FK CONSTRAINT     �   ALTER TABLE ONLY public.optantes_debito_remessa
    ADD CONSTRAINT fk_optantes_debito_remessa_controle_remessa_optantes_debito FOREIGN KEY (controle_remessa_optantes_debito_id) REFERENCES public.controle_remessa_optantes_debito(id);
 }   ALTER TABLE ONLY public.optantes_debito_remessa DROP CONSTRAINT fk_optantes_debito_remessa_controle_remessa_optantes_debito;
       public       postgres    false    530    4589    328            �           2606    20069 B   optantes_debito_remessa fk_optantes_debito_remessa_optantes_debito    FK CONSTRAINT     �   ALTER TABLE ONLY public.optantes_debito_remessa
    ADD CONSTRAINT fk_optantes_debito_remessa_optantes_debito FOREIGN KEY (optantes_debito_id) REFERENCES public.optantes_debito(id);
 l   ALTER TABLE ONLY public.optantes_debito_remessa DROP CONSTRAINT fk_optantes_debito_remessa_optantes_debito;
       public       postgres    false    4815    528    530                       2606    20074 %   tributo_sem_codigo_barra fk_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.tributo_sem_codigo_barra
    ADD CONSTRAINT fk_pagamento FOREIGN KEY (pagamento_id) REFERENCES public.pagamento(id);
 O   ALTER TABLE ONLY public.tributo_sem_codigo_barra DROP CONSTRAINT fk_pagamento;
       public       postgres    false    626    4817    531            >           2606    20079 )   vinculo_pagamento_lancamento fk_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_pagamento_lancamento
    ADD CONSTRAINT fk_pagamento FOREIGN KEY (pagamento_id) REFERENCES public.pagamento(id);
 S   ALTER TABLE ONLY public.vinculo_pagamento_lancamento DROP CONSTRAINT fk_pagamento;
       public       postgres    false    531    654    4817            �           2606    20084 .   pagamento_arquivo fk_pagamento_arquivo_arquivo    FK CONSTRAINT     �   ALTER TABLE ONLY public.pagamento_arquivo
    ADD CONSTRAINT fk_pagamento_arquivo_arquivo FOREIGN KEY (arquivo_id) REFERENCES public.arquivo(id);
 X   ALTER TABLE ONLY public.pagamento_arquivo DROP CONSTRAINT fk_pagamento_arquivo_arquivo;
       public       postgres    false    226    532    4463            �           2606    20089 0   pagamento_arquivo fk_pagamento_arquivo_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.pagamento_arquivo
    ADD CONSTRAINT fk_pagamento_arquivo_pagamento FOREIGN KEY (pagamento_id) REFERENCES public.pagamento(id);
 Z   ALTER TABLE ONLY public.pagamento_arquivo DROP CONSTRAINT fk_pagamento_arquivo_pagamento;
       public       postgres    false    532    531    4817            �           2606    20094 ,   pagamento_aviso fk_pagamento_aviso_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.pagamento_aviso
    ADD CONSTRAINT fk_pagamento_aviso_pagamento FOREIGN KEY (pagamento_id) REFERENCES public.pagamento(id);
 V   ALTER TABLE ONLY public.pagamento_aviso DROP CONSTRAINT fk_pagamento_aviso_pagamento;
       public       postgres    false    535    531    4817            �           2606    20099 "   pagamento fk_pagamento_compromisso    FK CONSTRAINT     �   ALTER TABLE ONLY public.pagamento
    ADD CONSTRAINT fk_pagamento_compromisso FOREIGN KEY (compromisso_id) REFERENCES public.compromisso(id);
 L   ALTER TABLE ONLY public.pagamento DROP CONSTRAINT fk_pagamento_compromisso;
       public       postgres    false    531    282    4524            U           2606    20104 4   historico_pagamento fk_pagamento_historico_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.historico_pagamento
    ADD CONSTRAINT fk_pagamento_historico_pagamento FOREIGN KEY (pagamento_id) REFERENCES public.pagamento(id);
 ^   ALTER TABLE ONLY public.historico_pagamento DROP CONSTRAINT fk_pagamento_historico_pagamento;
       public       postgres    false    430    531    4817            V           2606    20109 2   historico_pagamento fk_pagamento_historico_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.historico_pagamento
    ADD CONSTRAINT fk_pagamento_historico_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 \   ALTER TABLE ONLY public.historico_pagamento DROP CONSTRAINT fk_pagamento_historico_usuario;
       public       postgres    false    430    628    4926            �           2606    20114 :   parametro_autorizacao fk_parametro_autorizacao_compromisso    FK CONSTRAINT     �   ALTER TABLE ONLY public.parametro_autorizacao
    ADD CONSTRAINT fk_parametro_autorizacao_compromisso FOREIGN KEY (compromisso_id) REFERENCES public.compromisso(id);
 d   ALTER TABLE ONLY public.parametro_autorizacao DROP CONSTRAINT fk_parametro_autorizacao_compromisso;
       public       postgres    false    539    282    4524            �           2606    20119 7   parametro_autorizacao fk_parametro_autorizacao_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.parametro_autorizacao
    ADD CONSTRAINT fk_parametro_autorizacao_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 a   ALTER TABLE ONLY public.parametro_autorizacao DROP CONSTRAINT fk_parametro_autorizacao_convenio;
       public       postgres    false    539    334    4595            �           2606    20124 +   perfil_permissao fk_perfil_permissao_perfil    FK CONSTRAINT     �   ALTER TABLE ONLY public.perfil_permissao
    ADD CONSTRAINT fk_perfil_permissao_perfil FOREIGN KEY (perfil_id) REFERENCES public.perfil(id);
 U   ALTER TABLE ONLY public.perfil_permissao DROP CONSTRAINT fk_perfil_permissao_perfil;
       public       postgres    false    546    543    4829            �           2606    20129 .   perfil_permissao fk_perfil_permissao_permissao    FK CONSTRAINT     �   ALTER TABLE ONLY public.perfil_permissao
    ADD CONSTRAINT fk_perfil_permissao_permissao FOREIGN KEY (permissoes_id) REFERENCES public.permissao(id);
 X   ALTER TABLE ONLY public.perfil_permissao DROP CONSTRAINT fk_perfil_permissao_permissao;
       public       postgres    false    546    547    4831            �           2606    20134 %   permissao_ip fk_permissao__ip_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.permissao_ip
    ADD CONSTRAINT fk_permissao__ip_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 O   ALTER TABLE ONLY public.permissao_ip DROP CONSTRAINT fk_permissao__ip_usuario;
       public       postgres    false    549    628    4926            �           2606    20139 &   permissao fk_permissao_grupo_permissao    FK CONSTRAINT     �   ALTER TABLE ONLY public.permissao
    ADD CONSTRAINT fk_permissao_grupo_permissao FOREIGN KEY (grupopermissao_id) REFERENCES public.grupopermissao(id);
 P   ALTER TABLE ONLY public.permissao DROP CONSTRAINT fk_permissao_grupo_permissao;
       public       postgres    false    547    420    4693            �           2606    20144 F   recolhimento_transportadora_duplicidade fk_recolhimento_transportadora    FK CONSTRAINT     �   ALTER TABLE ONLY public.recolhimento_transportadora_duplicidade
    ADD CONSTRAINT fk_recolhimento_transportadora FOREIGN KEY (recolhimento_transportadora_id) REFERENCES public.recolhimento_transportadora(id);
 p   ALTER TABLE ONLY public.recolhimento_transportadora_duplicidade DROP CONSTRAINT fk_recolhimento_transportadora;
       public       postgres    false    561    558    4841                       2606    20149 5   tramite_processamento_arquivo fk_resumo_processamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.tramite_processamento_arquivo
    ADD CONSTRAINT fk_resumo_processamento FOREIGN KEY (resumo_processamento_id) REFERENCES public.resumo_processamento_arquivo(id);
 _   ALTER TABLE ONLY public.tramite_processamento_arquivo DROP CONSTRAINT fk_resumo_processamento;
       public       postgres    false    567    621    4849            �           2606    20154 .   recolhimento_transportadora_analise fk_rta_cup    FK CONSTRAINT     �   ALTER TABLE ONLY public.recolhimento_transportadora_analise
    ADD CONSTRAINT fk_rta_cup FOREIGN KEY (controle_upload_arquivo_id) REFERENCES public.controle_upload_arquivo(id);
 X   ALTER TABLE ONLY public.recolhimento_transportadora_analise DROP CONSTRAINT fk_rta_cup;
       public       postgres    false    559    332    4593            �           2606    20159 ,   recolhimento_transportadora_analise fk_rta_e    FK CONSTRAINT     �   ALTER TABLE ONLY public.recolhimento_transportadora_analise
    ADD CONSTRAINT fk_rta_e FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 V   ALTER TABLE ONLY public.recolhimento_transportadora_analise DROP CONSTRAINT fk_rta_e;
       public       postgres    false    559    360    4628            �           2606    20164 ,   recolhimento_transportadora_analise fk_rta_l    FK CONSTRAINT     �   ALTER TABLE ONLY public.recolhimento_transportadora_analise
    ADD CONSTRAINT fk_rta_l FOREIGN KEY (loja_id) REFERENCES public.loja(id);
 V   ALTER TABLE ONLY public.recolhimento_transportadora_analise DROP CONSTRAINT fk_rta_l;
       public       postgres    false    482    559    4761            �           2606    20169 ,   recolhimento_transportadora_analise fk_rtt_t    FK CONSTRAINT     �   ALTER TABLE ONLY public.recolhimento_transportadora_analise
    ADD CONSTRAINT fk_rtt_t FOREIGN KEY (transportadora_id) REFERENCES public.transportadora(id);
 V   ALTER TABLE ONLY public.recolhimento_transportadora_analise DROP CONSTRAINT fk_rtt_t;
       public       postgres    false    559    622    4920            �           2606    20174 ,   recolhimento_transportadora_analise fk_rtt_u    FK CONSTRAINT     �   ALTER TABLE ONLY public.recolhimento_transportadora_analise
    ADD CONSTRAINT fk_rtt_u FOREIGN KEY (usuario_alteracao_id) REFERENCES public.usuario(id);
 V   ALTER TABLE ONLY public.recolhimento_transportadora_analise DROP CONSTRAINT fk_rtt_u;
       public       postgres    false    4926    628    559            �           2606    20179    sacado fk_sacado_cidade    FK CONSTRAINT     y   ALTER TABLE ONLY public.sacado
    ADD CONSTRAINT fk_sacado_cidade FOREIGN KEY (cidade_id) REFERENCES public.cidade(id);
 A   ALTER TABLE ONLY public.sacado DROP CONSTRAINT fk_sacado_cidade;
       public       postgres    false    268    570    4510            �           2606    20184     titulo_auxiliar fk_sacado_cidade    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_auxiliar
    ADD CONSTRAINT fk_sacado_cidade FOREIGN KEY (cidade_sacado_id_sacado) REFERENCES public.cidade(id);
 J   ALTER TABLE ONLY public.titulo_auxiliar DROP CONSTRAINT fk_sacado_cidade;
       public       postgres    false    605    268    4510            �           2606    20189    sacado fk_sacado_empresa    FK CONSTRAINT     |   ALTER TABLE ONLY public.sacado
    ADD CONSTRAINT fk_sacado_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 B   ALTER TABLE ONLY public.sacado DROP CONSTRAINT fk_sacado_empresa;
       public       postgres    false    570    4628    360            �           2606    20194    sacado fk_sacado_estado    FK CONSTRAINT     y   ALTER TABLE ONLY public.sacado
    ADD CONSTRAINT fk_sacado_estado FOREIGN KEY (estado_id) REFERENCES public.estado(id);
 A   ALTER TABLE ONLY public.sacado DROP CONSTRAINT fk_sacado_estado;
       public       postgres    false    570    4634    367            �           2606    20199     titulo_auxiliar fk_sacado_estado    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_auxiliar
    ADD CONSTRAINT fk_sacado_estado FOREIGN KEY (estado_sacado_id_sacado) REFERENCES public.estado(id);
 J   ALTER TABLE ONLY public.titulo_auxiliar DROP CONSTRAINT fk_sacado_estado;
       public       postgres    false    605    4634    367            �           2606    20204 &   saldo_convenio fk_saldo_convenio_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.saldo_convenio
    ADD CONSTRAINT fk_saldo_convenio_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 P   ALTER TABLE ONLY public.saldo_convenio DROP CONSTRAINT fk_saldo_convenio_banco;
       public       postgres    false    572    4492    247            �           2606    20209 &   saldo_convenio fk_saldo_convenio_conta    FK CONSTRAINT     �   ALTER TABLE ONLY public.saldo_convenio
    ADD CONSTRAINT fk_saldo_convenio_conta FOREIGN KEY (conta_id) REFERENCES public.conta(id);
 P   ALTER TABLE ONLY public.saldo_convenio DROP CONSTRAINT fk_saldo_convenio_conta;
       public       postgres    false    572    4547    296            �           2606    20214 8   saldo_convenio fk_saldo_convenio_controle_upload_arquivo    FK CONSTRAINT     �   ALTER TABLE ONLY public.saldo_convenio
    ADD CONSTRAINT fk_saldo_convenio_controle_upload_arquivo FOREIGN KEY (controle_upload_arquivo_id) REFERENCES public.controle_upload_arquivo(id);
 b   ALTER TABLE ONLY public.saldo_convenio DROP CONSTRAINT fk_saldo_convenio_controle_upload_arquivo;
       public       postgres    false    4593    332    572            �           2606    20219 )   saldo_convenio fk_saldo_convenio_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.saldo_convenio
    ADD CONSTRAINT fk_saldo_convenio_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 S   ALTER TABLE ONLY public.saldo_convenio DROP CONSTRAINT fk_saldo_convenio_convenio;
       public       postgres    false    334    4595    572            �           2606    20224 (   saldo_convenio fk_saldo_convenio_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.saldo_convenio
    ADD CONSTRAINT fk_saldo_convenio_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 R   ALTER TABLE ONLY public.saldo_convenio DROP CONSTRAINT fk_saldo_convenio_empresa;
       public       postgres    false    360    4628    572            �           2606    20229 (   saldo_convenio fk_saldo_convenio_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.saldo_convenio
    ADD CONSTRAINT fk_saldo_convenio_usuario FOREIGN KEY (usuario_logado_id) REFERENCES public.usuario(id);
 R   ALTER TABLE ONLY public.saldo_convenio DROP CONSTRAINT fk_saldo_convenio_usuario;
       public       postgres    false    628    4926    572            S           2606    20234 /   historico_monitoramento fk_status_monitoramento    FK CONSTRAINT     �   ALTER TABLE ONLY public.historico_monitoramento
    ADD CONSTRAINT fk_status_monitoramento FOREIGN KEY (status_monitoramento_id) REFERENCES public.status_monitoramento(id);
 Y   ALTER TABLE ONLY public.historico_monitoramento DROP CONSTRAINT fk_status_monitoramento;
       public       postgres    false    575    426    4860            �           2606    20239 4   tarifa_divergente fk_tarifa_divergente_grupo_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.tarifa_divergente
    ADD CONSTRAINT fk_tarifa_divergente_grupo_empresa FOREIGN KEY (grupo_empresa_id) REFERENCES public.grupo_empresa(id);
 ^   ALTER TABLE ONLY public.tarifa_divergente DROP CONSTRAINT fk_tarifa_divergente_grupo_empresa;
       public       postgres    false    4672    577    403            �           2606    20244 B   tarifa_divergente fk_tarifa_divergente_item_contrato_cesta_servico    FK CONSTRAINT     �   ALTER TABLE ONLY public.tarifa_divergente
    ADD CONSTRAINT fk_tarifa_divergente_item_contrato_cesta_servico FOREIGN KEY (item_contrato_cesta_servico_id) REFERENCES public.item_contrato_cesta_servico(id);
 l   ALTER TABLE ONLY public.tarifa_divergente DROP CONSTRAINT fk_tarifa_divergente_item_contrato_cesta_servico;
       public       postgres    false    577    4719    448            �           2606    20249 1   tarifa_divergente fk_tarifa_divergente_lancamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.tarifa_divergente
    ADD CONSTRAINT fk_tarifa_divergente_lancamento FOREIGN KEY (lancamento_id) REFERENCES public.lancamento_new(id);
 [   ALTER TABLE ONLY public.tarifa_divergente DROP CONSTRAINT fk_tarifa_divergente_lancamento;
       public       postgres    false    577    466    4741            �           2606    20254 J   tarifa_divergente fk_tarifa_divergente_vinculo_tarifa_origem_tipo_operacao    FK CONSTRAINT     �   ALTER TABLE ONLY public.tarifa_divergente
    ADD CONSTRAINT fk_tarifa_divergente_vinculo_tarifa_origem_tipo_operacao FOREIGN KEY (vinculo_tarifa_origem_tipo_operacao_id) REFERENCES public.vinculo_tarifa_origem_tipo_operacao(id);
 t   ALTER TABLE ONLY public.tarifa_divergente DROP CONSTRAINT fk_tarifa_divergente_vinculo_tarifa_origem_tipo_operacao;
       public       postgres    false    577    659    4970            �           2606    20259 $   tarifa_origem fk_tarifa_origem_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.tarifa_origem
    ADD CONSTRAINT fk_tarifa_origem_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 N   ALTER TABLE ONLY public.tarifa_origem DROP CONSTRAINT fk_tarifa_origem_banco;
       public       postgres    false    581    247    4492            �           2606    20264 0   tarifa_sem_contrato fk_tarifa_sem_contrato_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.tarifa_sem_contrato
    ADD CONSTRAINT fk_tarifa_sem_contrato_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 Z   ALTER TABLE ONLY public.tarifa_sem_contrato DROP CONSTRAINT fk_tarifa_sem_contrato_banco;
       public       postgres    false    583    247    4492            �           2606    20269 0   tarifa_sem_contrato fk_tarifa_sem_contrato_conta    FK CONSTRAINT     �   ALTER TABLE ONLY public.tarifa_sem_contrato
    ADD CONSTRAINT fk_tarifa_sem_contrato_conta FOREIGN KEY (conta_id) REFERENCES public.conta(id);
 Z   ALTER TABLE ONLY public.tarifa_sem_contrato DROP CONSTRAINT fk_tarifa_sem_contrato_conta;
       public       postgres    false    583    296    4547            �           2606    20274 4   tarifa_sem_contrato fk_tarifa_sem_contrato_descricao    FK CONSTRAINT     �   ALTER TABLE ONLY public.tarifa_sem_contrato
    ADD CONSTRAINT fk_tarifa_sem_contrato_descricao FOREIGN KEY (descricao_lancamento_id) REFERENCES public.descricao_lancamento_new(id);
 ^   ALTER TABLE ONLY public.tarifa_sem_contrato DROP CONSTRAINT fk_tarifa_sem_contrato_descricao;
       public       postgres    false    583    350    4618            �           2606    20279 2   tarifa_sem_contrato fk_tarifa_sem_contrato_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.tarifa_sem_contrato
    ADD CONSTRAINT fk_tarifa_sem_contrato_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 \   ALTER TABLE ONLY public.tarifa_sem_contrato DROP CONSTRAINT fk_tarifa_sem_contrato_empresa;
       public       postgres    false    583    360    4628            �           2606    20284 +   tipo_compromisso fk_tipo_commpromisso_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.tipo_compromisso
    ADD CONSTRAINT fk_tipo_commpromisso_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 U   ALTER TABLE ONLY public.tipo_compromisso DROP CONSTRAINT fk_tipo_commpromisso_banco;
       public       postgres    false    588    247    4492            �           2606    20289    compromisso fk_tipo_compromisso    FK CONSTRAINT     �   ALTER TABLE ONLY public.compromisso
    ADD CONSTRAINT fk_tipo_compromisso FOREIGN KEY (tipo_compromisso_id) REFERENCES public.tipo_compromisso(id);
 I   ALTER TABLE ONLY public.compromisso DROP CONSTRAINT fk_tipo_compromisso;
       public       postgres    false    282    588    4877            �           2606    20294    conta_pagar fk_tipo_conta_pagar    FK CONSTRAINT     �   ALTER TABLE ONLY public.conta_pagar
    ADD CONSTRAINT fk_tipo_conta_pagar FOREIGN KEY (tipo_conta_id) REFERENCES public.tipo_conta_pagar(id);
 I   ALTER TABLE ONLY public.conta_pagar DROP CONSTRAINT fk_tipo_conta_pagar;
       public       postgres    false    302    590    4879            �           2606    20299 @   tipo_operacao_cesta_servico fk_tipo_operacao_cesta_servico_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.tipo_operacao_cesta_servico
    ADD CONSTRAINT fk_tipo_operacao_cesta_servico_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 j   ALTER TABLE ONLY public.tipo_operacao_cesta_servico DROP CONSTRAINT fk_tipo_operacao_cesta_servico_banco;
       public       postgres    false    597    247    4492            j           2606    20304 2   item_contrato_numerario fk_tipo_operacao_numerario    FK CONSTRAINT     �   ALTER TABLE ONLY public.item_contrato_numerario
    ADD CONSTRAINT fk_tipo_operacao_numerario FOREIGN KEY (tipo_operacao_numerario_id) REFERENCES public.tipo_operacao_numerario(id);
 \   ALTER TABLE ONLY public.item_contrato_numerario DROP CONSTRAINT fk_tipo_operacao_numerario;
       public       postgres    false    4889    598    453            �           2606    20309 0   conciliacao_financeira_auxiliar_titulo fk_titulo    FK CONSTRAINT     �   ALTER TABLE ONLY public.conciliacao_financeira_auxiliar_titulo
    ADD CONSTRAINT fk_titulo FOREIGN KEY (titulo_id) REFERENCES public.titulo(id);
 Z   ALTER TABLE ONLY public.conciliacao_financeira_auxiliar_titulo DROP CONSTRAINT fk_titulo;
       public       postgres    false    289    4894    602            �           2606    20314 "   titulo fk_titulo_carteira_cobranca    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo
    ADD CONSTRAINT fk_titulo_carteira_cobranca FOREIGN KEY (carteira_cobranca_id) REFERENCES public.carteira_cobranca(id);
 L   ALTER TABLE ONLY public.titulo DROP CONSTRAINT fk_titulo_carteira_cobranca;
       public       postgres    false    602    4498    258            �           2606    20319    titulo fk_titulo_convenio    FK CONSTRAINT        ALTER TABLE ONLY public.titulo
    ADD CONSTRAINT fk_titulo_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 C   ALTER TABLE ONLY public.titulo DROP CONSTRAINT fk_titulo_convenio;
       public       postgres    false    334    4595    602            �           2606    20324    conta_pagar fk_titulo_dda    FK CONSTRAINT     �   ALTER TABLE ONLY public.conta_pagar
    ADD CONSTRAINT fk_titulo_dda FOREIGN KEY (titulo_dda_id) REFERENCES public.titulo_dda(id);
 C   ALTER TABLE ONLY public.conta_pagar DROP CONSTRAINT fk_titulo_dda;
       public       postgres    false    607    4902    302            �           2606    20329    titulo fk_titulo_empresa    FK CONSTRAINT     |   ALTER TABLE ONLY public.titulo
    ADD CONSTRAINT fk_titulo_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 B   ALTER TABLE ONLY public.titulo DROP CONSTRAINT fk_titulo_empresa;
       public       postgres    false    360    602    4628                       2606    20334 7   titulo_movimento_remessa fk_titulo_movimentacao_arquivo    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_movimento_remessa
    ADD CONSTRAINT fk_titulo_movimentacao_arquivo FOREIGN KEY (arquivo_id) REFERENCES public.arquivo(id);
 a   ALTER TABLE ONLY public.titulo_movimento_remessa DROP CONSTRAINT fk_titulo_movimentacao_arquivo;
       public       postgres    false    613    4463    226                       2606    20339 M   titulo_movimento_remessa fk_titulo_movimentacao_movimento_remessa_cobranca_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_movimento_remessa
    ADD CONSTRAINT fk_titulo_movimentacao_movimento_remessa_cobranca_id FOREIGN KEY (movimento_remessa_cobranca_id) REFERENCES public.movimento_remessa_cobranca(id);
 w   ALTER TABLE ONLY public.titulo_movimento_remessa DROP CONSTRAINT fk_titulo_movimentacao_movimento_remessa_cobranca_id;
       public       postgres    false    505    4783    613            	           2606    20344 6   titulo_movimento_remessa fk_titulo_movimentacao_titulo    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_movimento_remessa
    ADD CONSTRAINT fk_titulo_movimentacao_titulo FOREIGN KEY (titulo_id) REFERENCES public.titulo(id);
 `   ALTER TABLE ONLY public.titulo_movimento_remessa DROP CONSTRAINT fk_titulo_movimentacao_titulo;
       public       postgres    false    613    602    4894            �           2606    20349 5   ocorrencia_retorno_cobranca_detalhe fk_titulo_retorno    FK CONSTRAINT     �   ALTER TABLE ONLY public.ocorrencia_retorno_cobranca_detalhe
    ADD CONSTRAINT fk_titulo_retorno FOREIGN KEY (titulo_retorno_id) REFERENCES public.titulo_retorno(id);
 _   ALTER TABLE ONLY public.ocorrencia_retorno_cobranca_detalhe DROP CONSTRAINT fk_titulo_retorno;
       public       postgres    false    614    4908    527                       2606    20354 (   titulo_retorno fk_titulo_retorno_arquivo    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_retorno
    ADD CONSTRAINT fk_titulo_retorno_arquivo FOREIGN KEY (arquivo_id) REFERENCES public.arquivo(id);
 R   ALTER TABLE ONLY public.titulo_retorno DROP CONSTRAINT fk_titulo_retorno_arquivo;
       public       postgres    false    226    4463    614                       2606    20359 '   titulo_retorno fk_titulo_retorno_titulo    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_retorno
    ADD CONSTRAINT fk_titulo_retorno_titulo FOREIGN KEY (titulo_id) REFERENCES public.titulo(id);
 Q   ALTER TABLE ONLY public.titulo_retorno DROP CONSTRAINT fk_titulo_retorno_titulo;
       public       postgres    false    4894    602    614            �           2606    20364    titulo fk_titulo_sacado    FK CONSTRAINT     y   ALTER TABLE ONLY public.titulo
    ADD CONSTRAINT fk_titulo_sacado FOREIGN KEY (sacado_id) REFERENCES public.sacado(id);
 A   ALTER TABLE ONLY public.titulo DROP CONSTRAINT fk_titulo_sacado;
       public       postgres    false    570    602    4853            �           2606    20369 !   titulo fk_titulo_sacador_avalista    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo
    ADD CONSTRAINT fk_titulo_sacador_avalista FOREIGN KEY (sacador_avalista_id) REFERENCES public.sacado(id);
 K   ALTER TABLE ONLY public.titulo DROP CONSTRAINT fk_titulo_sacador_avalista;
       public       postgres    false    602    570    4853                       2606    20374 %   titulo_serie fk_titulo_serie_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_serie
    ADD CONSTRAINT fk_titulo_serie_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 O   ALTER TABLE ONLY public.titulo_serie DROP CONSTRAINT fk_titulo_serie_convenio;
       public       postgres    false    617    334    4595                       2606    20379 $   titulo_serie fk_titulo_serie_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_serie
    ADD CONSTRAINT fk_titulo_serie_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 N   ALTER TABLE ONLY public.titulo_serie DROP CONSTRAINT fk_titulo_serie_empresa;
       public       postgres    false    617    360    4628                       2606    20384 $   titulo_serie fk_titulo_serie_pagador    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_serie
    ADD CONSTRAINT fk_titulo_serie_pagador FOREIGN KEY (pagador_id) REFERENCES public.sacado(id);
 N   ALTER TABLE ONLY public.titulo_serie DROP CONSTRAINT fk_titulo_serie_pagador;
       public       postgres    false    617    570    4853            �           2606    20389    titulo fk_titulo_titulo_serie    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo
    ADD CONSTRAINT fk_titulo_titulo_serie FOREIGN KEY (titulo_serie_id) REFERENCES public.titulo_serie(id);
 G   ALTER TABLE ONLY public.titulo DROP CONSTRAINT fk_titulo_titulo_serie;
       public       postgres    false    602    4912    617            �           2606    20394    titulo fk_titulo_vinculo_sacado    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo
    ADD CONSTRAINT fk_titulo_vinculo_sacado FOREIGN KEY (vinculo_sacado_id) REFERENCES public.vinculo_sacado(id);
 I   ALTER TABLE ONLY public.titulo DROP CONSTRAINT fk_titulo_vinculo_sacado;
       public       postgres    false    602    4966    657            �           2606    20399    contrato fk_transportadora    FK CONSTRAINT     �   ALTER TABLE ONLY public.contrato
    ADD CONSTRAINT fk_transportadora FOREIGN KEY (transportadora_id) REFERENCES public.transportadora(id);
 D   ALTER TABLE ONLY public.contrato DROP CONSTRAINT fk_transportadora;
       public       postgres    false    307    4920    622                       2606    20404 !   tributo_gps fk_tributo_gps_cidade    FK CONSTRAINT     �   ALTER TABLE ONLY public.tributo_gps
    ADD CONSTRAINT fk_tributo_gps_cidade FOREIGN KEY (cidade_id) REFERENCES public.cidade(id);
 K   ALTER TABLE ONLY public.tributo_gps DROP CONSTRAINT fk_tributo_gps_cidade;
       public       postgres    false    624    4510    268                       2606    20409 -   tributo_gps fk_tributo_gps_codigo_receita_gps    FK CONSTRAINT     �   ALTER TABLE ONLY public.tributo_gps
    ADD CONSTRAINT fk_tributo_gps_codigo_receita_gps FOREIGN KEY (codigo_receita_id) REFERENCES public.codigo_receita(id);
 W   ALTER TABLE ONLY public.tributo_gps DROP CONSTRAINT fk_tributo_gps_codigo_receita_gps;
       public       postgres    false    624    4522    280                       2606    20414 !   tributo_gps fk_tributo_gps_estado    FK CONSTRAINT     �   ALTER TABLE ONLY public.tributo_gps
    ADD CONSTRAINT fk_tributo_gps_estado FOREIGN KEY (estado_id) REFERENCES public.estado(id);
 K   ALTER TABLE ONLY public.tributo_gps DROP CONSTRAINT fk_tributo_gps_estado;
       public       postgres    false    4634    367    624                       2606    20419 *   tributo_gps fk_tributo_gps_forma_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.tributo_gps
    ADD CONSTRAINT fk_tributo_gps_forma_pagamento FOREIGN KEY (forma_pagamento_id) REFERENCES public.forma_pagamento(id);
 T   ALTER TABLE ONLY public.tributo_gps DROP CONSTRAINT fk_tributo_gps_forma_pagamento;
       public       postgres    false    624    4655    388                       2606    20424 $   tributo_gps fk_tributo_gps_pagamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.tributo_gps
    ADD CONSTRAINT fk_tributo_gps_pagamento FOREIGN KEY (pagamento_id) REFERENCES public.pagamento(id);
 N   ALTER TABLE ONLY public.tributo_gps DROP CONSTRAINT fk_tributo_gps_pagamento;
       public       postgres    false    531    4817    624            �           2606    20429    conta_pagar fk_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.conta_pagar
    ADD CONSTRAINT fk_usuario FOREIGN KEY (usuario_conciliou_id) REFERENCES public.usuario(id);
 @   ALTER TABLE ONLY public.conta_pagar DROP CONSTRAINT fk_usuario;
       public       postgres    false    628    4926    302            �           2606    20434    release_note fk_usuario    FK CONSTRAINT     {   ALTER TABLE ONLY public.release_note
    ADD CONSTRAINT fk_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 A   ALTER TABLE ONLY public.release_note DROP CONSTRAINT fk_usuario;
       public       postgres    false    628    4926    565                       2606    20439 +   usuario_empresas fk_usuario_empresa_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_empresas
    ADD CONSTRAINT fk_usuario_empresa_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 U   ALTER TABLE ONLY public.usuario_empresas DROP CONSTRAINT fk_usuario_empresa_empresa;
       public       postgres    false    360    4628    631                        2606    20444 +   usuario_empresas fk_usuario_empresa_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_empresas
    ADD CONSTRAINT fk_usuario_empresa_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 U   ALTER TABLE ONLY public.usuario_empresas DROP CONSTRAINT fk_usuario_empresa_usuario;
       public       postgres    false    4926    631    628            "           2606    20449 3   usuario_favorecido fk_usuario_favorecido_favorecido    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_favorecido
    ADD CONSTRAINT fk_usuario_favorecido_favorecido FOREIGN KEY (favorecido_id) REFERENCES public.favorecido(id);
 ]   ALTER TABLE ONLY public.usuario_favorecido DROP CONSTRAINT fk_usuario_favorecido_favorecido;
       public       postgres    false    632    378    4644            #           2606    20454 0   usuario_favorecido fk_usuario_favorecido_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_favorecido
    ADD CONSTRAINT fk_usuario_favorecido_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 Z   ALTER TABLE ONLY public.usuario_favorecido DROP CONSTRAINT fk_usuario_favorecido_usuario;
       public       postgres    false    632    628    4926            $           2606    20459 ;   usuario_favorecido fk_usuario_favorecido_usuario_favorecido    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_favorecido
    ADD CONSTRAINT fk_usuario_favorecido_usuario_favorecido FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 e   ALTER TABLE ONLY public.usuario_favorecido DROP CONSTRAINT fk_usuario_favorecido_usuario_favorecido;
       public       postgres    false    632    628    4926                       2606    20464     usuario fk_usuario_grupo_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT fk_usuario_grupo_empresa FOREIGN KEY (grupo_empresa_id) REFERENCES public.grupo_empresa(id);
 J   ALTER TABLE ONLY public.usuario DROP CONSTRAINT fk_usuario_grupo_empresa;
       public       postgres    false    628    403    4672                       2606    20469    convenio fk_usuario_id    FK CONSTRAINT     z   ALTER TABLE ONLY public.convenio
    ADD CONSTRAINT fk_usuario_id FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 @   ALTER TABLE ONLY public.convenio DROP CONSTRAINT fk_usuario_id;
       public       postgres    false    334    628    4926                       2606    20474    convenio_aud fk_usuario_id    FK CONSTRAINT     ~   ALTER TABLE ONLY public.convenio_aud
    ADD CONSTRAINT fk_usuario_id FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 D   ALTER TABLE ONLY public.convenio_aud DROP CONSTRAINT fk_usuario_id;
       public       postgres    false    335    628    4926            (           2606    20479 '   usuario_perfil fk_usuario_perfil_perfil    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_perfil
    ADD CONSTRAINT fk_usuario_perfil_perfil FOREIGN KEY (perfil_id) REFERENCES public.perfil(id);
 Q   ALTER TABLE ONLY public.usuario_perfil DROP CONSTRAINT fk_usuario_perfil_perfil;
       public       postgres    false    636    543    4829            )           2606    20484 (   usuario_perfil fk_usuario_perfil_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_perfil
    ADD CONSTRAINT fk_usuario_perfil_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 R   ALTER TABLE ONLY public.usuario_perfil DROP CONSTRAINT fk_usuario_perfil_usuario;
       public       postgres    false    636    628    4926            ,           2606    20489 '   usuario_sacado fk_usuario_sacado_sacado    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_sacado
    ADD CONSTRAINT fk_usuario_sacado_sacado FOREIGN KEY (sacado_id) REFERENCES public.sacado(id);
 Q   ALTER TABLE ONLY public.usuario_sacado DROP CONSTRAINT fk_usuario_sacado_sacado;
       public       postgres    false    638    570    4853            -           2606    20494 (   usuario_sacado fk_usuario_sacado_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_sacado
    ADD CONSTRAINT fk_usuario_sacado_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 R   ALTER TABLE ONLY public.usuario_sacado DROP CONSTRAINT fk_usuario_sacado_usuario;
       public       postgres    false    638    628    4926            .           2606    20499 1   usuario_sacado fk_usuario_sacado_usuario_cadastro    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_sacado
    ADD CONSTRAINT fk_usuario_sacado_usuario_cadastro FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 [   ALTER TABLE ONLY public.usuario_sacado DROP CONSTRAINT fk_usuario_sacado_usuario_cadastro;
       public       postgres    false    638    628    4926                       2606    20504     convenio fk_usuario_validador_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.convenio
    ADD CONSTRAINT fk_usuario_validador_id FOREIGN KEY (usuario_validador) REFERENCES public.usuario(id);
 J   ALTER TABLE ONLY public.convenio DROP CONSTRAINT fk_usuario_validador_id;
       public       postgres    false    4926    334    628                       2606    20509 $   convenio_aud fk_usuario_validador_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.convenio_aud
    ADD CONSTRAINT fk_usuario_validador_id FOREIGN KEY (usuario_validador) REFERENCES public.usuario(id);
 N   ALTER TABLE ONLY public.convenio_aud DROP CONSTRAINT fk_usuario_validador_id;
       public       postgres    false    335    628    4926            0           2606    20514 H   vinculacao_automatica_categoria fk_vinculacao_automatica_categoria_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculacao_automatica_categoria
    ADD CONSTRAINT fk_vinculacao_automatica_categoria_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 r   ALTER TABLE ONLY public.vinculacao_automatica_categoria DROP CONSTRAINT fk_vinculacao_automatica_categoria_banco;
       public       postgres    false    4492    644    247            1           2606    20519 M   vinculacao_automatica_categoria fk_vinculacao_automatica_categoria_lancamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculacao_automatica_categoria
    ADD CONSTRAINT fk_vinculacao_automatica_categoria_lancamento FOREIGN KEY (categoria_lancamento_id) REFERENCES public.categoria_lancamento(id);
 w   ALTER TABLE ONLY public.vinculacao_automatica_categoria DROP CONSTRAINT fk_vinculacao_automatica_categoria_lancamento;
       public       postgres    false    260    644    4500            2           2606    20524 2   vinculacao_cnpj_empresa fk_vinculacao_cnpj_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculacao_cnpj_empresa
    ADD CONSTRAINT fk_vinculacao_cnpj_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 \   ALTER TABLE ONLY public.vinculacao_cnpj_empresa DROP CONSTRAINT fk_vinculacao_cnpj_empresa;
       public       postgres    false    4628    360    646            Z           2606    35846 6   vinculo_categoria_cash fk_vinculo_categoria_cash_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_categoria_cash
    ADD CONSTRAINT fk_vinculo_categoria_cash_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 `   ALTER TABLE ONLY public.vinculo_categoria_cash DROP CONSTRAINT fk_vinculo_categoria_cash_banco;
       public       postgres    false    670    4492    247            Y           2606    35841 I   vinculo_categoria_cash fk_vinculo_categoria_cash_categoria_lancamento_new    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_categoria_cash
    ADD CONSTRAINT fk_vinculo_categoria_cash_categoria_lancamento_new FOREIGN KEY (categoria_lancamento_id) REFERENCES public.categoria_lancamento_new(id);
 s   ALTER TABLE ONLY public.vinculo_categoria_cash DROP CONSTRAINT fk_vinculo_categoria_cash_categoria_lancamento_new;
       public       postgres    false    670    261    4502            X           2606    35836 8   vinculo_categoria_cash fk_vinculo_categoria_cash_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_categoria_cash
    ADD CONSTRAINT fk_vinculo_categoria_cash_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 b   ALTER TABLE ONLY public.vinculo_categoria_cash DROP CONSTRAINT fk_vinculo_categoria_cash_empresa;
       public       postgres    false    670    360    4628            :           2606    20529 O   vinculo_descricao_ocorrencia_categoria fk_vinculo_cobranca_categoria_lancamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_descricao_ocorrencia_categoria
    ADD CONSTRAINT fk_vinculo_cobranca_categoria_lancamento FOREIGN KEY (categoria_lancamento_id) REFERENCES public.categoria_lancamento_new(id);
 y   ALTER TABLE ONLY public.vinculo_descricao_ocorrencia_categoria DROP CONSTRAINT fk_vinculo_cobranca_categoria_lancamento;
       public       postgres    false    261    651    4502            5           2606    20534 B   vinculo_conciliacao_cobranca fk_vinculo_conciliacao_cobranca_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_conciliacao_cobranca
    ADD CONSTRAINT fk_vinculo_conciliacao_cobranca_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 l   ALTER TABLE ONLY public.vinculo_conciliacao_cobranca DROP CONSTRAINT fk_vinculo_conciliacao_cobranca_banco;
       public       postgres    false    648    4492    247            6           2606    20539 F   vinculo_conciliacao_cobranca fk_vinculo_conciliacao_cobranca_categoria    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_conciliacao_cobranca
    ADD CONSTRAINT fk_vinculo_conciliacao_cobranca_categoria FOREIGN KEY (categoria_lancamento_id) REFERENCES public.categoria_lancamento_new(id);
 p   ALTER TABLE ONLY public.vinculo_conciliacao_cobranca DROP CONSTRAINT fk_vinculo_conciliacao_cobranca_categoria;
       public       postgres    false    648    4502    261            7           2606    20544 F   vinculo_conciliacao_cobranca fk_vinculo_conciliacao_cobranca_movimento    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_conciliacao_cobranca
    ADD CONSTRAINT fk_vinculo_conciliacao_cobranca_movimento FOREIGN KEY (movimento_retorno_cobranca_id) REFERENCES public.movimento_retorno_cobranca(id);
 p   ALTER TABLE ONLY public.vinculo_conciliacao_cobranca DROP CONSTRAINT fk_vinculo_conciliacao_cobranca_movimento;
       public       postgres    false    4789    507    648            ;           2606    20549 B   vinculo_ocorrencia_pagamento fk_vinculo_ocorrencia_pagamento_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_ocorrencia_pagamento
    ADD CONSTRAINT fk_vinculo_ocorrencia_pagamento_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 l   ALTER TABLE ONLY public.vinculo_ocorrencia_pagamento DROP CONSTRAINT fk_vinculo_ocorrencia_pagamento_banco;
       public       postgres    false    653    247    4492            <           2606    20554 F   vinculo_ocorrencia_pagamento fk_vinculo_ocorrencia_pagamento_categoria    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_ocorrencia_pagamento
    ADD CONSTRAINT fk_vinculo_ocorrencia_pagamento_categoria FOREIGN KEY (categoria_lancamento_id) REFERENCES public.categoria_lancamento_new(id);
 p   ALTER TABLE ONLY public.vinculo_ocorrencia_pagamento DROP CONSTRAINT fk_vinculo_ocorrencia_pagamento_categoria;
       public       postgres    false    653    261    4502            =           2606    20559 I   vinculo_ocorrencia_pagamento fk_vinculo_ocorrencia_pagamento_tipo_servico    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_ocorrencia_pagamento
    ADD CONSTRAINT fk_vinculo_ocorrencia_pagamento_tipo_servico FOREIGN KEY (tipo_servico_id) REFERENCES public.tipo_servico(id);
 s   ALTER TABLE ONLY public.vinculo_ocorrencia_pagamento DROP CONSTRAINT fk_vinculo_ocorrencia_pagamento_tipo_servico;
       public       postgres    false    4891    653    601            ?           2606    20564 &   vinculo_sacado fk_vinculo_sacado_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_sacado
    ADD CONSTRAINT fk_vinculo_sacado_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 P   ALTER TABLE ONLY public.vinculo_sacado DROP CONSTRAINT fk_vinculo_sacado_banco;
       public       postgres    false    247    657    4492            @           2606    20569 )   vinculo_sacado fk_vinculo_sacado_convenio    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_sacado
    ADD CONSTRAINT fk_vinculo_sacado_convenio FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 S   ALTER TABLE ONLY public.vinculo_sacado DROP CONSTRAINT fk_vinculo_sacado_convenio;
       public       postgres    false    4595    334    657            A           2606    20574 (   vinculo_sacado fk_vinculo_sacado_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_sacado
    ADD CONSTRAINT fk_vinculo_sacado_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 R   ALTER TABLE ONLY public.vinculo_sacado DROP CONSTRAINT fk_vinculo_sacado_empresa;
       public       postgres    false    4628    657    360            B           2606    20579 .   vinculo_sacado fk_vinculo_sacado_grupo_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_sacado
    ADD CONSTRAINT fk_vinculo_sacado_grupo_empresa FOREIGN KEY (grupo_empresa_id) REFERENCES public.grupo_empresa(id);
 X   ALTER TABLE ONLY public.vinculo_sacado DROP CONSTRAINT fk_vinculo_sacado_grupo_empresa;
       public       postgres    false    4672    657    403            C           2606    20584 '   vinculo_sacado fk_vinculo_sacado_sacado    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_sacado
    ADD CONSTRAINT fk_vinculo_sacado_sacado FOREIGN KEY (sacado_id) REFERENCES public.sacado(id);
 Q   ALTER TABLE ONLY public.vinculo_sacado DROP CONSTRAINT fk_vinculo_sacado_sacado;
       public       postgres    false    657    570    4853            D           2606    20589 P   vinculo_tarifa_origem_tipo_operacao fk_vinculo_tarifa_origem_tipo_operacao_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_tarifa_origem_tipo_operacao
    ADD CONSTRAINT fk_vinculo_tarifa_origem_tipo_operacao_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 z   ALTER TABLE ONLY public.vinculo_tarifa_origem_tipo_operacao DROP CONSTRAINT fk_vinculo_tarifa_origem_tipo_operacao_banco;
       public       postgres    false    4492    247    659            E           2606    20594 T   vinculo_tarifa_origem_tipo_operacao fk_vinculo_tarifa_origem_tipo_operacao_categoria    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_tarifa_origem_tipo_operacao
    ADD CONSTRAINT fk_vinculo_tarifa_origem_tipo_operacao_categoria FOREIGN KEY (categoria_id) REFERENCES public.categoria_lancamento_new(id);
 ~   ALTER TABLE ONLY public.vinculo_tarifa_origem_tipo_operacao DROP CONSTRAINT fk_vinculo_tarifa_origem_tipo_operacao_categoria;
       public       postgres    false    261    659    4502            F           2606    20599 X   vinculo_tarifa_origem_tipo_operacao fk_vinculo_tarifa_origem_tipo_operacao_tarifa_origem    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_tarifa_origem_tipo_operacao
    ADD CONSTRAINT fk_vinculo_tarifa_origem_tipo_operacao_tarifa_origem FOREIGN KEY (tarifa_origem_id) REFERENCES public.tarifa_origem(id);
 �   ALTER TABLE ONLY public.vinculo_tarifa_origem_tipo_operacao DROP CONSTRAINT fk_vinculo_tarifa_origem_tipo_operacao_tarifa_origem;
       public       postgres    false    659    581    4868            G           2606    20604 c   vinculo_tarifa_origem_tipo_operacao fk_vinculo_tarifa_origem_tipo_operacao_tipo_operacao_cesta_serv    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculo_tarifa_origem_tipo_operacao
    ADD CONSTRAINT fk_vinculo_tarifa_origem_tipo_operacao_tipo_operacao_cesta_serv FOREIGN KEY (tipo_operacao_id) REFERENCES public.tipo_operacao_cesta_servico(id);
 �   ALTER TABLE ONLY public.vinculo_tarifa_origem_tipo_operacao DROP CONSTRAINT fk_vinculo_tarifa_origem_tipo_operacao_tipo_operacao_cesta_serv;
       public       postgres    false    4885    659    597            �           2606    20609 (   receita_processamento fka4e69121b0c671df    FK CONSTRAINT     �   ALTER TABLE ONLY public.receita_processamento
    ADD CONSTRAINT fka4e69121b0c671df FOREIGN KEY (processamento_otimiza_id) REFERENCES public.processamento_otimiza(id);
 R   ALTER TABLE ONLY public.receita_processamento DROP CONSTRAINT fka4e69121b0c671df;
       public       postgres    false    551    556    4835            �           2606    20614 (   contrato_arrecadadora fkb41a2a3c29331374    FK CONSTRAINT     �   ALTER TABLE ONLY public.contrato_arrecadadora
    ADD CONSTRAINT fkb41a2a3c29331374 FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 R   ALTER TABLE ONLY public.contrato_arrecadadora DROP CONSTRAINT fkb41a2a3c29331374;
       public       postgres    false    247    308    4492            �           2606    20619 '   contrato_arrecadadora fkb41a2a3c562da34    FK CONSTRAINT     �   ALTER TABLE ONLY public.contrato_arrecadadora
    ADD CONSTRAINT fkb41a2a3c562da34 FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 Q   ALTER TABLE ONLY public.contrato_arrecadadora DROP CONSTRAINT fkb41a2a3c562da34;
       public       postgres    false    4628    360    308            �           2606    20624 (   contrato_arrecadadora fkb41a2a3c853506ab    FK CONSTRAINT     �   ALTER TABLE ONLY public.contrato_arrecadadora
    ADD CONSTRAINT fkb41a2a3c853506ab FOREIGN KEY (forma_pagamento_arrecadacao_id) REFERENCES public.forma_pagamento_arrecadacao(id);
 R   ALTER TABLE ONLY public.contrato_arrecadadora DROP CONSTRAINT fkb41a2a3c853506ab;
       public       postgres    false    4659    308    389            �           2606    20629    arrecadacao fkb953a9d28bce1edc    FK CONSTRAINT     ~   ALTER TABLE ONLY public.arrecadacao
    ADD CONSTRAINT fkb953a9d28bce1edc FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 H   ALTER TABLE ONLY public.arrecadacao DROP CONSTRAINT fkb953a9d28bce1edc;
       public       postgres    false    4492    247    227            �           2606    20634    arrecadacao fkb953a9d2bcb09c38    FK CONSTRAINT     �   ALTER TABLE ONLY public.arrecadacao
    ADD CONSTRAINT fkb953a9d2bcb09c38 FOREIGN KEY (forma_pagamento_arrecadacao_id) REFERENCES public.forma_pagamento_arrecadacao(id);
 H   ALTER TABLE ONLY public.arrecadacao DROP CONSTRAINT fkb953a9d2bcb09c38;
       public       postgres    false    4659    389    227            
           2606    20639 +   titulo_movimento_remessa fkbc3bdeed910f4b37    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_movimento_remessa
    ADD CONSTRAINT fkbc3bdeed910f4b37 FOREIGN KEY (arquivo_id) REFERENCES public.arquivo(id);
 U   ALTER TABLE ONLY public.titulo_movimento_remessa DROP CONSTRAINT fkbc3bdeed910f4b37;
       public       postgres    false    226    4463    613            �           2606    20644 /   conta_lancamento_fluxo_caixa fkc336e9a676a926f4    FK CONSTRAINT     �   ALTER TABLE ONLY public.conta_lancamento_fluxo_caixa
    ADD CONSTRAINT fkc336e9a676a926f4 FOREIGN KEY (conta_id) REFERENCES public.conta(id);
 Y   ALTER TABLE ONLY public.conta_lancamento_fluxo_caixa DROP CONSTRAINT fkc336e9a676a926f4;
       public       postgres    false    4547    296    299            �           2606    20649 '   processamento_otimiza fkc8d594e7562da34    FK CONSTRAINT     �   ALTER TABLE ONLY public.processamento_otimiza
    ADD CONSTRAINT fkc8d594e7562da34 FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 Q   ALTER TABLE ONLY public.processamento_otimiza DROP CONSTRAINT fkc8d594e7562da34;
       public       postgres    false    360    551    4628            �           2606    20654    cheque fkconta    FK CONSTRAINT     �   ALTER TABLE ONLY public.cheque
    ADD CONSTRAINT fkconta FOREIGN KEY (conta_id) REFERENCES public.conta(id) ON UPDATE CASCADE ON DELETE RESTRICT;
 8   ALTER TABLE ONLY public.cheque DROP CONSTRAINT fkconta;
       public       postgres    false    266    296    4547                       2606    20659    convenio fkde4b88c329331374    FK CONSTRAINT     {   ALTER TABLE ONLY public.convenio
    ADD CONSTRAINT fkde4b88c329331374 FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 E   ALTER TABLE ONLY public.convenio DROP CONSTRAINT fkde4b88c329331374;
       public       postgres    false    4492    334    247            �           2606    20664 %   cobranca_parametro fked0e8401bd9dc2e0    FK CONSTRAINT     �   ALTER TABLE ONLY public.cobranca_parametro
    ADD CONSTRAINT fked0e8401bd9dc2e0 FOREIGN KEY (cidade_id) REFERENCES public.cidade(id);
 O   ALTER TABLE ONLY public.cobranca_parametro DROP CONSTRAINT fked0e8401bd9dc2e0;
       public       postgres    false    268    278    4510            >           2606    20669 .   grupo_lancamento_fluxo_caixa fkf6b41b6c562da34    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_lancamento_fluxo_caixa
    ADD CONSTRAINT fkf6b41b6c562da34 FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 X   ALTER TABLE ONLY public.grupo_lancamento_fluxo_caixa DROP CONSTRAINT fkf6b41b6c562da34;
       public       postgres    false    4628    360    408            �           2606    20674    cheque fkfavorecido    FK CONSTRAINT     �   ALTER TABLE ONLY public.cheque
    ADD CONSTRAINT fkfavorecido FOREIGN KEY (favorecido_id) REFERENCES public.favorecido(id) ON UPDATE CASCADE ON DELETE RESTRICT;
 =   ALTER TABLE ONLY public.cheque DROP CONSTRAINT fkfavorecido;
       public       postgres    false    4644    266    378            �           2606    20679 +   controle_nsa_arrecadacao fkfd342f548bce1edc    FK CONSTRAINT     �   ALTER TABLE ONLY public.controle_nsa_arrecadacao
    ADD CONSTRAINT fkfd342f548bce1edc FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 U   ALTER TABLE ONLY public.controle_nsa_arrecadacao DROP CONSTRAINT fkfd342f548bce1edc;
       public       postgres    false    4492    320    247            �           2606    20684    cheque fklancamento    FK CONSTRAINT     �   ALTER TABLE ONLY public.cheque
    ADD CONSTRAINT fklancamento FOREIGN KEY (lancamento_id) REFERENCES public.lancamento_new(id) ON UPDATE CASCADE ON DELETE RESTRICT;
 =   ALTER TABLE ONLY public.cheque DROP CONSTRAINT fklancamento;
       public       postgres    false    266    466    4741            ?           2606    20689 0   grupo_numerario grupo_numerario_contrato_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_numerario
    ADD CONSTRAINT grupo_numerario_contrato_id_fkey FOREIGN KEY (contrato_id) REFERENCES public.contrato(id);
 Z   ALTER TABLE ONLY public.grupo_numerario DROP CONSTRAINT grupo_numerario_contrato_id_fkey;
       public       postgres    false    4559    307    410            @           2606    20694 /   grupo_numerario grupo_numerario_empresa_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_numerario
    ADD CONSTRAINT grupo_numerario_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 Y   ALTER TABLE ONLY public.grupo_numerario DROP CONSTRAINT grupo_numerario_empresa_id_fkey;
       public       postgres    false    4628    410    360            A           2606    20699 6   grupo_numerario grupo_numerario_transportadora_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_numerario
    ADD CONSTRAINT grupo_numerario_transportadora_id_fkey FOREIGN KEY (transportadora_id) REFERENCES public.transportadora(id);
 `   ALTER TABLE ONLY public.grupo_numerario DROP CONSTRAINT grupo_numerario_transportadora_id_fkey;
       public       postgres    false    410    4920    622            B           2606    20704 /   grupo_numerario grupo_numerario_usuario_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.grupo_numerario
    ADD CONSTRAINT grupo_numerario_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 Y   ALTER TABLE ONLY public.grupo_numerario DROP CONSTRAINT grupo_numerario_usuario_id_fkey;
       public       postgres    false    410    4926    628            M           2606    20709 ?   guia_transporte_valores guia_transporte_valores_empresa_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.guia_transporte_valores
    ADD CONSTRAINT guia_transporte_valores_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 i   ALTER TABLE ONLY public.guia_transporte_valores DROP CONSTRAINT guia_transporte_valores_empresa_id_fkey;
       public       postgres    false    421    4628    360            N           2606    20714 <   guia_transporte_valores guia_transporte_valores_loja_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.guia_transporte_valores
    ADD CONSTRAINT guia_transporte_valores_loja_id_fkey FOREIGN KEY (loja_id) REFERENCES public.loja(id);
 f   ALTER TABLE ONLY public.guia_transporte_valores DROP CONSTRAINT guia_transporte_valores_loja_id_fkey;
       public       postgres    false    421    4761    482            O           2606    20719 F   guia_transporte_valores guia_transporte_valores_transportadora_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.guia_transporte_valores
    ADD CONSTRAINT guia_transporte_valores_transportadora_id_fkey FOREIGN KEY (transportadora_id) REFERENCES public.transportadora(id);
 p   ALTER TABLE ONLY public.guia_transporte_valores DROP CONSTRAINT guia_transporte_valores_transportadora_id_fkey;
       public       postgres    false    4920    622    421            P           2606    20724 ?   guia_transporte_valores guia_transporte_valores_usuario_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.guia_transporte_valores
    ADD CONSTRAINT guia_transporte_valores_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 i   ALTER TABLE ONLY public.guia_transporte_valores DROP CONSTRAINT guia_transporte_valores_usuario_id_fkey;
       public       postgres    false    628    4926    421            T           2606    20729 9   historico_optantes_debito historico_optantes_debito_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.historico_optantes_debito
    ADD CONSTRAINT historico_optantes_debito_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 c   ALTER TABLE ONLY public.historico_optantes_debito DROP CONSTRAINT historico_optantes_debito_banco;
       public       postgres    false    247    4492    428            [           2606    20734 ^   importacao_personalizada_campo importacao_personalizada_campo_importacao_personalizada_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.importacao_personalizada_campo
    ADD CONSTRAINT importacao_personalizada_campo_importacao_personalizada_id_fkey FOREIGN KEY (importacao_personalizada_id) REFERENCES public.importacao_personalizada(id);
 �   ALTER TABLE ONLY public.importacao_personalizada_campo DROP CONSTRAINT importacao_personalizada_campo_importacao_personalizada_id_fkey;
       public       postgres    false    436    4707    437            ]           2606    35526 U   importacao_personalizada_conta_fixo importacao_personalizada_conta_fixo_conta_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.importacao_personalizada_conta_fixo
    ADD CONSTRAINT importacao_personalizada_conta_fixo_conta_id_fkey FOREIGN KEY (conta_id) REFERENCES public.conta(id);
    ALTER TABLE ONLY public.importacao_personalizada_conta_fixo DROP CONSTRAINT importacao_personalizada_conta_fixo_conta_id_fkey;
       public       postgres    false    296    439    4547            \           2606    20739 c   importacao_personalizada_conta_fixo importacao_personalizada_conta_importacao_personalizada_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.importacao_personalizada_conta_fixo
    ADD CONSTRAINT importacao_personalizada_conta_importacao_personalizada_id_fkey FOREIGN KEY (importacao_personalizada_id) REFERENCES public.importacao_personalizada(id);
 �   ALTER TABLE ONLY public.importacao_personalizada_conta_fixo DROP CONSTRAINT importacao_personalizada_conta_importacao_personalizada_id_fkey;
       public       postgres    false    4707    439    436            Y           2606    20744 A   importacao_personalizada importacao_personalizada_empresa_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.importacao_personalizada
    ADD CONSTRAINT importacao_personalizada_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 k   ALTER TABLE ONLY public.importacao_personalizada DROP CONSTRAINT importacao_personalizada_empresa_id_fkey;
       public       postgres    false    436    360    4628            ^           2606    20749 f   importacao_personalizada_ignorar_linha importacao_personalizada_ignor_importacao_personalizada_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.importacao_personalizada_ignorar_linha
    ADD CONSTRAINT importacao_personalizada_ignor_importacao_personalizada_id_fkey FOREIGN KEY (importacao_personalizada_id) REFERENCES public.importacao_personalizada(id);
 �   ALTER TABLE ONLY public.importacao_personalizada_ignorar_linha DROP CONSTRAINT importacao_personalizada_ignor_importacao_personalizada_id_fkey;
       public       postgres    false    4707    442    436            Z           2606    20754 H   importacao_personalizada importacao_personalizada_transportadora_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.importacao_personalizada
    ADD CONSTRAINT importacao_personalizada_transportadora_id_fkey FOREIGN KEY (transportadora_id) REFERENCES public.transportadora(id);
 r   ALTER TABLE ONLY public.importacao_personalizada DROP CONSTRAINT importacao_personalizada_transportadora_id_fkey;
       public       postgres    false    4920    436    622            J           2606    35059 N   lancamento_auxiliar_cash lancamento_auxiliar_cash_categoria_lancamento_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_auxiliar_cash
    ADD CONSTRAINT lancamento_auxiliar_cash_categoria_lancamento_id_fkey FOREIGN KEY (categoria_lancamento_id) REFERENCES public.categoria_lancamento_new(id);
 x   ALTER TABLE ONLY public.lancamento_auxiliar_cash DROP CONSTRAINT lancamento_auxiliar_cash_categoria_lancamento_id_fkey;
       public       postgres    false    660    4502    261            K           2606    35387 O   lancamento_auxiliar_cash lancamento_auxiliar_cash_categoria_lancamento_id_fkey1    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_auxiliar_cash
    ADD CONSTRAINT lancamento_auxiliar_cash_categoria_lancamento_id_fkey1 FOREIGN KEY (categoria_lancamento_id) REFERENCES public.categoria_lancamento_new(id);
 y   ALTER TABLE ONLY public.lancamento_auxiliar_cash DROP CONSTRAINT lancamento_auxiliar_cash_categoria_lancamento_id_fkey1;
       public       postgres    false    660    4502    261            L           2606    36177 P   lancamento_auxiliar_cash lancamento_auxiliar_cash_vinculo_categoria_cash_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.lancamento_auxiliar_cash
    ADD CONSTRAINT lancamento_auxiliar_cash_vinculo_categoria_cash_id_fkey FOREIGN KEY (vinculo_categoria_cash_id) REFERENCES public.vinculo_categoria_cash(id);
 z   ALTER TABLE ONLY public.lancamento_auxiliar_cash DROP CONSTRAINT lancamento_auxiliar_cash_vinculo_categoria_cash_id_fkey;
       public       postgres    false    4982    660    670            �           2606    20759 0   limite_especial limite_especial_convenio_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.limite_especial
    ADD CONSTRAINT limite_especial_convenio_id_fkey FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 Z   ALTER TABLE ONLY public.limite_especial DROP CONSTRAINT limite_especial_convenio_id_fkey;
       public       postgres    false    472    4595    334            �           2606    20764 /   limite_especial limite_especial_usuario_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.limite_especial
    ADD CONSTRAINT limite_especial_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 Y   ALTER TABLE ONLY public.limite_especial DROP CONSTRAINT limite_especial_usuario_id_fkey;
       public       postgres    false    4926    472    628            �           2606    20769 (   loja loja_empresa_transportadora_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.loja
    ADD CONSTRAINT loja_empresa_transportadora_id_fkey FOREIGN KEY (empresa_transportadora_id) REFERENCES public.empresa_transportadora(id);
 R   ALTER TABLE ONLY public.loja DROP CONSTRAINT loja_empresa_transportadora_id_fkey;
       public       postgres    false    482    363    4630            �           2606    20774 B   lojas_com_coleta_excedente lojas_com_coleta_excedente_loja_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.lojas_com_coleta_excedente
    ADD CONSTRAINT lojas_com_coleta_excedente_loja_id_fkey FOREIGN KEY (loja_id) REFERENCES public.loja(id);
 l   ALTER TABLE ONLY public.lojas_com_coleta_excedente DROP CONSTRAINT lojas_com_coleta_excedente_loja_id_fkey;
       public       postgres    false    484    4761    482            �           2606    20779 Y   lojas_com_coleta_excedente lojas_com_coleta_excedente_recolhimento_transportadora_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.lojas_com_coleta_excedente
    ADD CONSTRAINT lojas_com_coleta_excedente_recolhimento_transportadora_id_fkey FOREIGN KEY (recolhimento_transportadora_id) REFERENCES public.recolhimento_transportadora(id);
 �   ALTER TABLE ONLY public.lojas_com_coleta_excedente DROP CONSTRAINT lojas_com_coleta_excedente_recolhimento_transportadora_id_fkey;
       public       postgres    false    484    558    4841            �           2606    20784 E   lojas_com_coleta_excedente lojas_com_coleta_excedente_usuario_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.lojas_com_coleta_excedente
    ADD CONSTRAINT lojas_com_coleta_excedente_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 o   ALTER TABLE ONLY public.lojas_com_coleta_excedente DROP CONSTRAINT lojas_com_coleta_excedente_usuario_id_fkey;
       public       postgres    false    4926    484    628            �           2606    20789 8   lote_favorecido lote_favorecido_favorecido_conta_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.lote_favorecido
    ADD CONSTRAINT lote_favorecido_favorecido_conta_id_fkey FOREIGN KEY (favorecido_conta_id) REFERENCES public.favorecido_conta(id);
 b   ALTER TABLE ONLY public.lote_favorecido DROP CONSTRAINT lote_favorecido_favorecido_conta_id_fkey;
       public       postgres    false    380    490    4646            �           2606    20794 6   lote_favorecido lote_favorecido_favorecido_id_old_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.lote_favorecido
    ADD CONSTRAINT lote_favorecido_favorecido_id_old_fkey FOREIGN KEY (favorecido_id_old) REFERENCES public.favorecido(id);
 `   ALTER TABLE ONLY public.lote_favorecido DROP CONSTRAINT lote_favorecido_favorecido_id_old_fkey;
       public       postgres    false    4644    490    378            �           2606    20799 L   notificacao_destinatario notificacao_destinatario_empresa_notificado_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.notificacao_destinatario
    ADD CONSTRAINT notificacao_destinatario_empresa_notificado_id_fkey FOREIGN KEY (empresa_notificado_id) REFERENCES public.empresa(id);
 v   ALTER TABLE ONLY public.notificacao_destinatario DROP CONSTRAINT notificacao_destinatario_empresa_notificado_id_fkey;
       public       postgres    false    510    360    4628            �           2606    20804 R   notificacao_destinatario notificacao_destinatario_grupo_empresa_notificado_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.notificacao_destinatario
    ADD CONSTRAINT notificacao_destinatario_grupo_empresa_notificado_id_fkey FOREIGN KEY (grupo_empresa_notificado_id) REFERENCES public.grupo_empresa(id);
 |   ALTER TABLE ONLY public.notificacao_destinatario DROP CONSTRAINT notificacao_destinatario_grupo_empresa_notificado_id_fkey;
       public       postgres    false    403    4672    510            �           2606    20809 E   notificacao_destinatario notificacao_destinatario_notificacao_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.notificacao_destinatario
    ADD CONSTRAINT notificacao_destinatario_notificacao_id_fkey FOREIGN KEY (notificacao_id) REFERENCES public.notificacao(id);
 o   ALTER TABLE ONLY public.notificacao_destinatario DROP CONSTRAINT notificacao_destinatario_notificacao_id_fkey;
       public       postgres    false    509    4791    510            �           2606    20814 K   notificacao_destinatario notificacao_destinatario_perfil_notificado_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.notificacao_destinatario
    ADD CONSTRAINT notificacao_destinatario_perfil_notificado_id_fkey FOREIGN KEY (perfil_notificado_id) REFERENCES public.perfil(id);
 u   ALTER TABLE ONLY public.notificacao_destinatario DROP CONSTRAINT notificacao_destinatario_perfil_notificado_id_fkey;
       public       postgres    false    4829    510    543            �           2606    20819 ;   notificacao_usuario notificacao_usuario_notificacao_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.notificacao_usuario
    ADD CONSTRAINT notificacao_usuario_notificacao_id_fkey FOREIGN KEY (notificacao_id) REFERENCES public.notificacao(id);
 e   ALTER TABLE ONLY public.notificacao_usuario DROP CONSTRAINT notificacao_usuario_notificacao_id_fkey;
       public       postgres    false    4791    515    509            �           2606    20824 B   notificacao_usuario notificacao_usuario_usuario_notificado_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.notificacao_usuario
    ADD CONSTRAINT notificacao_usuario_usuario_notificado_id_fkey FOREIGN KEY (usuario_notificado_id) REFERENCES public.usuario(id);
 l   ALTER TABLE ONLY public.notificacao_usuario DROP CONSTRAINT notificacao_usuario_usuario_notificado_id_fkey;
       public       postgres    false    515    628    4926            �           2606    20829 +   numerario numerario_grupo_numerario_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.numerario
    ADD CONSTRAINT numerario_grupo_numerario_id_fkey FOREIGN KEY (grupo_numerario_id) REFERENCES public.grupo_numerario(id);
 U   ALTER TABLE ONLY public.numerario DROP CONSTRAINT numerario_grupo_numerario_id_fkey;
       public       postgres    false    4680    517    410            �           2606    20834 -   numerario numerario_usuario_conciliou_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.numerario
    ADD CONSTRAINT numerario_usuario_conciliou_id_fkey FOREIGN KEY (usuario_conciliou_id) REFERENCES public.usuario(id);
 W   ALTER TABLE ONLY public.numerario DROP CONSTRAINT numerario_usuario_conciliou_id_fkey;
       public       postgres    false    628    517    4926            �           2606    20839 %   optantes_debito optantes_debito_banco    FK CONSTRAINT     �   ALTER TABLE ONLY public.optantes_debito
    ADD CONSTRAINT optantes_debito_banco FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 O   ALTER TABLE ONLY public.optantes_debito DROP CONSTRAINT optantes_debito_banco;
       public       postgres    false    4492    247    528            �           2606    20844 N   recolhimento_transportadora recolhimento_transportadora_transportadora_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.recolhimento_transportadora
    ADD CONSTRAINT recolhimento_transportadora_transportadora_id_fkey FOREIGN KEY (transportadora_id) REFERENCES public.transportadora(id);
 x   ALTER TABLE ONLY public.recolhimento_transportadora DROP CONSTRAINT recolhimento_transportadora_transportadora_id_fkey;
       public       postgres    false    622    558    4920            �           2606    20849    sacado sacado_convenio_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.sacado
    ADD CONSTRAINT sacado_convenio_id_fkey FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 H   ALTER TABLE ONLY public.sacado DROP CONSTRAINT sacado_convenio_id_fkey;
       public       postgres    false    570    4595    334            P           2606    35730 5   saldo_transito_cash saldo_transito_cash_banco_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.saldo_transito_cash
    ADD CONSTRAINT saldo_transito_cash_banco_id_fkey FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 _   ALTER TABLE ONLY public.saldo_transito_cash DROP CONSTRAINT saldo_transito_cash_banco_id_fkey;
       public       postgres    false    4492    663    247            M           2606    35001 7   saldo_transito_cash saldo_transito_cash_empresa_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.saldo_transito_cash
    ADD CONSTRAINT saldo_transito_cash_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 a   ALTER TABLE ONLY public.saldo_transito_cash DROP CONSTRAINT saldo_transito_cash_empresa_id_fkey;
       public       postgres    false    4628    360    663            O           2606    35725 G   saldo_transito_cash saldo_transito_cash_frequencia_recolhimento_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.saldo_transito_cash
    ADD CONSTRAINT saldo_transito_cash_frequencia_recolhimento_id_fkey FOREIGN KEY (frequencia_recolhimento_id) REFERENCES public.frequencia_recolhimento(id);
 q   ALTER TABLE ONLY public.saldo_transito_cash DROP CONSTRAINT saldo_transito_cash_frequencia_recolhimento_id_fkey;
       public       postgres    false    395    663    4663            N           2606    35006 4   saldo_transito_cash saldo_transito_cash_loja_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.saldo_transito_cash
    ADD CONSTRAINT saldo_transito_cash_loja_id_fkey FOREIGN KEY (loja_id) REFERENCES public.loja(id);
 ^   ALTER TABLE ONLY public.saldo_transito_cash DROP CONSTRAINT saldo_transito_cash_loja_id_fkey;
       public       postgres    false    4761    482    663            Q           2606    35735 >   saldo_transito_cash saldo_transito_cash_transportadora_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.saldo_transito_cash
    ADD CONSTRAINT saldo_transito_cash_transportadora_id_fkey FOREIGN KEY (transportadora_id) REFERENCES public.transportadora(id);
 h   ALTER TABLE ONLY public.saldo_transito_cash DROP CONSTRAINT saldo_transito_cash_transportadora_id_fkey;
       public       postgres    false    622    663    4920            �           2606    20854 %   titulo_dda titulo_dda_arquivo_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_dda
    ADD CONSTRAINT titulo_dda_arquivo_id_fkey FOREIGN KEY (arquivo_id) REFERENCES public.arquivo(id);
 O   ALTER TABLE ONLY public.titulo_dda DROP CONSTRAINT titulo_dda_arquivo_id_fkey;
       public       postgres    false    607    4463    226            �           2606    20859 #   titulo_dda titulo_dda_banco_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_dda
    ADD CONSTRAINT titulo_dda_banco_id_fkey FOREIGN KEY (banco_id) REFERENCES public.banco(id);
 M   ALTER TABLE ONLY public.titulo_dda DROP CONSTRAINT titulo_dda_banco_id_fkey;
       public       postgres    false    4492    247    607            �           2606    20864 $   titulo_dda titulo_dda_boleto_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_dda
    ADD CONSTRAINT titulo_dda_boleto_id_fkey FOREIGN KEY (boleto_id) REFERENCES public.boleto(id);
 N   ALTER TABLE ONLY public.titulo_dda DROP CONSTRAINT titulo_dda_boleto_id_fkey;
       public       postgres    false    607    253    4494            �           2606    20869 ,   titulo_dda titulo_dda_convenio_conta_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_dda
    ADD CONSTRAINT titulo_dda_convenio_conta_id_fkey FOREIGN KEY (convenio_conta_id) REFERENCES public.convenio_conta(id);
 V   ALTER TABLE ONLY public.titulo_dda DROP CONSTRAINT titulo_dda_convenio_conta_id_fkey;
       public       postgres    false    607    338    4602                       2606    20874 .   titulo_dda_duplicado titulo_dda_duplicado_tdda    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_dda_duplicado
    ADD CONSTRAINT titulo_dda_duplicado_tdda FOREIGN KEY (titulo_dda_id) REFERENCES public.titulo_dda(id);
 X   ALTER TABLE ONLY public.titulo_dda_duplicado DROP CONSTRAINT titulo_dda_duplicado_tdda;
       public       postgres    false    4902    608    607                        2606    20879 %   titulo_dda titulo_dda_empresa_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_dda
    ADD CONSTRAINT titulo_dda_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 O   ALTER TABLE ONLY public.titulo_dda DROP CONSTRAINT titulo_dda_empresa_id_fkey;
       public       postgres    false    360    607    4628                       2606    20884 -   titulo_dda titulo_dda_fk_banco_modificador_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_dda
    ADD CONSTRAINT titulo_dda_fk_banco_modificador_id FOREIGN KEY (banco_modificador) REFERENCES public.banco(id);
 W   ALTER TABLE ONLY public.titulo_dda DROP CONSTRAINT titulo_dda_fk_banco_modificador_id;
       public       postgres    false    4492    247    607                       2606    20889 2   titulo_dda titulo_dda_usuario_movimentacao_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.titulo_dda
    ADD CONSTRAINT titulo_dda_usuario_movimentacao_id_fkey FOREIGN KEY (usuario_alteracao_id) REFERENCES public.usuario(id);
 \   ALTER TABLE ONLY public.titulo_dda DROP CONSTRAINT titulo_dda_usuario_movimentacao_id_fkey;
       public       postgres    false    4926    607    628                       2606    20894    token token_grupo_empresa_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.token
    ADD CONSTRAINT token_grupo_empresa_id FOREIGN KEY (grupo_empresa_id) REFERENCES public.grupo_empresa(id);
 F   ALTER TABLE ONLY public.token DROP CONSTRAINT token_grupo_empresa_id;
       public       postgres    false    4672    618    403                       2606    20899 I   tributo_sem_codigo_barra tributo_sem_codigo_barra_forma_pagamento_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.tributo_sem_codigo_barra
    ADD CONSTRAINT tributo_sem_codigo_barra_forma_pagamento_id_fkey FOREIGN KEY (forma_pagamento_id) REFERENCES public.forma_pagamento(id);
 s   ALTER TABLE ONLY public.tributo_sem_codigo_barra DROP CONSTRAINT tributo_sem_codigo_barra_forma_pagamento_id_fkey;
       public       postgres    false    626    388    4655            %           2606    20904 <   usuario_favorecido usuario_favorecido_favorecido_id_old_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_favorecido
    ADD CONSTRAINT usuario_favorecido_favorecido_id_old_fkey FOREIGN KEY (favorecido_id_old) REFERENCES public.favorecido(id);
 f   ALTER TABLE ONLY public.usuario_favorecido DROP CONSTRAINT usuario_favorecido_favorecido_id_old_fkey;
       public       postgres    false    4644    378    632            &           2606    20909 (   usuario_lojas usuario_lojas_loja_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_lojas
    ADD CONSTRAINT usuario_lojas_loja_id_fkey FOREIGN KEY (loja_id) REFERENCES public.loja(id);
 R   ALTER TABLE ONLY public.usuario_lojas DROP CONSTRAINT usuario_lojas_loja_id_fkey;
       public       postgres    false    482    635    4761            '           2606    20914 +   usuario_lojas usuario_lojas_usuario_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario_lojas
    ADD CONSTRAINT usuario_lojas_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 U   ALTER TABLE ONLY public.usuario_lojas DROP CONSTRAINT usuario_lojas_usuario_id_fkey;
       public       postgres    false    635    628    4926            �           2606    20919 "   log_acesso usuario_original_log_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.log_acesso
    ADD CONSTRAINT usuario_original_log_fk FOREIGN KEY (usuario_original) REFERENCES public.usuario(id);
 L   ALTER TABLE ONLY public.log_acesso DROP CONSTRAINT usuario_original_log_fk;
       public       postgres    false    4926    474    628            /           2606    20924    venda venda_empresa_id_fkey    FK CONSTRAINT        ALTER TABLE ONLY public.venda
    ADD CONSTRAINT venda_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 E   ALTER TABLE ONLY public.venda DROP CONSTRAINT venda_empresa_id_fkey;
       public       postgres    false    360    640    4628            3           2606    20929 =   vinculacao_cnpj_empresa vinculacao_cnpj_empresa_conta_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculacao_cnpj_empresa
    ADD CONSTRAINT vinculacao_cnpj_empresa_conta_id_fkey FOREIGN KEY (conta_id) REFERENCES public.conta(id);
 g   ALTER TABLE ONLY public.vinculacao_cnpj_empresa DROP CONSTRAINT vinculacao_cnpj_empresa_conta_id_fkey;
       public       postgres    false    4547    646    296            4           2606    20934 @   vinculacao_cnpj_empresa vinculacao_cnpj_empresa_convenio_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.vinculacao_cnpj_empresa
    ADD CONSTRAINT vinculacao_cnpj_empresa_convenio_id_fkey FOREIGN KEY (convenio_id) REFERENCES public.convenio(id);
 j   ALTER TABLE ONLY public.vinculacao_cnpj_empresa DROP CONSTRAINT vinculacao_cnpj_empresa_convenio_id_fkey;
       public       postgres    false    4595    334    646            �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �   i   x�34�0�4�t,-�/ʬJ<����|�Ĕ�����ĔD+����ë�2���ML��9����uLt,-���L,�M͸M-L�
�b���W� ��/      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �             x������ � �         c   x�m��� D�s\E��6Ԓ��Y�@s�z��|pe*UK��� B83�	�cdc���t��5#� GQϨ�H	�9#� �n�w��5�G��-�            x������ � �            x�31��4�4����� ��            x������ � �      
   /   x�3�,��4�4200���".C��)�!�'H���EQ���� #�	�            x������ � �         x   x�-���0Cg�c�%��26�J,ڎ]�N�0$��
]��l�1�Ȣ`�C`�=�n�:�s*q��k��Z��u~�Y�[�������6xG�-�T�M�wnԝ���R��h=cv;�"�            x������ � �            x������ � �            x������ � �            x������ � �            x������ � �            x������ � �         .   x�3�4�4����qVp��v��A����1~@����� �~	C            x������ � �            x������ � �            x������ � �             x������ � �      "      x�3�t�/*I�I�J�4����� 8�      $   E   x�3�4�L�O,�,.I䬨�242�4�CN#CN������\N����̼|�jCN��?����� �y      &      x������ � �      (      x������ � �      *   =   x�3�02��3 NC 2�3�L�� ��!� �`���Ԕ���Ȑ<#�i����� Dn       ,   >   x�3�05�4�40 bN#NK �B�&ƦƜ�@h�Y�Z\�ʙ�elaj����]a� ���      .      x������ � �      0   2   x�3�4000�"#NC�?Di�F\FF� y a�0B�7����� qq      �      x������ � �      2      x������ � �      3      x������ � �      6      x������ � �      7      x������ � �      9      x������ � �      :      x������ � �      ;      x������ � �      <      x������ � �      >   f   x�u��� ��g�(��pv���&?���%-�g��	�iK�(�3����`
;r����Bg\�.No�O�Zi�Lk�*Y%�I�}dM6GT6����0+      @      x������ � �      A      x������ � �      D      x������ � �      F      x������ � �      I      x������ � �      J      x������ � �      L      x������ � �      N      x������ � �      O      x������ � �      Q      x������ � �      S      x������ � �      U      x������ � �      V      x������ � �      Y      x������ � �      \      x������ � �      ]      x������ � �      ^      x������ � �      `      x������ � �      b      x������ � �      d   �   x��RA�� <�W�A������ ��RV=t#���_+j6��v� B <c�"�R }��5���nzo]�P�j�Oo�pȬHo��0��u�k`���jS�M�TBJE���,V�H�پ�e"��Dؤܤ�C�#��[>��RD�m|l��FF	�毽��ƌ����$��5:���y�S~�}/�ew꿺�����t�g�Y�2CC����      e   �   x����	!�g��\HLb����	�?�x�C[h9	J |�_V��J
j��R8]ϳyx�0ц�a�Q݉w&�6�)�O��:�^��;�P|�i�K����W,&v���}�����	A��0�_:h+�o�')A���4O�W�!D�wN����1� �2kS      f      x�34165�4�,�L����� )�      h   A   x�%���0�j�0d}�.���HC�ôXC�Y
b�(\=Lm6�á呅��7��e�"�>�>�7C      i      x�3�4�4�267�44165�4����� )LP      k   G   x�3��stw�U��s��u�tv�437127634000�4�4�470�tJ89z:a�0165����� ��      n      x������ � �      p      x������ � �      r      x������ � �      t      x������ � �      u      x������ � �      x      x������ � �      �      x���ˮG��=޼
�@�q���$����jГ8dw��SÃ�������M��j]���&��%���}����ė����÷�������|����o���O������o��?������x���o�4������?��e��?����Ə�����������3�J)G�9�+�0R���F��0rJ!���H���W
�.���u�#�t�6�W�'������s�5��+g
u��#��=�M��k����<��������|���Uk��{-w�}e�������ե�0��g���[8��gM���i�4F���Y`F^��`�_�-}�|1�|�)�#�����~�y�|�k�����걏��zy� 4]A�]2�z�]4{����D�d������=�gNk��j^������|5��F}�y��z��z~���7ڿ^_;~eo��޻]U^G��8ralx%,�k9J�=��s竅׍xAf�;?����:��8|��Ј�znQ�1��泳��U��v��z*��B=�QfW){��K(��γ�u��J;��2�Y���f�!ĖK8r�����;���xN�+���3f����+K���a����G��$�����7�_�U��[�\�5������:�B(m�3���q��#��,��M;���{�y~{��Zs���4�㸙���[�^�������t������1.�S��9
�O���+���)&|�L�+�Ƭ��y��hsg���/�L+�Uũg~���q�ӫ�����ӻ�<�������'��ϻ��;�W������\ǧ��_-��_}��y�����b1�rDڧ+�U��d��r��re������5�YF(9���E��J��<���әn�<V,�
���"/�½۝C�+��ZX5���]���}��.���x����.fp�Q:~�⼸Q�݅��\u��}��K���a�{���3՘�u�y"fz���'�w�p�#��Kg<�E ��Ɗƀ�<�^��-n�+�ZoF`��q�+���k��#���-������c�������N|1�0��=���"o��&z�u����heޣb/w��I8���Z�o�p��B\��5b9�u�5�ț�`0���ގ�<I�-v��H�Q���,XN���Ǯs�����}�}wW�W�c���9/���N%��Ԅq�3O�Hf��³/�d�8Q�C�9����*��^�'��o-�5���k�6s���U����Ǫ��1��mb'��9x�^��f��Yzh85����e�����cjgL�ja��H#���8.��Uvԗ��s�9/;���s�(�����i����=���o�}�;�Jeo���}�����hu�>k�N.�g^��ycs�_sSr��&�,~�p�'�X����q�S?�-�>(3�s�;p����Woe�9f�'׳6�,���U�<�1��ck-^��x��m���G�;W̟0�MO��ȸ��]�@���πqp�k�8Y�>1K.�߁o��걮�p�Nl�o^(��f;"�O�ą#�1&������u���?��b��T�ѳ���̘����m3ms����%ݼ�Q�܄���R��������^��<Q��߹�����n����he�YO�o���M)�/.ӹ�$�3���y��z���	e�_�Ux�k��
��FMk��*��O�Sq_�Ǩ���JC.�fZ��|������5E� �L,Y�M��Il�{
���N�D�`M�Hf�I�����q�B{�V&�@���.*�\��U�.'�H4�P�U�"���$�J�,���x�'�)��}�<'�LT���ؕ\G�ʼ�AVI$�0�ϝo������1����o2cq�Ky�Ș�z�R�����.���0��ɓ�4՚A�ON�wa�:�D�)Bh�qs�$m�{���d�ɛ�;�h|}����g0-|a��q��Fb�d*ɒNcY��Z����v����Ģ����T.p�`t�qEޓ��[�?��oʅ����O�tBZxޣ׉}�\lEV��$Oqk�_�A6K��b��n��҄*��d��)�R�ZA��u����}6R#���3�����B�|x����y֪Lw��=��}oNYt��B�kYe�K��.�ûsf��]������ �^��F�i[����%��$�u��Y?	�z��W"��]�t�9�*�D�	�r��U�~r��� R����qɛO�MZ��ƅec�K�$�t�*�mS+W=�u0�D�4QR�I��Sb����r��dI8>�(S^�f;�+$hn�M�X~���'��zp=r�x��dTt������e��}�'vF)��&���]�K��_�yt~�B�D�6o�"x�1x�Ef�#���_d$�.��3�i�f �c��4J�1n<z���=�YZT ��u�2q��Lx�9Q�7��ѡ����u*�:� �"��B���F��(<��Jy�f��1�t6����x ��)�x	!l^�a��\�2v��X ����žIOx���b�H���w���`d'�0�{G������qia\6�7S�F�ƺ��N,�w�77���k����Tol�gŢ3oA�"��o$j��AJ܆2�If�(�"I�ݦ��pS���;=�����J���|8�}���(_�o��
�{׫<���W<���E����9יd�ߥw=^�U�*s�~�p."��KdKe^I~�����p���4D�@�"�^2�':Hi<����ַ��BYa�@��<!<>���XOk�R�>���R��a�X5fOJ9������B���*d]�_I{�%�B�D>w_���Кwvq��A����H��o&KB�˘����� �	��wTq��P�%�2T�ץ/t�,��)�$���ՙdd�;�$�|7|�.��H�����U�S���߹^?�j�+e�P��On�m���O"�ԕ�W��&��P�����{��JZ�M�Q[��"�/�=�h�Rc��f@N"�P��t㚷$��DOo�.�R�B}��)U�����˫���=����}0ρ�Iэj���)0cO����N�:��G���8���|�N��T��?Vu�d(�p1aw6�*�OEY���/���	�xN�N����h����̸/��A�<-�+j�@y�����F��]8�u�id�C>�t�Y�������5�H#� ���/y�*Dg_��E��^�Br��`���MZ������kE�R#�s7�@ȵ�̕1R�C:��눈�Z*�	{D�3"���;n�Q=�T�$)���0{�{$vfIh\��@��<����
M�J&q�F�E�^��T$"�G^j�Z.�o���^��9+f��p�H��W��j``)��J9�I�-�u,
b�A�j�NB��s*Q�e�[�b6S�È�jT��L
/����5�7SM�)4巅��zK92�-�9#>�D��ݘ�Y&�u��ߘ��^�ȿq�x�*ȟ-w!�>���$f��⓪��*���B���1��@��E$ �Բ�}{Q:�ǡ'"��t����C�Cy��f:�'�-d¸{,�9c�ȍ6�E-��'W_R�(�"���N�I�骽i��|o�%p�y�@�Ħ�i�Gd�����0E�N��q�w���صR�zD�u7X��֙D
�1Co�^�O�'p�로B�2	OG���"�����)�&ȴ���\��{�%���ݐ_qD+W�r*�a�H���)�ܨA_��ݛ����X�V�։��
9�������ځ�h����v*ϛ*�k:��m�J���dL?HS6�)F%�z`
�
���|�U��<��}�
����6B���È=��9"����%[Ǳ��}競������_�Ă\L�}e'����͸E	�4��@�NQ0�;�}�gUma</3U�~�(���"�b%,��{�G��<*NTƸ:�1�N�?���XN�H��*�g5S�?L����)��w��E���>��6�F]%._�g�mw��$!�t� ��%������AN��Fs��;|��,��D�ň_��{�	*�wbj�mL.��gQ+>k}    }n$ʦ�CQ���*�Xf"�����56)�&�YRy%t���b�0�:�Q�TW\�	eF��(��s�	TJ x�5����2D]������*�k����ԐX
�5"�3��h�"�2��,�8h't��!��I��C�����³g-�]��<Ȱ�8j��q��xF�.ZV>��qb�xa�MHm�`�9T��J��]c"�D��8 	iG�>qJb�P��-(b� ���A�B�V���JeF6Q��z$h�'5G!�%��Ɨ&�7�OᲞ��$��B!��[�C�4)?F�K)Xy��c��[񘼓������W#�rE��)
e�y�kA�^�*Q�c#:C�jW�n�|��!��|�j��H�L�@1F����[	șBxi!m}���W/^Q�oM�n"U�� ����5RcH��y��D��k(j�H?T���ViM�L�ᾨ>o�]�y����q	�y3��y+��00��������$�ͤ�>��O����a��"���Vprekr�V�d��T�թ��n2\<,'UMUe�k-�cI̓ԥ#�$bm�筠��D�a*ZPY��a#�p��}�D�B�Qo���N��;�.I"�b�QR9k�j���2Q�P�t�ʀDZ��3S���&���h?�$ �w.钰�XO�K�k2I��c4ƃ�X�4��Qp[��N&�e���z	��c���׳�>�]��j�Ţ�X8��2�
AlVR,�aZ��H''m]�8��jA��N^����ǜ����N���ǉ��������DW�o�މ�X���	��*�0�b�I*���E���^��L@�J�z��]� � ���3J2߁y����,�t����gy�T����Hb>I6��Az�&�Q�ע|�����dO�Y�iH���Pm#�N�Fޕ_���������5��}���B-ʔ�}R,ס��(=�V�����i��HIm{�N�Ģݢ��cq�������$*R�i������vB:pˌBG��l�Y�:�ܵ��d<�}*~�1Z����^�+����HƵvŏ%�d���E�f�7���9�W\T��8!���O@����*澴9H�K!h�Z8d)�cr�dn�D�A������&-i�x�v��Q��pJ2�D��&��K�<i#٤��ʡ�ZZ�����Y��')�P����-�M��*�S�i�H��)TJT��������ϴ���{̛��v�1M2$FY���)�	�:ޞ��Q�7��PX+pg<�p��Y�'�6+��DZƟ K���sjIs``�-�ե��x���[?�D b���J��T�d�r��MFRI\b��0�C^#��g�~J�.����$V��7�P����	�l]���xD$8*�G2Ъ8�(��~֠��V�N�%��w'M�l�TIn���"������ui�0d�8BL�B��GfI�Rn��_W9��C6�x�zc��Ey�2r_��U	��?n	����p�<�A�"�L���R�'e�"���n%������$�T�o��u�1bŤj�M�V����N�D\���O�C{ԔT�!���>a�����s.����ڒ�a
ULS6����f�?��ta�\ພ2�jv
n_���=���"d=B�vp�C�7�ʳ�P.\�a���ъ�$0���I2�^U��ɀ�OZ_�K�QZp���D-���dAHY)P�`J�dkj���b���Ees2�����l�5��8bAX�3�E�P�>�h�p��2Jխ����/�dU��w�W�x�D�1H�"�����l�]����u�vd���um-@�S�7�}n��m,�޷���x&)uJ���r���'R1�55g8`��R�Q��I8���u!�%H�u��Z}O6�TP�#|�Q�g�So7�Iq��DJ�
N<�����gg�~�xC��Q�f����p3�\�|T�3��C������o��s���DTl5�n�|W�{2M�L*1,Z����u�P1a�]R��n�O��*��D�mR"URDv�,��$�A��V�ә� bE�k���B����<nJ�I����#��{�T%�1yJ�YrH�h+?�D=F�Z���g�]��b��0�_�B��A6�l\� �i,��dܤ��>!ў���:Hvp��­]���e�����ńʲ��K�LH��3��,Fx?J�"�k%����%,��B(P�ԃ�E"������,�2���*;��^��?GC�`��GH��0��������ϋ#�p2tI���(��������C]_MɄ�~k��M��Y�8�G(N���Pn�Bʷʙ�����HM��� �ߠ��?b�n�"�A��Y����$������\���rT97�+�A��B��enɫ}	�Z�/��Ar ��dJ-?��7�^����� ���<�=HB1'�H}����@u��ʝ܏zFVe�K��\�6Qل��5��H��GJP�mD��Q=ǳ@xj?NhgJC�Nё����_y�R!D�Ũ�mn駭� Ӭx���r@&`�+E"���;�;�;B��0o��N�uku�%��+�p7����_=o��_�Թx��TM\Ör��P���T�<ҝ�=��D�2�ݚ�y�3k+�g��~*	���QU���!�r��eF%џub�����4�X*�P�u
B|l���v�G	}��I��\¡�L��^���ԡ���O+2�Ha�ԮL��0G[M��BX��p��6=����J��E�MͬxJ  (�E����m��G{$&���/ؕ�C��:��$�(]�B�K����	ג�}à"�6�� �2�Xh���� �V^�ܨ��'�+kO��QbRS9� �dи���@�K�.E�C����z߇����ꙥü�-|�A��QU�21�E��n�=��c�/Q]�聭LB��S�D�8�VW�q�����֥�b�H���	�AF���Կ�䌡�!i9Mmb��O�B}�s`W�瘀z�� ��%�/2N�@�E�.�gv�U�ǺwDZ�*Ľ��/~������0fZv���S�n��z�W��(��<&�v��&�^�G������J;BN}-�y=b�d[�C����Ԓ�2�* �C�}�c��mL�z:�����)<	�8f�R�����hͦ�=c@�t�Ԟ�}#"�j�I�ɹ����F@�p%\jE�J3n��6�j@�mz�EF�Gi�}q�0k?͊��S���j�܇�+azk�Y;�8x��$A�1t8� �K?=Y����҃�%e>E�J�DL�N��T��K��NjP|�3?�=vUS���|�yl�>ś�jS�k�*��ZH����f�g>��о��1�����h��%�adwGB]Z�N1�wH�ڦ��MQ���ŇĦ�J���V��!)�l�+�30��DNQ�) 3�W����.�:y�&�Ž�N��7Fݘ?�	�OQy���������󅲨H�5Ǩ1"�2�ZT!�kՠ%���!�y�Ht*���X���p���2)Ua�|Kb#�Qo�.IYK��9��v�ҼZT��"N��&�Z�t=m)Z��v�'��n�Ū��/P0j�#����� �*?�eZXيI�I��97ګh��#h(�B�ؕڄ�^�|�P'5%�I��䖄1�r�/���i�32b��7���הЀUD�.(/7���B|HkS^�S�|P����>�%j�;�>M�Ւ9K��M���]��\������\$J��:F�8�<?˱Hx���X�NR�!���<5�x��?XH��v��d+���r��r�
j�h|[����sj�*j�K��@jEcɦ0^�:��njul5s�$ED©�7(Pĵ�q�A�A�bP(���=���)֫�\�Nek9k"BF��D��~]�#1"�H]�v͓*[}D*k/mSd̼Ur0��^���<B�d�w�B Hy���]�.m]�vhAH+��1�.���(Ĕv?��������$��)h��C�=J����GR	�%�̠>�.��|V����x��	���ֆ�u�q�L��ު��h)�k ��"XM�T�cR�-=Q��1��t*w`fX:�AyN�ez$��Ӣ���J%��u��˳ک��    ��a�����3�B��^�F)��Q)N-~R; �ԃ ɯ�0��t$��2@'��zS��z1��$����uU�V͝�V��=�ޣ6�c�a���#0��=#��zV	��T��}�^f�F���)%u���J�j�G�g�$yؠ�G{6�$�X��	�W(��Y��� ��v�����"��Q�Wt��'�Ω�(u4t������To��R���#_EpkB�;��Q�E�=+���J�̒���.�)>fBY�II(L	1�6*�(��7�BƝ���'&�����y:�g�pƃۡ�@Q�J�2'DS��13�W��
CK�˵�9w�s�)X��[��)����fGJ�[P��\>�� ���g�	� ȈM����>�2a���Ԫ/-J��^�b������\���rG������`jI�w�XV!$`�u�=%.nHa����HBpGwS��ƌ0�i�X�*�U�w��bS\�h�	�ap�V���ѭ�:w�o��*"�+c}h�ъ�-���<b%�����Vk�u_A%�_���u���C�eX�g�S�f�e'��_���ba��A�Ww�M��$;Q�_w٨*���@,����<1��M�|�OI4��s�z���$�T���]ϸ��dP)�Ug5w�Sǿ��O%��GMQ�Á���Ա�^��%��9-�'�n3 )���䰘�C��y�ZĊ��hS���쓎tjs���w5j���f�q�GӤSZH >�юQ'*�k��f�Δ�4ʎ�]6҉�<K@���yb��A����7e���N�'1�>�ݯ�M�*�3D�JA�w)"��"�u�cq�x"Sq�H*t:�X�lH&vk�s�. ���R��Շ�^�ETV����P�2s�C�r���i:������t�!|���l?��Z�BE���!-L��z�;5ݡj/m�^l�9��V���P�
B��$ۓWQ��$Q%iY�3NZVWcNt�Ӟ'��Z������͡�:�?����$d" 7p^k���Abތ�MmҵC+���%	h��RA�c�-��x��؉�!�"sT�GҚB!jO-v1�D|̤�]������*j9���slK�Y^}*ڱC!����.(Mj\���H�W���Y¥<�,���M"�����-J&L�t�^��v|�����A*�S�/�3�\�1>��x�s&i�
a���a�S�I���g�IM�
g�����HV����D'&��p6��F]���,z.�_mrǬ�p`���JE�
�EA���"ީ���>������Y��/Se�Ae�񒏫��ԝD��7#�ݙ��M�-�bL_7��,�L%����=��m��l��ͨez�Z��\��g+��(�����T3��M�.F��A��:eQuWT[��Ȅ�)A�U�:$�ۣ|(��)����c��J�$G�Z9�ե6�@�{�xj553'�q�H�L|`��Nm�|lm����%�B�cx��dE��Ԯ��m��H��>եL�BXרX�ԙ�N
���r�tϺ�i�uv�nGQ�����G�AJQM<�t4u�����H`�Nh�:	V�qw=����~��к0jg�Q�����yb��`"t�*����ɐǇ�¹t� ����`��\��Ρ��Ғ��23�ut�V#�FP΅��T�G��ia����HeZ�D�Q�#���?��"�؈��ܥ�*�F�.V��N	��EU0h$�@ֵj��2T��t�F5���ח�ɀ�Ϭ��8 cJ8���"���ĥ�S����}��TH�?�5N�;�� I�-��Yϋd~��TK�7�i����C+K�`�+���\h*�c�YKr:��%�Q��\H�g�)�ͨ���k��"��}S�K�[�DAɐn=ib�7�w��Pi���x���]{8j3��S�8�S۲Z�߲h-;Q2����j�"�6-v�2Mj��톲xgm�\���:�ɘ�v"�0�	t��&�>�Fj_w�ш���Gw�3��D��,���Kf9��Wd��g���):QD}�Up�Y�^ʷ��o�_QXQ��pf%���T�y�F��eϬE: M�{k#Tb^� *`o�nO%� ����N�"�`F�&�|�E�VPĨ���h�o�+�KO[[��<n�́x���zS��z�k��nt�U�s�j݈̺�ڨ���H����R}���ho1�;]T�S�E�T��]Q�PYlLIGŰau�3�q�L4�ߞ���cD�����'&�EZ�jb�n73p(��Π/�\.nbG�Dg&��#][.��v=��9�����y/aLJ8�#Y�4����V2�����w�׻��'��j�M�D��_P��R�zޡU�b�a)�^֡�ת-��Ѩ�)��KZ5J.猞NxdB D�T�r�m.*O�ǧ�؜��樍M�y~�]-`�B�����F��s�$�C�������ZA>y��>����Y)���j�R����"�%5�2�%x/ŹN~`���:��1$Z�bI+܌+ޫO��j�(�U4ia��i{6&F����W��z����E׫�s�M+����k<휤��ʖI�im>�~�&�$�X4ո	mѦ��xK�c ����HyX��ě٣��Ad�h��^E�@�M;Ѝ��P�=-� ��_y��D,�
�ׂ��j��wΈ��NU�Ð&<�%�A���ԙxQ�䥎ۭ)dz}�.,�١L'�w*����?(��$�گ_�t�@�,�#XJ����<c�*�A:�D��څ��!)K5Ӫ�J��x��T�1�*T9r=��u��[���8��=dw�I�����$thͮ���R���y�+�%9���w����YG��Uem7a��G�R�Q�r��P��}��N�6Zke�}���8�^�K�Հh��P@����:\�����$f[m�.=D]����(y{���yA��gT9��_zǩ�9M�zk�si��س�K��~:I�|��갗V�{����$��cL�}��������m�D���!��)F�B-�	.�澸�S�L�P���:3��,,S�)5�`�U�}���k�(�\�9"C�Ha�yF��U't�M/���!-cz"�ᡨ�?�a搢f���$}�"5��}��]�ٔ:��u'<@�V���Ť�M�%Y�-
FK<tb��Q�Cm��j-Q�qTI�=�\	���ꯓ4�G_L�۠3Z�_�c�����e�����BT3Җ!�T'S��U�����FP�Y��\rօ�P��4�څŪ��qD5����S+�2 �A	N}�~c��:B�]O���E�a���[SO�Q:&�����Ss��6VO-k���M�NU���d꾩�t\��^�⪓!#{�j'�9ء��EN�C��Z��oJ����T���u^��(�P�RP���3�m޴xaͅ@�c�ǿ�I�R�Q˅]�4�j�Z��Kh
����go.;ڌ�����Vw���İ�SQM҈b�M�ʦѱxE",��iim����`��$m���ۭ=�s=��}*Ǩ�_D=kE�q]�&^��ԩ��*��'�o=�eD�_��)�P��P�}5ͦ���.�WG������IC�'�B��N��Z2G�7K��;��Ȩ޵��Mm�Du�L|h�9���HW�^'�}��Z�(#����0�h��Q�C͵ZE���b�9�#9T];6��Qn%�Ai�#%���zBM��+�]G����L�g�9= �%m^uP�U;挂�5��j���tQ ��N�1�5Q|�!�^�!��N���TL>��,�(g�*U�IG�(u��` 2A����ɇs.�T%�X�Sޡ��7K;�|A�� �H#x��
X����H��(�qS�@�wYҡ�	B�{0���&���"���l���s�ʬ��3�)�UqS�\�W�o#r1���Hm�*�<�B�>ȓ<N�~h7�=�FU�:]j}k���&S)�Ry��"A�)	����D]�y��P��ς���U�*yZ��t���lg���KĒW�R�,A���V��	M�AH��q�1��Iq����tB�?/��ݘ�Ŀ;��)����F�VGv    2�OO�9�T��/�X !O����[}��(�tY_�-�׸@8VgE�s
t�=t���˨Љ'��(�2�:��-�^���ڍN�t�I�莡\x�J��U�j�y��H�K'멟��Ԟ���aը��ѨItVS�rJ)�\���V=��$����_���'u>�ѵΨsY��qᱷ���:k�����:H:`��<�!o*��G~i���I�Ld]�̗�'=+�&��Ig���	DO�:��������qt�^冀i���R�K���2f,�G{�@L�#������vH$�H�I��5p)}+�I��#�i�n���k�@�'�m����"�� �" 5�6.�N!������lgG~�;�26�LƠu^����h̖(AT��]��ŀ	L����D�;��k냹����6��XF����&�9W-��Y_���}�҄ȩ�Pr/*wM���:�ƥ�c,�V|t� ֣����~���M'��y<	y=��<�lI�6;�^�y ��⃜+8�N��[ѡ�o?���nahk9XӒ*��3�k_:��2��^�Ia��~�T`/-�1�j}"0RnGu�-�����H2�\U�F �G�176E����v2Hz[[z(������#3:�޹>��'���kU+b:H�њ։����|��Bg���������'�/�9�&Ő��T�m�c~zB�1��j>�Ȇ�n��eQR�Y�ʞz���ĸ����JO�dqV�WT'e�@&��t���E��t�(�S�6�8뜐iէzQV�O�Èı�����1J?Pem�>��@EB�/u-��K��C��'�GB���['���2�4���:��u�Y���ε���:�6���)d�waW�z�Z&?,��:�n!�t�zZO��Fh�<I��+����I�AK=q32�ө��!ynPg(+t�rg�/�	���k�bT�-ުp)�����7�B���X�;�lƻI9Z�����L�6��G+?	�F�])�T����V���X�%-u P�@W��ǭ�f=K-�Q6��SK=>�0��f��G�s)XrEۻŦ��ꡃI�,KmW��9l:����EL0:�[�:]W��q���[������Yx�����5-�ށ��T�N0�m��
�2h���(zbc�Q]��
)i�ֱ<�
Q�d�����ϱ_dq�1Ze�o��ozԂe\�A�]S���
R��@���B�����lȧ�WQ�Ú-9e�[�s����t�㾃�ɒ������4�/�D��'J��3x�m��9f�Vl�t������̒��ڑ��zI����b��w�h��x��Ķ2,=��L$�G��<([�X�	�@Q�k�g��V\��qYTE'��S��~סS�-�	/@�t�,T-�bzQG��:{���&O`��N��YO���r֚ĥ~-�SM�9��T6b��T�}+:)�x��Zy��0v�O=���v��t��bk��{m���|�ͷ��x\����Ɂ��^��O�nn5�KNV���gΪ6�؊��Hm(��zz��N�'C~Tj�Qq�jH�z�	]�|�Z�$:ur���9�c�z�U�#Ǵ�̍
O�lKX�M���Ss�r��bZM�,8����=}�<�{�'���ͯ� �;����	��Y7?���sO����]q����D�%��Pv=��PП�U=18�"�A�
Hm=@���s�j�S�<q�������=̉pڎ�9�W'�՗�E���!D�$b�j��l�)ЈT�jh���նҢ�jl�µQ�Ҫ ���]=�F۬���JT����yS�q�B�j�M�[�I�	�ej�O�іxD��9a[O8�Ђ�@O��RX�/֒^Z ����ֆĭ�W��Q�
�~η�p�'���c���t�Nj<�}"G�ͱ�SgW�@�z0�:��sW��O[�f 2ȡ�v��|��d`f� ir.�6�KA�JD�1!��g�f F��z$��3�Rr}�OAă�����̍i�����Q�ĵ���ڸF�M=]Y�a��ix橧h�1:%v!�*>ܥp����G����.��so��:��)�.=�d�cP�"�j ViI�V3��k����y~���өE ;@��VOL����p�+�X�dK,�@X��=���A��X�v%H�Djiv��z�����Iѣ̒�_@�ZQ;��8��S�GٺW��G$*�7e�a��x=��i֊/̠\�R�~�:��"',�D��IO��G!R=h�;i��O�TW܏j>$2Cʶ�1=s�q�b���5���ʉ����s���b3��CGU3E�>cb�8�G�
��9����5�\4��$��Ɇ���bx��MzI/�%�||���߾������`����a��Q2F�|!O2J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d������Gɤ��#F�����������6L�+�0L�0�d��'&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��&c��a2��|�m�{`2���d����}��o�����>~x��w��_��ߙ*�~�*c���2_ȓL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSe>�6�=T����U�m5W���0W�\se��'�+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2�ʘ+c���2��|�m��se�ˏo����_���������o�����F�|�F�%c���$�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�ϰ�~�L��M{	/�g������;�d���d��1J�y�Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��Q2F�%c��g��%s�9�Lx��÷�������|����o���O߼��;Ce��Ce�1T�y��2��*c���2��*c���2��*c���2��*c���2��*c���2��*c���2��*c���2��*c���2��*c���2��*c���2��*c���2��*c���2��*c���2��*c���2��* �	  c���2��*c���2��*c���2��*c���2��*c���2��*c���2��*c���2��*c���2��*c���2��*c��g��*����^�Kx����߿}��w�}k��W�a��Q2F�|!O2J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d��1J�(�d������D���ˏobx	/�g������;�d���d̒1K�y�Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��g���%s���!Ʉ��?|���޾����}������ͻ�3U�+�0U�TSe��'�*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2�ʘ*c���2��|�m�{�2?���%�������?�����>���,����,�d̒�B�d��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%c��Y2fɘ%����͒�Q,qd��,����wf�|�fɘ%c���$�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�ϰ~K�~�C�	/����?�}���?��������w?|g��W�a���2��|!O2U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�����Pe~|�Kz�/����?|�����}|��Y2_�Y2fɘ%�<�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�3l���%s�%s����3K�����Y2_�Y2fɘ%�<�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�,�d̒1K�3l��Ò�����d����}��o�����>~x��w���ߙ*�~�*c���2_ȓL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSeL�1U�TSe>�6�=T����z�����f�!      z      x������ � �      |      x������ � �      ~   �   x����
�0E��W���G̮ct0m��J7��"hS��}�ą`!s�@(`��h����4�q�3��)��0�s7�]�sN�$��R�j�����i>uٔ��@TTm�R�(t���bz����v
�����%��\����J�+9���|�'�dRaj�S�K��d�9�AB�;H�˲~㳦s      �      x������ � �      �      x������ � �      �      x�3�tNM,J�tv�����  �Z      �      x������ � �      �      x������ � �      �   �  x�m�]�%+��O��7І"��"�
f��I�	#����;*$X�?܋t�����Q�-rp>�Rn��S~ʥ�����Tm9J�?�R�>��������R���R�h�T&���K񺞚���Br�mq]8t=���=g��p.����yb� � U��T�_����tOt�n��}�nm �"�ٹ��#'j}��k�u]��1㎪-v�U�1*�\�uG��?hr�#p��49�/WK�*��T�;9�&��jN�i��$�8Z��[�Ȕ�sF#�ye5ͼ~��Q,�d��a?���8����y�Ӎ���a�e��)���d�:9���x�Y��7d��i�8�2���䔻�tÃ�Nȝ��� ����@j5������l�ԃ^]hr��s���I��sUs.wr�Յ���#�3xY �c[@��q��c������3��!���y�=��%(�r�����x��1��1)�P�#���ߌL����e���nT��;f��b�A%[����OP�A�n̜{BjࠄG�ß��_�ߟ�`:r^7��1�ɡ�G�t']���[�
�GҢE� ��[tW$tǌI�lQ$��9��:����tș��w���
j�V��܎�[A� q�pǌ��\J�Ȝ���0��:�:u�]M]�Y��~����|^�Z2�b�a���q�Z�@�?H��>tJiǡ0��Kyw��z���i�I��"<����U������ut��i����ҵd]<�o9+���~^m�����W:���i����he[���9٘�q������;�tH.d`���Έw.�Ⱥ�9['#t"v��z痎1�,pֺ�ĻP[�{�AQ�6��s�/\�<��E�r�G�á�k;�z���CF�q��y���c����v�x���f?'<T�1�]������1�9���Ļ0�Yh�ct�u�~��CW���T%����Rcst��=G�p��7'�N��n���Si}1��!vd<}�8'��u����^�8q��<Udݹڠ ��߹��Sx[w.Z6��l�Sm���f����3�֝_:�ȼ�[�'�ܜ�,5:�"�<ꗓ��	y���i�MҶ�Rcs�M�^Ŝ�{V���9�ԍ�z,5H��0D�9��_p�@�,�&�|�M'��h2���Ü�k8v*wW�e;t��/����󚷜x�<�_Ǯ6�!h�~��u엮%� ���c7�a�XΠ�k�=�����u����Kc�9���9��=�����[����i��C�2FA��o�Sio��gK�6���i�_:���!�rB�9��X����	a��!.ᠫ���p��sH��`2b�#�<�fs.d1���9t>u���R�q"ܜ/���1����gғ�~�]�'��s��X|8��ĜG�s'�J$���Q�ު:����Čw��O�y�6+��%��޵}�M�S1�!�rB��9���xx=Gb���k,�uu�z��
��a�s��Q8�V���*���/6�M��0%���hmñ��� d����]{v�)�)cr��w�|G�w�y�Ϡ�ޞ\�!�o�<�W�}{Z}y�?��;z*����g�g�R���7���xl+�n9���|G�3>"(����]}�^g����r�Ũ�N��<���\�Ԇ�7躇���:G8�c�i!	�|G�=���D�\���S���-���.��;�;xK�k8�0��cO<��d�Tw��yj�Ӥ�g� ��*]�A���F*��A���Ss��de���͏PЭ�K��ʶ�D��N4m���x��,Bطk��M[�:ƻ"� �rb
���<Vx�G��2ܡC��/�Bwi�q���t����ǤnE�~���;���v����^��1�_<����վZc,C���Y��?:��"���8-�ٿ����?�%B�      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �   "   x�356�t��s�sv���4�4�4����� KD�      �      x������ � �      �   3   x�3�t/*-�Wp�-(J-N�,�2�(JMK�,)-JTpJ�I�
��qqq =:B      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �             x������ � �            x������ � �            x������ � �            x������ � �            x������ � �      	      x������ � �            x������ � �            x������ � �            x������ � �            x������ � �            x������ � �            x������ � �            x������ � �            x������ � �            x������ � �            x������ � �            x������ � �             x������ � �      !      x������ � �      %      x������ � �      &      x������ � �      (      x������ � �      )      x������ � �      *      x������ � �      ,      x������ � �      -      x������ � �      0   $   x�3�4���4�4.#N�P���+F��� ���      2      x������ � �      4      x������ � �      5      x������ � �      7      x������ � �      8      x������ � �      :      x������ � �      �      x������ � �      <      x������ � �      >      x������ � �      A      x������ � �      C      x������ � �      D      x������ � �      F      x������ � �      J      x������ � �      L      x������ � �      M      x������ � �      O   �   x�3��p��uUpr�r�L�H�+�,,M-(��pH�M���K���4426153��4��t�Sp�V�u�Q0400����q��������!�����������	�Z�����F\1z\\\ 4�&      Q      x������ � �      �      x������ � �      S      x��}�n+9��o�S�,p_�F��|S����[Y����L���Z0跟�p� �$���� �~�������/���������?��׿��?����wߎ�������������������?�c'7\<0���Q�G�Je�������1�;>?o���v|}��.�?N��������&�C�8dC�<��������)!�1��G�?8k��q����r�����t�짷���vL��j�iؐ�E �MX鄝�b���p�����$�WW;�&��Ϸ��z~��_��������_�q�0���I��0�Gn�:��*`���z��	��4�X���2���#Sf�rr�$И3����x?���o����ϧ�}���/�t	��8~�8lǧ]�{��ca��|���0����������tM����}�d{C& �ø!\+�b~>�d{��T��� ����On�\5���{���p�8Li���9Q����t�y��h%�NsL�w�W-��������鈃���Ks|����FW�B��Zo����'8���S. N�=M�Y��᣸��3-��?�`Xm��a*N������t~=�w$�&�-�M�E����ڀ�����Q$�Y�r�����>����Y�H�x6����yPK��Ƣ�(kv��(�ර�l����$�r�p��1 ��P:Q�y'���������g���A=(�����T���N�L�Q�g�zy:�n8����r?����'��1.FidzenA��e�p���FO%��R��
o��4|�����\mk�,Sv��Y;�5����	���<΄�&?��g�Ke��~�aF��ʰN��n	��zĖ}�9�Y�nQ<���Rgrd�l�� )�'��������>ݞp\q�^���U`>)�a|h��V ��3/���Ň����~$/��*0g�0���J6��=�� tl4���z��9#�P�������|A]��^O/���H�����ʌC���xo���.�(�
록rFr,G�e��?5
�+2z8�z��\CdCl������;�H��C+g�3�Vh��i��ƄJ9��NU
�3�r_1S1g�a�P	jǤ��Rft����5�BP�agu@�w������5�p�K�gq��1�3/��� �䴿$.�᧜���}�^�:����5Ml���@#�bd���6K;c�5,�v��Y�;�p����z=A`�Wȉ�;��oW:�����$dE�;�'��䐟ғ� ���w�[�P�W�؝*$��pۓQ&Pni�2�8����
�L���7�$)O�4�gJ��z�/�7Z�7�^	B����ihD&�Ù���Tw.`,���5����f��2���.��Ĉ:H��V�  Ys��+��`�%ˌ�
Yr�hR
�� Xz��ģ�0n�0����r�������J<H�)���H��P�æ�N�m?K��E����H@ᄘ��'�����Ո��je�}XR�M<�|0�3F����/I��Ět���e�x�a��e��<�O��u�yi�`������*MlV'Vqb��P�6^�-4�  ���:MlW'�ab�a=������;I`>2�d��o�ߥ�FV�>�Q�&S����T�k�y�%��O���v� ����A�f�y���?M&�a�vB,����ήb;Ś�]K�v�Z�zp���]2Ɯb.,(q�̵ȧt�R�A���G�Eズ[
8��o��~�VvW�v��$I�;�I�d�eI���$����IKwت_DK�^g��'E~����aJ:�q��<,I�?�)����JM��`+57& �I�.+0hn����[<�z9���O��q&���I���X+��aZ0V�| j-a����N�L�p�5���5,�p�5����Lm6N�	5�a
6�mU^�c5v�q=�������t��az$�T��
��^�t=t���C
��|������z���yM��vI��K��ypҫ48�©��y��k*9����^�7���iy����G��Q��1�`�l�2����l���\Yw�la��6pΝ���j�
�:�x$�.tƥԥ����a���z�a�����_���y~N8��-�B����
ϐ�r��*���n)^�Gގ�?'��:���y)�2�oJ
!Lw.���Yh��0l������J�%�/�k���]���C�V��s0��.���i��]ݏ�����:�}��J�
��Q3��!lf����_[L-��0��Zc�����ι,�
خ�tu �n����|}�Xx9~��4��*><>�Cz<��Y>��Bs���ʂ��x`�N��3����}�i��]/w3����2X1�k�����C$@���n�3�+���e<����`s�0��'�&�T`|��x=���P�1��84	H
%a�l�-aN����y-6�v���w�����NO�"�F��o�N4n*���\!+���\��Xv��ڀd8�Lr���Z
�f�6�>M��77Rn�A RNGZ6�]�a�
����I�fŚ�1�Zz2�x�K�A]���5{�F���L����sЍ�a��<[� ��<snC7�L{X8�7v"��d.�`؂�gd��x$^(�F���@����awƍ���HXn���39ی�l�)2��ā��ƹW
4�C�����3�t!��?�>��yBk�g�#Ys��KҘGO YVc��YK�,k0M��L�I�)�a�;.���<���u��&<��k.7-���(��u�#σ;3�Zɝ�!�
H`��Tط뉴���u�I��'��䐞���8۠!g���H m��u���
^m���񹖭vd�u��©������ʸ�Fm�,�����XEk��t�<�S`Ķ�{��¨�zJs�)[���+�k0��9��`���lxuS�,x�D���X^j5����;;�ʫ����5��d'#�v�v���=�X����u��m�jU7�}0?$v{�/{+��;GBl�Z��av=��G���{bͶѣ��a;���7F*n��c09,�}Ҽ0�Ε��XЗ��3h��o�����@�w�E�� ���%����\<@��R���&+wP (����]a�<��i�ir���a�l��Y�e�b2)@�D�����\�������Pɞe �@�:�w�كP�}8� ������~����4v=¬{;eO����F��qXF����U�
�Ω	���v�q���x۟nx��s^U@��0n��bf�#�} �%�C�]��9�H:�qO�S��zf��~��H	�h���&<�����i"ʌ&]&�J����7�F*C����m����;ϟN��mY�Ҙ��������ϭ=Tb��׵�O��ہc�};^��,*>X���3<�����ou�:������x��v�f������3NN���k�jƊ�����^�/+6�@�4��؃b���γE�ˋ��2���������p�$!Eޝ�8�qD<��[��s:�+؆�m�[-$E���I�X�i&�$f�V��[d��� �Ha�L^~i�+���Y�\߆�W���N�%CHo=�Zw5{0P�}E��Ϋ%��g_/��L4z���P�,�o���
����LobD��kv��}��� �05��e;>�-I+-�lp)X��`�&��V){��0�osYi��W���H+�����/:�lI�k�������:m܌w/���q���7fC��J�!���λEUi�6��e��=Sؽuu��K�ن��B(RRPy߄+Ҧ�Kp|P�h��.yi�q�>����.Q|�>)�C�x�Ɠ�6`���Ml��(����]��$|�?ηP˧'Q�e�\2���:P����Yͷ�84g�n�f+c^oi����r�.�?��"\b~A���m.��B�',�Q�����6��D�4e�Q��$e43 �oFM���j�����`�    � e-MCI��jqϸ|�&f�����r};����6S�R9|Sò(u���'�{8�s����)���{�0��3�_�O���w<y~��'�֋}�B �����D��C�w|�,u>��Kr�Z�%�����hg�/����ܫ��sX�&f�����?�_�'_L�=ާ�n<X�֬���
�Y=yQv����z�;��~L5UTh?���>M.1X�+��t� ��Z�K��e��wH�PP�e.K�f�ևAC�\�����} �[��6�t(u����~l_������KZO2D��L��;A�>Di��>w�}~��xsY$ϝ~�߳>��y��M����1������Z�ل�
���?��+�P6��Rf'�`�� H)f]?{�A�0$���b��=FjҬ�n�8�n}&)��>�*릏��KQ���]��Z=�����7���� ��~~#B{��x&�D����c��0V���<,�u�R��R�p��<�G�����S�S�͇#�k�s��gzo|�Yo�+��dn���;(鰇T�I0�v*\�� ��v*ά��x&�q0�Ns�'4���WJ������z��]?Gn�֕��t�cCx,{3"�q�Z�P��R�u0�S���rIԬ�YK(NI�۲!/��e�; �WSo�N���Vs:)e`	l���fI/Oe�r����������9�OU�é�,���qWU����1Ʒ@xJg�6 P�MQ����~{;ca�4.T���Ya�(�7x�`��2�x���>;o�wrT�L�<���ip,o�%�����B��	�( ��Y���#��0&���\�j�쎜�ѳ�CZh�{�L�m+�gg���T���}W���M�I
JF�⸞n�m=sK!��#>S5W�Mjfy߈:�t��Cջm	(��|?����6=�ŕn�_�p�AGa�2E���oy.�ϑ��%]|��)��Y��5��z����|m�%��|eg�BT7i7tr'�kM�xS$���V�ˠ��u�V����X<(6��s�
.cw��l�TbJ����~�p���*Jǁc �z�W�Pٜ�D�(�$��PK��<�Z�<�	�Gz�e7@A� �8��.B�*�dAL{1�)�������� ��h�Sw:�6r�yCI]���p\�ie(�?�Ԇ2"qB4eu�Z^:J��T�¹J�sЄ��F�`Aه�0*6����tPfө=��%�tjf�ҩἔ�c��P�s$���+���S��l#[q0U�T:��v��?0n�S�,�j�������q�F�)7Dit�zP�u���}	��5����13W|� J���+�l%GA���<�{������@çR�0ɭ6�J_�-��&�j�t����4c�Ҹ?P5��嬄�������w�U~�,[<`{���1�%'و����|���2���J�&BM�|E~��.R�.�$*	J�~�Û:�@����Z���Uelrd+J�3K2�N�V�-K����T����w+Rk�f(=r�/�.���`����-��E��u(Z٤?�P��BmS��BM� 	W�����GJ�
�����ERTGV�bԤ�g�>=�Aӳ�����6-���� �V9hA� U�r'fbW�`�hSuÝ�H�
ך 6�⠻*��P��X�f��⁘�L����N@�h�;2�8�C�0M�d��򐜂�Mw��������A�NԖpxK�_?��)s��,]5��O-e�O��(a)S|��!�����ݞ�J܄�I���M�ޒD4�.��^���\&�\J��m���.(Z���0�Hǚ�?��ԥ�X	�!��h���8 �*�h�^����� sR{�I�¥X��oӿ3=�U�P)�����K��f���!�XF�`�
�)��؂"胅��tΉ�w����*Xx�Ǣh��Z��+�/�:S~ѳ��yd�5���@&/���+�66Oc\ҥ���ƥ��z��/��׭%0$i�Zp�o��y�|M�-�>ڔVF[7X�A�u��~��`X�Џ��xF���z~�<���A�ά_�0d<8*��|`��b��g������JnSs�b�L`��:�4�'���e֧<4�BEk��B�;�R��A�T���̝Wɭ�YA8�O��t�٬4���dJZ-,Y�[���&vb����=��3��f����o�R۔�Ž�Zm0.�(w+.��j�����oP���,�-��@P� ?'��)N}ޔdjZ�G��v���N�ih�Eu�[|,F`	�w���TQ�1RoK�~�[jl�07�"΁���І����� ���d)9�܏��c(�(g��u/�'��1}A�N�N����78�g�b&�`b�.���<�]�2�Z�=?�#?E[�h)#g�	�q%0q$��lY�����~Mr�\T����	�(qPm����%��O(���uj������Mc��X�s)7�K*��7Gƻ%������"��b����9�V���~��S,O�(%�LU�������r�^��J��2q.�)��IN��7`YK�]����ܶ����<���GY�V�o.�gV�.Ҙ�ҍq�Q�?���j���3y�N��N��5n�."���i�7Ay����);����>B�����T���!u���6/H=�R�u� �!�L� d�$�� ���S��k�r��S�)���9K"�.��*}n�b���֏��z�y" ~����swE^S~�8{�9Cr11������I`�
�]E�DG�V�s6�i
ь9M�F��	ͧ)^3OE�zI��H� ](��fX��v��2	�8?�{�8 ����?�YZm8c³u�F:�c�M�CEa=�͝�x,)�'��U�A�N�q�QjX�2�k��(�����?�������?�����m����O���2�V�^xdH�d�Iv/:a���qr�GҤ*K'�H��͸,�Z]g����i	+wc}�9��0���6vw<��m�������^�מ���T��)�J�6��lP�r���!�y%��B}�|�xjG�)��S��26������ pgƒ����G�\�ȩ1W��>?��jDKə�u���9���יp�E堘�fň�K��J����!�M��C7�}�|-�n%5�� aǙ���q�.&Z�Ԑ�͓�2������2r���2�ipv�hi���8x@]�ɔp�G<[ۡ`��n���/,�+h����v�)�Do4�+��G"
���*"~�x=�f�o�{���s1���	�I��x�J���F����_�����n&y}���q��G�	�ٯ4:Z���.q��8�:�^���1j�4djs")�)�֘�Tp�t�Y�]���(�c^� g#�����0a�E�K�zK�<5�S[d�N�5�C���c��x�s���K%;!�8=�^�OӃ��&�7&k��d�m4/nPVp�l���м߉(4,&�j�HDy0�}J���oǆ)�Js�؎G6�b����T����r�oU�Ĕ�-�:�>��T}��ǐ��R�H�h�)g��ʆ�Xo%����]t�FS8V��=����7m�s�{Գ���t}J�2���4��b��K�`�n[���?\����N�����&$)���\��$	�/*[�-�j��׌�NZn�� �#'�-�uϓ/�tO����Sv˸qަF:4�h��:�h����:��:V��W.`��k&y^	�h�g+�Z�����(m��ي�C1<�ȵ�Bu*"&*;��k-�S�^��|LQj�Q����4�ip|�p��V�lrW7+$vϦ[���k��=9��`��^(³VJ��a��_�[�K����1�����*��6C��r�`]M�ˌ@y���\�1�3	�6}C�c^��8:�莤�a��~A��Ԃ���,��_ަ�������PuBϏi�U�XN��{�Zi��K�Ru���w����q2{o�-���&S�K����k`v�)X(���C��/��
*�K��r[�Lh>�U|�$E���yɴQk{U��vk��V���=CT��Vz�vn����*j���uZyƷR�x����D�    ��y�* �w8��í�˫��+�F �lu�u�	:�3-��zTt-c�Q�8*�sCEO^o�Z���NEJ0���:��5����s��hvG�8x(�Y�ґ�����r�Q!�	����+�H\^>�b���(����gZQW�:��"d�W�"܇�����M���7H(X�������]1|Hów@Н���-AY��4a����[=���h��f�0Z������%ls5{�U4W�՝�!����� �j�@��!�?zz�[(�`��x>"����sAh�V�ݐ�T�j�]����YЏ< l�3�����kA�k��픫Edʒ�9.H{C]��
��~���nN�ڹN"b���I��n�k.�#n��ԭ���1ŝ����i�g�]�d���<�:(��N�[��e�^[��c���^�!9�r&7�CM��t"fЖ��͏˕���q�fV� +Z�t�}z����좹�.H�R,���º �Jݯl���Jn	����ӂ�aն�+�tج�]��
D��_�tZ�G�T�nBZ�F���y>N8O�Z���1�l�y>�;i�nW�:�,#&M�&���d�+��<�j�$+���Xɜ�l�`�[ȶ�*P�\�ޓ�v#���~y��W�\R��C�Dj} ��N�g�E�T�v�����3��2����;نC�>o�<r�;�L߯L�J�ĚT�C}��0��v�cj�6h�ԉ���q��}H!�����~ln�XbY��V��e��`,ɍ�T�D��9MF���J9���L���t�ecu;Gj��[rI{��:�XԄN�H�r�]fWP������.#��*�x��n��u�m�m�s��BH�Y�s޿Q\{�9%�o(r���K�����r��s�[�'h���#9�A ��������|��ƕ����֢A�Ա?3Aj�����%�U(*0!U�?#K�4K�&Ԧ�^^� ������Q��j�wb���P� �pj;+ï�P�	 6�^͡8�B-�R�v�'���lc�h�e�1<TC����sEc@`����2B �n�W�vIƳ���]R.�7r?�t��Կ��Q�����R���	;���,xe[3�)�#|Ť�9��*�W�;�S�)3<�:i�^� ���6�+���<:��Z~{q`�.U��@:�g��՜��t*��;@�Zm�"��-Q�
צ�y�W̊���^h!��4�$���RcE��fJ
�.��)�?�J��U�O�8��'�JŲ�1w�qJ��@j%U��6��������*K��H��eʊ.�6,��q�����z�L��u���e ��&y�׉%?R�Z��LR72�q_°�m ���D(����Z�Iyx�U�/��7y9���D{��WZE�/�/K!z�-{�C�RIy«�|���r���sƗT§�*��-(�4��!�^�1i:j�4���%z���q��.0O+���.V�>�$�Аw�D�EV���K��B����9 R�˭��^�Q����|�[�&�,&;�%�i�uF���L��1�g,q+���k�Ƣ z��r��U�+^����p����Y��h/Ul+�(x.�����8��;��b�v�t99;��@������H���)�)�<7��7�yLt�@Ї���'�X�~��&��K×��j����S����Çq:��}�|��+*��i*a�r�0�(V�~ɮ��Lu.,	�ۧE��T�z���c#`2�3�%����С�r���j�E�ݰ�h���-C�WN���
;��pR��*]Q����@�n�0���p)��z<��S�P{a�RH%u�ϥ�Jgơ�J�tR�K@a�x~N�P+x��.��W�ܚ��i��4~��GP!�Ȋ��P^R�	,�Pγݽ��G�[eW.����1���%߸pP��UL��H:���/O��52�z=���g2��C.*��c��z����iskWW�z;���k�+X;�b���Put�0�[���`�-?�3�l-�c�Kf�i��Gq�;e�L2>�1���6K�ѱ_�7����L�jA�R������8)Qsq���io+�NŶƫNG���J��(U*��2u���m}"S�>�zk�U*8�fx�@
[k��M�eʢm����ֲU�#ǈ�綊��T���n;��>o�EI��Y�胤�O@����_^�4,�h�6<��NˠÇI�Q��ʾ����Q_0:�Y��W�r�Vm^���bH�;t��[ꨡc�7M+�[
��T�#L�L���}���*���r� ���Qҍ��7��%�հH����%�����c;����?���X�Ep�[�;<�_ο��tKI�ǁFdy����0����gì�ı�O%O���7�U�ˌ���S��'��!�݋�w*�e�8�cD����53��jK��L����B��e*�%���)�����\-�%��9?6��⺑��Ԧ䣞�6]�D��HJ���z��?6�[�T���"��݌U���L���eu�55�����e��k�����M�2������3~���z	�1]D�̖� :�e�{=���z9����%e��7QP���z���l
��K��K�0����d�3}��dY����'c=�K-�J�A�kv�|z=���ӯO������k��"��!���/��S��ev{�$����l�KI�cB������c��i��0�������!W`<���Bgm|�+H�(�:���52�d���)�I��o�H�G�A<ʟ���c<�� �r�B����Z�M����A�[���Ů�>���c���ۍT5 2���$����(�Ȯ-����Ҋ�y����5��l{ki)�㢔�[�������d�g��zj�D���� ��|¯���	�z&z�O��0�i�O���`����{�}�{�ܯ��P����5KSl.�kn��lQ=�om`-m��M��d��6Hr�L+��,� �(cid��8q0�v}M@�h<�8��U��t#���-kFd�&��n�����t�S\�wsJ��LՉ�L��;NOO�ۥ�̮u�z=��c��X�,T܍c�M(M7	]`ZGBɤd?��Z9�۷��qpҷ��l�xz�n���RM~\��c��x��*9�n��l��A2�֝W�=2u���d���?�X��a#����ҍ._P�����������v�i��s��ٞ�Gn]�B�������C�9�������a��$����qvoSC�pAY=�e>���aR��t�5��^���%��w�ZSpRK2�U�'~�����H���Ts�Y|ͻX]K Yt��1y���	��r�y,&7{��d��@��DwM,�Zr1�S�~
��j`r1S�\�/J	L^ji��`���=�#3晧�}2��od�_$p�p��W��|���m�llP�i���̈́�ԌÆ�2;����^�S��|���Wj�#WC$�;�_V���D���5ٰ�}��s�.M��=�HE�J/��d3������x�9cnOIOi�@�S��s\�?T"��|�.���3dZeą�"�>���]fă��I����|� v��U-�y���us����5O�,
�Mt1r��&��#�ɱ�5�w�W�����6?����9��f�q�ۺ5Q��'��b�熪D���Ѝ1�H��)�N��;R@�h0�{��|�M��ߑ���yxA�z���5�2�A'4r�������~���o����(�5dq�e8���%�N;��N�褋�)	�䭛��ЖK2�P���ic���>��R��ᗱ�����k�IrN/��ަ��^��Lj����mh�W��-}��AG������3]�;��q<���mt�����%ձ�_2�#9:5�g�;F�7u���p9sR�����1	�.?s|&����Q�G.
�$d��qH��.�0a�z��u�E��q�C;!�Nq��s�Ƞ����6�|�"%BD�W^>_�>�%�9����X��륃@Z�~Ԥ���p�qz���m�7�FP|r���� �  ����M���ߘ5P���#x3��ܞ�G����s2磃��J�F��n4���z�K����-M;ı����]���>�ܣ��=Ϡ�ش� "��B��.��j]M���l��\�Y�{�^��{�6Cըr.��td������W|��u�c%�
�{F�4kDZ�<O�tS��[�stgm�$E���k��مed-��`��1s�ɦ�v��/�z�^aFK����eX��&)��?^��>	�	�o��oA^��>	I
�|�P�l���!���ݾޖ��븊��I,�Jr�u\E.�MQ/��A INֵ$�2�����+�j������a��9v ��^�uS������Ư ��S	p� �S>
u)bɐ�����'e&�9-��jv2��"v��am��/�f{^C�@7��H��;m1ooYg�����Ɠ�0c3�ȗn����O?��� �o�       T      x������ � �      V      x������ � �      Z      x������ � �      \      x������ � �      ]      x������ � �      ^   @  x�U��j#1F��a��&��NB��L�����%��+As����)N_߾��e�u�z�|Y&_�?����2�>�_�1�o��Sm��\nS[������v�ΧB�F�+�j�J�B�#�G�+��#��͈�#6+6+6�ج،�j��[��������Q��{r��$�I�@a�0a4�F�A�@b21�U�,&�A�Dc�1�uL<�I�@d4r��F#����i�4r9�F.#����i�2r9�\F#����e�0r��FN#����a�0r9��FA��Q�(`2
���AË�'�o5�j4
��F��Q�(h4
�F!��Q�(h2
�BF��Q�(e�0J��FI��Q�(a�0J%��FI��Q�(a�2J%��F)��Q�(e�0J%�RF	��Q�(a�4*��
F��Q��hT4*�
F%��Q=��n\�#pI�QѨdT0*��
FE��ϵ�p����qAl��y��u|�]����|j�f34��f35���l4��l��f�h���f�Yl���f�Yj����fW�����jv4i�h�d�`�`�dԆ���i�~ �H�      _      x������ � �      a   M   x�3�40�v�q��Wp���ttv�WpqUprv�4���2�40�ptw�u��Wp�s���;��Q���� ��x      c      x������ � �      e      x������ � �      g   �   x��ͱ�0���L�@���>$G�m�e�HY �x1:�4��+����V����Q�r��F�I�4��t�_�#������\>y�D�,F[�L3�������7R�~׊+V�_": Ԫ�2      j      x������ � �      k      x������ � �      n      x������ � �      o   `   x�3�4�4b#N#CCc]c]cNG7G�`	PʐӒ�����3�;*��@�,ld 2�d��oș����22Ə���dP�,F��� ��;i      p      x������ � �      r      x������ � �      t      x������ � �      u      x������ � �      y      x������ � �      z      x������ � �      {      x������ � �      ~      x������ � �            x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �   r   x�u��W���pr�tr�0LI�LJI25J10II62006KIJ�064NM105�4�,�4N0�&�CC��<�]��܃B�9�b����i1j��=... ��'�      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �      �      x������ � �     