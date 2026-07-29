import 'package:flutter/material.dart';

//name
class SwatchItem {
  final String name;
  final Color color;
  const SwatchItem(this.name, this.color);
}

/// The 12 Personal Color seasons.
enum SeasonKey { Winter, Spring, Autumn, Summer }

class SeasonCore {
  final SeasonKey key;
  final String displayName;
  final String undertone;
  final String description;
  final bool warm;
  final List<double> hueAnchors;
  final double satMin, satMax;
  final double lightMin, lightMax;
  final List<String> flavors;

  final List<SwatchItem>? curatedHair;
  final List<SwatchItem>? curatedEyeMakeup;
  final List<SwatchItem>? curatedBlush;
  final List<SwatchItem>? curatedLipstick;
  final List<SwatchItem>? curatedJewelry;

  const SeasonCore({
    required this.key,
    required this.displayName,
    required this.undertone,
    required this.description,
    required this.warm,
    required this.hueAnchors,
    required this.satMin,
    required this.satMax,
    required this.lightMin,
    required this.lightMax,
    required this.flavors,
    this.curatedHair,
    this.curatedEyeMakeup,
    this.curatedBlush,
    this.curatedLipstick,
    this.curatedJewelry,
  });
}

/// [ResultScreen] or [ClothingScreen] needs to display or compare against.
class SeasonProfile {
  final SeasonCore core;
  final List<SwatchItem> yourColorPalette; //10
  final List<SwatchItem> hair; // 10
  final List<SwatchItem> eyeMakeup; // 10
  final List<SwatchItem> blush; // 10
  final List<SwatchItem> lipstick; // 10
  final List<SwatchItem> jewelry; // 5

  SeasonProfile({
    required this.core,
    required this.yourColorPalette,
    required this.hair,
    required this.eyeMakeup,
    required this.blush,
    required this.lipstick,
    required this.jewelry,
  });

  String get displayName => core.displayName;
  String get undertone => core.undertone;
  String get description => core.description;
}

class SeasonPaletteData {
  SeasonPaletteData._();

  static const List<String> _defaultMods = [
    '',
    'Soft ',
    'Deep ',
    'Warm ',
    'Muted ',
    'Rich ',
    'Pale ',
    'Dusty ',
    'Vivid ',
    'Cool ',
  ];

