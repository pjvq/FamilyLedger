enum SyncOpType { create, update, delete }

class SyncOperation {
  final String id;
  final String entityType; // 'transaction', 'account', 'category'
  final String entityId;
  final SyncOpType opType;
  final String payload; // JSON
  final String clientId;
  final DateTime timestamp;
  final bool uploaded;

  const SyncOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.opType,
    required this.payload,
    required this.clientId,
    required this.timestamp,
    this.uploaded = false,
  });
}
