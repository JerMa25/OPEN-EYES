// lib/services/api_client.dart

import 'package:dio/dio.dart';
import '../config.dart';
import 'package:flutter/foundation.dart';


/// Client API centralisé utilisant Dio
/// Gère les intercepteurs, le retry, et les erreurs de manière uniforme
class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;

  // Singleton pattern
  factory ApiClient() {
    _instance ??= ApiClient._internal();
    return _instance!;
  }

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: Duration(seconds: AppConfig.httpTimeout),
      receiveTimeout: Duration(seconds: AppConfig.httpTimeout),
      sendTimeout: Duration(seconds: AppConfig.httpTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Ajouter les intercepteurs
    _dio.interceptors.addAll([
      _LoggingInterceptor(),
      _RetryInterceptor(_dio),
    ]);
  }

  /// Getter pour accéder à l'instance Dio
  Dio get dio => _dio;

  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTHODES HTTP
  // ═══════════════════════════════════════════════════════════════════════════

  /// GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GESTION DES ERREURS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Transforme une DioException en message lisible
  ApiException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          'Délai d\'attente dépassé. Vérifiez votre connexion.',
          code: 'TIMEOUT',
          statusCode: error.response?.statusCode,
        );

      case DioExceptionType.connectionError:
        return ApiException(
          'Impossible de se connecter au serveur. Vérifiez que le backend est lancé.',
          code: 'CONNECTION_ERROR',
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = _getErrorMessage(error.response);
        return ApiException(
          message,
          code: 'HTTP_$statusCode',
          statusCode: statusCode,
          data: error.response?.data,
        );

      case DioExceptionType.cancel:
        return ApiException(
          'Requête annulée',
          code: 'CANCELLED',
        );

      default:
        return ApiException(
          error.message ?? 'Erreur inconnue',
          code: 'UNKNOWN',
        );
    }
  }

  /// Extrait le message d'erreur de la réponse
  String _getErrorMessage(Response? response) {
    if (response?.data == null) {
      return 'Erreur serveur (${response?.statusCode})';
    }

    final data = response!.data;
    if (data is Map) {
      // Chercher les clés communes d'erreur
      return data['message']?.toString() ??
          data['error']?.toString() ??
          data['detail']?.toString() ??
          'Erreur serveur (${response.statusCode})';
    }

    return data.toString();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTERCEPTEUR DE LOGGING
// ═══════════════════════════════════════════════════════════════════════════════

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (AppConfig.enableDebugLogs) {
      debugPrint('╔══════════════════════════════════════════');
      debugPrint('║ 📤 REQUEST: ${options.method} ${options.uri}');
      if (options.data != null) {
        debugPrint('║ 📦 Data: ${options.data}');
      }
      debugPrint('╚══════════════════════════════════════════');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (AppConfig.enableDebugLogs) {
      debugPrint('╔══════════════════════════════════════════');
      debugPrint('║ 📥 RESPONSE: ${response.statusCode} ${response.requestOptions.uri}');
      debugPrint('╚══════════════════════════════════════════');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (AppConfig.enableDebugLogs) {
      debugPrint('╔══════════════════════════════════════════');
      debugPrint('║ ❌ ERROR: ${err.type}');
      debugPrint('║ 📍 URL: ${err.requestOptions.uri}');
      debugPrint('║ 💬 Message: ${err.message}');
      if (err.response != null) {
        debugPrint('║ 📦 Response: ${err.response?.data}');
      }
      debugPrint('╚══════════════════════════════════════════');
    }
    handler.next(err);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTERCEPTEUR DE RETRY
// ═══════════════════════════════════════════════════════════════════════════════

class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  final int _maxRetries = AppConfig.maxRetries;

  _RetryInterceptor(this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Ne retry que pour les erreurs de connexion/timeout
    if (_shouldRetry(err)) {
      final retryCount = err.requestOptions.extra['retryCount'] ?? 0;

      if (retryCount < _maxRetries) {
        if (AppConfig.enableDebugLogs) {
          debugPrint('🔄 Retry ${retryCount + 1}/$_maxRetries...');
        }

        // Attendre avant de retry (backoff exponentiel)
        await Future.delayed(Duration(seconds: retryCount + 1));

        // Mettre à jour le compteur
        err.requestOptions.extra['retryCount'] = retryCount + 1;

        try {
          final response = await _dio.fetch(err.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          // Continuer avec l'erreur originale si le retry échoue
        }
      }
    }

    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXCEPTION PERSONNALISÉE
// ═══════════════════════════════════════════════════════════════════════════════

class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final dynamic data;

  ApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => message;

  /// Vérifie si c'est une erreur de connexion
  bool get isConnectionError => code == 'CONNECTION_ERROR' || code == 'TIMEOUT';

  /// Vérifie si c'est une erreur 404
  bool get isNotFound => statusCode == 404;

  /// Vérifie si c'est une erreur d'authentification
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;
}
