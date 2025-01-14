library nhost_dart;

import 'package:http/http.dart' as http;
import 'package:nhost_flutter_auth/src/auth/auth_store.dart';
import 'package:nhost_flutter_auth/src/functions/functions_client.dart';
import 'package:nhost_flutter_auth/src/storage/storage_client.dart'
    show NhostStorageClient, applicationOctetStreamType;

import 'package:nhost_sdk/nhost_sdk.dart';

import '../nhost_flutter_auth.dart';
import 'logging.dart';

export 'package:nhost_sdk/nhost_sdk.dart'
    show
    ApiException,
    Session,
    createNhostServiceEndpoint,
    ServiceUrls,
    Subdomain,
    AuthenticationState,
    AuthStateChangedCallback,
    UnsubscribeDelegate,
    AuthStore;
export 'package:nhost_flutter_auth/src/auth/auth_client.dart' show NhostAuthClient;
export 'package:nhost_flutter_auth/src/functions/functions_client.dart'
    show NhostFunctionsClient;
export 'logging.dart' show debugLogNhostErrorsToConsole;


/// API client for accessing Nhost's authentication and storage APIs.
///
/// User authentication and management is provided by the [auth] service, which
/// implements the Nhost Authentication API.
///
/// File storage is provided by the [storage] service, which implements the
/// Nhost Storage API.
///
/// Additional packages for working with GraphQL and Flutter can be found at
/// https://pub.dev/publishers/nhost.io
class NhostClient implements NhostClientBase {
  /// Constructs a new Nhost client.
  ///
  /// {@template nhost.api.NhostClient.subdomain}
  /// [subdomain] is the Nhost "subdomain" and "region" that can be found on your Nhost
  /// project page.
  /// for local development pass 'local' to subdomain
  /// and leave region empty string '';
  /// {@endtemplate}
  ///
  /// {@template nhost.api.NhostClient.serviceUrls}
  /// [region] is the Nhost services Urls that can be found on
  /// your Nhost self-hosted project page.
  /// {@endtemplate}
  ///
  /// {@template nhost.api.NhostClient.authStore}
  /// [authStore] (optional) is used to persist authentication tokens
  /// between restarts of your app. If not provided, the tokens will not be
  /// persisted.
  /// {@endtemplate}
  ///
  /// {@template nhost.api.NhostClient.tokenRefreshInterval}
  /// [tokenRefreshInterval] (optional) is the amount of time the client will
  /// wait between refreshing its authentication tokens. If not provided, will
  /// default to a value provided by the server.
  /// {@endtemplate}
  ///
  /// {@template nhost.api.NhostClient.httpClientOverride}
  /// [httpClientOverride] (optional) can be provided in order to customize the
  /// requests made by the Nhost APIs, which can be useful for proxy
  /// configuration and debugging.
  /// {@endtemplate}
  NhostClient({
    this.subdomain,
    this.serviceUrls,
    AuthStore? authStore,
    Duration? tokenRefreshInterval,
    http.Client? httpClientOverride,
  })
      : _session = UserSession(),
        _authStore = authStore ?? InMemoryAuthStore(),
        _refreshInterval = tokenRefreshInterval,
        _httpClient = httpClientOverride {
    if ((subdomain == null && serviceUrls == null) ||
        (subdomain != null && serviceUrls != null)) {
      throw ArgumentError.notNull(
        'You have to pass either [Subdomain] or [ServiceUrls]',
      );
    }
    initializeLogging();
  }

  /// The Nhost project's backend subdomain and region
  @override
  final Subdomain? subdomain;

  /// The Nhost project's backend region
  @override
  final ServiceUrls? serviceUrls;

  /// Persists authentication information between restarts of the app.
  final AuthStore _authStore;
  final Duration? _refreshInterval;
  final UserSession _session;

  /// The HTTP client used by this client's services.
  @override
  http.Client get httpClient => _httpClient ??= http.Client();
  http.Client? _httpClient;

  /// The GraphQL endpoint URL.
  @override
  String get gqlEndpointUrl {
    if (subdomain != null) {
      return createNhostServiceEndpoint(
        subdomain: subdomain!.subdomain,
        region: subdomain!.region,
        service: 'graphql',
      );
    }

    return serviceUrls!.graphqlUrl;
  }

  /// The Nhost authentication service.
  ///
  /// https://docs.nhost.io/platform/authentication
  @override
  NhostAuthClient get auth =>
      _auth ??= NhostAuthClient(
        url: subdomain != null
            ? createNhostServiceEndpoint(
          subdomain: subdomain!.subdomain,
          region: subdomain!.region,
          service: 'auth',
        )
            : serviceUrls!.authUrl,
        authStore: _authStore,
        tokenRefreshInterval: _refreshInterval,
        session: _session,
        httpClient: httpClient,
      );
  NhostAuthClient? _auth;

  /// The Nhost serverless functions service.
  ///
  /// https://docs.nhost.io/platform/serverless-functions
  @override
  NhostFunctionsClient get functions =>
      _functions ??= NhostFunctionsClient(
        url: subdomain != null
            ? createNhostServiceEndpoint(
          subdomain: subdomain!.subdomain,
          region: subdomain!.region,
          service: 'functions',
        )
            : serviceUrls!.functionsUrl,
        session: _session,
        httpClient: httpClient,
      );
  NhostFunctionsClient? _functions;

  /// The Nhost file storage service.
  ///
  /// https://docs.nhost.io/platform/storage
  @override
  NhostStorageClient get storage =>
      _storage ??= NhostStorageClient(
        url: subdomain != null
            ? createNhostServiceEndpoint(
          subdomain: subdomain!.subdomain,
          region: subdomain!.region,
          service: 'storage',
        )
            : serviceUrls!.storageUrl,
        httpClient: httpClient,
        session: _session,
      );
  NhostStorageClient? _storage;

  /// Releases the resources used by this client.
  @override
  void close() {
    _auth?.close();
    _storage?.close();
    _httpClient?.close();
  }
}
