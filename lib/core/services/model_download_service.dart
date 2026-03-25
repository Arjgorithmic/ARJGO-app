import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ModelDownloadService {
  final Dio _dio = Dio();

  static const String modelUrl =
      'https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct/resolve/main/model.safetensors';

  Future<String> downloadModel({
    required Function(double progress) onProgress,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/model.safetensors';

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
    final filePath = '${directory.path}/model.safetensors';
    return File(filePath).exists();
  }

  Future<String> getModelPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/model.safetensors';
  }
}
