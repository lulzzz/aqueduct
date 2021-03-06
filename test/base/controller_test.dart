import "package:test/test.dart";
import "dart:core";
import "dart:io";
import 'package:http/http.dart' as http;
import 'package:aqueduct/aqueduct.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:mirrors';
import '../helpers.dart';

void main() {
  HttpServer server;

  setUpAll(() {
    new ManagedContext(
        new ManagedDataModel([TestModel]), new DefaultPersistentStore());
  });

  tearDown(() async {
    await server?.close(force: true);
    server = null;
  });

  test("Get w/ no params", () async {
    server = await enableController("/a", TController);

    var res = await http.get("http://localhost:4040/a");

    expect(res.statusCode, 200);
    expect(JSON.decode(res.body), "getAll");
  });

  test("Get w/ 1 param", () async {
    server = await enableController("/a/:id", TController);
    var res = await http.get("http://localhost:4040/a/123");

    expect(res.statusCode, 200);
    expect(JSON.decode(res.body), "123");
  });

  test("Get w/ 2 param", () async {
    server = await enableController("/a/:id/:flag", TController);

    var res = await http.get("http://localhost:4040/a/123/active");

    expect(res.statusCode, 200);
    expect(JSON.decode(res.body), "123active");
  });

  group("Unsupported method", () {
    test("Returns status code 405 with Allow response header", () async {
      server = await enableController("/a", TController);

      var res = await http.delete("http://localhost:4040/a");
      expect(res.statusCode, 405);
      expect(res.headers["allow"], "GET, POST");
    });

    test("Only returns allow for specific resource within controller",
        () async {
      server = await enableController("/a/[:id/[:flag]]", TController);

      var res = await http.delete("http://localhost:4040/a");
      expect(res.statusCode, 405);
      expect(res.headers["allow"], "GET, POST");

      res = await http.delete("http://localhost:4040/a/1");
      expect(res.statusCode, 405);
      expect(res.headers["allow"], "GET, PUT");

      res = await http.delete("http://localhost:4040/a/1/foo");
      expect(res.statusCode, 405);
      expect(res.headers["allow"], "GET");
    });
  });

  test("Crashing controller delivers 500", () async {
    server = await enableController("/a/:id", TController);

    var res = await http.put("http://localhost:4040/a/a");

    expect(res.statusCode, 500);
  });

  test("Only respond to appropriate content types", () async {
    server = await enableController("/a", TController);

    var body = JSON.encode({"a": "b"});
    var res = await http.post("http://localhost:4040/a",
        headers: {"Content-Type": "application/json"}, body: body);
    expect(res.statusCode, 200);
    expect(JSON.decode(res.body), equals({"a": "b"}));
  });

  test("Return error when wrong content type", () async {
    server = await enableController("/a", TController);

    var body = JSON.encode({"a": "b"});
    var res = await http.post("http://localhost:4040/a",
        headers: {"Content-Type": "application/somenonsense"}, body: body);
    expect(res.statusCode, 415);
  });

  test("Query parameters get delivered if exposed as optional params",
      () async {
    server = await enableController("/a", QController);

    var res = await http.get("http://localhost:4040/a?opt=x");
    expect(res.body, "\"OK\"");

    res = await http.get("http://localhost:4040/a");
    expect(res.body, "\"NOT\"");

    res = await http.get("http://localhost:4040/a?option=x");
    expect(res.body, "\"NOT\"");

    res = await http.get("http://localhost:4040/a?opt=x&q=1");
    expect(res.body, "\"OK\"");

    await server.close(force: true);

    server = await enableController("/:id", QController);

    res = await http.get("http://localhost:4040/123?opt=x");
    expect(res.body, "\"OK\"");

    res = await http.get("http://localhost:4040/123");
    expect(res.body, "\"NOT\"");

    res = await http.get("http://localhost:4040/123?option=x");
    expect(res.body, "\"NOT\"");

    res = await http.get("http://localhost:4040/123?opt=x&q=1");
    expect(res.body, "\"OK\"");
  });

  test("Path parameters are parsed into appropriate type", () async {
    server = await enableController("/:id", IntController);

    var res = await http.get("http://localhost:4040/123");
    expect(res.body, "\"246\"");

    res = await http.get("http://localhost:4040/word");
    expect(res.statusCode, 400);

    await server.close(force: true);

    server = await enableController("/:time", DateTimeController);
    res = await http.get("http://localhost:4040/2001-01-01T00:00:00.000000Z");
    expect(res.statusCode, 200);
    expect(res.body, "\"2001-01-01 00:00:05.000Z\"");

    res = await http.get("http://localhost:4040/foobar");
    expect(res.statusCode, 400);
  });

  test("Query parameters are parsed into appropriate types", () async {
    server = await enableController("/a", IntController);
    var res = await http.get("http://localhost:4040/a?opt=12");
    expect(res.body, "\"12\"");

    res = await http.get("http://localhost:4040/a?opt=word");
    expect(res.statusCode, 400);

    res = await http.get("http://localhost:4040/a?foo=2");
    expect(res.statusCode, 200);
    expect(res.body, "\"null\"");

    await server.close(force: true);

    server = await enableController("/a", DateTimeController);
    res = await http
        .get("http://localhost:4040/a?opt=2001-01-01T00:00:00.000000Z");
    expect(res.statusCode, 200);
    expect(res.body, "\"2001-01-01 00:00:00.000Z\"");

    res = await http.get("http://localhost:4040/a?opt=word");
    expect(res.statusCode, 400);

    res = await http
        .get("http://localhost:4040/a?foo=2001-01-01T00:00:00.000000Z");
    expect(res.statusCode, 200);
  });

  test("Query parameters can be obtained from x-www-form-urlencoded", () async {
    server = await enableController("/a", IntController);
    var res = await http.post("http://localhost:4040/a",
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: "opt=7");
    expect(res.body, '"7"');
  });

  test("Model and lists are encoded in response", () async {
    server = await enableController("/a/:thing", ModelEncodeController);
    var res = await http.get("http://localhost:4040/a/list");
    expect(JSON.decode(res.body), [
      {"id": 1},
      {"id": 2}
    ]);

    res = await http.get("http://localhost:4040/a/model");
    expect(JSON.decode(res.body), {"id": 1, "name": "Bob"});

    res = await http.get("http://localhost:4040/a/modellist");
    expect(JSON.decode(res.body), [
      {"id": 1, "name": "Bob"},
      {"id": 2, "name": "Fred"}
    ]);

    res = await http.get("http://localhost:4040/a/null");
    expect(res.body, isEmpty);
    expect(res.statusCode, 200);
  });

  test("Controllers return no body if null", () async {
    server = await enableController("/a/:thing", ModelEncodeController);

    var res = await http.get("http://localhost:4040/a/null");
    expect(res.body, isEmpty);
    expect(res.statusCode, 200);
  });

  test("Sending bad JSON returns 400", () async {
    server = await enableController("/a", TController);
    var res = await http.post("http://localhost:4040/a",
        body: "{`foobar' : 2}", headers: {"Content-Type": "application/json"});
    expect(res.statusCode, 400);

    res = await http.get("http://localhost:4040/a");
    expect(res.statusCode, 200);
  });

  test("Prefilter requests", () async {
    server = await enableController("/a", FilteringController);

    var resp = await http.get("http://localhost:4040/a");
    expect(resp.statusCode, 200);

    resp =
        await http.get("http://localhost:4040/a", headers: {"Ignore": "true"});
    expect(resp.statusCode, 400);
    expect(resp.body, '"ignored"');
  });

  test("Request with multiple query parameters of same key", () async {
    server = await enableController("/a", MultiQueryParamController);
    var resp = await http.get("http://localhost:4040/a?params=1&params=2");
    expect(resp.statusCode, 200);
    expect(resp.body, '"1,2"');
  });

  test("Request with query parameter key is bool", () async {
    server = await enableController("/a", BooleanQueryParamController);
    var resp = await http.get("http://localhost:4040/a?param");
    expect(resp.statusCode, 200);
    expect(resp.body, '"true"');

    resp = await http.get("http://localhost:4040/a");
    expect(resp.statusCode, 200);
    expect(resp.body, '"false"');
  });

  test("Content-Type defaults to application/json", () async {
    server = await enableController("/a", TController);
    var resp = await http.get("http://localhost:4040/a");
    expect(resp.statusCode, 200);
    expect(ContentType.parse(resp.headers["content-type"]).primaryType,
        "application");
    expect(ContentType.parse(resp.headers["content-type"]).subType, "json");
  });

  test("Content-Type can be set adjusting responseContentType", () async {
    server = await enableController("/a", ContentTypeController);
    var resp =
        await http.get("http://localhost:4040/a?opt=responseContentType");
    expect(resp.statusCode, 200);
    expect(resp.headers["content-type"], "text/plain");
    expect(resp.body, "body");
  });

  test("Content-Type set directly on Response overrides responseContentType",
      () async {
    server = await enableController("/a", ContentTypeController);
    var resp = await http.get("http://localhost:4040/a?opt=direct");
    expect(resp.statusCode, 200);
    expect(resp.headers["content-type"], "text/plain");
    expect(resp.body, "body");
  });

  test("didDecodeRequestBody invoked when there is a request body", () async {
    server = await enableController("/a", DecodeCallbackController);
    var resp = await http.get("http://localhost:4040/a");
    expect(JSON.decode(resp.body), {"didDecode": false});

    resp = await http.post("http://localhost:4040/a", headers: {
      HttpHeaders.CONTENT_TYPE: ContentType.JSON.toString()
    }, body: JSON.encode({
      "k":"v"
    }));
    expect(JSON.decode(resp.body), {"didDecode": true});
  });

  group("Annotated HTTP parameters", () {
    test("are supplied correctly", () async {
      server = await enableController("/a", HTTPParameterController);
      var resp = await http.get(
          "http://localhost:4040/a?number=3&Shaqs=1&Table=IKEA&table_legs=8",
          headers: {
            "x-request-id": "3423423adfea90",
            "location": "Nowhere",
            "Cookie": "Chips Ahoy",
            "Milk": "Publix",
          });

      expect(resp.statusCode, 200);
      expect(JSON.decode(resp.body), {
        "x-request-id": "3423423adfea90",
        "location": "Nowhere",
        "cookie": "Chips Ahoy",
        "milk": "Publix",
        "number": 3,
        "Shaqs": 1,
        "Table": "IKEA",
        "table_legs": 8
      });
    });

    test("optional parameters aren't required", () async {
      server = await enableController("/a", HTTPParameterController);
      var resp = await http
          .get("http://localhost:4040/a?Shaqs=1&Table=IKEA", headers: {
        "x-request-id": "3423423adfea90",
        "Cookie": "Chips Ahoy",
      });

      expect(resp.statusCode, 200);
      expect(JSON.decode(resp.body), {
        "x-request-id": "3423423adfea90",
        "location": null,
        "cookie": "Chips Ahoy",
        "milk": null,
        "number": null,
        "Shaqs": 1,
        "Table": "IKEA",
        "table_legs": null
      });
    });

    test("missing required controller header param fails", () async {
      server = await enableController("/a", HTTPParameterController);
      var resp = await http
          .get("http://localhost:4040/a?Shaqs=1&Table=IKEA", headers: {
        "Cookie": "Chips Ahoy",
      });

      expect(resp.statusCode, 400);
      expect(JSON.decode(resp.body),
          {"error": "Missing Header 'X-Request-id'"});
    });

    test("missing required controller query param fails", () async {
      server = await enableController("/a", HTTPParameterController);
      var resp = await http.get("http://localhost:4040/a?Table=IKEA", headers: {
        "x-request-id": "3423423adfea90",
        "Cookie": "Chips Ahoy",
      });

      expect(resp.statusCode, 400);
      expect(JSON.decode(resp.body),
          {"error": "Missing Query Parameter 'Shaqs'"});
    });

    test("missing required method header param fails", () async {
      server = await enableController("/a", HTTPParameterController);
      var resp = await http
          .get("http://localhost:4040/a?Shaqs=1&Table=IKEA", headers: {
        "x-request-id": "3423423adfea90",
      });

      expect(resp.statusCode, 400);
      expect(JSON.decode(resp.body), {"error": "Missing Header 'Cookie'"});
    });

    test("missing require method query param fails", () async {
      server = await enableController("/a", HTTPParameterController);
      var resp = await http.get("http://localhost:4040/a?Shaqs=1", headers: {
        "x-request-id": "3423423adfea90",
        "Cookie": "Chips Ahoy",
      });

      expect(resp.statusCode, 400);
      expect(JSON.decode(resp.body),
          {"error": "Missing Query Parameter 'Table'"});
    });

    test("reports all missing required parameters", () async {
      server = await enableController("/a", HTTPParameterController);
      var resp = await http.get("http://localhost:4040/a");

      expect(resp.statusCode, 400);
      var errorMessage = JSON.decode(resp.body)["error"];
      expect(errorMessage, contains("'X-Request-id'"));
      expect(errorMessage, contains("'Shaqs'"));
      expect(errorMessage, contains("'Cookie'"));
      expect(errorMessage, contains("'Table'"));
    });

    test("Headers are case-INsensitive", () async {
      server = await enableController("/a", HTTPParameterController);
      var resp = await http.get(
          "http://localhost:4040/a?number=3&Shaqs=1&Table=IKEA&table_legs=8",
          headers: {
            "X-Request-ID": "3423423adfea90",
            "location": "Nowhere",
            "Cookie": "Chips Ahoy",
            "Milk": "Publix",
          });

      expect(resp.statusCode, 200);
      expect(JSON.decode(resp.body), {
        "x-request-id": "3423423adfea90",
        "location": "Nowhere",
        "cookie": "Chips Ahoy",
        "milk": "Publix",
        "number": 3,
        "Shaqs": 1,
        "Table": "IKEA",
        "table_legs": 8
      });
    });

    test("Query parameters are case-SENSITIVE", () async {
      server = await enableController("/a", HTTPParameterController);
      var resp = await http
          .get("http://localhost:4040/a?SHAQS=1&table=IKEA", headers: {
        "X-Request-ID": "3423423adfea90",
        "Cookie": "Chips Ahoy",
      });

      expect(resp.statusCode, 400);

      expect(JSON.decode(resp.body)["error"], contains("Missing Query Parameter"));
      expect(JSON.decode(resp.body)["error"], contains("Table"));
      expect(JSON.decode(resp.body)["error"], contains("Shaqs"));
    });

    test("May only be one query parameter if arg type is not List<T>",
        () async {
      server = await enableController("/a", DuplicateParamController);
      var resp = await http
          .get("http://localhost:4040/a?list=a&list=b&single=x&single=y");

      expect(resp.statusCode, 400);

      expect(JSON.decode(resp.body)["error"],
          "Duplicate parameter for non-List parameter type");
    });

    test("Can be more than one query parameters for arg type that is List<T>",
        () async {
      server = await enableController("/a", DuplicateParamController);
      var resp =
          await http.get("http://localhost:4040/a?list=a&list=b&single=x");

      expect(resp.statusCode, 200);

      expect(JSON.decode(resp.body), {
        "list": ["a", "b"],
        "single": "x"
      });
    });

    test("Can be exactly one query parameter for arg type that is List<T>",
        () async {
      server = await enableController("/a", DuplicateParamController);
      var resp = await http.get("http://localhost:4040/a?list=a&single=x");

      expect(resp.statusCode, 200);

      expect(JSON.decode(resp.body), {
        "list": ["a"],
        "single": "x"
      });
    });

    test("Missing required List<T> query parameter still returns 400",
        () async {
      server = await enableController("/a", DuplicateParamController);
      var resp = await http.get("http://localhost:4040/a?single=x");

      expect(resp.statusCode, 400);

      expect(JSON.decode(resp.body)["error"], contains("list"));
    });
  });
}

