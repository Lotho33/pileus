import 'dart:math' as math;

/// Height of the backdrop art behind a hero band [bandHeight] tall on a
/// [width]-wide page. On a wide window the band is far wider than 16:9
/// (3:1 on the home, 4:1 on details at 1920×950), so a cover-fit backdrop
/// lost half its height, and its bottom edge sat under the fade too. The art
/// instead keeps up to a 16:9 box and runs on under the first rows, which
/// paint over it (TV and the big streaming apps do the same). Capped at 1.5×
/// the band so a tall window doesn't push the fade far down the page.
double bleedArtHeight(double bandHeight, double width) =>
    math.max(bandHeight, math.min(width * 9 / 16, bandHeight * 1.5));
