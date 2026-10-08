import 'package:flutter/material.dart';

import 'data/catalog_repository.dart';
import 'database_helper.dart';
import 'screens/folders_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final helper = DatabaseHelper();

  try {
    await helper.init();
  } catch (e) {
    debugPrint('Database init failed: $e');
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Could not open local storage. Restart the app.'),
        ),
      ),
    ));
    return;
  }

  runApp(DirectoryApp(helper: helper));
}

class DirectoryApp extends StatelessWidget {
  const DirectoryApp({super.key, required this.helper});

  final DatabaseHelper helper;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card Catalogue',
      home: FoldersScreen(
        repository: CatalogRepository(helper.db),
        helper: helper,
      ),
    );
  }
}

class RosterScreen extends StatefulWidget {
  const RosterScreen({super.key, required this.helper});

  final DatabaseHelper helper;

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  List<Map<String, dynamic>> _rows = [];

  int _count = 0;
  int? _editingId;

  bool _busy = true;
  bool _readFailed = false;

  String? _message;

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadRows() async {
    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) return;

      setState(() {
        _rows = rows;
        _count = count;
        _busy = false;
        _readFailed = false;
      });
    } catch (e) {
      debugPrint('Roster read failed: $e');
      if (!mounted) return;

      setState(() {
        _busy = false;
        _readFailed = true;
        _message = 'Could not read the roster. Tap Refresh to try again.';
      });
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) return;

      setState(() {
        _rows = rows;
        _count = count;
        _busy = false;
        _readFailed = false;
        _message = 'Refreshed. Records: $count.';
      });
    } catch (e) {
      debugPrint('Roster read failed: $e');
      if (!mounted) return;

      setState(() {
        _busy = false;
        _readFailed = true;
        _message = 'Could not read the roster. Tap Refresh to try again.';
      });
    }
  }

  void _clearForm() {
    _nameController.clear();
    _ageController.clear();
    _formKey.currentState?.reset();
    _editingId = null;
  }

  Future<void> _save() async {
    if (_busy) return;

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _message = 'Nothing was saved. Fix the field marked above.';
      });
      return;
    }

    String name = _nameController.text.trim();
    int age = int.parse(_ageController.text.trim());

    setState(() {
      _busy = true;
      _message = null;
    });

    String result;

    try {
      if (_editingId == null) {
        final id = await widget.helper.insert({
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        result = 'Added $name with ID $id.';
      } else {
        int id = _editingId!;

        final updated = await widget.helper.update({
          DatabaseHelper.columnId: id,
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        if (updated > 0) {
          result = 'Updated ID $id. Rows affected: $updated.';
        } else {
          result =
              'ID $id no longer exists. Rows affected: 0. Nothing was updated.';
        }
      }
    } catch (e) {
      debugPrint('Save failed: $e');
      if (!mounted) return;

      setState(() {
        _busy = false;
        _message = 'Save failed and nothing was written. '
            'Your input is still in the form, so you can try again.';
      });
      return;
    }

    // The write worked, so clear the form even if the refresh below fails.
    _clearForm();

    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) return;

      setState(() {
        _rows = rows;
        _count = count;
        _busy = false;
        _readFailed = false;
        _message = result;
      });
    } catch (e) {
      debugPrint('Refresh after save failed: $e');
      if (!mounted) return;

      setState(() {
        _busy = false;
        _message = 'Saved, but refresh failed. Tap Refresh.';
      });
    }
  }

  void _startEdit(Map<String, dynamic> row) {
    if (_busy) return;

    int id = row[DatabaseHelper.columnId];

    setState(() {
      _editingId = id;
      _nameController.text = row[DatabaseHelper.columnName].toString();
      _ageController.text = row[DatabaseHelper.columnAge].toString();

      _message = 'Editing ID $id. Save to keep changes or Cancel edit.';
    });
  }

  void _cancelEdit() {
    if (_busy) return;

    int? id = _editingId;

    setState(() {
      _clearForm();
      _message = 'Edit of ID $id cancelled. Nothing was changed.';
    });
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (_busy) return;

    int id = row[DatabaseHelper.columnId];
    String name = row[DatabaseHelper.columnName];

    bool? answer = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete guest?'),
          content: Text('Delete ID $id ($name) from the roster?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (answer != true) {
      setState(() {
        _message = 'Delete of ID $id cancelled. Nothing was changed.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    int deleted;

    try {
      deleted = await widget.helper.delete(id);
    } catch (e) {
      debugPrint('Delete failed: $e');
      if (!mounted) return;

      setState(() {
        _busy = false;
        _message = 'Delete failed and nothing was removed. Try again.';
      });
      return;
    }

    if (_editingId == id) {
      _clearForm();
    }

    String result;
    if (deleted > 0) {
      result = 'Deleted ID $id ($name). Rows affected: $deleted.';
    } else {
      result = 'ID $id no longer exists. Rows affected: 0. Nothing was deleted.';
    }

    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) return;

      setState(() {
        _rows = rows;
        _count = count;
        _busy = false;
        _readFailed = false;
        _message = result;
      });
    } catch (e) {
      debugPrint('Refresh after delete failed: $e');
      if (!mounted) return;

      setState(() {
        _busy = false;
        _message = 'Deleted, but refresh failed. Tap Refresh.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool editing = _editingId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Festival Roster'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Guest name',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a name. It cannot be blank.';
                      }

                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _ageController,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Age (whole number, 0 to 130)',
                    ),
                    validator: (value) {
                      String text = value?.trim() ?? '';

                      if (text.isEmpty) {
                        return 'Enter an age.';
                      }

                      int? age = int.tryParse(text);

                      if (age == null) {
                        return 'Age must be a whole number, like 21.';
                      }

                      if (age < 0 || age > 130) {
                        return 'Age must be from 0 to 130.';
                      }

                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _save,
                  child: Text(
                    editing ? 'Save ID $_editingId' : 'Add',
                  ),
                ),
                OutlinedButton(
                  onPressed: (_busy || !editing) ? null : _cancelEdit,
                  child: const Text('Cancel edit'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _refresh,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_busy) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_message!),
              ),
            const SizedBox(height: 4),
            Text(
              'Records: $_count',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _busy && _rows.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _readFailed
                      ? const Center(
                          child: Text('Error reading the roster. Tap Refresh.'),
                        )
                  : _rows.isEmpty
                      ? const Center(
                          child: Text(
                            'No festival guests yet. The hayride is empty.',
                          ),
                        )
                      : ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (context, index) {
                            var row = _rows[index];

                            var id = row[DatabaseHelper.columnId];
                            var name = row[DatabaseHelper.columnName];
                            var age = row[DatabaseHelper.columnAge];

                            return Card(
                              child: ListTile(
                                title: Text('$name'),
                                subtitle: Text(
                                  'ID: $id   Age: $age',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () {
                                              _startEdit(row);
                                            },
                                      child: const Text('Edit'),
                                    ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () {
                                              _delete(row);
                                            },
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}