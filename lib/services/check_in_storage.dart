import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/check_in_record.dart';

class CheckInStorage {
  static const _fileName = 'check_in_records.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<List<CheckInRecord>> loadAll() async {
    final file = await _file();
    if (!await file.exists()) return [];
    final raw = await file.readAsString();
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => CheckInRecord.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> save(CheckInRecord record) async {
    final records = await loadAll();
    records.insert(0, record);
    final file = await _file();
    await file.writeAsString(jsonEncode(records.map((r) => r.toJson()).toList()));
  }

  Future<void> delete(String id) async {
    final records = await loadAll();
    records.removeWhere((r) => r.id == id);
    final file = await _file();
    await file.writeAsString(jsonEncode(records.map((r) => r.toJson()).toList()));
  }
}
