import 'dart:convert';
import 'dart:isolate';
import 'cactus.dart';

const _inferOptions = '{"temperature":0,"max_tokens":1024,"force_tools":true,"auto_handoff":false,"enable_thinking":false,"stop_sequences":["<end_of_turn>"],"telemetry_enabled":false}';

void _isolateEntry(SendPort toMain) {
  final port = ReceivePort();
  toMain.send(port.sendPort);

  CactusModelT? model;

  port.listen((dynamic raw) {
    final msg = raw as Map;
    final reply = msg['reply'] as SendPort?;

    if (msg['type'] == 'dispose') {
      if (model != null) cactusDestroy(model!);
      port.close();
      return;
    }

    try {
      if (msg['type'] == 'load') {
        model = cactusInit(msg['path'] as String, null, false);
        reply!.send({'ok': true});
      } else {
        if (model == null) throw StateError('Model not loaded');
        final raw = cactusComplete(
          model!,
          jsonEncode(msg['messages']),
          _inferOptions,
          jsonEncode(msg['tools']),
          null,
        );
        List functionCalls = [];
        String rawContent = '';
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          functionCalls = json['function_calls'] as List? ?? [];
          rawContent = json['raw_content'] as String? ?? '';
        } on FormatException {
          // malformed model output — return empty so caller retries
        }
        reply!.send({'ok': true, 'functionCalls': functionCalls, 'rawContent': rawContent});
      }
    } catch (e) {
      reply!.send({'ok': false, 'error': e.toString()});
    }
  });
}

class ModelRunner {
  SendPort? _port;
  Isolate? _isolate;
  bool get isReady => _port != null;

  Future<void> load(String modelPath) async {
    final inbox = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntry, inbox.sendPort);
    _port = await inbox.first as SendPort;
    inbox.close();

    final reply = ReceivePort();
    _port!.send({'type': 'load', 'path': modelPath, 'reply': reply.sendPort});
    final result = await reply.first as Map;
    reply.close();
    if (result['ok'] != true) throw Exception(result['error']);
  }

  Future<Map<String, dynamic>> infer(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
  ) async {
    if (_port == null) throw StateError('ModelRunner not loaded');
    final reply = ReceivePort();
    _port!.send({'type': 'infer', 'messages': messages, 'tools': tools, 'reply': reply.sendPort});
    final result = await reply.first as Map;
    reply.close();
    return result.cast<String, dynamic>();
  }

  void dispose() {
    _port?.send({'type': 'dispose'});
    Future.delayed(const Duration(seconds: 2), () => _isolate?.kill());
    _port = null;
  }
}
