part of 'map_view.dart';

// ───────────────────────── چینی ناوی شوێنەکان ─────────────────────────
class _PlaceLabels extends StatelessWidget {
  const _PlaceLabels({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) {
    final store = PlacesStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final camera = MapCamera.of(context);
        final markers = <Marker>[];
        for (final p in store.visible(camera.visibleBounds, camera.zoom, cap: 90)) {
          final name = p.nameFor(lang);
          if (name.isEmpty) continue;
          markers.add(Marker(
            point: LatLng(p.lat, p.lng),
            width: 150,
            height: 44,
            alignment: Alignment.topCenter,
            child: _Label(name, p.kind),
          ));
        }
        return MarkerLayer(markers: markers);
      },
    );
  }
}

/// ناوێکی جوان: تێکستی سپی لەگەڵ هێڵی ڕەش بۆ ڕوونی
class _Label extends StatelessWidget {
  const _Label(this.text, this.kind);
  final String text;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final big = kind == 'country' || kind == 'province';
    final double size = big
        ? 17
        : kind == 'city'
            ? 15
            : kind == 'town'
                ? 13
                : 11.5;
    final weight = (big || kind == 'city') ? FontWeight.w700 : FontWeight.w500;

    final stroke = TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: 1.1,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xE6000000),
    );
    final fill = TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: 1.1,
      color: big ? kGold : Colors.white,
    );

    final direction = RegExp(r'[\u0600-\u06FF]').hasMatch(text)
        ? TextDirection.rtl
        : TextDirection.ltr;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (!big)
        Container(
          width: kind == 'city' ? 9 : 7,
          height: kind == 'city' ? 9 : 7,
          decoration: BoxDecoration(
            color: kGold,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black87, width: 1),
          ),
        ),
      const SizedBox(height: 2),
      Stack(
        alignment: Alignment.center,
        children: [
          Text(
            text,
            textDirection: direction,
            style: stroke,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            text,
            textDirection: direction,
            style: fill,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ]);
  }
}

// ───────────────────────── پێوانی دووری ─────────────────────────
class _NumDot extends StatelessWidget {
  const _NumDot(this.n);
  final int n;
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kGold,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black87, width: 1.5),
      ),
      child: Text(
        '$n',
        style: const TextStyle(
            color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MeasurePanel extends StatelessWidget {
  const _MeasurePanel();

  @override
  Widget build(BuildContext context) {
    final s = MapSettings.instance;
    final pts = s.points;
    final nav = NavStore.instance;
    double total = 0;
    for (var i = 0; i < pts.length - 1; i++) {
      total += _km(pts[i], pts[i + 1]);
    }
    final last = pts.length >= 2 ? _km(pts[pts.length - 2], pts.last) : 0.0;
    final direct = pts.length >= 2 ? _km(pts.first, pts.last) : 0.0;

    Widget endpoint(String key, int index, String fallback) {
      final point = pts[index];
      final savedLabel = index < s.pointLabels.length ? s.pointLabels[index] : null;
      final name = savedLabel?.trim().isNotEmpty == true
          ? savedLabel!.trim()
          : fallback;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${context.mt(key)}: ',
              style: const TextStyle(color: Colors.white70)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ]),
      );
    }

    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.straighten, color: kGold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(context.mt('tool_measure'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close),
              onPressed: () => s.setMeasuring(false),
            ),
          ]),
          if (pts.length < 2)
            Text(context.mt('measure_hint'),
                style: const TextStyle(color: Colors.white70))
          else ...[
            endpoint('measure_from', 0, 'A'),
            endpoint('measure_to', pts.length - 1, 'B'),
            Text('${context.mt('measure_straight')}: ${fmtDistance(direct)}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: kGold)),
            if (pts.length > 2) ...[
              Text('${context.mt('measure_chain')}: ${fmtDistance(total)}',
                  style: const TextStyle(color: Colors.white70)),
              Text('${context.mt('last_leg')}: ${fmtDistance(last)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
            TextButton.icon(
              onPressed: nav.routing
                  ? null
                  : () => unawaited(nav.routeBetween(pts.first, pts.last)),
              icon: nav.routing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.alt_route, size: 18),
              label: Text(nav.routing
                  ? xt(context, 'routing')
                  : context.mt('road_route')),
            ),
            if (nav.routeKm != null) ...[
              Text('${xt(context, 'dist')}: ${fmtDistance(nav.routeKm!)}',
                  style: const TextStyle(color: Colors.white70)),
              if (nav.carMin != null)
                Text('${xt(context, 'car')}: ${fmtDuration(context, nav.carMin!)}',
                    style: const TextStyle(color: Colors.white70)),
              if (nav.straight)
                Text(xt(context, 'route_straight'),
                    style: const TextStyle(color: Colors.orange, fontSize: 12)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: nav.clearRoute,
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(context.mt('clear')),
                ),
              ),
            ],
          ],
          const SizedBox(height: 6),
          Row(children: [
            Text('${pts.length} ${context.mt('points')}',
                style: const TextStyle(color: Colors.white54)),
            const Spacer(),
            TextButton.icon(
              onPressed: pts.isEmpty
                  ? null
                  : () {
                      nav.clearRoute();
                      s.undoPoint();
                    },
              icon: const Icon(Icons.undo, size: 18),
              label: Text(context.mt('undo')),
            ),
            TextButton.icon(
              onPressed: pts.isEmpty
                  ? null
                  : () {
                      nav.clearRoute();
                      s.clearPoints();
                    },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(context.mt('clear')),
            ),
          ]),
        ],
      ),
    );
  }
}

