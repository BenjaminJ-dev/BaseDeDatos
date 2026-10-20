-- NODO | Instalación local del inventario Oracle
-- Ejecutar UNA SOLA VEZ en una hoja SQL conectada como INVENTARIO.
-- En SQL Developer usar F5 (Ejecutar script), no Ctrl+Enter.
-- Requiere Oracle que admita columnas IDENTITY (Oracle 12c o posterior).
-- Incluye tablas, datos iniciales, package, procedimientos, funciones y triggers.
-- No ejecuta pedidos de demostración ni consume stock al instalar.
SET SERVEROUTPUT ON SIZE UNLIMITED;
PROMPT === CREANDO ESQUEMA DE INVENTARIO ===
CREATE TABLE categorias (
  id_categoria NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre_categoria VARCHAR2(60) NOT NULL,
  descripcion VARCHAR2(200)
);
CREATE TABLE proveedores (
  id_proveedor NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre_proveedor VARCHAR2(80) NOT NULL,
  contacto VARCHAR2(80), telefono VARCHAR2(20)
);
CREATE TABLE clientes (
  id_cliente NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre VARCHAR2(80) NOT NULL, email VARCHAR2(100) UNIQUE,
  telefono VARCHAR2(20), fecha_registro DATE DEFAULT SYSDATE
);
CREATE TABLE productos (
  id_producto NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre_producto VARCHAR2(120) NOT NULL,
  id_categoria NUMBER NOT NULL REFERENCES categorias(id_categoria),
  id_proveedor NUMBER NOT NULL REFERENCES proveedores(id_proveedor),
  precio NUMBER(10,2) NOT NULL CHECK (precio > 0),
  stock_actual NUMBER NOT NULL CHECK (stock_actual >= 0),
  stock_minimo NUMBER NOT NULL CHECK (stock_minimo >= 0)
);
CREATE TABLE pedidos (
  id_pedido NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_cliente NUMBER NOT NULL REFERENCES clientes(id_cliente),
  fecha_pedido DATE DEFAULT SYSDATE,
  estado VARCHAR2(20) DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE','PROCESADO','ANULADO'))
);
CREATE TABLE detalle_pedido (
  id_detalle NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_pedido NUMBER NOT NULL REFERENCES pedidos(id_pedido),
  id_producto NUMBER NOT NULL REFERENCES productos(id_producto),
  cantidad NUMBER NOT NULL CHECK (cantidad > 0),
  precio_unitario NUMBER(10,2) NOT NULL
);
CREATE TABLE log_stock_critico (
  id_log NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_producto NUMBER NOT NULL REFERENCES productos(id_producto),
  fecha_evento DATE DEFAULT SYSDATE,
  stock_al_momento NUMBER NOT NULL, mensaje VARCHAR2(200) NOT NULL
);
INSERT INTO categorias (nombre_categoria, descripcion) VALUES ('Procesadores','CPUs para equipos gaming');
INSERT INTO categorias (nombre_categoria, descripcion) VALUES ('Tarjetas de Video','GPUs dedicadas');
INSERT INTO categorias (nombre_categoria, descripcion) VALUES ('Memorias RAM','Memorias DDR4 y DDR5');
INSERT INTO categorias (nombre_categoria, descripcion) VALUES ('Almacenamiento','SSD y HDD');
INSERT INTO categorias (nombre_categoria, descripcion) VALUES ('Accesorios RGB','Categoria sin productos para probar NO_DATA_FOUND');
INSERT INTO proveedores (nombre_proveedor, contacto, telefono) VALUES ('TechDist SpA','Pablo Iturra','+56912345601');
INSERT INTO proveedores (nombre_proveedor, contacto, telefono) VALUES ('GamerParts Ltda','Fernanda Munoz','+56912345602');
INSERT INTO proveedores (nombre_proveedor, contacto, telefono) VALUES ('ImportPC S.A.','Rodrigo Vega','+56912345603');
INSERT INTO clientes (nombre,email,telefono) VALUES ('Juan Perez','juan.perez@mail.com','+56911111111');
INSERT INTO clientes (nombre,email,telefono) VALUES ('Maria Soto','maria.soto@mail.com','+56922222222');
INSERT INTO clientes (nombre,email,telefono) VALUES ('Diego Rojas','diego.rojas@mail.com','+56933333333');
INSERT INTO clientes (nombre,email,telefono) VALUES ('Camila Vidal','camila.vidal@mail.com','+56944444444');
INSERT INTO clientes (nombre,email,telefono) VALUES ('Sofia Torres','sofia.torres@mail.com','+56955555555');
INSERT INTO productos (nombre_producto,id_categoria,id_proveedor,precio,stock_actual,stock_minimo) VALUES ('AMD Ryzen 7 7800X3D',1,1,349990,12,5);
INSERT INTO productos (nombre_producto,id_categoria,id_proveedor,precio,stock_actual,stock_minimo) VALUES ('Intel Core i5-14600K',1,3,289990,3,5);
INSERT INTO productos (nombre_producto,id_categoria,id_proveedor,precio,stock_actual,stock_minimo) VALUES ('NVIDIA RTX 4070 Super',2,2,699990,2,4);
INSERT INTO productos (nombre_producto,id_categoria,id_proveedor,precio,stock_actual,stock_minimo) VALUES ('NVIDIA RTX 4060',2,2,429990,15,5);
INSERT INTO productos (nombre_producto,id_categoria,id_proveedor,precio,stock_actual,stock_minimo) VALUES ('AMD Radeon RX 7800 XT',2,1,549990,4,3);
INSERT INTO productos (nombre_producto,id_categoria,id_proveedor,precio,stock_actual,stock_minimo) VALUES ('Kingston Fury Beast 32GB',3,1,59990,25,10);
INSERT INTO productos (nombre_producto,id_categoria,id_proveedor,precio,stock_actual,stock_minimo) VALUES ('Corsair Vengeance 16GB',3,3,34990,4,10);
INSERT INTO productos (nombre_producto,id_categoria,id_proveedor,precio,stock_actual,stock_minimo) VALUES ('Samsung 990 Pro 2TB SSD',4,1,159990,10,5);
INSERT INTO productos (nombre_producto,id_categoria,id_proveedor,precio,stock_actual,stock_minimo) VALUES ('WD Black SN850X 1TB',4,3,99990,2,6);
INSERT INTO productos (nombre_producto,id_categoria,id_proveedor,precio,stock_actual,stock_minimo) VALUES ('Seagate Barracuda 2TB HDD',4,2,54990,20,8);
COMMIT;

