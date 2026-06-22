class Ride {
  final String id;
  final String status;
  final String vehicleType;
  final String pickupAddress;
  final String destinationAddress;
  final Map<String, dynamic>? driver;

  Ride({
    required this.id,
    required this.status,
    required this.vehicleType,
    required this.pickupAddress,
    required this.destinationAddress,
    this.driver,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['_id'],
      status: json['status'],
      vehicleType: json['vehicleType'] ?? 'Keke',
      pickupAddress: json['pickupLocation']['address'],
      destinationAddress: json['destination']['address'],
      driver: json['driver'],
    );
  }
}
