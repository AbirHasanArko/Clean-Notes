import 'package:flutter_test/flutter_test.dart';

import 'package:clean_notes/models/note.dart';

void main() {
  group('Note.empty()', () {
    test('returns a blank, untitled note', () {
      final note = Note.empty();
      expect(note.id, isEmpty);
      expect(note.title, isEmpty);
      expect(note.description, isEmpty);
    });
  });

  group('Note.copyWith', () {
    test('only swaps the fields you pass', () {
      final base = Note.empty().copyWith(title: 'Groceries');
      final updated = base.copyWith(description: 'Milk, eggs');

      expect(updated.title, 'Groceries');
      expect(updated.description, 'Milk, eggs');
      expect(updated.id, base.id);
    });
  });
}