class FilteringController extends HTTPController {
  @httpGet
  Future<Response> getAll() async {
    return new Response.ok(null);
  }

  @override
  Future<RequestOrResponse> willProcessRequest(Request req) async {
    if (req.innerRequest.headers.value("ignore") != null) {
      return new Response.badRequest(body: "ignored");
    }
    return super.willProcessRequest(req);
  }
}

class TController extends HTTPController {
  @httpGet
  Future<Response> getAll() async {
    return new Response.ok("getAll");
  }

  @httpGet
  Future<Response> getOne(@HTTPPath("id") String id) async {
    return new Response.ok("$id");
  }

  @httpGet
  Future<Response> getBoth(
      @HTTPPath("id") String id, @HTTPPath("flag") String flag) async {
    return new Response.ok("$id$flag");
  }

  @httpPut
  Future<Response> putOne(@HTTPPath("id") String id) async {
    throw new Exception("Exception!");
  }

  @httpPost
  Future<Response> post() async {
    var body = this.request.body.asMap();

    return new Response.ok(body);
  }
}

class QController extends HTTPController {
  @httpGet
  Future<Response> getAll({@HTTPQuery("opt") String opt: null}) async {
    if (opt == null) {
      return new Response.ok("NOT");
    }

    return new Response.ok("OK");
  }

