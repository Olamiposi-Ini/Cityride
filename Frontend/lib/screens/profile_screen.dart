import 'dart:convert';
import 'package:cityride/screens/signin.dart';
import 'package:cityride/services/rideservice.dart';
import 'package:cityride/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:cityride/services/authservice.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final RideService _rideService = RideService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await _authService.getCurrentProfile();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userData = data['user'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load profile")));
    }
  }

  Future<void> _openEditSheet() async {
    final bool isDriver = _userData?['role'] == 'DRIVER';
    final driverInfo = _userData?['driver'] as Map<String, dynamic>?;

    final firstNameController = TextEditingController(
      text: _userData?['firstName'] ?? '',
    );
    final lastNameController = TextEditingController(
      text: _userData?['lastName'] ?? '',
    );
    final phoneController = TextEditingController(
      text: _userData?['phone'] ?? '',
    );
    final plateController = TextEditingController(
      text: driverInfo?['plateNumber'] ?? '',
    );
    String? selectedVehicle = driverInfo?['vehicleType'];
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Edit Profile",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: firstNameController,
                      decoration: const InputDecoration(labelText: "First Name"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lastNameController,
                      decoration: const InputDecoration(labelText: "Last Name"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: "Phone"),
                    ),
                    if (isDriver) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: plateController,
                        decoration: const InputDecoration(
                          labelText: "Plate Number",
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Vehicle Type",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          {'value': 'KEKE', 'label': 'Keke', 'icon': Icons.motorcycle},
                          {'value': 'CAB', 'label': 'Cab', 'icon': Icons.directions_car},
                          {'value': 'BUS', 'label': 'Bus', 'icon': Icons.directions_bus},
                        ].map((opt) {
                          final bool isSelected = selectedVehicle == opt['value'];
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: GestureDetector(
                                onTap: () => setSheetState(
                                  () => selectedVehicle = opt['value'] as String,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.cardFill,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        opt['icon'] as IconData,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black54,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        opt['label'] as String,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setSheetState(() => isSaving = true);
                                try {
                                  await _authService.updateProfile(
                                    firstName: firstNameController.text.trim(),
                                    lastName: lastNameController.text.trim(),
                                    phone: phoneController.text.trim(),
                                  );
                                  if (isDriver) {
                                    await _rideService.updateDriverProfile(
                                      vehicleType: selectedVehicle,
                                      plateNumber:
                                          plateController.text.trim(),
                                    );
                                  }
                                  if (context.mounted) Navigator.pop(context);
                                  _loadProfile();
                                } catch (e) {
                                  debugPrint("Update Profile Error: $e");
                                  setSheetState(() => isSaving = false);
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Save Changes"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDriver = _userData?['role'] == 'DRIVER';
    final driverInfo = _userData?['driver'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: AppColors.pageBackgroundGray,
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _isLoading ? null : _openEditSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      const CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.cardFill,
                        child: Icon(
                          Icons.person,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _openEditSheet,
                          child: Container(
                            height: 32,
                            width: 32,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(color: Colors.white, width: 2),
                              ),
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    "${_userData?['firstName'] ?? ''} ${_userData?['lastName'] ?? ''}"
                        .trim(),
                    style: AppText.h1.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 2),
                  Text(_userData?['email'] ?? "", style: AppText.bodyMuted),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      children: [
                        _profileItem(
                          Icons.badge_outlined,
                          "First Name",
                          _userData?['firstName'] ?? "N/A",
                        ),
                        _profileItem(
                          Icons.badge_outlined,
                          "Last Name",
                          _userData?['lastName'] ?? "N/A",
                        ),
                        _profileItem(
                          Icons.phone_outlined,
                          "Phone",
                          _userData?['phone'] ?? "N/A",
                        ),
                        _profileItem(
                          Icons.verified_user_outlined,
                          "Role",
                          _userData?['role'] ?? "RIDER",
                          isLast: !isDriver,
                        ),
                        if (isDriver) ...[
                          _profileItem(
                            Icons.directions_car_outlined,
                            "Vehicle Type",
                            driverInfo?['vehicleType'] ?? "N/A",
                          ),
                          _profileItem(
                            Icons.pin_outlined,
                            "Plate Number",
                            driverInfo?['plateNumber'] ?? "N/A",
                          ),
                          _profileItem(
                            Icons.star_outline,
                            "Rating",
                            driverInfo?['ratingAverage'] != null
                                ? "${driverInfo?['ratingAverage']} ★ (${driverInfo?['ratingCount'] ?? 0})"
                                : "New",
                            isLast: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await _authService.logout();
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignInScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                      ),
                      child: const Text("Logout"),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _profileItem(
    IconData icon,
    String title,
    String value, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.lightGreyText),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppText.bodyMuted),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 48, endIndent: 16),
      ],
    );
  }
}
