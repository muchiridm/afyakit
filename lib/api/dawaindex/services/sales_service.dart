import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/api/dawaindex/client.dart';
import 'package:afyakit/api/dawaindex/providers.dart';
import 'package:afyakit/api/shared/types.dart';

class SalesTile {
  final String id;
  final String brand;
  final String strengthSig;
  final String form;
  final num? bestSellPrice;
  final int? offerCount;

  const SalesTile({
    required this.id,
    required this.brand,
    required this.strengthSig,
    required this.form,
    this.bestSellPrice,
    this.offerCount,
  });

  factory SalesTile.fromJson(Map<String, dynamic> j) => SalesTile(
    id: (j['id'] ?? j['cluster_key'] ?? j['sku'] ?? '') as String,
    brand: (j['brand'] ?? '') as String,
    strengthSig: (j['strength_sig'] ?? '') as String,
    form: (j['form'] ?? '') as String,
    bestSellPrice: j['best_sell_price'] as num?,
    offerCount: j['offer_count'] as int?,
  );
}

class ListSalesParams {
  final String q;
  final String form; // '', 'tablet', 'capsule', 'liquid', 'other'
  final int limit;
  final int offset;
  const ListSalesParams({
    this.q = '',
    this.form = '',
    this.limit = 50,
    this.offset = 0,
  });

  Map<String, dynamic> toQuery() => {
    if (q.trim().isNotEmpty) 'q': q.trim(),
    if (form.isNotEmpty) 'form': form,
    'limit': limit,
    'offset': offset,
  };
}

class SalesService {
  final DawaIndexClient client;
  const SalesService(this.client);

  Future<Paged<SalesTile>> listTiles(ListSalesParams params) async {
    final Dio dio = client.dio;
    final res = await dio.get(
      'v1/sales/tiles', // NOTE: no leading slash; supports /di-api
      queryParameters: params.toQuery(),
      options: Options(extra: {'skipAuth': true}),
    );

    final Map<String, dynamic> body = switch (res.data) {
      final Map<String, dynamic> m => m,
      final String s => jsonDecode(s) as Map<String, dynamic>,
      _ => throw StateError('Unexpected sales tiles payload'),
    };

    final items = (body['items'] as List)
        .map((e) => SalesTile.fromJson(e as Map<String, dynamic>))
        .toList();

    return Paged<SalesTile>(
      items: items,
      nextOffset: body['next_offset'] as int?,
    );
  }
}

final salesServiceProvider = Provider<SalesService>((ref) {
  final di = ref
      .watch(dawaIndexClientProvider)
      .maybeWhen(data: (c) => c, orElse: () => null);
  if (di == null) {
    // You can also throw and let UI use AsyncValue
    throw StateError('DawaIndex client not ready');
  }
  return SalesService(di);
});
