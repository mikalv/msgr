import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/ui/widgets/inner_drawer.dart';
import 'package:messngr/ui/widgets/scaffolds/ScaffoldWithNavigationBar.dart';
import 'package:messngr/ui/widgets/scaffolds/ScaffoldWithNavigationRail.dart';

class MainScreen extends StatefulWidget {
  final StatefulNavigationShell child;

  const MainScreen({super.key, required this.child});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<InnerDrawerState> _innerDrawerKey =
      GlobalKey<InnerDrawerState>();

  final GlobalKey _keyRed = GlobalKey();
  double _width = 10;

  void _toggle() {
    _innerDrawerKey.currentState?.toggle(
        // direction is optional
        // if not set, the last direction will be used
        //InnerDrawerDirection.start OR InnerDrawerDirection.end
        direction: InnerDrawerDirection.end);
  }

  void _getwidthContainer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyContext = _keyRed.currentContext;
      if (keyContext != null) {
        final RenderObject? box = keyContext.findRenderObject();
        if (box is RenderBox) {
          final size = box.size;
          setState(() {
            _width = size.width;
          });
        }
      }
    });
  }

  @override
  void initState() {
    _getwidthContainer();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var appBar = AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => AppNavigation.router.pop(),
      ),
      iconTheme: const IconThemeData(
        color: Colors.black, //change your color here
      ),
      title: const Text('Sample'),
      centerTitle: true,
    );

    return LayoutBuilder(builder: (context, constraints) {
      /*MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DashboardControllerProvider()),
        ],widget.child.currentIndex,
        child:*/
      return (constraints.maxWidth < maxWidthBeforeSidebarNavigation)
          ? ScaffoldWithNavigationBar(
              body: GestureDetector(
                  onPanUpdate: (details) {
                    // Swiping in right direction.
                    if (details.delta.dx > 0) {
                      print('rigt swipe');
                    }

                    // Swiping in left direction.
                    if (details.delta.dx < 0) {
                      print('left swipe');
                    }
                  },
                  child: SafeArea(child: widget.child)),
              selectedIndex: widget.child.currentIndex,
              onDestinationSelected: (index) {
                widget.child.goBranch(
                  index,
                  initialLocation: index == widget.child.currentIndex,
                );
                setState(() {});
              },
            )
          : ScaffoldWithNavigationRail(
              body: GestureDetector(
                  onPanUpdate: (details) {
                    // Swiping in right direction.
                    if (details.delta.dx > 0) {
                      print('right swipe');
                    }

                    // Swiping in left direction.
                    if (details.delta.dx < 0) {
                      print('left swipe');
                    }
                  },
                  child: SafeArea(child: widget.child)),
              selectedIndex: widget.child.currentIndex,
              onDestinationSelected: (index) {
                widget.child.goBranch(
                  index,
                  initialLocation: index == widget.child.currentIndex,
                );
                setState(() {});
              },
            );
    });
  }
}
