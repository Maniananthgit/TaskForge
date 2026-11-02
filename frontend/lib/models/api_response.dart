class PaginatedResult<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  PaginatedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    List<T> parsedItems = rawItems
        .map((i) => itemParser(i as Map<String, dynamic>))
        .toList();

    return PaginatedResult<T>(
      items: parsedItems,
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 10,
      totalPages: json['total_pages'] as int? ?? 1,
    );
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
  });

  @override
  String toString() => message;
}

class ApiResponse<T> {
  final T? data;
  final String? message;
  final bool isSuccess;

  ApiResponse.success(this.data, {this.message}) : isSuccess = true;
  ApiResponse.error(this.message) : data = null, isSuccess = false;
}

