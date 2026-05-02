class Trait {
  final String id;
  final String name;
  final String promptTemplate;
  final Map<String, dynamic>? outputSchema;

  const Trait({
    required this.id,
    required this.name,
    required this.promptTemplate,
    this.outputSchema,
  });
}
