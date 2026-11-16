import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// پانێلی ئەدمین: قبوڵکردن و هەڵوەشاندنەوەی بەکارهێنەران
/// پێویستی بە RLS هەیە (rls_approved.sql) تاکو تەنها ئەدمین بتوانێت نوێی بکاتەوە
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _db
          .from('profiles')
          .select('id, email, full_name, role, approved, created_at')
          .neq('role', 'admin')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() => _users = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'هەڵە لە هێنانی داتا. ئۆنلاین بە و دووبارە هەوڵبدەرەوە.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setApproved(Map<String, dynamic> user, bool value) async {
    if (!value) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('هەڵوەشاندنەوەی دەستپێگەیشتن'),
            content: Text('دەتەوێت دەستپێگەیشتنی ${user['email']} هەڵبوەشێنیتەوە؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('نەخێر')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('بەڵێ')),
            ],
          ),
        ),
      );
      if (ok != true) return;
    }
    try {
      await _db.from('profiles').update({'approved': value}).eq('id', user['id']);
      if (!mounted) return;
      setState(() => user['approved'] = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'قبوڵ کرا' : 'دەستپێگەیشتن هەڵوەشێنرایەوە')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نەتوانرا گۆڕانکاری بکرێت')),
      );
    }
  }

  List<Map<String, dynamic>> _filtered(bool approved) {
    final q = _query.trim().toLowerCase();
    return _users.where((u) {
      if ((u['approved'] == true) != approved) return false;
      if (q.isEmpty) return true;
      return '${u['email']} ${u['full_name']}'.toLowerCase().contains(q);
    }).toList();
  }

  Widget _list(bool approved) {
    final items = _filtered(approved);
    if (items.isEmpty) {
      return Center(child: Text(approved ? 'هیچ بەکارهێنەرێکی قبوڵکراو نییە' : 'هیچ داواکارییەک نییە'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final u = items[i];
          final name = (u['full_name'] ?? '').toString();
          return ListTile(
            leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?')),
            title: Text(name.isNotEmpty ? name : '(بێ ناو)'),
            subtitle: Text((u['email'] ?? '').toString()),
            trailing: approved
                ? OutlinedButton(
                    onPressed: () => _setApproved(u, false),
                    child: const Text('هەڵوەشاندنەوە'),
                  )
                : FilledButton(
                    onPressed: () => _setApproved(u, true),
                    child: const Text('قبوڵکردن'),
                  ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _users.where((u) => u['approved'] != true).length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('پانێلی ئەدمین'),
            actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
            bottom: TabBar(tabs: [
              Tab(text: 'چاوەڕێ ($pending)'),
              const Tab(text: 'قبوڵکراو'),
            ]),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'گەڕان بە ناو یان ئیمەیڵ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ),
                        Expanded(
                          child: TabBarView(children: [_list(false), _list(true)]),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

// ----- چۆنیەتی کردنەوە: تەنها بۆ ئەدمین نیشان بدە -----
// final me = await Supabase.instance.client
//     .from('profiles').select('role').eq('id', user.id).single();
// if (me['role'] == 'admin') {
//   Navigator.push(context,
//     MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
// }
