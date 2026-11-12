import 'package:flutter/material.dart';
import 'season_palette.dart';

/// ประเภทโอกาส/สถานที่ที่ต้องการเลือกสี
enum Occasion { work, nature, celebration }

/// ชื่อ คำอธิบาย และไอคอนของแต่ละ Occasion
extension OccasionLabel on Occasion {
  String get label {
    switch (this) {
      case Occasion.work:
        return 'Work';
      case Occasion.nature:
        return 'Weekends & Nature';
      case Occasion.celebration:
        return 'Celebration';
    }
  }

  String get subtitle {
    switch (this) {
      case Occasion.work:
        return 'Colors for work';
      case Occasion.nature:
        return 'Colors for outdoor activities';
      case Occasion.celebration:
        return 'Colors for celebrations';
    }
  }

  IconData get icon {
    switch (this) {
      case Occasion.work:
        return Icons.work_outline;
      case Occasion.nature:
        return Icons.nature_outlined;
      case Occasion.celebration:
        return Icons.celebration_outlined;
    }
  }
}

/// เก็บชุดสี Tops/Bottoms ของแต่ละฤดู แยกตาม Occasion
/// (Tops และ Bottoms ใช้ชุดสีเดียวกัน, ไม่มีการคำนวณ/สุ่ม)
///
/// วิธีเพิ่มสี ใส่ HEX คั่นด้วย ;  (ไม่ต้องมี #)
///   Work: 'E8D5B7;8B5E3C;3A3740'
/// หรือจะใส่ชื่อสีด้วยก็ได้
///   Work: 'Soft Beige,E8D5B7;Warm Brown,8B5E3C'
class OccasionPaletteData {
  OccasionPaletteData._();

  static List<SwatchItem> _parse(String raw) {
    return raw.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).map((
      item,
    ) {
      final i = item.lastIndexOf(',');
      final name = i == -1 ? '' : item.substring(0, i).trim();
      final hex = (i == -1 ? item : item.substring(i + 1)).trim().replaceAll(
        '#',
        '',
      );

      final value = hex.length == 6 ? int.tryParse('FF$hex', radix: 16) : null;
      if (value == null) {
        throw FormatException(
          'HEX ไม่ถูกต้อง: "$item" ต้องมี 6 ตัว เช่น FFFFFF',
        );
      }

      return SwatchItem(
        name.isEmpty ? '#${hex.toUpperCase()}' : name,
        Color(value),
      );
    }).toList();
  }

  /// SeasonKey -> Occasion -> HEX
  static final Map<SeasonKey, Map<Occasion, String>> _colorHexDatabase = {
    SeasonKey.Winter: {
      //True winter
      Occasion.work:
          'e285ac;3a3740;151518;c8102e;d6dae2;16265c;f2f3f5;0f7c74;6a2fb3',
      Occasion.nature:
          '0f7c74;202b49;f2f3f5;c22b65;c9d2dc;2c4a9e;E9D9F0;4F2B66',
      Occasion.celebration:
          'C22B65;2C4A9E;0F7C74;B77FD6;F2F3F5;6C2D5B;16265C;2C4A9E',
    },
    SeasonKey.Spring: {
      //Light spring
      Occasion.work:
          '7FCEC5;FFF5E8;E6C7A9;F2836B;B3D6E0;F9B475;E97387;F6F5F3;F4B9A0;EADBBD',
      Occasion.nature:
          'FBD9D2;9AD8CF;F6DFA6;F29E9B;9AD8CF;F58B4A;F6F5F3;DAD3CF',
      Occasion.celebration: 'B3D6E0;F2A9BA;9ADFC4;F9B475;FFF5E8;7FCEC5',
    },
    SeasonKey.Autumn: {
      //True autumn
      Occasion.work:
          'B85C38;F5E6CC;C7BFB6;6B6E3B;F0C890;2E6660;8F5530;EBD6B5;D3A029',
      Occasion.nature:
          'EBD6B5;6B6E3B;C96F2E;654735;2E6660;F6E3C8;B89060;C69287;C29435;F5E6CC',
      Occasion.celebration: 'C69287;6B7B3A;B85C38;D9A94E;2E6660',
    },
    SeasonKey.Summer: {
      //Light summer
      Occasion.work: 'E8A9BD;F2F3F5;C6CBD2;F2F3F5;A995DC;93B8DE;8AC3B6;C9648B',
      Occasion.nature:
          'F0C0D2;F2F3F5;B5E3D0;B7B8C5;BBAEDD;8FC6D8;E7E2E4;E895A2',
      Occasion.celebration: 'C5A8DE;9CBED8;D989A9;B5E3D0;F2F3F5;8FA3DC',
    },
  };

  /// ดึงรายการสีของฤดูและ Occasion ที่เลือก (ใช้ทั้ง Tops และ Bottoms)
  static List<SwatchItem> getPalette(SeasonKey season, Occasion occasion) {
    final raw = _colorHexDatabase[season]?[occasion] ?? '';
    return List.unmodifiable(_parse(raw));
  }
}
