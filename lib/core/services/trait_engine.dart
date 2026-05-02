import 'dart:convert';
import 'dart:io';
import 'package:arjgo/core/models/trait.dart';
import 'package:arjgo/core/services/trait_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:arjgo/core/services/llama_server_service.dart';

// ── Models ───────────────────────────────────────────────────────────────────

typedef PreProcessFunc = Future<File> Function(File image);
typedef PromptBuildFunc = String Function();
typedef InferenceFunc = Future<String> Function(String prompt, File image);
typedef ParseFunc<T> = T Function(String rawOutput);
typedef PostProcessFunc<T> = Future<T> Function(dynamic parsed);
typedef ValidateFunc<T> = T Function(dynamic parsed);

class TraitPipeline<T> {
  final Trait info;
  final PreProcessFunc? preProcess;
  final String promptTemplate; // Loaded from Supabase/Hive
  final ParseFunc<T> parse;
  final PostProcessFunc<T>? postProcess;
  final ValidateFunc<T> validate;

  const TraitPipeline({
    required this.info,
    required this.promptTemplate,
    this.preProcess,
    required this.parse,
    this.postProcess,
    required this.validate,
  });

  String get id => info.id;
  String get name => info.name;
  
  // Backward compatibility helper
  PromptBuildFunc get buildPrompt => () => promptTemplate;
}

// Logic components registry to keep code separated from dynamic data
class TraitLogic {
  final PreProcessFunc? preProcess;
  final ParseFunc<dynamic> parse;
  final PostProcessFunc<dynamic>? postProcess;
  final ValidateFunc<dynamic> validate;

  const TraitLogic({
    this.preProcess,
    required this.parse,
    this.postProcess,
    required this.validate,
  });
}

class SnackableResult {
  String status; // GOOD | MODERATE | BAD
  List<String> reasons;
  String suggestion;
  double confidence;
  String confidenceLabel;
  String verdictLabel; // NEW

  SnackableResult({
    required this.status,
    required this.reasons,
    required this.suggestion,
    this.confidence = 0.7,
    this.confidenceLabel = "Medium",
    this.verdictLabel = "⚠️ UNKNOWN",
  });

  @override
  String toString() => '## $verdictLabel\n**Confidence:** $confidenceLabel\n\n### Reasons\n${reasons.map((r) => '- $r').join('\n')}\n\n### Suggestion\n$suggestion';
}

class SlayResult {
  int score; // 1–10
  List<String> suggestions;
  String nextStep;
  int? delta;
  String? improvementReason;
  String nextLevelSuggestion;
  String identityLabel; // NEW

  SlayResult({
    required this.score,
    required this.suggestions,
    required this.nextStep,
    required this.nextLevelSuggestion,
    this.delta,
    this.improvementReason,
    this.identityLabel = "🔥 LOOK",
  });

  @override
  String toString() {
    final deltaStr = delta != null ? ' (${delta! > 0 ? "+$delta" : delta} improvement)' : '';
    final reasonStr = improvementReason != null ? '\n**Trend:** $improvementReason' : '';
    return '## $identityLabel ($score/10)$deltaStr\n$reasonStr\n\n### Next Step\n$nextStep\n\n### Next Level\n$nextLevelSuggestion\n\n### Suggestions\n${suggestions.map((s) => '- $s').join('\n')}';
  }
}

// ── Normalization & Identity Helpers ──────────────────────────────────────────

String normalizeOutput(String text) {
  if (text.isEmpty) return "";
  
  // 1. Basic cleanup but PRESERVE newlines
  String normalized = text.trim();
  
  // 2. Convert ALL-CAPS lines (3+ chars) to Markdown headers
  // We do this line-by-line to avoid greedy regex issues
  normalized = normalized.split('\n').map((line) {
    final trimmedLine = line.trim();
    if (trimmedLine.length >= 3 && 
        trimmedLine == trimmedLine.toUpperCase() && 
        RegExp(r'^[A-Z\s]+$').hasMatch(trimmedLine)) {
      return '## $trimmedLine';
    }
    return trimmedLine;
  }).join('\n');

  // 3. Normalize bullet points
  normalized = normalized.replaceAll("•", "-").replaceAll("●", "-").replaceAll("*", "-");
  
  // 4. Ensure bullets have a leading newline if they follow text
  normalized = normalized.replaceAllMapped(RegExp(r'([^\n])\n-\s+'), (match) => '${match.group(1)}\n\n- ');
  
  return normalized.trim();
}

