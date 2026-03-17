import 'dart:convert';
import '../cactus/flutter/cactus.dart';

export '../cactus/flutter/cactus.dart' show CactusModelT, cactusGetLastError;

class CactusException implements Exception {
  final String message;
  CactusException(this.message);
  @override
  String toString() => 'CactusException: $message';
}

class CompletionOptions {
  final double temperature;
  final int maxTokens;
  final bool forceTools;

  const CompletionOptions({this.temperature = 0.7, this.maxTokens = 512, this.forceTools = false});
  static const defaultOptions = CompletionOptions();

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'max_tokens': maxTokens,
        if (forceTools) 'force_tools': true,
        'auto_handoff': false,
      };
}

class CompletionResult {
  final String text;
  final List<Map<String, dynamic>> functionCalls;
  final String rawJson;

  CompletionResult({required this.text, required this.functionCalls, this.rawJson = ''});

  factory CompletionResult.fromJson(Map<String, dynamic> json, {String rawJson = ''}) {
    final calls = (json['function_calls'] as List<dynamic>? ?? [])
        .map((c) => (c as Map).cast<String, dynamic>())
        .toList();
    return CompletionResult(
      text: json['response'] as String? ?? '',
      functionCalls: calls,
      rawJson: rawJson,
    );
  }
}

class Cactus {
  final CactusModelT _handle;
  bool _disposed = false;

  Cactus._(this._handle);

  factory Cactus.create(String modelPath) => Cactus._(cactusInit(modelPath, null, false));

  CompletionResult complete(
    List<Map<String, dynamic>> messages, {
    CompletionOptions options = CompletionOptions.defaultOptions,
    List<Map<String, dynamic>>? tools,
  }) {
    if (_disposed) throw StateError('Cactus instance is disposed');
    final rawStr = cactusComplete(
      _handle,
      jsonEncode(messages),
      jsonEncode(options.toJson()),
      tools != null ? jsonEncode(tools) : null,
      null,
    );
    try {
      return CompletionResult.fromJson(jsonDecode(rawStr) as Map<String, dynamic>, rawJson: rawStr);
    } on FormatException {
      return CompletionResult(text: '', functionCalls: [], rawJson: rawStr);
    }
  }

  void dispose() {
    if (_disposed) return;
    cactusDestroy(_handle);
    _disposed = true;
  }
}
