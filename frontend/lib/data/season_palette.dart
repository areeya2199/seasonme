import 'package:flutter/material.dart';

class SwatchItem {
  final String name;
  final Color color;
  const SwatchItem(this.name, this.color);
}

enum SeasonKey { Winter, Spring, Autumn, Summer }

class TopGroup {
  final Color color;
  final List<SwatchItem> swatches;
  const TopGroup(this.color, this.swatches);
}

class SeasonCore {
  final String displayName;
  final String undertone;
  final String description;
  final bool warm;
  final List<TopGroup> topGroups;
  final List<TopGroup> hairGroups;
  final List<SwatchItem> eyeMakeup;
  final List<SwatchItem> blush;
  final List<SwatchItem> lipstick;
  final List<TopGroup> jewelryGroups;

  const SeasonCore({
    required this.displayName,
    required this.undertone,
    required this.description,
    required this.warm,
    required this.topGroups,
    required this.hairGroups,
    required this.eyeMakeup,
    required this.blush,
    required this.lipstick,
    required this.jewelryGroups,
  });
}

class SeasonModes {
  final SeasonCore day;
  final SeasonCore night;
  const SeasonModes({required this.day, required this.night});
}

class SeasonProfile {
  final SeasonCore core;
  SeasonProfile(this.core);

  String get displayName => core.displayName;
  String get undertone => core.undertone;
  String get description => core.description;

  List<TopGroup> get topGroups => core.topGroups;
  List<SwatchItem> get topsPool => [
    for (final g in core.topGroups) ...g.swatches,
  ];
  List<SwatchItem> bottomsOf(int groupIndex) =>
      core.topGroups[groupIndex].swatches;
  List<SwatchItem> get bottoms => topsPool;

  List<TopGroup> get hairGroups => core.hairGroups;
  List<TopGroup> get jewelryGroups => core.jewelryGroups;

  /// รวมทุกกลุ่ม (เผื่อไฟล์อื่นยังเรียกใช้แบบเดิม)
  List<SwatchItem> get hair => [for (final g in core.hairGroups) ...g.swatches];
  List<SwatchItem> get jewelry => [
    for (final g in core.jewelryGroups) ...g.swatches,
  ];

  List<SwatchItem> get eyeMakeup => core.eyeMakeup;
  List<SwatchItem> get blush => core.blush;
  List<SwatchItem> get lipstick => core.lipstick;
}

class SeasonPaletteData {
  SeasonPaletteData._();

