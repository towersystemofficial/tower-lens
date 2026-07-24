import 'anthropic_text_ai_service.dart';
import 'text_ai_service.dart';

const _anthropicEndpoint = 'https://api.anthropic.com/v1/messages';
const _defaultModel = 'claude-haiku-4-5-20251001';

const _buildTimeApiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
const _buildTimeBearerToken =
    String.fromEnvironment('TOWER_LENS_AI_BEARER_TOKEN');

bool get hasBuildTimeAiCredential =>
    _buildTimeApiKey.isNotEmpty || _buildTimeBearerToken.isNotEmpty;

TextAiService createTextAiService({String apiKey = ''}) {
  final selectedApiKey =
      apiKey.trim().isNotEmpty ? apiKey.trim() : _buildTimeApiKey;
  const endpoint = String.fromEnvironment(
    'TOWER_LENS_AI_ENDPOINT',
    defaultValue: _anthropicEndpoint,
  );
  const model = String.fromEnvironment(
    'TOWER_LENS_AI_MODEL',
    defaultValue: _defaultModel,
  );

  if (selectedApiKey.isEmpty && _buildTimeBearerToken.isEmpty) {
    return MockTextAiService();
  }

  return AnthropicTextAiService(
    endpoint: Uri.parse(endpoint),
    model: model,
    apiKey: selectedApiKey,
    bearerToken: _buildTimeBearerToken,
  );
}
