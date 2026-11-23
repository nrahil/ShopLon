import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shop/components/responsive.dart';
import 'package:shop/constants.dart';
import 'package:shop/route/screen_export.dart';
import 'package:provider/provider.dart';
import 'package:shop/providers/cart_provider.dart';

class _NavItem {
  const _NavItem(this.icon, this.label);
  final String icon;
  final String label;
}

class EntryPoint extends StatefulWidget {
  const EntryPoint({super.key});

  @override
  State<EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<EntryPoint> {
  static const _cartIndex = 3;

  static const List<_NavItem> _items = [
    _NavItem("assets/icons/Shop.svg", "Shop"),
    _NavItem("assets/icons/Category.svg", "Discover"),
    _NavItem("assets/icons/Bookmark.svg", "Bookmark"),
    _NavItem("assets/icons/Bag.svg", "Cart"),
    _NavItem("assets/icons/Profile.svg", "Profile"),
  ];

  // Each tab gets a content width that suits it on wide screens.
  static const List<Widget> _pages = [
    MaxWidthBox(maxWidth: Responsive.contentMaxWidth, child: HomeScreen()),
    MaxWidthBox(maxWidth: Responsive.readingMaxWidth, child: DiscoverScreen()),
    MaxWidthBox(
      maxWidth: Responsive.contentMaxWidth,
      child: BookmarkScreen(showAppBar: false),
    ),
    MaxWidthBox(
      maxWidth: Responsive.readingMaxWidth,
      child: CartScreen(showAppBar: false),
    ),
    MaxWidthBox(maxWidth: Responsive.readingMaxWidth, child: ProfileScreen()),
  ];

  int _currentIndex = 0;

  void _select(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  Widget _svgIcon(String src, {Color? color}) {
    final theme = Theme.of(context);
    return SvgPicture.asset(
      src,
      height: 24,
      colorFilter: ColorFilter.mode(
          color ??
              theme.iconTheme.color!.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.3 : 1),
          BlendMode.srcIn),
    );
  }

  /// Icon for nav item [index]; the cart icon carries the item-count badge.
  Widget _navIcon(int index, {required bool active}) {
    final icon =
        _svgIcon(_items[index].icon, color: active ? primaryColor : null);
    if (index != _cartIndex) return icon;
    return Consumer<CartProvider>(
      builder: (context, cart, child) => Badge(
        isLabelVisible: cart.itemCount > 0,
        label: Text(cart.itemCount.toString()),
        child: child,
      ),
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navBackground = theme.brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF101015);
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= Responsive.tabletBreakpoint;
    final extendedRail = width >= Responsive.desktopBreakpoint + 200;

    final body = PageTransitionSwitcher(
      duration: defaultDuration,
      transitionBuilder: (child, animation, secondAnimation) {
        return FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondAnimation,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_currentIndex),
        child: _pages[_currentIndex],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: const SizedBox(),
        leadingWidth: 0,
        centerTitle: false,
        title: SvgPicture.asset(
          "assets/logo/Shoplon.svg",
          colorFilter:
              ColorFilter.mode(theme.iconTheme.color!, BlendMode.srcIn),
          height: 20,
          width: 100,
        ),
        actions: [
          IconButton(
            tooltip: "Search",
            onPressed: () {
              Navigator.pushNamed(context, searchScreenRoute);
            },
            icon: SvgPicture.asset(
              "assets/icons/Search.svg",
              height: 24,
              colorFilter: ColorFilter.mode(
                  theme.textTheme.bodyLarge!.color!, BlendMode.srcIn),
            ),
          ),
          IconButton(
            tooltip: "Notifications",
            onPressed: () {
              Navigator.pushNamed(context, notificationsScreenRoute);
            },
            icon: SvgPicture.asset(
              "assets/icons/Notification.svg",
              height: 24,
              colorFilter: ColorFilter.mode(
                  theme.textTheme.bodyLarge!.color!, BlendMode.srcIn),
            ),
          ),
          if (useRail) const SizedBox(width: defaultPadding / 2),
        ],
      ),
      body: useRail
          ? Row(
              children: [
                NavigationRail(
                  backgroundColor: navBackground,
                  extended: extendedRail,
                  minExtendedWidth: 200,
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _select,
                  labelType: extendedRail
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  indicatorColor: primaryColor.withValues(alpha: 0.1),
                  selectedLabelTextStyle: const TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  unselectedLabelTextStyle: TextStyle(
                    color: theme.textTheme.bodyLarge!.color,
                    fontSize: 13,
                  ),
                  destinations: [
                    for (var i = 0; i < _items.length; i++)
                      NavigationRailDestination(
                        icon: _navIcon(i, active: false),
                        selectedIcon: _navIcon(i, active: true),
                        label: Text(_items[i].label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: useRail
          ? null
          : Container(
              padding: const EdgeInsets.only(top: defaultPadding / 2),
              color: navBackground,
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _select,
                backgroundColor: navBackground,
                type: BottomNavigationBarType.fixed,
                selectedFontSize: 12,
                selectedItemColor: primaryColor,
                unselectedItemColor: Colors.transparent,
                items: [
                  for (var i = 0; i < _items.length; i++)
                    BottomNavigationBarItem(
                      icon: _navIcon(i, active: false),
                      activeIcon: _navIcon(i, active: true),
                      label: _items[i].label,
                    ),
                ],
              ),
            ),
    );
  }
}
