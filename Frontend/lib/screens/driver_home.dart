import 'package:cityride/services/authservice.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final AuthService _authService = AuthService();

  // Dynamic State
  String _firstName = "";
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _fetchDriverProfile();
  }

  /// Fetching the name from the same API as the Rider side
  Future<void> _fetchDriverProfile() async {
    try {
      final response = await _authService.getCurrentProfile();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _firstName = data['user']['firstName'] ?? "Driver";
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildStatsRow(),
            const SizedBox(height: 20),
            _buildEarningsChart(),
            const SizedBox(height: 20),
            _buildRecentTransactions(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// 1. TOP HEADER (Gradient + Dynamic Name + Toggle)
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(25, 60, 25, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF38764B), Color(0xFF1E3A28)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Driver mode",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    _firstName.isEmpty ? "Hi, Driver" : "Hi, $_firstName",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Notification Bell
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          // Online Toggle Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFC5E1A5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wifi, color: Color(0xFF1E3A28)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "You're",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        _isOnline ? "Online" : "Offline",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoSwitch(
                  value: _isOnline,
                  activeColor: const Color(0xFFC5E1A5),
                  onChanged: (val) => setState(() => _isOnline = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. STATS ROW (Daily and Weekly)
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _statCard("₦4,800", "6 trips", const Color(0xFF38764B), Colors.white),
          const SizedBox(width: 15),
          _statCard("₦28,200", "32 trips", Colors.white, Colors.black87),
        ],
      ),
    );
  }

  Widget _statCard(
    String amount,
    String trips,
    Color bgColor,
    Color textColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (bgColor == Colors.white)
              const BoxShadow(color: Colors.black12, blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              amount,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              trips,
              style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// 3. WEEKLY EARNINGS CHART
  Widget _buildEarningsChart() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [Icon(Icons.attach_money, color: Color(0xFF38764B))],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _chartBar("M", 0.4),
                _chartBar("T", 0.6),
                _chartBar("W", 0.3),
                _chartBar("T", 0.7),
                _chartBar("F", 0.9),
                _chartBar("S", 0.6),
                _chartBar("S", 1.0, isActive: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartBar(String day, double heightFactor, {bool isActive = false}) {
    return Column(
      children: [
        Container(
          height: 80 * heightFactor,
          width: 25,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF38764B) : const Color(0xFFA3C1AD),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  /// 4. RECENT TRANSACTIONS
  Widget _buildRecentTransactions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          children: [
            _transactionItem("9:12 AM", "+₦450"),
            const Divider(height: 30),
            _transactionItem("8:34 AM", "+₦700"),
          ],
        ),
      ),
    );
  }

  Widget _transactionItem(String time, String amount) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.directions_car, color: Colors.grey, size: 20),
        ),
        const SizedBox(width: 15),
        Text(time, style: const TextStyle(color: Colors.grey)),
        const Spacer(),
        Text(
          amount,
          style: const TextStyle(
            color: Color(0xFF38764B),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
