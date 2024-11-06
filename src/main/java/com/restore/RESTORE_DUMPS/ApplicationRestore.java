package com.restore.RESTORE_DUMPS;

import com.restore.RESTORE_DUMPS.restore.Main;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ApplicationRestore implements CommandLineRunner {


	public static void main(String[] args) {
		SpringApplication.run(ApplicationRestore.class, args);
	}

	@Override
	public void run(String... args) throws Exception {
		Main.main(args);
	}
}