  /// รองรับทั้ง "ชื่อ,HEX" และ "HEX" ล้วน
  static List<SwatchItem> _parse(String raw) =>
      raw.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).map((e) {
        final i = e.lastIndexOf(',');
        final hex = e.substring(i + 1).trim().replaceAll('#', '');
        final name = i == -1
            ? '#${hex.toUpperCase()}'
            : e.substring(0, i).trim();
        return SwatchItem(name, Color(int.parse('FF$hex', radix: 16)));
      }).toList();

  /// hex = สีของจุดกลมที่ใช้เลือกกลุ่ม, raw = รายการสีในกลุ่ม (HEX คั่นด้วย ;)
  static TopGroup _group(String hex, String raw) =>
      TopGroup(Color(int.parse('FF$hex', radix: 16)), _parse(raw));

  /// 1 บรรทัด = 1 กลุ่ม, สีจุดกลม = สีแรกของบรรทัดนั้น
  static List<TopGroup> _groupsFromLines(List<String> lines) => [
    for (final line in lines)
      if (_parse(line).isNotEmpty)
        TopGroup(_parse(line).first.color, _parse(line)),
  ];

  static SeasonCore _core({
    required String name,
    required String undertone,
    required String description,
    required bool warm,
    required List<TopGroup> tops,
    required List<String> hair,
    required String eye,
    required String blush,
    required String lipstick,
    required List<String> jewelry,
  }) => SeasonCore(
    displayName: name,
    undertone: undertone,
    description: description,
    warm: warm,
    topGroups: tops,
    hairGroups: _groupsFromLines(hair),
    eyeMakeup: _parse(eye),
    blush: _parse(blush),
    lipstick: _parse(lipstick),
    jewelryGroups: _groupsFromLines(jewelry),
  );

  static final Map<SeasonKey, SeasonModes> database = {
    SeasonKey.Winter: SeasonModes(
      day: _core(
        //True Winter
        name: 'Winter',
        undertone: 'Cool undertone',
        description:
            'A cool, clear, and high-contrast season — bold jewel tones with striking clarity.',
        warm: false,
        tops: [
          _group(
            'C53364',
            'C53364;FADAE9;BF9C92;FF7164;9B615F;3A0000;9B0239;FE0190',
          ),
          _group(
            '92CBC1',
            '92CBC1;FFFE6D;FDFF06;99FF00;B4FFDE;30999A;046760;6A6A6A',
          ),
          _group(
            '4AABFF',
            '4AABFF;B9E0F7;9C9BF9;3C37FE;303089;00025A;979497;000000',
          ),
          _group(
            'C131BF',
            'C131BF;F29BF1;946B96;6B016B;6D0037;C093F0;CACAFE;38006A',
          ),
        ],
        hair: [
          'Platinum,E5E4E2;Icy Blonde,FFFEF0;Ash Blonde,C9C0A8;Silver Blonde,D3D3D3;Champagne,F7E7CE;Cool Beige,D4C5B9',
          'Blue-black,1B1B3A; Jet Black,0A0A0A; Cool Espresso,3C2414; Ash Brown,7A6A53;Cool Chocolate,3E2723;Mocha,5C4033',
          'True Burgundy,800020;Wine Red,722F37;Cherry,9B1B30;Mahogany,4E1609;Plum,673147;Cool Auburn,A0522D',
        ],
        eye:
            'Silver,C0C0C0; Slate grey,708090; Deep violet,4B0082; Cool navy,000080;'
            'Silver-white,E8E8E8; Light Silver,D4D4D4; Steel Gray,C8C8C8; Icy Blue,B0C4DE',
        blush:
            'Cool pink,E75480; Cool rose,DB7093; Cool deep pink,C71585; Plum-pink,DDA0DD',
        lipstick:
            'Cool raspberry,C0392B; Cool plum,8E44AD; Blue-based red,CB4335; Cool berry,943126',
        jewelry: [
          'Cool Charcoal,3A3D45;Ice Grey,D7DBE2;True Black,101014;Pure White,FFFFFF',
          'True Red,C8102E;Fuchsia,D6187F;Ultramarine,2B4CC0;Magenta,BE0E6F;Cool Crimson,AF0F2E;Royal Blue,2242A8',
        ],
      ),
      night: _core(
        //BrightWinter
        name: 'Winter',
        undertone: 'Cool undertone',
        description:
            'A cool, vivid, and electric season — sharp, saturated colors with icy brilliance.',
        warm: false,
        tops: [
          _group(
            'F93822',
            'F93822;F8F7F2;EEDC00;00A74A;00965E;006845;8BD3E6;00A9CE',
          ),
          _group(
            '00A7B5',
            '00A7B5;00B097;007D8A;00313C;C6D6E3;00A3E1;0047BB;003594',
          ),
          _group(
            '002F6C',
            '002F6C;041E42;101820;06038D;001A70;201547;4E008E;87189D',
          ),
          _group(
            'F5B6CD',
            'F5B6CD;F59BBB;D62598;FF008A;E0004D;CE0F69;FF8DA1;F55D7E',
          ),
          _group('F8485E', 'F8485E;EE2737'),
        ],
        hair: [
          'Platinum Blonde,E5E4E2;Icy Blonde,FFFEF0;Ash Blonde,C9C0A8;Silver Blonde,D4D4D4;Cool Champagne,F7E7CE;Pearl Blonde,EAE6CA',
          'Jet Black,0A0A0A;Blue-Black,1B1B3A;Espresso,3C2414;Cool Chocolate,3E2723;Ash Brown,7A6A53;Cool Mocha,5C4033',
          'Vivid Burgundy,800020;Cool Cherry,9B1B30;Wine Red,722F37;Magenta,A8287F;Cool Auburn,A52A2A;Plum,673147',
        ],
        eye:
            'Vivid violet,7029E9; Electric cobalt,0047AB; Clear silver,B9B9BD; Deep fuchsia shimmer,791F55; '
            'Icy silver,D2D2D4; Clear pink-silver,DA8EAF; Bright white shimmer,EAE3D2;',
        blush:
            'Vivid cool pink,FF4F99; Bright fuchsia,E11F92; Clear magenta,DF1395; Bright berry,BE1444 ',
        lipstick:
            'Vivid fuchsia,E31B92; True cherry red,EF205C; Electric berry,CC0F44; Clear hot pink,FF61B0',
        jewelry: [
          'Cool Charcoal,3A3D45;Ice Grey,D7DBE2;Silver Stone,B9BFCB;Pure White,FFFFFF;True Black,101014',
          'Violet Volt,8332E8;Electric Blue,1F51FF;Scarlet,E00420;Lime Ice,CCF23A;Cobalt Bright,1D4ED8;Shocking Pink,F5238F',
        ],
      ),
    ),

    SeasonKey.Spring: SeasonModes(
      day: _core(
        name: 'Spring', //light Spring
        undertone: 'Warm undertone',
        description:
            'A warm, light, and delicate season — soft pastels with a gentle golden glow.',
        warm: true,
        tops: [
          _group(
            'FE6730',
            'FE6730;FD9695;FE6C6F;FE0000;CB0306;F99A38;913200;693902',
          ),
          _group(
            'D7FF04',
            'D7FF04;FFCB7A;FED034;FFFE99;FAFE38;03FF00;2A9130;379B67',
          ),
          _group(
            '3499E1',
            '3499E1;31FBD3;3AFDFF;3DC9D9;086168;3499E1;3A6EF3;3C00D8',
          ),
          _group(
            '983399',
            '983399;FECACD;FE749E;FC3194;FF70FF;D034FF;983399;5F01A1',
          ),
        ],
        hair: [
          'Honey Blonde,DDB06A;Golden Blonde,E8C872;Caramel Blonde,D4A757;Butter Blonde,F5DEB3;Strawberry Blonde,E4977C;Champagne,F7E7CE',
          'Golden Brown,A67B5B;Light Caramel,FFD59A;Warm Beige,C9A98E;Light Toffee,C8A882;Sandy Brown,D4B896;Honey Brown,B8906B',
          'Light Copper,DA8A67;Peachy Rose,FFAD84;Soft Auburn,C17E5D;Light Ginger,E09E6F;Rose Gold,E0BFB8;Apricot,FBCEB1',
        ],
        eye:
            'Light gold shimmer,EEDA6A; Warm taupe matte,8B8589; Soft champagne,CEC4AB;Light warm brown,D68C57',
        blush:
            'Warm peach,F3A772; Light coral,E9A28D;Soft apricot,D1AC86; Warm pink,EB7799',
        lipstick:
            'Soft coral,F88379; Warm peach nude,F3A772; Light warm rose,CDA9A9; Clear warm pink,FC5E8C',
        jewelry: [
          'Camel Cream,D9B98D;Golden Sand,E4CFA4;Light Taupe,C9B49C;Dove Greige,CFC4B4;Warm Ivory,FBF0DC',
          'Baby Marigold,FBC65F;Fresh Leaf,9CCB76;Coral Pink,F99787;Melon Sorbet,FFA588;Buttercream,F7DC8E;Apricot Cream,FFC498',
        ],
      ),
      night: _core(
        name: 'Spring', //BrightSpring
        undertone: 'Warm undertone',
        description:
            'A warm, vivid, and radiant season — bold, saturated hues that pop with warmth.',
        warm: true,
        tops: [
          _group(
            'F18070',
            'F18070;DDCBA4;F0B27D;E1B744;F68D2E;BD9B60;F0B323;5C3D31',
          ),
          _group(
            'F9F6E7',
            'F9F6E7;DCC681;F3D03E;A1D884;77C02C;2B7E3C;CBE2D2;3AAC74',
          ),
          _group(
            '00A74A',
            '00A74A;205C40;6DCDB8;319C8A;00B7BD;007FA3;115E67;006F62',
          ),
          _group(
            '71C5E8',
            '71C5E8;418FDE;3A5DAE;0857C3;13294B;2C2E65;B580D1;FB84A3',
          ),
          _group('E24585', 'E24585;D5419E;F65275;E73C3E'),
        ],
        hair: [
          'Vibrant Golden,FFD700;Honey Blonde,DDB06A;Butter Blonde,F5DEB3;Champagne,F7E7CE;Sun Blonde,E8C872;Caramel Blonde,D4A757',
          'Golden Brown,A67B5B;Warm Chocolate,7B3F00;Chestnut,954535;Toffee,755139;Caramel,C68642;Bronze Brown,8B4513',
          'Vibrant Copper,B87333;Light Copper,DA8A67;Clear Auburn,A52A2A;Strawberry Blonde,E4977C;Ginger,B06500;Copper Penny,CB6D51',
        ],
        eye:
            'Warm copper,BB7330; Rich bronze,895A22; Peach-gold shimmer,DDA558; Bright warm amber,FFBF02; '
            'Warm gold,D4AF37; Peach-champagne,E5B98B; Warm bronze glow,AB7330',
        blush:
            'Clear warm peach,FFA15E; Vivid coral,FF6233; Warm apricot,EBA45A; Bright warm pink,FF5384 ',
        lipstick:
            'Vivid coral,FF6233; Clear warm red,DE000E; Bright warm pink,FF5384; Warm peach-nude,E5B089 ',
        jewelry: [
          'Light Camel,D8B384;Golden Beige,E7CFA4;Warm Grey,B7AC9E;Clear Charcoal,3E4148;Warm White,FBF4E4',
          'Violet Spark,7C4DFF;Poppy Orange,F4581F;Clear Red,E3242B;Sun Yellow,FFD02F;Lime Zest,B5D334;Hot Coral,FF5A4E',
        ],
      ),
    ),

    SeasonKey.Autumn: SeasonModes(
      day: _core(
        name: 'Autumn', // True Autumn or warm Autumn
        undertone: 'Warm undertone',
        description:
            'A warm, rich, and deep season — full-bodied earth tones bursting with warmth.',
        warm: true,
        tops: [
          _group(
            '9D0064',
            '9D0064;FC6D5B;FA3905;CF3831;390000;CE356B;8F309F;2E036F',
          ),
          _group(
            'FD9C35',
            'FD9C35;F7A06A;FF692D;FC6936;D43904;D6804B;933905;996C00',
          ),
          _group(
            '9D9835',
            '9D9835;FFCD6E;CE9734;FDCA29;FFFD6A;D8D26B;C6D137;6C6A37',
          ),
          _group(
            '37746C',
            '37746C;A6EA5F;9FC89E;3A96A4;4D4B00;2D9C9C;076D73;006292',
          ),
        ],
        hair: [
          'Honey Blonde,DDB06A;Golden Blonde,E8C872;Caramel Blonde,D4A757;Butter Blonde,F5DEB3;Strawberry Blonde,E4977C;Champagne,F7E7CE',
          'Golden Brown,A67B5B;Chestnut,954535;Caramel,FFD59A;Toffee,755139;Warm Chocolate,7B3F00;Cinnamon,D2691E',
          'Light Copper,DA8A67;True Copper,B87333;Auburn,A52A2A;Ginger,B06500;Strawberry,E4977C;Bronze,CD7F32',
        ],
        eye:
            'Warm gold,B8860B; warm amber-brown,8B6914; cognac,7B4F2E; olive-brown,556B2F; '
            'Golden Yellow,D4AF37; antique gold,C9A96E; Warm Gold,DAA520; Golden Bronze,B8860B',
        blush:
            'Warm peach-coral,E8956D; warm apricot-bronze,D4774A; Caramel Brown,C97B4B; warm terracotta,E2855A ',
        lipstick:
            'Warm terracotta,C47722; cognac,A0522D; warm brick,B8450A; burnt sienna,9B4F2E ',
        jewelry: [
          'Camel,C89F68;Olive,66622F;Warm Khaki,A79362;Espresso,43301F;Cream Caramel,EFDDBC',
          'Tomato Bisque,BF3E1D;Turmeric,C98A16;Pumpkin Spice,C46A1B;Mustard Gold,D19A2A;Marmalade,D97836;Paprika,AD3B21',
        ],
      ),
      night: _core(
        name: 'Autumn', //DarkAutumn
        undertone: 'Warm undertone',
        description:
            'A warm, deep, and bold season — rich chocolate and spice tones with intensity.',
        warm: true,
        tops: [
          _group(
            '4E312D',
            '4E312D;800020;A83C09;808000;228B22;014D4E;E1AD01;CC5500',
          ),
          _group(
            'C04000',
            'C04000;6F4E37;3B0910;FFFDD0;008080;3B7A58;800000;006400',
          ),
          _group(
            '483C32',
            '483C32;B33923;CD7F32;E2725B;B87333;722F37;234E52;11574A',
          ),
          _group(
            '8E4585',
            '8E4585;016795;367588;355E3B;D26911;614051;4B5320;FF7518',
          ),
          _group(
            '704214',
            '704214;C19A6B;0A5F38;712F2C;638B27;9E003A;A0522D;AF6F09',
          ),
          _group(
            'B5A642',
            'B5A642;8B553C;006A4E;875F42;773F1A;954535;826644;996515',
          ),
          _group(
            '2D1B0E',
            '2D1B0E;556B2F;4A0000;65000B;01796F;005F6A;964F4C;B59E5F',
          ),
          _group('CFB53B', 'CFB53B;8B4513;B8860B'),
        ],
        hair: [
          'Dark Auburn,6B2C2C;Espresso Brown,3C2414;Warm Black,1C1614;Dark Chocolate,3E2723;Mahogany,4E1609;Deep Walnut,5D432C',
          'Dark Auburn,7A2E19;Bronze,8B4513;Copper Mahogany,6F3428;Burnt Sienna,8B3626;Russet,80461B;Deep Copper,7C3030',
          'Deep Caramel,A67B5B;Bronze Gold,996515;Warm Honey,C17817;Toffee,755139;Amber,B8860B;Golden Brown,8B6914',
        ],
        eye:
            'Warm gold,B8860B; cognac brown,E0A15E; dark copper,B98A52; deep forest-brown,A2521E; '
            'Golden Yellow,D4AF37; antique gold,C9A96E; Golden Bronze,B8860B; Warm Gold,DAA520',
        blush:
            'Warm peach-bronze,CD853F; warm copper,C77441; warm terra,A0522D; golden-warm,DEB887 ',
        lipstick:
            'Deep burgundy,722F37; warm terracotta,B7410E; cognac brown,8B4513; warm brick,C17F24 ',
        jewelry: [
          'Camel Deep,B08A55;Olive,66622F;Cream Caramel,EFDDBC;Black Coffee,2A1F17;Dark Chocolate,3E2A1A',
          'Dark Mustard,A8791C;Rust Deep,9B441D;Burnt Copper,9C4A1E;Brick,8E3B22;Garnet,7C2432;Bronze,8C6A2B',
        ],
      ),
    ),

    SeasonKey.Summer: SeasonModes(
      day: _core(
        name: 'Summer', //lightSummer
        undertone: 'Cool undertone',
        description:
            'A cool, light, and airy season — soft pastel hues with a gentle silvery touch.',
        warm: false,
        tops: [
          _group(
            'FED0D2',
            'FED0D2;FFE7F7;FE756E;A06B6D;D0A29C;C9C8C4;FFFFCD;FDFE9F',
          ),
          _group(
            '73FFFC',
            '73FFFC;C1F798;D2FDD0;D3FEFC;33D6C5;A1CFCF;38A29D;38A29D',
          ),
          _group(
            '369EFD',
            '369EFD;39CAF6;369DC8;369DC8;9FA3FD;6F68FF;3836FF;393B98',
          ),
          _group(
            'FAA0FF',
            'FAA0FF;FED7EE;FEA9D9;FED2FF;AA0DAA;CDA2FC;C4C4FF;9C2DFC',
          ),
        ],
        hair: [
          'Light Ash Blonde,E5DCC5;Champagne Blonde,F7E7CE;Platinum Ash,E5E4E2;Sandy Ash,C8B896;Soft Beige Blonde,F5F5DC;Cool Vanilla,F3E5AB',
          'Soft Cool Brown,A89080;Mushroom Brown,B5A695;Light Ash Brown,9E8B7E;Rose Brown,B08B82;Taupe Brown,8B7D6B;Cool Beige,C9B99B',
          'Rose Gold,E0BFB8;Dusty Rose,C9A5A5;Soft Mauve,D4AFCD;Cool Pink Brown,B39388;Ash Rose,C3989E;Muted Berry,A67881',
        ],
        eye:
            'Cool taupe,8B8589; Soft grey-lavender,ABA7B5; Pale cool pink shimmer,E2B2C6; Muted slate,6C747F; '
            'Cool pink shimmer,E979A8; Soft pearl,DAD4C8; Icy lavender sheen,E6E6FA; Pale silver glow,D0D0D1',
        blush:
            'Soft cool rose,C68998; Pale pink,FFD1DC; Delicate mauve,B07A9A ',
        lipstick:
            'Soft cool pink,D595B0; Dusty rose,B8818E; Mauve-pink,CC7AA1; Cool berry tint,9D294A ',
        jewelry: [
          'Pale Slate,AEB6C2;Dove Grey,D7DBE2;Soft White,F6F4F0;Cool Sand,DDD3C6;Cocoa Mist,B9A8A0',
          'Cool Lemon,F2E6A2;Watery Rose,DE8FA8;Wisteria,A99BD1;Heather,B790B8;Rose Quartz,E8A9BD;Spearmint,8FCDB4',
        ],
      ),
      night: _core(
        name: 'Summer', //TrueSummer
        undertone: 'Cool undertone',
        description:
            'A cool, muted, and elegant season — soft dusty tones with quiet sophistication.',
        warm: false,
        tops: [
          _group(
            'B0E0E6',
            'B0E0E6;5170D7;5A6B82;516572;90A4AE;C8A2C8;8E4585;B3436C',
          ),
          _group(
            'FFC0CB',
            'FFC0CB;DE5D83;2E8B57;5E8D8D;808080;ADD8E6;C0C0C0;E6E6FA',
          ),
          _group(
            'D3D3D3',
            'D3D3D3;3EB489;87CEEB;722F37;36454F;91A092;4E518B;BA797D',
          ),
          _group(
            '77A1B5',
            '77A1B5;8E82FE;86A17D;87E0CF;D2DAE2;367588;6A5ACD;F1EFEA',
          ),
          _group(
            '614051',
            '614051;F7CEE0;727B89;D58A94;4682B4;739BD0;9966CC;FDB0C0',
          ),
          _group(
            'DA70D6',
            'DA70D6;BFC8C3;A9C6C2;6C3461;C9A0DC;C54B8C;849BCC;9EA1A5',
          ),
          _group(
            'DB96C0',
            'DB96C0;354E8C;5F9EA0;6D9292;BDBBD7;9A8AA5;C9D6CE;D8BFD8',
          ),
          _group('EBCED5', 'EBCED5;BC8E8F'),
        ],
        hair: [
          'Ash Blonde,C9C0A8;Champagne,F7E7CE;Cool Beige,E8DCC0;Sandy Ash,C8B896;Mushroom Blonde,B5A695;Soft Platinum,E5E4DD',
          'Ash Brown,7A6A53;Mocha,5C4033;Cool Chocolate,3E2723;Mushroom Brown,8B7355;Taupe,8B8589;Rose Brown,8E6D5E',
          'Rose Brown,8E6D5E;Soft Burgundy,804D57;Dusty Rose,C5A3A0;Cool Auburn,8B4243;Mauve,91697C;Wine,722F37',
        ],
        eye:
            'Cool taupe,8B8589; Soft grey,9C9C9D; Muted lavender,B3ABC4; Dusty rose,B8818E ',
        blush:
            'Dusty rose,B8818E; Soft mauve,B195A6; Cool pink,E979A8; Muted raspberry,A15C70 ',
        lipstick:
            'Soft berry,AD5770;Muted mauve,A18997; Cool rose,D5637E; Dusty plum,7E5875 ',
        jewelry: [
          'Cool Grey,A9AEB6;Slate,D7DBE2;Soft White,F5F3EF;Rose Beige,CBB6AC;Cocoa Taupe,94807A',
          'Pewter,9A9B9C;Rhodium,D0D3D6;Cool Rose Gold,D9B0A8;Gunmetal,6B7076',
        ],
      ),
    ),
  };

  static final Map<String, SeasonProfile> _cache = {};

  static SeasonProfile getProfile(SeasonKey key, {bool night = false}) {
    final modes = database[key]!;
    return _cache.putIfAbsent(
      '${key.name}_$night',
      () => SeasonProfile(night ? modes.night : modes.day),
    );
  }

  static SeasonCore coreOf(SeasonKey key) => database[key]!.day;
  static String labelOf(SeasonKey key) => database[key]!.day.displayName;

  static const Color _springAccent = Color.fromARGB(255, 255, 227, 151);
  static const Color _summerAccent = Color.fromARGB(255, 167, 199, 255);
  static const Color _autumnAccent = Color.fromARGB(255, 235, 168, 114);
  static const Color _winterAccent = Color.fromARGB(255, 142, 155, 239);

  static Color groupColorOf(SeasonKey key) {
    switch (key) {
      case SeasonKey.Spring:
        return _springAccent;
      case SeasonKey.Summer:
        return _summerAccent;
      case SeasonKey.Autumn:
        return _autumnAccent;
      case SeasonKey.Winter:
        return _winterAccent;
    }
  }
}