class _AreaPanel extends StatelessWidget {
  const _AreaPanel();

  @override
  Widget build(BuildContext context) {
    final s = MapSettings.instance;
    final pts = s.areaPoints;
    return _Panel(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Icons.square_foot, color: Color(0xFF4FC3F7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.mt('tool_area'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close),
            onPressed: () => s.setAreaMode(false),
          ),
        ]),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            pts.length < 3
                ? context.mt('area_hint')
                : '${context.mt('area_result')}: ${_formatArea(_areaSquareMeters(pts))}',
            style: TextStyle(
              color: pts.length < 3 ? Colors.white70 : const Color(0xFF4FC3F7),
              fontSize: pts.length < 3 ? 14 : 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Text('${pts.length} ${context.mt('points')}',
              style: const TextStyle(color: Colors.white54)),
          const Spacer(),
          TextButton.icon(
            onPressed: pts.isEmpty ? null : s.undoAreaPoint,
            icon: const Icon(Icons.undo, size: 18),
            label: Text(context.mt('undo')),
          ),
          TextButton.icon(
            onPressed: pts.isEmpty ? null : s.clearAreaPoints,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(context.mt('clear')),
          ),
        ]),
      ]),
    );
  }
}

class _CirclePanel extends StatelessWidget {
  const _CirclePanel();

  @override
  Widget build(BuildContext context) {
    final s = MapSettings.instance;
    final center = s.circleCenter;
    final edge = s.circleEdge;
    final radius = center != null && edge != null ? _meters(center, edge) : null;
    final radiusValue = radius == null
        ? null
        : radius < 1000
            ? '${radius.toStringAsFixed(0)} m'
            : '${(radius / 1000).toStringAsFixed(2)} km';
    final radiusText = radiusValue == null
        ? context.mt('circle_hint')
        : '${context.mt('radius_result')}: $radiusValue';

    return _Panel(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Icons.circle_outlined, color: Color(0xFF4FC3F7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.mt('tool_circle'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close),
            onPressed: () => s.setCircleMode(false),
          ),
        ]),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(radiusText,
              style: TextStyle(
                color: radius == null ? Colors.white70 : const Color(0xFF4FC3F7),
                fontSize: radius == null ? 14 : 18,
                fontWeight: FontWeight.w700,
              )),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: center == null ? null : s.clearCirclePoints,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(context.mt('clear')),
          ),
        ),
      ]),
    );
  }
}

class _AzimuthPanel extends StatelessWidget {
  const _AzimuthPanel();

  @override
  Widget build(BuildContext context) {
    final s = MapSettings.instance;
    final pts = s.azimuthPoints;
    final ready = pts.length >= 2;
    return _Panel(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Icons.explore_outlined, color: Color(0xFF80CBC4)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.mt('tool_azimuth'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close),
            onPressed: () => s.setAzimuthMode(false),
          ),
        ]),
        if (!ready)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(context.mt('azimuth_hint'),
                style: const TextStyle(color: Colors.white70)),
          )
        else
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(children: [
              Text('${context.mt('bearing_forward')}: ${_bearing(pts[0], pts[1]).toStringAsFixed(1)}°',
                  style: const TextStyle(color: Color(0xFF80CBC4), fontWeight: FontWeight.w700)),
              Text('${context.mt('bearing_reverse')}: ${_bearing(pts[1], pts[0]).toStringAsFixed(1)}°',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Text(context.mt('azimuth_note'),
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),
        Row(children: [
          Text('${pts.length} ${context.mt('points')}',
              style: const TextStyle(color: Colors.white54)),
          const Spacer(),
          TextButton.icon(
            onPressed: pts.isEmpty ? null : s.undoAzimuthPoint,
            icon: const Icon(Icons.undo, size: 18),
            label: Text(context.mt('undo')),
          ),
          TextButton.icon(
            onPressed: pts.isEmpty ? null : s.clearAzimuthPoints,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(context.mt('clear')),
          ),
        ]),
      ]),
    );
  }
}

class _TerrainPanel extends StatelessWidget {
  const _TerrainPanel({required this.store});
  final TerrainStore store;

