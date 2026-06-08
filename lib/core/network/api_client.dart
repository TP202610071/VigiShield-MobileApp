import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../storage/auth_storage.dart';

class ApiClient {
  final Dio _dio = Dio();
  final AuthStorage _storage;

  ApiClient(this._storage, {String baseUrl = AppConstants.defaultEmulatorUrl}) {
    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  String get currentBaseUrl => _dio.options.baseUrl;

  /// Hot-swap the backend URL without rebuilding the widget tree.
  void updateBaseUrl(String url) {
    _dio.options.baseUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');
  }

  String _extractErrorMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return data['error'] as String;
      if (data is Map && data['title'] != null) return data['title'] as String;
    } catch (_) {}
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'No se pudo conectar al servidor. Verifica la dirección IP en Ajustes → Servidor.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Sin conexión al servidor. ¿Estás en la misma red WiFi que el servidor?';
    }
    switch (e.response?.statusCode) {
      case 400:
        return 'Datos inválidos';
      case 401:
        return 'No autorizado';
      case 403:
        return 'Acceso denegado';
      case 404:
        return 'Recurso no encontrado';
      case 409:
        return 'Conflicto con datos existentes';
      case 500:
        return 'Error interno del servidor';
      default:
        return 'Error de conexión. Verifica la dirección del servidor en Ajustes.';
    }
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? queryParams}) async {
    try {
      final res = await _dio.get(path, queryParameters: queryParams);
      return res.data as T;
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e), e.response?.statusCode);
    }
  }

  Future<T> post<T>(String path, {dynamic body}) async {
    try {
      final res = await _dio.post(path, data: body);
      return res.data as T;
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e), e.response?.statusCode);
    }
  }

  Future<T> put<T>(String path, {dynamic body}) async {
    try {
      final res = await _dio.put(path, data: body);
      return res.data as T;
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e), e.response?.statusCode);
    }
  }

  Future<void> delete(String path) async {
    try {
      await _dio.delete(path);
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e), e.response?.statusCode);
    }
  }

  /// POST multipart/form-data (e.g. uploading face photos). Dio sets the
  /// multipart boundary automatically when [formData] is FormData.
  Future<T> postMultipart<T>(String path, FormData formData) async {
    try {
      final res = await _dio.post(
        path,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return res.data as T;
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e), e.response?.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}
