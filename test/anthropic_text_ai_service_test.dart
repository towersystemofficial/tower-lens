import 'dart:convert';
import 'dart:typed_data';

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
      expect(requestBody['max_tokens'], greaterThan(1200));
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
      expect(requestBody['system'], contains('## Immediate notice'));
      expect(requestBody['system'], contains('## Potential major consequences'));
      expect(requestBody['system'], contains('## Ordinary restrictions'));
      expect(requestBody['system'], contains('charges and the conditions'));
      expect(requestBody['system'], contains('cross-border transfer'));
      expect(requestBody['system'], contains('class-action waivers'));
      expect(requestBody['system'], contains('connected third-party services'));
      expect(requestBody['system'], contains('Unusual or suspicious terms'));
      expect(
        requestBody['system'],
        contains('Not stated in the supplied text.'),
      );
      expect(
        requestBody['system'],
        contains('This is an informational summary only, not legal advice.'),
      );
    });

    test('sends distinct summary and simplification prompt contracts', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Response'},
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

      await service.runTask(
        taskType: TextAiTaskType.summary,
        sourceText: 'Dense source text',
        instruction: 'Summarize the supplied text.',
      );
      await service.runTask(
        taskType: TextAiTaskType.simplify,
        sourceText: 'Dense source text',
        instruction: 'Use the top 7000 most common words.',
      );

      final summaryBody =
          jsonDecode(requests.first.body) as Map<String, dynamic>;
      final simplifyBody =
          jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(summaryBody['system'], contains('## Quick summary'));
      expect(summaryBody['system'], contains('## Main points'));
      expect(summaryBody['system'], contains('## Detailed breakdown'));
      expect(summaryBody['system'], contains('high-fidelity'));
      expect(simplifyBody['system'], contains('Rewrite the supplied text'));
      expect(simplifyBody['system'], contains('Preserve as much'));
      expect(
        (simplifyBody['messages'] as List<dynamic>).single.toString(),
        contains('top 7000 most common words'),
      );
    });

    test('sends high-fidelity OCR evidence in one multimodal request', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'content': [
              {
                'type': 'text',
                'text': 'First paragraph.\n\nSecond [unclear] paragraph.',
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

      final result = await service.reconstructScannedText(
        frozenOcrText: 'First paragraph. Second paragraph.',
        previousOcrCaptures: const [
          'F1rst paragraph',
          'First paragraph',
          'First paragraph. Second',
          'First paragraph. Second paragraph',
          'First paragraph. Second paragraph.',
        ],
        imageBytes: Uint8List.fromList([1, 2, 3]),
        imageMediaType: 'image/jpeg',
      );

      expect(result, 'First paragraph.\n\nSecond [unclear] paragraph.');
      final requestBody =
          jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(requestBody['max_tokens'], 16000);
      expect(requestBody['system'], contains('[unclear]'));
      expect(requestBody['system'], contains('oldest to newest'));
      expect(
        requestBody['system'],
        contains('Do not return source-by-source transcriptions'),
      );
      final messages = requestBody['messages'] as List<dynamic>;
      final content =
          (messages.single as Map<String, dynamic>)['content'] as List<dynamic>;
      final textBlock = content.first as Map<String, dynamic>;
      final imageBlock = content.last as Map<String, dynamic>;
      expect(textBlock['text'], contains('Capture 1:\nF1rst paragraph'));
      expect(
        textBlock['text'],
        contains('Capture 5:\nFirst paragraph. Second paragraph.'),
      );
      expect(imageBlock['type'], 'image');
      expect(
        (imageBlock['source'] as Map<String, dynamic>)['data'],
        base64Encode([1, 2, 3]),
      );
    });

    test('honors an explicit timeout override', () async {
      final client = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Late response'},
            ],
          }),
          200,
        );
      });
      final service = AnthropicTextAiService(
        endpoint: Uri.parse('https://example.test/v1/messages'),
        model: 'test-model',
        apiKey: 'test-key',
        timeout: const Duration(milliseconds: 1),
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
            contains('timed out'),
          ),
        ),
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