  @override
  Widget build(BuildContext context) {
    final isProfile = store.tool == TerrainTool.profile;
    final ready = isProfile ? store.points.length >= 2 : store.points.isNotEmpty;
    final elevations = store.profile.map((point) => point.elevationM).toList();
    final minElevation = elevations.isEmpty
        ? null
        : elevations.reduce((a, b) => a < b ? a : b);
    final maxElevation = elevations.isEmpty
        ? null
        : elevations.reduce((a, b) => a > b ? a : b);

    Widget result;
    switch (store.tool) {
      case TerrainTool.profile:
        result = store.profile.isEmpty
            ? const SizedBox.shrink()
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tt('terrain_profile_result'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _ProfileChartPainter(store.profile),
                  ),
                ),
                if (minElevation != null && maxElevation != null)
                  Text('${context.tt('terrain_elevation_range')}: '
                      '${minElevation.toStringAsFixed(0)} / '
                      '${maxElevation.toStringAsFixed(0)} m'),
                Text(store.profileObstructed == true
                    ? context.tt('terrain_obstructed')
                    : context.tt('terrain_clear_line')),
                Text('${context.tt('terrain_spacing')}: '
                    '${store.sampleSpacingM.toStringAsFixed(0)} m'),
              ]);
        break;
      case TerrainTool.slope:
        result = store.slopeDegrees == null
            ? const SizedBox.shrink()
            : Text('${context.tt('terrain_slope_result')}: '
                '${store.slopeDegrees!.toStringAsFixed(1)}° · '
                '${store.slopePercent!.toStringAsFixed(1)}%');
        break;
      case TerrainTool.viewshed:
        result = store.cells.isEmpty
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${context.tt('terrain_viewshed_result')}: '
                      '${store.visibleCells} / ${store.cells.length}'),
                  Text('${context.tt('terrain_visible_area')}: '
                      '${(store.visibleCells * store.sampleSpacingM * store.sampleSpacingM / 1000000).toStringAsFixed(2)} km²'),
                  Text('${context.tt('terrain_spacing')}: '
                      '${store.sampleSpacingM.toStringAsFixed(0)} m'),
                ],
              );
        break;
      case TerrainTool.hillshade:
        result = store.cells.isEmpty
            ? const SizedBox.shrink()
            : Text(context.tt('terrain_hillshade_result'));
        break;
      case TerrainTool.contours:
        result = store.contours.isEmpty
            ? store.completed
                ? Text(context.tt('terrain_no_contours'))
                : const SizedBox.shrink()
            : Text('${context.tt('terrain_contour_result')}: ${store.contours.length}');
        break;
      case TerrainTool.none:
        result = const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 460, maxHeight: 330),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x6653D9E8)),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0x3353D9E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                store.tool == TerrainTool.viewshed
                    ? Icons.visibility_outlined
                    : store.tool == TerrainTool.hillshade
                        ? Icons.wb_sunny_outlined
                        : Icons.terrain,
                color: kAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                switch (store.tool) {
                  TerrainTool.profile => context.tt('terrain_profile'),
                  TerrainTool.slope => context.tt('terrain_slope'),
                  TerrainTool.viewshed => context.tt('terrain_viewshed'),
                  TerrainTool.hillshade => context.tt('terrain_hillshade'),
                  TerrainTool.contours => context.tt('terrain_contours'),
                  TerrainTool.none => '',
                },
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: store.deactivate,
              icon: const Icon(Icons.close, size: 19),
            ),
          ]),
          Text(
            isProfile ? context.tt('terrain_pick_line') : context.tt('terrain_pick_center'),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          if (store.loading)
            Row(children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(context.tt('terrain_loading'))),
            ]),
          if (store.completed && !store.loading)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                const Icon(Icons.check_circle, color: Color(0xFF5DE6B0), size: 16),
                const SizedBox(width: 6),
                Text(context.mt('terrain_ready'),
                    style: const TextStyle(color: Color(0xFF9CF2C9), fontSize: 12)),
              ]),
            ),
          if (store.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(context.tt('terrain_${store.error}'),
                  style: const TextStyle(color: Color(0xFFFFB4AB))),
            ),
          if (result is! SizedBox) ...[
            const SizedBox(height: 6),
            result,
            const SizedBox(height: 5),
          ],
          if (store.tool == TerrainTool.viewshed) ...[
            Row(children: [
              Expanded(child: Text(context.tt('terrain_radius'))),
              Text('${store.viewshedRadiusM.toStringAsFixed(0)} m',
                  style: const TextStyle(color: Colors.white70)),
            ]),
            Slider(
              value: store.viewshedRadiusM,
              min: TerrainStore.minViewshedRadiusM,
              max: TerrainStore.maxViewshedRadiusM,
              divisions: 15,
              label: '${store.viewshedRadiusM.toStringAsFixed(0)} m',
              onChanged: store.loading ? null : store.setViewshedRadius,
            ),
            Row(children: [
              Expanded(child: Text(context.tt('terrain_observer_height'))),
              Text('${store.observerHeightM.toStringAsFixed(1)} m',
                  style: const TextStyle(color: Colors.white70)),
            ]),
            Slider(
              value: store.observerHeightM,
              min: TerrainStore.minObserverHeightM,
              max: TerrainStore.maxObserverHeightM,
              divisions: 98,
              label: '${store.observerHeightM.toStringAsFixed(1)} m',
              onChanged: store.loading ? null : store.setObserverHeight,
            ),
            Wrap(spacing: 14, runSpacing: 4, children: [
              _TerrainLegendItem(
                color: const Color(0xFF34C759),
                label: context.tt('terrain_visible'),
              ),
              _TerrainLegendItem(
                color: const Color(0xFFE45757),
                label: context.tt('terrain_hidden'),
              ),
            ]),
            const SizedBox(height: 5),
          ],
          Text(context.tt('terrain_note'),
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            OutlinedButton.icon(
              onPressed: store.points.isEmpty || store.loading ? null : store.undoPoint,
              icon: const Icon(Icons.undo, size: 17),
              label: Text(context.mt('undo')),
            ),
            OutlinedButton.icon(
              onPressed: store.points.isEmpty || store.loading ? null : store.clearPoints,
              icon: const Icon(Icons.delete_outline, size: 17),
              label: Text(context.mt('clear')),
            ),
            FilledButton.icon(
              onPressed: !ready || store.loading ? null : () => unawaited(store.analyze()),
              icon: const Icon(Icons.terrain, size: 17),
              label: Text(context.tt('terrain_analyze')),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _TerrainLegendItem extends StatelessWidget {
  const _TerrainLegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: color.withOpacity(0.75),
              border: Border.all(color: color, width: 1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

class _ProfileChartPainter extends CustomPainter {
  const _ProfileChartPainter(this.points);
  final List<ProfilePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.width <= 0 || size.height <= 0) return;
    final values = points.map((point) => point.elevationM).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = math.max(5.0, maxValue - minValue).toDouble();
    const inset = 8.0;
    final width = math.max(1.0, size.width - inset * 2).toDouble();
    final height = math.max(1.0, size.height - inset * 2).toDouble();
    final gridPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = inset + height * i / 4;
      canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), gridPaint);
    }
    final path = ui.Path();
    for (var i = 0; i < points.length; i++) {
      final x = inset + width * i / (points.length - 1);
      final y = inset + (maxValue - points[i].elevationM) / range * height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF8A65)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ProfileChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

// ───────────────────────── ئاراستەی قیبلە ─────────────────────────
/// هێڵی کورتترین ڕێگا بۆ کەعبە
class _QiblaLine extends StatelessWidget {
  const _QiblaLine({required this.pin});
  final LatLng? pin;

  @override
  Widget build(BuildContext context) {
    final origin = pin ?? MapCamera.of(context).center;
    return Stack(fit: StackFit.expand, children: [
      PolylineLayer(polylines: [
        Polyline(
          points: _greatCircle(origin, _kaaba),
          strokeWidth: 3.5,
          color: const Color(0xFF7CFC9A),
          borderStrokeWidth: 1.5,
          borderColor: Colors.black87,
        ),
      ]),
      MarkerLayer(markers: [
        Marker(
          point: _kaaba,
          width: 40,
          height: 40,
          child: const Icon(Icons.mosque, color: Color(0xFF7CFC9A), size: 34),
        ),
      ]),
    ]);
  }
}

class _QiblaCard extends StatelessWidget {
  const _QiblaCard({required this.center, required this.pin});
  final ValueNotifier<LatLng> center;
  final LatLng? pin;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LatLng>(
      valueListenable: center,
      builder: (context, c, _) {
        final origin = pin ?? c;
        final b = _bearing(origin, _kaaba);
        final d = _km(origin, _kaaba);
        return _Panel(
          child: Row(children: [
            // نەخشەکە باکوور بەرەو سەرەوەیە، بۆیە ئاراستەکە ڕاستەوخۆ دەسووڕێتەوە
            Transform.rotate(
              angle: _rad(b),
              child: const Icon(Icons.navigation,
                  color: Color(0xFF7CFC9A), size: 42),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.mt('tool_qibla'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('${context.mt('qibla_bearing')}: ${b.toStringAsFixed(1)}°'),
                  Text(
                      '${context.mt('qibla_distance')}: ${_fmtKm(d)} ${context.mt('km')}'),
                  Text(
                    context.mt(
                        pin == null ? 'qibla_from_center' : 'qibla_from_pin'),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close),
              onPressed: () => MapSettings.instance.setQibla(false),
            ),
          ]),
        );
      },
    );
  }
}

class _TrackRecorderPanel extends StatelessWidget {
  const _TrackRecorderPanel({required this.store});
  final NavStore store;

  String _formatElapsed(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:$minutes:$seconds'
        : '${value.inMinutes.remainder(60).toString().padLeft(2, '0')}:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = store.trackDistanceMeters / 1000;
    return _Panel(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(Icons.directions_walk,
              color: store.recordingTrack ? const Color(0xFFFF5252) : kGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.mt('track_recorder'),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          if (store.recordingTrack)
            const SizedBox(
              width: 9,
              height: 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFFF5252),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: _TrackMetric(
              icon: Icons.route,
              label: fmtDistance(distanceKm),
            ),
          ),
          Expanded(
            child: _TrackMetric(
              icon: Icons.timer_outlined,
              label: _formatElapsed(store.trackElapsed),
            ),
          ),
          Expanded(
            child: _TrackMetric(
              icon: Icons.location_on_outlined,
              label: '${store.trackPoints.length} ${context.mt('points')}',
            ),
          ),
        ]),
        if (!store.recordingTrack && store.trackSaved)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(context.mt('track_saved'),
                  style: const TextStyle(
                      color: Color(0xFF81C784), fontSize: 11)),
            ),
          )
        else if (!store.recordingTrack && store.trackPoints.length >= 2)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(context.mt('track_save_hint'),
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 11)),
            ),
          ),
        Row(children: [
          if (store.recordingTrack)
            TextButton.icon(
              onPressed: store.stopTrack,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: Text(context.mt('track_stop')),
            )
          else if (store.trackPoints.length >= 2 && !store.trackSaved)
            TextButton.icon(
              onPressed: () async {
                final saved = await store.saveTrack();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text(context.mt(
                        saved ? 'track_saved' : 'track_save_error')),
                  ));
              },
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(context.mt('track_save')),
            ),
          const Spacer(),
          TextButton.icon(
            onPressed: store.trackPoints.isEmpty ? null : store.clearTrack,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(context.mt('clear')),
          ),
        ]),
      ]),
    );
  }
}