DECLARE
  TYPE r_producto_critico IS RECORD (
    id_producto productos.id_producto%TYPE,
    nombre_producto productos.nombre_producto%TYPE,
    categoria categorias.nombre_categoria%TYPE,
    proveedor proveedores.nombre_proveedor%TYPE,
    stock_actual productos.stock_actual%TYPE,
    stock_minimo productos.stock_minimo%TYPE
  );
  TYPE t_productos_criticos IS VARRAY(20) OF r_producto_critico;
  v_criticos t_productos_criticos := t_productos_criticos();
  CURSOR c_categorias IS SELECT id_categoria,nombre_categoria FROM categorias ORDER BY id_categoria;
  CURSOR c_productos_criticos(p_categoria NUMBER) IS
    SELECT p.id_producto,p.nombre_producto,pr.nombre_proveedor,p.stock_actual,p.stock_minimo
    FROM productos p JOIN proveedores pr ON pr.id_proveedor=p.id_proveedor
    WHERE p.id_categoria=p_categoria AND p.stock_actual<p.stock_minimo ORDER BY p.stock_actual;
  v_nombre productos.nombre_producto%TYPE;
  ex_varray_lleno EXCEPTION;
BEGIN
  DBMS_OUTPUT.PUT_LINE('REPORTE DE STOCK CRITICO POR CATEGORIA');
  FOR cat IN c_categorias LOOP
    DBMS_OUTPUT.PUT_LINE('Categoria: ' || cat.nombre_categoria);
    FOR prod IN c_productos_criticos(cat.id_categoria) LOOP
      IF v_criticos.COUNT = v_criticos.LIMIT THEN RAISE ex_varray_lleno; END IF;
      v_criticos.EXTEND;
      v_criticos(v_criticos.LAST).id_producto := prod.id_producto;
      v_criticos(v_criticos.LAST).nombre_producto := prod.nombre_producto;
      v_criticos(v_criticos.LAST).categoria := cat.nombre_categoria;
      v_criticos(v_criticos.LAST).proveedor := prod.nombre_proveedor;
      v_criticos(v_criticos.LAST).stock_actual := prod.stock_actual;
      v_criticos(v_criticos.LAST).stock_minimo := prod.stock_minimo;
      DBMS_OUTPUT.PUT_LINE('  ' || prod.nombre_producto || ' - ' || prod.nombre_proveedor || ' (' || prod.stock_actual || '/' || prod.stock_minimo || ')');
    END LOOP;
    BEGIN
      SELECT nombre_producto INTO v_nombre FROM (
        SELECT nombre_producto FROM productos WHERE id_categoria=cat.id_categoria ORDER BY stock_actual
      ) WHERE ROWNUM=1;
      DBMS_OUTPUT.PUT_LINE('  Menor stock: ' || v_nombre);
    EXCEPTION WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('  NO_DATA_FOUND: categoria sin productos');
    END;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Registros criticos guardados en VARRAY: ' || v_criticos.COUNT);
