import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<bool> requestPersistentStorage() async {
  try {
    return (await web.window.navigator.storage.persist().toDart).toDart;
  } catch (_) {
    return false;
  }
}

void downloadText(String text, String filename) {
  final blob = web.Blob(
    [text.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor =
      web.HTMLAnchorElement()
        ..href = url
        ..download = filename;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // Safari may open the download after the event loop returns.
  Future.delayed(
    const Duration(minutes: 1),
    () => web.URL.revokeObjectURL(url),
  );
}
