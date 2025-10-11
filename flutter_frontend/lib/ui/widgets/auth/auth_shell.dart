import 'package:flutter/material.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.illustrationAsset,
    this.illustration,
    this.icon = Icons.lock_outline_rounded,
    this.bulletPoints = const <String>[],
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? illustrationAsset;
  final Widget? illustration;
  final IconData icon;
  final List<String> bulletPoints;
  final List<Widget>? footer;

  static const LinearGradient _backgroundGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF2E1065)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient _heroGradient = LinearGradient(
    colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color _cardColor = Color(0xFF0B1120);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: _backgroundGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth >= 880;
                  return Card(
                    elevation: 24,
                    color: _cardColor.withOpacity(0.9),
                    shadowColor: Colors.black54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 45,
                                  child: _buildHero(context, true),
                                ),
                                Expanded(
                                  flex: 55,
                                  child: _buildFormSection(context, true),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHero(context, false),
                                _buildFormSection(context, false),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, bool isWide) {
    final BorderRadius borderRadius = isWide
        ? const BorderRadius.horizontal(
            left: Radius.circular(36),
          )
        : const BorderRadius.vertical(
            top: Radius.circular(36),
          );

    final Widget? heroIllustration = illustration ??
        (illustrationAsset != null
            ? Image.asset(
                illustrationAsset!,
                height: isWide ? 220 : 200,
                fit: BoxFit.contain,
              )
            : null);

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: _heroGradient,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 36 : 28,
        vertical: isWide ? 48 : 32,
      ),
      child: Column(
        crossAxisAlignment:
            isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.shield_lock_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'messngr secure',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Sikre samtaler, levert stilfullt',
            textAlign: isWide ? TextAlign.left : TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ) ??
                const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 18),
          if (bulletPoints.isNotEmpty)
            ...bulletPoints.map(
              (text) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 18, color: Colors.white70),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (bulletPoints.isNotEmpty) const SizedBox(height: 16),
          if (heroIllustration != null)
            Padding(
              padding: EdgeInsets.only(
                top: bulletPoints.isEmpty ? 12 : 0,
              ),
              child: heroIllustration,
            ),
        ],
      ),
    );
  }

  Widget _buildFormSection(BuildContext context, bool isWide) {
    final BorderRadius borderRadius = isWide
        ? const BorderRadius.horizontal(
            right: Radius.circular(36),
          )
        : const BorderRadius.vertical(
            bottom: Radius.circular(36),
          );

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: Colors.black.withOpacity(0.35),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 48 : 28,
        vertical: isWide ? 56 : 36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ) ??
                const TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                  height: 1.5,
                ) ??
                const TextStyle(
                  color: Colors.white70,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 36),
          child,
          if (footer != null) ...[
            const SizedBox(height: 28),
            ...footer!,
          ],
        ],
      ),
    );
  }
}
