/// API origin can be overridden for isolated QA runs while development keeps
/// the existing local default.
class ApiConfig {
  static const String host = String.fromEnvironment(
    'TRIPMATE_API_HOST',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
