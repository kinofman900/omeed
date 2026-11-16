import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

import 'map_view.dart' show MapSettings;

class WeatherOverlayLayers extends StatefulWidget {
  const WeatherOverlayLayers({super.key, required this.settings});

  final MapSettings settings;

  @override
  State<WeatherOverlayLayers> createState() => _WeatherOverlayLayersState();
}

class _WeatherOverlayLayersState extends State<WeatherOverlayLayers> {
  String? _radarUrl;
  bool _loadingRadar = false;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
    _onSettingsChanged();
  }

  @override
  void didUpdateWidget(covariant WeatherOverlayLayers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      oldWidget.settings.removeListener(_onSettingsChanged);
      widget.settings.addListener(_onSettingsChanged);
      _onSettingsChanged();
    }
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {});
    if (widget.settings.weatherRadar && _radarUrl == null) {
      _loadRadar();
    }
  }

  Future<void> _loadRadar() async {
    if (_loadingRadar || !widget.settings.weatherRadar) return;
    _loadingRadar = true;
    try {
      final response = await http
          .get(Uri.parse('https://api.rainviewer.com/public/weather-maps.json'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final radar = root['radar'] as Map<String, dynamic>?;
      final past = (radar?['past'] as List?) ?? const [];
      if (past.isEmpty || !mounted) return;

      final frame = Map<String, dynamic>.from(past.last as Map);
      final host = '${root['host']}';
      final path = '${frame['path']}';
      final url = '$host$path/256/{z}/{x}/{y}/2/1_1.png';
      if (mounted) setState(() => _radarUrl = url);
    } catch (_) {
      // Radar is optional; the base map must continue working if it fails.
    } finally {
      _loadingRadar = false;
    }
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final openWeatherKey =
        const String.fromEnvironment('OPENWEATHER_API_KEY');
    final opacity = settings.weatherOpacity.clamp(0.1, 1.0).toDouble();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (settings.weatherRadar && _radarUrl != null)
          TileLayer(
            key: ValueKey(_radarUrl),
            urlTemplate: _radarUrl!,
            maxNativeZoom: 7,
            userAgentPackageName: 'kurdistan_map',
            tileDisplay: TileDisplay.instantaneous(opacity: opacity),
          ),
        if (openWeatherKey.isNotEmpty && settings.weatherClouds)
          _tile(
            'https://tile.openweathermap.org/map/clouds_new/{z}/{x}/{y}.png?appid=$openWeatherKey',
            opacity,
          ),
        if (openWeatherKey.isNotEmpty && settings.weatherWind)
          _tile(
            'https://tile.openweathermap.org/map/wind_new/{z}/{x}/{y}.png?appid=$openWeatherKey',
            opacity,
          ),
        if (openWeatherKey.isNotEmpty && settings.weatherTemperature)
          _tile(
            'https://tile.openweathermap.org/map/temp_new/{z}/{x}/{y}.png?appid=$openWeatherKey',
            opacity,
          ),
      ],
    );
  }

  TileLayer _tile(String url, double opacity) => TileLayer(
        key: ValueKey(url),
        urlTemplate: url,
        userAgentPackageName: 'kurdistan_map',
        tileDisplay: TileDisplay.instantaneous(opacity: opacity),
      );
}
