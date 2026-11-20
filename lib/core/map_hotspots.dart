import 'dart:ui' show Offset;

/// Gehege-Polygone der Zookarte (übernommen aus MapActivity.java).
///
/// Die Koordinaten stammen aus der alten Android-App und sind in Geräte-Pixeln
/// eines 420-dpi-Geräts angegeben: `map_raw.png` (1080 x 1920 px) lag dort in
/// `res/drawable` und wurde daher um den Faktor 2,625 hochskaliert.
/// [kHotspotScale] rechnet Bildpixel in dieses Koordinatensystem um.
const double kHotspotScale = 2.625;

/// Größe des Kartenbildes `assets/images/map_raw.png` in Pixeln.
const double kMapImageWidth = 1080;
const double kMapImageHeight = 1920;

class PolygonHotspot {
  const PolygonHotspot(this.enclosureNr, this.points);

  final int enclosureNr;
  final List<Offset> points;
}

/// Liefert die Gehege-Nummer zum Punkt [imagePoint] (in Bildpixeln)
/// oder `null`, wenn kein Gehege getroffen wurde.
int? findEnclosureByImagePoint(Offset imagePoint) {
  final p = imagePoint * kHotspotScale;
  for (final hotspot in kHotspots) {
    if (pointInPolygon(p, hotspot.points)) return hotspot.enclosureNr;
  }
  return null;
}

