import 'package:flutter_test/flutter_test.dart';
import 'package:staydoct/features/ai_chat/data/prompt_builder.dart';
import 'package:staydoct/features/ai_chat/domain/entities/chat_message.dart';

void main() {
  test('Gemini prompt does not include precise location data', () {
    const context = EmergencyContext(
      description: 'Dolor de pecho',
      address: 'Calle de prueba 123',
      latitude: 4.711,
      longitude: -74.0721,
    );

    final prompt = EmergencyPromptBuilder.systemInstruction(context);

    expect(prompt, contains('compartida con el servicio de emergencias'));
    expect(prompt, isNot(contains('Calle de prueba 123')));
    expect(prompt, isNot(contains('4.711')));
    expect(prompt, isNot(contains('-74.0721')));
  });
}
