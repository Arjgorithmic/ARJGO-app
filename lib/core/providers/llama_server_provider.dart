import 'package:arjgo/core/providers/auth_provider.dart';
import 'package:arjgo/core/services/llama_server_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final llamaServerProvider = ChangeNotifierProvider<LlamaServerNotifier>((ref) {
  return LlamaServerNotifier(ref);
});

class LlamaServerNotifier extends ChangeNotifier {
  final Ref _ref;
  LlamaServer? _server;
  bool _isStarting = false;
  String? _error;

  LlamaServerNotifier(this._ref) {
    _ref.listen(authProvider, (previous, next) {
      _checkAndStart(next.state);
    }, fireImmediately: true);
  }

  bool get isRunning => _server?.isRunning ?? false;
  bool get isStarting => _isStarting;
  String? get error => _error;

  Future<void> _checkAndStart(AuthState authState) async {
    final shouldRun = authState.isModelConfigured && !authState.isOnlineModel && authState.localModelPath != null;
    
    if (shouldRun) {
      if (!_isStarting) {
        // If we have a reference, check it
        if (_server != null && _server!.isRunning) return;
        
        // Otherwise, check if a process is already listening on the port
        final tempServer = LlamaServer(modelPath: authState.localModelPath!, mmprojPath: authState.localMMProjPath);
        if (await tempServer.isAlive()) {
          _server = tempServer;
          notifyListeners();
          return;
        }

        await startServer(authState.localModelPath!, authState.localMMProjPath);
      }
    } else {
      if (isRunning || _isStarting) {
        await stopServer();
      }
    }
  }

  Future<void> startServer(String modelPath, String? mmprojPath) async {
    if (isRunning || _isStarting) return;

    _isStarting = true;
    _error = null;
    notifyListeners();

    try {
      _server = LlamaServer(modelPath: modelPath, mmprojPath: mmprojPath);
      await _server!.start();
      _isStarting = false;
      notifyListeners();
    } catch (e) {
      _isStarting = false;
      _error = e.toString();
      debugPrint('LlamaServerProvider Error: $e');
      notifyListeners();
    }
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.stop();
      _server = null;
      _isStarting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Note: We don't necessarily want to stop the server on provider dispose 
    // if the provider is being rebuilt, but since we use ref.listen, 
    // the provider instance should persist.
    stopServer();
    super.dispose();
  }
}
