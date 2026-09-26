import 'package:flutter/services.dart';

class PlatformBridge {
  static const _channel = MethodChannel('app.scanandopen/platform');
  Future<List<String>> scanDocument() async => (await _channel.invokeListMethod<String>('scanDocument')) ?? const [];
  Future<bool?> saveAs(String path, String mime, String filename) => _channel.invokeMethod<bool>('saveAs', {'path': path, 'mime': mime, 'filename': filename});
  Future<List<String>> consumeSharedImages() async => (await _channel.invokeListMethod<String>('consumeSharedImages')) ?? const [];
}
