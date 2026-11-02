class NetworkUtils {
  static bool isNetworkOrHostFailure(dynamic error) {
    if (error == null) return false;
    final str = error.toString().toLowerCase();
    return str.contains('clientexception') ||
        str.contains('failed to fetch') ||
        str.contains('socketexception') ||
        str.contains('connection refused') ||
        str.contains('network is unreachable') ||
        str.contains('doctype') ||
        str.contains('html') ||
        str.contains('type \'string\' is not a subtype') ||
        str.contains('formatexception') ||
        str.contains('backend api service is not connected') ||
        str.contains('connection failed') ||
        str.contains('502') ||
        str.contains('503') ||
        str.contains('404');
  }
}
