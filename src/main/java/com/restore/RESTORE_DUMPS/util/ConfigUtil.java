package com.restore.RESTORE_DUMPS.util;


import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

public class ConfigUtil {
    private static final Properties properties = new Properties();

    static {
        try (InputStream input = ConfigUtil.class.getClassLoader().getResourceAsStream("application.properties")) {
            if (input == null) {
                throw new IOException("ARQUIVO application.properties NÃO ENCONTRADO.");
            }
            properties.load(input);
        } catch (IOException e) {
            throw new ExceptionInInitializerError("FALHA AO CARREGAR AS CONFIGURAÇÕES: " + e.getMessage());
        }
    }

    public static String getProperty(String key) {
        return properties.getProperty(key);
    }
}