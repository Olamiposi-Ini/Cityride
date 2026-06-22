import 'package:cityride/models/ride_model.dart';
import 'package:flutter/material.dart';

class ActiveRideWidget extends StatelessWidget {
  final Ride ride;
  final VoidCallback onCancel;

  const ActiveRideWidget({
    super.key,
    required this.ride,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    bool isAccepted = ride.status != 'pending';

    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          Text(
            isAccepted ? "Driver is on the way!" : "Waiting for a driver...",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF147D44),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey[200],
              child: Icon(
                isAccepted ? Icons.person : Icons.hourglass_empty,
                color: Colors.grey,
              ),
            ),
            title: Text(
              isAccepted
                  ? "${ride.driver!['firstName']} ${ride.driver!['lastName']}"
                  : "Searching...",
            ),
            subtitle: Text(
              isAccepted
                  ? "Rating: 4.8 ★"
                  : "We are connecting you to the best driver",
            ),
            trailing: isAccepted
                ? IconButton(
                    icon: const Icon(Icons.phone, color: Color(0xFF147D44)),
                    onPressed: () {},
                  )
                : null,
          ),
          const Divider(),
          _infoRow("From", ride.pickupAddress),
          _infoRow("To", ride.destinationAddress),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              "Cancel Ride",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
