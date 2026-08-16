/// Generic result type used by HakPay services.

sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;

  bool get isErr => this is Err<T>;

  T? get value {
    final current = this;

    if (current is Ok<T>) {
      return current.value;
    }

    return null;
  }

  String? get error {
    final current = this;

    if (current is Err<T>) {
      return current.message;
    }

    return null;
  }
}

final class Ok<T> extends Result<T> {
  final T value;

  const Ok(this.value);
}

final class Err<T> extends Result<T> {
  final String message;

  const Err(this.message);
}
