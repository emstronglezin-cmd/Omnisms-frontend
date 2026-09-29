import 'dart:async';

import 'package:app_links/app_links.dart';

/// Waits for one of the registered OmniSMS OAuth callbacks while the system
/// browser flow is active. The callback contains a one-use backend code only.
class GoogleDeepLinkService {
  GoogleDeepLinkService._();

  static final GoogleDeepLinkService instance = GoogleDeepLinkService._();
  final AppLinks _appLinks = AppLinks();

  Future<Uri> runAndWait({
    required String callbackPath,
    required Future<void> Function() startFlow,
    Duration timeout = const Duration(minutes: 4),
  }) async {
    final completer = Completer<Uri>();
    bool isCallback(Uri uri) =>
        uri.scheme == 'omnisms' && uri.host == 'auth' && uri.path == callbackPath;

    final subscription = _appLinks.uriLinkStream.listen((uri) {
      if (!completer.isCompleted && isCallback(uri)) {
        completer.complete(uri);
      }
    }, onError: (Object error) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Le retour Google est indisponible.'));
      }
    });

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null && isCallback(initial)) {
        return initial;
      }

      await startFlow();
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      throw StateError('Le délai de connexion Google a expiré.');
    } finally {
      await subscription.cancel();
    }
  }
}
