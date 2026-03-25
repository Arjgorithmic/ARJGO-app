import 'dart:io';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

// ── Model ────────────────────────────────────────────────────────────────────
class Skill {
  final String name;
  final String description;

  const Skill({required this.name, required this.description});
}

// ── Provider ─────────────────────────────────────────────────────────────────
final skillsProvider =
    AsyncNotifierProvider<SkillsNotifier, List<Skill>>(SkillsNotifier.new);

class SkillsNotifier extends AsyncNotifier<List<Skill>> {
  @override
  Future<List<Skill>> build() async {
    return _loadFromAsset();
  }

  Future<List<Skill>> _loadFromAsset() async {
    try {
      final raw = await rootBundle.loadString('assets/skills/skill.md');
      return _parse(raw);
    } catch (_) {
      return [];
    }
  }

  List<Skill> _parse(String raw) {
    final skills = <Skill>[];
    final lines = raw.split('\n');
    String? currentName;
    final descBuf = StringBuffer();

    for (final line in lines) {
      if (line.startsWith('## ')) {
        if (currentName != null) {
          skills.add(Skill(name: currentName, description: descBuf.toString().trim()));
          descBuf.clear();
        }
        currentName = line.substring(3).trim();
      } else if (currentName != null && line.isNotEmpty) {
        if (descBuf.isNotEmpty) descBuf.write(' ');
        descBuf.write(line.trim());
      }
    }
    if (currentName != null) {
      skills.add(Skill(name: currentName, description: descBuf.toString().trim()));
    }
    return skills;
  }

  Future<void> addSkill({required String name, required String description}) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, Skill(name: name, description: description)]);
  }

  Future<bool> addSkillFromZip() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) return false;

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final appDir = await getApplicationDocumentsDirectory();
      final skillName = result.files.single.name.split('.').first;
      final skillDir = Directory('${appDir.path}/skills/$skillName');

      if (!skillDir.existsSync()) skillDir.createSync(recursive: true);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          File('${skillDir.path}/$filename')
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        }
      }

      // Add to list
      final current = state.valueOrNull ?? [];
      state = AsyncData([
        ...current,
        Skill(name: skillName, description: 'Imported skill package (${archive.length} files)'),
      ]);
      return true;
    } catch (e) {
      debugPrint('Error unzipping: $e');
      return false;
    }
  }
}

// ── Screen ───────────────────────────────────────────────────────────────────
class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillsAsync = ref.watch(skillsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Header
              Text(
                'Skills',
                style: GoogleFonts.dmSans(
                  fontSize: 36,
                  fontWeight: FontWeight.w200,
                  color: Theme.of(context).textTheme.headlineMedium?.color,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'YOUR LIBRARY',
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: AppColors.grey,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.archive_outlined, size: 20, color: AppColors.accent),
                    onPressed: () async {
                      final ok = await ref.read(skillsProvider.notifier).addSkillFromZip();
                      if (context.mounted && ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Skill package imported')),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // List
              Expanded(
                child: skillsAsync.when(
                  loading: () => const Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.2,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  error: (e, _) => Text('Failed to load skills.',
                      style: GoogleFonts.dmSans(color: AppColors.grey)),
                  data: (skills) => skills.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'No skills yet.',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                  color: AppColors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: skills.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, i) {
                            final skill = skills[i];
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    skill.name,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  if (skill.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      skill.description,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w300,
                                        color: AppColors.grey,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
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

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72, right: 8),
        child: GestureDetector(
          onTap: () => _showAddSkill(context, ref),
          child: Text(
            '+',
            style: GoogleFonts.dmSans(
              fontSize: 32,
              fontWeight: FontWeight.w300,
              color: AppColors.accent,
              height: 1.0,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showAddSkill(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 32,
          right: 32,
          top: 32,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ADD SKILL',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.grey,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'SKILL NAME'),
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w300,
                color: Theme.of(ctx).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'DESCRIPTION',
                alignLabelWithHint: true,
              ),
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: Theme.of(ctx).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                ref.read(skillsProvider.notifier).addSkill(
                      name: name,
                      description: descCtrl.text.trim(),
                    );
                Navigator.pop(ctx);
              },
              child: Text(
                'ADD',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 2.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
