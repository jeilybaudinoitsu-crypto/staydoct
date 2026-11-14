import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Botón SOS con animación de pulso. Es la acción primaria de la app y
/// está disponible incluso sin iniciar sesión.
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.onPressed,
    this.size = 208,
    this.label = 'SOS',
    this.subtitle = 'Toca para pedir ayuda',
  });

  final VoidCallback onPressed;
  final double size;
  final String label;
  final String subtitle;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _pulse = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Botón de emergencia. Toca para pedir ayuda médica.',
      child: SizedBox(
        width: widget.size + 56,
        height: widget.size + 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                return Transform.scale(
                  scale: _pulse.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.emergency.withValues(alpha: 0.10),
                    ),
                  ),
                );
              },
            ),
            Container(
              width: widget.size - 26,
              height: widget.size - 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emergency.withValues(alpha: 0.16),
              ),
            ),
            Material(
              color: AppColors.emergency,
              shape: const CircleBorder(),
              elevation: 8,
              shadowColor: AppColors.emergency.withValues(alpha: 0.45),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onPressed,
                child: SizedBox(
                  width: widget.size - 62,
                  height: widget.size - 62,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sos_rounded,
                          color: Colors.white, size: 40),
                      const SizedBox(height: 6),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
