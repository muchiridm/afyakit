// lib/features/delivery_addresses/widgets/delivery_pin_picker_screen.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:afyakit/features/delivery_addresses/models/delivery_address.dart';

class DeliveryPinPickerScreen extends StatefulWidget {
  const DeliveryPinPickerScreen({
    super.key,
    this.initialPin,
    this.initialCenter,
    this.initialZoom = 16,
  });

  final DeliveryPinLocation? initialPin;
  final LatLng? initialCenter;
  final double initialZoom;

  @override
  State<DeliveryPinPickerScreen> createState() =>
      _DeliveryPinPickerScreenState();
}

class _DeliveryPinPickerScreenState extends State<DeliveryPinPickerScreen> {
  static const LatLng _fallbackCenter = LatLng(-1.286389, 36.817223); // Nairobi
  static const String _userAgent = 'AfyaKit/1.0 (delivery pin picker)';

  late final MapController _mapController;
  late final TextEditingController _searchController;

  LatLng? _selectedLatLng;
  String? _selectedPlaceName;

  bool _isSearching = false;
  bool _isFetchingCurrentLocation = false;
  bool _isReverseGeocoding = false;

  List<_PlaceSearchResult> _results = const [];

  LatLng get _startCenter {
    if (widget.initialCenter != null) return widget.initialCenter!;

    final initialPin = widget.initialPin;
    if (initialPin != null) {
      return LatLng(initialPin.latitude, initialPin.longitude);
    }

    return _fallbackCenter;
  }

  bool get _hasSelection => _selectedLatLng != null;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _searchController = TextEditingController();

