import 'package:cityride/screens/splash.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // const String accessToken =
  //     "sk.eyJ1Ijoib2xhbWlwb3NpIiwiYSI6ImNtcWt4NGQzczBsNmkycXM2N3ZzeW5wbXgifQ.M5srKwUWJqvNZ_KjSCSd2Q";
  // MapboxOptions.setAccessToken(accessToken);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: SplashScreen());
  }
}
