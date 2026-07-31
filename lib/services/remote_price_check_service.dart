import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/price_check.dart';
import 'price_check_service.dart';

class RemotePriceCheckService implements PriceCheckService {
  RemotePriceCheckService({
    required this.endpoint,
    this.bearerToken = '',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri endpoint;
  final String bearerToken;
  final http.Client _client;

  @override
  Future<PriceCheckIdentification> identify(
    PriceCheckInput input, [
    PriceCheckMockScenario scenario = PriceCheckMockScenario.typical,
  ]) async {
    final photos = await Future.wait(input.photos.map(_encodePhoto));
    final json = await _post(
      'identify',
      {'input': input.toJson(encodedPhotos: photos)},
      const Duration(minutes: 4),
    );
    return PriceCheckIdentification.fromJson(json);
  }

  @override
  Future<PriceCheckMarketResult> research(
    PriceCheckInput input,
    PriceCheckIdentification identification, [
    PriceCheckMockScenario scenario = PriceCheckMockScenario.typical,
  ]) async {
    final json = await _post(
      'research',
      {'input': input.toJson(encodedPhotos: const []), 'identification': identification.toJson()},
      input.tier == PriceCheckTier.higherCredit
          ? const Duration(minutes: 8)
          : const Duration(minutes: 5),
    );
    return PriceCheckMarketResult.fromJson(json);
  }

  @override
  Future<PriceCheckGuidanceResult> analyzeBuyer(
    PriceCheckMarketResult market,
  ) async => PriceCheckGuidanceResult.fromJson(
        await _post('buyer', {'market': market.toJson()}, const Duration(minutes: 3)),
      );

  @override
  Future<PriceCheckGuidanceResult> analyzeSeller(
    PriceCheckMarketResult market,
  ) async => PriceCheckGuidanceResult.fromJson(
        await _post('seller', {'market': market.toJson()}, const Duration(minutes: 3)),
      );

  @override
  Future<String> compareMarketChanges({
    required String priorOutputs,
    required PriceCheckMarketResult currentMarket,
  }) async {
    final result = await _post(
      'compare',
      {'priorOutputs': priorOutputs, 'currentMarket': currentMarket.toJson()},
      const Duration(minutes: 3),
    );
    return result['summary'] as String? ?? '';
  }

  Future<String> _encodePhoto(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const PriceCheckServiceException(
        'A selected photo is no longer available. Remove it and add it again.',
      );
    }
    final extension = p.extension(path).toLowerCase();
    final mediaType = switch (extension) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      _ => 'image/jpeg',
    };
    return 'data:$mediaType;base64,${base64Encode(await file.readAsBytes())}';
  }

  Future<Map<String, dynamic>> _post(
    String stage,
    Map<String, dynamic> payload,
    Duration timeout,
  ) async {
    final uri = endpoint.replace(
      path: '${endpoint.path.replaceFirst(RegExp(r'/$'), '')}/$stage',
    );
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              if (bearerToken.isNotEmpty) 'authorization': 'Bearer $bearerToken',
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PriceCheckServiceException(
          body['error'] as String? ?? 'Price Check failed. Please try again.',
        );
      }
      return body['result'] as Map<String, dynamic>? ?? body;
    } on TimeoutException {
      throw const PriceCheckServiceException(
        'Price Check timed out. Your inputs were kept so you can retry.',
      );
    } on SocketException {
      throw const PriceCheckServiceException(
        'Price Check needs an internet connection. Your inputs were kept.',
      );
    } on http.ClientException {
      throw const PriceCheckServiceException(
        'Tower Lens could not reach Price Check. Your inputs were kept.',
      );
    } on FormatException {
      throw const PriceCheckServiceException(
        'Price Check returned an unreadable response. Please try again.',
      );
    }
  }
}
