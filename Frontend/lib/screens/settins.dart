import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: const Color(0xFF147D44),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          _settingTile(
            Icons.notifications_active_outlined,
            "Notifications",
            true,
          ),
          _settingTile(Icons.dark_mode_outlined, "Dark Mode", false),
          const Divider(),
          _settingTile(Icons.lock_outline, "Privacy Policy", null),
          _settingTile(Icons.help_outline, "Support Help", null),
          _settingTile(Icons.info_outline, "About CityRide", null),
        ],
      ),
    );
  }

  Widget _settingTile(IconData icon, String title, bool? trailingSwitch) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF147D44)),
      title: Text(title),
      trailing: trailingSwitch != null
          ? Switch(
              value: trailingSwitch,
              onChanged: (v) {},
              activeColor: const Color(0xFF147D44),
            )
          : const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}
