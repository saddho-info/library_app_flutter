import 'dart:convert';

import 'package:library_app/core/db/sync_status.dart';
import 'package:library_app/features/scan/domain/book_copy.dart';

Map<String, dynamic> _stringMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('Offline record is not a map.');
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

DateTime _date(Object? value) => DateTime.parse(value as String);

class LocalSaleItem {
  const LocalSaleItem({
    required this.id,
    required this.localSaleId,
    required this.editionId,
    required this.copyId,
    required this.unitPriceCents,
    required this.createdAt,
    this.quantity = 1,
    this.titleSnapshot,
    this.authorsSnapshot,
    this.isbnSnapshot,
    this.copyNumberSnapshot,
  });

  final String id;
  final String localSaleId;
  final String editionId;
  final String copyId;
  final int unitPriceCents;
  final int quantity;
  final DateTime createdAt;
  final String? titleSnapshot;
  final String? authorsSnapshot;
  final String? isbnSnapshot;
  final int? copyNumberSnapshot;

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'localSaleId': localSaleId,
    'editionId': editionId,
    'copyId': copyId,
    'unitPriceCents': unitPriceCents,
    'quantity': quantity,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'titleSnapshot': titleSnapshot,
    'authorsSnapshot': authorsSnapshot,
    'isbnSnapshot': isbnSnapshot,
    'copyNumberSnapshot': copyNumberSnapshot,
  };

  factory LocalSaleItem.fromJson(Object? value) {
    final json = _stringMap(value);
    return LocalSaleItem(
      id: json['id'] as String,
      localSaleId: json['localSaleId'] as String,
      editionId: json['editionId'] as String,
      copyId: json['copyId'] as String,
      unitPriceCents: json['unitPriceCents'] as int,
      quantity: json['quantity'] as int? ?? 1,
      createdAt: _date(json['createdAt']),
      titleSnapshot: json['titleSnapshot'] as String?,
      authorsSnapshot: json['authorsSnapshot'] as String?,
      isbnSnapshot: json['isbnSnapshot'] as String?,
      copyNumberSnapshot: json['copyNumberSnapshot'] as int?,
    );
  }
}

class LocalSale {
  const LocalSale({
    required this.id,
    required this.libraryId,
    required this.code,
    required this.currency,
    required this.totalCents,
    required this.actorUserId,
    required this.soldAt,
    required this.createdAt,
    required this.updatedAt,
    required this.idempotencyKey,
    required this.request,
    required this.items,
    this.serverId,
    this.notes,
    this.syncStatus = LocalSyncStatus.pending,
    this.syncErrorCode,
    this.syncErrorMessage,
    this.retryCount = 0,
  });

  final String id;
  final String? serverId;
  final String libraryId;
  final String code;
  final String currency;
  final int totalCents;
  final String? notes;
  final String actorUserId;
  final DateTime soldAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String idempotencyKey;
  final LocalSyncStatus syncStatus;
  final String? syncErrorCode;
  final String? syncErrorMessage;
  final int retryCount;
  final Map<String, dynamic> request;
  final List<LocalSaleItem> items;

  LocalSale copyWith({
    String? serverId,
    LocalSyncStatus? syncStatus,
    String? syncErrorCode,
    String? syncErrorMessage,
    int? retryCount,
    DateTime? updatedAt,
    bool clearError = false,
  }) {
    return LocalSale(
      id: id,
      serverId: serverId ?? this.serverId,
      libraryId: libraryId,
      code: code,
      currency: currency,
      totalCents: totalCents,
      notes: notes,
      actorUserId: actorUserId,
      soldAt: soldAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      idempotencyKey: idempotencyKey,
      syncStatus: syncStatus ?? this.syncStatus,
      syncErrorCode: clearError ? null : syncErrorCode ?? this.syncErrorCode,
      syncErrorMessage: clearError
          ? null
          : syncErrorMessage ?? this.syncErrorMessage,
      retryCount: retryCount ?? this.retryCount,
      request: request,
      items: items,
    );
  }