String getConfidenceLabel(double confidence) {
  if (confidence >= 0.85) return "High";
  if (confidence >= 0.7) return "Medium";
  return "Low";
}

String getSnackableVerdict(String status) {
  switch (status) {
    case "GOOD":
      return "✅ SNACKABLE";
    case "MODERATE":
      return "⚠️ MODERATE";
    case "BAD":
      return "❌ NOT SNACKABLE";
    default:
      return "⚠️ UNKNOWN";
  }
}

String getSlayIdentity(int score) {
  if (score >= 8) return "🔥 SHARP LOOK";
  if (score >= 6) return "🔥 GOOD LOOK";
  return "⚠️ NEEDS IMPROVEMENT";
}

String getFriendlyErrorMessage(String traitId) {
  switch (traitId) {
    case "snackable":
      return "⚠️ Couldn't analyze food clearly. Try again with better lighting.";
    case "slay":
      return "⚠️ Couldn't analyze your look properly. Try a clearer photo.";
    default:
      return "⚠️ Couldn't process image. Please try again.";
  }
}

// ── Executor ────────────────────────────────────────────────────────────────

class TraitExecutor {
  Future<T> execute<T>({
    required TraitPipeline<T> pipeline,
    required File image,
    required bool isOnline,
    String? apiKey,
    bool isPriority = false,
  }) async {
    try {
      File processedImage = image;
      if (pipeline.preProcess != null) {
        processedImage = await pipeline.preProcess!(image);
      }

      final prompt = pipeline.buildPrompt();
      
      String rawOutput;
      if (isOnline && apiKey != null && apiKey.isNotEmpty) {
        debugPrint('TraitExecutor: Using Cloud Inference (OpenRouter)');
        rawOutput = await runCloudInference(prompt, processedImage, apiKey);
      } else {
        debugPrint('TraitExecutor: Using Local Inference (127.0.0.1:8080)');
        rawOutput = await runLocalInference(prompt, processedImage, isPriority: isPriority);
      }

      if (rawOutput.startsWith("ERROR_INTERNAL")) {
        throw rawOutput;
      }

      final cleanOutput = normalizeOutput(rawOutput);
      final parsed = pipeline.parse(cleanOutput);
      final postProcessed = pipeline.postProcess != null ? await pipeline.postProcess!(parsed) : parsed;
      final validated = pipeline.validate(postProcessed);

      return validated;
    } catch (e) {
      debugPrint('Execution failed: $e');
      final errorMsg = getFriendlyErrorMessage(pipeline.id);
      return pipeline.parse("ERROR_FALLBACK: $errorMsg");
    }
  }
}

// ── Shared Services ───────────────────────────────────────────────────────────

final Dio _dio = Dio();

Future<File> optimizeImage(File file) async {
  try {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return file;

    img.Image resized;
    if (image.width > image.height) {
      resized = img.copyResize(image, width: 640); // Restored for high-fidelity vision
    } else {
      resized = img.copyResize(image, height: 640);
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/optimized_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(img.encodeJpg(resized, quality: 90)); // High quality preservation
    return tempFile;
  } catch (e) {
    debugPrint('Optimization error: $e');
    return file;
  }
}

Future<String> runLocalInference(String prompt, File image, {bool isPriority = false}) async {
  // If priority (scan), wait up to 15 seconds for current inference to finish
  if (isPriority) {
    int retries = 0;
    while (LlamaServer.isInferenceRunning && retries < 30) {
      debugPrint('TraitEngine: Priority wait for inference lock (retry $retries)...');
      await Future.delayed(const Duration(milliseconds: 500));
      retries++;
    }
  }

  if (LlamaServer.isInferenceRunning) {
    throw "Intelligence engine is busy with another task. Please wait a moment.";
  }
  
  LlamaServer.isInferenceRunning = true;
  try {
    final base64Image = base64Encode(await image.readAsBytes());
    debugPrint('TraitEngine: Sending CHAT vision request to 127.0.0.1:8080');
    
    final response = await _dio.post(
      'http://127.0.0.1:8080/v1/chat/completions',
      data: {
        'model': 'qwen2-vl',
        'messages': [
          {'role': 'system', 'content': 'You are a pocket intelligence engine. Provide strictly structured data based on the user prompt. You must always complete all sections in full. Do not stop early.'},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
              }
            ]
          }
        ],
        'temperature': 0.1,
        'max_tokens': 1024,
        'stream': false,
      },
    ).timeout(const Duration(seconds: 300));

    debugPrint('TraitEngine: Native chat inference successful');
    final content = response.data['choices'][0]['message']['content'] as String;
    debugPrint('TraitEngine: Raw Content: $content');
    return content.trim();
  } catch (e) {
    debugPrint('TraitEngine: Native inference FAILED: $e');
    return "ERROR_INTERNAL: $e";
  } finally {
    LlamaServer.isInferenceRunning = false;
  }
}

