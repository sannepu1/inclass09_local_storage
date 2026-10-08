import 'package:flutter/material.dart';

import '../data/catalog_repository.dart';
import '../models/card_item.dart';
import '../models/folder.dart';
import '../widgets/card_image.dart';

/// One form for both Add and Edit.
/// Pops with a result message on a successful save, or null on Cancel.
class CardFormScreen extends StatefulWidget {
  const CardFormScreen({
    super.key,
    required this.repository,
    required this.initialFolderId,
    this.card,
  });

  final CatalogRepository repository;
  final int initialFolderId;

  /// null means Add mode.
  final CardItem? card;

  @override
  State<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends State<CardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController =
      TextEditingController(text: widget.card?.title ?? '');
  late final TextEditingController _notesController =
      TextEditingController(text: widget.card?.notes ?? '');
  late final TextEditingController _imageController =
      TextEditingController(text: widget.card?.imageRef ?? '');

  List<Folder> _folders = [];
  int? _folderId;
  String? _suit;
  bool _busy = true;
  String? _error;

  bool get _editing => widget.card != null;

  @override
  void initState() {
    super.initState();
    _folderId = widget.card?.folderId ?? widget.initialFolderId;
    _suit = widget.card?.suit;
    _loadFolders();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    try {
      final folders = await widget.repository.getFoldersWithCounts();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        // Only keep a folder id that really exists.
        if (!folders.any((f) => f.id == _folderId)) {
          _folderId = null;
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Folder list failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _error = 'Could not load folders. Go back and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _error = 'Nothing was saved. Fix the fields marked above.';
      });
      return;
    }
    final imageText = _imageController.text.trim();
    final card = CardItem(
      id: widget.card?.id,
      title: _titleController.text.trim(),
      suit: _suit!,
      notes: _notesController.text.trim(),
      imageRef: imageText.isEmpty ? null : imageText,
      folderId: _folderId!,
    );

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String result;
      if (_editing) {
        final updated = await widget.repository.updateCard(card);
        if (updated == 0) {
          if (!mounted) return;
          setState(() {
            _error = 'Card ID ${card.id} no longer exists. Nothing was updated.';
          });
          return;
        }
        result = 'Updated card ID ${card.id}. Rows affected: $updated.';
      } else {
        final id = await widget.repository.insertCard(card);
        result = 'Added card "${card.title}" with ID $id.';
      }
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error, stackTrace) {
      debugPrint('Save card failed: $error\n$stackTrace');
      if (!mounted) return;
      // Keep the user's input so they can try again.
      setState(() {
        _error = 'Save failed and nothing was written. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit card ID ${widget.card!.id}' : 'Add card'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_busy) const LinearProgressIndicator(),
              TextFormField(
                controller: _titleController,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a title. It cannot be blank.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey('folders-${_folders.length}'),
                initialValue: _folderId,
                decoration: const InputDecoration(labelText: 'Folder'),
                items: [
                  for (final folder in _folders)
                    DropdownMenuItem(
                      value: folder.id,
                      child: Text('${folder.name} (ID ${folder.id})'),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                          _folderId = value;
                        }),
                validator: (value) => value == null ? 'Pick a folder.' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _suit,
                decoration: const InputDecoration(labelText: 'Suit'),
                items: [
                  for (final suit in CardItem.suits)
                    DropdownMenuItem(
                      value: suit,
                      child: Text(
                        '${CardItem.symbolFor(suit)} ${CardItem.labelFor(suit)}',
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                          _suit = value;
                        }),
                validator: (value) => (value == null ||
                        !CardItem.suits.contains(value))
                    ? 'Pick a suit.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Image reference (optional)',
                  helperText: 'An https:// URL or an assets/ path. '
                      'Leave blank for the suit symbol.',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Preview: '),
                  CardImage(
                    imageRef: _imageController.text,
                    suit: _suit ?? '',
                    size: 64,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_editing ? 'Save changes' : 'Add card'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
