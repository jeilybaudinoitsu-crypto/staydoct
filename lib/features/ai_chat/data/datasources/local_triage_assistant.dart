import '../../../emergency/domain/entities/emergency_incident.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/ai_assistant_repository.dart';

/// Protocolo local de respaldo, basado en reglas.
///
/// Se usa cuando Gemini no está configurado o no hay conectividad. Garantiza
/// que el usuario SIEMPRE reciba contención, primeros auxilios básicos y el
/// despacho automático de ayuda. No sustituye al modelo: es una red de
/// seguridad operativa.
class LocalTriageAssistant implements AiAssistantRepository {
  @override
  Future<AiTurnResult> reply({
    required List<ChatMessage> history,
    required EmergencyContext context,
  }) async {
    final userMessages = history
        .where((message) => message.role == ChatRole.user)
        .map((message) => message.content)
        .toList();

    final text = userMessages.isEmpty
        ? context.description
        : userMessages.last;

    final category = _classify(text);
    final severity = category.severity;
    final userTurns = userMessages.length;

    final willDispatch = !context.alreadyDispatched && userTurns >= 1;

    final response = <String>[
      'Estoy contigo. Respira profundo conmigo: inhala en 4, sostén 4, exhala en 6.',
      _instructions(category),
      if (willDispatch)
        'Ya estoy notificando a los servicios de emergencia con tu ubicación exacta. No cuelgues ni cierres la app.'
      else
        'Mantente en un lugar seguro y no dejes sola a la persona.',
      _question(category),
    ].join('\n\n');

    return AiTurnResult(
      text: response,
      source: AiReplySource.localProtocol,
      dispatchRequest: willDispatch
          ? AiDispatchRequest(
              severity: severity,
              summary:
                  'Emergencia (${category.label}): ${context.description}',
              recommendations: _recommendations(category),
            )
          : null,
    );
  }

  _Category _classify(String input) {
    final text = _normalize(input);
    bool has(List<String> keys) => keys.any(text.contains);

    if (has(['inconsciente', 'no responde', 'desmay', 'no respira', 'paro'])) {
      return _Category.unconscious;
    }
    if (has(['pecho', 'corazon', 'infarto', 'brazo izquierdo', 'sudor frio'])) {
      return _Category.cardiac;
    }
    if (has(['respirar', 'ahogo', 'asma', 'asfixia', 'falta de aire', 'silencio'])) {
      return _Category.breathing;
    }
    if (has(['sangre', 'sangrado', 'herida', 'corte', 'hemorragia'])) {
      return _Category.bleeding;
    }
    if (has(['cara', 'hablar', 'derrame', 'paraliz', 'lado del cuerpo', 'vision'])) {
      return _Category.stroke;
    }
    if (has(['convuls', 'ataque', 'epilep'])) {
      return _Category.seizure;
    }
    if (has(['quemadura', 'quemo', 'fuego', 'agua caliente'])) {
      return _Category.burn;
    }
    if (has(['veneno', 'intoxic', 'sobredosis', 'medicamento de mas'])) {
      return _Category.poisoning;
    }
    if (has(['accidente', 'caida', 'golpe', 'fractura', 'hueso', 'moto', 'carro'])) {
      return _Category.trauma;
    }
    if (has(['embaraz', 'parto', 'contracciones', 'sangrado vaginal'])) {
      return _Category.obstetric;
    }
    if (has(['suicid', 'matarme', 'no quiero vivir'])) {
      return _Category.mentalHealth;
    }
    return _Category.general;
  }

  String _instructions(_Category category) => switch (category) {
        _Category.unconscious =>
          '1. Verifica si responde y si respira con normalidad.\n2. Si no respira, empieza compresiones en el centro del pecho, fuertes y rápidas, 100 a 120 por minuto.\n3. Si alguien más está contigo, pídele que llame al 123 en altavoz.',
        _Category.cardiac =>
          '1. Siéntala y afloja su ropa. No la dejes caminar ni hacer esfuerzos.\n2. No le des comida ni bebida.\n3. Si tiene aspirina y no es alérgica, puede masticar una dosis estándar mientras llega la ayuda.\n4. Si pierde la consciencia y no respira, inicia RCP.',
        _Category.breathing =>
          '1. Siéntala erguida y pídele que respire lento por la nariz.\n2. Afloja la ropa del cuello y el pecho.\n3. Si tiene inhalador de rescate, ayúdale a usarlo.\n4. Si los labios se ponen morados o no puede hablar, es una emergencia crítica.',
        _Category.bleeding =>
          '1. Presiona la herida con un paño limpio, con fuerza y sin retirarlo.\n2. Si es una extremidad, elévala por encima del corazón.\n3. No retires objetos clavados; estabilízalos.\n4. Si empapa el paño, añade otro encima sin quitar el primero.',
        _Category.stroke =>
          '1. Pídele que sonría, levante los brazos y diga una frase.\n2. Anota la hora exacta en que empezaron los síntomas.\n3. No le des comida, bebida ni medicamentos.\n4. Acuéstala de lado si está inconsciente o vomita.',
        _Category.seizure =>
          '1. Retira objetos con los que pueda golpearse y protege su cabeza.\n2. No la inmovilices ni le metas nada en la boca.\n3. Cronometra la convulsión.\n4. Al terminar, ponla de lado y acompáñala.',
        _Category.burn =>
          '1. Enfría la zona con agua templada 10 a 20 minutos.\n2. Retira anillos o ropa que no esté pegada.\n3. No uses hielo, cremas ni pasta de dientes.\n4. No revientes las ampollas.',
        _Category.poisoning =>
          '1. No induzcas el vómito.\n2. Guarda el envase o el medicamento para mostrarlo al personal de salud.\n3. Si está inconsciente o convulsiona, ponla de lado.\n4. Anota la hora y la cantidad ingerida.',
        _Category.trauma =>
          '1. No muevas a la persona si sospechas lesión de cuello o espalda.\n2. Inmoviliza la zona y aplica presión si hay sangrado.\n3. No endereces huesos ni retires cascos.\n4. Abrígala y vigila su respiración.',
        _Category.obstetric =>
          '1. Si hay contracciones regulares o sangrado, acuéstala de lado.\n2. No la dejes sola y anota la frecuencia de las contracciones.\n3. Si ves la cabeza del bebé, prepara un lugar limpio y no tires de él.\n4. Mantén la calma y espera a los servicios de emergencia.',
        _Category.mentalHealth =>
          '1. No la dejes sola y retira objetos que puedan hacerle daño.\n2. Escúchala sin juzgar; no minimices lo que siente.\n3. Mantén un tono calmado y cercano.\n4. Lo más importante ahora es que siga contigo hasta que llegue la ayuda.',
        _Category.general =>
          '1. Mantén a la persona en un lugar seguro y no la dejes sola.\n2. No le des comida, bebida ni medicamentos sin indicación.\n3. Vigila su respiración y si responde.\n4. Prepárate para dar más detalles cuando llegue la ayuda.',
      };

