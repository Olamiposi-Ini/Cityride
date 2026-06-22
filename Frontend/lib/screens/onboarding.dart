import 'package:cityride/screens/signup.dart';
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  static const Color _green = Color(0xFF0F7543);
  static const Color _bgTop = Color(0xFFEDFAF2);
  static const Color _textDark = Color(0xFF0A1C2A);
  static const Color _textGrey = Color(0xFF7A868F);

  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      title: "Fast rides across\nRedemption City",
      description:
          "Book reliable local drivers, track them in real time, and pay easily.",
    ),
    _OnboardingData(
      title: "Real time tracking,\nalways",
      description:
          "See your driver moving on the map, share your trip, and arrive with peace of mind.",
    ),
    _OnboardingData(
      title: "Reliable Local Drivers",
      description:
          "Every CityRide driver is verified by the community. Friendly faces from your own neighborhood.",
    ),
  ];

  void _goToSignUp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SignUpScreen()),
    );
  }

  void _next() {
    if (_currentIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _goToSignUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Dynamic Top Gradient Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.58,
            child: Container(color: _bgTop),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Header Action Row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: TextButton(
                      onPressed: _goToSignUp,
                      child: const Text(
                        "Skip",
                        style: TextStyle(
                          color: _green,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                // Interactive Slide Content (Graphics + Dynamic Texts)
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            // Map Canvas container with strictly controlled overflows allowed
                            Center(
                              child: index == 0
                                  ? const _ScreenOneGraphic()
                                  : _SingleGraphic(pageIndex: index),
                            ),
                            const Spacer(),
                            Text(
                              page.title,
                              style: const TextStyle(
                                color: _textDark,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              page.description,
                              style: const TextStyle(
                                color: _textGrey,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Footer Control Elements
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          _pages.length,
                          (i) => _Indicator(isActive: i == _currentIndex),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Continue",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenOneGraphic extends StatelessWidget {
  const _ScreenOneGraphic();

  @override
  Widget build(BuildContext context) {
    const double mapWidth = 400.0;
    const double mapHeight = 350.0;

    return SizedBox(
      width: mapWidth,
      height: mapHeight,
      child: Stack(
        clipBehavior:
            Clip.none, // Allows cards to overflow layout bounds perfectly
        children: [
          // Base Map Layer
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/map1.png', fit: BoxFit.cover),
            ),
          ),

          // "2k riders today" pill — Top Right area
          Positioned(
            top: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 18,
                    color: Color(0xFF0F7543),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '2k riders today',
                    style: TextStyle(
                      color: Color(0xFF0A1C2A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Keke Float Card — Pops out below the bottom of the map view bounds
          Positioned(
            bottom: -50,
            left: 32,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/keke.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.electric_bike, color: Colors.white),
              ),
            ),
          ),

          // Cab Float Card — Placed higher up and shifts left to overlap the bottom-left corner of the cab over the Keke card
          Positioned(
            bottom: -20,
            left:
                145, // Adjusted to overlap the Keke container precisely on the left
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/cab.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.local_taxi, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SingleGraphic extends StatelessWidget {
  final int pageIndex;
  const _SingleGraphic({required this.pageIndex});

  @override
  Widget build(BuildContext context) {
    final asset = pageIndex == 1 ? 'assets/map 2.png' : 'assets/map 3.png';
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.asset(
        asset,
        width: 400,
        height: 310,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 400,
          height: 310,
          color: Colors.grey.shade300,
          child: const Icon(Icons.map, size: 48, color: Colors.grey),
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  final bool isActive;
  const _Indicator({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 6),
      height: 6,
      width: isActive ? 20 : 6,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF0F7543) : const Color(0xFFC4D1C9),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _OnboardingData {
  final String title;
  final String description;
  const _OnboardingData({required this.title, required this.description});
}
