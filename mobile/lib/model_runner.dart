import 'dart:convert';
import 'dart:isolate';
import 'cactus.dart';

const _inferOptions = '{"temperature":0,"max_tokens":256,"force_tools":false,"tool_rag_top_k":0,"auto_handoff":false,"enable_thinking_if_supported":false,"stop_sequences":["<end_of_turn>","<turn|>"],"telemetry_enabled":false}';

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
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          functionCalls = json['function_calls'] as List? ?? [];
        } on FormatException {
          // malformed model output — return empty so caller retries
        }
        reply!.send({'ok': true, 'functionCalls': functionCalls});
      }
    } catch (e) {
      reply!.send({'ok': false, 'error': e.toString()});
    }
  });
}

class ModelRunner {
  SendPort? _port;
  Isolate? _isolate;

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
