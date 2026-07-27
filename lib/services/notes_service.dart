import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';
import 'auth_service.dart';

/// Thin wrapper around the `notes` collection in Cloud Firestore.
///
/// All CRUD operations go through one place so the UI layer stays unaware
/// of Firestore APIs (easier to swap, mock or test).
///
/// Every operation is scoped to the authenticated user via [AuthService]:
/// reads filter by `ownerId == current uid`, and writes stamp the
/// `ownerId` on create. Combined with the per-document security rules
/// (`firestore.rules`), this guarantees that users can only see,
/// create, edit, and delete their own notes.
class NotesService {
  NotesService({
    required this.auth,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// The auth service used to resolve the current user's uid.
  final AuthService auth;

  final FirebaseFirestore _firestore;

  /// Path: `notes/{noteId}`.
  CollectionReference<Map<String, dynamic>> get _notesRef =>
      _firestore.collection('notes');

  /// Returns the signed-in user's uid. Throws [StateError] if no user is
  /// signed in — callers should ensure [AuthService.ensureSignedIn] has
  /// run before reaching this point.
  String get _uid {
    final uid = auth.currentUid;
    if (uid == null || uid.isEmpty) {
      throw StateError(
        'NotesService used before the user was signed in. '
        'Call AuthService.ensureSignedIn() first.',
      );
    }
    return uid;
  }

  /// Real-time stream of the *current user's* notes, ordered
  /// most-recently-updated first. [NotesListScreen] listens to this via
  /// `StreamBuilder`.
  ///
  /// The `where('ownerId', isEqualTo: uid)` + `orderBy('updatedAt')`
  /// query requires a composite index. See `firestore.indexes.json`.
  Stream<List<Note>> getNotesStream() {
    return _notesRef
        .where('ownerId', isEqualTo: _uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Note.fromFirestore).toList());
  }

  /// Creates a new note owned by the current user. Returns the generated
  /// document id. [createdAt] and [updatedAt] are stamped server-side by
  /// Firestore.
  Future<String> addNote({
    required String title,
    required String description,
  }) async {
    final now = Timestamp.now();
    final note = Note(
      id: '',
      ownerId: _uid,
      title: title.trim(),
      description: description.trim(),
      createdAt: now.toDate(),
      updatedAt: now.toDate(),
    );

    final docRef = await _notesRef.add(note.toFirestore());
    return docRef.id;
  }

  /// Updates an existing note. Only mutates `title`, `description`,
  /// and `updatedAt` — `createdAt` and `ownerId` must remain immutable.
  /// [note.ownerId] is preserved so a malicious caller cannot reassign
  /// ownership of an existing document.
  Future<void> updateNote(Note note) async {
    if (note.id.isEmpty) {
      throw ArgumentError('Cannot update a note without an id.');
    }
    final updated = note.copyWith(
      title: note.title.trim(),
      description: note.description.trim(),
      updatedAt: DateTime.now(),
    );

    await _notesRef.doc(note.id).update({
      'title': updated.title,
      'description': updated.description,
      'updatedAt': Timestamp.fromDate(updated.updatedAt),
    });
  }

  /// Deletes the note with the given id. The security rules ensure a
  /// user can only delete docs they own.
  Future<void> deleteNote(String id) async {
    if (id.isEmpty) {
      throw ArgumentError('Cannot delete a note without an id.');
    }
    await _notesRef.doc(id).delete();
  }
}
