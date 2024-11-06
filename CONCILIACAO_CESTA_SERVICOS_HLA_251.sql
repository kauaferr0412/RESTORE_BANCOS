-- 1 CRIANDO TABELA DE EVENTOS PRA CONCILIAÇÃO CESTA SERVIÇOS ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS "event"."conciliacao-cesta-servicos-evento" (
    nu_sequencial BIGSERIAL NOT null,
    id BIGSERIAL NOT null,
    id_evento uuid DEFAULT gen_random_uuid() NOT NULL,
    data_hora_evento timestamp DEFAULT now() NOT NULL,
    data_inicial date NOT NULL,
    data_final date NOT NULL,
    id_empresa int8 NOT NULL,
    id_conta int8 NOT NULL,
    id_controle_upload int8 NOT NULL,
    CONSTRAINT "unique-id_evento-conciliacao-cesta-servicos-evento" UNIQUE (id_evento)
    );

CREATE INDEX "conciliacao-cesta-servicos-evento-data_hora_evento-id" ON "event"."conciliacao-cesta-servicos-evento" USING btree (data_hora_evento, id_evento);