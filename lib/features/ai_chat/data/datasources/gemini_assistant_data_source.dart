import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/app_constants.dart';
import '../../../../core/config/env.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../emergency/domain/entities/emergency_incident.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/ai_assistant_repository.dart';
import '../prompt_builder.dart';

/// Cliente REST de Gemini (Google AI Studio) con function calling.
///
/// Se usa la API REST directa para mantener el control total del protocolo de
/// triaje, de la voz y del contenido que se envía al modelo.
class GeminiAssistantDataSource implements AiAssistantRepository {
  GeminiAssistantDataSource({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? Env.geminiApiKey;

  final http.Client _client;
  final String _apiKey;

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  static const List<Map<String, dynamic>> _tools = [
    {
      'functionDeclarations': [
        {
          'name': 'dispatch_emergency_services',
          'description':
              'Notifica al servicio de emergencias (ambulancia y hospital) con la ubicación GPS del usuario, la gravedad y un resumen. Úsala en cuanto conozcas la emergencia; no esperes a tener todos los detalles.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'severity': {
                'type': 'STRING',
                'enum': ['low', 'moderate', 'high', 'critical'],
                'description': 'Gravedad estimada de la emergencia.',
              },
              'summary': {
                'type': 'STRING',
                'description':
                    'Resumen de una frase para el despachador: qué ocurre, edad aproximada si se conoce, estado de consciencia y respiración.',
              },
              'recommendations': {
                'type': 'ARRAY',
                'items': {'type': 'STRING'},
                'description':
                    'De 2 a 4 acciones inmediatas y seguras para el usuario.',
              },
              'needs_ambulance': {
                'type': 'BOOLEAN',
                'description':
                    'true si requiere ambulancia; false solo si requiere orientación o traslado propio.',
              },
            },
            'required': ['severity', 'summary', 'recommendations'],
          },
        },
      ],
    },
  ];

  @override
  Future<AiTurnResult> reply({
    required List<ChatMessage> history,
    required EmergencyContext context,
  }) async {
    if (!isConfigured) {
      throw const AiException(
        'Gemini no está configurado.',
        code: 'gemini_not_configured',
      );
    }

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${Env.geminiModel}:generateContent',
      {'key': _apiKey},
    );

    final body = {
      'systemInstruction': {
        'parts': [
          {'text': EmergencyPromptBuilder.systemInstruction(context)},
        ],
      },
      'contents': _buildContents(history, context),
      'tools': _tools,
      'toolConfig': {
        'functionCallingConfig': {'mode': 'AUTO'},
      },
      'generationConfig': {
        'temperature': 0.35,
        'topP': 0.9,
        'maxOutputTokens': 700,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_ONLY_HIGH',
        },
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_ONLY_HIGH',
        },
      ],
    };

    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(AppConstants.geminiTimeout);
    } on TimeoutException catch (error) {
      throw AiException(
        'El asistente está tardando en responder.',
        code: 'gemini_timeout',
        cause: error,
      );
    } catch (error) {
      throw AiException(
        'No hay conexión con el asistente de IA.',
        code: 'gemini_network',
        cause: error,
      );
    }

    if (response.statusCode != 200) {
      throw AiException(
        _errorMessage(response),
        code: 'gemini_http_${response.statusCode}',
      );
    }

    return _parse(response.body);
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
      throw AiException('Respuesta ilegible del asistente.',
          code: 'gemini_parse', cause: error);
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
    final recommendations = (args['recommendations'] as List?)
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

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final message = decoded['error']?['message'] as String?;
      if (message != null && message.isNotEmpty) {
        if (response.statusCode == 401 || response.statusCode == 403) {
          return 'La clave de Gemini no es válida. Revisa GEMINI_API_KEY.';
        }
        if (response.statusCode == 429) {
          return 'El asistente alcanzó su límite de uso. Reintenta en unos segundos.';
        }
        return 'El asistente no está disponible: $message';
      }
    } catch (_) {
      // Se usa el mensaje genérico.
    }
    return 'El asistente de IA no está disponible (HTTP ${response.statusCode}).';
  }

  void dispose() => _client.close();
}
