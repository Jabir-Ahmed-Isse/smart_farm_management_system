import '../errors.dart';
import 'local_store.dart';

/// Wraps a farm-scoped list read with an offline-first cache:
///   online  → fetch, mirror rows into [LocalStore], return them;
///   offline → return the cached rows (filtered to [farmId]) instead of
///             throwing a raw socket error; if there is no cache and the error
///             is a connectivity failure, throw a friendly [OfflineException].
///
/// [table] must match the Supabase table name and the LocalStore key prefix.
Future<List<T>> cachedList<T>({
  required String table,
  String? farmId,
  required Future<List<Map<String, dynamic>>> Function() fetch,
  required T Function(Map<String, dynamic>) fromMap,
  int Function(Map<String, dynamic> a, Map<String, dynamic> b)? sort,
}) async {
  try {
    final rows = await fetch();
    final maps = rows.map((r) => Map<String, dynamic>.from(r)).toList();
    if (LocalStore.isReady) await LocalStore.instance.putAll(table, maps);
    return maps.map(fromMap).toList();
  } catch (e) {
    if (LocalStore.isReady) {
      final cached = LocalStore.instance.list(table, farmId: farmId);
      if (cached.isNotEmpty) {
        cached.sort(sort ?? _newestFirst);
        return cached.map(fromMap).toList();
      }
    }
    if (isOfflineError(e)) throw const OfflineException();
    rethrow;
  }
}

int _newestFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
  String k(Map<String, dynamic> m) =>
      (m['created_at'] ?? m['date'] ?? '').toString();
  return k(b).compareTo(k(a));
}
