import 'dart:convert';
import 'package:cityride/screens/signin.dart';
import 'package:cityride/screens/verification.dart';
import 'package:cityride/services/authservice.dart';
import 'package:cityride/theme/colors.dart';
import 'package:flutter/material.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const Color green = AppColors.primaryDark;
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  String? selectedRole;
  String? selectedVehicle;
  bool _isLoading = false;

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final plateController = TextEditingController();

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    plateController.dispose();
    super.dispose();
  }

  // Handle the registration API request logic flow
  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    // Local validation for matching passwords
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match!")));
      return;
    }

    // Enforce role selection
    if (selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a profile role type")),
      );
      return;
    }

    // Enforce vehicle type selection for drivers
    if (selectedRole == "DRIVER" && selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a vehicle type")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _authService.register(
        firstName: firstNameController.text,
        lastName: lastNameController.text,
        email: emailController.text,
        phone: phoneController.text,
        password: passwordController.text,
        role: selectedRole!,
        vehicleType: selectedRole == "DRIVER" ? selectedVehicle : null,
        plateNumber: selectedRole == "DRIVER" ? plateController.text : null,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          final String? otp = jsonDecode(
            response.body,
          )['verification']?['otp'];
          if (otp != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Your verification code: $otp"),
                duration: const Duration(seconds: 6),
              ),
            );
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  VerificationScreen(email: emailController.text.trim()),
            ),
          );
        }
      } else if (response.statusCode == 409) {
        // Intercept 409 Conflict (User already exists)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "An account with this email/phone already exists. Redirecting to login...",
              ),
              duration: Duration(seconds: 2),
            ),
          );

          // Navigate to the Sign In screen and drop the registration stack
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SignInScreen()),
          );
        }
      } else {
        // Parse server error descriptions gracefully for other codes (e.g., 400, 500)
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['message'] ?? 'An error occurred during registration',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Network connection error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _roleSelector() {
    return Row(
      children: [
        Expanded(
          child: _selectableOption(
            label: "Rider",
            icon: Icons.person_outline,
            isSelected: selectedRole == "RIDER",
            onTap: () => setState(() => selectedRole = "RIDER"),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _selectableOption(
            label: "Driver",
            icon: Icons.directions_car_outlined,
            isSelected: selectedRole == "DRIVER",
            onTap: () => setState(() => selectedRole = "DRIVER"),
          ),
        ),
      ],
    );
  }

  Widget _vehicleTypeSelector() {
    const options = [
      {"value": "KEKE", "label": "Keke", "icon": Icons.motorcycle},
      {"value": "CAB", "label": "Cab", "icon": Icons.directions_car},
      {"value": "BUS", "label": "Bus", "icon": Icons.directions_bus},
    ];
    return Row(
      children: options.map((opt) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _selectableOption(
              label: opt["label"] as String,
              icon: opt["icon"] as IconData,
              isSelected: selectedVehicle == opt["value"],
              onTap: () =>
                  setState(() => selectedVehicle = opt["value"] as String),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _selectableOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? green : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? green : AppColors.borderLight,
            width: 1.4,
          ),
          boxShadow: isSelected ? AppShadows.subtle : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.darkText,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.darkText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: green,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.22,
            right: 40,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              // Top Section containing the Logo
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    Center(
                      child: SizedBox(
                        height: 120,
                        width: 180,
                        child: Image.asset(
                          "assets/cityride.png",
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),

              // Main Form Container
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.pageBackgroundAlt,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 30,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const Text(
                              "Welcome!",
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkTextAlt,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Please Sign up to enjoy our services",
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 30),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: firstNameController,
                                    decoration: const InputDecoration(
                                      labelText: "First Name",
                                      hintText: "Enter First Name",
                                    ),
                                    validator: (value) => value!.isEmpty
                                        ? "First name is required"
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: lastNameController,
                                    decoration: const InputDecoration(
                                      labelText: "Last Name",
                                      hintText: "Enter Last Name",
                                    ),
                                    validator: (value) => value!.isEmpty
                                        ? "Last name is required"
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: "Phone Number",
                                hintText: "Enter Phone",
                              ),
                              validator: (value) =>
                                  value!.isEmpty ? "Phone number is required" : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: "Email",
                                hintText: "Enter Email",
                              ),
                              validator: (value) {
                                if (value!.isEmpty) return "Email is required";
                                if (!value.contains("@")) {
                                  return "Enter a valid email address";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: "Password",
                                hintText: "Enter Password",
                              ),
                              validator: (value) => value!.length < 6
                                  ? "Password must be at least 6 characters"
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: confirmPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: "Confirm Password",
                                hintText: "Confirm Password",
                              ),
                              validator: (value) => value!.isEmpty
                                  ? "Please confirm your password"
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "I am a",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkTextAlt,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _roleSelector(),
                            if (selectedRole == "DRIVER") ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: plateController,
                                decoration: const InputDecoration(
                                  labelText: "Plate Number",
                                  hintText: "Enter Plate Number",
                                ),
                                validator: (value) =>
                                    selectedRole == "DRIVER" && value!.isEmpty
                                        ? "Plate number is required for drivers"
                                        : null,
                              ),
                              const SizedBox(height: 20),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Vehicle Type",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkTextAlt,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _vehicleTypeSelector(),
                            ],
                            const SizedBox(height: 35),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSignUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: green,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text("Sign Up"),
                              ),
                            ),
                            const SizedBox(height: 25),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Already have an account? ",
                                  style: TextStyle(color: Colors.black54),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SignInScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Sign In",
                                    style: TextStyle(
                                      color: green,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
