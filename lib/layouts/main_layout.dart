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

class _MainLayoutState extends State<MainLayout> {
  bool _isPanelVisible = true;
  bool? _previousIsMobile;

  @override
  Widget build(BuildContext context) {
    // Detect if mobile
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Auto-hide panel when switching to mobile view
    if (_previousIsMobile != null && _previousIsMobile != isMobile) {
      if (isMobile) {
        _isPanelVisible = false;
      } else {
        _isPanelVisible = true;
      }
    }
    _previousIsMobile = isMobile;

    // Calculate panel width
    final panelWidth = isMobile
        ? (_isPanelVisible ? 280.0 : 0.0)
        : (_isPanelVisible ? 256.0 : 64.0);

    return Scaffold(
      body: Stack(
        clipBehavior: Clip.none, // Allow children to overflow
        children: [
          // Main content area with padding for left panel
          AnimatedPadding(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.only(
              left: isMobile ? 0 : panelWidth,
            ),
            child: widget.child,
          ),

          // Mobile backdrop (when panel is open)
          if (isMobile && _isPanelVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: _togglePanel,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isPanelVisible ? 1.0 : 0.0,
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
              ),
            ),

          // Left navigation panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            left: isMobile && !_isPanelVisible ? -280.0 : 0,
            width: isMobile ? 280.0 : panelWidth,
            child: Material(
              elevation: 8,
              child: LeftPanel(
                isPanelVisible: _isPanelVisible,
                isMobile: isMobile,
                togglePanel: _togglePanel,
              ),
            ),
          ),

          // Desktop toggle button (OUTSIDE panel to avoid clipping)
          if (!isMobile)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: MediaQuery.of(context).size.height / 2 - 16,
              left: panelWidth - 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).cardColor,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _togglePanel,
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    child: Icon(
                      _isPanelVisible ? Icons.chevron_left : Icons.chevron_right,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),

          // Mobile hamburger menu button (ALWAYS visible when panel closed)
          if (isMobile && !_isPanelVisible)
            Positioned(
              top: 16,
              left: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).cardColor,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _togglePanel,
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: const Icon(Icons.menu, size: 24),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _togglePanel() {
    setState(() {
      _isPanelVisible = !_isPanelVisible;
    });
  }
}