EXCEPTION WHEN ex_varray_lleno THEN
  DBMS_OUTPUT.PUT_LINE('Excepcion propia: el VARRAY alcanzo su limite');
END;
/
DECLARE
  v_total NUMBER;
  ex_categoria_sin_productos EXCEPTION;
BEGIN
  SELECT COUNT(*) INTO v_total FROM productos WHERE id_categoria=5;
  IF v_total=0 THEN RAISE ex_categoria_sin_productos; END IF;
EXCEPTION WHEN ex_categoria_sin_productos THEN
  DBMS_OUTPUT.PUT_LINE('Excepcion propia: Accesorios RGB no tiene productos; se requiere reposicion.');
END;
/
DECLARE
  v_total NUMBER;
  v_promedio NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_total FROM productos WHERE id_categoria=5;
  v_promedio := 100 / v_total;
EXCEPTION WHEN ZERO_DIVIDE THEN
  DBMS_OUTPUT.PUT_LINE('Excepcion Oracle ZERO_DIVIDE: no se puede dividir por una categoria vacia.');
END;
/

CREATE OR REPLACE PACKAGE pkg_inventario AS
  TYPE r_producto_critico IS RECORD (
    id_producto productos.id_producto%TYPE, nombre_producto productos.nombre_producto%TYPE,
    stock_actual productos.stock_actual%TYPE, stock_minimo productos.stock_minimo%TYPE
  );
  TYPE t_productos_criticos IS VARRAY(50) OF r_producto_critico;
  ex_stock_insuficiente EXCEPTION;
  ex_cliente_inexistente EXCEPTION;
  ex_varray_limite EXCEPTION;
  FUNCTION valor_inventario_categoria(p_id_categoria NUMBER) RETURN NUMBER;
  FUNCTION producto_bajo_stock(p_id_producto NUMBER) RETURN VARCHAR2;
  FUNCTION obtener_productos_criticos(p_id_categoria NUMBER) RETURN t_productos_criticos;
  PROCEDURE registrar_pedido(p_id_cliente NUMBER,p_id_producto NUMBER,p_cantidad NUMBER,p_id_pedido OUT NUMBER);
  PROCEDURE reporte_stock_critico;
