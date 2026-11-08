import 'package:flutter/material.dart';

import 'navigation.dart';

typedef MapLabel = String Function(String key);

class MapGpsHud extends StatelessWidget {
  const MapGpsHud({super.key, required this.label});
  final MapLabel label;

  String _number(double? value, {int digits = 1}) =>
      value == null || !value.isFinite ? '--' : value.toStringAsFixed(digits);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NavStore.instance,
      builder: (context, _) {
        final nav = NavStore.instance;
        final point = nav.me;
        if (point == null) return const SizedBox.shrink();
        final speed = (nav.speedMps ?? 0) * 3.6;
        return Material(
          color: const Color(0xE8223440),
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.gps_fixed, color: Color(0xFF65D6C7), size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(label('gps_info'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                Text('${_number(nav.accuracy, digits: 0)} m',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
              const SizedBox(height: 7),
              Row(children: [
                Expanded(child: _Metric(icon: Icons.speed, label: label('gps_speed'), value: '${_number(speed)} km/h')),
                Expanded(child: _Metric(icon: Icons.terrain, label: label('gps_altitude'), value: '${_number(nav.altitudeM, digits: 0)} m')),
                Expanded(child: _Metric(
                  icon: Icons.explore,
                  label: label('gps_heading'),
                  value: nav.heading == null || nav.heading! < 0 ? '--' : '${_number(nav.heading, digits: 0)}°',
                )),
              ]),
              const SizedBox(height: 5),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${label('gps_max_speed')}: ${_number(nav.maxSpeedMps * 3.6)} km/h  •  ${label('gps_avg_speed')}: ${_number(nav.averageSpeedMps * 3.6)} km/h',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ),
              const SizedBox(height: 6),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text('${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, letterSpacing: .15)),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: const Color(0xFF9ADBD5), size: 16),
        const SizedBox(width: 5),
        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ])),
      ]);
}