  static const SeasonCore _darkWinter = SeasonCore(
    key: SeasonKey.Winter,
    displayName: 'Winter',
    undertone: 'Cool undertone',
    description:
        'A cool, deep, and dramatic season striking dark hues with icy undertones.',
    warm: false,
    hueAnchors: [220, 270, 350, 150, 10],
    satMin: 0.45,
    satMax: 0.72,
    lightMin: 0.16,
    lightMax: 0.34,
    flavors: [
      'Midnight',
      'Onyx',
      'Rumba',
      'Claret',
      'Mulberry',
      'Blackberry',
      'Navy',
      'Elm',
      'Forest',
      'Charcoal',
    ],
    curatedHair: [
      SwatchItem('Pure Black', Color(0xFF0B0B0D)),
      SwatchItem('Ebony', Color(0xFF1A1512)),
      SwatchItem('Blue-Black', Color(0xFF10131F)),
      SwatchItem('Plum Black', Color(0xFF1E1420)),
      SwatchItem('Bitter Chocolate', Color(0xFF2E1D16)),
      SwatchItem('Cool Espresso', Color(0xFF3A2A22)),
      SwatchItem('Cool Dark Brown', Color(0xFF3F2E28)),
      SwatchItem('Medium Cool Brown', Color(0xFF5A4238)),
      SwatchItem('Darkest Mahogany', Color(0xFF4A2420)),
      SwatchItem('Deep Ash Brown', Color(0xFF4A3D38)),
    ],
    curatedEyeMakeup: [
      SwatchItem('Chiffon', Color(0xFFF3ECD9)),
      SwatchItem('Ice White', Color(0xFFF1F3F5)),
      SwatchItem('Metallic Silver', Color(0xFFB8BCC2)),
      SwatchItem('Slate Grey', Color(0xFF6E7580)),
      SwatchItem('Charcoal', Color(0xFF35383D)),
      SwatchItem('Soft Umber', Color(0xFF6B5344)),
      SwatchItem('Chocolate Brown', Color(0xFF4A3226)),
      SwatchItem('Deep Brown-Black', Color(0xFF241813)),
      SwatchItem('Navy', Color(0xFF16244A)),
      SwatchItem('Cobalt', Color(0xFF1B4FA0)),
      SwatchItem('Electric Blue', Color(0xFF1670D6)),
      SwatchItem('Deep Teal', Color(0xFF0E5A5C)),
      SwatchItem('Emerald', Color(0xFF157A55)),
      SwatchItem('Plum', Color(0xFF5B2A55)),
      SwatchItem('Burgundy', Color(0xFF6E1E32)),
    ],
    curatedBlush: [
      SwatchItem('Raspberry', Color(0xFFC23A62)),
      SwatchItem('Dark Punch', Color(0xFFA32E4A)),
      SwatchItem('Pale Berry Red', Color(0xFFC96070)),
      SwatchItem('Magenta', Color(0xFFB21E6E)),
      SwatchItem('Pale Mulberry', Color(0xFFB57D93)),
      SwatchItem('Pale Raisin', Color(0xFF8C6478)),
      SwatchItem('Soft Berry', Color(0xFFB9647C)),
      SwatchItem('Cool Mauve', Color(0xFFA97388)),
      SwatchItem('Cold Fuchsia', Color(0xFFC93E93)),
      SwatchItem('Soft Raspberry', Color(0xFFC46B80)),
    ],
    curatedLipstick: [
      SwatchItem('Berry Deep', Color(0xFF6E1E3C)),
      SwatchItem('Wine Cool', Color(0xFF6B1F2C)),
      SwatchItem('Cherry', Color(0xFFB0203A)),
      SwatchItem('Raspberry', Color(0xFFC23A62)),
      SwatchItem('Magenta Cool', Color(0xFFB21E6E)),
      SwatchItem('Cool Neon Fuchsia', Color(0xFFD4258C)),
      SwatchItem('Plum Wine', Color(0xFF5B2440)),
      SwatchItem('Dark Mulberry', Color(0xFF7A3355)),
      SwatchItem('Violet', Color(0xFF5C3A8E)),
      SwatchItem('Cool Mauve', Color(0xFF8E5C72)),
    ],
    curatedJewelry: [
      SwatchItem('Silver', Color(0xFFC7C9CC)),
      SwatchItem('Platinum', Color(0xFFDAD7CE)),
      SwatchItem('White Gold', Color(0xFFE4E0D6)),
      SwatchItem('Gunmetal', Color(0xFF4A4E55)),
      SwatchItem('Pewter', Color(0xFF8B8D8F)),
    ],
  );

  //Spring

