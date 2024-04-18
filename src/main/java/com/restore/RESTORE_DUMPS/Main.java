package com.restore.RESTORE_DUMPS;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
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


public class Main {

    private final static Logger logger = LoggerFactory.getLogger(Main.class);

    @Autowired
    private static Environment env;

    public static void main(final String[] args) throws Exception {

        if(args != null) {
            List<String> databaseNames = new ArrayList<>();
            String dumpFileName = null;
            if(args[0].equals("0")) {
                databaseNames = Arrays.asList(
                        "EBANK_TEST_CATALOGADOR", "EBANK_TEST_PROCESSADOR", "EBANK_TEST_SUITE", "EBANK_TEST_CONCILIADOR",
                        "EBANK_TEST_PROCESSADOR_ETES", "EBANK_GITLAB_SUITE", "EBANK_GITLAB_PROCESSADOR",
                        "EBANK_GITLAB_PROCESSADOR_ETES"
                );
                dumpFileName = "bkp_suite.sql";
            }else if (args[0].equals("1")) {
                databaseNames = Arrays.asList(
                        "EEXTRATO_TEST_CATALOGADOR", "EEXTRATO_TEST_CONCILIADOR", "EEXTRATO_TEST_PROCESSADOR",
                        "EEXTRATO_TEST_SERVICO_CONCILIACAO_BANCARIA", "EEXTRATO_TEST_CONCILIADOR_ECARD_API",
                        "EEXTRATO_TEST_RETORNO_ECARD_API", "EEXTRATO_TEST_1CLIQ", "EEXTRATO_GITLAB_CATALOGADOR",
                        "EEXTRATO_GITLAB_CONCILIADOR", "EEXTRATO_GITLAB_PROCESSADOR", "EEXTRATO_REMESSA_MOTOR_SUPORTE",
                        "EEXTRATO_REMESSA_MOTOR", "EEXTRATO_TEST_REMESSA_ARQUIVO", "LOG_ACESSO_TEST_CATALOGADOR",
                        "LOG_ACESSO_TEST_CONCILIADOR", "LOG_ACESSO_TEST_PROCESSADOR", "LOG_ACESSO_TEST_1CLIQ",
                        "LOG_ACESSO_GITLAB_CATALOGADOR", "LOG_ACESSO_GITLAB_CONCILIADOR", "LOG_ACESSO_GITLAB_PROCESSADOR"
                );
            }



            for (String dbName : databaseNames) {
                dbName = dbName.toUpperCase();
                createDatabase(dbName);

                try {
                    restoreDatabase(dbName, "dump/" + (Objects.nonNull(dumpFileName) ? dumpFileName : "dump-" + dbName) );
                } catch (Exception e) {
                    logger.info("Erro durante a restauração do banco de dados '" + dbName + "': " + e.getMessage());
                }
            }
        }

    }


    private static void createDatabase(String dbName) throws Exception {
        try (Connection connection = DriverManager.getConnection("jdbc:postgresql://localhost:5432/", "postgres", "postgres");
             Statement statement = connection.createStatement()) {
            String sql = "DROP DATABASE IF EXISTS \"" + dbName + "\"";
            statement.executeUpdate(sql);
            logger.info("Banco de dados '" + dbName + "' deletado com sucesso.");
            sql = "CREATE DATABASE \"" + dbName + "\"";
            statement.executeUpdate(sql);
            logger.info("Banco de dados '" + dbName + "' criado com sucesso.");
        }
    }

    private static void restoreDatabase(String dbName, String filePath) throws Exception {
        try {
            String senha = "postgres";

            String[] env = {"PGPASSWORD=" + senha};

            String command = "\"C:/Program Files/PostgreSQL/15/bin/pg_restore.exe\"" +
                    " -d " + dbName +
                    " -U postgres" +
                    " -h localhost" +
                    " -c -v" +
                    " \"" + filePath + "\"";

            Process process = Runtime.getRuntime().exec(command, env);

            Thread stdOutThread = new Thread(() -> {
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                    reader.lines().forEach(System.out::println);
                } catch (IOException e) {
                    e.printStackTrace();
                }
            });

            Thread stdErrThread = new Thread(() -> {
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getErrorStream()))) {
                    reader.lines().forEach(System.err::println);
                } catch (IOException e) {
                    e.printStackTrace();
                }
            });

            stdOutThread.start();
            stdErrThread.start();

            int exitCode = process.waitFor();

            stdOutThread.join();
            stdErrThread.join();

            if (exitCode == 0) {
                logger.info("Banco de dados '" + dbName + "' restaurado com sucesso.");
            } else {
                throw new RuntimeException("Falha ao restaurar o banco de dados '" + dbName + "'.");
            }

        } catch (IOException | InterruptedException e) {
            throw new RuntimeException("Erro durante o processo de restauração do banco de dados '" + dbName + "'.", e);
        }
    }
}
