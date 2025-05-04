class PlaceTypeLocalization {
  static const Map<String, String> typeTranslations = {
    // Населенные пункты
    'city': 'Город',
    'town': 'Город',
    'village': 'Село',
    'hamlet': 'Деревня',
    'suburb': 'Район города',
    'neighbourhood': 'Микрорайон',
    'isolated_dwelling': 'Хутор',
    'farm': 'Ферма',
    
    // Административные единицы
    'administrative': 'Административная единица',
    'state': 'Регион',
    'region': 'Область',
    'county': 'Район',
    'municipality': 'Муниципалитет',
    'district': 'Район',
    'borough': 'Округ',
    'province': 'Провинция',
    'federal_district': 'Федеральный округ',
    'republic': 'Республика',
    'oblast': 'Область',
    'krai': 'Край',
    'autonomous_region': 'Автономная область',
    'autonomous_district': 'Автономный округ',
    
    // Административные уровни
    'admin_level_1': 'Страна',
    'admin_level_2': 'Федеральный округ',
    'admin_level_3': 'Регион',
    'admin_level_4': 'Район',
    'admin_level_5': 'Муниципальный округ',
    'admin_level_6': 'Город/Село',
    'admin_level_7': 'Район города',
    'admin_level_8': 'Микрорайон',
    'admin_level_9': 'Квартал',
    'admin_level_10': 'Участок',
    
    // Природные объекты
    'water': 'Водоем',
    'river': 'Река',
    'lake': 'Озеро',
    'sea': 'Море',
    'ocean': 'Океан',
    'forest': 'Лес',
    'peak': 'Гора',
    'valley': 'Долина',
    'island': 'Остров',
    'cape': 'Мыс',
    'beach': 'Пляж',
    'bay': 'Залив',
    'wetland': 'Болото',
    'glacier': 'Ледник',
    'volcano': 'Вулкан',
    
    // Дороги и пути
    'motorway': 'Автомагистраль',
    'trunk': 'Шоссе',
    'primary': 'Основная дорога',
    'secondary': 'Второстепенная дорога',
    'tertiary': 'Местная дорога',
    'residential_road': 'Жилая улица',
    'path': 'Тропа',
    'track': 'Грунтовая дорога',
    'service': 'Служебная дорога',
    'footway': 'Пешеходная дорожка',
    'steps': 'Лестница',
    'platform': 'Платформа',
    
    // Места и здания
    'house': 'Дом',
    'apartments': 'Многоквартирный дом',
    'hotel': 'Отель',
    'supermarket': 'Супермаркет',
    'convenience': 'Магазин',
    'school': 'Школа',
    'university': 'Университет',
    'hospital': 'Больница',
    'police': 'Полиция',
    'post_office': 'Почта',
    'bank': 'Банк',
    'restaurant': 'Ресторан',
    'cafe': 'Кафе',
    'bar': 'Бар',
    'pharmacy': 'Аптека',
    'cinema': 'Кинотеатр',
    'theatre': 'Театр',
    'library': 'Библиотека',
    'marketplace': 'Рынок',
    'fuel': 'АЗС',
    'parking': 'Парковка',
    
    // Общие типы
    'yes': 'Место',
    'building': 'Здание',
    'amenity': 'Инфраструктура',
    'shop': 'Магазин',
    'tourism': 'Туризм',
    'leisure': 'Отдых',
    'historic': 'Историческое место',
    'landuse': 'Землепользование',
    'natural': 'Природный объект',
    'railway': 'Железная дорога',
    'aeroway': 'Авиация',
    'military': 'Военный объект',
    'office': 'Офис',
    'industrial': 'Промышленный объект',
    'commercial': 'Коммерческий объект',
    'residential_area': 'Жилой район',
    'retail': 'Торговый объект',
    'cemetery': 'Кладбище',
    'religious': 'Религиозный объект',
    'place_of_worship': 'Религиозное учреждение',
    'monument': 'Памятник',
    'memorial': 'Мемориал',
    'archaeological_site': 'Археологический объект',
    'unknown': 'Неизвестный тип',
  };

  static String getLocalizedType(String type) {
    // Приводим к нижнему регистру для сравнения
    final lowerType = type.toLowerCase();
    
    // Обрабатываем особые случаи
    if (lowerType == 'residential') {
      // Проверяем контекст использования
      if (lowerType.contains('highway') || lowerType.contains('road')) {
        return 'Жилая улица';
      }
      return 'Жилой район';
    }

    // Проверяем административные уровни
    if (lowerType.contains('admin_level')) {
      final level = lowerType.split('=').last;
      final adminKey = 'admin_level_$level';
      return typeTranslations[adminKey] ?? 'Административная единица';
    }

    // Проверяем тип места
    if (lowerType.startsWith('place=')) {
      final placeType = lowerType.split('=').last;
      return typeTranslations[placeType] ?? placeType;
    }

    // Проверяем административные границы
    if (lowerType.startsWith('boundary=administrative')) {
      return 'Административная единица';
    }

    return typeTranslations[lowerType] ?? type;
  }
} 