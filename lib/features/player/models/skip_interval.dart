enum SkipType { op, ed, recap }

class SkipInterval {
  final SkipType type;
  final double start;
  final double end;

  const SkipInterval({required this.type, required this.start, required this.end});

  String get label => switch (type) {
        SkipType.op => 'Salta sigla',
        SkipType.ed => 'Salta ending',
        SkipType.recap => 'Salta recap',
      };
}
