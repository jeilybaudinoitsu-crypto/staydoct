import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Burbuja de mensaje del chat de emergencia.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.isUser, required this.child});

  final bool isUser;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 14.5,
            height: 1.5,
            color: isUser ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Indicador "Vera está escribiendo…".
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Vera está escribiendo',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 7),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  children: List.generate(3, (index) {
                    final phase =
                        ((_controller.value * 3) - index).clamp(0.0, 1.0);
                    final opacity = 0.25 + (phase < 0.5 ? phase : 1 - phase);
                    return Container(
                      margin: const EdgeInsets.only(right: 3),
                      height: 5,
                      width: 5,
                      decoration: BoxDecoration(
                        color: AppColors.emergency
                            .withValues(alpha: opacity.clamp(0.2, 1.0)),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de respuestas rápidas sugeridas.
class QuickReplies extends StatelessWidget {
  const QuickReplies({
    super.key,
    required this.replies,
    required this.onSelected,
    this.enabled = true,
  });

  final List<String> replies;
  final ValueChanged<String> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: replies.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(replies[index]),
            onPressed: enabled ? () => onSelected(replies[index]) : null,
            backgroundColor: AppColors.emergencySoft,
            side: BorderSide(
              color: AppColors.emergency.withValues(alpha: 0.25),
            ),
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.emergencyDark,
            ),
          );
        },
      ),
    );
  }
}
