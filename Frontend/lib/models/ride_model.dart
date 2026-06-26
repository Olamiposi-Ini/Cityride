class Ride {
  final String id;
  final String status;
  final bool isAccepted;
  final String vehicleType;
  final String pickupAddress;
  final String destinationAddress;
  final num? fareEstimate;
  final num? distanceKm;
  final int? rating;
  final String? createdAt;
  final String? completedAt;
  final num? driverRatingAverage;
  final int? driverRatingCount;
  final Map<String, dynamic>? driver;
  final Map<String, dynamic>? rider;

  Ride({
    required this.id,
    required this.status,
    required this.isAccepted,
    required this.vehicleType,
    required this.pickupAddress,
    required this.destinationAddress,
    this.fareEstimate,
    this.distanceKm,
    this.rating,
    this.createdAt,
    this.completedAt,
    this.driverRatingAverage,
    this.driverRatingCount,
    this.driver,
    this.rider,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? driverInfo =
        json['driver'] as Map<String, dynamic>?;
    final Map<String, dynamic>? vehicleInfo =
        driverInfo?['driver'] as Map<String, dynamic>?;

    return Ride(
      id: json['id'] ?? json['_id'],
      status: json['status'],
      // The backend keeps `status` at "DRIVER_ASSIGNED" through both the
      // pre-accept and accepted-but-not-yet-en-route phases; `acceptedAt`
      // is the only field that actually flips on acceptance.
      isAccepted: json['acceptedAt'] != null,
      vehicleType: vehicleInfo?['vehicleType'] ?? 'Keke',
      pickupAddress:
          json['pickupLabel'] ??
          json['pickupLocation']?['label'] ??
          'Pickup location',
      destinationAddress:
          json['destinationLabel'] ??
          json['destination']?['label'] ??
          'Destination',
      fareEstimate: json['fareEstimate'],
      distanceKm: json['distanceKm'],
      rating: json['rating'],
      createdAt: json['createdAt'],
      completedAt: json['completedAt'],
      driverRatingAverage: vehicleInfo?['ratingAverage'],
      driverRatingCount: vehicleInfo?['ratingCount'],
      driver: driverInfo,
      rider: json['rider'],
    );
  }
}
