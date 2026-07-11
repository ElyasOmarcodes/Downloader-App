import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_task.dart';

/// Persists the download queue so tasks (and their resume offsets) survive
/// app restarts.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _tasksKey = 'download_tasks_v1';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> saveTasks(List<DownloadTask> tasks) async {
    await init();
    final raw = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await _prefs!.setString(_tasksKey, raw);
  }

  Future<List<DownloadTask>> loadTasks() async {
    await init();
    final raw = _prefs!.getString(_tasksKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => DownloadTask.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
