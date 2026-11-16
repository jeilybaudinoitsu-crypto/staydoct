import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../emergency/domain/entities/emergency_incident.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/ai_assistant_repository.dart';
import '../prompt_builder.dart';

/// Invoca la función backend que llama a Gemini con function calling.
class GeminiAssistantDataSource implements AiAssistantRepository {
  GeminiAssistantDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<AiTurnResult> reply({
    required List<ChatMessage> history,
    required EmergencyContext context,
  }) async {
    final incidentId = context.incidentId;
    final accessToken = context.accessToken;
    if (incidentId == null || accessToken == null) {
      throw const AiException(
        'No pudimos validar la sesión de emergencia para usar el asistente.',
        code: 'gemini_missing_emergency_access',
      );
    }

    try {
      final response = await _client.functions
          .invoke(
            'gemini-assistant',
            body: {
              'incident_id': incidentId,
              'access_token': accessToken,
              'system_instruction': EmergencyPromptBuilder.systemInstruction(
                context,
              ),
              'contents': _buildContents(history, context),
            },
          )
          .timeout(const Duration(seconds: 35));
      final rawBody = response.data is String
          ? response.data as String
          : jsonEncode(response.data);
      return _parse(rawBody);
    } on AiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw AiException(
        'Gemini tardó demasiado en responder. Intenta de nuevo o llama al 123.',
        code: 'gemini_timeout',
        cause: error,
      );
    } catch (error) {
      throw AiException(
        'No se pudo conectar con Gemini. Verifica tu conexión y que la función '
        'gemini-assistant esté desplegada en Supabase.',
        code: 'gemini_request_failed',
        cause: error,
      );
    }
  }

  List<Map<String, dynamic>> _buildContents(
    List<ChatMessage> history,
    EmergencyContext context,
  ) {
    final conversational = history
        .where((message) => message.role != ChatRole.system)
        .toList(growable: true);

    // Gemini exige que el primer turno sea del usuario.
    while (conversational.isNotEmpty &&
        conversational.first.role != ChatRole.user) {
      conversational.removeAt(0);
    }

    if (conversational.isEmpty) {
      conversational.add(
        ChatMessage(
          id: 'seed',
          role: ChatRole.user,
          content:
              'Tengo una emergencia: ${context.description}. Necesito ayuda ahora.',
          createdAt: DateTime.now(),
        ),
      );
    }

    return conversational
        .map(
          (message) => {
            'role': message.role == ChatRole.user ? 'user' : 'model',
            'parts': [
              {'text': message.content},
            ],
          },
        )
        .toList();
  }

  AiTurnResult _parse(String rawBody) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(rawBody) as Map<String, dynamic>;
    } catch (error) {
      throw AiException(
        'Respuesta ilegible del asistente.',
        code: 'gemini_parse',
        cause: error,
      );
    }

    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      final blocked = data['promptFeedback']?['blockReason'] as String?;
      throw AiException(
        blocked == null
            ? 'El asistente no devolvió una respuesta.'
            : 'El asistente no pudo responder por filtros de seguridad.',
        code: 'gemini_blocked',
      );
    }

    final parts =
        (candidates.first['content'] as Map?)?['parts'] as List? ?? const [];
    final buffer = StringBuffer();
    AiDispatchRequest? dispatchRequest;

    for (final part in parts.whereType<Map>()) {
      final text = part['text'] as String?;
      if (text != null && text.trim().isNotEmpty) {
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(text.trim());
      }

      final functionCall = part['functionCall'] as Map?;
      if (functionCall != null &&
          functionCall['name'] == 'dispatch_emergency_services') {
        dispatchRequest = _dispatchFromArgs(
          (functionCall['args'] as Map?)?.cast<String, dynamic>() ?? const {},
        );
      }
    }

    if (buffer.isEmpty && dispatchRequest == null) {
      throw const AiException(
        'El asistente no devolvió contenido útil.',
        code: 'gemini_empty',
      );
    }

    return AiTurnResult(
      text: buffer.toString().trim(),
      dispatchRequest: dispatchRequest,
    );
  }

  AiDispatchRequest _dispatchFromArgs(Map<String, dynamic> args) {
    final recommendations =
        (args['recommendations'] as List?)
            ?.map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .take(5)
            .toList() ??
        const <String>[];

    final summary = (args['summary'] as String?)?.trim();
    return AiDispatchRequest(
      severity: SeverityLevel.fromDb(args['severity'] as String?),
      summary: (summary == null || summary.isEmpty)
          ? 'Emergencia reportada desde la app Staydoct.'
          : summary,
      recommendations: recommendations.isEmpty
          ? const ['Mantén la calma y no dejes sola a la persona.']
          : recommendations,
      needsAmbulance: args['needs_ambulance'] as bool? ?? true,
    );
  }
}