  @httpGet
  Future<Response> getOne(@HTTPPath("id") String id,
      {@HTTPQuery("opt") String opt: null}) async {
    if (opt == null) {
      return new Response.ok("NOT");
    }

    return new Response.ok("OK");
  }
}

class IntController extends HTTPController {
  @httpGet
  Future<Response> getOne(@HTTPPath("id") int id) async {
    return new Response.ok("${id * 2}");
  }

  @httpGet
  Future<Response> getAll({@HTTPQuery("opt") int opt: null}) async {
    return new Response.ok("$opt");
  }

  @httpPost
  Future<Response> create({@HTTPQuery("opt") int opt: null}) async {
    return new Response.ok("$opt");
  }
}

class DateTimeController extends HTTPController {
  @httpGet
  Future<Response> getOne(@HTTPPath("time") DateTime time) async {
    return new Response.ok("${time.add(new Duration(seconds: 5))}");
  }

  @httpGet
  Future<Response> getAll({@HTTPQuery("opt") DateTime opt: null}) async {
    return new Response.ok("$opt");
  }
}

class MultiQueryParamController extends HTTPController {
  @httpGet
  Future<Response> get({@HTTPQuery("params") List<String> params: null}) async {
    return new Response.ok(params.join(","));
  }
}

class BooleanQueryParamController extends HTTPController {
  @httpGet
  Future<Response> get({@HTTPQuery("param") bool param: false}) async {
    return new Response.ok(param ? "true" : "false");
  }
}