  String _question(_Category category) => switch (category) {
        _Category.unconscious =>
          '¿La persona está respirando ahora mismo? Responde "sí" o "no".',
        _Category.breathing =>
          '¿Puede hablar o decir frases completas en este momento?',
        _Category.cardiac =>
          '¿La persona está consciente y sudando o con náuseas?',
        _Category.bleeding =>
          '¿El sangrado sale a chorros o empapa el paño rápido?',
        _Category.stroke =>
          '¿Hace cuántos minutos empezaron los síntomas?',
        _Category.seizure =>
          '¿La convulsión ya terminó? ¿La persona responde?',
        _Category.burn =>
          '¿Qué tan grande es la quemadura y en qué parte del cuerpo está?',
        _Category.poisoning =>
          '¿Qué sustancia o medicamento ingirió y hace cuánto tiempo?',
        _Category.trauma =>
          '¿La persona responde y puede mover brazos y piernas?',
        _Category.obstetric =>
          '¿Está sangrando o ya hay contracciones muy seguidas?',
        _Category.mentalHealth =>
          '¿La persona está contigo ahora? ¿Está en un lugar segura?',
        _Category.general =>
          '¿La persona está consciente y respirando con normalidad?',
      };

  List<String> _recommendations(_Category category) => switch (category) {
        _Category.unconscious => const [
            'Verificar respiración y comenzar RCP si no respira.',
            'Mantener a la persona en el suelo, boca arriba.',
          ],
        _Category.cardiac => const [
            'Mantener en reposo absoluto y no dejarla sola.',
            'Vigilar consciencia y respiración.',
          ],
        _Category.breathing => const [
            'Sentar erguida y aflojar la ropa.',
            'Vigilar color de labios y dificultad para hablar.',
          ],
        _Category.bleeding => const [
            'Presión directa firme sobre la herida.',
            'No retirar el apósito aunque se empape.',
          ],
        _Category.stroke => const [
            'Anotar la hora de inicio de los síntomas.',
            'No dar alimentos, bebidas ni medicamentos.',
          ],
        _Category.seizure => const [
            'Proteger la cabeza y retirar objetos peligrosos.',
            'No inmovilizar ni introducir objetos en la boca.',
          ],
        _Category.burn => const [
            'Enfriar con agua templada 10 a 20 minutos.',
            'Cubrir con paño limpio sin cremas.',
          ],
        _Category.poisoning => const [
            'No inducir el vómito.',
            'Conservar el envase de la sustancia.',
          ],
        _Category.trauma => const [
            'No mover a la persona si hay sospecha de lesión cervical.',
            'Controlar sangrado y vigilar respiración.',
          ],
        _Category.obstetric => const [
            'Acostar de lado y no dejar sola a la gestante.',
            'Anotar frecuencia de contracciones o sangrado.',
          ],
        _Category.mentalHealth => const [
            'No dejar sola a la persona.',
            'Retirar objetos que puedan causar daño.',
          ],
        _Category.general => const [
            'Mantener a la persona en un lugar seguro.',
            'Vigilar consciencia y respiración.',
          ],
      };

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
}

enum _Category {
  cardiac('dolor de pecho', SeverityLevel.critical),
  breathing('dificultad respiratoria', SeverityLevel.critical),
  unconscious('pérdida de consciencia', SeverityLevel.critical),
  bleeding('sangrado', SeverityLevel.high),
  stroke('posible derrame cerebral', SeverityLevel.critical),
  seizure('convulsión', SeverityLevel.high),
  trauma('trauma', SeverityLevel.high),
  burn('quemadura', SeverityLevel.high),
  poisoning('intoxicación', SeverityLevel.high),
  obstetric('emergencia obstétrica', SeverityLevel.high),
  mentalHealth('crisis de salud mental', SeverityLevel.high),
  general('emergencia médica', SeverityLevel.moderate);

  const _Category(this.label, this.severity);

  final String label;
  final SeverityLevel severity;
}