END pkg_inventario;
/
CREATE OR REPLACE PACKAGE BODY pkg_inventario AS
  FUNCTION valor_inventario_categoria(p_id_categoria NUMBER) RETURN NUMBER IS v_valor NUMBER;
  BEGIN
    SELECT NVL(SUM(precio*stock_actual),0) INTO v_valor FROM productos WHERE id_categoria=p_id_categoria;
    RETURN v_valor;
  END;
  FUNCTION producto_bajo_stock(p_id_producto NUMBER) RETURN VARCHAR2 IS v_actual NUMBER; v_minimo NUMBER;
  BEGIN
    SELECT stock_actual,stock_minimo INTO v_actual,v_minimo FROM productos WHERE id_producto=p_id_producto;
    RETURN CASE WHEN v_actual<v_minimo THEN 'SI' ELSE 'NO' END;
  EXCEPTION WHEN NO_DATA_FOUND THEN RETURN 'PRODUCTO NO EXISTE'; END;
  FUNCTION obtener_productos_criticos(p_id_categoria NUMBER) RETURN t_productos_criticos IS
    v_resultado t_productos_criticos := t_productos_criticos();
    CURSOR c_criticos(p_categoria NUMBER) IS
      SELECT id_producto,nombre_producto,stock_actual,stock_minimo FROM productos
      WHERE id_categoria=p_categoria AND stock_actual<stock_minimo ORDER BY stock_actual;
  BEGIN
    FOR r IN c_criticos(p_id_categoria) LOOP
      IF v_resultado.COUNT=v_resultado.LIMIT THEN RAISE ex_varray_limite; END IF;
      v_resultado.EXTEND;
      v_resultado(v_resultado.LAST).id_producto:=r.id_producto;
      v_resultado(v_resultado.LAST).nombre_producto:=r.nombre_producto;
      v_resultado(v_resultado.LAST).stock_actual:=r.stock_actual;
      v_resultado(v_resultado.LAST).stock_minimo:=r.stock_minimo;
    END LOOP;
    RETURN v_resultado;
  END;
  PROCEDURE registrar_pedido(p_id_cliente NUMBER,p_id_producto NUMBER,p_cantidad NUMBER,p_id_pedido OUT NUMBER) IS
    v_precio productos.precio%TYPE; v_stock productos.stock_actual%TYPE; v_existe NUMBER;
  BEGIN
    SAVEPOINT registrar_pedido_sp;
    IF p_cantidad IS NULL OR p_cantidad<=0 THEN RAISE_APPLICATION_ERROR(-20004,'La cantidad debe ser mayor que cero'); END IF;
    SELECT COUNT(*) INTO v_existe FROM clientes WHERE id_cliente=p_id_cliente;
    IF v_existe=0 THEN RAISE ex_cliente_inexistente; END IF;
    SELECT precio,stock_actual INTO v_precio,v_stock FROM productos WHERE id_producto=p_id_producto FOR UPDATE;
    IF p_cantidad>v_stock THEN RAISE ex_stock_insuficiente; END IF;
    INSERT INTO pedidos(id_cliente,estado) VALUES(p_id_cliente,'PROCESADO') RETURNING id_pedido INTO p_id_pedido;
    INSERT INTO detalle_pedido(id_pedido,id_producto,cantidad,precio_unitario) VALUES(p_id_pedido,p_id_producto,p_cantidad,v_precio);
  EXCEPTION
    WHEN ex_cliente_inexistente THEN ROLLBACK TO registrar_pedido_sp; RAISE_APPLICATION_ERROR(-20001,'Cliente inexistente: '||p_id_cliente);
    WHEN ex_stock_insuficiente THEN ROLLBACK TO registrar_pedido_sp; RAISE_APPLICATION_ERROR(-20002,'Stock insuficiente para producto '||p_id_producto);
    WHEN NO_DATA_FOUND THEN ROLLBACK TO registrar_pedido_sp; RAISE_APPLICATION_ERROR(-20003,'Producto inexistente: '||p_id_producto);
    WHEN OTHERS THEN ROLLBACK TO registrar_pedido_sp; RAISE;
  END;
  PROCEDURE reporte_stock_critico IS
    CURSOR c_categorias IS SELECT id_categoria,nombre_categoria FROM categorias ORDER BY id_categoria;
    v_criticos t_productos_criticos;
  BEGIN
    DBMS_OUTPUT.PUT_LINE('REPORTE VIA PACKAGE');
    FOR cat IN c_categorias LOOP
      v_criticos:=obtener_productos_criticos(cat.id_categoria);
      IF v_criticos.COUNT=0 THEN DBMS_OUTPUT.PUT_LINE(cat.nombre_categoria || ': sin productos criticos');
      ELSE FOR i IN 1..v_criticos.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(cat.nombre_categoria || ': ' || v_criticos(i).nombre_producto || ' (' || v_criticos(i).stock_actual || '/' || v_criticos(i).stock_minimo || ')');
      END LOOP; END IF;
    END LOOP;
  END;
END pkg_inventario;
/

CREATE OR REPLACE TRIGGER trg_valida_precio_producto
BEFORE INSERT OR UPDATE OF precio ON productos FOR EACH ROW
BEGIN
  IF :NEW.precio<=0 THEN RAISE_APPLICATION_ERROR(-20010,'El precio debe ser mayor que cero'); END IF;
END;
/
CREATE OR REPLACE TRIGGER trg_actualizar_stock
AFTER INSERT ON detalle_pedido FOR EACH ROW
BEGIN
  UPDATE productos SET stock_actual=stock_actual-:NEW.cantidad
  WHERE id_producto=:NEW.id_producto AND stock_actual>=:NEW.cantidad;
  IF SQL%ROWCOUNT=0 THEN RAISE_APPLICATION_ERROR(-20011,'No hay stock disponible para el detalle solicitado'); END IF;
