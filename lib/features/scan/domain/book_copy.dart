class BookCopy {
  const BookCopy({
    required this.id,
    required this.editionId,
    required this.publisherId,
    required this.status,
    required this.copyNumber,
    required this.createdAt,
    required this.updatedAt,
    this.libraryId,
    this.qrToken,
    this.edition,
    this.library,
  });

  final String id;
  final String editionId;
  final String publisherId;
  final String? libraryId;
  final String status;
  final int copyNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? qrToken;
  final EditionSummary? edition;
  final LibrarySummary? library;

  String get displayTitle {
    final editionTitle = edition?.title?.trim();
    if (editionTitle != null && editionTitle.isNotEmpty) {
      return editionTitle;
    }
    final bookTitle = edition?.book?.title.trim();
    if (bookTitle != null && bookTitle.isNotEmpty) {
      return bookTitle;
    }
    return 'Untitled copy';
  }

  String get authorsLabel {
    final authors = edition?.book?.authors ?? const <String>[];
    if (authors.isEmpty) {
      return 'Unknown author';
    }
    return authors.join(', ');
  }

  String get statusLabel => switch (status) {
    'IN_STOCK_PUBLISHER' => 'In publisher stock',
    'DISTRIBUTED' => 'In transit',
    'IN_STOCK_LIBRARY' => 'In library stock',
    'SOLD' => 'Sold',
    'RETURNED' => 'Returned',
    'LOST' => 'Lost',
    _ => status,
  };

  bool get isSellable => status == 'IN_STOCK_LIBRARY';

  String? get coverImageUrl =>
      edition?.coverImageUrl ?? edition?.book?.coverImageUrl;

  String get priceLabel {
    final cents = edition?.listPriceCents;
    if (cents == null) {
      return '—';
    }
    final currency = edition?.currency ?? 'USD';
    final amount = cents / 100;
    return '$currency ${amount.toStringAsFixed(2)}';
  }

  factory BookCopy.fromJson(Map<String, dynamic> json) {
    return BookCopy(
      id: json['id'] as String,
      editionId: json['editionId'] as String,
      publisherId: json['publisherId'] as String,
      libraryId: json['libraryId'] as String?,
      status: json['status'] as String,
      copyNumber: json['copyNumber'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      qrToken: json['qrToken'] as String?,
      edition: json['edition'] is Map<String, dynamic>
          ? EditionSummary.fromJson(json['edition'] as Map<String, dynamic>)
          : null,
      library: json['library'] is Map<String, dynamic>
          ? LibrarySummary.fromJson(json['library'] as Map<String, dynamic>)
          : null,
    );
  }
}

class EditionSummary {
  const EditionSummary({
    required this.id,
    required this.isbn,
    required this.format,
    required this.listPriceCents,
    required this.currency,
    this.title,
    this.coverImageUrl,
    this.book,
  });

  final String id;
  final String isbn;
  final String format;
  final String? title;
  final int listPriceCents;
  final String currency;
  final String? coverImageUrl;
  final BookSummary? book;

  factory EditionSummary.fromJson(Map<String, dynamic> json) {
    return EditionSummary(
      id: json['id'] as String,
      isbn: json['isbn'] as String,
      format: json['format'] as String,
      title: json['title'] as String?,
      listPriceCents: json['listPriceCents'] as int,
      currency: json['currency'] as String,
      coverImageUrl: json['coverImageUrl'] as String?,
      book: json['book'] is Map<String, dynamic>
          ? BookSummary.fromJson(json['book'] as Map<String, dynamic>)
          : null,
    );
  }
}

class BookSummary {
  const BookSummary({
    required this.id,
    required this.title,
    required this.authors,
    required this.publisherId,
    required this.slug,
    this.coverImageUrl,
  });

  final String id;
  final String title;
  final List<String> authors;
  final String publisherId;
  final String slug;
  final String? coverImageUrl;

  factory BookSummary.fromJson(Map<String, dynamic> json) {
    return BookSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      authors: _parseAuthors(json['authors']),
      publisherId: json['publisherId'] as String,
      slug: json['slug'] as String,
      coverImageUrl: json['coverImageUrl'] as String?,
    );
  }
}

List<String> _parseAuthors(Object? raw) {
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

class LibrarySummary {
  const LibrarySummary({
    required this.id,
    required this.name,
    required this.slug,
  });

  final String id;
  final String name;
  final String slug;

  factory LibrarySummary.fromJson(Map<String, dynamic> json) {
    return LibrarySummary(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
    );
  }
}
