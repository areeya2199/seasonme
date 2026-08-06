import 'dart:math';

import 'package:flutter/material.dart';

class SwatchItem {
  final String name;
  final Color color;
  const SwatchItem(this.name, this.color);
}

enum SeasonKey { Winter, Spring, Autumn, Summer }

class SeasonCore {
  final String displayName;
  final String undertone;
  final String description;
  final bool warm;

  final List<SwatchItem> curatedHair;
  final List<SwatchItem> curatedBottoms;
  final List<SwatchItem> curatedEyeMakeup;
  final List<SwatchItem> curatedBlush;
  final List<SwatchItem> curatedLipstick;
  final List<SwatchItem> curatedJewelry;

  final List<SwatchItem> curatedTops;

  const SeasonCore({
    required this.displayName,
    required this.undertone,
    required this.description,
    required this.warm,
    required this.curatedHair,
    required this.curatedEyeMakeup,
    required this.curatedBlush,
    required this.curatedLipstick,
    required this.curatedJewelry,
    required this.curatedTops,
    required this.curatedBottoms,
  });
}

class SeasonProfile {
  final SeasonCore core;
  final List<SwatchItem> topsPool; // 63 — 7 groups of 9
  final List<SwatchItem> bottoms; // 9
  final List<SwatchItem> hair; // 9
  final List<SwatchItem> eyeMakeup; // 9
  final List<SwatchItem> blush; // 9
  final List<SwatchItem> lipstick; // 9
  final List<SwatchItem> jewelry; // 5

