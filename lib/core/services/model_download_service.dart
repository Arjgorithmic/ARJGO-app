import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ModelDownloadService {
  static const String modelUrl =
      'https://huggingface.co/Arjgorithmic/Arjgo-Qwen2-VL-2B/resolve/main/Qwen2-VL-2B-Instruct-Q4_K_M.gguf';

  static const String mmprojUrl =
      'https://huggingface.co/Arjgorithmic/Arjgo-Qwen2-VL-2B/resolve/main/mmproj-Qwen2-VL-2B-Instruct-Q8_0.gguf';

  Future<String> _downloadFile({
    required String url,
    required String fileName,
    required Function(double progress) onProgress,
  }) async {
    // 1. Create the background task
    final task = DownloadTask(
      url: url,
      filename: fileName,
      baseDirectory: BaseDirectory.applicationDocuments,
      updates: Updates.statusAndProgress,
      retries: 5,
      allowPause: true,
      displayName: fileName,
    );

    // 2. Configure background notifications
    FileDownloader().configureNotification(
      running: TaskNotification('Arjgo Intelligence', 'Downloading $fileName: {progress}'),
      complete: TaskNotification('Download Complete', '$fileName has been synchronized'),
      error: TaskNotification('Download Failed', 'Interrupted during $fileName transfer'),
      progressBar: true,
    );

    // 3. Execute download (will continue in background if app is closed)
    final result = await FileDownloader().download(
      task,
      onProgress: (progress) {
        onProgress(progress);
      },
      onStatus: (status) => debugPrint('Arjgo Download Status: $status'),
    );

    if (result.status == TaskStatus.complete) {
      return await task.filePath();
    } else {
      throw Exception('Download failed with status: ${result.status}');
    }
  }

  Future<String> downloadModel({
    required Function(double progress) onProgress,
  }) async {
    if (kIsWeb) {
      for (double i = 0; i <= 1.0; i += 0.0025) {
        await Future.delayed(const Duration(milliseconds: 15));
        onProgress(i);
      }
      return 'web_simulated_model_path';
    }
    return _downloadFile(url: modelUrl, fileName: 'model.gguf', onProgress: onProgress);
  }

  Future<String> downloadMMProj({
    required Function(double progress) onProgress,
  }) async {
    if (kIsWeb) {
      for (double i = 0; i <= 1.0; i += 0.01) {
        await Future.delayed(const Duration(milliseconds: 10));
        onProgress(i);
      }
      return 'web_simulated_mmproj_path';
    }
    return _downloadFile(url: mmprojUrl, fileName: 'mmproj.gguf', onProgress: onProgress);
  }

  static const String macBinaryUrl =
      'https://github.com/Arjgorithmic/Arjgo-assets/raw/main/binaries/llama-server-macos';

  Future<String> downloadBinary({
    required Function(double progress) onProgress,
  }) async {
    if (kIsWeb) {
      for (double i = 0; i <= 1.0; i += 0.1) {
        await Future.delayed(const Duration(milliseconds: 100));
        onProgress(i);
      }
      return 'web_simulated_binary_path';
    }

    if (Platform.isAndroid) {
      onProgress(1.0);
      return 'android_native_binary_path';
    }

    if (Platform.isMacOS) {
      const binaryName = 'llama-server-macos';
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$binaryName';

      try {
        final assetData = await rootBundle.load('assets/binaries/$binaryName');
        final file = File(filePath);
        await file.writeAsBytes(assetData.buffer.asUint8List());
        await Process.run('chmod', ['+x', filePath]);
        onProgress(1.0);
        return filePath;
      } catch (_) {
        debugPrint('Binary: Not found in asset bundle, downloading via background service...');
      }

      return _downloadFile(url: macBinaryUrl, fileName: binaryName, onProgress: onProgress);
    }

    throw UnsupportedError('Binary not available for this platform');
  }

  Future<bool> isModelDownloaded() async {
    if (kIsWeb) return false;
    final directory = await getApplicationDocumentsDirectory();
    final modelFile = File('${directory.path}/model.gguf');
    final mmprojFile = File('${directory.path}/mmproj.gguf');
    
    if (Platform.isAndroid) {
      // Binary is bundled in APK, only check models
      return modelFile.existsSync() && mmprojFile.existsSync();
    }
    
    String binaryName = 'llama-server-macos';
    final binaryFile = File('${directory.path}/$binaryName');
    return modelFile.existsSync() && binaryFile.existsSync() && mmprojFile.existsSync();
  }

  Future<String> getModelPath() async {
    if (kIsWeb) return 'web_simulated_model_path';
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/model.gguf';
  }

  Future<String> getMMProjPath() async {
    if (kIsWeb) return 'web_simulated_mmproj_path';
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/mmproj.gguf';
  }

  // NOTE: On Android the binary lives in nativeLibraryDir (set by the OS at
  // install time from jniLibs/). Call LlamaServer._prepareBinary() to get the
  // real executable path — do NOT use this method on Android.
  Future<String> getBinaryPath() async {
    if (kIsWeb) return 'web_simulated_binary_path';
    if (Platform.isAndroid) throw UnsupportedError('Use nativeLibraryDir on Android');
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/llama-server-macos';
  }
}
