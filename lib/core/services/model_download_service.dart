import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ModelDownloadService {
  final Dio _dio = Dio();

  static const String modelUrl =
      'https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct/resolve/main/model.safetensors';

  Future<String> downloadModel({
    required Function(double progress) onProgress,
  }) async {
    if (kIsWeb) {
      // Simulate real progress on Web for developer testing
      // since direct Dio download to File isn't supported/CORS restricted
      for (int i = 0; i <= 100; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        onProgress(i / 100.0);
      }
      return 'web_simulated_path';
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/model.safetensors';

    await _dio.download(
      modelUrl,
      filePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          final p = received / total;
          onProgress(p);
          if (received % (1024 * 1024) == 0) {
             debugPrint('Download progress: ${(p * 100).toStringAsFixed(2)}% ($received bytes)');
          }
        } else {
          debugPrint('Download received: $received bytes (Total size unknown)');
        }
      },
    );

    return filePath;
  }

  Future<bool> isModelDownloaded() async {
    if (kIsWeb) return false; // Web always simulates for now unless we use IDB

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/model.safetensors';
    return File(filePath).exists();
  }

  Future<String> getModelPath() async {
    if (kIsWeb) return 'web_simulated_path';

    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/model.safetensors';
  }
}