/// Point-in-Polygon-Test mittels Ray-Casting-Algorithmus.
/// Quelle: https://www.youtube.com/watch?v=RSXM9bgqxJM
bool pointInPolygon(Offset point, List<Offset> polygon) {
  var inside = false;
  final n = polygon.length;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final xi = polygon[i].dx, yi = polygon[i].dy;
    final xj = polygon[j].dx, yj = polygon[j].dy;
    final intersect =
        ((yi > point.dy) != (yj > point.dy)) &&
        (point.dx < (xj - xi) * (point.dy - yi) / (yj - yi) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

const List<PolygonHotspot> kHotspots = [
  PolygonHotspot(1, [
    Offset(1112, 1666),
    Offset(787, 2068),
    Offset(884, 2144),
    Offset(1065, 1921),
    Offset(1115, 1942),
    Offset(1254, 1782),
  ]),
  PolygonHotspot(2, [
    Offset(1569, 1600),
    Offset(1417, 1766),
    Offset(1485, 1816),
    Offset(1627, 1816),
    Offset(1724, 1866),
    Offset(1787, 1934),
    Offset(1900, 1824),
  ]),
  PolygonHotspot(3, [
    Offset(2005, 1824),
    Offset(1900, 1934),
    Offset(2031, 2047),
    Offset(2131, 1908),
  ]),
  PolygonHotspot(4, [
    Offset(2367, 1622),
    Offset(2136, 1913),
    Offset(2031, 2047),
    Offset(1885, 2207),
    Offset(2031, 2388),
    Offset(2504, 1845),
  ]),
  PolygonHotspot(5, [
    Offset(1390, 1822),
    Offset(1482, 1819),
    Offset(1458, 1995),
    Offset(1379, 1995),
  ]),
  PolygonHotspot(6, [
    Offset(1479, 1827),
    Offset(1566, 1811),
    Offset(1645, 1824),
    Offset(1718, 1871),
    Offset(1787, 1934),
    Offset(1579, 2179),
    Offset(1503, 2174),
    Offset(1442, 2119),
    Offset(1442, 2034),
    Offset(1458, 1979),
  ]),
  PolygonHotspot(7, [
    Offset(1821, 2263),
    Offset(1621, 2463),
    Offset(1797, 2740),
    Offset(2017, 2519),
  ]),
  PolygonHotspot(8, [
    Offset(1952, 2581),
    Offset(2092, 2716),
    Offset(2106, 2824),
    Offset(2022, 2840),
    Offset(1874, 2911),
    Offset(1797, 2742),
  ]),
  PolygonHotspot(9, [
    Offset(1803, 2756),
    Offset(1629, 2811),
    Offset(1737, 3019),
    Offset(1889, 2948),
  ]),
  PolygonHotspot(10, [
    Offset(1905, 3011),
    Offset(1765, 3063),
    Offset(1827, 3190),
    Offset(1974, 3142),
  ]),
  PolygonHotspot(11, [
    Offset(2227, 2958),
    Offset(2081, 2995),
    Offset(2200, 3314),
    Offset(2327, 3257),
  ]),
  PolygonHotspot(12, [
    Offset(2013, 3211),
    Offset(1650, 3335),
    Offset(1718, 3527),
    Offset(1895, 3479),
    Offset(1984, 3657),
    Offset(2060, 3611),
    Offset(1997, 3451),
    Offset(2097, 3411),
  ]),
  PolygonHotspot(13, [
    Offset(2097, 3411),
    Offset(2161, 3559),
    Offset(2074, 3606),
    Offset(1997, 3451),
  ]),
  PolygonHotspot(14, [
    Offset(1984, 3659),
    Offset(2097, 3843),
    Offset(2290, 3738),
    Offset(2161, 3559),
  ]),
  PolygonHotspot(15, [
    Offset(2582, 3164),
    Offset(2413, 3335),
    Offset(2529, 3442),
    Offset(2685, 3259),
  ]),
  PolygonHotspot(16, [
    Offset(2345, 3343),
    Offset(2227, 3455),
    Offset(2540, 3795),
    Offset(2666, 3669),
  ]),
  PolygonHotspot(17, [
    Offset(2097, 3843),
    Offset(2129, 4504),
    Offset(2674, 4338),
    Offset(2298, 3738),
  ]),
  PolygonHotspot(18, [
    Offset(2053, 4322),
    Offset(1958, 4346),
    Offset(2003, 4504),
    Offset(2111, 4497),
  ]),
  PolygonHotspot(19, [
    Offset(1958, 4359),
    Offset(1853, 4383),
    Offset(1890, 4524),
    Offset(1997, 4504),
  ]),
  PolygonHotspot(20, [
    Offset(1850, 4396),
    Offset(1750, 4420),
    Offset(1803, 4561),
    Offset(1890, 4524),
  ]),
  PolygonHotspot(21, [
    Offset(1682, 4422),
    Offset(1587, 4448),
    Offset(1619, 4582),
    Offset(1734, 4561),
  ]),
  PolygonHotspot(22, [
    Offset(1582, 4451),
    Offset(1482, 4475),
    Offset(1498, 4585),
    Offset(1619, 4582),
  ]),
  PolygonHotspot(23, [
    Offset(1250, 3779),
    Offset(939, 3832),
    Offset(1116, 4658),
    Offset(1498, 4590),
    Offset(1419, 4180),
    Offset(1321, 4111),
  ]),
  PolygonHotspot(24, [
    Offset(879, 3543),
    Offset(1206, 3480),
    Offset(1250, 3706),
    Offset(1247, 3779),
    Offset(942, 3840),
  ]),
  PolygonHotspot(25, [
    Offset(766, 2898),
    Offset(1074, 2858),
    Offset(1156, 3195),
    Offset(795, 3248),
  ]),
  PolygonHotspot(26, [
    Offset(708, 2648),
    Offset(911, 2598),
    Offset(940, 2735),
    Offset(1056, 2679),
    Offset(1090, 2806),
    Offset(979, 2795),
    Offset(979, 2866),
    Offset(766, 2903),
  ]),
  PolygonHotspot(27, [
    Offset(1358, 3786),
    Offset(1379, 3879),
    Offset(1342, 3879),
    Offset(1379, 4035),
    Offset(1434, 4134),
    Offset(1513, 4066),
    Offset(1606, 4066),
    Offset(1695, 4087),
    Offset(1737, 4137),
    Offset(1797, 4038),
    Offset(1705, 3967),
    Offset(1606, 3924),
    Offset(1595, 3811),
    Offset(1563, 3811),
    Offset(1563, 3751),
    Offset(1529, 3748),
  ]),
];
