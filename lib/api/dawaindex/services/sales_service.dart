// lib/api/dawaindex/services/sales_service.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/api/dawaindex/client.dart';
import 'package:afyakit/api/dawaindex/providers.dart';
import 'package:afyakit/api/shared/types.dart';

class SalesTile {
  /// canon_key from API
  final String id;

  /// normalized brand from BE (may be empty string)
  final String brand;

  /// e.g. "500mg", "250mg/5ml"
  final String strengthSig;

  /// our normalized formulation from BE: tablet|capsule|liquid|injection|other
  final String form;

  final num? bestSellPrice;
  final int? offerCount;
  final String? tileTitle;
  final String? tileDesc;
  final int? bestPackCount;
  final String? bestSupplier;

  // new from BE / engine
  final String? packsFmt;
  final String? volumeSig;
  final String? concentrationSig;

  /// BE enriches tiles with merge info in list-all; search may still return null
  final bool? hasMergeOverride;

  const SalesTile({
    required this.id,
    required this.brand,
    required this.strengthSig,
    required this.form,
    this.bestSellPrice,
    this.offerCount,
    this.tileTitle,
    this.tileDesc,
    this.bestPackCount,
    this.bestSupplier,
    this.packsFmt,
    this.volumeSig,
    this.concentrationSig,
    this.hasMergeOverride,
  });

  factory SalesTile.fromJson(Map<String, dynamic> j) => SalesTile(
    // BE returns canon_key, so make that the id
    id: (j['canon_key'] ?? '') as String,
    brand: (j['brand'] ?? '') as String,
    strengthSig: (j['strength_sig'] ?? '') as String,
    form: (j['form'] ?? '') as String,
    bestSellPrice: j['best_sell_price'] as num?,
    offerCount: j['offer_count'] as int?,
    tileTitle: j['tile_title'] as String?,
    tileDesc: j['tile_desc'] as String?,
    bestPackCount: j['best_pack_count'] as int?,
    bestSupplier: j['best_supplier'] as String?,
    // extras
    packsFmt: j['packs_fmt'] as String?,
    volumeSig: j['volume_sig'] as String?,
    concentrationSig: j['concentration_sig'] as String?,
    hasMergeOverride: j['has_merge_override'] as bool?,
  );
}

class ListSalesParams {
  final String q;

  /// backend allows: tablet|capsule|liquid|injection|other (and '' for no filter)
  final String form;
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
      'v1/sales/tiles',
      queryParameters: params.toQuery(),
      // your BE already requires auth, but you had this flag, keeping it
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

    final int total = body['total'] as int? ?? items.length;
    final int offset = body['offset'] as int? ?? params.offset;

    final int? nextOffset = (offset + items.length) < total
        ? offset + items.length
        : null;

    return Paged<SalesTile>(items: items, nextOffset: nextOffset);
  }
}

final salesServiceProvider = Provider<SalesService>((ref) {
  final di = ref
      .watch(dawaIndexClientProvider)
      .maybeWhen(data: (c) => c, orElse: () => null);
  if (di == null) {
    throw StateError('DawaIndex client not ready');
  }
  return SalesService(di);
});
