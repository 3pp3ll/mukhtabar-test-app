import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const TodoApp());

/// نموذج المهمة.
class Task {
  Task({required this.id, required this.title, this.done = false});

  final String id;
  final String title;
  bool done;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        done: json['done'] as bool? ?? false,
      );
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مهامي',
      debugShowCheckedModeBanner: false,
      // اللغة العربية تضبط اتجاه RTL تلقائياً.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const TodoPage(),
    );
  }
}

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  static const String _storageKey = 'tasks';

  final TextEditingController _controller = TextEditingController();

  List<Task> _tasks = <Task>[];
  bool _loading = true;
  SharedPreferences? _prefs;

  // سلسلة الحفظ: تضمن أن تُكتب النسخ بترتيب التعديلات.
  Future<void> _pending = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    var tasks = <Task>[];
    var failed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        tasks = (jsonDecode(raw) as List)
            .map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {
      // عند الفشل نبدأ بقائمة فارغة دون الكتابة فوق التخزين.
      tasks = <Task>[];
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
    if (failed) _notify('تعذّر تحميل المهام المحفوظة');
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) {
      _notify('تعذّر حفظ المهام');
      return;
    }
    // نلتقط نسخة JSON لحظة التعديل.
    final snapshot = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    _pending = _pending.then((_) async {
      try {
        final ok = await prefs.setString(_storageKey, snapshot);
        if (!ok) _notify('تعذّر حفظ المهام');
      } catch (_) {
        _notify('تعذّر حفظ المهام');
      }
    });
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _add() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _tasks.add(
        Task(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title,
        ),
      );
    });
    _controller.clear();
    _save();
  }

  void _toggle(Task task, bool value) {
    setState(() => task.done = value);
    _save();
  }

  void _remove(Task task) {
    setState(() => _tasks.removeWhere((t) => t.id == task.id));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مهامي'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildInput(),
                  Expanded(
                    child: _tasks.isEmpty ? _buildEmpty() : _buildList(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(),
              decoration: const InputDecoration(
                hintText: 'أضف مهمة جديدة',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.checklist_rounded, size: 64, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            'لا توجد مهام بعد',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return CheckboxListTile(
          key: ValueKey<String>(task.id),
          value: task.done,
          onChanged: (value) => _toggle(task, value ?? false),
          // في الواجهة العربية يظهر المربع على اليمين.
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.done ? TextDecoration.lineThrough : null,
              color: task.done ? scheme.outline : null,
            ),
          ),
          secondary: IconButton(
            tooltip: 'حذف المهمة',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _remove(task),
          ),
        );
      },
    );
  }
}
