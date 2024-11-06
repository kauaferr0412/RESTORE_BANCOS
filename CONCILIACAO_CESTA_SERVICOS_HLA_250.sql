-- 1 CRIAÇÃO DA TABELA DE grupos_lancamentos_tarifas------------------------------------------------------------------------------------------------------------------
CREATE TABLE public.grupos_lancamentos_tarifas (
   grupo_lancamento_id int8 NOT NULL,
   chave_lancamento varchar(120) NOT NULL,
   id bigserial NOT NULL,
   CONSTRAINT pk_grupos_lancamentos_tarifas PRIMARY KEY (id)
);

CREATE UNIQUE INDEX idx_grupos_lancamentos_tarifas_id ON public.grupos_lancamentos_tarifas USING btree (grupo_lancamento_id, chave_lancamento);

ALTER TABLE public.grupos_lancamentos_tarifas ADD CONSTRAINT fk_grupos_lancamentos_tarifas_grupo_lancamento FOREIGN KEY (grupo_lancamento_id) REFERENCES public.grupo_lancamento(id);

-- 2 ADICIONANDO COLUNA DE status_conciliacao-------------------------------------------------------------------------------------------------------------------
ALTER TABLE grupo_lancamento ADD COLUMN status_conciliacao int;