  static const SeasonCore _lightSpring = SeasonCore(
    key: SeasonKey.Spring,
    displayName: 'Spring',
    undertone: 'Warm undertone',
    description:
        'A warm, light, and delicate season soft pastels with a gentle golden glow.',
    warm: true,
    hueAnchors: [30, 45, 15, 90],
    satMin: 0.35,
    satMax: 0.55,
    lightMin: 0.65,
    lightMax: 0.80,
    flavors: [
      'Peach',
      'Buttercream',
      'Blush',
      'Mint',
      'Coral',
      'Vanilla',
      'Apricot',
      'Petal',
    ],
    curatedHair: [
      SwatchItem('Pure Diamond', Color(0xFFE9DEC8)),
      SwatchItem('Light Blonde', Color(0xFFE0C08C)),
      SwatchItem('Sunflower Blonde', Color(0xFFE8B865)),
      SwatchItem('Beeline Honey', Color(0xFFC89355)),
      SwatchItem('Medium Champagne', Color(0xFFD2AE7C)),
      SwatchItem('Golden Brown', Color(0xFFA9713C)),
      SwatchItem('Reddish Blonde', Color(0xFFD69A5E)),
      SwatchItem('Copper Shimmer', Color(0xFFC97A42)),
      SwatchItem('Strawberry Blonde', Color(0xFFD98F5F)),
      SwatchItem('Honey Blonde', Color(0xFFD1A159)),
    ],
    curatedEyeMakeup: [
      SwatchItem('Soft Pink', Color(0xFFF2D9D9)),
      SwatchItem('Apricot', Color(0xFFF2C29B)),
      SwatchItem('Champagne', Color(0xFFEADCC0)),
      SwatchItem('Light Gold', Color(0xFFE8D19A)),
      SwatchItem('Cocoa', Color(0xFF8A5F44)),
      SwatchItem('Honey Brown', Color(0xFFA9713C)),
      SwatchItem('Moss', Color(0xFF97A76E)),
      SwatchItem('Soft Gray', Color(0xFFC7C6C0)),
      SwatchItem('Soft Blue', Color(0xFFB7D3DE)),
      SwatchItem('Pale Aqua', Color(0xFFC6E6DE)),
      SwatchItem('Teal', Color(0xFF4E8C8A)),
      SwatchItem('Violet', Color(0xFFB49BD1)),
      SwatchItem('Coffee Liner', Color(0xFF5A3A28)),
      SwatchItem('Moss Liner', Color(0xFF6E7C4B)),
      SwatchItem('Teal Liner', Color(0xFF2E6E6C)),
    ],
    curatedBlush: [
      SwatchItem('Cream Blush', Color(0xFFF2C9BC)),
      SwatchItem('Peach Quartz', Color(0xFFF2B79A)),
      SwatchItem('Strawberry Cream', Color(0xFFF0A79C)),
      SwatchItem('Blossom', Color(0xFFF0AFBB)),
      SwatchItem('Candlelight Peach', Color(0xFFF4C79A)),
      SwatchItem('Peach Blossom', Color(0xFFF2B9A6)),
      SwatchItem('Sun-Kissed Coral', Color(0xFFEE9B7C)),
      SwatchItem('Tickled Pink', Color(0xFFF0A9B8)),
      SwatchItem('Morning Glory', Color(0xFFE893A0)),
      SwatchItem('Camellia Rose', Color(0xFFE88EA0)),
    ],
    curatedLipstick: [
      SwatchItem('Clear Red', Color(0xFFE4453F)),
      SwatchItem('Coral', Color(0xFFF0765A)),
      SwatchItem('Warm Pink', Color(0xFFE97C93)),
      SwatchItem('Salmon', Color(0xFFF09075)),
      SwatchItem('Peach', Color(0xFFF0A57C)),
      SwatchItem('Living Coral', Color(0xFFF16F5C)),
      SwatchItem('Sun-Kissed Coral', Color(0xFFEE9B7C)),
      SwatchItem('Tickled Pink', Color(0xFFF0A9B8)),
      SwatchItem('Morning Glory', Color(0xFFE893A0)),
      SwatchItem('Strawberry Pink', Color(0xFFE97F8E)),
    ],
    curatedJewelry: [
      SwatchItem('Light Gold', Color(0xFFE4C98A)),
      SwatchItem('Champagne Gold', Color(0xFFDCC08F)),
      SwatchItem('White Gold', Color(0xFFE6DCC6)),
      SwatchItem('Warm Rose Gold', Color(0xFFE3AE8F)),
      SwatchItem('Yellow Gold', Color(0xFFD9B45C)),
    ],
  );

  // Autumn

