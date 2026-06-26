import 'package:cityride/theme/colors.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackgroundGray,
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _sectionCard([
            _settingTile(
              Icons.notifications_active_outlined,
              "Notifications",
              true,
              isLast: false,
            ),
            _settingTile(Icons.dark_mode_outlined, "Dark Mode", false, isLast: true),
          ]),
          const SizedBox(height: AppSpacing.md),
          _sectionCard([
            _settingTile(Icons.lock_outline, "Privacy Policy", null, isLast: false),
            _settingTile(Icons.help_outline, "Support Help", null, isLast: false),
            _settingTile(Icons.info_outline, "About CityRide", null, isLast: true),
          ]),
        ],
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Material(
          color: Colors.transparent,
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _settingTile(
    IconData icon,
    String title,
    bool? trailingSwitch, {
    required bool isLast,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title, style: AppText.body),
          trailing: trailingSwitch != null
              ? Switch(
                  value: trailingSwitch,
                  onChanged: (v) {},
                  activeTrackColor: AppColors.primary,
                )
              : const Icon(Icons.chevron_right, color: AppColors.lightGreyText),
          onTap: () {},
        ),
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}