  SeasonProfile({
    required this.core,
    required this.topsPool,
    required this.bottoms,
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

  // WINTER
  static const SeasonCore trueWinter = SeasonCore(
    displayName: 'Winter',
    undertone: 'Cool undertone',
    description:
        'A cool, clear, and high-contrast season ,bold jewel tones with striking clarity.',
    warm: false,

    curatedBottoms: [
      SwatchItem('True Black', Color(0xFF0B0B0C)),
      SwatchItem('Charcoal Gray', Color(0xFF42464D)),
      SwatchItem('Cool Navy', Color(0xFF253852)),
      SwatchItem('Steel Gray', Color(0xFF68707B)),
      SwatchItem('Crisp Pure White', Color(0xFFF8F8F7)),
      SwatchItem('Deep Pine', Color(0xFF24453B)),
      SwatchItem('True Burgundy', Color(0xFF5B1F2C)),
      SwatchItem('Sapphire Blue', Color(0xFF235A9C)),
      SwatchItem('Deep Purple', Color(0xFF4A3768)),
    ],

    curatedHair: [
      SwatchItem('Silver', Color(0xFFC7CDD2)),
      SwatchItem('Ash Blonde', Color(0xFFB8AFA0)),
      SwatchItem('Ash Brown', Color(0xFF6E5C52)),
      SwatchItem('Taupe Brown', Color(0xFF5C4C46)),
      SwatchItem('Cool Medium Brown', Color(0xFF4A3A34)),
      SwatchItem('Dark Ash Brown', Color(0xFF3A2E2A)),
      SwatchItem('Brown Black', Color(0xFF2A211C)),
      SwatchItem('Blue Black', Color(0xFF14171F)),
      SwatchItem('Intense Black', Color(0xFF0A0A0C)),
    ],
    curatedEyeMakeup: [
      SwatchItem('Ivory', Color(0xfff3e8cf)),
      SwatchItem('Apricot', Color(0xffedd1b4)),
      SwatchItem('Beach', Color(0xffb49964)),
      SwatchItem('Brown', Color(0xff895d3f)),
      SwatchItem('Dark khaki', Color(0xff645e4e)),
      SwatchItem('Albergine', Color(0xff56354e)),
      SwatchItem('Royal blue', Color(0xff485985)),
      SwatchItem('Teal blue', Color(0xff115c77)),
      SwatchItem('Yellow moss', Color(0xff857e47)),
    ],
    curatedBlush: [
      SwatchItem('Light Magenta', Color(0xFFE0619E)),
      SwatchItem('Pale Magenta', Color(0xFFE68CB4)),
      SwatchItem('Pale Mulberry', Color(0xFFC084A0)),
      SwatchItem('Pale Raisin', Color(0xFFA5748A)),
      SwatchItem('Cool Pink', Color(0xFFE081A8)),
      SwatchItem('Rose Pink', Color(0xFFD65C8C)),
      SwatchItem('Deep Rose', Color(0xFFB84070)),
      SwatchItem('Berry Pink', Color(0xFFCC5286)),
      SwatchItem('Plum Blush', Color(0xFF9C5478)),
    ],
    curatedLipstick: [
      SwatchItem('Bubblegum Pink', Color(0xFFE85DA0)),
      SwatchItem('Deep Mauve', Color(0xFF8E5270)),
      SwatchItem('Dark Orchid', Color(0xFF7A3C94)),
      SwatchItem('Ruby Red', Color(0xFFC4213E)),
      SwatchItem('Raspberry', Color(0xFFC23A62)),
      SwatchItem('Boysenberry', Color(0xFF8A2E5C)),
      SwatchItem('Cranberry', Color(0xFFA61E42)),
      SwatchItem('Magenta Rose', Color(0xFFC82C7C)),
      SwatchItem('Cool Berry', Color(0xFF96305A)),
    ],
    curatedJewelry: [
      SwatchItem('Silver', Color(0xFFC9CDD1)),
      SwatchItem('Platinum', Color(0xFFD8D5CE)),
      SwatchItem('White Gold', Color(0xFFE2DED4)),
      SwatchItem('Steel Grey', Color(0xFF767B80)),
      SwatchItem('Diamond White', Color(0xFFECEDEF)),
    ],
    curatedTops: _trueWinterTops,
  );

  static const SeasonCore brightWinter = SeasonCore(
    displayName: 'Winter',
    undertone: 'Cool undertone',
    description:
        'A cool, vivid, and electric season ,sharp, saturated colors with icy brilliance.',
    warm: false,

    curatedBottoms: [
      SwatchItem('Jet Black', Color(0xFF0A0A0A)),
      SwatchItem('Crisp White', Color(0xFFFDFDFB)),
      SwatchItem('Midnight Navy', Color(0xFF1C2F5A)),
      SwatchItem('Charcoal Grey', Color(0xFF3F444B)),
      SwatchItem('Cobalt Blue', Color(0xFF0047AB)),
      SwatchItem('Emerald Green', Color(0xFF007A5A)),
      SwatchItem('Ruby Red', Color(0xFF9B1B30)),
      SwatchItem('Bright Fuchsia', Color(0xFFC61A73)),
      SwatchItem('Electric Turquoise', Color(0xFF00B8C8)),
    ],

    curatedHair: [
      SwatchItem('Neutral Brown', Color(0xFF4A3830)),
      SwatchItem('Medium Cool Brown', Color(0xFF5C463C)),
      SwatchItem('Bitter Chocolate', Color(0xFF2E1D16)),
      SwatchItem('Dark Golden Brown', Color(0xFF4A3020)),
      SwatchItem('Cool Black Brown', Color(0xFF2A211C)),
      SwatchItem('Espresso', Color(0xFF2A1D16)),
      SwatchItem('Ebony', Color(0xFF1A1512)),
      SwatchItem('Blue-Black', Color(0xFF10131F)),
      SwatchItem('Jet Black', Color(0xFF0C0C0E)),
    ],
    curatedEyeMakeup: [
      SwatchItem('Lemon', Color(0xfff4f2d9)),
      SwatchItem('Icy Purple', Color(0xffe8e6fb)),
      SwatchItem('Icy Blue', Color(0xffc9d6df)),
      SwatchItem('Icy Green', Color(0xffd2e1cc)),
      SwatchItem('Umber', Color(0xFF5C4636)),
      SwatchItem('Dark Grey', Color(0xFF47494E)),
      SwatchItem('Mulberry', Color(0xFF7A2F5C)),
      SwatchItem('Dark Plum', Color(0xFF4A1F52)),
      SwatchItem('Admiral Blue', Color(0xFF163C74)),
    ],
    curatedBlush: [
      SwatchItem('Coral', Color(0xFFF0715C)),
      SwatchItem('Light Berry Red', Color(0xFFE24862)),
      SwatchItem('Pale Raspberry', Color(0xFFE4708E)),
      SwatchItem('Hibiscus', Color(0xFFEE4F8A)),
      SwatchItem('Pale Boysenberry', Color(0xFFC0568C)),
      SwatchItem('Mulberry', Color(0xFF9C3A6E)),
      SwatchItem('Fuchsia Pink', Color(0xFFEC3E9C)),
      SwatchItem('Cool Raspberry', Color(0xFFD63A6E)),
      SwatchItem('Vivid Berry', Color(0xFFC2245E)),
    ],
    curatedLipstick: [
      SwatchItem('Fuchsia', Color(0xFFE01890)),
      SwatchItem('Vivid Lilac', Color(0xffdc65d9)),
      SwatchItem('Purple', Color(0xffb52bb4)),
      SwatchItem('Magenta', Color(0xFFD4147A)),
      SwatchItem('Cherry Red', Color(0xFFC41E38)),
      SwatchItem('Raspberry', Color(0xFFC23A62)),
      SwatchItem('Bright Raspberry Pink', Color(0xFFE2447E)),
      SwatchItem('Cool Cherry Red', Color(0xFFD4162E)),
      SwatchItem('Hot Pink', Color(0xFFF02E96)),
    ],
    curatedJewelry: [
      SwatchItem('Silver', Color(0xFFC9CDD1)),
      SwatchItem('Platinum', Color(0xFFDAD7CE)),
      SwatchItem('White Gold', Color(0xFFE2DED4)),
      SwatchItem('Chrome', Color(0xFFD4D6D8)),
      SwatchItem('Pale Gold', Color(0xFFE8D7A0)),
    ],
    curatedTops: _brightWinterTops,
  );

  // SPRING
  static const SeasonCore lightSpring = SeasonCore(
    displayName: 'Spring',
    undertone: 'Warm undertone',
    description:
        'A warm, light, and delicate season ,soft pastels with a gentle golden glow.',
    warm: true,

    curatedBottoms: [
      SwatchItem('Light Camel', Color(0xFFD8B88A)),
      SwatchItem('Warm Beige', Color(0xFFDCC7A3)),
      SwatchItem('Warm Taupe', Color(0xFFB89F84)),
      SwatchItem('Soft Cocoa', Color(0xFF9A7B61)),
      SwatchItem('Warm Light Gray', Color(0xFFC9C2B7)),
      SwatchItem('Soft Mint', Color(0xFFBFE5C7)),
      SwatchItem('Light Peach', Color(0xFFF7C8AE)),
      SwatchItem('Sky Blue', Color(0xFF9FD5F5)),
      SwatchItem('Butter Yellow', Color(0xFFF8E38B)),
    ],

    curatedHair: [
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
      SwatchItem('Apricot', Color(0xffffeed4)),
      SwatchItem('Champagne', Color(0xfffff8dc)),
      SwatchItem('Light Gold', Color(0xffebe6e0)),
      SwatchItem('Cocoa', Color(0xff93786d)),
      SwatchItem('Honey Brown', Color(0xffc39a6c)),
      SwatchItem('Moss', Color(0xffbdc9b1)),
      SwatchItem('Soft Gray', Color(0xffd8cecf)),
      SwatchItem('Soft Blue', Color(0xffd6eef2)),
    ],
    curatedBlush: [
      SwatchItem('Cream Blush', Color(0xFFF2C9BC)),
      SwatchItem('Peach Quartz', Color(0xFFF2B79A)),
      SwatchItem('Strawberry Cream', Color(0xFFF0A79C)),
      SwatchItem('Blossom', Color(0xFFF0AFBB)),
      SwatchItem('Peach Blossom', Color(0xFFF2B9A6)),
      SwatchItem('Sun-Kissed Coral', Color(0xFFEE9B7C)),
      SwatchItem('Tickled Pink', Color(0xFFF0A9B8)),
      SwatchItem('Morning Glory', Color(0xFFE893A0)),
      SwatchItem('Camellia Rose', Color(0xFFE88EA0)),
    ],
    curatedLipstick: [
      SwatchItem('Living coral', Color(0xffff7062)),
      SwatchItem('Candlelight Peach', Color(0xfff7a29d)),
      SwatchItem('Peach blossom', Color(0xffea8686)),
      SwatchItem('Sun-kissed coral', Color(0xffea6578)),
      SwatchItem('Tickled pink', Color(0xfff9b7c1)),
      SwatchItem('Morning glory', Color(0xffec819d)),
      SwatchItem('Strawberry pink', Color(0xfff77e8d)),
      SwatchItem('Camellia rose', Color(0xffe86181)),
      SwatchItem('Teaberry', Color(0xffdc3755)),
    ],
    curatedJewelry: [
      SwatchItem('Light Gold', Color(0xFFE4C98A)),
      SwatchItem('Champagne Gold', Color(0xFFDCC08F)),
      SwatchItem('White Gold', Color(0xFFE6DCC6)),
      SwatchItem('Warm Rose Gold', Color(0xFFE3AE8F)),
      SwatchItem('Yellow Gold', Color(0xFFD9B45C)),
    ],
    curatedTops: _lightSpringTops,
  );

  static const SeasonCore brightSpring = SeasonCore(
    displayName: 'Spring',
    undertone: 'Warm undertone',
    description:
        'A warm, vivid, and radiant season — bold, saturated hues that pop with warmth.',
    warm: true,
    curatedBottoms: [
      SwatchItem('Warm Camel', Color(0xFFC79A63)),
      SwatchItem('Cream', Color(0xFFF8F2DE)),
      SwatchItem('Cocoa Brown', Color(0xFF7B5A46)),
      SwatchItem('Clear Navy', Color(0xFF29507A)),
      SwatchItem('Yellow Charcoal', Color(0xFF68614D)),
      SwatchItem('Bright Warm Green', Color(0xFF4FA83D)),
      SwatchItem('Vivid Aqua', Color(0xFF27C7D9)),
      SwatchItem('Golden Yellow', Color(0xFFF5C22F)),
      SwatchItem('Electric Coral', Color(0xFFFF6B5A)),
    ],

    curatedHair: [
      SwatchItem('Golden Blonde', Color(0xFFE4B04E)),
      SwatchItem('Sunflower Blonde', Color(0xFFEAC24E)),
      SwatchItem('Honey Blonde', Color(0xFFD89A44)),
      SwatchItem('Light Copper Red', Color(0xFFC85A2C)),
      SwatchItem('Medium Copper Red', Color(0xFFB84A22)),
      SwatchItem('Light Golden Brown', Color(0xFF9C6A2E)),
      SwatchItem('Medium Golden Brown', Color(0xFF7E4E22)),
      SwatchItem('Amber Brown', Color(0xFF6E4018)),
      SwatchItem('Glossy Chocolate', Color(0xFF4A2E18)),
    ],
    curatedEyeMakeup: [
      SwatchItem('Ivory', Color(0xFFF2E9D2)),
      SwatchItem('Pale Peach', Color(0xffe5d9c3)),
      SwatchItem('Pale Pink', Color(0xfff7dad3)),
      SwatchItem('Cocoa', Color(0xff8f7b70)),
      SwatchItem('Pale magenta', Color(0xffd26292)),
      SwatchItem('Grape', Color(0xff52437c)),
      SwatchItem('Turquoise', Color(0xff377e82)),
      SwatchItem('Lime green', Color(0xffa1bb70)),
      SwatchItem('Emerald', Color(0xff245748)),
    ],
    curatedBlush: [
      SwatchItem('Soft Coral', Color(0xFFF2896A)),
      SwatchItem('Light Berry Red', Color(0xFFE24862)),
      SwatchItem('Pale Raspberry', Color(0xFFE4708E)),
      SwatchItem('Hibiscus', Color(0xFFEE4F8A)),
      SwatchItem('Bright Coral', Color(0xFFF4664E)),
      SwatchItem('Fuchsia Pink', Color(0xFFEC3E9C)),
      SwatchItem('Cool Raspberry', Color(0xFFD63A6E)),
      SwatchItem('Vivid Berry', Color(0xFFC2245E)),
      SwatchItem('Watermelon Pink', Color(0xFFEA5C6A)),
    ],
    curatedLipstick: [
      SwatchItem('Orange', Color(0xFFE85A20)),
      SwatchItem('Tomato Red', Color(0xFFE23A24)),
      SwatchItem('Cherry Red', Color(0xFFD01C34)),
      SwatchItem('Bright Coral', Color(0xFFF1523A)),
      SwatchItem('Pomegranate Red', Color(0xFFC01230)),
      SwatchItem('Fuchsia', Color(0xFFE01890)),
      SwatchItem('Cherry', Color(0xFFC41E38)),
      SwatchItem('Watermelon Red', Color(0xFFE43050)),
      SwatchItem('Vivid Raspberry Pink', Color(0xFFE2447E)),
    ],
    curatedJewelry: [
      SwatchItem('Buttery Yellow Gold', Color(0xFFE8C24E)),
      SwatchItem('Rose Gold Peach', Color(0xFFE3A084)),
      SwatchItem('Silver', Color(0xFFC9CDD1)),
      SwatchItem('Bright Turquoise', Color(0xFF1CB4B4)),
      SwatchItem('Sapphire Yellow', Color(0xFFE8D24E)),
    ],
    curatedTops: _brightSpringTops,
  );

  // AUTUMN
  static const SeasonCore trueAutumn = SeasonCore(
    displayName: 'Autumn',
    undertone: 'Warm undertone',
    description:
        'A warm, rich, and deep season ,full-bodied earth tones bursting with warmth.',
    warm: true,

    curatedBottoms: [
      SwatchItem('Chocolate Brown', Color(0xFF5A3A29)),
      SwatchItem('Dark Olive Green', Color(0xFF4B5A2A)),
      SwatchItem('Camel', Color(0xFFC19A6B)),
      SwatchItem('Rust', Color(0xFFB24A2A)),
      SwatchItem('Warm Espresso', Color(0xFF3A241A)),
      SwatchItem('Deep Moss Green', Color(0xFF556B2F)),
      SwatchItem('Warm Beige', Color(0xFFD8C3A5)),
      SwatchItem('Cognac', Color(0xFF9A5A2E)),
      SwatchItem('Brick Red', Color(0xFF8B3A2B)),
    ],

    curatedHair: [
      SwatchItem('Caramel Blonde', Color(0xFFA6702A)),
      SwatchItem('Copper Red', Color(0xFFB4501E)),
      SwatchItem('Russet Red', Color(0xFF9E4420)),
      SwatchItem('Auburn Red', Color(0xFF8A3418)),
      SwatchItem('Cinnamon Red', Color(0xFF7E3016)),
      SwatchItem('Caramel Brown', Color(0xFF7A4E24)),
      SwatchItem('Light Golden Brown', Color(0xFF8F6030)),
      SwatchItem('Honey Brown', Color(0xFF74491E)),
      SwatchItem('Chestnut Brown', Color(0xFF5C381C)),
    ],
    curatedEyeMakeup: [
      SwatchItem('Warm Ivory', Color(0xFFEEE0BE)),
      SwatchItem('Apricot', Color(0xFFE0A15E)),
      SwatchItem('Gold', Color(0xFFC99A3E)),
      SwatchItem('Khaki', Color(0xFFA79256)),
      SwatchItem('Olive', Color(0xFF6E6A2E)),
      SwatchItem('Moss', Color(0xFF5C6E2E)),
      SwatchItem('Teal', Color(0xFF146070)),
      SwatchItem('Dark Teal', Color(0xFF0E4A52)),
      SwatchItem('Terracotta', Color(0xFFC05A34)),
    ],
    curatedBlush: [
      SwatchItem('Peach', Color(0xFFE8A574)),
      SwatchItem('Apricot', Color(0xFFE0955C)),
      SwatchItem('Coral', Color(0xFFDE7A56)),
      SwatchItem('Terracotta', Color(0xFFC4633C)),
      SwatchItem('Warm Rose', Color(0xFFC46A6C)),
      SwatchItem('Brick', Color(0xFFA2432E)),
      SwatchItem('Cinnamon', Color(0xFF9E5A32)),
      SwatchItem('Amber', Color(0xFFC4791E)),
      SwatchItem('Soft Coral', Color(0xFFE08E68)),
    ],
    curatedLipstick: [
      SwatchItem('Rust', Color(0xFFA2441E)),
      SwatchItem('Terracotta', Color(0xFFC4633C)),
      SwatchItem('Brick Red', Color(0xFF92322A)),
      SwatchItem('Warm Nude', Color(0xFFC4855F)),
      SwatchItem('Cinnamon', Color(0xFF7E3016)),
      SwatchItem('Copper', Color(0xFFA2521E)),
      SwatchItem('Burnt Orange', Color(0xFFB24E1E)),
      SwatchItem('Deep Coral', Color(0xFFC4543A)),
      SwatchItem('Cognac', Color(0xFF7A3E1C)),
    ],
    curatedJewelry: [
      SwatchItem('Copper', Color(0xFFB4611E)),
      SwatchItem('Dark Brass', Color(0xFF8A6A2A)),
      SwatchItem('Gold', Color(0xFFC99A3E)),
      SwatchItem('Bronze', Color(0xFF8A5A20)),
      SwatchItem('Amber Gold', Color(0xFFC4922C)),
    ],
    curatedTops: _trueAutumnTops,
  );

  static const SeasonCore darkAutumn = SeasonCore(
    displayName: 'Autumn',
    undertone: 'Warm undertone',
    description:
        'A warm, deep, and bold season — rich chocolate and spice tones with intensity.',
    warm: true,
    curatedBottoms: [
      SwatchItem('Espresso Brown', Color(0xFF3B241B)),
      SwatchItem('Dark Chocolate', Color(0xFF4A2F25)),
      SwatchItem('Warm Charcoal', Color(0xFF4F4945)),
      SwatchItem('Rich Mahogany', Color(0xFF63372C)),
      SwatchItem('Deep Olive Green', Color(0xFF4B5A2A)),
      SwatchItem('Dark Burgundy', Color(0xFF5A1F2F)),
      SwatchItem('Deep Teal', Color(0xFF1F5C5A)),
      SwatchItem('Warm Navy', Color(0xFF2B3F5B)),
      SwatchItem('Deep Aubergine', Color(0xFF4A304F)),
    ],
    curatedHair: [
      SwatchItem('Dark Honey Blonde', Color(0xFFA9702C)),
      SwatchItem('Dark Caramel Blonde', Color(0xFF97622A)),
      SwatchItem('Dark Copper Red', Color(0xFF8A3A1E)),
      SwatchItem('French Roast', Color(0xFF4A2E1C)),
      SwatchItem('Auburn Red', Color(0xFF7A2E1A)),
      SwatchItem('Mahogany Red', Color(0xFF6E2418)),
      SwatchItem('Medium Chocolate', Color(0xFF3E2818)),
      SwatchItem('Dark Chocolate', Color(0xFF2E1C12)),
      SwatchItem('Jet Black', Color(0xFF16110D)),
    ],
    curatedEyeMakeup: [
      SwatchItem('Ivory', Color(0xFFEDE2C6)),
      SwatchItem('Apricot', Color(0xFFE0A15E)),
      SwatchItem('Camel', Color(0xFFB98A52)),
      SwatchItem('Copper', Color(0xFFA2521E)),
      SwatchItem('Bronze', Color(0xFF8A5A20)),
      SwatchItem('Mahogany', Color(0xFF6E2418)),
      SwatchItem('Deep Amber', Color(0xFFB4681A)),
      SwatchItem('Olive', Color(0xFF6E6A2E)),
      SwatchItem('Teal', Color(0xFF14606A)),
    ],
    curatedBlush: [
      SwatchItem('Pale Salmon', Color(0xFFE4977A)),
      SwatchItem('Pale Vermilion', Color(0xFFDE6A44)),
      SwatchItem('Berry Red', Color(0xFFA62E3A)),
      SwatchItem('Cardinal Red', Color(0xFF942028)),
      SwatchItem('Pale Magenta', Color(0xFFC4587C)),
      SwatchItem('Mulberry', Color(0xFF8A3358)),
      SwatchItem('Terracotta', Color(0xFFC05A34)),
      SwatchItem('Warm Rose', Color(0xFFC4626C)),
      SwatchItem('Deep Coral', Color(0xFFC4543A)),
    ],
    curatedLipstick: [
      SwatchItem('Pale Vermilion', Color(0xFFDE6A44)),
      SwatchItem('Berry Red', Color(0xFFA62E3A)),
      SwatchItem('Mulberry', Color(0xFF8A3358)),
      SwatchItem('Pecan Brown', Color(0xFF6E4226)),
      SwatchItem('Dark Wine', Color(0xFF5A1A28)),
      SwatchItem('Rust', Color(0xFFA24422)),
      SwatchItem('Cognac', Color(0xFF7A3E1C)),
      SwatchItem('Burnt Orange', Color(0xFFB24E1E)),
      SwatchItem('Deep Red', Color(0xFF7A1A22)),
    ],
    curatedJewelry: [
      SwatchItem('Oxidized Copper', Color(0xFF8A5030)),
      SwatchItem('Gold', Color(0xFFC99A3E)),
      SwatchItem('Bronze', Color(0xFF8A5A20)),
      SwatchItem('Matte Silver', Color(0xFF8F9092)),
      SwatchItem('Antique Brass', Color(0xFF7E602A)),
    ],
    curatedTops: _darkAutumnTops,
  );

  // SUMMER
  static const SeasonCore lightSummer = SeasonCore(
    displayName: 'Summer',
    undertone: 'Cool undertone',
    description:
        'A cool, light, and airy season ,soft pastel hues with a gentle silvery touch.',
    warm: false,

    curatedBottoms: [
      SwatchItem('Soft Dove Gray', Color(0xFFD7D9DD)),
      SwatchItem('Cool Beige', Color(0xFFD9D2C7)),
      SwatchItem('Light Ash Gray', Color(0xFFC2C7CC)),
      SwatchItem('Pale Taupe', Color(0xFFB4AAA4)),
      SwatchItem('Off-White', Color(0xFFF8F7F2)),
      SwatchItem('Powder Blue', Color(0xFFAFCDEB)),
      SwatchItem('Soft Navy Blue', Color(0xFF556C89)),
      SwatchItem('Cool Sage Green', Color(0xFFA7B8A3)),
      SwatchItem('Soft Lavender', Color(0xFFC7BEDF)),
    ],

    curatedHair: [
      SwatchItem('Icy Blonde', Color(0xFFE3D8C2)),
      SwatchItem('Nordic Blonde', Color(0xFFD9C9A6)),
      SwatchItem('Light Ash Blonde', Color(0xFFCDBB94)),
      SwatchItem('Dark Ash Blonde', Color(0xFFB4A17A)),
      SwatchItem('Light Neutral Brown', Color(0xFFA48F70)),
      SwatchItem('Light Cool Brown', Color(0xFF96805E)),
      SwatchItem('Light Ash Brown', Color(0xFF83714F)),
      SwatchItem('Medium Neutral Brown', Color(0xFF6E5B41)),
      SwatchItem('Medium Ash Brown', Color(0xFF5E4E38)),
    ],
    curatedEyeMakeup: [
      SwatchItem('Rice', Color(0xFFF0EFEE)),
      SwatchItem('Cream', Color(0xFFEDE6D2)),
      SwatchItem('Dusty Peach', Color(0xFFE4C1AA)),
      SwatchItem('Soft Grey', Color(0xFFC6C6C4)),
      SwatchItem('Cocoa', Color(0xFF8E7361)),
      SwatchItem('Slate Blue', Color(0xFF7C93AA)),
      SwatchItem('Lilac', Color(0xFFC6B4D6)),
      SwatchItem('Powder Blue', Color(0xFFB9D3E0)),
      SwatchItem('Dusty Rose', Color(0xFFD4A7A9)),
    ],
    curatedBlush: [
      SwatchItem('Light Pink', Color(0xFFF0C6CC)),
      SwatchItem('Rose', Color(0xFFD98C9C)),
      SwatchItem('Watermelon', Color(0xFFE4808F)),
      SwatchItem('Mauve', Color(0xFFB98C97)),
      SwatchItem('Punch', Color(0xFFE36E86)),
      SwatchItem('Soft Coral', Color(0xFFE8A490)),
      SwatchItem('Dusty Rose', Color(0xFFD4A7A9)),
      SwatchItem('Cool Pink', Color(0xFFE499AC)),
      SwatchItem('Lilac Pink', Color(0xFFDDA9C4)),
    ],
    curatedLipstick: [
      SwatchItem('Ultra Pink', Color(0xFFE874A0)),
      SwatchItem('Rose Glow', Color(0xFFD9748C)),
      SwatchItem('Soft Rose', Color(0xFFD48A98)),
      SwatchItem('Cool Mauve', Color(0xFFA9707E)),
      SwatchItem('Petal Pink', Color(0xFFE7A8B8)),
      SwatchItem('Dusty Rose', Color(0xFFC48A92)),
      SwatchItem('Raspberry', Color(0xFFC23A62)),
      SwatchItem('Ballerina Pink', Color(0xFFE7B4C2)),
      SwatchItem('Soft Berry', Color(0xFFB45A72)),
    ],
    curatedJewelry: [
      SwatchItem('Silver', Color(0xFFCBCDD0)),
      SwatchItem('White Gold', Color(0xFFE2DED4)),
      SwatchItem('Rose Gold', Color(0xFFE0B8AC)),
      SwatchItem('Platinum', Color(0xFFD9D6CE)),
      SwatchItem('Pearl White', Color(0xFFEDE9E1)),
    ],
    curatedTops: _lightSummerTops,
  );

  static const SeasonCore trueSummer = SeasonCore(
    displayName: 'Summer',
    undertone: 'Cool undertone',
    description:
        'A cool, muted, and elegant season ,soft dusty tones with quiet sophistication.',
    warm: false,

    curatedBottoms: [
      SwatchItem('Cool Navy', Color(0xFF2F4768)),
      SwatchItem('Slate Grey', Color(0xFF6E7682)),
      SwatchItem('Soft Charcoal', Color(0xFF4B5058)),
      SwatchItem('Cool Taupe', Color(0xFF9A908B)),
      SwatchItem('Classic Denim Blue', Color(0xFF4F6D8C)),
      SwatchItem('Pine Green', Color(0xFF3F5E55)),
      SwatchItem('Muted Plum', Color(0xFF6D5A78)),
      SwatchItem('Soft Sage', Color(0xFF9AA995)),
      SwatchItem('Raspberry', Color(0xFFB14E73)),
    ],

    curatedHair: [
      SwatchItem('Ash Blonde', Color(0xFFB9AC90)),
      SwatchItem('Dark Ash Blonde', Color(0xFFA0906E)),
      SwatchItem('Medium Ash Brown', Color(0xFF7C6B52)),
      SwatchItem('Dark Ash Brown', Color(0xFF5E4E3C)),
      SwatchItem('Taupe Brown', Color(0xFF6E5C4A)),
      SwatchItem('Cool Brunette', Color(0xFF4A3C2E)),
      SwatchItem('Silver', Color(0xFFC3C4C6)),
      SwatchItem('Pewter', Color(0xFF9A9B9C)),
      SwatchItem('Mushroom Brown', Color(0xFF8A7A64)),
    ],
    curatedEyeMakeup: [
      SwatchItem('Porcelain', Color(0xffe6e2e3)),
      SwatchItem('Hazel Wood', Color(0xffcfc6c1)),
      SwatchItem('Ash brown', Color(0xff816c71)),
      SwatchItem('Mauve', Color(0xFFA9707E)),
      SwatchItem('Dusty Rose', Color(0xFFC48A92)),
      SwatchItem('Teal', Color(0xFF1E6E70)),
      SwatchItem('Slate Blue', Color(0xFF5C7690)),
      SwatchItem('Aubergine', Color(0xff652b65)),
      SwatchItem('Sage', Color(0xFF8A9878)),
    ],
    curatedBlush: [
      SwatchItem('Sea Pink', Color(0xFFDE93A0)),
      SwatchItem('Chateau Rose', Color(0xFFC97488)),
      SwatchItem('Bubblegum', Color(0xFFE48CAC)),
      SwatchItem('Carmine', Color(0xFFA02040)),
      SwatchItem('Anemone', Color(0xFFC060A0)),
      SwatchItem('Pink-a-boo', Color(0xFFE4A0B8)),
      SwatchItem('Mauve Rose', Color(0xFFB4788C)),
      SwatchItem('Berry', Color(0xFF9C3A5E)),
      SwatchItem('Wine', Color(0xFF6E2438)),
      SwatchItem('Dusty Pink', Color(0xFFCB93A0)),
    ],
    curatedLipstick: [
      SwatchItem('Rose Petal', Color(0xFFC97488)),
      SwatchItem('Mauve Rose', Color(0xFFB4788C)),
      SwatchItem('Berry Wine', Color(0xFF8A2E48)),
      SwatchItem('Carmine Red', Color(0xFFA02040)),
      SwatchItem('Plum', Color(0xFF6E4462)),
      SwatchItem('Raspberry', Color(0xFFB23A5E)),
      SwatchItem('Dusty Mauve', Color(0xFFA9707E)),
      SwatchItem('Cool Pink', Color(0xFFDE93A0)),
      SwatchItem('Orchid', Color(0xFFA060A8)),
    ],
    curatedJewelry: [
      SwatchItem('Silver', Color(0xFFCBCDD0)),
      SwatchItem('Sterling Silver', Color(0xFFC3C5C8)),
      SwatchItem('Platinum', Color(0xFFD9D6CE)),
      SwatchItem('White Gold', Color(0xFFE2DED4)),
      SwatchItem('Pewter', Color(0xFF9A9B9C)),
    ],
    curatedTops: _trueSummerTops,
  );

  //trueWinter = winter กลางวัน
  static const List<SwatchItem> _trueWinterTops = [
    //Group 1
    SwatchItem('Pure White', Color(0xFFFFFFFF)),
    SwatchItem('Ice White', Color(0xFFF3F4FA)),
    SwatchItem('Cool Pearl', Color(0xFFE6E4EA)),
    SwatchItem('Taupe Grey', Color(0xFFB2A7AE)),
    SwatchItem('Cool Charcoal', Color(0xFF7E727A)),
    SwatchItem('Silver Grey', Color(0xFFD7D9E2)),
    SwatchItem('Steel Grey', Color(0xFFB8BCC8)),
    SwatchItem('Blue Grey', Color(0xFF8D93A5)),
    SwatchItem('Midnight Navy', Color(0xFF222935)),
    //Group 2
    SwatchItem('Soft Ice Pink', Color(0xFFF8D7F0)),
    SwatchItem('Lemon Ice', Color(0xFFF8F38A)),
    SwatchItem('Mint Frost', Color(0xFFC6EBC8)),
    SwatchItem('Ice Aqua', Color(0xFFBCEFFD)),
    SwatchItem('Ice Lavender', Color(0xFFD6DBFF)),
    SwatchItem('Winter Yellow', Color(0xFFF3E95C)),
    SwatchItem('Golden Lemon', Color(0xFFF5D24C)),
    SwatchItem('Winter Red', Color(0xFFE53B61)),
    SwatchItem('Raspberry Red', Color(0xFFB63259)),
    //Group 3
    SwatchItem('Baby Pink', Color(0xFFF2A9DA)),
    SwatchItem('Rose Pink', Color(0xFFE887C3)),
    SwatchItem('Hot Pink', Color(0xFFD960AF)),
    SwatchItem('Fuchsia Pink', Color(0xFFD13F9E)),
    SwatchItem('Berry Pink', Color(0xFFB53581)),
    SwatchItem('Cherry Pink', Color(0xFFE96AA8)),
    SwatchItem('Magenta', Color(0xFFE34C95)),
    SwatchItem('Deep Magenta', Color(0xFFC02E77)),
    SwatchItem('Plum Purple', Color(0xFF6C2C63)),
    //Group 4
    SwatchItem('Berry Pink', Color(0xFFE98CC9)),
    SwatchItem('Rose Pink', Color(0xFFE77ABF)),
    SwatchItem('Hot Pink', Color(0xFFE457B8)),
    SwatchItem('Cyclamen', Color(0xFFD63FA8)),
    SwatchItem('Magenta', Color(0xFFC32F92)),
    SwatchItem('Raspberry', Color(0xFFE94C8A)),
    SwatchItem('Cerise', Color(0xFFD93D7E)),
    SwatchItem('Ruby', Color(0xFFC72E73)),
    SwatchItem('Mulberry', Color(0xFF9C2D63)),
    //Group 5
    SwatchItem('Orchid', Color(0xFFD78CCB)),
    SwatchItem('Fuchsia', Color(0xFFC95CB8)),
    SwatchItem('Deep Fuchsia', Color(0xFFB445A3)),
    SwatchItem('Plum', Color(0xFF9D3E8A)),
    SwatchItem('Wine', Color(0xFF82356F)),
    SwatchItem('Eggplant', Color(0xFF5D294E)),
    SwatchItem('Lavender Purple', Color(0xFFA996DB)),
    SwatchItem('Royal Purple', Color(0xFF8766C9)),
    SwatchItem('Deep Violet', Color(0xFF6548A9)),
    //Group 6
    SwatchItem('Indigo', Color(0xFF4D4EA8)),
    SwatchItem('Royal Blue', Color(0xFF3F46B4)),
    SwatchItem('Sapphire', Color(0xFF2847B8)),
    SwatchItem('Cobalt Blue', Color(0xFF204FAE)),
    SwatchItem('True Blue', Color(0xFF2E6CCB)),
    SwatchItem('Cornflower Blue', Color(0xFF5E90E3)),
    SwatchItem('Sky Blue', Color(0xFF6EB5F0)),
    SwatchItem('Steel Blue', Color(0xFF3476A8)),
    SwatchItem('Petrol Blue', Color(0xFF255E82)),
    //Group 7
    SwatchItem('Navy', Color(0xFF203C84)),
    SwatchItem('Midnight Blue', Color(0xFF1B2E69)),
    SwatchItem('Deep Navy', Color(0xFF18234F)),
    SwatchItem('Charcoal', Color(0xFF34323B)),
    SwatchItem('Graphite', Color(0xFF4A4752)),
    SwatchItem('Soft Black', Color(0xFF26232C)),
    SwatchItem('Black', Color(0xFF121212)),
    SwatchItem('Cool Black', Color(0xFF1A1C24)),
    SwatchItem('Jet Black', Color(0xFF0A0A0A)),
  ];

  //brightWinter = winter กลางคืน
  static const List<SwatchItem> _brightWinterTops = [
    //Group 1
    SwatchItem('Lemon Yellow', Color(0xFFFFE36A)),
    SwatchItem('Butter Yellow', Color(0xFFF9EA8A)),
    SwatchItem('Lime Green', Color(0xFF7FD13F)),
    SwatchItem('Apple Green', Color(0xFF8AAE55)),
    SwatchItem('Yellow Green', Color(0xFFA9C943)),
    SwatchItem('Bright Pink', Color(0xFFE02E7C)),
    SwatchItem('Coral Pink', Color(0xFFE97A84)),
    SwatchItem('Cherry Red', Color(0xFFE53C4B)),
    SwatchItem('True Red', Color(0xFFE51E3E)),
    //Group 2
    SwatchItem('Raspberry', Color(0xFFD22D73)),
    SwatchItem('Berry', Color(0xFFA33159)),
    SwatchItem('Rose Pink', Color(0xFFDD7AAE)),
    SwatchItem('Hot Pink', Color(0xFFE02C7C)),
    SwatchItem('Fuchsia', Color(0xFFDF287F)),
    SwatchItem('Cerise', Color(0xFFD12B87)),
    SwatchItem('Magenta', Color(0xFFCA2E87)),
    SwatchItem('Mulberry', Color(0xFFAA367E)),
    SwatchItem('Orchid', Color(0xFFB04398)),
    //Group 3
    SwatchItem('Purple', Color(0xFF863C91)),
    SwatchItem('Lavender Purple', Color(0xFF9759A6)),
    SwatchItem('Royal Purple', Color(0xFF833A91)),
    SwatchItem('Muted Purple', Color(0xFF76589C)),
    SwatchItem('Indigo Purple', Color(0xFF564A95)),
    SwatchItem('Mint Green', Color(0xFF5DB16D)),
    SwatchItem('Emerald', Color(0xFF119C46)),
    SwatchItem('Forest Green', Color(0xFF11743B)),
    SwatchItem('Teal', Color(0xFF149A8A)),
    //Group 4
    SwatchItem('Deep Teal', Color(0xFF126C64)),
    SwatchItem('Soft Aqua', Color(0xFF69B7BF)),
    SwatchItem('Turquoise', Color(0xFF1797A0)),
    SwatchItem('Sky Blue', Color(0xFF40A9D5)),
    SwatchItem('Azure', Color(0xFF1D88C2)),
    SwatchItem('Ocean Blue', Color(0xFF197393)),
    SwatchItem('Powder Blue', Color(0xFF82A9D3)),
    SwatchItem('Royal Blue', Color(0xFF3E69A9)),
    SwatchItem('True Blue', Color(0xFF1B5FA5)),
    //Group 5
    SwatchItem('Cobalt Blue', Color(0xFF3E57A6)),
    SwatchItem('Navy Blue', Color(0xFF324F89)),
    SwatchItem('Slate Blue', Color(0xFF6576B1)),
    SwatchItem('Steel Blue', Color(0xFF4E5AA0)),
    SwatchItem('Deep Indigo', Color(0xFF43469A)),
    SwatchItem('Indigo', Color(0xFF4A4C98)),
    SwatchItem('Midnight Blue', Color(0xFF4A4B86)),
    SwatchItem('Dusty Purple', Color(0xFF786AAE)),
    SwatchItem('Blue Violet', Color(0xFF50479C)),
    //Group 6
    SwatchItem('Taupe', Color(0xFF6A5A57)),
    SwatchItem('Mushroom', Color(0xFF5B4A47)),
    SwatchItem('Espresso', Color(0xFF4A3A3D)),
    SwatchItem('Charcoal', Color(0xFF454346)),
    SwatchItem('Cool Gray', Color(0xFF666A69)),
    SwatchItem('Light Gray', Color(0xFFA7A79F)),
    SwatchItem('Silver Gray', Color(0xFFB7B7B4)),
    SwatchItem('Soft Gray', Color(0xFFC9C8C4)),
    SwatchItem('Warm Taupe', Color(0xFF8A8478)),
    //Group 7
    SwatchItem('Stone', Color(0xFF918B84)),
    SwatchItem('Greige', Color(0xFF979090)),
    SwatchItem('Warm Beige', Color(0xFFB3AC9A)),
    SwatchItem('Cream', Color(0xFFDDD6C7)),
    SwatchItem('White', Color(0xFFF7F7F7)),
    SwatchItem('Ice Blue', Color(0xFFC0E4EC)),
    SwatchItem('Ice Pink', Color(0xFFECC8D9)),
    SwatchItem('Ice Yellow', Color(0xFFF8EFA8)),
    SwatchItem('Ice Mint', Color(0xFFB7D2C4)),
  ];

  //lightSpring = spring กลางวัน
  static const List<SwatchItem> _lightSpringTops = [
    //Group 1
    SwatchItem('Ivory Cream', Color(0xFFF9F2E6)),
    SwatchItem('Warm Cream', Color(0xFFF5ECD8)),
    SwatchItem('Vanilla', Color(0xFFF0E4C8)),
    SwatchItem('Soft Khaki', Color(0xFFC8C4A9)),
    SwatchItem('Warm Gray', Color(0xFF9C9B8B)),
    SwatchItem('Light Gray', Color(0xFFC7C6BD)),
    SwatchItem('Olive Gray', Color(0xFF9B998A)),
    SwatchItem('Taupe', Color(0xFF7C766C)),
    SwatchItem('Charcoal Taupe', Color(0xFF5E5A53)),
    //Group 2
    SwatchItem('Camel', Color(0xFFD8B487)),
    SwatchItem('Sand', Color(0xFFC9AC8C)),
    SwatchItem('Warm Beige', Color(0xFFB89C85)),
    SwatchItem('Mocha', Color(0xFF8D7867)),
    SwatchItem('Peach Cream', Color(0xFFF9D8CB)),
    SwatchItem('Soft Peach', Color(0xFFF7C3B1)),
    SwatchItem('Apricot', Color(0xFFF4AF8D)),
    SwatchItem('Coral Peach', Color(0xFFF28E7D)),
    SwatchItem('Soft Coral', Color(0xFFEF766D)),
    //Group 3
    SwatchItem('Butter Yellow', Color(0xFFFDEB8A)),
    SwatchItem('Soft Lemon', Color(0xFFFCE37A)),
    SwatchItem('Golden Yellow', Color(0xFFFAD968)),
    SwatchItem('Honey Yellow', Color(0xFFF9D15B)),
    SwatchItem('Warm Butter', Color(0xFFF7E8A3)),
    SwatchItem('Pale Aqua', Color(0xFFAEDFD8)),
    SwatchItem('Seafoam', Color(0xFF8FD5CC)),
    SwatchItem('Mint Aqua', Color(0xFF73CFC7)),
    SwatchItem('Soft Turquoise', Color(0xFF58C4B9)),
    //Group 4
    SwatchItem('Turquoise', Color(0xFF36B6A8)),
    SwatchItem('Light Mint', Color(0xFF9FD7C8)),
    SwatchItem('Fresh Mint', Color(0xFF78CDBA)),
    SwatchItem('Spring Green', Color(0xFF49BEA4)),
    SwatchItem('Aqua Green', Color(0xFF2FAE95)),
    SwatchItem('Robin Egg Blue', Color(0xFF79C9D8)),
    SwatchItem('Sky Blue', Color(0xFF5EBAD4)),
    SwatchItem('Ocean Blue', Color(0xFF40A9CB)),
    SwatchItem('Bright Teal', Color(0xFF2E9FBC)),
    //Group 5
    SwatchItem('Baby Blue', Color(0xFFA6CDEA)),
    SwatchItem('Powder Blue', Color(0xFF8FBFE2)),
    SwatchItem('Cornflower Blue', Color(0xFF74AED9)),
    SwatchItem('Azure Blue', Color(0xFF4E9BCF)),
    SwatchItem('Cerulean Blue', Color(0xFF338DC6)),
    SwatchItem('Steel Blue', Color(0xFF7DABD4)),
    SwatchItem('Denim Blue', Color(0xFF5D94C7)),
    SwatchItem('Royal Blue', Color(0xFF2E73B9)),
    SwatchItem('Deep Royal Blue', Color(0xFF1F5DA8)),
    //Group 6
    SwatchItem('Blush Pink', Color(0xFFF7C6CD)),
    SwatchItem('Rose Pink', Color(0xFFF3AEBB)),
    SwatchItem('Watermelon', Color(0xFFEE8C9F)),
    SwatchItem('Coral Pink', Color(0xFFE96F88)),
    SwatchItem('Bright Rose', Color(0xFFE55674)),
    SwatchItem('Candy Pink', Color(0xFFF3A2C3)),
    SwatchItem('Pink Peony', Color(0xFFEF86B0)),
    SwatchItem('Raspberry Pink', Color(0xFFE4538F)),
    SwatchItem('Cherry Pink', Color(0xFFD93C6E)),
    //Group 7
    SwatchItem('Light Lime', Color(0xFFC7DF8A)),
    SwatchItem('Fresh Green', Color(0xFFA8D07A)),
    SwatchItem('Apple Green', Color(0xFF87C160)),
    SwatchItem('Leaf Green', Color(0xFF63AF4E)),
    SwatchItem('Emerald Green', Color(0xFF20A36F)),
    SwatchItem('Periwinkle', Color(0xFF93A8DA)),
    SwatchItem('Blue Violet', Color(0xFF738CCF)),
    SwatchItem('Lavender', Color(0xFF8977B9)),
    SwatchItem('Royal Purple', Color(0xFF684A95)),
  ];

  //brightSpring = spring กลางคืน
  static const List<SwatchItem> _brightSpringTops = [
    //Group 1
    SwatchItem('Ivory', Color(0xFFF7F3E8)),
    SwatchItem('Vanilla Cream', Color(0xFFF4EEDB)),
    SwatchItem('Warm Cream', Color(0xFFEFE5C8)),
    SwatchItem('Light Sand', Color(0xFFD9D1BE)),
    SwatchItem('Warm Beige', Color(0xFFC8BDA7)),
    SwatchItem('Sage Gray', Color(0xFFA5A79A)),
    SwatchItem('Warm Taupe', Color(0xFF89887B)),
    SwatchItem('Olive Gray', Color(0xFF6F746B)),
    SwatchItem('Charcoal', Color(0xFF4C4D49)),
    //Group 2
    SwatchItem('Lemon Chiffon', Color(0xFFFFEBA8)),
    SwatchItem('Butter Yellow', Color(0xFFFFE078)),
    SwatchItem('Sunshine Yellow', Color(0xFFFFD45B)),
    SwatchItem('Golden Yellow', Color(0xFFFFC94F)),
    SwatchItem('Marigold', Color(0xFFF8B84B)),
    SwatchItem('Apricot', Color(0xFFF6A45B)),
    SwatchItem('Tangerine', Color(0xFFEF8B47)),
    SwatchItem('Persimmon', Color(0xFFE76E45)),
    SwatchItem('Vermilion', Color(0xFFD6533E)),
    //Group 3
    SwatchItem('Shell Pink', Color(0xFFF5B5B2)),
    SwatchItem('Peach Pink', Color(0xFFF5A096)),
    SwatchItem('Salmon', Color(0xFFF4877E)),
    SwatchItem('Warm Coral', Color(0xFFF1786E)),
    SwatchItem('Living Coral', Color(0xFFEE695F)),
    SwatchItem('Poppy Red', Color(0xFFE95655)),
    SwatchItem('Tomato Red', Color(0xFFE34843)),
    SwatchItem('Strawberry Red', Color(0xFFDB3F51)),
    SwatchItem('Bright Scarlet', Color(0xFFD32E46)),
    //Group 4
    SwatchItem('Pallet Pink', Color(0xFFF4A6BB)),
    SwatchItem('Flamingo Pink', Color(0xFFF18FAE)),
    SwatchItem('Watermelon Pink', Color(0xFFED718F)),
    SwatchItem('Geranium Pink', Color(0xFFE65E85)),
    SwatchItem('Rose Pink', Color(0xFFE34E7E)),
    SwatchItem('Raspberry Pink', Color(0xFFD83F77)),
    SwatchItem('Hot Pink', Color(0xFFD93683)),
    SwatchItem('Fuchsia', Color(0xFFC83786)),
    SwatchItem('Magenta', Color(0xFFAE397F)),
    //Group 5
    SwatchItem('Soft Lavender', Color(0xFFB4A7D7)),
    SwatchItem('Lavender', Color(0xFFA58BCD)),
    SwatchItem('Orchid', Color(0xFF9D72C3)),
    SwatchItem('Amethyst', Color(0xFF8B62B6)),
    SwatchItem('Bright Violet', Color(0xFF7950AA)),
    SwatchItem('Purple', Color(0xFF69439A)),
    SwatchItem('Royal Purple', Color(0xFF62368D)),
    SwatchItem('Periwinkle', Color(0xFF6269AE)),
    SwatchItem('Blue Violet', Color(0xFF4D579E)),
    //Group 6
    SwatchItem('Powder Blue', Color(0xFFA9D9E8)),
    SwatchItem('Aqua', Color(0xFF79CFD9)),
    SwatchItem('Bright Aqua', Color(0xFF58C3CE)),
    SwatchItem('Turquoise', Color(0xFF3DB5BE)),
    SwatchItem('Lagoon Blue', Color(0xFF319EAA)),
    SwatchItem('Cerulean', Color(0xFF278DA7)),
    SwatchItem('Azure Blue', Color(0xFF267CAD)),
    SwatchItem('Cobalt Blue', Color(0xFF2D64A0)),
    SwatchItem('Deep Marine Blue', Color(0xFF315378)),
    //Group 7
    SwatchItem('Mint Green', Color(0xFF75BE83)),
    SwatchItem('Spring Green', Color(0xFF59B574)),
    SwatchItem('Apple Green', Color(0xFF48AA61)),
    SwatchItem('Kelly Green', Color(0xFF329B58)),
    SwatchItem('Emerald Green', Color(0xFF238C54)),
    SwatchItem('Jade Green', Color(0xFF258B70)),
    SwatchItem('Tropical Green', Color(0xFF197D69)),
    SwatchItem('Teal Green', Color(0xFF17716A)),
    SwatchItem('Deep Teal', Color(0xFF23645F)),
  ];

  //trueAutumn = autumn กลางวัน
  static const List<SwatchItem> _trueAutumnTops = [
    //Group 1
    SwatchItem('Ivory', Color(0xFFF5ECDD)),
    SwatchItem('Oatmeal', Color(0xFFE9DDC3)),
    SwatchItem('Camel', Color(0xFFD8C19B)),
    SwatchItem('Golden Beige', Color(0xFFC9AE82)),
    SwatchItem('Tan', Color(0xFFB49266)),
    SwatchItem('Caramel', Color(0xFF9F7A50)),
    SwatchItem('Cocoa', Color(0xFF826042)),
    SwatchItem('Coffee Brown', Color(0xFF644731)),
    SwatchItem('Espresso', Color(0xFF493224)),
    //Group 2
    SwatchItem('Wheat', Color(0xFFF0D98A)),
    SwatchItem('Honey', Color(0xFFE8C96C)),
    SwatchItem('Goldenrod', Color(0xFFDDB24E)),
    SwatchItem('Mustard', Color(0xFFD09B36)),
    SwatchItem('Ochre', Color(0xFFC3872E)),
    SwatchItem('Bronze Gold', Color(0xFFB6782D)),
    SwatchItem('Antique Gold', Color(0xFFA86A2D)),
    SwatchItem('Burnished Gold', Color(0xFF935A29)),
    SwatchItem('Copper Gold', Color(0xFF7F4C25)),
    //Group 3
    SwatchItem('Apricot', Color(0xFFF1B174)),
    SwatchItem('Peach', Color(0xFFE99A60)),
    SwatchItem('Pumpkin', Color(0xFFE28547)),
    SwatchItem('Tangerine', Color(0xFFD97234)),
    SwatchItem('Burnt Orange', Color(0xFFCA6330)),
    SwatchItem('Rust', Color(0xFFB9572D)),
    SwatchItem('Cinnamon', Color(0xFFA84C2B)),
    SwatchItem('Terracotta', Color(0xFF94442A)),
    SwatchItem('Copper', Color(0xFF7F3C28)),
    //Group 4
    SwatchItem('Salmon', Color(0xFFE39B8A)),
    SwatchItem('Coral', Color(0xFFD98773)),
    SwatchItem('Coral Rose', Color(0xFFD17663)),
    SwatchItem('Brick', Color(0xFFC26557)),
    SwatchItem('Brick Red', Color(0xFFAF554B)),
    SwatchItem('Tomato Brown', Color(0xFF9C473F)),
    SwatchItem('Redwood', Color(0xFF883C36)),
    SwatchItem('Mahogany', Color(0xFF71302D)),
    SwatchItem('Oxblood', Color(0xFF5B2626)),
    //Group 5
    SwatchItem('Dusty Rose', Color(0xFFC79AA4)),
    SwatchItem('Mauve', Color(0xFFB28393)),
    SwatchItem('Heather', Color(0xFF9C6E83)),
    SwatchItem('Dusty Plum', Color(0xFF8A5D77)),
    SwatchItem('Plum', Color(0xFF784E69)),
    SwatchItem('Mulberry', Color(0xFF68405B)),
    SwatchItem('Aubergine', Color(0xFF58354E)),
    SwatchItem('Eggplant', Color(0xFF472A42)),
    SwatchItem('Deep Aubergine', Color(0xFF382035)),
    //Group 6
    SwatchItem('Duck Egg Blue', Color(0xFFA5C8C8)),
    SwatchItem('Mist Blue', Color(0xFF8CB8BE)),
    SwatchItem('Slate Blue', Color(0xFF73A6B1)),
    SwatchItem('Petrol Blue', Color(0xFF5B95A1)),
    SwatchItem('Teal', Color(0xFF47858E)),
    SwatchItem('Peacock', Color(0xFF3C7682)),
    SwatchItem('Deep Teal', Color(0xFF346771)),
    SwatchItem('Blue Spruce', Color(0xFF2C5862)),
    SwatchItem('Ink Blue', Color(0xFF244A54)),
    //Group 7
    SwatchItem('Sage', Color(0xFFB7C19A)),
    SwatchItem('Moss', Color(0xFF9EAF7D)),
    SwatchItem('Olive', Color(0xFF879A61)),
    SwatchItem('Olive Green', Color(0xFF71854C)),
    SwatchItem('Leaf Green', Color(0xFF5F7443)),
    SwatchItem('Fern', Color(0xFF51653B)),
    SwatchItem('Forest Green', Color(0xFF425634)),
    SwatchItem('Pine Green', Color(0xFF35472D)),
    SwatchItem('Deep Moss', Color(0xFF293A27)),
  ];

  //darkAutumn = autumn กลางคืน
  static const List<SwatchItem> _darkAutumnTops = [
    //Group 1
    SwatchItem('Bone', Color(0xFFF0E5D5)),
    SwatchItem('Antique Ivory', Color(0xFFE4D2BA)),
    SwatchItem('Camel', Color(0xFFCDAA79)),
    SwatchItem('Golden Brown', Color(0xFFB88857)),
    SwatchItem('Saddle Brown', Color(0xFF9F6A43)),
    SwatchItem('Walnut', Color(0xFF835337)),
    SwatchItem('Chestnut', Color(0xFF69402C)),
    SwatchItem('Dark Chocolate', Color(0xFF4E3023)),
    SwatchItem('Espresso', Color(0xFF342019)),
    //Group 2
    SwatchItem('Golden Honey', Color(0xFFE3BF62)),
    SwatchItem('Harvest Gold', Color(0xFFD4A948)),
    SwatchItem('Mustard', Color(0xFFC39431)),
    SwatchItem('Bronze', Color(0xFFB18028)),
    SwatchItem('Burnished Gold', Color(0xFF9D6D24)),
    SwatchItem('Antique Brass', Color(0xFF8A5D22)),
    SwatchItem('Old Gold', Color(0xFF77501F)),
    SwatchItem('Olive Gold', Color(0xFF64451C)),
    SwatchItem('Tarnished Gold', Color(0xFF513919)),
    //Group 3
    SwatchItem('Apricot', Color(0xFFD89A66)),
    SwatchItem('Pumpkin', Color(0xFFC97F49)),
    SwatchItem('Copper', Color(0xFFB86937)),
    SwatchItem('Burnt Orange', Color(0xFFA95A2F)),
    SwatchItem('Rust', Color(0xFF964C2C)),
    SwatchItem('Cinnamon', Color(0xFF84412B)),
    SwatchItem('Terracotta', Color(0xFF733828)),
    SwatchItem('Mahogany', Color(0xFF612F24)),
    SwatchItem('Burnt Copper', Color(0xFF51271F)),
    //Group 4
    SwatchItem('Dusty Coral', Color(0xFFC98578)),
    SwatchItem('Brick', Color(0xFFB56A5C)),
    SwatchItem('Redwood', Color(0xFFA0564C)),
    SwatchItem('Burnt Brick', Color(0xFF8E473F)),
    SwatchItem('Auburn', Color(0xFF7C3C37)),
    SwatchItem('Mahogany Red', Color(0xFF69332F)),
    SwatchItem('Oxblood', Color(0xFF582A2A)),
    SwatchItem('Burgundy', Color(0xFF472124)),
    SwatchItem('Black Cherry', Color(0xFF38191E)),
    //Group 5
    SwatchItem('Dusty Mauve', Color(0xFFAE8793)),
    SwatchItem('Mauve', Color(0xFF977181)),
    SwatchItem('Plum', Color(0xFF825D70)),
    SwatchItem('Mulberry', Color(0xFF714D63)),
    SwatchItem('Aubergine', Color(0xFF603F56)),
    SwatchItem('Eggplant', Color(0xFF523449)),
    SwatchItem('Blackberry', Color(0xFF442A3E)),
    SwatchItem('Deep Plum', Color(0xFF382133)),
    SwatchItem('Black Plum', Color(0xFF2B1828)),
    //Group 6
    SwatchItem('Slate Blue', Color(0xFF84A2AD)),
    SwatchItem('Steel Blue', Color(0xFF6E8E99)),
    SwatchItem('Petrol Blue', Color(0xFF597A85)),
    SwatchItem('Teal', Color(0xFF4A6872)),
    SwatchItem('Peacock', Color(0xFF3F5962)),
    SwatchItem('Blue Spruce', Color(0xFF344C54)),
    SwatchItem('Deep Teal', Color(0xFF2A4048)),
    SwatchItem('Midnight Teal', Color(0xFF22353D)),
    SwatchItem('Ink Blue', Color(0xFF1A2A31)),
    //Group 7
    SwatchItem('Sage', Color(0xFFA3AE83)),
    SwatchItem('Moss', Color(0xFF8C996A)),
    SwatchItem('Olive', Color(0xFF758355)),
    SwatchItem('Olive Drab', Color(0xFF627046)),
    SwatchItem('Fern Green', Color(0xFF53603B)),
    SwatchItem('Forest Green', Color(0xFF455232)),
    SwatchItem('Pine Green', Color(0xFF384429)),
    SwatchItem('Spruce Green', Color(0xFF2D3722)),
    SwatchItem('Black Forest', Color(0xFF232C1C)),
  ];

  //lightSummer = summer กลางวัน
  static const List<SwatchItem> _lightSummerTops = [
    //Group 1
    SwatchItem('Snow White', Color(0xFFF8F7F3)),
    SwatchItem('Pearl', Color(0xFFF1EEE7)),
    SwatchItem('Soft Ivory', Color(0xFFE7E2D8)),
    SwatchItem('Dove Gray', Color(0xFFD4D0D0)),
    SwatchItem('Silver Gray', Color(0xFFC1BEC5)),
    SwatchItem('Mist Gray', Color(0xFFAAA9B4)),
    SwatchItem('Cool Taupe', Color(0xFF97939A)),
    SwatchItem('Slate Gray', Color(0xFF7E8190)),
    SwatchItem('Blue Gray', Color(0xFF5D748F)),
    //Group 2
    SwatchItem('Blush Beige', Color(0xFFE7D7DC)),
    SwatchItem('Dusty Rose', Color(0xFFD8C0CB)),
    SwatchItem('Mauve Taupe', Color(0xFFBEA3B1)),
    SwatchItem('Ash Mauve', Color(0xFFA78E9D)),
    SwatchItem('Heather', Color(0xFF90798A)),
    SwatchItem('Smoky Plum', Color(0xFF7B6679)),
    SwatchItem('Cocoa Mauve', Color(0xFF675965)),
    SwatchItem('Mulberry Gray', Color(0xFF584B5B)),
    SwatchItem('Deep Mauve', Color(0xFF4B404F)),
    //Group 3
    SwatchItem('Powder Pink', Color(0xFFF4D3D8)),
    SwatchItem('Ballet Pink', Color(0xFFEABBC6)),
    SwatchItem('Rose Pink', Color(0xFFE29CB2)),
    SwatchItem('Cool Rose', Color(0xFFD97D9C)),
    SwatchItem('Pink Coral', Color(0xFFD86489)),
    SwatchItem('Raspberry Pink', Color(0xFFD14D7B)),
    SwatchItem('Berry Pink', Color(0xFFC63D6F)),
    SwatchItem('Cerise', Color(0xFFB83369)),
    SwatchItem('Cranberry', Color(0xFFA7305E)),
    //Group 4
    SwatchItem('Petal Pink', Color(0xFFF0B3B8)),
    SwatchItem('Watermelon', Color(0xFFEA8F99)),
    SwatchItem('Rose Red', Color(0xFFE16E7E)),
    SwatchItem('Summer Rose', Color(0xFFD9566F)),
    SwatchItem('Raspberry', Color(0xFFCD4965)),
    SwatchItem('Berry Red', Color(0xFFC03E5C)),
    SwatchItem('Carmine', Color(0xFFB33A57)),
    SwatchItem('Wine Rose', Color(0xFFA83A58)),
    SwatchItem('Dusty Burgundy', Color(0xFF97384F)),
    //Group 5
    SwatchItem('Vanilla', Color(0xFFF9EDC8)),
    SwatchItem('Buttercream', Color(0xFFF6E3A9)),
    SwatchItem('Primrose', Color(0xFFF3DA8A)),
    SwatchItem('Soft Lemon', Color(0xFFF2D56F)),
    SwatchItem('Straw Yellow', Color(0xFFEFCF61)),
    SwatchItem('Light Gold', Color(0xFFE7C55B)),
    SwatchItem('Honey Cream', Color(0xFFDDBB56)),
    SwatchItem('Pale Wheat', Color(0xFFD2AE53)),
    SwatchItem('Soft Mustard', Color(0xFFC4A24D)),
    //Group 6
    SwatchItem('Seafoam', Color(0xFFAEE4D5)),
    SwatchItem('Mint Aqua', Color(0xFF89DACD)),
    SwatchItem('Aqua', Color(0xFF66CFCA)),
    SwatchItem('Turquoise', Color(0xFF49C2C2)),
    SwatchItem('Lagoon', Color(0xFF3CB0B3)),
    SwatchItem('Soft Teal', Color(0xFF339EA1)),
    SwatchItem('Ocean Teal', Color(0xFF2C8B8D)),
    SwatchItem('Deep Teal', Color(0xFF34797A)),
    SwatchItem('Smoky Teal', Color(0xFF496F6C)),
    //Group 7
    SwatchItem('Ice Blue', Color(0xFFD8E6F6)),
    SwatchItem('Powder Blue', Color(0xFFBFD8F2)),
    SwatchItem('Sky Blue', Color(0xFFA6CAF0)),
    SwatchItem('Cornflower', Color(0xFF86B3EA)),
    SwatchItem('Periwinkle', Color(0xFF788FD9)),
    SwatchItem('Blue Violet', Color(0xFF6978C7)),
    SwatchItem('Lavender', Color(0xFF8D86D0)),
    SwatchItem('Soft Violet', Color(0xFF7667B6)),
    SwatchItem('Smoky Purple', Color(0xFF5D4F93)),
  ];

  //trueSummer = summer กลางคืน
  static const List<SwatchItem> _trueSummerTops = [
    //Group 1
    SwatchItem('Soft White', Color(0xFFF7F7F5)),
    SwatchItem('Pearl', Color(0xFFEEEDE7)),
    SwatchItem('Silver', Color(0xFFE0E1DF)),
    SwatchItem('Light Gray', Color(0xFFD0D0D2)),
    SwatchItem('Cool Gray', Color(0xFFB9BEC2)),
    SwatchItem('Slate Gray', Color(0xFF9FA8B0)),
    SwatchItem('Steel Gray', Color(0xFF85919C)),
    SwatchItem('Blue Gray', Color(0xFF6E7D8B)),
    SwatchItem('Charcoal', Color(0xFF53545A)),
    //Group 2
    SwatchItem('Shell Pink', Color(0xFFE8DCDD)),
    SwatchItem('Ash Rose', Color(0xFFD7C9CC)),
    SwatchItem('Mushroom', Color(0xFFC0B4B7)),
    SwatchItem('Taupe', Color(0xFFA89C9E)),
    SwatchItem('Dusty Mauve', Color(0xFF918387)),
    SwatchItem('Heather', Color(0xFF7E7075)),
    SwatchItem('Smoky Plum', Color(0xFF6A5E63)),
    SwatchItem('Mulberry Gray', Color(0xFF594E54)),
    SwatchItem('Espresso Gray', Color(0xFF474047)),
    //Group 3
    SwatchItem('Blush Pink', Color(0xFFE8B8C8)),
    SwatchItem('Ballet Pink', Color(0xFFDFA6BF)),
    SwatchItem('Rose Pink', Color(0xFFD48DAD)),
    SwatchItem('Dusty Rose', Color(0xFFC8789A)),
    SwatchItem('Berry Pink', Color(0xFFBD658A)),
    SwatchItem('Raspberry Rose', Color(0xFFAF577E)),
    SwatchItem('Cranberry', Color(0xFFA04973)),
    SwatchItem('Rosewood', Color(0xFF8D3F63)),
    SwatchItem('Burgundy Rose', Color(0xFF7B3455)),
    //Group 4
    SwatchItem('Lilac', Color(0xFFC7C2E3)),
    SwatchItem('Lavender', Color(0xFFB1ABD8)),
    SwatchItem('Wisteria', Color(0xFF9C95CC)),
    SwatchItem('Periwinkle', Color(0xFF8581BF)),
    SwatchItem('Iris', Color(0xFF706CB0)),
    SwatchItem('Violet', Color(0xFF625A9F)),
    SwatchItem('Plum', Color(0xFF554D8D)),
    SwatchItem('Aubergine', Color(0xFF474179)),
    SwatchItem('Deep Plum', Color(0xFF3C3667)),
    //Group 5
    SwatchItem('Ice Blue', Color(0xFFD4E7F6)),
    SwatchItem('Powder Blue', Color(0xFFBCD9F2)),
    SwatchItem('Sky Blue', Color(0xFFA5C9EB)),
    SwatchItem('Cornflower Blue', Color(0xFF89B5E1)),
    SwatchItem('Denim Blue', Color(0xFF6F9DCE)),
    SwatchItem('Steel Blue', Color(0xFF5B88B8)),
    SwatchItem('Slate Blue', Color(0xFF4B739F)),
    SwatchItem('Cadet Blue', Color(0xFF3E617F)),
    SwatchItem('Navy', Color(0xFF304B65)),
    //Group 6
    SwatchItem('Seafoam', Color(0xFFB7DDD4)),
    SwatchItem('Aqua Mist', Color(0xFF98D1C9)),
    SwatchItem('Aqua', Color(0xFF7CC4BD)),
    SwatchItem('Soft Teal', Color(0xFF61B5AF)),
    SwatchItem('Teal', Color(0xFF4AA19D)),
    SwatchItem('Blue Green', Color(0xFF3B8C89)),
    SwatchItem('Peacock', Color(0xFF337978)),
    SwatchItem('Deep Teal', Color(0xFF2C6767)),
    SwatchItem('Pine Teal', Color(0xFF235455)),
    //Group 7
    SwatchItem('Lemon Cream', Color(0xFFF7F0BF)),
    SwatchItem('Vanilla Cream', Color(0xFFF1E7A8)),
    SwatchItem('Soft Butter', Color(0xFFEAD98D)),
    SwatchItem('Primrose', Color(0xFFE3CC74)),
    SwatchItem('Straw', Color(0xFFD8C162)),
    SwatchItem('Pale Gold', Color(0xFFCBB356)),
    SwatchItem('Antique Gold', Color(0xFFBDA34B)),
    SwatchItem('Olive Gold', Color(0xFFA48D43)),
    SwatchItem('Soft Olive', Color(0xFF8A763C)),
  ];

  //เลือกสีที่ใช้ในช่วงกลางวันและกลางคืนตามฤดูกาล
  static SeasonCore _dayCoreFor(SeasonKey key) {
    switch (key) {
      case SeasonKey.Winter:
        return trueWinter;
      case SeasonKey.Spring:
        return lightSpring;
      case SeasonKey.Autumn:
        return trueAutumn;
      case SeasonKey.Summer:
        return lightSummer;
    }
  }

  static SeasonCore _nightCoreFor(SeasonKey key) {
    switch (key) {
      case SeasonKey.Winter:
        return brightWinter;
      case SeasonKey.Spring:
        return brightSpring;
      case SeasonKey.Autumn:
        return darkAutumn;
      case SeasonKey.Summer:
        return trueSummer;
    }
  }

  static final Map<String, SeasonProfile> _cache = {};

  //Returns season for night
  static SeasonProfile getProfile(SeasonKey key, {bool night = false}) {
    final core = night ? _nightCoreFor(key) : _dayCoreFor(key);
    final cacheKey = '${key.name}_$night';
    return _cache.putIfAbsent(
      cacheKey,
      () => SeasonProfile(
        core: core,
        topsPool: core.curatedTops,
        bottoms: core.curatedBottoms,
        hair: core.curatedHair,
        eyeMakeup: core.curatedEyeMakeup,
        blush: core.curatedBlush,
        lipstick: core.curatedLipstick,
        jewelry: core.curatedJewelry,
      ),
    );
  }

  //Returns season for day
  static SeasonCore coreOf(SeasonKey key) => _dayCoreFor(key);

  //สีseason ที่ใช้ในหน้าจอผลลัพธ์
  static String labelOf(SeasonKey key) => _dayCoreFor(key).displayName;

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

  //Randomly pick colors from the pool
  static List<SwatchItem> pickRandom(
    List<SwatchItem> pool,
    int count, [
    Random? random,
  ]) {
    final r = random ?? Random();
    final shuffled = List<SwatchItem>.from(pool)..shuffle(r);
    return shuffled.take(count).toList();
  }
}
