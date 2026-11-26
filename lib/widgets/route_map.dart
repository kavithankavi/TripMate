import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// OpenStreetMap view showing a route and the current position.
/// No API key needed. Tiles are loaded on demand and not bundled.
class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.route,
    this.follow = true,
    this.interactive = false,
  });

  final List<LatLng> route;

  /// Keep the latest point centred (live trip). Otherwise fit the whole route.
  final bool follow;
  final bool interactive;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final _controller = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    if (_ready && widget.follow && widget.route.isNotEmpty) {
      _controller.move(widget.route.last, _controller.camera.zoom);
    }
  }

  void _onReady() {
    _ready = true;
    if (!widget.follow && widget.route.length > 1) {
      _controller.fitCamera(CameraFit.coordinates(
        coordinates: widget.route,
        padding: const EdgeInsets.all(24),
        maxZoom: 17,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    if (route.isEmpty) {
      return Container(
        color: const Color(0xFFE2EBEA),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: const Text('Waiting for GPS…',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
      );
    }
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: route.last,
        initialZoom: 16,
        onMapReady: _onReady,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.tripmate',
        ),
        if (route.length > 1)
          PolylineLayer(polylines: [
            Polyline(
                points: route, strokeWidth: 4, color: AppColors.primary),
          ]),
        MarkerLayer(markers: [
          if (!widget.follow)
            Marker(
                point: route.first,
                width: 14,
                height: 14,
                child: const _Dot(color: AppColors.success)),
          Marker(
              point: route.last,
              width: 18,
              height: 18,
              child: _Dot(
                  color: widget.follow ? AppColors.accent : AppColors.danger)),
        ]),
        // Own credit label: flutter_map's SimpleAttributionWidget prefixes
        // "flutter_map |". OpenStreetMap's tile policy still needs this credit.
        const _OsmCredit(),
      ],
    );
  }
}

class _OsmCredit extends StatelessWidget {
  const _OsmCredit();

  @override
  Widget build(BuildContext context) => const Align(
        alignment: Alignment.bottomRight,
        child: ColoredBox(
          color: Color(0xB3FFFFFF),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: Text('© OpenStreetMap',
                style: TextStyle(fontSize: 9, color: AppColors.text)),
          ),
        ),
      );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
        ),
      );
}
