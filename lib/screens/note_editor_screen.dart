import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/notes_service.dart';

/// Add or edit a note. The same screen handles both flows to keep the UX
/// consistent and the code path single-sourced.
///
/// Pass [existing] to switch into edit mode. Otherwise the screen
/// creates a new document.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    required this.service,
    this.existing,
    super.key,
  });

  final NotesService service;
  final Note? existing;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.existing?.description ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      if (_isEditing) {
        await widget.service.updateNote(
          widget.existing!.copyWith(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
          ),
        );
      } else {
        await widget.service.addNote(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
        );
      }

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Note updated' : 'Note added'),
          duration: const Duration(seconds: 2),
        ),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to save note: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit note' : 'New note'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Save',
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    if (value.trim().length > 80) {
                      return 'Title must be 80 characters or fewer';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _descriptionFocusNode.requestFocus(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  focusNode: _descriptionFocusNode,
                  maxLines: 8,
                  minLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != null && value.trim().length > 1000) {
                      return 'Description must be 1000 characters or fewer';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: Text(_isEditing ? 'Update note' : 'Save note'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
