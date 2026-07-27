import 'package:cloud_firestore/cloud_firestore.dart';

/// A single note stored in Cloud Firestore.
///
/// Firestore document shape:
/// ```
/// notes/{noteId}
///   ownerId:      String  // Firebase Auth uid of the creator
///   title:        String
///   description:  String
///   createdAt:    Timestamp
///   updatedAt:    Timestamp
/// ```
class Note {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates an in-memory `Note` that has not yet been persisted.
  /// Useful when opening the Add screen. [ownerId] must be supplied by the
  /// service layer when the note is actually written to Firestore.
  factory Note.empty({String ownerId = ''}) => Note(
        id: '',
        ownerId: ownerId,
        title: '',
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  /// Builds a `Note` from a Firestore [DocumentSnapshot].
  factory Note.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Note(
      id: doc.id,
      ownerId: (data['ownerId'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
    );
  }

  /// Returns the map that will be written to Firestore.
  /// `id` is the document id and is intentionally excluded — Firestore
  /// owns the document identity. `ownerId` is always included so the
  /// security rules can verify it matches the requester's uid.
  Map<String, dynamic> toFirestore() => {
        'ownerId': ownerId,
        'title': title,
        'description': description,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  Note copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