  Map<String, dynamic> toJson({bool includeItems = true}) => {
    'schemaVersion': 1,
    'id': id,
    'serverId': serverId,
    'libraryId': libraryId,
    'code': code,
    'currency': currency,
    'totalCents': totalCents,
    'notes': notes,
    'actorUserId': actorUserId,
    'soldAt': soldAt.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'idempotencyKey': idempotencyKey,
    'syncStatus': syncStatus.storageValue,
    'syncErrorCode': syncErrorCode,
    'syncErrorMessage': syncErrorMessage,
    'retryCount': retryCount,
    'request': request,
    if (includeItems) 'items': items.map((item) => item.toJson()).toList(),
  };

  factory LocalSale.fromJson(Object? value, {List<LocalSaleItem>? items}) {
    final json = _stringMap(value);
    final embeddedItems = json['items'] as List<dynamic>?;
    return LocalSale(
      id: json['id'] as String,
      serverId: json['serverId'] as String?,
      libraryId: json['libraryId'] as String,
      code: json['code'] as String,
      currency: json['currency'] as String? ?? 'USD',
      totalCents: json['totalCents'] as int,
      notes: json['notes'] as String?,
      actorUserId: json['actorUserId'] as String,
      soldAt: _date(json['soldAt']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
      idempotencyKey: json['idempotencyKey'] as String,
      syncStatus: LocalSyncStatus.fromStorage(
        json['syncStatus'] as String? ?? 'PENDING',
      ),
      syncErrorCode: json['syncErrorCode'] as String?,
      syncErrorMessage: json['syncErrorMessage'] as String?,
      retryCount: json['retryCount'] as int? ?? 0,
      request: _stringMap(json['request']),
      items:
          items ??
          embeddedItems?.map(LocalSaleItem.fromJson).toList(growable: false) ??
          const [],
    );
  }
}

class InventorySnapshot {
  const InventorySnapshot({
    required this.id,
    required this.editionId,
    required this.holderType,
    required this.holderId,
    required this.onHand,
    required this.inTransit,
    required this.sold,
    required this.returned,
    required this.lost,
    required this.lowStockThreshold,
    required this.version,
    required this.serverUpdatedAt,
    required this.cachedAt,
    this.titleSnapshot,
    this.isbnSnapshot,
  });

  final String id;
  final String editionId;
  final String holderType;
  final String holderId;
  final int onHand;
  final int inTransit;
  final int sold;
  final int returned;
  final int lost;
  final int lowStockThreshold;
  final int version;
  final DateTime serverUpdatedAt;
  final DateTime cachedAt;
  final String? titleSnapshot;
  final String? isbnSnapshot;

  String get storageKey => '$editionId::$holderType::$holderId';
  bool get isLibraryHolder => holderType == 'LIBRARY';

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'editionId': editionId,
    'holderType': holderType,
    'holderId': holderId,
    'onHand': onHand,
    'inTransit': inTransit,
    'sold': sold,
    'returned': returned,
    'lost': lost,
    'lowStockThreshold': lowStockThreshold,
    'version': version,
    'serverUpdatedAt': serverUpdatedAt.toUtc().toIso8601String(),
    'cachedAt': cachedAt.toUtc().toIso8601String(),
    'titleSnapshot': titleSnapshot,
    'isbnSnapshot': isbnSnapshot,
  };

  factory InventorySnapshot.fromJson(Object? value) {
    final json = _stringMap(value);
    final updatedRaw = json['serverUpdatedAt'] ?? json['updatedAt'];
    return InventorySnapshot(
      id: json['id'] as String,
      editionId: json['editionId'] as String,
      holderType: json['holderType'] as String,
      holderId: json['holderId'] as String,
      onHand: json['onHand'] as int? ?? 0,
      inTransit: json['inTransit'] as int? ?? 0,
      sold: json['sold'] as int? ?? 0,
      returned: json['returned'] as int? ?? 0,
      lost: json['lost'] as int? ?? 0,
      lowStockThreshold: json['lowStockThreshold'] as int? ?? 5,
      version: json['version'] as int? ?? 0,
      serverUpdatedAt: updatedRaw is String
          ? DateTime.parse(updatedRaw)
          : DateTime.now().toUtc(),
      cachedAt: json['cachedAt'] is String
          ? DateTime.parse(json['cachedAt'] as String)
          : DateTime.now().toUtc(),
      titleSnapshot:
          json['titleSnapshot'] as String? ?? json['title'] as String?,
      isbnSnapshot: json['isbnSnapshot'] as String? ?? json['isbn'] as String?,
    );
  }
}

