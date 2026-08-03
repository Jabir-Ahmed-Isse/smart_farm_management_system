/// Raised when a read fails because the device is offline and there is no
/// cached copy to fall back to. Its message is already user-friendly.
class OfflineException implements Exception {
  const OfflineException([
    this.message =
        'You’re offline. Connect to the internet to load the latest data.',
  ]);
  final String message;
  @override
  String toString() => message;
}

/// True when [e] looks like a connectivity failure (mobile SocketException or
/// web ClientException / XHR error) rather than a server/logic error.
bool isOfflineError(Object e) {
  if (e is OfflineException) return true;
  final s = e.toString();
  return s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('ClientException') ||
      s.contains('XMLHttpRequest') ||
      s.contains('Connection closed') ||
      s.contains('Connection refused');
}

/// Turns any thrown error into a short, human message for the UI — never the
/// raw exception text.
String friendlyError(Object e) {
  if (e is OfflineException) return e.message;
  if (isOfflineError(e)) {
    return 'You’re offline. Connect to the internet and try again.';
  }
  final s = e.toString();
  if (s.contains('42501') || s.toLowerCase().contains('not authorized')) {
    return 'You don’t have permission to view this.';
  }
  return 'Something went wrong. Please try again.';
}
