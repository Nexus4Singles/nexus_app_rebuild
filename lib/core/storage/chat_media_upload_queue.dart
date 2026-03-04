import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Persistent queue for pending chat media uploads.
/// Survives app crashes, restarts, and background termination.
class ChatMediaUploadQueue {
  static const String tableName = 'chat_media_uploads';

  /// Unique ID for the upload task
  final String? id;

  /// Firestore chat ID
  final String chatId;

  /// Firestore message ID (to update when upload completes)
  final String messageId;

  /// Local file path to upload
  final String localFilePath;

  /// User ID who owns this upload
  final String userId;

  /// Message type ('image' or 'audio')
  final String mediaType;

  /// Current upload status: 'pending', 'uploading', 'uploaded', 'failed'
  final String status;

  /// Number of retry attempts made
  final int retryCount;

  /// Max retry attempts before giving up
  final int maxRetries;

  /// Timestamp when created
  final DateTime createdAt;

  /// Timestamp when last attempted
  final DateTime? lastAttemptAt;

  /// Error message from last failure (for logging)
  final String? lastError;

  ChatMediaUploadQueue({
    this.id,
    required this.chatId,
    required this.messageId,
    required this.localFilePath,
    required this.userId,
    required this.mediaType,
    this.status = 'pending',
    this.retryCount = 0,
    this.maxRetries = 5,
    DateTime? createdAt,
    this.lastAttemptAt,
    this.lastError,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'messageId': messageId,
      'localFilePath': localFilePath,
      'userId': userId,
      'mediaType': mediaType,
      'status': status,
      'retryCount': retryCount,
      'maxRetries': maxRetries,
      'createdAt': createdAt.toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'lastError': lastError,
    };
  }

