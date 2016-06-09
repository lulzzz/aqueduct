import "package:test/test.dart";
import "dart:core";
import "dart:io";
import 'package:http/http.dart' as http;
import 'package:aqueduct/aqueduct.dart';
import 'dart:async';

void main() {
  group("No CORS Policy", () {
    var app = new Application<CORSPipeline>();
    app.configuration.port = 8000;

    setUpAll(() async {
      await app.start(runOnMainIsolate: true);
    });
    tearDownAll(() async {
      await app?.stop();
    });

    test("Unknown route still returns 404", () async {
      var resp = await http.get("http://localhost:8000/foobar");
      expect(resp.statusCode, 404);
      expect(resp.headers["access-control-allow-origin"], isNull);
    });

    test("Normal request when no CORS policy", () async {
      var resp = await http.get("http://localhost:8000/nopolicy");
      expect(resp.statusCode, 200);
      expect(resp.headers["access-control-allow-origin"], isNull);
    });

    test("Origin request when no CORS policy", () async {
      var resp = await http.get("http://localhost:8000/nopolicy", headers: {
        "Origin" : "http://somewhereelse.com"
      });
      expect(resp.statusCode, 200);
      expect(resp.headers["access-control-allow-origin"], isNull);
    });

    test("Preflight request when no CORS policy", () async {
      var client = new HttpClient();
      var req = await client.openUrl("OPTIONS", new Uri(scheme: "http", host: "localhost", port: 8000, path: "nopolicy"));
      var resp = await req.close();
      expect(resp.statusCode, 404);
    });

    test("Normal request when no CORS policy + Auth (Success)", () async {
      var resp = await http.get("http://localhost:8000/nopolicyauth", headers: {"Authorization" : "Bearer auth"});
      expect(resp.statusCode, 200);
      expect(resp.headers["access-control-allow-origin"], isNull);
    });

    test("Origin request when no CORS policy + Auth (Success)", () async {
      var resp = await http.get("http://localhost:8000/nopolicyauth", headers: {
        "Origin" : "http://somewhereelse.com",
        "Authorization" : "Bearer auth"
      });
      expect(resp.statusCode, 200);
      expect(resp.headers["access-control-allow-origin"], isNull);
    });

    test("Preflight request when no CORS policy + Auth (Success)", () async {
      var client = new HttpClient();
      var req = await client.openUrl("OPTIONS", new Uri(scheme: "http", host: "localhost", port: 8000, path: "nopolicyauth"));
      var resp = await req.close();

      // Should return 401, the preflight is unsigned and therefore doesn't make it past the authenticator, since it
      // won't allow OPTIONS thru because it isn't expecting a preflight request.
      expect(resp.statusCode, 401);
    });

    test("Normal request when no CORS policy + Auth (Failure)", () async {
      var resp = await http.get("http://localhost:8000/nopolicyauth", headers: {"Authorization" : "Bearer noauth"});
      expect(resp.statusCode, 401);
      expect(resp.headers["access-control-allow-origin"], isNull);
    });

    test("Origin request when no CORS policy + Auth (Failure)", () async {
      var resp = await http.get("http://localhost:8000/nopolicyauth", headers: {
        "Origin" : "http://somewhereelse.com",
        "Authorization" : "Bearer noauth"
      });
      expect(resp.statusCode, 401);
      expect(resp.headers["access-control-allow-origin"], isNull);
    });
  });

  group("Default CORS Policy", () {
    var app = new Application<CORSPipeline>();
    app.configuration.port = 8000;

    setUpAll(() async {
      await app.start(runOnMainIsolate: true);
    });
    tearDownAll(() async {
      await app?.stop();
    });

    test("Unknown route still returns 404", () async {
      var resp = await http.get("http://localhost:8000/foobar", headers: {
        "Origin" : "http://somewhereelse.com"
      });
      print("${resp.headers}");
      expect(resp.statusCode, 404);
      expect(resp.headers["access-control-allow-origin"], "http://somewhereelse.com");
    });

    test("Normal request", () async {
      var resp = await http.get("http://localhost:8000/defaultpolicy");
      expect(resp.statusCode, 200);
      expect(resp.headers["access-control-allow-origin"], isNull);
    });

    test("Origin request, valid", () async {
      var resp = await http.get("http://localhost:8000/defaultpolicy", headers: {
        "Origin" : "http://somewhereelse.com"
      });
      expect(resp.statusCode, 200);
      expect(resp.headers["access-control-allow-origin"], "http://somewhereelse.com");
    });

    test("Preflight request, valid", () async {
      var client = new HttpClient();
      var req = await client.openUrl("OPTIONS", new Uri(scheme: "http", host: "localhost", port: 8000, path: "defaultpolicy"));
      req.headers.add("Origin", "http://localhost");
      req.headers.add("Access-Control-Request-Method", "POST");
      req.headers.add("Access-Control-Request-Headers", "authorization,x-requested-with");
      req.headers.add("Accept", "*/*");
      var resp = await req.close();
      expect(resp.statusCode, 200);
      expect(resp.contentLength, 0);
      expect(resp.headers.value("access-control-allow-origin"), "http://localhost");
      expect(resp.headers.value("access-control-allow-methods"), "POST, PUT, DELETE, GET");
      expect(resp.headers.value("access-control-allow-headers"), "authorization, x-requested-with, content-type, accept");
    });

  /////////
    test("Normal request + Auth (Success)", () async {
      var resp = await http.get("http://localhost:8000/defaultpolicyauth", headers: {"Authorization" : "Bearer auth"});
      expect(resp.statusCode, 200);
      expect(resp.headers["access-control-allow-origin"], isNull);
    });

    test("Origin request + Auth (Success)", () async {
      var resp = await http.get("http://localhost:8000/defaultpolicyauth", headers: {
        "Origin" : "http://somewhereelse.com",
        "Authorization" : "Bearer auth"
      });
      expect(resp.statusCode, 200);
      expect(resp.headers["access-control-allow-origin"], "http://somewhereelse.com");
    });

    test("Preflight request + Auth (Success)", () async {
      var client = new HttpClient();
      var req = await client.openUrl("OPTIONS", new Uri(scheme: "http", host: "localhost", port: 8000, path: "defaultpolicyauth"));
      req.headers.add("Origin", "http://localhost");
      req.headers.add("Access-Control-Request-Method", "POST");
      req.headers.add("Access-Control-Request-Headers", "authorization,x-requested-with");
      req.headers.add("Accept", "*/*");
      var resp = await req.close();
      expect(resp.statusCode, 200);
      expect(resp.contentLength, 0);
      expect(resp.headers.value("access-control-allow-origin"), "http://localhost");
      expect(resp.headers.value("access-control-allow-methods"), "POST, PUT, DELETE, GET");
      expect(resp.headers.value("access-control-allow-headers"), "authorization, x-requested-with, content-type, accept");
    });

    test("Normal request + Auth (Failure)", () async {
      var resp = await http.get("http://localhost:8000/defaultpolicyauth", headers: {"Authorization" : "Bearer noauth"});
      expect(resp.statusCode, 401);
      expect(resp.headers["access-control-allow-origin"], isNull);
    });

    test("Origin request + Auth (Failure)", () async {
      var resp = await http.get("http://localhost:8000/defaultpolicyauth", headers: {
        "Origin" : "http://somewhereelse.com",
        "Authorization" : "Bearer noauth"
      });
      expect(resp.statusCode, 401);
      expect(resp.headers["access-control-allow-origin"], "http://somewhereelse.com");
    });
  });
}

