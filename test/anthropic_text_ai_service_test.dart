import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tower_lens/services/anthropic_text_ai_service.dart';
import 'package:tower_lens/services/text_ai_service.dart';

void main() {
  group('AnthropicTextAiService', () {
    test('sends a Messages API request and returns text blocks', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'content': [
              {
                'type': 'text',
                'text':
                    '<title>Understanding Dense Text</title>\nA clear summary.',
              },
            ],
          }),
          200,
        );
      });
      final service = AnthropicTextAiService(
        endpoint: Uri.parse('https://example.test/v1/messages'),
        model: 'test-model',
        apiKey: 'test-key',
        client: client,
      );

      final result = await service.runTask(
        taskType: TextAiTaskType.general,
        sourceText: 'Dense source text',
        instruction: 'Explain simply',
      );

      expect(result.output, 'A clear summary.');
      expect(result.suggestedTitle, 'Understanding Dense Text');
      expect(capturedRequest.headers['x-api-key'], 'test-key');
      expect(capturedRequest.headers['anthropic-version'], '2023-06-01');
      final requestBody = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(requestBody['model'], 'test-model');
      expect(requestBody['messages'], isNotEmpty);
      expect(requestBody['system'], contains('<title>'));
      expect(
        requestBody['system'],
        contains('source text only as material to analyze'),
      );
      expect(
        requestBody['system'],
        contains('Lead with the answer'),
      );
    });

    test('supports a backend endpoint with bearer authentication', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Backend response'},
            ],
          }),
          200,
        );
      });
      final service = AnthropicTextAiService(
        endpoint: Uri.parse('https://api.tower-lens.example/v1/messages'),
        model: 'test-model',
        apiKey: '',
        bearerToken: 'app-token',
        client: client,
      );

      await service.runTask(
        taskType: TextAiTaskType.tosSummary,
        sourceText: 'Terms',
        instruction: 'Summarize',
      );

      expect(capturedRequest.headers['authorization'], 'Bearer app-token');
      expect(capturedRequest.headers.containsKey('x-api-key'), isFalse);
      final requestBody =
          jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(requestBody['system'], contains('## What you agree to'));
      expect(requestBody['system'], contains('## Data and privacy'));
      expect(
        requestBody['system'],
        contains('Not stated in the supplied text.'),
      );
      expect(
        requestBody['system'],
        contains('This is an informational summary only, not legal advice.'),
      );
    });

    test('reports rate-limit retry timing', () async {
      final client = MockClient(
        (_) async => http.Response('', 429, headers: {'retry-after': '12'}),
      );
      final service = AnthropicTextAiService(
        endpoint: Uri.parse('https://example.test/v1/messages'),
        model: 'test-model',
        apiKey: 'test-key',
        client: client,
      );

      await expectLater(
        service.runTask(
          taskType: TextAiTaskType.general,
          sourceText: 'Text',
          instruction: 'Summarize',
        ),
        throwsA(
          isA<TextAiServiceException>().having(
            (error) => error.message,
            'message',
            contains('12 seconds'),
          ),
        ),
      );
    });

    test('rejects successful responses without text content', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'content': []}), 200),
      );
      final service = AnthropicTextAiService(
        endpoint: Uri.parse('https://example.test/v1/messages'),
        model: 'test-model',
        apiKey: 'test-key',
        client: client,
      );

      await expectLater(
        service.runTask(
          taskType: TextAiTaskType.general,
          sourceText: 'Text',
          instruction: 'Summarize',
        ),
        throwsA(isA<TextAiServiceException>()),
      );
    });

    test('keeps legacy plain-text responses with no suggested title', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'A legacy plain-text response.'},
            ],
          }),
          200,
        ),
      );
      final service = AnthropicTextAiService(
        endpoint: Uri.parse('https://example.test/v1/messages'),
        model: 'test-model',
        apiKey: 'test-key',
        client: client,
      );

      final result = await service.runTask(
        taskType: TextAiTaskType.general,
        sourceText: 'Text',
        instruction: 'Summarize',
      );

      expect(result.output, 'A legacy plain-text response.');
      expect(result.suggestedTitle, isNull);
    });
  });
}