class _TrackMetric extends StatelessWidget {
  const _TrackMetric({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: Colors.white60),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ]);
}

// ───────────────────────── پێکهاتە هاوبەشەکان ─────────────────────────
class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x4453D9E8)),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor = _mapText,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color iconColor;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: kPanel,
        elevation: 5,
        shape: const CircleBorder(
          side: BorderSide(color: Color(0x6653D9E8), width: 1.2),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: iconColor == _mapText ? kAccent : iconColor),
          ),
        ),
      ),
    );
  }
}

class _MapToolDock extends StatelessWidget {
  const _MapToolDock({required this.center});
  final ValueListenable<LatLng> center;

  @override
  Widget build(BuildContext context) {
    final settings = MapSettings.instance;
    final terrain = TerrainStore.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([settings, terrain, NavStore.instance]),
      builder: (context, _) {
        final nav = NavStore.instance;
        void selectTerrain(TerrainTool tool) {
          if (terrain.tool == tool) {
            terrain.deactivate();
          } else {
            settings.prepareForTerrainTool();
            terrain.activate(tool);
          }
        }

        final tools = <_DockTool>[
          _DockTool(xt(context, 'tool_mark'), Icons.location_on_outlined,
              settings.marking, () => settings.setMarking(!settings.marking)),
          _DockTool(context.mt('tool_area'), Icons.square_foot, settings.areaMode,
              () => settings.setAreaMode(!settings.areaMode)),
          _DockTool(context.mt('tool_circle'), Icons.circle_outlined, settings.circleMode,
              () => settings.setCircleMode(!settings.circleMode)),
          _DockTool(context.mt('tool_measure'), Icons.straighten,
              settings.measuring,
              () => settings.setMeasuring(!settings.measuring)),
          _DockTool(context.mt('track_recorder'), Icons.directions_walk,
              nav.recordingTrack || nav.trackPoints.isNotEmpty,
              () => settings.toggleGpsTrack?.call()),
          _DockTool(context.mt('tool_compass'), Icons.explore_outlined,
              settings.qibla, () => settings.setQibla(!settings.qibla)),
          _DockTool(context.mt('tool_azimuth'), Icons.explore,
              settings.azimuthMode,
              () => settings.setAzimuthMode(!settings.azimuthMode)),
          _DockTool(context.tt('terrain_profile'), Icons.show_chart,
              terrain.tool == TerrainTool.profile,
              () => selectTerrain(TerrainTool.profile)),
          _DockTool(context.tt('terrain_slope'), Icons.trending_up,
              terrain.tool == TerrainTool.slope,
              () => selectTerrain(TerrainTool.slope)),
          _DockTool(context.tt('terrain_viewshed'), Icons.visibility_outlined,
              terrain.tool == TerrainTool.viewshed,
              () => selectTerrain(TerrainTool.viewshed)),
          _DockTool(context.tt('terrain_hillshade'), Icons.wb_sunny_outlined,
              terrain.tool == TerrainTool.hillshade,
              () => selectTerrain(TerrainTool.hillshade)),
          _DockTool(context.tt('terrain_contours'), Icons.filter_hdr,
              terrain.tool == TerrainTool.contours,
              () => selectTerrain(TerrainTool.contours)),
          _DockTool(xt(context, 'tool_poi'), Icons.travel_explore, false,
              () => settings.openPoi?.call()),
          _DockTool('GPX/KML', Icons.import_export, false,
              () => settings.openExchange?.call()),
          _DockTool(context.mt('layer_kri_boundary'), Icons.account_balance_outlined,
              settings.kriBoundary,
              () => settings.setKriBoundary(!settings.kriBoundary)),
          _DockTool(context.mt('layer_history_sites'), Icons.history_edu_outlined,
              settings.publicHistorySites,
              () => settings.setPublicHistorySites(!settings.publicHistorySites)),
        ];

        return Material(
          color: kPanel,
          elevation: 10,
          shadowColor: const Color(0x55000000),
          borderRadius: BorderRadius.circular(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0x4453D9E8)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Row(children: [
                  const Icon(Icons.my_location, size: 13, color: Colors.white70),
                  const SizedBox(width: 6),
                  ValueListenableBuilder<LatLng>(
                    valueListenable: center,
                    builder: (_, point, __) => Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${point.latitude.toStringAsFixed(4)}°, ${point.longitude.toStringAsFixed(4)}°',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10.5),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.swipe, size: 15, color: Colors.white54),
                ]),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 70,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      for (var i = 0; i < tools.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        _DockToolButton(tool: tools[i]),
                      ],
                    ],
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _DockTool {
  const _DockTool(this.label, this.icon, this.selected, this.onTap);
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
}

class _DockToolButton extends StatelessWidget {
  const _DockToolButton({required this.tool});
  final _DockTool tool;

  @override
  Widget build(BuildContext context) {
    final foreground = tool.selected ? Colors.white : const Color(0xFFD5E0E5);
    return Semantics(
      button: true,
      selected: tool.selected,
      label: tool.label,
      child: Tooltip(
        message: tool.label,
        child: Material(
          color: tool.selected ? const Color(0xFF158C98) : kPanelSoft,
          borderRadius: BorderRadius.circular(17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
            side: BorderSide(
              color: tool.selected ? kAccent : const Color(0x3353D9E8),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: tool.onTap,
            child: SizedBox(
              width: 72,
              height: 68,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tool.icon, size: 24, color: foreground),
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      tool.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 9,
                        height: 1.05,
                        fontWeight:
                            tool.selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── مینیوی لای ڕاست/چەپ ─────────────────────────
class MapDrawer extends StatefulWidget {
  const MapDrawer({super.key});
  @override
  State<MapDrawer> createState() => _MapDrawerState();
}

class _MapDrawerState extends State<MapDrawer> {
  late final Future<bool> _admin = _isAdmin();

  Future<bool> _isAdmin() async {
    final db = Supabase.instance.client;
    final uid = db.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final me = await db
          .from('profiles')
          .select('role')
          .eq('id', uid)
          .single()
          .timeout(const Duration(seconds: 5));
      return me['role'] == 'admin';
    } catch (_) {
      return false;
    }
  }

  Widget _title(String text, IconData icon) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Row(children: [
          Icon(icon, size: 18, color: _mapBlue),
          const SizedBox(width: 9),
          Text(text,
              style: const TextStyle(
                color: _mapText,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              )),
        ]),
      );

  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _mapSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _drawerBorder),
          boxShadow: const [
            BoxShadow(color: Color(0x0A17212F), blurRadius: 12, offset: Offset(0, 3)),
          ],
        ),
        child: child,
      );

  Widget _baseMapTile(BuildContext context, MapSettings settings, BaseMap base) {
    final selected = settings.base == base;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        settings.setBase(base);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _mapBlue.withOpacity(.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _mapBlue.withOpacity(.55) : _drawerBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(children: [
          Icon(_baseIcons[base], size: 19,
              color: selected ? _mapBlue : _mapSecondaryText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.mt(_baseKeys[base]!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? _mapBlue : _mapText,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                )),
          ),
          if (selected) const Icon(Icons.check_circle, size: 16, color: _mapBlue),
        ]),
      ),
    );
  }

  Widget _layerSwitch({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: _mapSurface,
        activeTrackColor: _mapBlue,
        inactiveTrackColor: const Color(0xFFE2E7EE),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        secondary: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: value ? _mapBlue.withOpacity(.09) : const Color(0xFFF1F4F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              size: 20, color: value ? _mapBlue : _mapSecondaryText),
        ),
        title: Text(title,
            style: const TextStyle(
                color: _mapText, fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle,
                style: const TextStyle(
                    color: _drawerMuted, fontSize: 11, height: 1.25)),
      );

  Widget _toolTile({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected ? _mapBlue.withOpacity(.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected ? _mapBlue : const Color(0xFFF1F4F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      size: 20,
                      color: selected ? Colors.white : _mapSecondaryText),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? _mapBlue : _mapText,
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      )),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.chevron_right,
                  size: 19,
                  color: selected ? _mapBlue : const Color(0xFFA8B0BC),
                ),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = MapSettings.instance;
    return Drawer(
      width: math.min(MediaQuery.sizeOf(context).width * .9, 380.0).toDouble(),
      backgroundColor: _drawerBackground,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: s,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  padding: const EdgeInsets.fromLTRB(16, 18, 8, 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF155E75), Color(0xFF123B58)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26123B58),
                        blurRadius: 16,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.map_rounded,
                          color: Colors.white, size: 27),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('app_title'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              )),
                          const SizedBox(height: 4),
                          Text(context.mt('drawer_subtitle'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD3E7EF),
                                height: 1.25,
                                fontSize: 11,
                              )),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.mt('menu'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70),
                    ),
                  ]),
                ),

                _title(context.mt('base_map'), Icons.layers_rounded),
                _card(
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.9,
                    children: [
                      for (final base in BaseMap.values)
                        _baseMapTile(context, s, base),
                    ],
                  ),
                ),

                _title(context.mt('layers'), Icons.tune_rounded),
                _card(
                  child: Column(children: [
                    _layerSwitch(
                      icon: Icons.place_outlined,
                      title: context.tr('layer_names'),
                      value: s.names,
                      onChanged: s.setNames,
                    ),
                    _layerSwitch(
                      icon: Icons.public_outlined,
                      title: context.mt('layer_borders'),
                      value: s.borders,
                      onChanged: s.setBorders,
                    ),
                    _layerSwitch(
                      icon: Icons.account_balance_outlined,
                      title: context.mt('layer_kri_boundary'),
                      value: s.kriBoundary,
                      onChanged: s.setKriBoundary,
                    ),
                    if (s.kriBoundary)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        tileColor: const Color(0xFFF4F8FD),
                        leading: const Icon(Icons.zoom_out_map,
                            color: _mapBlue),
                        title: Text(context.mt('boundary_focus'),
                            style: const TextStyle(
                                color: _mapText,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          s.kriBoundaryAreaKm2 == null ||
                                  s.kriBoundaryPerimeterKm == null
                              ? context.mt('boundary_loading')
                              : '${context.mt('boundary_area')}: '
                                  '${s.kriBoundaryAreaKm2!.toStringAsFixed(1)} km² · '
                                  '${context.mt('boundary_perimeter')}: '
                                  '${s.kriBoundaryPerimeterKm!.toStringAsFixed(1)} km\n'
                                  '${context.mt('boundary_approx_note')}',
                          style: const TextStyle(
                              color: _drawerMuted, fontSize: 10, height: 1.3),
                        ),
                        onTap: () {
                          s.focusKriBoundary?.call();
                          Navigator.pop(context);
                        },
                      ),
                    _layerSwitch(
                      icon: Icons.account_balance_outlined,
                      title: context.mt('layer_history_sites'),
                      subtitle: context.mt('layer_history_hint'),
                      value: s.publicHistorySites,
                      onChanged: s.setPublicHistorySites,
                    ),
                  ]),
                ),

                _title(context.tr('language'), Icons.language_rounded),
                _card(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: LanguageChips(),
                  ),
                ),

                _card(
                  child: Column(children: [
                    FutureBuilder<bool>(
                      future: _admin,
                      builder: (context, snapshot) {
                        if (snapshot.data != true) {
                          return const SizedBox.shrink();
                        }
                        return _toolTile(
                          title: context.mt('admin_panel'),
                          icon: Icons.admin_panel_settings_outlined,
                          selected: false,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminPanelScreen()),
                            );
                          },
                        );
                      },
                    ),
                    _toolTile(
                      title: context.tr('logout'),
                      icon: Icons.logout_rounded,
                      selected: false,
                      onTap: signOutAndClear,
                    ),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DynamicPlaceLabels extends StatelessWidget {
  final List<Map<String, dynamic>> places;
  final String lang;

  const _DynamicPlaceLabels({
    required this.places,
    required this.lang,
  });

  String _localizedName(Map<String, dynamic> place) {
    final rawNames = place['names'];
    if (rawNames is Map) {
      final names = <String, String>{};
      rawNames.forEach((key, value) {
        if (value != null && value.toString().trim().isNotEmpty) {
          names[key.toString()] = value.toString().trim();
        }
      });

      final List<String> preferred;
      switch (lang) {
        case 'ckb':
          preferred = const ['ckb', 'ku', 'default', 'ar', 'en'];
          break;
        case 'bdn':
          preferred = const ['ku', 'ckb', 'default', 'ar', 'en'];
          break;
        case 'ar':
          preferred = const ['ar', 'default', 'ku', 'ckb', 'en'];
          break;
        default:
          preferred = const ['en', 'default', 'ar', 'ku', 'ckb'];
      }

      for (final key in preferred) {
        final value = names[key];
        if (value != null && value.isNotEmpty) return value;
      }
    }

    return (place['name'] ?? '').toString().trim();
  }

  int _priority(String kind) {
    switch (kind) {
      case 'city':
      case 'town':
        return 0;
      case 'village':
      case 'hamlet':
      case 'suburb':
      case 'neighbourhood':
      case 'quarter':
        return 1;
      default:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PlacesStore.instance,
      builder: (context, _) {
        final camera = MapCamera.of(context);
        final zoom = camera.zoom;
        final int cap =
            zoom < 11 ? 18 : (zoom < 13 ? 32 : (zoom < 15 ? 48 : 65));

        final markers = <Marker>[];
        final seen = <String>{};
        final acceptedPoints = <LatLng>[];
        final minimumLabelDistance = zoom < 11
            ? 2600.0
            : (zoom < 13 ? 1100.0 : (zoom < 15 ? 420.0 : 150.0));

        void addLabel(LatLng point, String name, String kind) {
          if (name.trim().isEmpty || markers.length >= cap) return;
          final identity =
              '${name.toLowerCase()}:${point.latitude.toStringAsFixed(3)}:${point.longitude.toStringAsFixed(3)}';
          if (!seen.add(identity)) return;

          // Prevent neighboring labels from stacking on top of each other.
          for (final accepted in acceptedPoints) {
            if (_calculateDistance(accepted, point) < minimumLabelDistance) {
              return;
            }
          }
          acceptedPoints.add(point);

          markers.add(
            Marker(
              point: point,
              width: 168,
              height: 48,
              alignment: Alignment.topCenter,
              child: _Label(name, kind),
            ),
          );
        }

        // First use the offline place catalogue. It provides labels even
        // before Overpass responds or when the device is offline.
        for (final place in PlacesStore.instance.visible(
          camera.visibleBounds,
          zoom,
          cap: cap,
        )) {
          final name = place.nameFor(lang);
          addLabel(
            LatLng(place.lat, place.lng),
            name,
            place.kind,
          );
        }

        // Then fill remaining space with current-area Overpass results.
        final dynamicVisible = <Map<String, dynamic>>[];
        for (final place in places) {
          final lat = double.tryParse('${place['lat']}');
          final lon = double.tryParse('${place['lng']}');
          if (lat == null || lon == null) continue;

          final point = LatLng(lat, lon);
          if (!camera.visibleBounds.contains(point)) continue;

          final name = _localizedName(place);
          if (name.isEmpty) continue;

          final kind = (place['kind'] ?? 'place').toString();
          if (kind == 'public_history') continue;
          dynamicVisible.add(<String, dynamic>{
            'point': point,
            'name': name,
            'kind': kind,
            'priority': _priority(kind),
          });
        }

        dynamicVisible.sort((a, b) =>
            (a['priority'] as int).compareTo(b['priority'] as int));

        for (final place in dynamicVisible) {
          if (markers.length >= cap) break;
          addLabel(
            place['point'] as LatLng,
            place['name'] as String,
            place['kind'] as String,
          );
        }

        return markers.isEmpty
            ? const SizedBox.shrink()
            : MarkerLayer(markers: markers);
      },
    );
  }
}

