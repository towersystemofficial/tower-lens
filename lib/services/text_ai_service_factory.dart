import 'anthropic_text_ai_service.dart';
import 'text_ai_service.dart';

const _anthropicEndpoint = 'https://api.anthropic.com/v1/messages';
const _defaultModel = 'claude-haiku-4-5-20251001';

TextAiService createTextAiService() {
  const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  const bearerToken = String.fromEnvironment('TOWER_LENS_AI_BEARER_TOKEN');
  const endpoint = String.fromEnvironment(
    'TOWER_LENS_AI_ENDPOINT',
    defaultValue: _anthropicEndpoint,
  );
  const model = String.fromEnvironment(
    'TOWER_LENS_AI_MODEL',
    defaultValue: _defaultModel,
  );

  if (apiKey.isEmpty && bearerToken.isEmpty) return MockTextAiService();

  return AnthropicTextAiService(
    endpoint: Uri.parse(endpoint),
    model: model,
    apiKey: apiKey,
    bearerToken: bearerToken,
  );
}
