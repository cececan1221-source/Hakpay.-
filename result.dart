/// Generic result type used by HakPay services.
///
/// Success:
///   Ok(value)
///
/// Failure:
///   Err(message)
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get value {
    final result = this;
    if (result is Ok<T>) {
      return result.value;
    }
    return null;
  }

  String? get error {
    final result = this;
    if (result is Err<T>) {
      return result.message;
    }
    return null;
  }
}

/// Successful result.
final class Ok<T> extends Result<T> {
  final T value;

  const Ok(this.value);
}

/// Failed result.
final class Err<T> extends Result<T> {
  final String message;

  const Err(this.message);
}
