package cl.inventario;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class ConexionBD {
  private static final String URL = "jdbc:oracle:thin:@//localhost:1521/XE";
  private static final String USUARIO = "inventario";
  private static final String CLAVE = "TU_CLAVE";

  public static Connection conectar() throws SQLException {
    return DriverManager.getConnection(URL, USUARIO, CLAVE);
  }
}
