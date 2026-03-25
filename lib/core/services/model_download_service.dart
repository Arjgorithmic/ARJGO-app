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
      // Mock download for web to allow testing UI and feature flow without CORS/storage bottlenecks
      for (double i = 0; i <= 1.0; i += 0.0025) { // Faster steps for testing
        await Future.delayed(const Duration(milliseconds: 15));
        onProgress(i);
        if ((i * 100) % 5 == 0) {
           debugPrint('Web Mock Download: ${(i * 100).toStringAsFixed(2)}%');
        }
      }
      return 'web_simulated_model_path';
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
          if (received % (1024 * 1024) == 0) { // Log every MB
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
    if (kIsWeb) {
       // On web, we check SharedPreferences since there's no dart:io File
       return false; // AuthNotifier handles the SharedPreferences check
    }
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/model.safetensors';
    return File(filePath).exists();
  }

  Future<String> getModelPath() async {
    if (kIsWeb) return 'web_simulated_model_path';
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/model.safetensors';
  }
}