Future<String> runCloudInference(String prompt, File image, String apiKey) async {
  try {
    final base64Image = base64Encode(await image.readAsBytes());
    final response = await _dio.post(
      'https://openrouter.ai/api/v1/chat/completions',
      options: Options(headers: {
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': 'https://arjgo.app',
        'X-Title': 'Arjgo',
      }),
      data: {
        'model': 'qwen/qwen-2-vl-72b-instruct', // Use the powerful version in cloud
        'messages': [
          {'role': 'system', 'content': 'Provide professional data based strictly on visuals. You must always complete all sections in full. Do not stop early.'},
          {
            'role': 'user',
            'content': [
              {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}},
              {'type': 'text', 'text': prompt},
            ]
          }
        ],
      },
    ).timeout(const Duration(seconds: 60));

    return response.data['choices'][0]['message']['content'] as String;
  } catch (e) {
    debugPrint('TraitEngine: Cloud inference FAILED: $e');
    return "ERROR_INTERNAL: $e";
  }
}

// Registry of hardcoded logic tied to trait IDs
final Map<String, TraitLogic> traitLogicRegistry = {
  'snackable': TraitLogic(
    preProcess: optimizeImage,
    parse: (raw) {
      if (raw.contains("ERROR_FALLBACK")) {
        return SnackableResult(status: "MODERATE", reasons: [raw.split(": ").last], suggestion: "Try another angle.");
      }

      try {
        String status = "MODERATE";
        if (raw.toUpperCase().contains("STATUS: BAD")) status = "BAD";
        else if (raw.toUpperCase().contains("STATUS: GOOD")) status = "GOOD";

        final reasonsMatch = RegExp(r'REASONS:(.*?)(SUGGESTION:|$)', caseSensitive: false, dotAll: true).firstMatch(raw);
        final reasons = (reasonsMatch?.group(1) ?? '')
            .split('-')
            .where((String s) => s.trim().isNotEmpty)
            .map((s) => normalizeOutput(s))
            .toList();

        final suggestionMatch = RegExp(r'SUGGESTION:(.*)', caseSensitive: false, dotAll: true).firstMatch(raw);
        String suggestion = normalizeOutput(suggestionMatch?.group(1) ?? "Eat mindfully.");

        return SnackableResult(status: status, reasons: reasons, suggestion: suggestion);
      } catch (e) {
        return SnackableResult(status: "MODERATE", reasons: ["Data unclear"], suggestion: "Review capture settings.");
      }
    },
    postProcess: (parsed) async {
      const suspects = ["sugar", "palm oil", "glucose syrup", "msg", "artificial"];
      final rawText = parsed.toString().toLowerCase();
      
      bool foundSuspect = false;
      for (var s in suspects) {
        if (rawText.contains(s)) {
          parsed.status = "BAD";
          parsed.reasons.add("Detected potentially harmful: $s");
          foundSuspect = true;
        }
      }

      parsed.confidence = foundSuspect ? 0.9 : (parsed.reasons.any((String r) => r.toLowerCase().contains("natural")) ? 0.8 : 0.6);
      parsed.confidenceLabel = getConfidenceLabel(parsed.confidence);
      parsed.verdictLabel = getSnackableVerdict(parsed.status);
      // Removed take(3) to show full model response
      parsed.reasons = (parsed.reasons as List).cast<String>().toList();
      return parsed;
    },
    validate: (parsed) {
      const valid = ["GOOD", "MODERATE", "BAD"];
      if (!valid.contains(parsed.status)) parsed.status = "MODERATE";
      if (parsed.reasons.isEmpty) parsed.reasons.add("Limited dataset for categorization.");
      return parsed;
    },
  ),
  'slay': TraitLogic(
    preProcess: optimizeImage,
    parse: (raw) {
      if (raw.contains("ERROR_FALLBACK")) {
        return SlayResult(score: 5, suggestions: [raw.split(": ").last], nextStep: "Try again.", nextLevelSuggestion: "N/A");
      }

      try {
        final scoreMatch = RegExp(r'STYLE_SCORE:\s*(\d+)').firstMatch(raw);
        final score = int.tryParse(scoreMatch?.group(1) ?? '5') ?? 5;

        final suggestionsMatch = RegExp(r'SUGGESTIONS:(.*?)(NEXT_STEP:|$)', caseSensitive: false, dotAll: true).firstMatch(raw);
        final suggestions = (suggestionsMatch?.group(1) ?? '')
            .split('-')
            .where((String s) => s.trim().isNotEmpty)
            .map((s) => normalizeOutput(s))
            .toList();

        final nextStepMatch = RegExp(r'NEXT_STEP:(.*?)(NEXT_LEVEL:|$)', caseSensitive: false, dotAll: true).firstMatch(raw);
        final nextStep = normalizeOutput(nextStepMatch?.group(1) ?? "Keep refining your look.");

        final nextLevelMatch = RegExp(r'NEXT_LEVEL:(.*)', caseSensitive: false, dotAll: true).firstMatch(raw);
        final nextLevel = normalizeOutput(nextLevelMatch?.group(1) ?? nextStep);

        return SlayResult(score: score, suggestions: suggestions, nextStep: nextStep, nextLevelSuggestion: nextLevel);
      } catch (e) {
        return SlayResult(score: 5, suggestions: ["Visual data incomplete"], nextStep: "Capture again.", nextLevelSuggestion: "Maintain grooming.");
      }
    },
    postProcess: (parsed) async {
      try {
        final storage = TraitStorageService();
        final history = await storage.getAll();
        final lastSlayResult = history.firstWhere(
          (SavedScan h) => h.traitId == "slay", 
          orElse: () => const SavedScan(date: '', traitId: '', traitName: '', result: '', imagePath: '')
        );

        if (lastSlayResult.date.isNotEmpty) {
          final lastScoreMatch = RegExp(r'Score:\s*(\d+)').firstMatch(lastSlayResult.result);
          final lastScore = int.tryParse(lastScoreMatch?.group(1) ?? '0') ?? 0;
          if (lastScore > 0) {
            parsed.delta = parsed.score - lastScore;
            if (parsed.delta! > 0) {
              parsed.improvementReason = "Improved grooming and structure";
            } else if (parsed.delta == 0) {
              parsed.improvementReason = "No visible change";
            } else {
              parsed.improvementReason = "Slight decline in presentation";
            }
          }
        }
      } catch (_) {}

      parsed.identityLabel = getSlayIdentity(parsed.score);
      // Removed take(3) to show full model response
      parsed.suggestions = (parsed.suggestions as List).cast<String>().toList();
      return parsed;
    },
    validate: (parsed) {
      parsed.score = parsed.score.clamp(1, 10);
      if (parsed.suggestions.isEmpty) parsed.suggestions.add("Keep exploring personal styles.");
      return parsed;
    },
  ),
  'decoded': TraitLogic(
    preProcess: optimizeImage,
    parse: (raw) {
      if (raw.contains("ERROR_FALLBACK")) return raw.split(": ").last;
      return normalizeOutput(raw);
    },
    validate: (parsed) => (parsed as String).isEmpty ? "Vision data not decoded." : parsed,
  ),
};

// Fallback pipelines for first launch/offline
final List<TraitPipeline<dynamic>> fallbackPipelines = [
  TraitPipeline<SnackableResult>(
    info: const Trait(
      id: "snackable",
      name: "Snackable",
      promptTemplate: "Analyze the food in the image. Identify if it is GOOD, MODERATE, or BAD for health.",
    ),
    promptTemplate: "Analyze the food in the image. Identify if it is GOOD, MODERATE, or BAD for health.",
    preProcess: traitLogicRegistry['snackable']!.preProcess,
    parse: (raw) => traitLogicRegistry['snackable']!.parse(raw) as SnackableResult,
    postProcess: (parsed) async => await traitLogicRegistry['snackable']!.postProcess!(parsed) as SnackableResult,
    validate: (parsed) => traitLogicRegistry['snackable']!.validate(parsed) as SnackableResult,
  ),
  // Add others here or rely on the provider to stitch them from the registry
];
