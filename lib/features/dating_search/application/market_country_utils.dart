class MarketCountryUtils {
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