class HTTPParameterController extends HTTPController {
  @requiredHTTPParameter
  @HTTPHeader("X-Request-id")
  String requestId;
  @requiredHTTPParameter
  @HTTPQuery("Shaqs")
  int numberOfShaqs;
  @HTTPHeader("Location")
  String location;
  @HTTPQuery("number")
  int number;

  @httpGet
  Future<Response> get(@HTTPHeader("Cookie") String cookieBrand,
      @HTTPQuery("Table") String tableBrand,
      {@HTTPHeader("Milk") String milkBrand,
      @HTTPQuery("table_legs") int numberOfTableLegs}) async {
    return new Response.ok({
      "location": location,
      "x-request-id": requestId,
      "number": number,
      "Shaqs": numberOfShaqs,
      "cookie": cookieBrand,
      "milk": milkBrand,
      "Table": tableBrand,
      "table_legs": numberOfTableLegs
    });
  }
}

class ModelEncodeController extends HTTPController {
  @httpGet
  Future<Response> getThings(@HTTPPath("thing") String thing) async {
    if (thing == "list") {
      return new Response.ok([
        {"id": 1},
        {"id": 2}
      ]);
    }

    if (thing == "model") {
      var m = new TestModel()
        ..id = 1
        ..name = "Bob";
      return new Response.ok(m);
    }

    if (thing == "modellist") {
      var m1 = new TestModel()
        ..id = 1
        ..name = "Bob";
      var m2 = new TestModel()
        ..id = 2
        ..name = "Fred";

      return new Response.ok([m1, m2]);
    }

    if (thing == "null") {
      return new Response.ok(null);
    }

    return new Response.serverError();
  }
}

