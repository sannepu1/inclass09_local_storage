import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../data/catalog_repository.dart';
import '../database_helper.dart';
import '../main.dart';
import '../models/folder.dart';
import 'cards_screen.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({
    super.key,
    required this.repository,
    required this.helper,
  });

  final CatalogRepository repository;
  final DatabaseHelper helper;

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  List<Folder> _folders = [];
  bool _busy = true;
  bool _loaded = false;
  String? _readError;
  String? _message;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    try {
      await _fetch();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<bool> _fetch() async {
    try {
      final folders = await widget.repository.getFoldersWithCounts();
      if (!mounted) return false;
      setState(() {
        _folders = folders;
        _readError = null;
        _loaded = true;
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('Folder read failed: $error\n$stackTrace');
      if (!mounted) return false;
      setState(() {
        _readError = 'Could not read folders. Tap refresh to try again.';
      });
      return false;
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final ok = await _fetch();
      if (ok && mounted) {
        setState(() {
          _message = 'Refreshed. Folders: ${_folders.length}.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _addFolder() async {
    if (_busy) return;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _FolderNameDialog(title: 'New folder'),
    );
    if (name == null || !mounted) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final id = await widget.repository.insertFolder(name);
      final ok = await _fetch();
      if (!mounted) return;
      setState(() {
        _message = ok
            ? 'Added folder "$name" with ID $id.'
            : 'Saved, but refresh failed. Tap refresh.';
      });
    } on DatabaseException catch (error) {
      debugPrint('Insert folder failed: $error');
      if (!mounted) return;
      setState(() {
        _message = error.isUniqueConstraintError()
            ? 'A folder named "$name" already exists. Nothing was saved.'
            : 'Could not save the folder. Nothing was saved.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _renameFolder(Folder folder) async {
    if (_busy) return;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _FolderNameDialog(
        title: 'Rename folder (ID ${folder.id})',
        initialName: folder.name,
      ),
    );
    if (name == null || !mounted) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final updated = await widget.repository.renameFolder(folder.id!, name);
      final ok = await _fetch();
      if (!mounted) return;
      setState(() {
        if (updated == 0) {
          _message = 'Folder ID ${folder.id} no longer exists. Nothing changed.';
        } else if (!ok) {
          _message = 'Renamed, but refresh failed. Tap refresh.';
        } else {
          _message = 'Renamed folder ID ${folder.id}. Rows affected: $updated.';
        }
      });
    } on DatabaseException catch (error) {
      debugPrint('Rename folder failed: $error');
      if (!mounted) return;
      setState(() {
        _message = error.isUniqueConstraintError()
            ? 'A folder named "$name" already exists. Nothing changed.'
            : 'Could not rename the folder. Nothing changed.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _deleteFolder(Folder folder) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'Delete "${folder.name}" (ID ${folder.id})? '
          'This also deletes its ${folder.cardCount} card(s).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() {
        _message = 'Delete of folder "${folder.name}" cancelled. '
            'Nothing was changed.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final deleted = await widget.repository.deleteFolder(folder.id!);
      final ok = await _fetch();
      if (!mounted) return;
      setState(() {
        if (deleted == 0) {
          _message = 'Folder ID ${folder.id} no longer exists. '
              'Nothing was deleted.';
        } else if (!ok) {
          _message = 'Deleted, but refresh failed. Tap refresh.';
        } else {
          _message = 'Deleted folder "${folder.name}" (ID ${folder.id}). '
              'Rows affected: $deleted. Its cards were removed by cascade.';
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Delete folder failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _message = 'Delete failed and nothing was removed. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _openFolder(Folder folder) async {
    if (_busy) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CardsScreen(
          repository: widget.repository,
          folder: folder,
        ),
      ),
    );
    if (!mounted) return;
    // Card counts may have changed while we were away.
    await _refresh();
  }

  void _openPartOne() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RosterScreen(helper: widget.helper),
      ),
    );
  }

  Widget _buildList() {
    if (!_loaded && _readError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_readError != null) {
      return Center(child: Text('Error: $_readError'));
    }
    if (_folders.isEmpty) {
      return const Center(
        child: Text('No folders yet. Tap + to make your first drawer.'),
      );
    }
    return ListView.builder(
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final folder = _folders[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.folder),
            title: Text(folder.name),
            subtitle: Text('ID: ${folder.id}   Cards: ${folder.cardCount}'),
            onTap: _busy ? null : () => _openFolder(folder),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Rename',
                  icon: const Icon(Icons.edit),
                  onPressed: _busy ? null : () => _renameFolder(folder),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete),
                  onPressed: _busy ? null : () => _deleteFolder(folder),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Catalogue'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _refresh,
          ),
          TextButton(
            onPressed: _openPartOne,
            child: const Text('Part I guests'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add folder',
        onPressed: _busy ? null : _addFolder,
        child: const Icon(Icons.create_new_folder),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_message!),
              ),
            Text(
              'Folders: ${_folders.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }
}

/// Small dialog that asks for a folder name and won't accept a blank one.
class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({required this.title, this.initialName = ''});

  final String title;
  final String initialName;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Enter a folder name. It cannot be blank.';
      });
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Folder name',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
