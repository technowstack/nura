sealed class UiState<T> {
  const UiState();
}

class UiLoading<T> extends UiState<T> {
  const UiLoading();
}

class UiEmpty<T> extends UiState<T> {
  const UiEmpty();
}

class UiData<T> extends UiState<T> {
  const UiData(this.value);

  final T value;
}

class UiError<T> extends UiState<T> {
  const UiError(this.message);

  final String message;
}
