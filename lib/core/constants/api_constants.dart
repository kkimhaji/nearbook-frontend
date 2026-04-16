class ApiConstants {
  static const String baseUrl = String.fromEnvironment('BASE_URL',
      defaultValue: 'http://localhost:3000/api');
  static const String socketUrl = String.fromEnvironment('SOCKET_URL',
      defaultValue: 'http://localhost:3000');
}