  static const SeasonCore _softAutumn = SeasonCore(
    key: SeasonKey.Autumn,
    displayName: 'Autumn',
    undertone: 'Warm undertone',
    description:
        "A warm, and earthy season golden undertones meeting nature's understated hues.",
    warm: true,
    hueAnchors: [30, 40, 150, 10],
    satMin: 0.25,
    satMax: 0.45,
    lightMin: 0.45,
    lightMax: 0.60,
    flavors: [
      'Camel',
      'Sage',
      'Fawn',
      'Moss',
      'Dune',
      'Clay',
      'Stone',
      'Olive',
    ],
    curatedHair: [
      SwatchItem('Butterscotch Blonde', Color(0xFFC99A5E)),
      SwatchItem('Soft Golden Blonde', Color(0xFFD2AC72)),
      SwatchItem('Strawberry Blonde', Color(0xFFC48A5E)),
      SwatchItem('Honey Blonde', Color(0xFFB4874E)),
      SwatchItem('Faded Copper', Color(0xFFA66A44)),
      SwatchItem('Light Auburn', Color(0xFF9E5A3A)),
      SwatchItem('Light Golden Brown', Color(0xFF8F6E44)),
      SwatchItem('Medium Toasted Brown', Color(0xFF785A3A)),
      SwatchItem('Dark Warm Brown', Color(0xFF5C4530)),
      SwatchItem('Caramel Brown', Color(0xFF8A5E36)),
    ],
    curatedEyeMakeup: [
      SwatchItem('Ivory', Color(0xFFEDE4CE)),
      SwatchItem('Soft Apricot', Color(0xFFDDB088)),
      SwatchItem('Camel', Color(0xFFB99A6E)),
      SwatchItem('Khaki', Color(0xFFA99B70)),
      SwatchItem('Olive', Color(0xFF7C7B52)),
      SwatchItem('Sage', Color(0xFF8B9878)),
      SwatchItem('Moss', Color(0xFF7A8258)),
      SwatchItem('Sea Green', Color(0xFF6E9884)),
      SwatchItem('Dusty Teal', Color(0xFF5C8280)),
      SwatchItem('Dusty Blue', Color(0xFF7C93A0)),
      SwatchItem('Soft Brown', Color(0xFF6E5640)),
      SwatchItem('Taupe', Color(0xFF7C6E5E)),
      SwatchItem('Mauve', Color(0xFF9C7B7A)),
      SwatchItem('Terracotta', Color(0xFFB4714E)),
      SwatchItem('Brick', Color(0xFF935640)),
    ],
    curatedBlush: [
      SwatchItem('Soft Pink', Color(0xFFDDA79C)),
      SwatchItem('Terracotta', Color(0xFFB4714E)),
      SwatchItem('Pale Peach', Color(0xFFE0B790)),
      SwatchItem('Salmon', Color(0xFFD08A6E)),
      SwatchItem('Soft Rose', Color(0xFFC48A82)),
      SwatchItem('Rusty Pink', Color(0xFFC0755E)),
      SwatchItem('Dusty Coral', Color(0xFFC57B62)),
      SwatchItem('Warm Mauve', Color(0xFFA97D74)),
      SwatchItem('Apricot', Color(0xFFD69C6E)),
      SwatchItem('Soft Brick', Color(0xFFA25A44)),
    ],
    curatedLipstick: [
      SwatchItem('Soft Pink', Color(0xFFC98A82)),
      SwatchItem('Terracotta', Color(0xFFB4714E)),
      SwatchItem('Pale Brick Red', Color(0xFFA25A44)),
      SwatchItem('Brick Red', Color(0xFF8A4232)),
      SwatchItem('Soft Peach', Color(0xFFD8A47E)),
      SwatchItem('Russet', Color(0xFF8A5230)),
      SwatchItem('Cinnamon', Color(0xFF7A4A2A)),
      SwatchItem('Warm Mauve', Color(0xFF9C6E68)),
      SwatchItem('Dusty Rose', Color(0xFFB47A72)),
      SwatchItem('Clay', Color(0xFFA4694A)),
    ],
    curatedJewelry: [
      SwatchItem('Brushed Warm Gold', Color(0xFFC4A05E)),
      SwatchItem('Brushed Silver', Color(0xFFA6A49A)),
      SwatchItem('Rose Gold', Color(0xFFC99884)),
      SwatchItem('Soft Bronze Gold', Color(0xFFB4924E)),
      SwatchItem('Antique Gold', Color(0xFFAC8B4E)),
    ],
  );