class LocalReceipt {
  const LocalReceipt({
    required this.id,
    required this.libraryId,
    required this.actorUserId,
    required this.idempotencyKey,
    required this.createdAt,
    required this.updatedAt,
    required this.request,
    this.serverId,
    this.syncStatus = LocalSyncStatus.pending,
    this.syncErrorCode,
    this.syncErrorMessage,
    this.retryCount = 0,
  });

  final String id;
  final String? serverId;
  final String libraryId;
  final String actorUserId;
  final String idempotencyKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LocalSyncStatus syncStatus;
  final String? syncErrorCode;
  final String? syncErrorMessage;
  final int retryCount;
  final Map<String, dynamic> request;

  LocalReceipt copyWith({
    String? serverId,
    LocalSyncStatus? syncStatus,
    String? syncErrorCode,
    String? syncErrorMessage,
    int? retryCount,
    bool clearError = false,
  }) => LocalReceipt(
    id: id,
    serverId: serverId ?? this.serverId,
    libraryId: libraryId,
    actorUserId: actorUserId,
    idempotencyKey: idempotencyKey,
    createdAt: createdAt,
    updatedAt: DateTime.now().toUtc(),
    request: request,
    syncStatus: syncStatus ?? this.syncStatus,
    syncErrorCode: clearError ? null : syncErrorCode ?? this.syncErrorCode,
    syncErrorMessage: clearError
        ? null
        : syncErrorMessage ?? this.syncErrorMessage,
    retryCount: retryCount ?? this.retryCount,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'serverId': serverId,
    'libraryId': libraryId,
    'actorUserId': actorUserId,
    'idempotencyKey': idempotencyKey,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'syncStatus': syncStatus.storageValue,
    'syncErrorCode': syncErrorCode,
    'syncErrorMessage': syncErrorMessage,
    'retryCount': retryCount,
    'request': request,
  };

  factory LocalReceipt.fromJson(Object? value) {
    final json = _stringMap(value);
    return LocalReceipt(
      id: json['id'] as String,
      serverId: json['serverId'] as String?,
      libraryId: json['libraryId'] as String,
      actorUserId: json['actorUserId'] as String,
      idempotencyKey: json['idempotencyKey'] as String,
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
      syncStatus: LocalSyncStatus.fromStorage(
        json['syncStatus'] as String? ?? 'PENDING',
      ),
      syncErrorCode: json['syncErrorCode'] as String?,
      syncErrorMessage: json['syncErrorMessage'] as String?,
      retryCount: json['retryCount'] as int? ?? 0,
      request: _stringMap(json['request']),
    );
  }
}

Map<String, dynamic> bookCopyToJson(BookCopy copy) => {
  'schemaVersion': 1,
  'id': copy.id,
  'editionId': copy.editionId,
  'publisherId': copy.publisherId,
  'libraryId': copy.libraryId,
  'status': copy.status,
  'copyNumber': copy.copyNumber,
  'createdAt': copy.createdAt.toUtc().toIso8601String(),
  'updatedAt': copy.updatedAt.toUtc().toIso8601String(),
  'cachedAt': DateTime.now().toUtc().toIso8601String(),
  'qrToken': copy.qrToken,
  if (copy.edition != null)
    'edition': {
      'id': copy.edition!.id,
      'isbn': copy.edition!.isbn,
      'format': copy.edition!.format,
      'title': copy.edition!.title,
      'listPriceCents': copy.edition!.listPriceCents,
      'currency': copy.edition!.currency,
      'coverImageUrl': copy.edition!.coverImageUrl,
      if (copy.edition!.book != null)
        'book': {
          'id': copy.edition!.book!.id,
          'title': copy.edition!.book!.title,
          'authors': copy.edition!.book!.authors,
          'publisherId': copy.edition!.book!.publisherId,
          'slug': copy.edition!.book!.slug,
          'coverImageUrl': copy.edition!.book!.coverImageUrl,
        },
    },
  if (copy.library != null)
    'library': {
      'id': copy.library!.id,
      'name': copy.library!.name,
      'slug': copy.library!.slug,
    },
};

BookCopy bookCopyFromStored(Object? value) =>
    BookCopy.fromJson(_stringMap(value));

BookCopy bookCopyFromPayloadJson(String raw) {
  final decoded = jsonDecode(raw);
  return bookCopyFromStored(decoded);
}
