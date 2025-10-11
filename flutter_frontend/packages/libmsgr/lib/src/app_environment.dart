enum Environment { localMikal, development, staging, production }

abstract class AppEnvironment {
  static late Environment _environment;

  static Environment get environment => _environment;

  static setupEnv(Environment env) {
    _environment = env;
    switch (env) {
      case Environment.localMikal:
        break;
      case Environment.development:
        break;
      case Environment.staging:
        break;
      case Environment.production:
        break;
    }
  }
}