END;
/
CREATE OR REPLACE TRIGGER trg_log_stock_critico
AFTER UPDATE OF stock_actual ON productos FOR EACH ROW
WHEN (NEW.stock_actual < NEW.stock_minimo AND OLD.stock_actual >= OLD.stock_minimo)
BEGIN
  INSERT INTO log_stock_critico(id_producto,stock_al_momento,mensaje)
  VALUES(:NEW.id_producto,:NEW.stock_actual,'Producto paso a stock critico ('||:NEW.stock_actual||'/'||:NEW.stock_minimo||')');
END;
/

-- Complemento de la solución de inventario. Ejecutar después del esquema y datos entregados.
-- Agrega procedimientos y funciones con/sin parámetros, rutina privada de package,
-- y trigger de sentencia. Los objetos existentes del archivo base se conservan.

CREATE OR REPLACE PROCEDURE pr_reporte_stock_critico IS
BEGIN
  DBMS_OUTPUT.PUT_LINE('REPORTE GENERAL DE STOCK CRITICO');
  FOR r IN (SELECT p.nombre_producto, c.nombre_categoria, p.stock_actual,
                   p.stock_minimo, pr.nombre_proveedor
              FROM productos p JOIN categorias c ON c.id_categoria=p.id_categoria
              JOIN proveedores pr ON pr.id_proveedor=p.id_proveedor
             WHERE p.stock_actual < p.stock_minimo
             ORDER BY c.nombre_categoria, p.stock_actual) LOOP
    DBMS_OUTPUT.PUT_LINE(r.nombre_categoria||' | '||r.nombre_producto||' | '||
      r.stock_actual||'/'||r.stock_minimo||' | '||r.nombre_proveedor);
  END LOOP;
END;
/

CREATE OR REPLACE PROCEDURE pr_reporte_stock_categoria(p_id_categoria IN NUMBER) IS
  v_encontrada NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_encontrada FROM categorias WHERE id_categoria=p_id_categoria;
  IF v_encontrada=0 THEN RAISE_APPLICATION_ERROR(-20020,'Categoría inexistente'); END IF;
  FOR r IN (SELECT nombre_producto,stock_actual,stock_minimo FROM productos
             WHERE id_categoria=p_id_categoria AND stock_actual<stock_minimo
             ORDER BY stock_actual) LOOP
    DBMS_OUTPUT.PUT_LINE(r.nombre_producto||' ('||r.stock_actual||'/'||r.stock_minimo||')');
  END LOOP;
END;
/

CREATE OR REPLACE FUNCTION fn_total_productos_criticos RETURN NUMBER IS v_total NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_total FROM productos WHERE stock_actual<stock_minimo;
  RETURN v_total;
END;
/

CREATE OR REPLACE FUNCTION fn_valor_inventario_categoria(p_id_categoria IN NUMBER)
RETURN NUMBER IS v_total NUMBER;
BEGIN
  SELECT NVL(SUM(precio*stock_actual),0) INTO v_total
    FROM productos WHERE id_categoria=p_id_categoria;
  RETURN v_total;
END;
/

-- Para integrar en PKG_INVENTARIO: declarar en la especificación pública:
--   FUNCTION total_criticos RETURN NUMBER;
--   PROCEDURE alerta_criticos;
-- Y agregar al cuerpo privado la rutina privada y las implementaciones siguientes.
-- La rutina privada no aparece en la especificación y solo se usa desde el package.
--   PROCEDURE imprimir_linea(p_nombre VARCHAR2,p_actual NUMBER,p_minimo NUMBER) IS
--   BEGIN DBMS_OUTPUT.PUT_LINE('  '||p_nombre||' ('||p_actual||'/'||p_minimo||')'); END;
--   FUNCTION total_criticos RETURN NUMBER IS v_total NUMBER;
--   BEGIN SELECT COUNT(*) INTO v_total FROM productos WHERE stock_actual<stock_minimo;
--         RETURN v_total; END;
--   PROCEDURE alerta_criticos IS
--   BEGIN DBMS_OUTPUT.PUT_LINE('Productos bajo mínimo: '||total_criticos); END;
-- Demostración de rutina pública consumida desde SQL:
-- SELECT pkg_inventario.valor_inventario_categoria(1) FROM dual;
-- SELECT pkg_inventario.producto_bajo_stock(2) FROM dual;

