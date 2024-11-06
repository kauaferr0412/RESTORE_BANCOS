package com.restore.RESTORE_DUMPS;

import com.restore.RESTORE_DUMPS.enums.BancoCard;
import com.restore.RESTORE_DUMPS.enums.BancoSuite;
import com.restore.RESTORE_DUMPS.restore.Restore;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

/**
 * FIXME PARAMETROS - [ RODE A APLICAÇÃO COM UM DOS SEGUINTES PARÂMETROS ABAIXO ] :
 * (0)  - CRIAÇÃO BANCOS DA SUÍTE FINANCEIRA COM OS BANCOS LISTADOS: {@link com.restore.RESTORE_DUMPS.enums.BancoSuite}
 * (1)  - CRIAÇÃO BANCOS DO EXTRATO CARD COM OS BANCOS LISTADOS: {@link com.restore.RESTORE_DUMPS.enums.BancoCard}
 */
public class Main {

    private final static Logger logger = LoggerFactory.getLogger(Main.class);

    private static String DUMP_SUITE = "bkp_suite.sql";

    public static void main(final String[] args) throws Exception {
        if (Objects.nonNull(args)) {
            String parametroProjeto = args[0];
            List<String> databaseNames = montarNomesBancos(parametroProjeto);

            Restore.createGlobalRole();

            for (String dbName : databaseNames) {
                dbName = dbName.toUpperCase();
                Restore.createDatabase(dbName);

                try {
                    Restore.restoreDatabase(dbName, "dump/" + (parametroProjeto.equals("0") ? DUMP_SUITE : "dump-" + dbName));
                } catch (Exception e) {
                    logger.info("ERRO DURANTE A EXECUÇÃO DO RESTORE '" + dbName + "': " + e.getMessage());
                }
            }
        }
    }

    private static List<String> montarNomesBancos(String parametroProjeto) {
        if (parametroProjeto.equals("0")) {
            return Arrays.stream(BancoSuite.values())
                    .map(Enum::name)
                    .collect(Collectors.toList());
        } else if (parametroProjeto.equals("1")) {
            return Arrays.stream(BancoCard.values())
                    .map(Enum::name)
                    .collect(Collectors.toList());
        }
        return new ArrayList<>();
    }
}
