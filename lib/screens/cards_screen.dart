import 'package:flutter/material.dart';

import '../data/catalog_repository.dart';
import '../models/card_item.dart';
import '../models/folder.dart';
import '../widgets/card_image.dart';
import 'card_form_screen.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({
    super.key,
    required this.repository,
    required this.folder,
  });

  final CatalogRepository repository;
  final Folder folder;

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  List<CardItem> _cards = [];
  bool _busy = true;
  bool _loaded = false;
  String? _readError;
  String? _message;

  int get _folderId => widget.folder.id!;

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
      final cards = await widget.repository.getCards(_folderId);
      if (!mounted) return false;
      setState(() {
        _cards = cards;
        _readError = null;
        _loaded = true;
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('Card read failed: $error\n$stackTrace');
      if (!mounted) return false;
      setState(() {
        _readError = 'Could not read cards. Tap refresh to try again.';
      });
      return false;
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });
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

  Future<void> _openForm({CardItem? card}) async {
    if (_busy) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => CardFormScreen(
          repository: widget.repository,
          initialFolderId: _folderId,
          card: card,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _message = result ??
          (card == null
              ? 'Add cancelled. Nothing was saved.'
              : 'Edit of card ID ${card.id} cancelled. Nothing was changed.');
    });
    await _refresh();
  }

  Future<void> _deleteCard(CardItem card) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text('Delete "${card.title}" (ID ${card.id})?'),
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
        _message = 'Delete of card ID ${card.id} cancelled. '
            'Nothing was changed.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final deleted = await widget.repository.deleteCard(card.id!);
      final ok = await _fetch();
      if (!mounted) return;
      setState(() {
        if (deleted == 0) {
          _message = 'Card ID ${card.id} no longer exists. Nothing was deleted.';
        } else if (!ok) {
          _message = 'Deleted, but refresh failed. Tap refresh.';
        } else {
          _message = 'Deleted card "${card.title}" (ID ${card.id}). '
              'Rows affected: $deleted.';
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Delete card failed: $error\n$stackTrace');
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

  Widget _buildList() {
    if (!_loaded && _readError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_readError != null) {
      return Center(child: Text('Error: $_readError'));
    }
    if (_cards.isEmpty) {
      return const Center(
        child: Text('This folder has no cards yet. Tap + to add one.'),
      );
    }
    return ListView.builder(
      itemCount: _cards.length,
      itemBuilder: (context, index) {
        final card = _cards[index];
        final notes = card.notes.isEmpty ? '' : '   ${card.notes}';
        return Card(
          child: ListTile(
            leading: CardImage(imageRef: card.imageRef, suit: card.suit),
            title: Text(card.title),
            subtitle: Text(
              'ID: ${card.id}   ${CardItem.symbolFor(card.suit)} '
              '${CardItem.labelFor(card.suit)}$notes',
            ),
            onTap: _busy ? null : () => _openForm(card: card),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit),
                  onPressed: _busy ? null : () => _openForm(card: card),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete),
                  onPressed: _busy ? null : () => _deleteCard(card),
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
        title: Text('${widget.folder.name} (ID $_folderId)'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add card',
        onPressed: _busy ? null : () => _openForm(),
        child: const Icon(Icons.add),
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
              'Cards in this folder: ${_cards.length}',
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
