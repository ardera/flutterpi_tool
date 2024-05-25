import 'dart:io';

class AuthenticatingHttpClient extends DelegatingHttpClient {
  AuthenticatingHttpClient({
    required this.bearerToken,
    required HttpClient delegate,
  }) : super(delegate: delegate);

  final String? bearerToken;

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) async {
    final req = await super.open(method, host, port, path);

    if (bearerToken != null) {
      req.headers.add('Authorization', 'Bearer $bearerToken');
    }

    return req;
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final req = await super.openUrl(method, url);

    if (bearerToken != null) {
      req.headers.add('Authorization', 'Bearer $bearerToken');
    }

    return req;
  }
}

class DelegatingHttpClient implements HttpClient {
  DelegatingHttpClient({
    required this.delegate,
  });

  final HttpClient delegate;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) {
    return delegate.addCredentials(url, realm, credentials);
  }

  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) {
    return delegate.addProxyCredentials(host, port, realm, credentials);
  }

  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) {
    delegate.authenticate = f;
  }

  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) {
    delegate.authenticateProxy = f;
  }

  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) {
    delegate.badCertificateCallback = callback;
  }

  @override
  void close({bool force = false}) {
    return delegate.close(force: force);
  }

  @override
  set connectionFactory(Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f) {
    delegate.connectionFactory = f;
  }

  @override
  set findProxy(String Function(Uri url)? f) {
    delegate.findProxy = f;
  }

  @override
  set keyLog(Function(String line)? callback) {
    delegate.keyLog = callback;
  }

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) {
    return delegate.open(method, host, port, path);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return delegate.openUrl(method, url);
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) => open("get", host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl("get", url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) => open("post", host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl("post", url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) => open("put", host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl("put", url);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) => open("delete", host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl("delete", url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) => open("head", host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl("head", url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) => open("patch", host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl("patch", url);

  @override
  bool get autoUncompress => delegate.autoUncompress;

  @override
  set autoUncompress(bool value) => delegate.autoUncompress = value;

  @override
  Duration? get connectionTimeout => delegate.connectionTimeout;

  @override
  set connectionTimeout(Duration? value) {
    delegate.connectionTimeout = value;
  }

  @override
  Duration get idleTimeout => delegate.idleTimeout;

  @override
  set idleTimeout(Duration value) {
    delegate.idleTimeout = value;
  }

  @override
  int? get maxConnectionsPerHost => delegate.maxConnectionsPerHost;

  @override
  set maxConnectionsPerHost(int? value) {
    delegate.maxConnectionsPerHost = value;
  }

  @override
  String? get userAgent => delegate.userAgent;

  @override
  set userAgent(String? value) {
    delegate.userAgent = value;
  }
}
