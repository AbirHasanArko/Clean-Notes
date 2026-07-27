import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/notes_service.dart';
import '../services/subscription_service.dart';
import '../widgets/note_tile.dart';
import 'note_editor_screen.dart';

/// Displays every note stored in Firestore. The list is a live stream, so
/// adds/edits/deletes made elsewhere show up automatically.
class NotesListScreen extends StatelessWidget {
  const NotesListScreen({
    required this.service,
    this.subscriptionService,
    this.onLogout,
    super.key,
  });

  final NotesService service;

  /// Optional — when provided, the AppBar overflow shows an "Unsubscribe
  /// & log out" action.
  final SubscriptionService? subscriptionService;

  /// Invoked after a successful logout so the parent gate can re-mount.
  final Future<void> Function()? onLogout;

  Future<void> _openEditor(BuildContext context, {Note? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorScreen(
          service: service,
          existing: existing,
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final sub = subscriptionService;
    final logout = onLogout;
    if (sub == null || logout == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final stored = await sub.loadStored();

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsubscribe & log out?'),
        content: const Text(
          'Your BDApps subscription will be cancelled and you will be '
          'signed out of Clean Notes. You can re-subscribe at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unsubscribe'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Try to cancel on BDApps. We still complete the local logout if this
    // fails so the user isn't stranded, but we surface the failure so
    // they know their BDApps subscription may still be active.
    if (stored != null) {
      try {
        await sub.unsubscribe(stored);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Could not cancel BDApps subscription: $e. '
              'You have still been logged out locally.',
            ),
          ),
        );
      }
    }
    await sub.clearStored();

    if (!navigator.mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('You have been logged out.')),
    );

    await logout();
  }

  Future<void> _confirmDelete(BuildContext context, Note note) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text(
          '“${note.title}” will be removed permanently. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await service.deleteNote(note.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Note deleted')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete note: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [
          IconButton(
            tooltip: 'Unsubscribe & log out',
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Note>>(
        stream: service.getNotesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: () {
                // The stream itself cannot be restarted cheaply. Easiest
                // workaround is to navigate away and back, which rebuilds
                // the widget and re-subscribes.
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => NotesListScreen(
                      service: service,
                      subscriptionService: subscriptionService,
                      onLogout: onLogout,
                    ),
                  ),
                  (_) => false,
                );
              },
            );
          }

          final notes = snapshot.data ?? const <Note>[];

          if (notes.isEmpty) {
            return _EmptyState(
              onAdd: () => _openEditor(context),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return NoteTile(
                note: note,
                onEdit: () => _openEditor(context, existing: note),
                onDelete: () => _confirmDelete(context, note),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add note'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No notes yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to create your first note.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add note'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              'Could not load notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
