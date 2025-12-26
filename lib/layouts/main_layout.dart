import 'package:flutter/material.dart';
import '../widgets/left_panel/left_panel.dart';

/// Main layout wrapper that includes the left panel navigation
/// Similar to ClientLayout in React version
class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({
    super.key,
    required this.child,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _isPanelVisible = true;
  bool? _previousIsMobile;

  // Swipe tracking for mobile
  double _dragStartX = 0;
  double _currentDragX = 0;
  bool _isDragging = false;

  static const double _mobileDrawerWidth = 300.0;
  static const double _desktopExpandedWidth = 256.0;
  static const double _desktopCollapsedWidth = 64.0;
  static const double _edgeSwipeAreaWidth = 32.0; // Larger area for easier edge swipe
  static const double _swipeThreshold = 100.0; // Slightly larger threshold

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Initialize controller state based on initial panel visibility
    if (_isPanelVisible) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _togglePanel() {
    setState(() {
      _isPanelVisible = !_isPanelVisible;
    });

    if (_isPanelVisible) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _openPanel() {
    if (!_isPanelVisible) {
      setState(() => _isPanelVisible = true);
      _animationController.forward();
    }
  }

  void _closePanel() {
    if (_isPanelVisible) {
      setState(() => _isPanelVisible = false);
      _animationController.reverse();
    }
  }

  // Handle swipe gestures for mobile
  void _onHorizontalDragStart(DragStartDetails details, bool isMobile) {
    if (!isMobile) return;

    final startX = details.globalPosition.dx;

    // Allow swipe from left edge to open, or anywhere when panel is open to close
    if (!_isPanelVisible && startX <= _edgeSwipeAreaWidth) {
      _isDragging = true;
      _dragStartX = startX;
      _currentDragX = 0;
    } else if (_isPanelVisible && startX <= _mobileDrawerWidth + 50) {
      _isDragging = true;
      _dragStartX = startX;
      _currentDragX = _mobileDrawerWidth;
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, bool isMobile) {
    if (!isMobile || !_isDragging) return;

    final delta = details.globalPosition.dx - _dragStartX;

    if (!_isPanelVisible) {
      // Opening: drag from left edge
      _currentDragX = delta.clamp(0, _mobileDrawerWidth);
    } else {
      // Closing: drag from open position
      _currentDragX = (_mobileDrawerWidth + delta).clamp(0, _mobileDrawerWidth);
    }

    // Update animation controller based on drag position
    _animationController.value = _currentDragX / _mobileDrawerWidth;
    setState(() {});
  }

  void _onHorizontalDragEnd(DragEndDetails details, bool isMobile) {
    if (!isMobile || !_isDragging) return;

    _isDragging = false;
    final velocity = details.velocity.pixelsPerSecond.dx;

    // Determine whether to open or close based on velocity and position
    if (velocity > 500) {
      // Fast swipe right -> open
      _openPanel();
    } else if (velocity < -500) {
      // Fast swipe left -> close
      _closePanel();
    } else {
      // Slow drag -> check position threshold
      if (_currentDragX > _swipeThreshold) {
        _openPanel();
      } else {
        _closePanel();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final colorScheme = Theme.of(context).colorScheme;

    // Auto-hide/show panel when switching between mobile/desktop
    if (_previousIsMobile != null && _previousIsMobile != isMobile) {
      if (isMobile) {
        _isPanelVisible = false;
        _animationController.value = 0;
      } else {
        _isPanelVisible = true;
        _animationController.value = 1;
      }
    }
    _previousIsMobile = isMobile;

    // Calculate panel width for desktop
    final desktopPanelWidth = _isPanelVisible ? _desktopExpandedWidth : _desktopCollapsedWidth;

    return Scaffold(
      body: GestureDetector(
        // Handle swipe gestures on the entire screen for mobile
        onHorizontalDragStart: (details) => _onHorizontalDragStart(details, isMobile),
        onHorizontalDragUpdate: (details) => _onHorizontalDragUpdate(details, isMobile),
        onHorizontalDragEnd: (details) => _onHorizontalDragEnd(details, isMobile),
        child: Stack(
          children: [
            // Main content area
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: isMobile ? 0 : desktopPanelWidth,
                  ),
                  child: widget.child,
                );
              },
            ),

            // Mobile: Dark overlay when drawer is open
            if (isMobile)
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  if (_fadeAnimation.value <= 0.01) {
                    return const SizedBox.shrink();
                  }
                  return Positioned.fill(
                    child: GestureDetector(
                      onTap: _closePanel,
                      child: Container(
                        color: Colors.black.withAlpha((_fadeAnimation.value * 255).round()),
                      ),
                    ),
                  );
                },
              ),

            // Left navigation panel
            if (isMobile)
              _buildMobileDrawer(colorScheme)
            else
              _buildDesktopPanel(desktopPanelWidth, colorScheme),

            // Mobile: Edge arrow toggle button
            if (isMobile)
              _buildMobileEdgeToggle(colorScheme),

            // Desktop: Toggle button on panel edge
            if (!isMobile)
              _buildDesktopToggle(desktopPanelWidth, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        final slideOffset = (_slideAnimation.value - 1) * _mobileDrawerWidth;

        return Positioned(
          top: 0,
          bottom: 0,
          left: slideOffset,
          width: _mobileDrawerWidth,
          child: Material(
            elevation: 16,
            shadowColor: Colors.black38,
            child: LeftPanel(
              isPanelVisible: true, // Always show full content in mobile drawer
              isMobile: true,
              togglePanel: _closePanel,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopPanel(double panelWidth, ColorScheme colorScheme) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      left: 0,
      width: panelWidth,
      child: Material(
        elevation: 4,
        child: LeftPanel(
          isPanelVisible: _isPanelVisible,
          isMobile: false,
          togglePanel: _togglePanel,
        ),
      ),
    );
  }

  Widget _buildMobileEdgeToggle(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        // Position the toggle at the edge of the drawer or at the screen edge
        final drawerEdge = _slideAnimation.value * _mobileDrawerWidth;
        final buttonLeft = drawerEdge - 12; // Slightly overlap the edge

        // Rotate the arrow based on panel state
        final rotation = _slideAnimation.value * 3.14159; // 180 degrees

        // Use card color (same as left panel) when panel is open, primary container when closed
        final cardColor = Theme.of(context).cardColor;
        final buttonColor = Color.lerp(
          colorScheme.primaryContainer,
          cardColor,
          _slideAnimation.value,
        )!;

        // Adjust icon color based on background
        final iconColor = Color.lerp(
          colorScheme.onPrimaryContainer,
          colorScheme.onSurface,
          _slideAnimation.value,
        )!;

        return Positioned(
          top: MediaQuery.of(context).size.height / 2 - 24,
          left: buttonLeft.clamp(0, _mobileDrawerWidth - 12),
          child: GestureDetector(
            onTap: _togglePanel,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 48,
              decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withAlpha(
                      (40 * (1 - _slideAnimation.value * 0.5)).round(),
                    ),
                    blurRadius: 8,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: Center(
                child: Transform.rotate(
                  angle: rotation,
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopToggle(double panelWidth, ColorScheme colorScheme) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      top: MediaQuery.of(context).size.height / 2 - 20,
      left: panelWidth - 14,
      child: GestureDetector(
        onTap: _togglePanel,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outlineVariant.withAlpha(100),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withAlpha(30),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Center(
              child: AnimatedRotation(
                turns: _isPanelVisible ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper widget for listening to animations
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}

