class MemoryFormData {
  const MemoryFormData({
    required this.title,
    this.description,
    required this.memoryDate,
    this.locationName,
    this.locationAddress,
    this.latitude,
    this.longitude,
    this.dateId,
  });

  final String title;
  final String? description;
  final DateTime memoryDate;
  final String? locationName;
  final String? locationAddress;
  final double? latitude;
  final double? longitude;
  final int? dateId;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'memory_date': _formatDate(memoryDate),
      'location_name': locationName,
      'location_address': locationAddress,
      'latitude': latitude,
      'longitude': longitude,
      'date_id': dateId,
    };
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
