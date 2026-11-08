/// Mapbox configuration for the raster-style tile setup used with flutter_map.
///
/// Supply the public token at build/run time with:
/// --dart-define=MAPBOX_ACCESS_TOKEN=pk...
class MapboxConfig {
  MapboxConfig._();

  static const String accessToken =
      String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  static bool get isConfigured => accessToken.trim().isNotEmpty;

  static String styleTiles(String styleId) {
    // Never throw from a widget build. A missing/invalid token must not turn
    // the entire map screen into Flutter's red/orange error overlay.
    if (isConfigured) {
      return 'https://api.mapbox.com/styles/v1/mapbox/$styleId/'
          'tiles/256/{z}/{x}/{y}?access_token=$accessToken';
    }

    // Public fallbacks keep the map useful without a Mapbox token. Keep
    // projection/order conventions explicit: Esri uses {z}/{y}/{x}.
    if (styleId.startsWith('satellite')) {
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/'
          'World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
    if (styleId.startsWith('outdoors')) {
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/'
          'World_Topo_Map/MapServer/tile/{z}/{y}/{x}';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }
}
