import 'package:flutter_test/flutter_test.dart';

import 'package:jo_market/app/delivery/delivery_models.dart';
import 'package:jo_market/app/delivery/route_optimizer.dart';

void main() {
  group('RouteOptimizer', () {
    test('optimizes waypoint order using nearest neighbor', () {
      final List<RouteWaypoint> waypoints = [
        RouteWaypoint(
          latitude: 31.963158,
          longitude: 35.930359,
          type: 'dropoff',
          address: 'Waypoint A',
        ),
        RouteWaypoint(
          latitude: 31.951569,
          longitude: 35.923963,
          type: 'dropoff',
          address: 'Waypoint B',
        ),
        RouteWaypoint(
          latitude: 31.964456,
          longitude: 35.906635,
          type: 'dropoff',
          address: 'Waypoint C',
        ),
      ];

      final order = RouteOptimizer.optimizeOrder(waypoints);

      expect(order.length, waypoints.length);
      expect(order.toSet().length, waypoints.length);
      expect(order.first, 0); // starting point pinned
    });

    test('calculates total distance between ordered waypoints', () {
      final List<RouteWaypoint> waypoints = [
        RouteWaypoint(
          latitude: 31.963158,
          longitude: 35.930359,
          type: 'dropoff',
          address: 'Waypoint A',
        ),
        RouteWaypoint(
          latitude: 31.951569,
          longitude: 35.923963,
          type: 'dropoff',
          address: 'Waypoint B',
        ),
        RouteWaypoint(
          latitude: 31.964456,
          longitude: 35.906635,
          type: 'dropoff',
          address: 'Waypoint C',
        ),
      ];
      final order = [0, 1, 2];

      final distance = RouteOptimizer.totalDistance(waypoints, order);

      expect(distance, greaterThan(1000));
      expect(distance, lessThan(10000));
    });

    test('estimates duration from distance', () {
      final minutes = RouteOptimizer.estimateDuration(15000);
      expect(minutes, 30); // 15km at 30km/h => 30 minutes
    });
  });
}
