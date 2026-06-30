enum AppFailureType {
  configuration,
  authentication,
  authorization,
  network,
  notFound,
  validation,
  unavailable,
  unknown,
}

class AppFailure {
  const AppFailure({
    required this.type,
    required this.message,
    this.code,
    this.details,
  });

  final AppFailureType type;
  final String message;
  final String? code;
  final Object? details;

  bool get isConfigurationError => type == AppFailureType.configuration;
}