class ContentTypeController extends HTTPController {
  @httpGet
  Future<Response> getThing(@HTTPQuery("opt") String opt) async {
    if (opt == "responseContentType") {
      responseContentType = new ContentType("text", "plain");
      return new Response.ok("body");
    } else if (opt == "direct") {
      return new Response.ok("body")
        ..contentType = new ContentType("text", "plain");
    }

    return new Response.serverError();
  }
}

class DuplicateParamController extends HTTPController {
  @httpGet
  Future<Response> getThing(@HTTPQuery("list") List<String> list,
      @HTTPQuery("single") String single) async {
    return new Response.ok({"list": list, "single": single});
  }
}

class DecodeCallbackController extends HTTPController {
  bool didDecode = false;

  @httpGet
  Future<Response> getThing() async {
    return new Response.ok({"didDecode": didDecode});
  }

  @httpPost
  Future<Response> postThing() async {
    return new Response.ok({"didDecode": didDecode});
  }

  @override
  void didDecodeRequestBody(HTTPRequestBody decodedObject) {
    didDecode = true;
  }
}

Future<HttpServer> enableController(String pattern, Type controller) async {
  var router = new Router();
  router.route(pattern).generate(
      () => reflectClass(controller).newInstance(new Symbol(""), []).reflectee);
  router.finalize();

  var server = await HttpServer.bind(InternetAddress.ANY_IP_V4, 4040);
  server.map((httpReq) => new Request(httpReq)).listen(router.receive);

  return server;
}

class TestModel extends ManagedObject<_TestModel> implements _TestModel {}

class _TestModel {
  @managedPrimaryKey
  int id;
  String name;
}