class _PublicHistoryMarkers extends StatelessWidget {
  const _PublicHistoryMarkers({required this.places, required this.lang});
  final List<Map<String, dynamic>> places;
  final String lang;

  String _nameFor(Map<String, dynamic> place) {
    final rawNames = place['names'];
    if (rawNames is Map) {
      final preferred = switch (lang) {
        'ckb' => const ['ckb', 'ku', 'default', 'ar', 'en'],
        'bdn' => const ['ku', 'ckb', 'default', 'ar', 'en'],
        'ar' => const ['ar', 'default', 'ku', 'ckb', 'en'],
        _ => const ['en', 'default', 'ar', 'ku', 'ckb'],
      };
      for (final key in preferred) {
        final value = rawNames[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return (place['name'] ?? '').toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final mapCenter = camera.center;
    if (mapCenter == null) return const SizedBox.shrink();
    final candidates = <({LatLng point, String name, double distance})>[];
    for (final place in places) {
      if (place['kind'] != 'public_history') continue;
      final lat = double.tryParse('${place['lat']}');
      final lon = double.tryParse('${place['lng']}');
      if (lat == null || lon == null) continue;
      final point = LatLng(lat, lon);
      if (!camera.visibleBounds.contains(point)) continue;
      final name = _nameFor(place);
      if (name.isEmpty) continue;
      candidates.add((
        point: point,
        name: name,
        distance: _calculateDistance(mapCenter, point),
      ));
    }
    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    final markers = candidates.take(35).map((site) => Marker(
          point: site.point,
          width: 170,
          height: 48,
          alignment: Alignment.topCenter,
          child: _PublicHistoryLabel(site.name),
        )).toList(growable: false);
    return markers.isEmpty
        ? const SizedBox.shrink()
        : MarkerLayer(markers: markers);
  }
}

class _PublicHistoryLabel extends StatelessWidget {
  const _PublicHistoryLabel(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xE51A222B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kGold, width: 1),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.account_balance_outlined, color: kGold, size: 17),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
      );
}

double _calculateDistance(LatLng a, LatLng b) {
  const double earthRadius = 6371000;

  final double lat1 = a.latitude * math.pi / 180;
  final double lat2 = b.latitude * math.pi / 180;

  final double dLat =
      (b.latitude - a.latitude) * math.pi / 180;

  final double dLon =
      (b.longitude - a.longitude) * math.pi / 180;

  final double h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  return earthRadius *
      2 *
      math.atan2(math.sqrt(h), math.sqrt(1 - h));
}
