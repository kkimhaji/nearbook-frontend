import 'package:dio/dio.dart';

class DioExceptionHandler {
  static String getMessage(Object error) {
    if (error is DioException) {
      return error.error?.toString() ?? '알 수 없는 오류가 발생했습니다.';
    }
    return error.toString();
  }
}
