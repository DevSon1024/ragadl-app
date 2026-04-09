class LatestItem {
  final String url;
  final String image;
  final String title;
  final String date;
  String? name;
  String? profileLink;

  LatestItem({
    required this.url,
    required this.image,
    required this.title,
    required this.date,
    this.name,
    this.profileLink,
  });
}