-- Trigger de sentencia: registra una auditoría por cada sentencia que cambie stock.
-- Se usa una tabla propia para no interferir con log_stock_critico (que es por fila).
CREATE TABLE log_sentencia_stock (
  id_log NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fecha_evento DATE DEFAULT SYSDATE NOT NULL,
  usuario_bd VARCHAR2(128) NOT NULL,
  accion VARCHAR2(30) NOT NULL
);
CREATE OR REPLACE TRIGGER trg_audita_sentencia_stock
AFTER UPDATE OF stock_actual ON productos
BEGIN
  INSERT INTO log_sentencia_stock(usuario_bd,accion)
  VALUES(SYS_CONTEXT('USERENV','SESSION_USER'),'UPDATE STOCK');
END;
/

-- Demostraciones de uso desde PL/SQL y SQL.
BEGIN pr_reporte_stock_critico; END;
/
BEGIN pr_reporte_stock_categoria(2); END;
/
SELECT fn_total_productos_criticos() AS productos_criticos FROM dual;
SELECT fn_valor_inventario_categoria(1) AS valor_categoria FROM dual;
SELECT COUNT(*) AS auditorias_de_sentencia FROM log_sentencia_stock;


-- Package complementario ejecutable con API pública y rutina privada real.
CREATE OR REPLACE PACKAGE pkg_inventario_rubrica AS
  FUNCTION total_criticos RETURN NUMBER;
  FUNCTION valor_categoria(p_id_categoria NUMBER) RETURN NUMBER;
  PROCEDURE reporte_criticos;
  PROCEDURE reporte_categoria(p_id_categoria NUMBER);
END pkg_inventario_rubrica;
/
CREATE OR REPLACE PACKAGE BODY pkg_inventario_rubrica AS
  -- Privada: solo puede invocarse desde este cuerpo.
  PROCEDURE imprimir_linea(p_nombre VARCHAR2,p_actual NUMBER,p_minimo NUMBER) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('  '||p_nombre||' ('||p_actual||'/'||p_minimo||')');
  END;

  FUNCTION total_criticos RETURN NUMBER IS v_total NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_total FROM productos WHERE stock_actual<stock_minimo;
    RETURN v_total;
  END;

  FUNCTION valor_categoria(p_id_categoria NUMBER) RETURN NUMBER IS v_valor NUMBER;
  BEGIN
    SELECT NVL(SUM(precio*stock_actual),0) INTO v_valor
      FROM productos WHERE id_categoria=p_id_categoria;
    RETURN v_valor;
  END;

  PROCEDURE reporte_criticos IS
  BEGIN
    FOR r IN (SELECT nombre_producto,stock_actual,stock_minimo FROM productos
               WHERE stock_actual<stock_minimo ORDER BY stock_actual) LOOP
      imprimir_linea(r.nombre_producto,r.stock_actual,r.stock_minimo);
    END LOOP;
  END;

  PROCEDURE reporte_categoria(p_id_categoria NUMBER) IS
    v_existe NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_existe FROM categorias WHERE id_categoria=p_id_categoria;
    IF v_existe=0 THEN RAISE_APPLICATION_ERROR(-20020,'Categoría inexistente'); END IF;
    FOR r IN (SELECT nombre_producto,stock_actual,stock_minimo FROM productos
               WHERE id_categoria=p_id_categoria AND stock_actual<stock_minimo
               ORDER BY stock_actual) LOOP
      imprimir_linea(r.nombre_producto,r.stock_actual,r.stock_minimo);
    END LOOP;
  END;
END pkg_inventario_rubrica;
/

-- Llamadas de demostración del package (públicas, desde SQL y PL/SQL).
SELECT pkg_inventario_rubrica.total_criticos() AS criticos FROM dual;
SELECT pkg_inventario_rubrica.valor_categoria(1) AS valor FROM dual;
BEGIN pkg_inventario_rubrica.reporte_criticos; END;
/
BEGIN pkg_inventario_rubrica.reporte_categoria(2); END;
/
PROMPT === VALIDACION INICIAL ===
SELECT COUNT(*) AS total_productos FROM productos;
SELECT COUNT(*) AS total_clientes FROM clientes;
SELECT fn_total_productos_criticos() AS productos_criticos FROM dual;
SELECT COUNT(*) AS total_pedidos FROM pedidos;
SELECT COUNT(*) AS total_detalles FROM detalle_pedido;

PROMPT === INSTALACION TERMINADA ===
