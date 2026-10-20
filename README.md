# NODO — Centro de inventario

Aplicación web local para administrar y consultar el inventario en Oracle. Java sirve la página y realiza las operaciones de base de datos mediante JDBC.

## Preparar Oracle

En SQL Developer, conéctate con el usuario `INVENTARIO` y ejecuta `sql/Instalar_Inventario.sql`.

## Configurar la conexión

Abre `src/main/java/cl/inventario/ConexionBD.java` y completa `URL`, `USUARIO` y `CLAVE` con los datos de tu Oracle local. El repositorio deja `TU_CLAVE` como marcador para no publicar una contraseña.

## Ejecutar

Necesitas JDK 17 y Maven. Desde la carpeta del proyecto ejecuta:

```powershell
mvn compile exec:java
```

Cuando la consola indique que Oracle conectó correctamente, abre [http://localhost:8080](http://localhost:8080).

La aplicación consulta las tablas `productos`, `categorias` y `proveedores`. Al registrar un pedido, Java llama al procedimiento `PKG_INVENTARIO.REGISTRAR_PEDIDO` y Oracle actualiza el stock mediante el trigger.
