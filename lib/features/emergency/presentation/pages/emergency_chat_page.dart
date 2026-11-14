import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/location_service.dart';
import '../../../../core/services/phone_service.dart';
import '../../../../core/services/prefs_service.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/layout.dart';
import '../../../emergency/domain/entities/emergency_incident.dart';
import '../../../emergency/domain/repositories/emergency_repository.dart';
import '../../../ai_chat/domain/entities/chat_message.dart';
import '../../../ai_chat/domain/repositories/ai_assistant_repository.dart';
import '../../../ai_chat/presentation/controllers/emergency_chat_controller.dart';
import '../../../ai_chat/presentation/widgets/chat_widgets.dart';

/// Chat de emergencia con Vera (texto y voz).
class EmergencyChatPage extends StatefulWidget {
  const EmergencyChatPage({super.key, required this.session});

  final EmergencySession session;

  @override
  State<EmergencyChatPage> createState() => _EmergencyChatPageState();
}

class _EmergencyChatPageState extends State<EmergencyChatPage> {
  late final EmergencyChatController _controller;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _syncTimer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _controller = EmergencyChatController(
      assistant: context.read<AiAssistantRepository>(),
      emergencies: context.read<EmergencyRepository>(),
      speech: context.read<SpeechService>(),
      prefs: context.read<PrefsService>(),
      locationService: context.read<LocationService>(),
    );
    _controller.addListener(_onControllerChanged);
    _controller.initialize(widget.session);
    _controller.syncLocation();
    _syncTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _tick++;
      _controller.refreshIncident();
      if (_tick % 2 == 0) _controller.syncLocation();
    });
  }

  void _onControllerChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await _controller.sendMessage(text);
  }

  Future<void> _dispatchNow() async {
    await _controller.dispatchNow();
    if (!mounted) return;
    final error = _controller.error;
    if (error != null && !_controller.isDispatched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EmergencyChatController>.value(
      value: _controller,
      child: Consumer<EmergencyChatController>(
        builder: (context, controller, _) {
          final incident = controller.incident;
          if (incident == null) {
            return const Scaffold(body: AppLoader(label: 'Preparando asistente…'));
          }

          return Scaffold(
            appBar: AppBar(
              titleSpacing: 0,
              title: Row(
                children: [
                  _VeraAvatar(online: !controller.isSending),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Vera'),
                      Text(
                        controller.isSending
                            ? 'Escribiendo…'
                            : 'Asistente de emergencias',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: controller.voiceRepliesEnabled
                      ? 'Silenciar a Vera'
                      : 'Activar voz',
                  onPressed: controller.toggleVoiceReplies,
                  icon: Icon(
                    controller.voiceRepliesEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Llamar al 123',
                  onPressed: () =>
                      context.read<PhoneService>().callEmergencyLine(),
                  icon: const Icon(Icons.phone_in_talk_rounded,
                      color: AppColors.emergency),
                ),
              ],
            ),
            body: Column(
              children: [
                _StatusHeader(
                  incident: incident,
                  isDispatching: controller.isDispatching,
                  onDispatch: _dispatchNow,
                  onTrack: () {
                    final session = controller.session;
                    if (session == null) return;
                    context.push('/emergencia/seguimiento', extra: session);
                  },
                ),
                _LocationStrip(
                  incident: incident,
                  lastSync: controller.lastLocationSync,
                  onRefresh: () => controller.syncLocation(silent: false),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    itemCount: controller.messages.length +
                        (controller.isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= controller.messages.length) {
                        return const TypingIndicator();
                      }
                      final message = controller.messages[index];
                      return _MessageView(message: message);
                    },
                  ),
                ),
                if (controller.messages.length <= 2 && !controller.isSending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: QuickReplies(
                      enabled: !controller.isBusy,
                      replies: const [
                        'Me duele el pecho',
                        'No puede respirar',
                        'Está sangrando',
                        'Se desmayó',
                      ],
                      onSelected: (reply) =>
                          controller.sendMessage(reply),
                    ),
                  ),
                if (controller.isListening)
                  Container(
                    width: double.infinity,
                    color: AppColors.emergencySoft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.graphic_eq_rounded,
                            size: 17, color: AppColors.emergency),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            controller.partialTranscript == null ||
                                    controller.partialTranscript!.isEmpty
                                ? 'Escuchando…'
                                : controller.partialTranscript!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emergencyDark,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: controller.stopListening,
                          child: const Text('Detener'),
                        ),
                      ],
                    ),
                  ),
                if (controller.error != null && !controller.isListening)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: ErrorBanner(message: controller.error!),
                  ),
                if (!controller.isDispatched)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: PrimaryButton(
                      label: controller.isDispatching
                          ? 'Notificando…'
                          : 'Notificar ayuda ahora',
                      icon: Icons.emergency_share_rounded,
                      backgroundColor: AppColors.emergency,
                      isLoading: controller.isDispatching,
                      height: 48,
                      onPressed: controller.isDispatching ? null : _dispatchNow,
                    ),
                  ),
                _InputBar(
                  controller: _input,
                  isListening: controller.isListening,
                  isSending: controller.isSending,
                  onSend: _send,
                  onMic: controller.sendVoiceMessage,
                  onStopListening: controller.stopListening,
                  onRepeat: controller.repeatLastGuidance,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VeraAvatar extends StatelessWidget {
  const _VeraAvatar({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: AppColors.emergencySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.health_and_safety_rounded,
              color: AppColors.emergency, size: 20),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            height: 9,
            width: 9,
            decoration: BoxDecoration(
              color: online ? AppColors.mint : AppColors.amber,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({
    required this.incident,
    required this.isDispatching,
    required this.onDispatch,
    required this.onTrack,
  });

  final EmergencyIncident incident;
  final bool isDispatching;
  final VoidCallback onDispatch;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final dispatched = incident.status.isDispatched;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dispatched ? AppColors.mintSoft : AppColors.amberSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            dispatched ? Icons.local_shipping_rounded : Icons.hourglass_top_rounded,
            color: dispatched ? AppColors.mint : AppColors.amber,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dispatched ? 'Ayuda en camino' : 'Preparando el despacho',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: dispatched
                        ? AppColors.mint
                        : const Color(0xFF9A6412),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dispatched
                      ? (incident.hospital?.name ??
                          'El centro de despacho asignará una ambulancia.')
                      : 'Vera notificará automáticamente. Si no puedes escribir, pulsa el botón rojo.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: (dispatched ? AppColors.mint : AppColors.amber)
                        .withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (dispatched)
            TextButton(
              onPressed: onTrack,
              style: TextButton.styleFrom(foregroundColor: AppColors.mint),
              child: const Text('Ver'),
            )
          else if (!isDispatching)
            TextButton(
              onPressed: onDispatch,
              style: TextButton.styleFrom(foregroundColor: AppColors.emergency),
              child: const Text('Ahora'),
            ),
        ],
      ),
    );
  }
}

class _LocationStrip extends StatelessWidget {
  const _LocationStrip({
    required this.incident,
    required this.lastSync,
    required this.onRefresh,
  });

  final EmergencyIncident incident;
  final DateTime? lastSync;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final hasLocation = incident.hasCoordinates;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            hasLocation ? Icons.location_on_rounded : Icons.location_off_rounded,
            size: 16,
            color: hasLocation ? AppColors.mint : AppColors.amber,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hasLocation
                  ? (incident.address ??
                      Formatters.coordinates(
                        incident.latitude!,
                        incident.longitude!,
                      ))
                  : 'Ubicación pendiente · activa el GPS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (lastSync != null)
            Text(
              'act. ${Formatters.time(lastSync!)}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          IconButton(
            onPressed: onRefresh,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            tooltip: 'Actualizar ubicación',
          ),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    switch (message.role) {
      case ChatRole.user:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (message.isVoice)
              const Padding(
                padding: EdgeInsets.only(right: 6, bottom: 18),
                child: Icon(Icons.mic_rounded,
                    size: 14, color: AppColors.textTertiary),
              ),
            Flexible(
              child: ChatBubble(
                isUser: true,
                child: Text(message.content),
              ),
            ),
          ],
        );
      case ChatRole.assistant:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4, right: 8),
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: AppColors.emergencySoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.health_and_safety_rounded,
                  color: AppColors.emergency, size: 16),
            ),
            Flexible(
              child: ChatBubble(
                isUser: false,
                child: Text(message.content),
              ),
            ),
          ],
        );
      case ChatRole.system:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: message.isError ? AppColors.dangerSoft : AppColors.mintSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (message.isError ? AppColors.emergency : AppColors.mint)
                  .withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                message.isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 19,
                color:
                    message.isError ? AppColors.emergency : AppColors.mint,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: message.isError
                        ? AppColors.emergencyDark
                        : const Color(0xFF0C6B58),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isListening,
    required this.isSending,
    required this.onSend,
    required this.onMic,
    required this.onStopListening,
    required this.onRepeat,
  });

  final TextEditingController controller;
  final bool isListening;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onMic;
  final VoidCallback onStopListening;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: isSending ? null : (isListening ? onStopListening : onMic),
              tooltip: isListening ? 'Detener' : 'Hablar',
              style: IconButton.styleFrom(
                backgroundColor:
                    isListening ? AppColors.emergency : AppColors.emergencySoft,
                foregroundColor:
                    isListening ? Colors.white : AppColors.emergency,
                minimumSize: const Size(46, 46),
              ),
              icon: Icon(isListening ? Icons.stop_rounded : Icons.mic_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isSending,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Escribe o dicta tu mensaje…',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: isSending ? null : onRepeat,
              tooltip: 'Repetir última indicación',
              icon: const Icon(Icons.replay_rounded,
                  size: 20, color: AppColors.textSecondary),
            ),
            IconButton.filled(
              onPressed: isSending ? null : onSend,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.navy,
                minimumSize: const Size(46, 46),
              ),
              icon: const Icon(Icons.send_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}