  // Summer
  static const SeasonCore _softSummer = SeasonCore(
    key: SeasonKey.Summer,
    displayName: 'Soft Summer',
    undertone: 'Cool undertone',
    description:
        'A cool, blended, and gentle season muted neutrals with understated charm.',
    warm: false,
    hueAnchors: [210, 280, 340, 160],
    satMin: 0.20,
    satMax: 0.40,
    lightMin: 0.50,
    lightMax: 0.65,
    flavors: [
      'Dusty Rose',
      'Mauve',
      'Slate',
      'Lavender',
      'Fog',
      'Heather',
      'Pewter',
      'Mist',
    ],
    curatedHair: [
      SwatchItem('Light Ash Blonde', Color(0xFFC9BC9E)),
      SwatchItem('Medium Ash Blonde', Color(0xFFB4A484)),
      SwatchItem('Dark Ash Blonde', Color(0xFF9A8968)),
      SwatchItem('Dirty Beige Blonde', Color(0xFFA6926E)),
      SwatchItem('Violet Ash Blonde', Color(0xFFB0A090)),
      SwatchItem('Light Ash Brown', Color(0xFF8A7A5E)),
      SwatchItem('Medium Ash Brown', Color(0xFF6E5E46)),
      SwatchItem('Dark Ash Brown', Color(0xFF4E4232)),
      SwatchItem('Mushroom Brown', Color(0xFF83725A)),
      SwatchItem('Ashy Cedar Brown', Color(0xFF5C4E3E)),
    ],
    curatedEyeMakeup: [
      SwatchItem('Off-White', Color(0xFFEDE7DA)),
      SwatchItem('Pale Hazelnut', Color(0xFFC9B79C)),
      SwatchItem('Dark Khaki', Color(0xFF8C8262)),
      SwatchItem('Taupe', Color(0xFF8C7C6A)),
      SwatchItem('Chocolate Brown', Color(0xFF4A3A2A)),
      SwatchItem('Dark Grey', Color(0xFF504F4C)),
      SwatchItem('Aubergine', Color(0xFF503A50)),
      SwatchItem('Pale Indigo', Color(0xFF7C7CA0)),
      SwatchItem('Soft Mauve', Color(0xFFA9707E)),
      SwatchItem('Dusty Rose', Color(0xFFC48A92)),
      SwatchItem('Sage', Color(0xFF8A9878)),
      SwatchItem('Dusty Teal', Color(0xFF5C8280)),
      SwatchItem('Lavender', Color(0xFFB4A0C4)),
      SwatchItem('Cocoa', Color(0xFF6E5644)),
      SwatchItem('Mushroom', Color(0xFF83725A)),
    ],
    curatedBlush: [
      SwatchItem('Pink Moonstruck', Color(0xFFDDA0AC)),
      SwatchItem('Soft Pink', Color(0xFFDDA79C)),
      SwatchItem('Raspberry', Color(0xFFB23A5E)),
      SwatchItem('Pale Rosewood', Color(0xFFC4838A)),
      SwatchItem('Dark Plum', Color(0xFF6E3A54)),
      SwatchItem('Soft Mulberry', Color(0xFF8A4E66)),
      SwatchItem('Dusty Rose', Color(0xFFC48A92)),
      SwatchItem('Mauve Pink', Color(0xFFB4788C)),
      SwatchItem('Berry', Color(0xFF9C3A5E)),
      SwatchItem('Cool Coral', Color(0xFFD48078)),
    ],
    curatedLipstick: [
      SwatchItem('Pink Pearl', Color(0xFFDDA9B4)),
      SwatchItem('Pink Mauve', Color(0xFFB4788C)),
      SwatchItem('Magenta', Color(0xFFA02C7A)),
      SwatchItem('Soft Mulberry', Color(0xFF8A4E66)),
      SwatchItem('Grape', Color(0xFF6E4479)),
      SwatchItem('Pink Berry', Color(0xFFB23A5E)),
      SwatchItem('Wine', Color(0xFF6E2438)),
      SwatchItem('Plum', Color(0xFF6E4462)),
      SwatchItem('Rosewood', Color(0xFFA5695E)),
      SwatchItem('Cranberry', Color(0xFF8A2038)),
    ],
    curatedJewelry: [
      SwatchItem('Silver', Color(0xFFC9CDD0)),
      SwatchItem('Platinum', Color(0xFFD9D6CE)),
      SwatchItem('White Gold', Color(0xFFE2DED4)),
      SwatchItem('Rose Gold', Color(0xFFDDB0A2)),
      SwatchItem('Pearl', Color(0xFFEDE9E1)),
    ],
  );

  static final Map<SeasonKey, SeasonCore> _cores = {
    SeasonKey.Winter: _darkWinter,
    SeasonKey.Spring: _lightSpring,
    SeasonKey.Autumn: _softAutumn,
    SeasonKey.Summer: _softSummer,
  };

  static String _nameFor(List<String> flavors, List<String> mods, int i) {
    final flavor = flavors[i % flavors.length];
    final mod = mods[(i ~/ flavors.length) % mods.length];
    return (mod + flavor).trim();
  }

  static List<SwatchItem> _generate({
    required List<double> hueAnchors,
    required double satMin,
    required double satMax,
    required double lightMin,
    required double lightMax,
    required List<String> flavors,
    required int count,
    List<String>? mods,
  }) {
    final modifiers = mods ?? _defaultMods;
    final result = <SwatchItem>[];
    for (int i = 0; i < count; i++) {
      final anchor = hueAnchors[i % hueAnchors.length];
      final jitter = ((i ~/ hueAnchors.length) % 5 - 2) * 4.0;
      double hue = (anchor + jitter) % 360;
      if (hue < 0) hue += 360;

      final tSat = (i * 0.61803398875) % 1.0;
      final tLight = (i * 0.38196601125) % 1.0;
      final sat = (satMin + (satMax - satMin) * tSat).clamp(0.0, 1.0);
      final light = (lightMin + (lightMax - lightMin) * tLight).clamp(0.0, 1.0);

      final color = HSLColor.fromAHSL(1, hue, sat, light).toColor();
      result.add(SwatchItem(_nameFor(flavors, modifiers, i), color));
    }
    return result;
  }

