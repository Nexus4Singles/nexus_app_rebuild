class MarketCountryUtils {
  static bool isUkMarket(String? country) {
    if (country == null || country.trim().isEmpty) return false;

    const ukCountries = <String>{
      'united kingdom',
      'uk',
      'england',
      'scotland',
      'wales',
      'northern ireland',
    };
    return ukCountries.contains(country.trim().toLowerCase());
  }

  static bool isEuropeanMarket(String? country) {
    if (country == null || country.trim().isEmpty) return false;

    const europeanCountries = <String>{
      'albania',
      'andorra',
      'austria',
      'belarus',
      'belgium',
      'bosnia and herzegovina',
      'bulgaria',
      'croatia',
      'cyprus',
      'czech republic',
      'czechia',
      'denmark',
      'estonia',
      'finland',
      'france',
      'germany',
      'greece',
      'hungary',
      'iceland',
      'ireland',
      'italy',
      'kosovo',
      'latvia',
      'liechtenstein',
      'lithuania',
      'luxembourg',
      'malta',
      'moldova',
      'monaco',
      'montenegro',
      'netherlands',
      'north macedonia',
      'norway',
      'poland',
      'portugal',
      'romania',
      'russia',
      'san marino',
      'serbia',
      'slovakia',
      'slovenia',
      'spain',
      'sweden',
      'switzerland',
      'ukraine',
      'vatican city',
    };
    return europeanCountries.contains(country.trim().toLowerCase());
  }

  static bool isPrelaunchCarouselMarket(String? country) {
    if (country == null || country.trim().isEmpty) return false;
    final normalized = country.trim().toLowerCase();
    return normalized == 'united states' ||
        normalized == 'us' ||
        normalized == 'usa' ||
        normalized == 'america' ||
        normalized == 'canada' ||
        isEuropeanMarket(country);
  }

  static String marketCodeForCountry(String country) {
    final normalized = country.trim().toLowerCase();
    switch (normalized) {
      case 'united states':
      case 'us':
      case 'usa':
      case 'america':
        return 'us';
      case 'czech republic':
        return 'czechia';
      case 'united kingdom':
      case 'uk':
      case 'england':
      case 'scotland':
      case 'wales':
      case 'northern ireland':
        return 'uk';
      default:
        return normalized.replaceAll(' ', '_');
    }
  }

  static bool isAfricanMarket(String? country) {
    if (country == null || country.trim().isEmpty) return false;

    final normalized = country.trim().toLowerCase();
    const africanCountries = <String>{
      'nigeria',
      'ghana',
      'south africa',
      'kenya',
      'egypt',
      'ethiopia',
      'tanzania',
      'uganda',
      'rwanda',
      'cameroon',
      'senegal',
      'morocco',
      'algeria',
      'tunisia',
      'zimbabwe',
      'zambia',
      'botswana',
      'malawi',
      'namibia',
      'mozambique',
      'angola',
      'mauritius',
      'ivory coast',
      'côte d’ivoire',
      'cote d ivoire',
      'sudan',
      'liberia',
      'sierra leone',
      'benin',
      'burkina faso',
      'mali',
      'niger',
      'togo',
      'guinea',
      'congo',
      'democratic republic of the congo',
      'dr congo',
      'djibouti',
      'eritrea',
      'somalia',
      'comoros',
      'sao tome and principe',
      'seychelles',
      'cape verde',
      'equatorial guinea',
      'gabon',
      'central african republic',
      'chad',
      'burundi',
      'eswatini',
      'lesotho',
      'south sudan',
      'republic of the congo',
    };

    return africanCountries.contains(normalized);
  }

  static bool isUkUsCanadaMarket(String? country) {
    if (country == null || country.trim().isEmpty) return false;

    final normalized = country.trim().toLowerCase();
    const ukUsCanadaCountries = <String>{
      'united kingdom',
      'uk',
      'england',
      'scotland',
      'wales',
      'northern ireland',
      'united states',
      'us',
      'usa',
      'america',
      'canada',
    };

    return ukUsCanadaCountries.contains(normalized);
  }

  static bool isAdvancedMarket(String? country) => isUkUsCanadaMarket(country);

  static bool isNonAfricanMarket(String? country) => !isAfricanMarket(country);
}
