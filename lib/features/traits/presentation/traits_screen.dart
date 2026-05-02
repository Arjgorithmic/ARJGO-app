import 'dart:convert';
import 'dart:io';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:arjgo/core/models/trait.dart';
import 'package:arjgo/core/services/trait_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:arjgo/core/providers/trait_provider.dart';

// ── Provider (Simplified for Dynamic Loading) ────────────────────────────────
final traitsProvider = FutureProvider<List<Trait>>((ref) async {
  final pipelines = await ref.watch(dynamicTraitsProvider.future);
  return pipelines.map((p) => p.info).toList();
});

// ── Screen ───────────────────────────────────────────────────────────────────
class TraitsScreen extends ConsumerWidget {
  const TraitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traitsAsync = ref.watch(traitsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Traits',
                    style: GoogleFonts.dmSans(
                      fontSize: 36,
                      fontWeight: FontWeight.w200,
                      color: Theme.of(context).textTheme.headlineLarge?.color,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Syncing traits...'), duration: Duration(seconds: 1)),
                      );
                      await ref.read(traitSyncProvider).syncTraits();
                      ref.invalidate(dynamicTraitsProvider);
                    },
                    icon: const Icon(Icons.sync, size: 20, color: AppColors.accent),
                    tooltip: 'Sync with Cloud',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'TRAIT LIBRARY',
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: traitsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 1)),
                  error: (e, _) => const Text('Error loading traits'),
                  data: (traits) => traits.isEmpty
                      ? const Center(child: Text('No traits available'))
                      : ListView.separated(
                          itemCount: traits.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, i) {
                            final trait = traits[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                trait.id.toUpperCase(),
                                style: GoogleFonts.dmSans(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accent.withOpacity(0.5),
                                  letterSpacing: 2,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trait.name,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    trait.promptTemplate,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w300,
                                      color: AppColors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
