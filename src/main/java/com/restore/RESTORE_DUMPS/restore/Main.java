package com.restore.RESTORE_DUMPS.restore;

import com.restore.RESTORE_DUMPS.enums.BancoCard;
import com.restore.RESTORE_DUMPS.enums.BancoSuite;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.env.Environment;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;


public class Main {

    private final static Logger logger = LoggerFactory.getLogger(Main.class);

    private static String DUMP_SUITE = "bkp_suite.sql";

    public static void main(final String[] args) throws Exception {
        if(Objects.nonNull(args)) {
            String parametroProjeto = args[0];
            List<String> databaseNames = montarNomesBancos(parametroProjeto);

            for (String dbName : databaseNames) {
                dbName = dbName.toUpperCase();
                Restore.createDatabase(dbName);

                try {
                    Restore.restoreDatabase(dbName, "dump/" + (parametroProjeto.equals("0") ? DUMP_SUITE : "dump-" + dbName) );
                } catch (Exception e) {
                    logger.info("Erro durante a restauração do banco de dados '" + dbName + "': " + e.getMessage());
                }
            }
        }

    }

    private static List<String> montarNomesBancos( String parametroProjeto ) {
        if(parametroProjeto.equals("0")) {
            return Arrays.stream(BancoSuite.values())
                    .map(Enum::name)
                    .collect(Collectors.toList());
        }else if (parametroProjeto.equals("1")) {
            return Arrays.stream(BancoCard.values())
                    .map(Enum::name)
                    .collect(Collectors.toList());
        }
        return new ArrayList<>();
    }
}