  static SeasonProfile _build(SeasonCore core) {
    final palette = _generate(
      hueAnchors: core.hueAnchors,
      satMin: core.satMin,
      satMax: core.satMax,
      lightMin: core.lightMin,
      lightMax: core.lightMax,
      flavors: core.flavors,
      count: 10,
    );

    final hair =
        core.curatedHair ??
        _generate(
          hueAnchors: core.warm ? [25, 35, 45] : [15, 25, 30],
          satMin: core.warm ? 0.30 : 0.10,
          satMax: core.warm ? 0.55 : 0.30,
          lightMin: core.warm ? 0.15 : 0.08,
          lightMax: core.warm ? 0.55 : 0.45,
          flavors: core.warm
              ? const [
                  'Chestnut',
                  'Caramel',
                  'Copper',
                  'Honey',
                  'Auburn',
                  'Cinnamon',
                  'Golden Brown',
                  'Toffee',
                ]
              : const [
                  'Ash Brown',
                  'Espresso',
                  'Cool Black',
                  'Taupe Brown',
                  'Smoky Brown',
                  'Charcoal',
                  'Ash Blonde',
                  'Cool Brunette',
                ],
          count: 10,
          mods: const ['', 'Soft ', 'Deep ', 'Light ', 'Rich '],
        );

    final eyeMakeup =
        core.curatedEyeMakeup ??
        _generate(
          hueAnchors: core.hueAnchors,
          satMin: (core.satMin - 0.30).clamp(0.05, 1.0),
          satMax: core.satMax,
          lightMin: 0.25,
          lightMax: 0.75,
          flavors: core.flavors,
          count: 10,
        );

    final blush =
        core.curatedBlush ??
        _generate(
          hueAnchors: core.warm ? [10, 20, 30] : [340, 350, 0],
          satMin: 0.35,
          satMax: 0.65,
          lightMin: 0.55,
          lightMax: 0.75,
          flavors: core.warm
              ? const [
                  'Coral',
                  'Apricot',
                  'Peach',
                  'Terracotta Blush',
                  'Warm Rose',
                  'Amber Glow',
                ]
              : const [
                  'Rosewood',
                  'Mauve Blush',
                  'Dusty Pink',
                  'Cool Rose',
                  'Berry Blush',
                  'Petal Pink',
                ],
          count: 10,
          mods: const ['', 'Soft ', 'Deep '],
        );

    final lipstick =
        core.curatedLipstick ??
        _generate(
          hueAnchors: core.warm ? [5, 15, 25] : [335, 345, 355],
          satMin: 0.45,
          satMax: 0.75,
          lightMin: 0.35,
          lightMax: 0.55,
          flavors: core.warm
              ? const [
                  'Brick',
                  'Terracotta',
                  'Warm Nude',
                  'Rust Red',
                  'Amber Rose',
                  'Cinnamon',
                ]
              : const [
                  'Berry',
                  'Cool Rose',
                  'Plum',
                  'Raspberry',
                  'Mauve Rose',
                  'Wine',
                ],
          count: 10,
          mods: const ['', 'Soft ', 'Deep '],
        );

    final jewelry =
        core.curatedJewelry ??
        _generate(
          hueAnchors: core.warm ? [35, 40, 45] : [210, 215, 220],
          satMin: core.warm ? 0.35 : 0.02,
          satMax: core.warm ? 0.60 : 0.10,
          lightMin: core.warm ? 0.45 : 0.25,
          lightMax: core.warm ? 0.70 : 0.85,
          flavors: core.warm
              ? const [
                  'Gold',
                  'Rose Gold',
                  'Bronze',
                  'Champagne Gold',
                  'Copper',
                ]
              : const [
                  'Silver',
                  'Platinum',
                  'White Gold',
                  'Pewter',
                  'Gunmetal',
                ],
          count: 5,
          mods: const [''],
        );

    return SeasonProfile(
      core: core,
      yourColorPalette: palette,
      hair: hair,
      eyeMakeup: eyeMakeup,
      blush: blush,
      lipstick: lipstick,
      jewelry: jewelry,
    );
  }

  static final Map<SeasonKey, SeasonProfile> _cache = {};

  static SeasonProfile getProfile(SeasonKey key) {
    return _cache.putIfAbsent(key, () => _build(_cores[key]!));
  }

  static SeasonCore coreOf(SeasonKey key) => _cores[key]!;

  static String labelOf(SeasonKey key) => _cores[key]!.displayName;
}
