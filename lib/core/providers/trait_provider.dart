import 'package:arjgo/core/services/trait_engine.dart';
import 'package:arjgo/core/services/trait_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final traitSyncProvider = Provider((ref) => TraitSyncService());

final dynamicTraitsProvider = FutureProvider<List<TraitPipeline<dynamic>>>((ref) async {
  final syncService = ref.read(traitSyncProvider);
  
  // 1. Get cached traits (Hive)
  final cached = await syncService.getCachedTraits();
  
  if (cached.isEmpty) {
    return fallbackPipelines;
  }

  // 3. Map cached traits to pipelines using the Logic Registry
  return cached.map((trait) {
    final logic = traitLogicRegistry[trait.id];
    
    // If we have logic for this trait, use it. 
    // If not (e.g. brand new trait), we can provide a default lightweight handler
    if (logic != null) {
      return TraitPipeline(
        info: trait,
        promptTemplate: trait.promptTemplate,
        preProcess: logic.preProcess,
        parse: logic.parse,
        postProcess: logic.postProcess,
        validate: logic.validate,
      );
    } else {
      // Default lightweight handler for unknown future traits
      return TraitPipeline<String>(
        info: trait,
        promptTemplate: trait.promptTemplate,
        preProcess: optimizeImage,
        parse: (raw) => raw,
        validate: (parsed) => parsed,
      );
    }
  }).toList();
});
