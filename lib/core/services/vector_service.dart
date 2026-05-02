import 'dart:io';
import 'package:flutter_embedder/flutter_embedder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class VectorService {
  static final VectorService _instance = VectorService._internal();
  factory VectorService() => _instance;
  VectorService._internal();

  MiniLmEmbedder? _embedder;
  bool _isInitializing = false;

  bool get isReady => _embedder != null;

  Future<void> init() async {
    if (_embedder != null || _isInitializing) return;
    _isInitializing = true;

    try {
      debugPrint('VECTOR: Initializing Embedder...');
      
      // 1. Initialize native runtime
      await initFlutterEmbedder();

      // 2. Prepare files (Native ORT needs direct file paths, assets are compressed)
      final docsDir = await getApplicationSupportDirectory();
      final modelFile = File(p.join(docsDir.path, 'all-MiniLM-L6-v2.onnx'));
      final tokenizerFile = File(p.join(docsDir.path, 'tokenizer.json'));

      // Always copy for safety in dev, or check if exists
      if (!await modelFile.exists() || !await tokenizerFile.exists()) {
        debugPrint('VECTOR: Copying assets to local storage...');
        await _copyAssetToFile('assets/models/all-MiniLM-L6-v2.onnx', modelFile.path);
        await _copyAssetToFile('assets/models/tokenizer.json', tokenizerFile.path);
      }

      // 3. Create embedder
      _embedder = MiniLmEmbedder.create(
        modelPath: modelFile.path,
        tokenizerPath: tokenizerFile.path,
      );
      
      debugPrint('VECTOR: Ready.');
    } catch (e) {
      debugPrint('VECTOR ERROR: Failed to initialize embedder: $e');
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _copyAssetToFile(String assetPath, String filePath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    await File(filePath).writeAsBytes(bytes);
  }

  List<double> embed(String text) {
    if (_embedder == null) {
      debugPrint('VECTOR: Warning - embedder not ready. Returning empty vector.');
      return List.filled(384, 0.0);
    }
    try {
      final result = _embedder!.embed(texts: [text]);
      return result.first;
    } catch (e) {
      debugPrint('VECTOR ERROR: Embedding failed: $e');
      return List.filled(384, 0.0);
    }
  }

  Future<List<List<double>>> embedBatch(List<String> texts) async {
    if (_embedder == null) await init();
    if (_embedder == null) return texts.map((e) => List.filled(384, 0.0)).toList();
    
    return _embedder!.embed(texts: texts);
  }
}
