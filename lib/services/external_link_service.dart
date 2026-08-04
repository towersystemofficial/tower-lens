import 'package:flutter/services.dart';

class ExternalLinkService {
  const ExternalLinkService();

  static const _channel = MethodChannel(
    'com.example.tower_lens/external_links',
  );

  Future<void> open(String url) async {
    final opened = await _channel.invokeMethod<bool>('open', {'url': url});
    if (opened != true) {
      throw PlatformException(
        code: 'link_not_opened',
        message: 'No app is available to open this link.',
      );
    }
  }
}
