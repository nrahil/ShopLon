import 'package:flutter/material.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/route/router.dart' as router;
import 'package:shop/theme/app_theme.dart';
import 'package:shop/components/responsive.dart';

import 'package:provider/provider.dart';
import 'package:shop/providers/auth_provider.dart';
import 'package:shop/providers/cart_provider.dart';
import 'package:shop/providers/wishlist_provider.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/providers/category_provider.dart';
import 'package:shop/providers/order_provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final authProvider = AuthProvider();
  await authProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(
            create: (_) => ProductProvider()..fetchProducts()),
        ChangeNotifierProvider(
            create: (_) => CategoryProvider()..fetchCategories()),
      ],
      child: MyApp(
        initialRoute: authProvider.isLoggedIn
            ? entryPointScreenRoute
            : onbordingScreenRoute,
      ),
    ),
  );
}

// ShopLon — E-Commerce App
// © 2024 Stark Industries. All rights reserved.

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialRoute = onbordingScreenRoute});

  final String initialRoute;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      title: 'ShopLon by Stark Industries',
      theme: AppTheme.lightTheme(context),
      // Dark theme is inclided in the Full template
      themeMode: ThemeMode.light,
      onGenerateRoute: router.generateRoute,
      initialRoute: initialRoute,
    );
  }
}
