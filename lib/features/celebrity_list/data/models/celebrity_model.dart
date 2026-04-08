class CelebrityModel {
  final String name;
  final String url;

  const CelebrityModel({
    required this.name,
    required this.url,
  });

  factory CelebrityModel.fromJson(Map<String, dynamic> json) {
    return CelebrityModel(
      name: json['name'] as String,
      url: json['url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CelebrityModel &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          url == other.url;

  @override
  int get hashCode => name.hashCode ^ url.hashCode;
}
