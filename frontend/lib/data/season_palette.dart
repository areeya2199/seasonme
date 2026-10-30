import 'package:flutter/material.dart';

class SwatchItem {
  final String name;
  final Color color;
  const SwatchItem(this.name, this.color);
}

enum SeasonKey { Winter, Spring, Autumn, Summer }

class TopGroup {
  final String name;
  final Color color;
  final List<SwatchItem> swatches;
  const TopGroup(this.name, this.color, this.swatches);
}

class SeasonCore {
  final String displayName;
  final String undertone;
  final String description;
  final bool warm;
  final List<TopGroup> topGroups;
  final List<SwatchItem> hair;
  final List<SwatchItem> eyeMakeup;
  final List<SwatchItem> blush;
  final List<SwatchItem> lipstick;
  final List<SwatchItem> jewelry;

  const SeasonCore({
    required this.displayName,
    required this.undertone,
    required this.description,
    required this.warm,
    required this.topGroups,
    required this.hair,
    required this.eyeMakeup,
    required this.blush,
    required this.lipstick,
    required this.jewelry,
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
  List<SwatchItem> bottomsOf(int groupIndex) => core.topGroups[groupIndex].swatches;
  List<SwatchItem> get bottoms => topsPool;
  List<SwatchItem> get hair => core.hair;
  List<SwatchItem> get eyeMakeup => core.eyeMakeup;
  List<SwatchItem> get blush => core.blush;
  List<SwatchItem> get lipstick => core.lipstick;
  List<SwatchItem> get jewelry => core.jewelry;
}

class SeasonPaletteData {
  SeasonPaletteData._();

  static List<SwatchItem> _parse(String raw) => raw
      .split(';')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map((e) {
        final i = e.lastIndexOf(',');
        final hex = e.substring(i + 1).trim().replaceAll('#', '');
        return SwatchItem(
          e.substring(0, i).trim(),
          Color(int.parse('FF$hex', radix: 16)),
        );
      })
      .toList();

  static TopGroup _group(String name, String hex, String raw) =>
      TopGroup(name, Color(int.parse('FF$hex', radix: 16)), _parse(raw));

  static SeasonCore _core({
    required String name,
    required String undertone,
    required String description,
    required bool warm,
    required List<TopGroup> tops,
    required String hair,
    required String eye,
    required String blush,
    required String lipstick,
    required String jewelry,
  }) => SeasonCore(
    displayName: name,
    undertone: undertone,
    description: description,
    warm: warm,
    topGroups: tops,
    hair: _parse(hair),
    eyeMakeup: _parse(eye),
    blush: _parse(blush),
    lipstick: _parse(lipstick),
    jewelry: _parse(jewelry),
  );

  static final Map<SeasonKey, SeasonModes> database = {
    SeasonKey.Winter: SeasonModes(
      day: _core(
        name: 'Winter',
        undertone: 'Cool undertone',
        description:
            'A cool, clear, and high-contrast season — bold jewel tones with striking clarity.',
        warm: false,
        tops: [
          _group(
            '1',
            'C53364',
            '1,C53364; 2,FADAE9; 3,BF9C92; 4,FF7164; 5,9B615F; 6,3A0000; 7,9B0239; 8,FE0190',
          ),
          _group(
            '2',
            '92CBC1',
            '1,92CBC1; 2,FFE6D; 3,FDFF06; 4,99FF00; 5,B4FFDE; 6,30999A; 7,046760; 8,6A6A6A',
          ),
          _group(
            '3',
            '4AABFF',
            '1,4AABFF; 2,B9E0F7; 3,9C9BF9; 4,3C37FE; 5,303089; 6,00025A; 7,979497; 8,000000',
          ),
          _group(
            '4',
            'C131BF',
            '1,C131BF; 2,F29BF1; 3,946B96; 4,6B016B; 5,6D0037; 6,C093F0; 7,CACAFE; 8,38006A',
          ),
        ],
        hair:
            'Silver,C7CDD2; Ash Blonde,B8AFA0; Ash Brown,6E5C52; Taupe Brown,5C4C46; '
            'Cool Medium Brown,4A3A34; Dark Ash Brown,3A2E2A; Brown Black,2A211C; Blue Black,14171F',
        eye:
            'Ivory,F3E8CF; Apricot,EDD1B4; Beach,B49964; Brown,895D3F; '
            'Dark Khaki,645E4E; Aubergine,56354E; Royal Blue,485985; Teal Blue,115C77',
        blush:
            'Light Magenta,E0619E; Pale Magenta,E68CB4; Pale Mulberry,C084A0; Pale Raisin,A5748A; '
            'Cool Pink,E081A8; Rose Pink,D65C8C; Deep Rose,B84070; Berry Pink,CC5286',
        lipstick:
            'Bubblegum Pink,E85DA0; Deep Mauve,8E5270; Dark Orchid,7A3C94; Ruby Red,C4213E; '
            'Raspberry,C23A62; Boysenberry,8A2E5C; Cranberry,A61E42; Magenta Rose,C82C7C',
        jewelry:
            'Silver,C9CDD1; Platinum,D8D5CE; White Gold,E2DED4; Steel Grey,767B80; '
            'Diamond White,ECEDEF; Chrome,D4D6D8; Pewter,9A9B9C; Sterling Silver,C3C5C8',
      ),
      night: _core(
        name: 'Winter',
        undertone: 'Cool undertone',
        description:
            'A cool, vivid, and electric season — sharp, saturated colors with icy brilliance.',
        warm: false,
        tops: [
          _group(
            'Bright',
            'E51E3E',
            'Lemon Yellow,FFE36A; Butter Yellow,F9EA8A; Lime Green,7FD13F; Yellow Green,A9C943; '
                'Coral Pink,E97A84; Cherry Red,E53C4B; True Red,E51E3E; Bright Pink,E02E7C',
          ),
          _group(
            'Pink',
            'E02C7C',
            'Raspberry,D22D73; Berry,A33159; Rose Pink,DD7AAE; Hot Pink,E02C7C; '
                'Fuchsia,DF287F; Cerise,D12B87; Magenta,CA2E87; Mulberry,AA367E',
          ),
          _group(
            'Purple',
            '833A91',
            'Purple,863C91; Lavender Purple,9759A6; Royal Purple,833A91; Muted Purple,76589C; '
                'Indigo Purple,564A95; Dusty Purple,786AAE; Blue Violet,50479C; Indigo,4A4C98',
          ),
          _group(
            'Blue',
            '1D88C2',
            'Soft Aqua,69B7BF; Turquoise,1797A0; Sky Blue,40A9D5; Azure,1D88C2; '
                'Ocean Blue,197393; Powder Blue,82A9D3; Royal Blue,3E69A9; True Blue,1B5FA5',
          ),
        ],
        hair:
            'Neutral Brown,4A3830; Medium Cool Brown,5C463C; Bitter Chocolate,2E1D16; Dark Golden Brown,4A3020; '
            'Cool Black Brown,2A211C; Espresso,2A1D16; Ebony,1A1512; Blue-Black,10131F',
        eye:
            'Lemon,F4F2D9; Icy Purple,E8E6FB; Icy Blue,C9D6DF; Icy Green,D2E1CC; '
            'Umber,5C4636; Dark Grey,47494E; Mulberry,7A2F5C; Dark Plum,4A1F52',
        blush:
            'Coral,F0715C; Light Berry Red,E24862; Pale Raspberry,E4708E; Hibiscus,EE4F8A; '
            'Pale Boysenberry,C0568C; Mulberry,9C3A6E; Fuchsia Pink,EC3E9C; Cool Raspberry,D63A6E',
        lipstick:
            'Fuchsia,E01890; Vivid Lilac,DC65D9; Purple,B52BB4; Magenta,D4147A; '
            'Cherry Red,C41E38; Raspberry,C23A62; Bright Raspberry Pink,E2447E; Cool Cherry Red,D4162E',
        jewelry:
            'Silver,C9CDD1; Platinum,DAD7CE; White Gold,E2DED4; Chrome,D4D6D8; '
            'Pale Gold,E8D7A0; Rhodium,CFD3D6; Diamond White,ECEDEF; Gunmetal,6B7076',
      ),
    ),

    SeasonKey.Spring: SeasonModes(
      day: _core(
        name: 'Spring',
        undertone: 'Warm undertone',
        description:
            'A warm, light, and delicate season — soft pastels with a gentle golden glow.',
        warm: true,
        tops: [
          _group(
            '1',
            'FE6730',
            '1,FE6730; 2,FD9695; 3,FE6C6F; 4,FE0000; 5,CB0306; 6,F99A38; 7,913200; 8,693902',
          ),
          _group(
            '2',
            'D7FF04',
            '1,D7FF04; 2,FFCB7A; 3,FED034; 4,FFFE99; 5,FAFE38; 6,03FF00; 7,2A9130; 8,379B67',
          ),
          _group(
            '3',
            '3499E1',
            '1,3499E1; 2,31FBD3; 3,3AFDFF; 4,3DC9D9; 5,086168; 6,3499E1; 7,3A6EF3; 8,3C00D8',
          ),
          _group(
            '4',
            '983399',
            '1,983399; 2,FECACD; 3,FE749E; 4,FC3194; 5,FF70FF; 6,D034FF; 7,983399; 8,5F01A1',
          ),
        ],
        hair:
            'Light Blonde,E0C08C; Sunflower Blonde,E8B865; Beeline Honey,C89355; Medium Champagne,D2AE7C; '
            'Golden Brown,A9713C; Reddish Blonde,D69A5E; Copper Shimmer,C97A42; Strawberry Blonde,D98F5F',
        eye:
            'Soft Pink,F2D9D9; Apricot,FFEED4; Champagne,FFF8DC; Light Gold,EBE6E0; '
            'Cocoa,93786D; Honey Brown,C39A6C; Moss,BDC9B1; Soft Gray,D8CECF',
        blush:
            'Cream Blush,F2C9BC; Peach Quartz,F2B79A; Strawberry Cream,F0A79C; Blossom,F0AFBB; '
            'Peach Blossom,F2B9A6; Sun-Kissed Coral,EE9B7C; Tickled Pink,F0A9B8; Morning Glory,E893A0',
        lipstick:
            'Living Coral,FF7062; Candlelight Peach,F7A29D; Peach Blossom,EA8686; Sun-kissed Coral,EA6578; '
            'Tickled Pink,F9B7C1; Morning Glory,EC819D; Strawberry Pink,F77E8D; Camellia Rose,E86181',
        jewelry:
            'Light Gold,E4C98A; Champagne Gold,DCC08F; White Gold,E6DCC6; Warm Rose Gold,E3AE8F; '
            'Yellow Gold,D9B45C; Pale Gold,EBD9A8; Peach Gold,E8BE9A; Soft Brass,CDB070',
      ),
      night: _core(
        name: 'Spring',
        undertone: 'Warm undertone',
        description:
            'A warm, vivid, and radiant season — bold, saturated hues that pop with warmth.',
        warm: true,
        tops: [
          _group(
            'Neutral',
            'C8BDA7',
            'Ivory,F7F3E8; Vanilla Cream,F4EEDB; Warm Cream,EFE5C8; Light Sand,D9D1BE; '
                'Warm Beige,C8BDA7; Sage Gray,A5A79A; Warm Taupe,89887B; Olive Gray,6F746B',
          ),
          _group(
            'Yellow & Orange',
            'F8B84B',
            'Butter Yellow,FFE078; Sunshine Yellow,FFD45B; Golden Yellow,FFC94F; Marigold,F8B84B; '
                'Apricot,F6A45B; Tangerine,EF8B47; Persimmon,E76E45; Vermilion,D6533E',
          ),
          _group(
            'Red & Coral',
            'EE695F',
            'Peach Pink,F5A096; Salmon,F4877E; Warm Coral,F1786E; Living Coral,EE695F; '
                'Poppy Red,E95655; Tomato Red,E34843; Strawberry Red,DB3F51; Bright Scarlet,D32E46',
          ),
          _group(
            'Green',
            '48AA61',
            'Mint Green,75BE83; Spring Green,59B574; Apple Green,48AA61; Kelly Green,329B58; '
                'Emerald Green,238C54; Jade Green,258B70; Tropical Green,197D69; Teal Green,17716A',
          ),
        ],
        hair:
            'Golden Blonde,E4B04E; Sunflower Blonde,EAC24E; Honey Blonde,D89A44; Light Copper Red,C85A2C; '
            'Medium Copper Red,B84A22; Light Golden Brown,9C6A2E; Medium Golden Brown,7E4E22; Amber Brown,6E4018',
        eye:
            'Ivory,F2E9D2; Pale Peach,E5D9C3; Pale Pink,F7DAD3; Cocoa,8F7B70; '
            'Pale Magenta,D26292; Grape,52437C; Turquoise,377E82; Lime Green,A1BB70',
        blush:
            'Soft Coral,F2896A; Light Berry Red,E24862; Pale Raspberry,E4708E; Hibiscus,EE4F8A; '
            'Bright Coral,F4664E; Fuchsia Pink,EC3E9C; Cool Raspberry,D63A6E; Vivid Berry,C2245E',
        lipstick:
            'Orange,E85A20; Tomato Red,E23A24; Cherry Red,D01C34; Bright Coral,F1523A; '
            'Pomegranate Red,C01230; Fuchsia,E01890; Cherry,C41E38; Watermelon Red,E43050',
        jewelry:
            'Buttery Yellow Gold,E8C24E; Rose Gold Peach,E3A084; Silver,C9CDD1; Bright Turquoise,1CB4B4; '
            'Sapphire Yellow,E8D24E; Bright Gold,F0CC5A; Coral Gold,E8A878; Polished Brass,D4AE3E',
      ),
    ),

    SeasonKey.Autumn: SeasonModes(
      day: _core(
        name: 'Autumn',
        undertone: 'Warm undertone',
        description:
            'A warm, rich, and deep season — full-bodied earth tones bursting with warmth.',
        warm: true,
        tops: [
          _group(
            '1',
            '9D0064',
            '1,9D0064; 2,FC6D5B; 3,FA3905; 4,CF3831; 5,390000; 6,CE356B; 7,8F309F; 8,2E036F',
          ),
          _group(
            '2',
            'FD9C35',
            '1,FD9C35; 2,F7A06A; 3,FF692D; 4,FC6936; 5,D43904; 6,D6804B; 7,933905; 8,996C00',
          ),
          _group(
            '3',
            '9D9835',
            '1,9D9835; 2,FFCD6E; 3,CE9734; 4,FDCA29; 5,FFFD6A; 6,D8D26B; 7,C6D137; 8,6C6A37',
          ),
          _group(
            '4',
            '37746C',
            '1,37746C; 2,A6EA5F; 3,9FC89E; 4,3A96A4; 5,4D4B00; 6,2D9C9C; 7,076D73; 8,006292',
          ),
        ],
        hair:
            'Caramel Blonde,A6702A; Copper Red,B4501E; Russet Red,9E4420; Auburn Red,8A3418; '
            'Cinnamon Red,7E3016; Caramel Brown,7A4E24; Light Golden Brown,8F6030; Honey Brown,74491E',
        eye:
            'Warm Ivory,EEE0BE; Apricot,E0A15E; Gold,C99A3E; Khaki,A79256; '
            'Olive,6E6A2E; Moss,5C6E2E; Teal,146070; Dark Teal,0E4A52',
        blush:
            'Peach,E8A574; Apricot,E0955C; Coral,DE7A56; Terracotta,C4633C; '
            'Warm Rose,C46A6C; Brick,A2432E; Cinnamon,9E5A32; Amber,C4791E',
        lipstick:
            'Rust,A2441E; Terracotta,C4633C; Brick Red,92322A; Warm Nude,C4855F; '
            'Cinnamon,7E3016; Copper,A2521E; Burnt Orange,B24E1E; Deep Coral,C4543A',
        jewelry:
            'Copper,B4611E; Dark Brass,8A6A2A; Gold,C99A3E; Bronze,8A5A20; '
            'Amber Gold,C4922C; Antique Gold,B08A3A; Rose Copper,B87450; Brushed Brass,A88A48',
      ),
      night: _core(
        name: 'Autumn',
        undertone: 'Warm undertone',
        description:
            'A warm, deep, and bold season — rich chocolate and spice tones with intensity.',
        warm: true,
        tops: [
          _group(
            'Neutral',
            '9F6A43',
            'Antique Ivory,E4D2BA; Camel,CDAA79; Golden Brown,B88857; Saddle Brown,9F6A43; '
                'Walnut,835337; Chestnut,69402C; Dark Chocolate,4E3023; Espresso,342019',
          ),
          _group(
            'Gold',
            'C39431',
            'Golden Honey,E3BF62; Harvest Gold,D4A948; Mustard,C39431; Bronze,B18028; '
                'Burnished Gold,9D6D24; Antique Brass,8A5D22; Old Gold,77501F; Olive Gold,64451C',
          ),
          _group(
            'Rust',
            'A95A2F',
            'Pumpkin,C97F49; Copper,B86937; Burnt Orange,A95A2F; Rust,964C2C; '
                'Cinnamon,84412B; Terracotta,733828; Mahogany,612F24; Burnt Copper,51271F',
          ),
          _group(
            'Green',
            '758355',
            'Sage,A3AE83; Moss,8C996A; Olive,758355; Olive Drab,627046; '
                'Fern Green,53603B; Forest Green,455232; Pine Green,384429; Spruce Green,2D3722',
          ),
        ],
        hair:
            'Dark Honey Blonde,A9702C; Dark Caramel Blonde,97622A; Dark Copper Red,8A3A1E; French Roast,4A2E1C; '
            'Auburn Red,7A2E1A; Mahogany Red,6E2418; Medium Chocolate,3E2818; Dark Chocolate,2E1C12',
        eye:
            'Ivory,EDE2C6; Apricot,E0A15E; Camel,B98A52; Copper,A2521E; '
            'Bronze,8A5A20; Mahogany,6E2418; Deep Amber,B4681A; Olive,6E6A2E',
        blush:
            'Pale Salmon,E4977A; Pale Vermilion,DE6A44; Berry Red,A62E3A; Cardinal Red,942028; '
            'Pale Magenta,C4587C; Mulberry,8A3358; Terracotta,C05A34; Warm Rose,C4626C',
        lipstick:
            'Pale Vermilion,DE6A44; Berry Red,A62E3A; Mulberry,8A3358; Pecan Brown,6E4226; '
            'Dark Wine,5A1A28; Rust,A24422; Cognac,7A3E1C; Burnt Orange,B24E1E',
        jewelry:
            'Oxidized Copper,8A5030; Gold,C99A3E; Bronze,8A5A20; Matte Silver,8F9092; '
            'Antique Brass,7E602A; Dark Gold,A67C2E; Burnished Copper,9A5A32; Pewter,7A7B7C',
      ),
    ),

    SeasonKey.Summer: SeasonModes(
      day: _core(
        name: 'Summer',
        undertone: 'Cool undertone',
        description:
            'A cool, light, and airy season — soft pastel hues with a gentle silvery touch.',
        warm: false,
        tops: [
          _group(
            '1',
            'FED0D2',
            '1,FED0D2; 2,FFE7F7; 3,FE756E; 4,A06B6D; 5,D0A29C; 6,C9C8C4; 7,FFFFCD; 8,FDFE9F',
          ),
          _group(
            '2',
            '73FFFC',
            '1,73FFFC; 2,C1F798; 3,D2FDD0; 4,D3FEFC; 5,33D6C5; 6,A1CFCF; 7,38A29D; 8,38A29D',
          ),
          _group(
            '3',
            '369EFD',
            '1,369EFD; 2,39CAF6; 3,369DC8; 4,369DC8; 5,9FA3FD; 6,6F68FF; 7,3836FF; 8,393B98',
          ),
          _group(
            '4',
            'FAA0FF',
            '1,FAA0FF; 2,FED7EE; 3,FEA9D9; 4,FED2FF; 5,AA0DAA; 6,CDA2FC; 7,C4C4FF; 8,9C2DFC',
          ),
        ],
        hair:
            'Icy Blonde,E3D8C2; Nordic Blonde,D9C9A6; Light Ash Blonde,CDBB94; Dark Ash Blonde,B4A17A; '
            'Light Neutral Brown,A48F70; Light Cool Brown,96805E; Light Ash Brown,83714F; Medium Neutral Brown,6E5B41',
        eye:
            'Rice,F0EFEE; Cream,EDE6D2; Dusty Peach,E4C1AA; Soft Grey,C6C6C4; '
            'Cocoa,8E7361; Slate Blue,7C93AA; Lilac,C6B4D6; Powder Blue,B9D3E0',
        blush:
            'Light Pink,F0C6CC; Rose,D98C9C; Watermelon,E4808F; Mauve,B98C97; '
            'Punch,E36E86; Soft Coral,E8A490; Dusty Rose,D4A7A9; Cool Pink,E499AC',
        lipstick:
            'Ultra Pink,E874A0; Rose Glow,D9748C; Soft Rose,D48A98; Cool Mauve,A9707E; '
            'Petal Pink,E7A8B8; Dusty Rose,C48A92; Raspberry,C23A62; Ballerina Pink,E7B4C2',
        jewelry:
            'Silver,CBCDD0; White Gold,E2DED4; Rose Gold,E0B8AC; Platinum,D9D6CE; '
            'Pearl White,EDE9E1; Pale Silver,DADCDF; Champagne Silver,D8D3C8; Light Pewter,B0B2B5',
      ),
      night: _core(
        name: 'Summer',
        undertone: 'Cool undertone',
        description:
            'A cool, muted, and elegant season — soft dusty tones with quiet sophistication.',
        warm: false,
        tops: [
          _group(
            'Neutral',
            '9FA8B0',
            'Soft White,F7F7F5; Pearl,EEEDE7; Silver,E0E1DF; Light Gray,D0D0D2; '
                'Cool Gray,B9BEC2; Slate Gray,9FA8B0; Steel Gray,85919C; Blue Gray,6E7D8B',
          ),
          _group(
            'Pink',
            'D48DAD',
            'Blush Pink,E8B8C8; Ballet Pink,DFA6BF; Rose Pink,D48DAD; Dusty Rose,C8789A; '
                'Berry Pink,BD658A; Raspberry Rose,AF577E; Cranberry,A04973; Rosewood,8D3F63',
          ),
          _group(
            'Purple',
            '8581BF',
            'Lilac,C7C2E3; Lavender,B1ABD8; Wisteria,9C95CC; Periwinkle,8581BF; '
                'Iris,706CB0; Violet,625A9F; Plum,554D8D; Aubergine,474179',
          ),
          _group(
            'Blue',
            '6F9DCE',
            'Ice Blue,D4E7F6; Powder Blue,BCD9F2; Sky Blue,A5C9EB; Cornflower Blue,89B5E1; '
                'Denim Blue,6F9DCE; Steel Blue,5B88B8; Slate Blue,4B739F; Cadet Blue,3E617F',
          ),
        ],
        hair:
            'Ash Blonde,B9AC90; Dark Ash Blonde,A0906E; Medium Ash Brown,7C6B52; Dark Ash Brown,5E4E3C; '
            'Taupe Brown,6E5C4A; Cool Brunette,4A3C2E; Silver,C3C4C6; Pewter,9A9B9C',
        eye:
            'Porcelain,E6E2E3; Hazel Wood,CFC6C1; Ash Brown,816C71; Mauve,A9707E; '
            'Dusty Rose,C48A92; Teal,1E6E70; Slate Blue,5C7690; Aubergine,652B65',
        blush:
            'Sea Pink,DE93A0; Chateau Rose,C97488; Bubblegum,E48CAC; Carmine,A02040; '
            'Anemone,C060A0; Pink-a-boo,E4A0B8; Mauve Rose,B4788C; Berry,9C3A5E',
        lipstick:
            'Rose Petal,C97488; Mauve Rose,B4788C; Berry Wine,8A2E48; Carmine Red,A02040; '
            'Plum,6E4462; Raspberry,B23A5E; Dusty Mauve,A9707E; Cool Pink,DE93A0',
        jewelry:
            'Silver,CBCDD0; Sterling Silver,C3C5C8; Platinum,D9D6CE; White Gold,E2DED4; '
            'Pewter,9A9B9C; Rhodium,D0D3D6; Cool Rose Gold,D9B0A8; Gunmetal,6B7076',
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