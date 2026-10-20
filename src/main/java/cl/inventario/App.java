package cl.inventario;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import java.io.*;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.sql.*;
import java.util.*;
import java.util.concurrent.Executors;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class App {
  record Product(int id, String name, String category, String supplier, int stock, int minimum, long price) {
    boolean critical() { return stock < minimum; }
  }
  interface Inventory { List<Product> products() throws Exception; int order(int customerId,int productId,int quantity) throws Exception; }

  static final class OracleInventory implements Inventory {
    private Connection connect() throws SQLException {return ConexionBD.conectar();}
    public List<Product> products() throws SQLException {
      String sql="SELECT p.id_producto,p.nombre_producto,c.nombre_categoria,pr.nombre_proveedor,p.stock_actual,p.stock_minimo,p.precio FROM productos p JOIN categorias c ON c.id_categoria=p.id_categoria JOIN proveedores pr ON pr.id_proveedor=p.id_proveedor ORDER BY c.nombre_categoria,p.nombre_producto";
      List<Product> list=new ArrayList<>();
      try(Connection c=connect();PreparedStatement q=c.prepareStatement(sql);ResultSet r=q.executeQuery()){
        while(r.next()) list.add(new Product(r.getInt(1),r.getString(2),r.getString(3),r.getString(4),r.getInt(5),r.getInt(6),r.getLong(7)));
      } return list;
    }
    public int order(int customerId,int productId,int quantity) throws SQLException {
      try(Connection c=connect();CallableStatement q=c.prepareCall("{call pkg_inventario.registrar_pedido(?,?,?,?)}")){
        q.setInt(1,customerId);q.setInt(2,productId);q.setInt(3,quantity);q.registerOutParameter(4,Types.NUMERIC);q.execute();return q.getInt(4);
      }
    }
  }

  private static final Inventory inventory=new OracleInventory();
  private static final String mode="oracle";
  public static void main(String[] args) throws Exception {
    int port=Integer.parseInt(Optional.ofNullable(System.getenv("PORT")).orElse("8080"));
    HttpServer server=HttpServer.create(new InetSocketAddress(port),0);
    inventory.products(); // Verifica la conexión antes de abrir la página.
    server.createContext("/api/status",x->handle(x,App::status));
    server.createContext("/api/products",x->handle(x,App::products));
    server.createContext("/api/orders",x->handle(x,App::order));
    server.createContext("/",App::staticFile);
    server.setExecutor(Executors.newFixedThreadPool(8));server.start();
    System.out.println("Inventario listo en http://localhost:"+port);
    System.out.println("Oracle conectado correctamente.");
  }
  interface Handler { void run(HttpExchange x) throws Exception; }
  static void handle(HttpExchange x,Handler h){try{h.run(x);}catch(IllegalArgumentException e){send(x,400,"{\"error\":"+json(e.getMessage())+"}");}catch(SQLException e){e.printStackTrace();int status=e.getErrorCode()>=20000?400:503;send(x,status,"{\"error\":"+json(e.getMessage()==null?"Error de Oracle":e.getMessage())+"}");}catch(Exception e){e.printStackTrace();send(x,500,"{\"error\":"+json("No se pudo completar la operación")+"}");}}
  static void products(HttpExchange x)throws Exception{
    if(!x.getRequestMethod().equals("GET")){send(x,405,"{\"error\":\"Método no permitido\"}");return;}
    List<Product> ps=inventory.products();StringJoiner arr=new StringJoiner(",","[","]");
    for(Product p:ps) arr.add("{\"id\":"+p.id()+",\"name\":"+json(p.name())+",\"category\":"+json(p.category())+",\"supplier\":"+json(p.supplier())+",\"stock\":"+p.stock()+",\"minimum\":"+p.minimum()+",\"price\":"+p.price()+",\"critical\":"+p.critical()+"}");
    send(x,200,arr.toString());
  }
  static void status(HttpExchange x)throws IOException{
    if(!x.getRequestMethod().equals("GET")){send(x,405,"{\"error\":\"Método no permitido\"}");return;}
    send(x,200,"{\"mode\":"+json(mode)+"}");
  }
  static void order(HttpExchange x)throws Exception{
    if(!x.getRequestMethod().equals("POST")){send(x,405,"{\"error\":\"Método no permitido\"}");return;}
    String body=new String(x.getRequestBody().readAllBytes(),StandardCharsets.UTF_8);
    int customer=number(body,"customerId"),product=number(body,"productId"),qty=number(body,"quantity");
    int id=inventory.order(customer,product,qty);send(x,201,"{\"orderId\":"+id+",\"message\":\"Pedido registrado\"}");
  }
  static int number(String body,String key){Matcher m=Pattern.compile("\\\""+Pattern.quote(key)+"\\\"\\s*:\\s*(\\d+)").matcher(body);if(!m.find())throw new IllegalArgumentException("Falta el campo "+key);return Integer.parseInt(m.group(1));}
  static void staticFile(HttpExchange x)throws IOException{
    String path=x.getRequestURI().getPath();if(path.equals("/"))path="/index.html";
    if(path.contains("..")||!path.matches("/[a-zA-Z0-9._-]+")){send(x,404,"No encontrado");return;}
    try(InputStream in=App.class.getResourceAsStream("/static"+path)){
      if(in==null){send(x,404,"No encontrado");return;}byte[] bytes=in.readAllBytes();String type=path.endsWith(".css")?"text/css; charset=utf-8":path.endsWith(".js")?"application/javascript; charset=utf-8":"text/html; charset=utf-8";x.getResponseHeaders().set("Content-Type",type);x.sendResponseHeaders(200,bytes.length);try(OutputStream out=x.getResponseBody()){out.write(bytes);}
    }
  }
  static String json(String s){return "\""+s.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r")+"\"";}
  static void send(HttpExchange x,int status,String body){try{byte[] b=body.getBytes(StandardCharsets.UTF_8);x.getResponseHeaders().set("Content-Type","application/json; charset=utf-8");x.getResponseHeaders().set("Cache-Control","no-store");x.sendResponseHeaders(status,b.length);x.getResponseBody().write(b);x.close();}catch(IOException ignored){}}
}
