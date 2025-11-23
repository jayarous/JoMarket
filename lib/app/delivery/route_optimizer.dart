import 'dart:math' as math;

import 'delivery_models.dart';

class RouteOptimizer {
  const RouteOptimizer._();

  static List<int> optimizeOrder(List<RouteWaypoint> waypoints) {
    if (waypoints.length <= 2) {
      return List<int>.generate(waypoints.length, (index) => index);
    }

    final visited = <int>{};
    final order = <int>[];
    var current = 0;

    order.add(current);
    visited.add(current);

    while (visited.length < waypoints.length) {
      var nearest = -1;
      var minDistance = double.infinity;

      for (var i = 0; i < waypoints.length; i++) {
        if (visited.contains(i)) continue;

        final distance = calculateDistance(
          waypoints[current].latitude,
          waypoints[current].longitude,
          waypoints[i].latitude,
          waypoints[i].longitude,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearest = i;
        }
      }

      if (nearest != -1) {
        order.add(nearest);
        visited.add(nearest);
        current = nearest;
      } else {
        break;
      }
    }

    return order;
  }

  static double totalDistance(
    List<RouteWaypoint> waypoints,
    List<int> order,
  ) {
    var total = 0.0;
    for (var i = 0; i < order.length - 1; i++) {
      final from = waypoints[order[i]];
      final to = waypoints[order[i + 1]];
      total += calculateDistance(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
    }
    return total;
  }

  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static int estimateDuration(double distanceMeters) {
    const avgSpeedKmh = 30.0;
    final distanceKm = distanceMeters / 1000.0;
    final hours = distanceKm / avgSpeedKmh;
    return (hours * 60).round();
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
}
