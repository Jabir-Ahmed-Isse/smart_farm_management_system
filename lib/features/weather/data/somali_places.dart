/// A named place with coordinates, so a farmer can pick their town instead of
/// typing latitude and longitude by hand.
class Place {
  const Place(this.name, this.region, this.latitude, this.longitude);

  final String name;
  final String region;
  final double latitude;
  final double longitude;

  /// Loose match on the town or region name, accent/case-insensitive enough
  /// for the Somali/English spellings farmers actually type.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) || region.toLowerCase().contains(q);
  }
}

/// Somali towns and district centres, grouped loosely by region. Coordinates
/// are town-centre approximations — good enough for a local forecast.
/// Sorted by name so the picker reads alphabetically.
const somaliPlaces = <Place>[
  Place('Afgooye', 'Lower Shabelle', 2.1385, 45.1201),
  Place('Afmadow', 'Lower Juba', 0.5133, 42.0722),
  Place('Baidoa (Baydhabo)', 'Bay', 3.1136, 43.6498),
  Place('Balcad', 'Middle Shabelle', 2.3500, 45.3833),
  Place('Baraawe (Brava)', 'Lower Shabelle', 1.1122, 44.0289),
  Place('Bardheere (Bardera)', 'Gedo', 2.3417, 42.2792),
  Place('Beledweyne', 'Hiiraan', 4.7358, 45.2036),
  Place('Berbera', 'Woqooyi Galbeed', 10.4396, 45.0143),
  Place('Boorama (Borama)', 'Awdal', 9.9361, 43.1836),
  Place('Bosaso (Boosaaso)', 'Bari', 11.2842, 49.1816),
  Place('Bulo Burte', 'Hiiraan', 3.8500, 45.5667),
  Place('Burco (Burao)', 'Togdheer', 9.5221, 45.5336),
  Place('Buurhakaba', 'Bay', 2.7994, 44.0833),
  Place('Buuhoodle', 'Togdheer', 8.2333, 46.3333),
  Place('Cadaado (Adado)', 'Galgaduud', 6.0956, 46.6367),
  Place('Cadale (Adale)', 'Middle Shabelle', 2.7500, 46.3167),
  Place('Ceel Buur (El Bur)', 'Galgaduud', 4.6871, 46.6167),
  Place('Ceel Dheer (El Dher)', 'Galgaduud', 3.8500, 47.1667),
  Place('Ceel Waaq (El Wak)', 'Gedo', 2.8028, 40.9314),
  Place('Ceerigaabo (Erigavo)', 'Sanaag', 10.6160, 47.3690),
  Place('Dhuusamareeb', 'Galgaduud', 5.5352, 46.3868),
  Place('Dinsoor', 'Bay', 2.4167, 42.9833),
  Place('Doolow (Dollow)', 'Gedo', 4.1667, 42.0833),
  Place('Eyl', 'Nugaal', 7.9803, 49.8164),
  Place('Gaalkacyo (Galkayo)', 'Mudug', 6.7697, 47.4308),
  Place('Garbahaarey', 'Gedo', 3.3286, 42.2206),
  Place('Garoowe (Garowe)', 'Nugaal', 8.4054, 48.4845),
  Place('Hargeisa (Hargeysa)', 'Woqooyi Galbeed', 9.5624, 44.0770),
  Place('Iskushuban', 'Bari', 10.2833, 50.2333),
  Place('Jamaame', 'Lower Juba', 0.0703, 42.7472),
  Place('Jariiban', 'Mudug', 7.3667, 48.6167),
  Place('Jowhar', 'Middle Shabelle', 2.7809, 45.5005),
  Place('Kismayo (Kismaayo)', 'Lower Juba', -0.3582, 42.5454),
  Place('Laascaanood (Las Anod)', 'Sool', 8.4774, 47.3597),
  Place('Luuq', 'Gedo', 3.8028, 42.5442),
  Place('Marka (Merca)', 'Lower Shabelle', 1.7147, 44.7716),
  Place('Mogadishu (Muqdisho)', 'Banadir', 2.0469, 45.3182),
  Place('Qardho', 'Bari', 9.5008, 49.0864),
  Place('Qoryooley', 'Lower Shabelle', 1.7869, 44.5297),
  Place('Saakow', 'Middle Juba', 1.9500, 42.6333),
  Place('Taleex', 'Sool', 9.1728, 48.4147),
  Place('Waajid', 'Bakool', 3.8103, 43.2458),
  Place('Wanlaweyn', 'Lower Shabelle', 2.6186, 44.8917),
  Place('Xudur (Hudur)', 'Bakool', 4.1213, 43.8894),
];
