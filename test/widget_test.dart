import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_tiergarto/core/map_hotspots.dart';
import 'package:flutter_application_tiergarto/feature_animals/animal.dart';

void main() {
  group('Kartenhotspots', () {
    test('alle 27 Gehege sind vorhanden', () {
      expect(kHotspots.map((h) => h.enclosureNr).toSet().length, 27);
    });

    // Punkte (in Bildpixeln von map_raw.png) mitten in beschrifteten Gehegen
    const samples = {
      1: Offset(420, 700),
      2: Offset(614, 660),
      4: Offset(840, 775),
      7: Offset(688, 952),
      12: Offset(713, 1290),
      17: Offset(883, 1585),
      23: Offset(451, 1598),
      25: Offset(359, 1160),
    };

    samples.forEach((nr, point) {
      test('Tipp auf Gehege $nr wird erkannt', () {
        expect(findEnclosureByImagePoint(point), nr);
      });
    });

    test('Tipp außerhalb der Gehege liefert null', () {
      expect(findEnclosureByImagePoint(const Offset(180, 390)), isNull);
    });
  });

  group('Animal', () {
    test('parseEnclosureNr akzeptiert Zahl und Text', () {
      expect(parseEnclosureNr(3), 3);
      expect(parseEnclosureNr(3.0), 3);
      expect(parseEnclosureNr(' 12 '), 12);
      expect(parseEnclosureNr('abc'), isNull);
      expect(parseEnclosureNr(null), isNull);
    });

    test('Suche filtert nach Name, Info und Gehege', () {
      const animal = Animal(
        id: 'x',
        name: 'Erdmännchen',
        info: 'Frisst gern Insekten',
        enclosureNr: 14,
      );
      expect(animal.matches(''), isTrue);
      expect(animal.matches('erdm'), isTrue);
      expect(animal.matches('INSEKT'), isTrue);
      expect(animal.matches('14'), isTrue);
      expect(animal.matches('Löwe'), isFalse);
    });
  });
}