    final initialPin = widget.initialPin;
    if (initialPin != null) {
      _selectedLatLng = LatLng(initialPin.latitude, initialPin.longitude);
      _selectedPlaceName = _clean(initialPin.placeName);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marker = _selectedLatLng == null
        ? const <Marker>[]
        : <Marker>[
            Marker(
              point: _selectedLatLng!,
              width: 44,
              height: 44,
              child: const Icon(
                Icons.location_pin,
                size: 44,
                color: Colors.red,
              ),
            ),
          ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drop Delivery Pin'),
        actions: [
          TextButton(
            onPressed: _hasSelection ? _confirmSelection : null,
            child: const Text('Use Pin'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _startCenter,
              initialZoom: widget.initialZoom,
              onTap: (tapPosition, point) => _selectPoint(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'app.afyakit',
              ),
              MarkerLayer(markers: marker),
            ],
          ),

          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SearchCard(
                  controller: _searchController,
                  isSearching: _isSearching,
                  isFetchingCurrentLocation: _isFetchingCurrentLocation,
                  onSubmit: _runSearch,
                  onUseCurrentLocation: _useCurrentLocation,
                  onClearSearch: () {
                    _searchController.clear();
                    setState(() {
                      _results = const [];
                    });
                  },
                ),
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SearchResultsCard(
                    results: _results,
                    onSelect: _selectSearchResult,
                  ),
                ],
                const SizedBox(height: 8),
                _HelpCard(
                  selectedLatLng: _selectedLatLng,
                  selectedPlaceName: _selectedPlaceName,
                  isReverseGeocoding: _isReverseGeocoding,
                  onClear: _hasSelection
                      ? () {
                          setState(() {
                            _selectedLatLng = null;
                            _selectedPlaceName = null;
                          });
                        }
                      : null,
                ),
              ],
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _hasSelection ? _confirmSelection : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm Pin'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runSearch([String? rawQuery]) async {
    final query = (rawQuery ?? _searchController.text).trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _results = const [];
    });

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '8',
        'addressdetails': '1',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Search failed (${response.statusCode})');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw Exception('Unexpected search response');
      }

      final results = decoded
          .whereType<Map>()
          .map(
            (e) => _PlaceSearchResult.fromMap(
              Map<String, dynamic>.from(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ),
            ),
          )
          .toList(growable: false);

      if (!mounted) return;

      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    }
  }

  Future<void> _selectSearchResult(_PlaceSearchResult result) async {
    final point = LatLng(result.latitude, result.longitude);

    setState(() {
      _selectedLatLng = point;
      _selectedPlaceName = result.displayName;
      _results = const [];
      _searchController.text = result.displayName;
    });

    _mapController.move(point, 17);
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isFetchingCurrentLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission permanently denied. Enable it in device settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final point = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {
        _selectedLatLng = point;
        _selectedPlaceName = null;
        _isFetchingCurrentLocation = false;
      });

      _mapController.move(point, 17);

      await _reverseGeocode(point);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isFetchingCurrentLocation = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Current location failed: $e')));
    }
  }

  Future<void> _selectPoint(LatLng point) async {
    setState(() {
      _selectedLatLng = point;
      _selectedPlaceName = null;
      _results = const [];
    });

    await _reverseGeocode(point);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() {
      _isReverseGeocoding = true;
    });

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'format': 'jsonv2',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Reverse geocoding failed (${response.statusCode})');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw Exception('Unexpected reverse geocoding response');
      }

      final map = Map<String, dynamic>.from(
        decoded.map((k, v) => MapEntry(k.toString(), v)),
      );

      final displayName = _clean(map['display_name']?.toString());

      if (!mounted) return;

      setState(() {
        _selectedPlaceName = displayName;
        _isReverseGeocoding = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isReverseGeocoding = false;
      });
    }
  }

  Future<void> _confirmSelection() async {
    final selected = _selectedLatLng;
    if (selected == null) return;

    Navigator.of(context).pop(
      DeliveryPinLocation(
        latitude: selected.latitude,
        longitude: selected.longitude,
        placeName: _selectedPlaceName,
      ),
    );
  }

  String? _clean(String? value) {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.controller,
    required this.isSearching,
    required this.isFetchingCurrentLocation,
    required this.onSubmit,
    required this.onUseCurrentLocation,
    required this.onClearSearch,
  });

  final TextEditingController controller;
  final bool isSearching;
  final bool isFetchingCurrentLocation;
  final Future<void> Function([String? query]) onSubmit;
  final Future<void> Function() onUseCurrentLocation;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => onSubmit(value),
              decoration: InputDecoration(
                hintText: 'Search area, estate, road, place…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (controller.text.trim().isNotEmpty)
                            IconButton(
                              tooltip: 'Clear',
                              onPressed: onClearSearch,
                              icon: const Icon(Icons.clear),
                            ),
                          IconButton(
                            tooltip: 'Search',
                            onPressed: () => onSubmit(),
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ],
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: isFetchingCurrentLocation
                    ? null
                    : onUseCurrentLocation,
                icon: isFetchingCurrentLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('Use Current Location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultsCard extends StatelessWidget {
  const _SearchResultsCard({required this.results, required this.onSelect});

  final List<_PlaceSearchResult> results;
  final Future<void> Function(_PlaceSearchResult result) onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 260),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final result = results[index];
            return ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(
                result.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                result.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onSelect(result),
            );
          },
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.selectedLatLng,
    required this.selectedPlaceName,
    required this.isReverseGeocoding,
    required this.onClear,
  });

  final LatLng? selectedLatLng;
  final String? selectedPlaceName;
  final bool isReverseGeocoding;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedLatLng != null;

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasSelection ? 'Pin selected' : 'Tap the map to drop a pin',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasSelection && isReverseGeocoding)
                    Text(
                      'Looking up place name…',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Text(
                      hasSelection
                          ? _selectionText(
                              selectedLatLng: selectedLatLng!,
                              selectedPlaceName: selectedPlaceName,
                            )
                          : 'Place the pin where the rider should find the delivery location.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (hasSelection) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: onClear, child: const Text('Clear')),
            ],
          ],
        ),
      ),
    );
  }

  String _selectionText({
    required LatLng selectedLatLng,
    required String? selectedPlaceName,
  }) {
    final coords =
        '${selectedLatLng.latitude.toStringAsFixed(6)}, ${selectedLatLng.longitude.toStringAsFixed(6)}';

    if (selectedPlaceName != null && selectedPlaceName.trim().isNotEmpty) {
      return '$selectedPlaceName\n$coords';
    }

    return coords;
  }
}

class _PlaceSearchResult {
  const _PlaceSearchResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });

  final double latitude;
  final double longitude;
  final String displayName;

  String get title {
    final parts = displayName
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? displayName : parts.first;
  }

  factory _PlaceSearchResult.fromMap(Map<String, dynamic> json) {
    final lat = double.tryParse((json['lat'] ?? '').toString().trim());
    final lon = double.tryParse((json['lon'] ?? '').toString().trim());
    final displayName = (json['display_name'] ?? '').toString().trim();

    if (lat == null || lon == null || displayName.isEmpty) {
      throw ArgumentError('Invalid place search result');
    }

    return _PlaceSearchResult(
      latitude: lat,
      longitude: lon,
      displayName: displayName,
    );
  }
}
