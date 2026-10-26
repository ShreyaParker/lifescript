import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/api_client.dart';

final capabilitiesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await ref
      .watch(apiClientProvider)
      .dio
      .get('/v1/capabilities');
  return Map<String, dynamic>.from(response.data);
});

final runsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) async {
  final response = await ref.watch(apiClientProvider).dio.get('/v1/runs');
  return (response.data as List)
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
});
final automationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final response = await ref
          .watch(apiClientProvider)
          .dio
          .get('/v1/automations');
      return (response.data as List)
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    });
final automationEventsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final response = await ref
          .watch(apiClientProvider)
          .dio
          .get('/v1/automation-events');
      return (response.data as List)
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    });
