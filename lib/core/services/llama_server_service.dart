import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class LlamaServer {
  Process? _process;
  final int port;
  final String modelPath;
  final String? mmprojPath;
  
  // Global lock for local inference
  static bool isInferenceRunning = false;

  static const _channel = MethodChannel('com.arjgorithmic.arjgo/native');

  LlamaServer({this.port = 8080, required this.modelPath, this.mmprojPath});

  final Dio _dio = Dio();

  Future<bool> isAlive() async {
    try {
      final response = await _dio.get('http://127.0.0.1:$port/health').timeout(const Duration(seconds: 1));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> start() async {
    if (_process != null) return;

    try {
      final String workingPath = await _prepareBinary();

      debugPrint('LlamaServer: Starting binary $workingPath on port $port');
      debugPrint('LlamaServer: Model = $modelPath');
      debugPrint('LlamaServer: MMProj = $mmprojPath');

      final List<String> args = [
        '--model', modelPath,
        '--port', port.toString(),
        '--host', '127.0.0.1',
        '--ctx-size', '4096',
        '--threads', Platform.isAndroid ? '4' : '8',
        '--n-gpu-layers', Platform.isMacOS ? '99' : '0',
        '--parallel', '2',
        '--alias', 'qwen2-vl', // Added for API consistency
      ];

      if (Platform.isAndroid) {
        args.add('--no-mmap'); // Safer for mobile memory constraints
      }

      if (mmprojPath != null) {
        args.addAll(['--mmproj', mmprojPath!]);
      }

      // On Android the binary's companion .so files (libllama, libggml, etc.)
      // live in nativeLibraryDir alongside the server binary. Without an RPATH
      // the dynamic linker won't find them, so we set LD_LIBRARY_PATH explicitly.
      final Map<String, String> env = Map.from(Platform.environment);
      if (Platform.isAndroid) {
        final nativeLibDir = workingPath.substring(0, workingPath.lastIndexOf('/'));
        env['LD_LIBRARY_PATH'] = nativeLibDir;
        debugPrint('LlamaServer: LD_LIBRARY_PATH=$nativeLibDir');
      }

      _process = await Process.start(
        workingPath,
        args,
        environment: env,
      );

      final completer = Completer<void>();

      // Patterns the llama-server binary may print when ready
      // (varies across llama.cpp versions)
      bool _isReadyLine(String line) {
        final l = line.toLowerCase();
        return l.contains('http server listening') ||
            l.contains('server listening') ||
            l.contains('listening on') ||
            l.contains('all slots are idle');
      }

      _process!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        debugPrint('LlamaServer STDOUT: $line');
        if (!completer.isCompleted && _isReadyLine(line)) {
          completer.complete();
        }
      });

      _process!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        debugPrint('LlamaServer STDERR: $line');
        if (!completer.isCompleted && _isReadyLine(line)) {
          completer.complete();
        }
      });

      // If the process exits before printing the ready line, fail immediately
      // with the exit code rather than waiting the full timeout.
      _process!.exitCode.then((code) {
        debugPrint('LlamaServer: Process exited early with code $code');
        if (!completer.isCompleted) {
          completer.completeError(
            Exception('Process exited with code $code. '
                'Check that the binary is a valid arm64 ELF for this device.'),
          );
        }
      });

      // Loading a 1–2 GB model on a phone can easily take 60–90 s.
      await completer.future
          .timeout(const Duration(seconds: 120))
          .catchError((e) {
        debugPrint('LlamaServer: Startup failed: $e');
        throw Exception('Server failed to start: $e');
      });

      debugPrint('LlamaServer: Started successfully');
    } catch (e) {
      debugPrint('LlamaServer Error: $e');
      _process?.kill();
      _process = null;
      rethrow;
    }
  }

  Future<void> stop() async {
    _process?.kill();
    _process = null;
    debugPrint('LlamaServer: Stopped');
  }

  String _getBinaryName() {
    if (Platform.isAndroid) return 'libllama_server.so';
    if (Platform.isMacOS) return 'llama-server-macos';
    throw UnsupportedError('Platform not supported');
  }

  Future<String> _prepareBinary() async {
    if (Platform.isAndroid) {
      // The binary lives in nativeLibraryDir — always executable, no chmod needed.
      final String nativeLibDir = await _channel.invokeMethod('getNativeLibDir');
      final binaryPath = '$nativeLibDir/libllama_server.so';
      final file = File(binaryPath);
      if (!await file.exists()) {
        throw Exception(
          'Native binary not found at $binaryPath. '
          'Reinstall the app to re-extract the binary.',
        );
      }
      debugPrint('LlamaServer: Binary at $binaryPath (${await file.length()} bytes)');
      return binaryPath;
    }

    final String binaryName = _getBinaryName();
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$binaryName');

    if (!await file.exists()) {
      throw Exception('Binary not found. Please complete download first.');
    }

    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', file.path]);
    }

    return file.path;
  }

  bool get isRunning => _process != null;
}
