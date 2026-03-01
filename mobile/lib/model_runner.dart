import 'dart:isolate';
import 'cactus.dart';

// ---------------------------------------------------------------------------
// Isolate entry (top-level so Isolate.spawn can reference it)
// ---------------------------------------------------------------------------

void _isolateEntry(SendPort toMain) {
  final port = ReceivePort();
  toMain.send(port.sendPort);

  Cactus? model;

  port.listen((dynamic raw) {
    final msg = raw as Map;
    final type = msg['type'] as String;

    if (type == 'dispose') {
      model?.dispose();
      port.close();
      return;
    }

    final reply = msg['reply'] as SendPort;

    switch (type) {
      case 'load':
        try {
          model = Cactus.create(msg['path'] as String);
          reply.send({'ok': true});
        } catch (e) {
          reply.send({'ok': false, 'error': e.toString()});
        }

      case 'infer':
        try {
          if (model == null) throw StateError('Model not loaded');
          final result = model!.complete(
            _castList(msg['messages'] as List).cast<Map<String, dynamic>>(),
            options: const CompletionOptions(temperature: 0, maxTokens: 1024, forceTools: true),
            tools: _castList(msg['tools'] as List).cast<Map<String, dynamic>>(),
          );
          reply.send({'ok': true, 'functionCalls': result.functionCalls, 'rawJson': result.rawJson});
        } catch (e) {
          reply.send({'ok': false, 'error': e.toString()});
        }
    }
  });
}

List<dynamic> _castList(List raw) =>
    raw.map<dynamic>((e) => e is Map ? _castMap(e) : e).toList();

Map<String, dynamic> _castMap(Map raw) => raw.map((k, v) {
      final value = switch (v) {
        Map m => _castMap(m),
        List l => _castList(l),
        _ => v,
      };
      return MapEntry(k as String, value);
    });

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

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
    final result = _castMap(await reply.first as Map);
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
    final result = _castMap(await reply.first as Map);
    reply.close();
    return result;
  }

  void dispose() {
    _port?.send({'type': 'dispose'});
    Future.delayed(const Duration(seconds: 2), () => _isolate?.kill());
    _port = null;
  }
}
