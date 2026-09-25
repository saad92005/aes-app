part of '../main.dart';

// ---------------- PHOTO REPO (subcollection-based photo storage) ----------------
// Photos live one-per-document in `{parentCollection}/{parentId}/photos/{autoId}` instead
// of embedded in the parent doc, so a work order/expense/vendor bill can hold tens or
// hundreds of photos without ever approaching Firestore's 1 MiB-per-document limit. Detail
// screens fetch/watch this subcollection directly, scoped to one parent at a time - nothing
// reads every photo of every parent in one go the way the old flat `workOrderPhotos`
// collection used to.
class PhotoDoc {
  final String id;
  final String? kind;
  final String? itemId;
  final int index;
  final String dataUrl;
  final String uploaderUsername;
  final String timestamp;

  PhotoDoc({
    required this.id,
    this.kind,
    this.itemId,
    this.index = 0,
    required this.dataUrl,
    required this.uploaderUsername,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind,
        'itemId': itemId,
        'index': index,
        'dataUrl': dataUrl,
        'uploaderUsername': uploaderUsername,
        'timestamp': timestamp,
      };

  static PhotoDoc fromMap(Map<String, dynamic> m) => PhotoDoc(
        id: m['id'] ?? '',
        kind: m['kind'],
        itemId: m['itemId'],
        index: (m['index'] as num?)?.toInt() ?? 0,
        dataUrl: m['dataUrl'] ?? '',
        uploaderUsername: m['uploaderUsername'] ?? '',
        timestamp: m['timestamp'] ?? '',
      );
}

class PhotoRepo {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _photosRef(String parentCollection, String parentId) =>
      _db.collection(parentCollection).doc(parentId).collection('photos');

  // Replaces every photo of the given kind/itemId for one parent with the current list -
  // same "reconcile on save" approach the app already used for work order photos, just
  // backed by an auto-ID subcollection instead of a flat collection with hand-built keys.
  // dataUrls that already have a matching stored doc (same content) are left untouched;
  // this only deletes docs that are no longer present and inserts new ones.
  static Future<void> replaceAll({
    required String parentCollection,
    required String parentId,
    String? kind,
    String? itemId,
    required List<String> dataUrls,
    required String uploaderUsername,
  }) async {
    final ref = _photosRef(parentCollection, parentId);
    Query<Map<String, dynamic>> q = ref;
    if (kind != null) q = q.where('kind', isEqualTo: kind);
    if (itemId != null) q = q.where('itemId', isEqualTo: itemId);
    final existing = await q.get();

    final batch = _db.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    final now = DateTime.now().toIso8601String();
    for (int i = 0; i < dataUrls.length; i++) {
      final doc = ref.doc();
      batch.set(doc, PhotoDoc(id: doc.id, kind: kind, itemId: itemId, index: i, dataUrl: dataUrls[i], uploaderUsername: uploaderUsername, timestamp: now).toMap());
    }
    await batch.commit();
  }

  // One-time fetch, e.g. to populate a screen's initial state. Ordered to match how the
  // photos were originally added.
  static Future<List<String>> loadDataUrls(String parentCollection, String parentId, {String? kind, String? itemId}) async {
    Query<Map<String, dynamic>> q = _photosRef(parentCollection, parentId);
    if (kind != null) q = q.where('kind', isEqualTo: kind);
    if (itemId != null) q = q.where('itemId', isEqualTo: itemId);
    final snapshot = await q.get();
    final docs = snapshot.docs.map((d) => PhotoDoc.fromMap(d.data())).toList()..sort((a, b) => a.index.compareTo(b.index));
    return docs.map((d) => d.dataUrl).toList();
  }

  static Stream<List<String>> watchDataUrls(String parentCollection, String parentId, {String? kind, String? itemId}) {
    Query<Map<String, dynamic>> q = _photosRef(parentCollection, parentId);
    if (kind != null) q = q.where('kind', isEqualTo: kind);
    if (itemId != null) q = q.where('itemId', isEqualTo: itemId);
    return q.snapshots().map((snap) {
      final docs = snap.docs.map((d) => PhotoDoc.fromMap(d.data())).toList()..sort((a, b) => a.index.compareTo(b.index));
      return docs.map((d) => d.dataUrl).toList();
    });
  }

  static Future<void> deleteAll(String parentCollection, String parentId) async {
    final snapshot = await _photosRef(parentCollection, parentId).get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // One-time migration off the legacy flat `workOrderPhotos` collection (fixed-slot keys
  // like `{workOrderId}_{kind}_{index}`) into the new per-work-order subcollections. Guarded
  // by a marker doc so it only ever runs once across the whole app's lifetime, not once per
  // device/session. Existing legacy docs are left in place (not deleted) so this is safe to
  // re-run if it's ever interrupted partway through.
  static Future<void> migrateLegacyWorkOrderPhotosIfNeeded() async {
    final marker = _db.collection('_meta').doc('photoMigration');
    final markerSnap = await marker.get();
    if (markerSnap.exists && markerSnap.data()?['done'] == true) return;

    final legacy = await _db.collection('workOrderPhotos').get();
    if (legacy.docs.isNotEmpty) {
      final byWorkOrder = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
      for (final doc in legacy.docs) {
        final workOrderId = doc.data()['workOrderId'] as String?;
        if (workOrderId == null) continue;
        byWorkOrder.putIfAbsent(workOrderId, () => []).add(doc);
      }
      for (final entry in byWorkOrder.entries) {
        final ref = _photosRef('workOrders', entry.key);
        const chunkSize = 400;
        for (int start = 0; start < entry.value.length; start += chunkSize) {
          final chunk = entry.value.sublist(start, min(start + chunkSize, entry.value.length));
          final batch = _db.batch();
          for (final doc in chunk) {
            final data = doc.data();
            final newDoc = ref.doc();
            batch.set(newDoc, {
              'id': newDoc.id,
              'kind': data['kind'],
              'itemId': null,
              'index': data['index'] ?? 0,
              'dataUrl': data['dataUrl'],
              'uploaderUsername': '',
              'timestamp': DateTime.now().toIso8601String(),
            });
          }
          await batch.commit();
        }
      }
    }
    await marker.set({'done': true, 'migratedAt': DateTime.now().toIso8601String()});
  }
}
