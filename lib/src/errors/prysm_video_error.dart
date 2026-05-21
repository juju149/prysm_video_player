enum PrysmVideoErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  unsupportedCodec,
  unsupportedFormat,
  drm,
  cors,
  platformUnsupported,
  backendInitializationFailed,
  disposed,
  unknown,
}

sealed class PrysmVideoError implements Exception {
  const PrysmVideoError({
    required this.kind,
    required this.code,
    required this.userMessage,
    required this.developerMessage,
    required this.retryable,
    this.cause,
  });

  factory PrysmVideoError.map(Object error, [StackTrace? stackTrace]) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('401') || lower.contains('unauthorized')) {
      return PrysmNetworkVideoError.unauthorized(text, error);
    }
    if (lower.contains('403') || lower.contains('forbidden')) {
      return PrysmNetworkVideoError.forbidden(text, error);
    }
    if (lower.contains('404') || lower.contains('not found')) {
      return PrysmNetworkVideoError.notFound(text, error);
    }
    if (lower.contains('timeout')) {
      return PrysmNetworkVideoError.timeout(text, error);
    }
    if (lower.contains('cors')) {
      return PrysmCorsVideoError(text, error);
    }
    if (lower.contains('codec')) {
      return PrysmUnsupportedVideoError.codec(text, error);
    }
    if (lower.contains('format')) {
      return PrysmUnsupportedVideoError.format(text, error);
    }
    if (lower.contains('drm') ||
        lower.contains('widevine') ||
        lower.contains('fairplay')) {
      return PrysmDrmVideoError(text, error);
    }
    return PrysmUnknownVideoError(text, error);
  }

  final PrysmVideoErrorKind kind;
  final String code;
  final String userMessage;
  final String developerMessage;
  final bool retryable;
  final Object? cause;

  @override
  String toString() => '$code: $developerMessage';
}

final class PrysmNetworkVideoError extends PrysmVideoError {
  const PrysmNetworkVideoError({
    required super.kind,
    required super.code,
    required super.userMessage,
    required super.developerMessage,
    required super.retryable,
    super.cause,
  });

  factory PrysmNetworkVideoError.timeout(String message, Object cause) {
    return PrysmNetworkVideoError(
      kind: PrysmVideoErrorKind.timeout,
      code: 'network_timeout',
      userMessage: 'The video request timed out.',
      developerMessage: message,
      retryable: true,
      cause: cause,
    );
  }

  factory PrysmNetworkVideoError.unauthorized(String message, Object cause) {
    return PrysmNetworkVideoError(
      kind: PrysmVideoErrorKind.unauthorized,
      code: 'network_unauthorized',
      userMessage: 'You are not authorized to watch this video.',
      developerMessage: message,
      retryable: false,
      cause: cause,
    );
  }

  factory PrysmNetworkVideoError.forbidden(String message, Object cause) {
    return PrysmNetworkVideoError(
      kind: PrysmVideoErrorKind.forbidden,
      code: 'network_forbidden',
      userMessage: 'This video is not available for this account.',
      developerMessage: message,
      retryable: false,
      cause: cause,
    );
  }

  factory PrysmNetworkVideoError.notFound(String message, Object cause) {
    return PrysmNetworkVideoError(
      kind: PrysmVideoErrorKind.notFound,
      code: 'network_not_found',
      userMessage: 'The video could not be found.',
      developerMessage: message,
      retryable: false,
      cause: cause,
    );
  }
}

final class PrysmUnsupportedVideoError extends PrysmVideoError {
  const PrysmUnsupportedVideoError({
    required super.kind,
    required super.code,
    required super.userMessage,
    required super.developerMessage,
    required super.retryable,
    super.cause,
  });

  factory PrysmUnsupportedVideoError.codec(String message, Object cause) {
    return PrysmUnsupportedVideoError(
      kind: PrysmVideoErrorKind.unsupportedCodec,
      code: 'unsupported_codec',
      userMessage: 'This device cannot decode the video codec.',
      developerMessage: message,
      retryable: false,
      cause: cause,
    );
  }

  factory PrysmUnsupportedVideoError.format(String message, Object cause) {
    return PrysmUnsupportedVideoError(
      kind: PrysmVideoErrorKind.unsupportedFormat,
      code: 'unsupported_format',
      userMessage: 'This video format is not supported.',
      developerMessage: message,
      retryable: false,
      cause: cause,
    );
  }
}

final class PrysmDrmVideoError extends PrysmVideoError {
  PrysmDrmVideoError(String message, Object cause)
    : super(
        kind: PrysmVideoErrorKind.drm,
        code: 'drm_error',
        userMessage: 'This protected video cannot be played here.',
        developerMessage: message,
        retryable: false,
        cause: cause,
      );
}

final class PrysmCorsVideoError extends PrysmVideoError {
  PrysmCorsVideoError(String message, Object cause)
    : super(
        kind: PrysmVideoErrorKind.cors,
        code: 'web_cors',
        userMessage: 'The browser blocked access to this video.',
        developerMessage: message,
        retryable: false,
        cause: cause,
      );
}

final class PrysmDisposedVideoError extends PrysmVideoError {
  const PrysmDisposedVideoError()
    : super(
        kind: PrysmVideoErrorKind.disposed,
        code: 'controller_disposed',
        userMessage: 'The player is no longer available.',
        developerMessage: 'PrysmVideoController was used after dispose.',
        retryable: false,
      );
}

final class PrysmUnknownVideoError extends PrysmVideoError {
  PrysmUnknownVideoError(String message, Object cause)
    : super(
        kind: PrysmVideoErrorKind.unknown,
        code: 'unknown',
        userMessage: 'The video could not be played.',
        developerMessage: message,
        retryable: true,
        cause: cause,
      );
}
