class SaleSummary {
  const SaleSummary({
    required this.saleCount,
    required this.itemCount,
    required this.totalCents,
  });

  final int saleCount;
  final int itemCount;
  final int totalCents;

  factory SaleSummary.fromJson(Map<String, dynamic> json) {
    return SaleSummary(
      saleCount: json['saleCount'] as int? ?? 0,
      itemCount: json['itemCount'] as int? ?? 0,
      totalCents: json['totalCents'] as int? ?? 0,
    );
  }
}

class Sale {
  const Sale({
    required this.id,
    required this.libraryId,
    required this.code,
    required this.currency,
    required this.totalCents,
    required this.actorUserId,
    required this.soldAt,
    required this.createdAt,
    required this.updatedAt,
    required this.itemCount,
    required this.items,
    this.notes,
    this.idempotencyKey,
    this.library,
    this.actor,
  });

  final String id;
  final String libraryId;
  final String code;
  final String currency;
  final int totalCents;
  final String? notes;
  final String actorUserId;
  final DateTime soldAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? idempotencyKey;
  final int itemCount;
  final SaleLibrary? library;
  final SaleActor? actor;
  final List<SaleItem> items;

  String get totalLabel => formatMoney(totalCents, currency);

  String get primaryTitle {
    if (items.isEmpty) {
      return 'Sale $code';
    }
    return items.first.displayTitle;
  }

  factory Sale.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return Sale(
      id: json['id'] as String,
      libraryId: json['libraryId'] as String,
      code: json['code'] as String,
      currency: json['currency'] as String? ?? 'USD',
      totalCents: json['totalCents'] as int? ?? 0,
      notes: json['notes'] as String?,
      actorUserId: json['actorUserId'] as String,
      soldAt: DateTime.parse(json['soldAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      idempotencyKey: json['idempotencyKey'] as String?,
      itemCount: json['itemCount'] as int? ??
          (rawItems is List ? rawItems.length : 0),
      library: json['library'] is Map<String, dynamic>
          ? SaleLibrary.fromJson(json['library'] as Map<String, dynamic>)
          : null,
      actor: json['actor'] is Map<String, dynamic>
          ? SaleActor.fromJson(json['actor'] as Map<String, dynamic>)
          : null,
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(SaleItem.fromJson)
                .toList()
          : const <SaleItem>[],
    );
  }
}

class SaleItem {
  const SaleItem({
    required this.id,
    required this.saleId,
    required this.editionId,
    required this.copyId,
    required this.unitPriceCents,
    required this.quantity,
    required this.createdAt,
    this.edition,
    this.copy,
  });

  final String id;
  final String saleId;
  final String editionId;
  final String copyId;
  final int unitPriceCents;
  final int quantity;
  final DateTime createdAt;
  final SaleEdition? edition;
  final SaleCopy? copy;

  String get displayTitle {
    final editionTitle = edition?.title?.trim();
    if (editionTitle != null && editionTitle.isNotEmpty) {
      return editionTitle;
    }
    final bookTitle = edition?.book?.title.trim();
    if (bookTitle != null && bookTitle.isNotEmpty) {
      return bookTitle;
    }
    return 'Untitled item';
  }

  String get authorsLabel => edition?.book?.authorsLabel ?? 'Unknown author';

  String priceLabel(String currency) => formatMoney(unitPriceCents, currency);

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'] as String,
      saleId: json['saleId'] as String,
      editionId: json['editionId'] as String,
      copyId: json['copyId'] as String,
      unitPriceCents: json['unitPriceCents'] as int,
      quantity: json['quantity'] as int? ?? 1,
      createdAt: DateTime.parse(json['createdAt'] as String),
      edition: json['edition'] is Map<String, dynamic>
          ? SaleEdition.fromJson(json['edition'] as Map<String, dynamic>)
          : null,
      copy: json['copy'] is Map<String, dynamic>
          ? SaleCopy.fromJson(json['copy'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SaleEdition {
  const SaleEdition({
    required this.id,
    required this.isbn,
    required this.format,
    required this.listPriceCents,
    required this.currency,
    this.title,
    this.book,
  });

  final String id;
  final String isbn;
  final String format;
  final String? title;
  final int listPriceCents;
  final String currency;
  final SaleBook? book;

  factory SaleEdition.fromJson(Map<String, dynamic> json) {
    return SaleEdition(
      id: json['id'] as String,
      isbn: json['isbn'] as String,
      format: json['format'] as String,
      title: json['title'] as String?,
      listPriceCents: json['listPriceCents'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      book: json['book'] is Map<String, dynamic>
          ? SaleBook.fromJson(json['book'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SaleBook {
  const SaleBook({
    required this.id,
    required this.title,
    required this.authors,
    required this.slug,
    required this.publisherId,
  });

  final String id;
  final String title;
  final List<String> authors;
  final String slug;
  final String publisherId;

  String get authorsLabel {
    if (authors.isEmpty) {
      return 'Unknown author';
    }
    return authors.join(', ');
  }

  factory SaleBook.fromJson(Map<String, dynamic> json) {
    return SaleBook(
      id: json['id'] as String,
      title: json['title'] as String,
      authors: parseAuthors(json['authors']),
      slug: json['slug'] as String,
      publisherId: json['publisherId'] as String,
    );
  }
}

class SaleCopy {
  const SaleCopy({
    required this.id,
    required this.copyNumber,
    required this.status,
    required this.publisherId,
    this.libraryId,
  });

  final String id;
  final int copyNumber;
  final String status;
  final String publisherId;
  final String? libraryId;

  factory SaleCopy.fromJson(Map<String, dynamic> json) {
    return SaleCopy(
      id: json['id'] as String,
      copyNumber: json['copyNumber'] as int,
      status: json['status'] as String,
      publisherId: json['publisherId'] as String,
      libraryId: json['libraryId'] as String?,
    );
  }
}

class SaleLibrary {
  const SaleLibrary({
    required this.id,
    required this.name,
    required this.slug,
  });

  final String id;
  final String name;
  final String slug;

  factory SaleLibrary.fromJson(Map<String, dynamic> json) {
    return SaleLibrary(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
    );
  }
}

class SaleActor {
  const SaleActor({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }

  factory SaleActor.fromJson(Map<String, dynamic> json) {
    return SaleActor(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

class PaginatedSales {
  const PaginatedSales({required this.data, required this.meta});

  final List<Sale> data;
  final PaginationMeta meta;

  factory PaginatedSales.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    return PaginatedSales(
      data: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(Sale.fromJson)
                .toList()
          : const <Sale>[],
      meta: PaginationMeta.fromJson(
        json['meta'] is Map<String, dynamic>
            ? json['meta'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
    );
  }
}

class PaginationMeta {
  const PaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
    );
  }
}

List<String> parseAuthors(Object? raw) {
  if (raw is List) {
    return raw
        .map((a) => a.toString().trim())
        .where((a) => a.isNotEmpty)
        .toList();
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }
    return trimmed
        .split(RegExp(r'\s*,\s*'))
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

String formatMoney(int cents, [String currency = 'USD']) {
  final amount = cents / 100;
  return '$currency ${amount.toStringAsFixed(2)}';
}

String formatSaleDate(DateTime value) {
  final local = value.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

int? parseMoneyToCents(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) {
    return null;
  }
  final value = double.tryParse(cleaned);
  if (value == null || value < 0) {
    return null;
  }
  return (value * 100).round();
}
