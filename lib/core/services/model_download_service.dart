import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ModelDownloadService {
  final Dio _dio = Dio();

  static const String modelUrl =
      'https://huggingface.co/bartowski/Qwen_Qwen3-VL-2B-Instruct-GGUF/resolve/main/Qwen3-VL-2B-Instruct-Q4_K_M.gguf';

  Future<String> downloadModel({
    required Function(double progress) onProgress,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/qwen3_vl_model.gguf';

    await _dio.download(
      modelUrl,
      filePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          onProgress(received / total);
        }
      },
    );

    return filePath;
  }

  Future<bool> isModelDownloaded() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/qwen3_vl_model.gguf';
    return File(filePath).exists();
  }

  Future<String> getModelPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/qwen3_vl_model.gguf';
  }
}
