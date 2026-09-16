class Shipment {
  const Shipment({
    required this.id,
    required this.code,
    required this.status,
    required this.publisherName,
    required this.items,
    this.notes,
  });

  final String id;
  final String code;
  final String status;
  final String publisherName;
  final String? notes;
  final List<ShipmentItem> items;

  int get inTransitCount => items.fold(
    0,
    (total, item) =>
        total +
        item.copies.where((copy) => copy.status == 'DISTRIBUTED').length,
  );

  factory Shipment.fromJson(Map<String, dynamic> json) {
    final publisher = json['publisher'];
    final rawItems = json['items'];
    return Shipment(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      status: json['status'] as String? ?? '',
      publisherName: publisher is Map
          ? publisher['name'] as String? ?? 'Unknown publisher'
          : 'Unknown publisher',
      notes: json['notes'] as String?,
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(ShipmentItem.fromJson)
                .toList()
          : const [],
    );
  }
}

class ShipmentItem {
  const ShipmentItem({
    required this.id,
    required this.quantity,
    required this.edition,
    required this.copies,
  });

  final String id;
  final int quantity;
  final ShipmentEdition edition;
  final List<ShipmentCopy> copies;

  factory ShipmentItem.fromJson(Map<String, dynamic> json) {
    final rawCopies = json['copies'];
    return ShipmentItem(
      id: json['id'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      edition: ShipmentEdition.fromJson(
        json['edition'] is Map<String, dynamic>
            ? json['edition'] as Map<String, dynamic>
            : const {},
      ),
      copies: rawCopies is List
          ? rawCopies
                .whereType<Map<String, dynamic>>()
                .map(ShipmentCopy.fromJson)
                .toList()
          : const [],
    );
  }
}

class ShipmentEdition {
  const ShipmentEdition({
    required this.isbn,
    required this.format,
    required this.title,
    required this.authors,
  });

  final String isbn;
  final String format;
  final String title;
  final String authors;

  factory ShipmentEdition.fromJson(Map<String, dynamic> json) {
    final book = json['book'];
    return ShipmentEdition(
      isbn: json['isbn'] as String? ?? '',
      format: json['format'] as String? ?? '',
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : book is Map
          ? book['title'] as String? ?? 'Untitled'
          : 'Untitled',
      authors: book is Map ? book['authors']?.toString() ?? '' : '',
    );
  }
}

class ShipmentCopy {
  const ShipmentCopy({
    required this.id,
    required this.copyNumber,
    required this.status,
  });

  final String id;
  final int copyNumber;
  final String status;

  factory ShipmentCopy.fromJson(Map<String, dynamic> json) => ShipmentCopy(
    id: json['id'] as String? ?? '',
    copyNumber: json['copyNumber'] as int? ?? 0,
    status: json['status'] as String? ?? '',
  );
}

class PaginatedShipments {
  const PaginatedShipments({required this.data});
  final List<Shipment> data;

  factory PaginatedShipments.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    return PaginatedShipments(
      data: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(Shipment.fromJson)
                .toList()
          : const [],
    );
  }
}

class ReceiptSummary {
  const ReceiptSummary({
    required this.draft,
    required this.confirmed,
    required this.copiesReceived,
  });

  final int draft;
  final int confirmed;
  final int copiesReceived;

  factory ReceiptSummary.fromJson(Map<String, dynamic> json) => ReceiptSummary(
    draft: json['draft'] as int? ?? 0,
    confirmed: json['confirmed'] as int? ?? 0,
    copiesReceived: json['copiesReceived'] as int? ?? 0,
  );
}

class StockReceipt {
  const StockReceipt({
    required this.id,
    required this.code,
    required this.status,
    required this.receivedCount,
    required this.discrepancyCount,
    required this.createdAt,
    this.notes,
  });

  final String id;
  final String code;
  final String status;
  final int receivedCount;
  final int discrepancyCount;
  final DateTime createdAt;
  final String? notes;

  factory StockReceipt.fromJson(Map<String, dynamic> json) => StockReceipt(
    id: json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    status: json['status'] as String? ?? '',
    receivedCount: json['receivedCount'] as int? ?? 0,
    discrepancyCount: json['discrepancyCount'] as int? ?? 0,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    notes: json['notes'] as String?,
  );
}

enum ReceiptDiscrepancy { none, missing, damaged }

extension ReceiptDiscrepancyValue on ReceiptDiscrepancy {
  String get apiValue => name.toUpperCase();
}

class ReceiptCopySelection {
  const ReceiptCopySelection({
    required this.copyId,
    required this.received,
    required this.discrepancy,
  });

  final String copyId;
  final bool received;
  final ReceiptDiscrepancy discrepancy;
}