class CORSPipeline extends ApplicationPipeline implements AuthenticationServerDelegate<AuthImpl, TokenImpl> {
  CORSPipeline(Map opts) : super(opts) {
    authServer = new AuthenticationServer<AuthImpl, TokenImpl>(this);
  }

  AuthenticationServer<AuthImpl, TokenImpl> authServer;

  void addRoutes() {
    router.route("/nopolicy").then(new RequestHandlerGenerator<NoPolicyController>());
    router.route("/defaultpolicy").then(new RequestHandlerGenerator<DefaultPolicyController>());
    router.route("/nopolicyauth")
        .then(authServer.authenticator())
        .then(new RequestHandlerGenerator<NoPolicyController>());
    router.route("/defaultpolicyauth")
        .then(authServer.authenticator())
        .then(new RequestHandlerGenerator<DefaultPolicyController>());
  }

  Future<TokenImpl> tokenForAccessToken(AuthenticationServer server, String accessToken) async {
    if (accessToken == "noauth") {
      return null;
    }

    return new TokenImpl()
        ..accessToken = "access"
        ..refreshToken = "access"
        ..clientID = "access"
        ..resourceOwnerIdentifier = "access"
        ..issueDate = new DateTime.now().toUtc()
        ..expirationDate = new DateTime(10000)
        ..type = "password";
  }
  Future<TokenImpl> tokenForRefreshToken(AuthenticationServer server, String refreshToken) async {
    if (refreshToken == "noauth") {
      return null;
    }

    return new TokenImpl()
      ..accessToken = "access"
      ..refreshToken = "access"
      ..clientID = "access"
      ..resourceOwnerIdentifier = "access"
      ..type = "password";
  }
  Future<AuthImpl> authenticatableForUsername(AuthenticationServer server, String username) async {
    return new AuthImpl()
          ..username = "access"
          ..id = "access";
  }
  Future<AuthImpl> authenticatableForID(AuthenticationServer server, dynamic id) async {
    return new AuthImpl()
      ..username = "access"
      ..id = "access";
  }

  Future<Client> clientForID(AuthenticationServer server, String id) async {
    if (id == "noauth") {
      return null;
    }

    var salt = AuthenticationServer.generateRandomSalt();
    var password = AuthenticationServer.generatePasswordHash("access", salt);

    return new Client("access", password, salt);
  }

  Future deleteTokenForAccessToken(AuthenticationServer server, String accessToken) async {}
  Future storeToken(AuthenticationServer server, TokenImpl t) async {}
  Future pruneTokensForResourceOwnerID(AuthenticationServer server, dynamic id) async {}
}
class AuthImpl implements Authenticatable {
  String username;
  String hashedPassword;
  String salt;
  dynamic id;
}

class TokenImpl implements Tokenizable {
  String accessToken;
  String refreshToken;
  DateTime issueDate;
  DateTime expirationDate;
  String type;
  dynamic resourceOwnerIdentifier;
  String clientID;
}

class NoPolicyController extends HttpController {
  NoPolicyController() {
    policy = null;
  }

  @httpGet
  Future<Response> getAll() async {
    return new Response.ok("getAll");
  }
}

class DefaultPolicyController extends HttpController {
  @httpGet
  Future<Response> getAll() async {
    return new Response.ok("getAll");
  }
}