  /// Create from database map
  factory ChatMediaUploadQueue.fromMap(Map<String, dynamic> map) {
    return ChatMediaUploadQueue(
      id: map['id'] as String?,
      chatId: map['chatId'] as String? ?? '',
      messageId: map['messageId'] as String? ?? '',
      localFilePath: map['localFilePath'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      mediaType: map['mediaType'] as String? ?? 'image',
      status: map['status'] as String? ?? 'pending',
      retryCount: map['retryCount'] as int? ?? 0,
      maxRetries: map['maxRetries'] as int? ?? 5,
      createdAt:
          map['createdAt'] != null
              ? DateTime.parse(map['createdAt'] as String)
              : DateTime.now(),
      lastAttemptAt:
          map['lastAttemptAt'] != null
              ? DateTime.parse(map['lastAttemptAt'] as String)
              : null,
      lastError: map['lastError'] as String?,
    );
  }

  /// Create a copy with updated fields
  ChatMediaUploadQueue copyWith({
    String? id,
    String? chatId,
    String? messageId,
    String? localFilePath,
    String? userId,
    String? mediaType,
    String? status,
    int? retryCount,
    int? maxRetries,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    String? lastError,
  }) {
    return ChatMediaUploadQueue(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      messageId: messageId ?? this.messageId,
      localFilePath: localFilePath ?? this.localFilePath,
      userId: userId ?? this.userId,
      mediaType: mediaType ?? this.mediaType,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Database helper for managing the upload queue
class ChatMediaUploadQueueDb {
  static Database? _db;

  /// Initialize the database
  static Future<Database> getDatabase() async {
    if (_db != null) return _db!;

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'nexus_chat_media_uploads.db');

    _db = await openDatabase(path, version: 1, onCreate: _onCreate);

    return _db!;
  }

  /// Create tables on first run
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${ChatMediaUploadQueue.tableName} (
        id TEXT PRIMARY KEY,
        chatId TEXT NOT NULL,
        messageId TEXT NOT NULL,
        localFilePath TEXT NOT NULL,
        userId TEXT NOT NULL,
        mediaType TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        retryCount INTEGER DEFAULT 0,
        maxRetries INTEGER DEFAULT 5,
        createdAt TEXT NOT NULL,
        lastAttemptAt TEXT,
        lastError TEXT
      )
    ''');

    // Index for faster queries
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_status_user 
      ON ${ChatMediaUploadQueue.tableName}(status, userId)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_message_id 
      ON ${ChatMediaUploadQueue.tableName}(messageId)
    ''');
  }

  /// Insert a new upload task
  static Future<String> insert(ChatMediaUploadQueue upload) async {
    final db = await getDatabase();
    final id =
        '${upload.userId}_${upload.messageId}_${DateTime.now().millisecondsSinceEpoch}';
    final uploadWithId = upload.copyWith(id: id);

    await db.insert(
      ChatMediaUploadQueue.tableName,
      uploadWithId.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return id;
  }

  /// Get all pending uploads for a user (excludes permanently failed ones)
  static Future<List<ChatMediaUploadQueue>> getPendingUploads(
    String userId,
  ) async {
    final db = await getDatabase();
    final results = await db.query(
      ChatMediaUploadQueue.tableName,
      where: 'userId = ? AND status IN (?, ?) AND retryCount < maxRetries',
      whereArgs: [userId, 'pending', 'failed'],
      orderBy: 'createdAt ASC',
    );

    return results.map((map) => ChatMediaUploadQueue.fromMap(map)).toList();
  }

  /// Get a specific upload by message ID
  static Future<ChatMediaUploadQueue?> getByMessageId(String messageId) async {
    final db = await getDatabase();
    final results = await db.query(
      ChatMediaUploadQueue.tableName,
      where: 'messageId = ?',
      whereArgs: [messageId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return ChatMediaUploadQueue.fromMap(results.first);
  }

  /// Get a specific upload by its unique ID
  static Future<ChatMediaUploadQueue?> getById(String uploadId) async {
    final db = await getDatabase();
    final results = await db.query(
      ChatMediaUploadQueue.tableName,
      where: 'id = ?',
      whereArgs: [uploadId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return ChatMediaUploadQueue.fromMap(results.first);
  }

  /// Update an upload's status
  static Future<void> updateStatus(
    String uploadId,
    String newStatus, {
    int? retryCount,
    String? lastError,
  }) async {
    final db = await getDatabase();
    await db.update(
      ChatMediaUploadQueue.tableName,
      {
        'status': newStatus,
        if (retryCount != null) 'retryCount': retryCount,
        'lastAttemptAt': DateTime.now().toIso8601String(),
        if (lastError != null) 'lastError': lastError,
      },
      where: 'id = ?',
      whereArgs: [uploadId],
    );
  }

  /// Delete a completed upload
  static Future<void> delete(String uploadId) async {
    final db = await getDatabase();
    await db.delete(
      ChatMediaUploadQueue.tableName,
      where: 'id = ?',
      whereArgs: [uploadId],
    );
  }

  /// Delete uploads for a chat (cleanup after conversation deletion)
  static Future<void> deleteByChat(String chatId) async {
    final db = await getDatabase();
    await db.delete(
      ChatMediaUploadQueue.tableName,
      where: 'chatId = ?',
      whereArgs: [chatId],
    );
  }

  /// Delete all old failed uploads (older than 90 days) to prevent DB bloat
  static Future<void> deleteExpiredFailed() async {
    final db = await getDatabase();
    final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));

    await db.delete(
      ChatMediaUploadQueue.tableName,
      where: 'status = ? AND createdAt < ?',
      whereArgs: ['failed', ninetyDaysAgo.toIso8601String()],
    );
  }

  /// Get count of pending uploads (excludes permanently failed)
  static Future<int> getPendingCount(String userId) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${ChatMediaUploadQueue.tableName} '
      'WHERE userId = ? AND status IN (?, ?) AND retryCount < maxRetries',
      [userId, 'pending', 'failed'],
    );

    return (result.first['count'] as int?) ?? 0;
  }

  /// Reset any 'uploading' records back to 'pending' (crash recovery)
  /// If app crashed during upload, these records were left in 'uploading' state
  static Future<void> resetUploadingToPending(String userId) async {
    final db = await getDatabase();
    await db.update(
      ChatMediaUploadQueue.tableName,
      {'status': 'pending'},
      where: 'userId = ? AND status = ?',
      whereArgs: [userId, 'uploading'],
    );
  }

  /// Close the database
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
