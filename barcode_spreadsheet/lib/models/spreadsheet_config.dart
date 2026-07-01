class SpreadsheetConfig {
  final String id;
  final String title;
  final String url;
  final bool isActive;
  final String? sheetName;
  final List<String> availableSheets;
  final Map<String, int> mapping;
  final List<String> headers;

  SpreadsheetConfig({
    required this.id,
    required this.title,
    required this.url,
    this.isActive = true,
    this.sheetName,
    this.availableSheets = const [],
    this.mapping = const {},
    this.headers = const [],
  });

  factory SpreadsheetConfig.fromJson(Map<String, dynamic> json) {
    Map<String, int> parsedMapping = {};
    if (json['mapping'] != null) {
      final map = json['mapping'] as Map<String, dynamic>;
      parsedMapping = map.map((k, v) => MapEntry(k, v as int));
    }
    
    List<String> parsedHeaders = [];
    if (json['headers'] != null) {
      parsedHeaders = List<String>.from(json['headers']);
    }

    List<String> parsedAvailableSheets = [];
    if (json['availableSheets'] != null) {
      parsedAvailableSheets = List<String>.from(json['availableSheets']);
    }

    return SpreadsheetConfig(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      isActive: json['isActive'] ?? true,
      sheetName: json['sheetName'],
      availableSheets: parsedAvailableSheets,
      mapping: parsedMapping,
      headers: parsedHeaders,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'isActive': isActive,
      'sheetName': sheetName,
      'availableSheets': availableSheets,
      'mapping': mapping,
      'headers': headers,
    };
  }

  SpreadsheetConfig copyWith({
    String? title,
    bool? isActive,
    String? sheetName,
    List<String>? availableSheets,
    Map<String, int>? mapping,
    List<String>? headers,
  }) {
    return SpreadsheetConfig(
      id: id,
      title: title ?? this.title,
      url: url,
      isActive: isActive ?? this.isActive,
      sheetName: sheetName ?? this.sheetName,
      availableSheets: availableSheets ?? this.availableSheets,
      mapping: mapping ?? this.mapping,
      headers: headers ?? this.headers,
    );
  }
}
