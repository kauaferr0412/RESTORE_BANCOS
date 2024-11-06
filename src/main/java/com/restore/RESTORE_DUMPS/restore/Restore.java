package com.restore.RESTORE_DUMPS.restore;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.Statement;

public class Restore {

    private final static Logger logger = LoggerFactory.getLogger(Restore.class);

    public static void createDatabase(String dbName) throws Exception {
        try (Connection connection = DriverManager.getConnection("jdbc:postgresql://localhost:5432/", "postgres", "postgres");
             Statement statement = connection.createStatement()) {
            String sql = "DROP DATABASE IF EXISTS \"" + dbName + "\"";
            statement.executeUpdate(sql);
            logger.info("BANCO DE DADOS '" + dbName + "' DELETADO COM SUCESSO.");
            sql = "CREATE DATABASE \"" + dbName + "\"";
            statement.executeUpdate(sql);
            logger.info("BANCO DE DADOS '" + dbName + "' CRIADO COM SUCESSO.");
        }
    }

    public static void restoreDatabase(String dbName, String filePath) throws Exception {
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
                logger.info("BANCO DE DADOS '" + dbName + "' RESTAURADO COM SUCESSO.");
            } else {
                throw new RuntimeException("FALHA AO RESTAURAR O BANCO DE DADOS '" + dbName + "'.");
            }

        } catch (IOException | InterruptedException e) {
            throw new RuntimeException("ERRO DURANTE O PROCESSO DE RESTAURAÇÃO DO BANCO DE DADOS '" + dbName + "'.", e);
        }
    }


    public static void createGlobalRole() {
        String roleName = "bv_postgres";
        String password = "postgres";

        try (Connection connection = DriverManager.getConnection("jdbc:postgresql://localhost:5432/postgres", "postgres", "postgres");
             Statement statement = connection.createStatement()) {

            String sqlCreateRole = "DO $$ BEGIN " +
                    "IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '" + roleName + "') THEN " +
                    "CREATE ROLE " + roleName + " WITH SUPERUSER LOGIN PASSWORD '" + password + "' CREATEROLE CREATEDB INHERIT; " +
                    "END IF; " +
                    "END $$;";
            statement.execute(sqlCreateRole);

            logger.info("NOVA ROLE/LOGIN GLOBAL '" + roleName + "' CRIADA COM PRIVILÉGIOS DE SUPERUSER NO SERVIDOR.");

        } catch (Exception e) {
            logger.error("ERRO AO CRIAR A ROLE/LOGIN GLOBAL: " + e.getMessage());
        }
    }

}
