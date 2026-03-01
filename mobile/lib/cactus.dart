import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// ---------------------------------------------------------------------------
// Native bindings
// ---------------------------------------------------------------------------

// cactus_init(model_path, corpus_dir, cache_index)
typedef _InitNative = Pointer<Void> Function(Pointer<Utf8> path, Pointer<Utf8> corpus, Bool cacheIndex);
typedef _DestroyNative = Void Function(Pointer<Void> model);
typedef _CompleteNative = Int32 Function(
  Pointer<Void> model,
  Pointer<Utf8> messages,
  Pointer<Utf8> buffer,
  IntPtr bufferSize,
  Pointer<Utf8> options,
  Pointer<Utf8> tools,
  Pointer<Void> callback,
  Pointer<Void> userData,
);

DynamicLibrary _load() {
  if (Platform.isAndroid) return DynamicLibrary.open('libcactus.so');
  if (Platform.isIOS) return DynamicLibrary.process();
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

final _lib = _load();
final _init = _lib.lookupFunction<
    _InitNative,
    Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, bool)>('cactus_init');
final _destroy =
    _lib.lookupFunction<_DestroyNative, void Function(Pointer<Void>)>('cactus_destroy');
final _complete = _lib.lookupFunction<
    _CompleteNative,
    int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>, int, Pointer<Utf8>, Pointer<Utf8>,
        Pointer<Void>, Pointer<Void>)>('cactus_complete');

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Cactus model
// ---------------------------------------------------------------------------

class Cactus {
  final Pointer<Void> _handle;
  bool _disposed = false;

  Cactus._(this._handle);

  factory Cactus.create(String modelPath) {
    final ptr = modelPath.toNativeUtf8();
    try {
      final handle = _init(ptr, nullptr, false);
      if (handle == nullptr) throw CactusException('Failed to load model: $modelPath');
      return Cactus._(handle);
    } finally {
      calloc.free(ptr);
    }
  }

  CompletionResult complete(
    List<Map<String, dynamic>> messages, {
    CompletionOptions options = CompletionOptions.defaultOptions,
    List<Map<String, dynamic>>? tools,
  }) {
    if (_disposed) throw StateError('Cactus instance is disposed');

    final msgPtr = jsonEncode(messages).toNativeUtf8();
    final optPtr = jsonEncode(options.toJson()).toNativeUtf8();
    final toolPtr = tools != null ? jsonEncode(tools).toNativeUtf8() : nullptr;
    const bufSize = 1024 * 1024;
    final buf = calloc<Uint8>(bufSize);

    try {
      final code = _complete(
          _handle, msgPtr, buf.cast(), bufSize, optPtr, toolPtr, nullptr, nullptr);
      if (code < 0) throw CactusException('Completion failed (code $code)');
      final rawStr = buf.cast<Utf8>().toDartString();
      try {
        final json = jsonDecode(rawStr) as Map<String, dynamic>;
        return CompletionResult.fromJson(json, rawJson: rawStr);
      } on FormatException {
        return CompletionResult(text: '', functionCalls: [], rawJson: rawStr);
      }
    } finally {
      calloc.free(buf);
      calloc.free(msgPtr);
      calloc.free(optPtr);
      if (toolPtr != nullptr) calloc.free(toolPtr);
    }
  }

  void dispose() {
    if (_disposed) return;
    _destroy(_handle);
    _disposed = true;
  }
}
