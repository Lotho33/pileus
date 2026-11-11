// This is a generated file - do not edit.
//
// Generated from media.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// CatalogItem is the lightweight tile object used in catalog/search/browse.
/// Rich per-type metadata lives in DetailsResponse.details (oneof typed messages).
/// Lua plugins must return JSON with these exact field names.
class CatalogItem extends $pb.GeneratedMessage {
  factory CatalogItem({
    $core.String? id,
    $core.String? title,
    $core.String? mediaType,
    $core.String? posterUrl,
    $core.int? year,
    $core.double? rating,
    $core.bool? isDir,
    $core.String? providerId,
    $core.String? showId,
    $core.String? parentId,
    $core.int? seasonNumber,
    $core.int? episodeNumber,
    $core.String? directStreamUrl,
    $core.bool? isExternal,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? extra,
    $core.String? logoUrl,
    $core.String? bannerUrl,
    LogoMeta? logoMeta,
  }) {
    final result = CatalogItem._();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (mediaType != null) result.mediaType = mediaType;
    if (posterUrl != null) result.posterUrl = posterUrl;
    if (year != null) result.year = year;
    if (rating != null) result.rating = rating;
    if (isDir != null) result.isDir = isDir;
    if (providerId != null) result.providerId = providerId;
    if (showId != null) result.showId = showId;
    if (parentId != null) result.parentId = parentId;
    if (seasonNumber != null) result.seasonNumber = seasonNumber;
    if (episodeNumber != null) result.episodeNumber = episodeNumber;
    if (directStreamUrl != null) result.directStreamUrl = directStreamUrl;
    if (isExternal != null) result.isExternal = isExternal;
    if (extra != null) result.extra.addEntries(extra);
    if (logoUrl != null) result.logoUrl = logoUrl;
    if (bannerUrl != null) result.bannerUrl = bannerUrl;
    if (logoMeta != null) result.logoMeta = logoMeta;
    return result;
  }

  CatalogItem._();

  factory CatalogItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CatalogItem()..mergeFromBuffer(data, registry);
  factory CatalogItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CatalogItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CatalogItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: CatalogItem.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'mediaType')
    ..aOS(4, _omitFieldNames ? '' : 'posterUrl')
    ..aI(5, _omitFieldNames ? '' : 'year')
    ..aD(6, _omitFieldNames ? '' : 'rating')
    ..aOB(7, _omitFieldNames ? '' : 'isDir')
    ..aOS(8, _omitFieldNames ? '' : 'providerId')
    ..aOS(9, _omitFieldNames ? '' : 'showId')
    ..aOS(10, _omitFieldNames ? '' : 'parentId')
    ..aI(11, _omitFieldNames ? '' : 'seasonNumber')
    ..aI(12, _omitFieldNames ? '' : 'episodeNumber')
    ..aOS(13, _omitFieldNames ? '' : 'directStreamUrl')
    ..aOB(14, _omitFieldNames ? '' : 'isExternal')
    ..m<$core.String, $core.String>(15, _omitFieldNames ? '' : 'extra',
        entryClassName: 'CatalogItem.ExtraEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('mycelium'))
    ..aOS(16, _omitFieldNames ? '' : 'logoUrl')
    ..aOS(17, _omitFieldNames ? '' : 'bannerUrl')
    ..aOM<LogoMeta>(18, _omitFieldNames ? '' : 'logoMeta',
        subBuilder: LogoMeta.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CatalogItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CatalogItem copyWith(void Function(CatalogItem) updates) =>
      super.copyWith((message) => updates(message as CatalogItem))
          as CatalogItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CatalogItem() / CatalogItem.new instead')
  static CatalogItem create() => CatalogItem._();
  static $pb.GeneratedMessage $_createMessage() => CatalogItem._();
  @$core.override
  CatalogItem createEmptyInstance() => CatalogItem._();
  @$core.pragma('dart2js:noInline')
  static CatalogItem getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CatalogItem>(
          CatalogItem.$_createMessage);
  static CatalogItem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// media_type: "movie"|"series"|"episode"|"live"|"music"|"podcast"|"video"
  @$pb.TagNumber(3)
  $core.String get mediaType => $_getSZ(2);
  @$pb.TagNumber(3)
  set mediaType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMediaType() => $_has(2);
  @$pb.TagNumber(3)
  void clearMediaType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get posterUrl => $_getSZ(3);
  @$pb.TagNumber(4)
  set posterUrl($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPosterUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearPosterUrl() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get year => $_getIZ(4);
  @$pb.TagNumber(5)
  set year($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasYear() => $_has(4);
  @$pb.TagNumber(5)
  void clearYear() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get rating => $_getN(5);
  @$pb.TagNumber(6)
  set rating($core.double value) => $_setDouble(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRating() => $_has(5);
  @$pb.TagNumber(6)
  void clearRating() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get isDir => $_getBF(6);
  @$pb.TagNumber(7)
  set isDir($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIsDir() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsDir() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get providerId => $_getSZ(7);
  @$pb.TagNumber(8)
  set providerId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasProviderId() => $_has(7);
  @$pb.TagNumber(8)
  void clearProviderId() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get showId => $_getSZ(8);
  @$pb.TagNumber(9)
  set showId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasShowId() => $_has(8);
  @$pb.TagNumber(9)
  void clearShowId() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get parentId => $_getSZ(9);
  @$pb.TagNumber(10)
  set parentId($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasParentId() => $_has(9);
  @$pb.TagNumber(10)
  void clearParentId() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get seasonNumber => $_getIZ(10);
  @$pb.TagNumber(11)
  set seasonNumber($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasSeasonNumber() => $_has(10);
  @$pb.TagNumber(11)
  void clearSeasonNumber() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get episodeNumber => $_getIZ(11);
  @$pb.TagNumber(12)
  set episodeNumber($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasEpisodeNumber() => $_has(11);
  @$pb.TagNumber(12)
  void clearEpisodeNumber() => $_clearField(12);

  /// direct play without resolve step:
  @$pb.TagNumber(13)
  $core.String get directStreamUrl => $_getSZ(12);
  @$pb.TagNumber(13)
  set directStreamUrl($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasDirectStreamUrl() => $_has(12);
  @$pb.TagNumber(13)
  void clearDirectStreamUrl() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.bool get isExternal => $_getBF(13);
  @$pb.TagNumber(14)
  set isExternal($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasIsExternal() => $_has(13);
  @$pb.TagNumber(14)
  void clearIsExternal() => $_clearField(14);

  /// escape hatch for plugin-specific edge cases — NOT for structured data:
  @$pb.TagNumber(15)
  $pb.PbMap<$core.String, $core.String> get extra => $_getMap(14);

  /// logo_url: transparent PNG/SVG wordmark of the title
  @$pb.TagNumber(16)
  $core.String get logoUrl => $_getSZ(15);
  @$pb.TagNumber(16)
  set logoUrl($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasLogoUrl() => $_has(15);
  @$pb.TagNumber(16)
  void clearLogoUrl() => $_clearField(16);

  /// banner_url: wide landscape image (banner-mode)
  @$pb.TagNumber(17)
  $core.String get bannerUrl => $_getSZ(16);
  @$pb.TagNumber(17)
  set bannerUrl($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasBannerUrl() => $_has(16);
  @$pb.TagNumber(17)
  void clearBannerUrl() => $_clearField(17);

  /// Set by the core, never by plugins: see LogoMeta.
  @$pb.TagNumber(18)
  LogoMeta get logoMeta => $_getN(17);
  @$pb.TagNumber(18)
  set logoMeta(LogoMeta value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasLogoMeta() => $_has(17);
  @$pb.TagNumber(18)
  void clearLogoMeta() => $_clearField(18);
  @$pb.TagNumber(18)
  LogoMeta ensureLogoMeta() => $_ensure(17);
}

/// LogoMeta describes a logo_url image, measured by the core the first time
/// the URL goes out (in the background: until then the field is unset, and a
/// later response carries it). Clients use it to decide whether the logo
/// needs a halo to read on the background they draw it on.
/// Luminance values are WCAG relative luminance, 0 (black) to 1 (white), of
/// the logo's visible pixels (alpha >= 50%).
class LogoMeta extends $pb.GeneratedMessage {
  factory LogoMeta({
    $core.int? width,
    $core.int? height,
    $core.double? lumLow,
    $core.double? lumMid,
    $core.double? lumHigh,
    $core.double? darkShare,
    $core.double? lightShare,
    $core.double? coverage,
    $core.int? color,
    $core.String? halo,
  }) {
    final result = LogoMeta._();
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (lumLow != null) result.lumLow = lumLow;
    if (lumMid != null) result.lumMid = lumMid;
    if (lumHigh != null) result.lumHigh = lumHigh;
    if (darkShare != null) result.darkShare = darkShare;
    if (lightShare != null) result.lightShare = lightShare;
    if (coverage != null) result.coverage = coverage;
    if (color != null) result.color = color;
    if (halo != null) result.halo = halo;
    return result;
  }

  LogoMeta._();

  factory LogoMeta.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LogoMeta()..mergeFromBuffer(data, registry);
  factory LogoMeta.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LogoMeta()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogoMeta',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: LogoMeta.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'width')
    ..aI(2, _omitFieldNames ? '' : 'height')
    ..aD(3, _omitFieldNames ? '' : 'lumLow', fieldType: $pb.PbFieldType.OF)
    ..aD(4, _omitFieldNames ? '' : 'lumMid', fieldType: $pb.PbFieldType.OF)
    ..aD(5, _omitFieldNames ? '' : 'lumHigh', fieldType: $pb.PbFieldType.OF)
    ..aD(6, _omitFieldNames ? '' : 'darkShare', fieldType: $pb.PbFieldType.OF)
    ..aD(7, _omitFieldNames ? '' : 'lightShare', fieldType: $pb.PbFieldType.OF)
    ..aD(8, _omitFieldNames ? '' : 'coverage', fieldType: $pb.PbFieldType.OF)
    ..aI(9, _omitFieldNames ? '' : 'color', fieldType: $pb.PbFieldType.OU3)
    ..aOS(10, _omitFieldNames ? '' : 'halo')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogoMeta clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogoMeta copyWith(void Function(LogoMeta) updates) =>
      super.copyWith((message) => updates(message as LogoMeta)) as LogoMeta;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LogoMeta() / LogoMeta.new instead')
  static LogoMeta create() => LogoMeta._();
  static $pb.GeneratedMessage $_createMessage() => LogoMeta._();
  @$core.override
  LogoMeta createEmptyInstance() => LogoMeta._();
  @$core.pragma('dart2js:noInline')
  static LogoMeta getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LogoMeta>(LogoMeta.$_createMessage);
  static LogoMeta? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get width => $_getIZ(0);
  @$pb.TagNumber(1)
  set width($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWidth() => $_has(0);
  @$pb.TagNumber(1)
  void clearWidth() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get height => $_getIZ(1);
  @$pb.TagNumber(2)
  set height($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeight() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get lumLow => $_getN(2);
  @$pb.TagNumber(3)
  set lumLow($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLumLow() => $_has(2);
  @$pb.TagNumber(3)
  void clearLumLow() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get lumMid => $_getN(3);
  @$pb.TagNumber(4)
  set lumMid($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLumMid() => $_has(3);
  @$pb.TagNumber(4)
  void clearLumMid() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get lumHigh => $_getN(4);
  @$pb.TagNumber(5)
  set lumHigh($core.double value) => $_setFloat(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLumHigh() => $_has(4);
  @$pb.TagNumber(5)
  void clearLumHigh() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get darkShare => $_getN(5);
  @$pb.TagNumber(6)
  set darkShare($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDarkShare() => $_has(5);
  @$pb.TagNumber(6)
  void clearDarkShare() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.double get lightShare => $_getN(6);
  @$pb.TagNumber(7)
  set lightShare($core.double value) => $_setFloat(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLightShare() => $_has(6);
  @$pb.TagNumber(7)
  void clearLightShare() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get coverage => $_getN(7);
  @$pb.TagNumber(8)
  set coverage($core.double value) => $_setFloat(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCoverage() => $_has(7);
  @$pb.TagNumber(8)
  void clearCoverage() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get color => $_getIZ(8);
  @$pb.TagNumber(9)
  set color($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasColor() => $_has(8);
  @$pb.TagNumber(9)
  void clearColor() => $_clearField(9);

  /// halo suggested for a dark background: "" (none) or "light". A client
  /// drawing on a light background decides from the values above instead.
  @$pb.TagNumber(10)
  $core.String get halo => $_getSZ(9);
  @$pb.TagNumber(10)
  set halo($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasHalo() => $_has(9);
  @$pb.TagNumber(10)
  void clearHalo() => $_clearField(10);
}

/// EpisodeInfo is the rich episode object returned when browsing a season.
class EpisodeInfo extends $pb.GeneratedMessage {
  factory EpisodeInfo({
    $core.String? id,
    $core.String? title,
    $core.int? episodeNumber,
    $core.int? seasonNumber,
    $core.String? thumbnailUrl,
    $core.String? airDate,
    $core.int? duration,
    $core.double? vote,
    $core.String? plot,
    $core.String? showId,
    $core.String? parentId,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? extra,
  }) {
    final result = EpisodeInfo._();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (episodeNumber != null) result.episodeNumber = episodeNumber;
    if (seasonNumber != null) result.seasonNumber = seasonNumber;
    if (thumbnailUrl != null) result.thumbnailUrl = thumbnailUrl;
    if (airDate != null) result.airDate = airDate;
    if (duration != null) result.duration = duration;
    if (vote != null) result.vote = vote;
    if (plot != null) result.plot = plot;
    if (showId != null) result.showId = showId;
    if (parentId != null) result.parentId = parentId;
    if (extra != null) result.extra.addEntries(extra);
    return result;
  }

  EpisodeInfo._();

  factory EpisodeInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EpisodeInfo()..mergeFromBuffer(data, registry);
  factory EpisodeInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EpisodeInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EpisodeInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: EpisodeInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aI(3, _omitFieldNames ? '' : 'episodeNumber')
    ..aI(4, _omitFieldNames ? '' : 'seasonNumber')
    ..aOS(5, _omitFieldNames ? '' : 'thumbnailUrl')
    ..aOS(6, _omitFieldNames ? '' : 'airDate')
    ..aI(7, _omitFieldNames ? '' : 'duration')
    ..aD(8, _omitFieldNames ? '' : 'vote')
    ..aOS(9, _omitFieldNames ? '' : 'plot')
    ..aOS(10, _omitFieldNames ? '' : 'showId')
    ..aOS(11, _omitFieldNames ? '' : 'parentId')
    ..m<$core.String, $core.String>(12, _omitFieldNames ? '' : 'extra',
        entryClassName: 'EpisodeInfo.ExtraEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('mycelium'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpisodeInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpisodeInfo copyWith(void Function(EpisodeInfo) updates) =>
      super.copyWith((message) => updates(message as EpisodeInfo))
          as EpisodeInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EpisodeInfo() / EpisodeInfo.new instead')
  static EpisodeInfo create() => EpisodeInfo._();
  static $pb.GeneratedMessage $_createMessage() => EpisodeInfo._();
  @$core.override
  EpisodeInfo createEmptyInstance() => EpisodeInfo._();
  @$core.pragma('dart2js:noInline')
  static EpisodeInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EpisodeInfo>(
          EpisodeInfo.$_createMessage);
  static EpisodeInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get episodeNumber => $_getIZ(2);
  @$pb.TagNumber(3)
  set episodeNumber($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEpisodeNumber() => $_has(2);
  @$pb.TagNumber(3)
  void clearEpisodeNumber() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get seasonNumber => $_getIZ(3);
  @$pb.TagNumber(4)
  set seasonNumber($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSeasonNumber() => $_has(3);
  @$pb.TagNumber(4)
  void clearSeasonNumber() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get thumbnailUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set thumbnailUrl($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasThumbnailUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearThumbnailUrl() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get airDate => $_getSZ(5);
  @$pb.TagNumber(6)
  set airDate($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAirDate() => $_has(5);
  @$pb.TagNumber(6)
  void clearAirDate() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get duration => $_getIZ(6);
  @$pb.TagNumber(7)
  set duration($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDuration() => $_has(6);
  @$pb.TagNumber(7)
  void clearDuration() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get vote => $_getN(7);
  @$pb.TagNumber(8)
  set vote($core.double value) => $_setDouble(7, value);
  @$pb.TagNumber(8)
  $core.bool hasVote() => $_has(7);
  @$pb.TagNumber(8)
  void clearVote() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get plot => $_getSZ(8);
  @$pb.TagNumber(9)
  set plot($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPlot() => $_has(8);
  @$pb.TagNumber(9)
  void clearPlot() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get showId => $_getSZ(9);
  @$pb.TagNumber(10)
  set showId($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasShowId() => $_has(9);
  @$pb.TagNumber(10)
  void clearShowId() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get parentId => $_getSZ(10);
  @$pb.TagNumber(11)
  set parentId($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasParentId() => $_has(10);
  @$pb.TagNumber(11)
  void clearParentId() => $_clearField(11);

  /// Same convention as CatalogItem.extra. "lang": the language versions of
  /// this episode — "" / "both" (nothing to flag), "ita", "jap", "eng".
  @$pb.TagNumber(12)
  $pb.PbMap<$core.String, $core.String> get extra => $_getMap(11);
}

/// SeasonInfo lives inside SeriesDetails.
class SeasonInfo extends $pb.GeneratedMessage {
  factory SeasonInfo({
    $core.int? number,
    $core.String? label,
    $core.String? directoryId,
    $core.String? posterUrl,
    $core.int? year,
    $core.int? episodeCount,
    $core.String? overview,
    $core.String? airDate,
  }) {
    final result = SeasonInfo._();
    if (number != null) result.number = number;
    if (label != null) result.label = label;
    if (directoryId != null) result.directoryId = directoryId;
    if (posterUrl != null) result.posterUrl = posterUrl;
    if (year != null) result.year = year;
    if (episodeCount != null) result.episodeCount = episodeCount;
    if (overview != null) result.overview = overview;
    if (airDate != null) result.airDate = airDate;
    return result;
  }

  SeasonInfo._();

  factory SeasonInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonInfo()..mergeFromBuffer(data, registry);
  factory SeasonInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SeasonInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: SeasonInfo.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'number')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOS(3, _omitFieldNames ? '' : 'directoryId')
    ..aOS(4, _omitFieldNames ? '' : 'posterUrl')
    ..aI(5, _omitFieldNames ? '' : 'year')
    ..aI(6, _omitFieldNames ? '' : 'episodeCount')
    ..aOS(7, _omitFieldNames ? '' : 'overview')
    ..aOS(8, _omitFieldNames ? '' : 'airDate')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonInfo copyWith(void Function(SeasonInfo) updates) =>
      super.copyWith((message) => updates(message as SeasonInfo)) as SeasonInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SeasonInfo() / SeasonInfo.new instead')
  static SeasonInfo create() => SeasonInfo._();
  static $pb.GeneratedMessage $_createMessage() => SeasonInfo._();
  @$core.override
  SeasonInfo createEmptyInstance() => SeasonInfo._();
  @$core.pragma('dart2js:noInline')
  static SeasonInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SeasonInfo>(SeasonInfo.$_createMessage);
  static SeasonInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get number => $_getIZ(0);
  @$pb.TagNumber(1)
  set number($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNumber() => $_has(0);
  @$pb.TagNumber(1)
  void clearNumber() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get directoryId => $_getSZ(2);
  @$pb.TagNumber(3)
  set directoryId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDirectoryId() => $_has(2);
  @$pb.TagNumber(3)
  void clearDirectoryId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get posterUrl => $_getSZ(3);
  @$pb.TagNumber(4)
  set posterUrl($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPosterUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearPosterUrl() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get year => $_getIZ(4);
  @$pb.TagNumber(5)
  set year($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasYear() => $_has(4);
  @$pb.TagNumber(5)
  void clearYear() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get episodeCount => $_getIZ(5);
  @$pb.TagNumber(6)
  set episodeCount($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEpisodeCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearEpisodeCount() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get overview => $_getSZ(6);
  @$pb.TagNumber(7)
  set overview($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasOverview() => $_has(6);
  @$pb.TagNumber(7)
  void clearOverview() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get airDate => $_getSZ(7);
  @$pb.TagNumber(8)
  set airDate($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAirDate() => $_has(7);
  @$pb.TagNumber(8)
  void clearAirDate() => $_clearField(8);
}

class CatalogRequest extends $pb.GeneratedMessage {
  factory CatalogRequest({
    $core.String? pluginId,
    $core.String? catalogId,
    $core.int? page,
  }) {
    final result = CatalogRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    if (catalogId != null) result.catalogId = catalogId;
    if (page != null) result.page = page;
    return result;
  }

  CatalogRequest._();

  factory CatalogRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CatalogRequest()..mergeFromBuffer(data, registry);
  factory CatalogRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CatalogRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CatalogRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: CatalogRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'catalogId')
    ..aI(3, _omitFieldNames ? '' : 'page')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CatalogRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CatalogRequest copyWith(void Function(CatalogRequest) updates) =>
      super.copyWith((message) => updates(message as CatalogRequest))
          as CatalogRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CatalogRequest() / CatalogRequest.new instead')
  static CatalogRequest create() => CatalogRequest._();
  static $pb.GeneratedMessage $_createMessage() => CatalogRequest._();
  @$core.override
  CatalogRequest createEmptyInstance() => CatalogRequest._();
  @$core.pragma('dart2js:noInline')
  static CatalogRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CatalogRequest>(
          CatalogRequest.$_createMessage);
  static CatalogRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get catalogId => $_getSZ(1);
  @$pb.TagNumber(2)
  set catalogId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCatalogId() => $_has(1);
  @$pb.TagNumber(2)
  void clearCatalogId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get page => $_getIZ(2);
  @$pb.TagNumber(3)
  set page($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPage() => $_has(2);
  @$pb.TagNumber(3)
  void clearPage() => $_clearField(3);
}

class CatalogResponse extends $pb.GeneratedMessage {
  factory CatalogResponse({
    $core.Iterable<CatalogItem>? items,
    $core.bool? hasMore,
  }) {
    final result = CatalogResponse._();
    if (items != null) result.items.addAll(items);
    if (hasMore != null) result.hasMore = hasMore;
    return result;
  }

  CatalogResponse._();

  factory CatalogResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CatalogResponse()..mergeFromBuffer(data, registry);
  factory CatalogResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CatalogResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CatalogResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: CatalogResponse.$_createMessage)
    ..pPM<CatalogItem>(1, _omitFieldNames ? '' : 'items',
        subBuilder: CatalogItem.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'hasMore')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CatalogResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CatalogResponse copyWith(void Function(CatalogResponse) updates) =>
      super.copyWith((message) => updates(message as CatalogResponse))
          as CatalogResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CatalogResponse() / CatalogResponse.new instead')
  static CatalogResponse create() => CatalogResponse._();
  static $pb.GeneratedMessage $_createMessage() => CatalogResponse._();
  @$core.override
  CatalogResponse createEmptyInstance() => CatalogResponse._();
  @$core.pragma('dart2js:noInline')
  static CatalogResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CatalogResponse>(
          CatalogResponse.$_createMessage);
  static CatalogResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<CatalogItem> get items => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get hasMore => $_getBF(1);
  @$pb.TagNumber(2)
  set hasMore($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHasMore() => $_has(1);
  @$pb.TagNumber(2)
  void clearHasMore() => $_clearField(2);
}

class SearchFilter extends $pb.GeneratedMessage {
  factory SearchFilter({
    $core.String? id,
    $core.String? label,
    $core.String? type,
    $core.Iterable<FilterOption>? options,
  }) {
    final result = SearchFilter._();
    if (id != null) result.id = id;
    if (label != null) result.label = label;
    if (type != null) result.type = type;
    if (options != null) result.options.addAll(options);
    return result;
  }

  SearchFilter._();

  factory SearchFilter.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SearchFilter()..mergeFromBuffer(data, registry);
  factory SearchFilter.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SearchFilter()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchFilter',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: SearchFilter.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOS(3, _omitFieldNames ? '' : 'type')
    ..pPM<FilterOption>(4, _omitFieldNames ? '' : 'options',
        subBuilder: FilterOption.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchFilter clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchFilter copyWith(void Function(SearchFilter) updates) =>
      super.copyWith((message) => updates(message as SearchFilter))
          as SearchFilter;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SearchFilter() / SearchFilter.new instead')
  static SearchFilter create() => SearchFilter._();
  static $pb.GeneratedMessage $_createMessage() => SearchFilter._();
  @$core.override
  SearchFilter createEmptyInstance() => SearchFilter._();
  @$core.pragma('dart2js:noInline')
  static SearchFilter getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SearchFilter>(
          SearchFilter.$_createMessage);
  static SearchFilter? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  /// type:
  ///   "select"      one option id, sent as filters[id] = "<optId>"
  ///   "multiselect" zero+ option ids, sent comma-joined: filters[id] = "a,b,c"
  ///   "range"       numeric interval; `options` carries {id:"min"|"max"|"step"}
  ///                 bounds (step optional, default 1). Sent as
  ///                 filters[id] = "<lo>..<hi>"; either side may be empty
  ///                 ("2000..", "..2015"). Absent key = no constraint.
  ///   "bool"        filters[id] = "true" | "false"
  ///   "number"      one integer, sent as filters[id] = "<n>"
  /// (filters stays map<string,string> on the wire — see SearchRequest.)
  @$pb.TagNumber(3)
  $core.String get type => $_getSZ(2);
  @$pb.TagNumber(3)
  set type($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<FilterOption> get options => $_getList(3);
}

class FilterOption extends $pb.GeneratedMessage {
  factory FilterOption({
    $core.String? id,
    $core.String? label,
  }) {
    final result = FilterOption._();
    if (id != null) result.id = id;
    if (label != null) result.label = label;
    return result;
  }

  FilterOption._();

  factory FilterOption.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FilterOption()..mergeFromBuffer(data, registry);
  factory FilterOption.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FilterOption()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FilterOption',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: FilterOption.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterOption clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterOption copyWith(void Function(FilterOption) updates) =>
      super.copyWith((message) => updates(message as FilterOption))
          as FilterOption;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FilterOption() / FilterOption.new instead')
  static FilterOption create() => FilterOption._();
  static $pb.GeneratedMessage $_createMessage() => FilterOption._();
  @$core.override
  FilterOption createEmptyInstance() => FilterOption._();
  @$core.pragma('dart2js:noInline')
  static FilterOption getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FilterOption>(
          FilterOption.$_createMessage);
  static FilterOption? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);
}

class SearchFiltersRequest extends $pb.GeneratedMessage {
  factory SearchFiltersRequest({
    $core.String? pluginId,
  }) {
    final result = SearchFiltersRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    return result;
  }

  SearchFiltersRequest._();

  factory SearchFiltersRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SearchFiltersRequest()..mergeFromBuffer(data, registry);
  factory SearchFiltersRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SearchFiltersRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchFiltersRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: SearchFiltersRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchFiltersRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchFiltersRequest copyWith(void Function(SearchFiltersRequest) updates) =>
      super.copyWith((message) => updates(message as SearchFiltersRequest))
          as SearchFiltersRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SearchFiltersRequest() / SearchFiltersRequest.new instead')
  static SearchFiltersRequest create() => SearchFiltersRequest._();
  static $pb.GeneratedMessage $_createMessage() => SearchFiltersRequest._();
  @$core.override
  SearchFiltersRequest createEmptyInstance() => SearchFiltersRequest._();
  @$core.pragma('dart2js:noInline')
  static SearchFiltersRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchFiltersRequest>(
          SearchFiltersRequest.$_createMessage);
  static SearchFiltersRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);
}

class SearchFiltersResponse extends $pb.GeneratedMessage {
  factory SearchFiltersResponse({
    $core.Iterable<SearchFilter>? filters,
  }) {
    final result = SearchFiltersResponse._();
    if (filters != null) result.filters.addAll(filters);
    return result;
  }

  SearchFiltersResponse._();

  factory SearchFiltersResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SearchFiltersResponse()..mergeFromBuffer(data, registry);
  factory SearchFiltersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SearchFiltersResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchFiltersResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: SearchFiltersResponse.$_createMessage)
    ..pPM<SearchFilter>(1, _omitFieldNames ? '' : 'filters',
        subBuilder: SearchFilter.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchFiltersResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchFiltersResponse copyWith(
          void Function(SearchFiltersResponse) updates) =>
      super.copyWith((message) => updates(message as SearchFiltersResponse))
          as SearchFiltersResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SearchFiltersResponse() / SearchFiltersResponse.new instead')
  static SearchFiltersResponse create() => SearchFiltersResponse._();
  static $pb.GeneratedMessage $_createMessage() => SearchFiltersResponse._();
  @$core.override
  SearchFiltersResponse createEmptyInstance() => SearchFiltersResponse._();
  @$core.pragma('dart2js:noInline')
  static SearchFiltersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchFiltersResponse>(
          SearchFiltersResponse.$_createMessage);
  static SearchFiltersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SearchFilter> get filters => $_getList(0);
}

class SearchRequest extends $pb.GeneratedMessage {
  factory SearchRequest({
    $core.String? pluginId,
    $core.String? query,
    $core.int? page,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? filters,
  }) {
    final result = SearchRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    if (query != null) result.query = query;
    if (page != null) result.page = page;
    if (filters != null) result.filters.addEntries(filters);
    return result;
  }

  SearchRequest._();

  factory SearchRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SearchRequest()..mergeFromBuffer(data, registry);
  factory SearchRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SearchRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: SearchRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'query')
    ..aI(3, _omitFieldNames ? '' : 'page')
    ..m<$core.String, $core.String>(4, _omitFieldNames ? '' : 'filters',
        entryClassName: 'SearchRequest.FiltersEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('mycelium'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchRequest copyWith(void Function(SearchRequest) updates) =>
      super.copyWith((message) => updates(message as SearchRequest))
          as SearchRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SearchRequest() / SearchRequest.new instead')
  static SearchRequest create() => SearchRequest._();
  static $pb.GeneratedMessage $_createMessage() => SearchRequest._();
  @$core.override
  SearchRequest createEmptyInstance() => SearchRequest._();
  @$core.pragma('dart2js:noInline')
  static SearchRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SearchRequest>(
          SearchRequest.$_createMessage);
  static SearchRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get query => $_getSZ(1);
  @$pb.TagNumber(2)
  set query($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuery() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuery() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get page => $_getIZ(2);
  @$pb.TagNumber(3)
  set page($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPage() => $_has(2);
  @$pb.TagNumber(3)
  void clearPage() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $core.String> get filters => $_getMap(3);
}

class SearchResponse extends $pb.GeneratedMessage {
  factory SearchResponse({
    $core.Iterable<CatalogItem>? items,
    $core.bool? hasMore,
  }) {
    final result = SearchResponse._();
    if (items != null) result.items.addAll(items);
    if (hasMore != null) result.hasMore = hasMore;
    return result;
  }

  SearchResponse._();

  factory SearchResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SearchResponse()..mergeFromBuffer(data, registry);
  factory SearchResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SearchResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: SearchResponse.$_createMessage)
    ..pPM<CatalogItem>(1, _omitFieldNames ? '' : 'items',
        subBuilder: CatalogItem.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'hasMore')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchResponse copyWith(void Function(SearchResponse) updates) =>
      super.copyWith((message) => updates(message as SearchResponse))
          as SearchResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SearchResponse() / SearchResponse.new instead')
  static SearchResponse create() => SearchResponse._();
  static $pb.GeneratedMessage $_createMessage() => SearchResponse._();
  @$core.override
  SearchResponse createEmptyInstance() => SearchResponse._();
  @$core.pragma('dart2js:noInline')
  static SearchResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SearchResponse>(
          SearchResponse.$_createMessage);
  static SearchResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<CatalogItem> get items => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get hasMore => $_getBF(1);
  @$pb.TagNumber(2)
  set hasMore($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHasMore() => $_has(1);
  @$pb.TagNumber(2)
  void clearHasMore() => $_clearField(2);
}

class DetailsRequest extends $pb.GeneratedMessage {
  factory DetailsRequest({
    $core.String? pluginId,
    $core.String? mediaId,
  }) {
    final result = DetailsRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    if (mediaId != null) result.mediaId = mediaId;
    return result;
  }

  DetailsRequest._();

  factory DetailsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DetailsRequest()..mergeFromBuffer(data, registry);
  factory DetailsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DetailsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DetailsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: DetailsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'mediaId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DetailsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DetailsRequest copyWith(void Function(DetailsRequest) updates) =>
      super.copyWith((message) => updates(message as DetailsRequest))
          as DetailsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DetailsRequest() / DetailsRequest.new instead')
  static DetailsRequest create() => DetailsRequest._();
  static $pb.GeneratedMessage $_createMessage() => DetailsRequest._();
  @$core.override
  DetailsRequest createEmptyInstance() => DetailsRequest._();
  @$core.pragma('dart2js:noInline')
  static DetailsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DetailsRequest>(
          DetailsRequest.$_createMessage);
  static DetailsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mediaId => $_getSZ(1);
  @$pb.TagNumber(2)
  set mediaId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaId() => $_clearField(2);
}

class MovieDetails extends $pb.GeneratedMessage {
  factory MovieDetails({
    $core.String? plot,
    $core.int? year,
    $core.Iterable<$core.String>? genres,
    $core.String? runtime,
    $core.Iterable<$core.String>? cast,
    $core.Iterable<$core.String>? directors,
    $core.String? trailerUrl,
    $core.String? released,
    $core.String? tagline,
    $core.String? contentRating,
    $core.String? posterUrl,
    $core.String? fanartUrl,
    $core.String? logoUrl,
    LogoMeta? logoMeta,
  }) {
    final result = MovieDetails._();
    if (plot != null) result.plot = plot;
    if (year != null) result.year = year;
    if (genres != null) result.genres.addAll(genres);
    if (runtime != null) result.runtime = runtime;
    if (cast != null) result.cast.addAll(cast);
    if (directors != null) result.directors.addAll(directors);
    if (trailerUrl != null) result.trailerUrl = trailerUrl;
    if (released != null) result.released = released;
    if (tagline != null) result.tagline = tagline;
    if (contentRating != null) result.contentRating = contentRating;
    if (posterUrl != null) result.posterUrl = posterUrl;
    if (fanartUrl != null) result.fanartUrl = fanartUrl;
    if (logoUrl != null) result.logoUrl = logoUrl;
    if (logoMeta != null) result.logoMeta = logoMeta;
    return result;
  }

  MovieDetails._();

  factory MovieDetails.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MovieDetails()..mergeFromBuffer(data, registry);
  factory MovieDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MovieDetails()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MovieDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: MovieDetails.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'plot')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..pPS(3, _omitFieldNames ? '' : 'genres')
    ..aOS(4, _omitFieldNames ? '' : 'runtime')
    ..pPS(5, _omitFieldNames ? '' : 'cast')
    ..pPS(6, _omitFieldNames ? '' : 'directors')
    ..aOS(7, _omitFieldNames ? '' : 'trailerUrl')
    ..aOS(8, _omitFieldNames ? '' : 'released')
    ..aOS(9, _omitFieldNames ? '' : 'tagline')
    ..aOS(10, _omitFieldNames ? '' : 'contentRating')
    ..aOS(11, _omitFieldNames ? '' : 'posterUrl')
    ..aOS(12, _omitFieldNames ? '' : 'fanartUrl')
    ..aOS(13, _omitFieldNames ? '' : 'logoUrl')
    ..aOM<LogoMeta>(14, _omitFieldNames ? '' : 'logoMeta',
        subBuilder: LogoMeta.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MovieDetails clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MovieDetails copyWith(void Function(MovieDetails) updates) =>
      super.copyWith((message) => updates(message as MovieDetails))
          as MovieDetails;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MovieDetails() / MovieDetails.new instead')
  static MovieDetails create() => MovieDetails._();
  static $pb.GeneratedMessage $_createMessage() => MovieDetails._();
  @$core.override
  MovieDetails createEmptyInstance() => MovieDetails._();
  @$core.pragma('dart2js:noInline')
  static MovieDetails getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MovieDetails>(
          MovieDetails.$_createMessage);
  static MovieDetails? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get plot => $_getSZ(0);
  @$pb.TagNumber(1)
  set plot($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlot() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlot() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get year => $_getIZ(1);
  @$pb.TagNumber(2)
  set year($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasYear() => $_has(1);
  @$pb.TagNumber(2)
  void clearYear() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get genres => $_getList(2);

  @$pb.TagNumber(4)
  $core.String get runtime => $_getSZ(3);
  @$pb.TagNumber(4)
  set runtime($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRuntime() => $_has(3);
  @$pb.TagNumber(4)
  void clearRuntime() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get cast => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get directors => $_getList(5);

  @$pb.TagNumber(7)
  $core.String get trailerUrl => $_getSZ(6);
  @$pb.TagNumber(7)
  set trailerUrl($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTrailerUrl() => $_has(6);
  @$pb.TagNumber(7)
  void clearTrailerUrl() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get released => $_getSZ(7);
  @$pb.TagNumber(8)
  set released($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasReleased() => $_has(7);
  @$pb.TagNumber(8)
  void clearReleased() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get tagline => $_getSZ(8);
  @$pb.TagNumber(9)
  set tagline($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTagline() => $_has(8);
  @$pb.TagNumber(9)
  void clearTagline() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get contentRating => $_getSZ(9);
  @$pb.TagNumber(10)
  set contentRating($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasContentRating() => $_has(9);
  @$pb.TagNumber(10)
  void clearContentRating() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get posterUrl => $_getSZ(10);
  @$pb.TagNumber(11)
  set posterUrl($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasPosterUrl() => $_has(10);
  @$pb.TagNumber(11)
  void clearPosterUrl() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get fanartUrl => $_getSZ(11);
  @$pb.TagNumber(12)
  set fanartUrl($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasFanartUrl() => $_has(11);
  @$pb.TagNumber(12)
  void clearFanartUrl() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get logoUrl => $_getSZ(12);
  @$pb.TagNumber(13)
  set logoUrl($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasLogoUrl() => $_has(12);
  @$pb.TagNumber(13)
  void clearLogoUrl() => $_clearField(13);

  @$pb.TagNumber(14)
  LogoMeta get logoMeta => $_getN(13);
  @$pb.TagNumber(14)
  set logoMeta(LogoMeta value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasLogoMeta() => $_has(13);
  @$pb.TagNumber(14)
  void clearLogoMeta() => $_clearField(14);
  @$pb.TagNumber(14)
  LogoMeta ensureLogoMeta() => $_ensure(13);
}

class SeriesDetails extends $pb.GeneratedMessage {
  factory SeriesDetails({
    $core.String? plot,
    $core.int? year,
    $core.Iterable<$core.String>? genres,
    $core.String? status,
    $core.String? contentRating,
    $core.String? network,
    $core.String? episodeRuntime,
    $core.Iterable<$core.String>? cast,
    $core.Iterable<$core.String>? creators,
    $core.String? trailerUrl,
    $core.String? firstAirDate,
    $core.String? posterUrl,
    $core.String? fanartUrl,
    $core.Iterable<SeasonInfo>? seasons,
    $core.String? logoUrl,
    LogoMeta? logoMeta,
  }) {
    final result = SeriesDetails._();
    if (plot != null) result.plot = plot;
    if (year != null) result.year = year;
    if (genres != null) result.genres.addAll(genres);
    if (status != null) result.status = status;
    if (contentRating != null) result.contentRating = contentRating;
    if (network != null) result.network = network;
    if (episodeRuntime != null) result.episodeRuntime = episodeRuntime;
    if (cast != null) result.cast.addAll(cast);
    if (creators != null) result.creators.addAll(creators);
    if (trailerUrl != null) result.trailerUrl = trailerUrl;
    if (firstAirDate != null) result.firstAirDate = firstAirDate;
    if (posterUrl != null) result.posterUrl = posterUrl;
    if (fanartUrl != null) result.fanartUrl = fanartUrl;
    if (seasons != null) result.seasons.addAll(seasons);
    if (logoUrl != null) result.logoUrl = logoUrl;
    if (logoMeta != null) result.logoMeta = logoMeta;
    return result;
  }

  SeriesDetails._();

  factory SeriesDetails.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeriesDetails()..mergeFromBuffer(data, registry);
  factory SeriesDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeriesDetails()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SeriesDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: SeriesDetails.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'plot')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..pPS(3, _omitFieldNames ? '' : 'genres')
    ..aOS(4, _omitFieldNames ? '' : 'status')
    ..aOS(5, _omitFieldNames ? '' : 'contentRating')
    ..aOS(6, _omitFieldNames ? '' : 'network')
    ..aOS(7, _omitFieldNames ? '' : 'episodeRuntime')
    ..pPS(8, _omitFieldNames ? '' : 'cast')
    ..pPS(9, _omitFieldNames ? '' : 'creators')
    ..aOS(10, _omitFieldNames ? '' : 'trailerUrl')
    ..aOS(11, _omitFieldNames ? '' : 'firstAirDate')
    ..aOS(12, _omitFieldNames ? '' : 'posterUrl')
    ..aOS(13, _omitFieldNames ? '' : 'fanartUrl')
    ..pPM<SeasonInfo>(14, _omitFieldNames ? '' : 'seasons',
        subBuilder: SeasonInfo.$_createMessage)
    ..aOS(15, _omitFieldNames ? '' : 'logoUrl')
    ..aOM<LogoMeta>(16, _omitFieldNames ? '' : 'logoMeta',
        subBuilder: LogoMeta.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeriesDetails clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeriesDetails copyWith(void Function(SeriesDetails) updates) =>
      super.copyWith((message) => updates(message as SeriesDetails))
          as SeriesDetails;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SeriesDetails() / SeriesDetails.new instead')
  static SeriesDetails create() => SeriesDetails._();
  static $pb.GeneratedMessage $_createMessage() => SeriesDetails._();
  @$core.override
  SeriesDetails createEmptyInstance() => SeriesDetails._();
  @$core.pragma('dart2js:noInline')
  static SeriesDetails getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SeriesDetails>(
          SeriesDetails.$_createMessage);
  static SeriesDetails? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get plot => $_getSZ(0);
  @$pb.TagNumber(1)
  set plot($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlot() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlot() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get year => $_getIZ(1);
  @$pb.TagNumber(2)
  set year($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasYear() => $_has(1);
  @$pb.TagNumber(2)
  void clearYear() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get genres => $_getList(2);

  @$pb.TagNumber(4)
  $core.String get status => $_getSZ(3);
  @$pb.TagNumber(4)
  set status($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get contentRating => $_getSZ(4);
  @$pb.TagNumber(5)
  set contentRating($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasContentRating() => $_has(4);
  @$pb.TagNumber(5)
  void clearContentRating() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get network => $_getSZ(5);
  @$pb.TagNumber(6)
  set network($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNetwork() => $_has(5);
  @$pb.TagNumber(6)
  void clearNetwork() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get episodeRuntime => $_getSZ(6);
  @$pb.TagNumber(7)
  set episodeRuntime($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEpisodeRuntime() => $_has(6);
  @$pb.TagNumber(7)
  void clearEpisodeRuntime() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get cast => $_getList(7);

  @$pb.TagNumber(9)
  $pb.PbList<$core.String> get creators => $_getList(8);

  @$pb.TagNumber(10)
  $core.String get trailerUrl => $_getSZ(9);
  @$pb.TagNumber(10)
  set trailerUrl($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTrailerUrl() => $_has(9);
  @$pb.TagNumber(10)
  void clearTrailerUrl() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get firstAirDate => $_getSZ(10);
  @$pb.TagNumber(11)
  set firstAirDate($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasFirstAirDate() => $_has(10);
  @$pb.TagNumber(11)
  void clearFirstAirDate() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get posterUrl => $_getSZ(11);
  @$pb.TagNumber(12)
  set posterUrl($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasPosterUrl() => $_has(11);
  @$pb.TagNumber(12)
  void clearPosterUrl() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get fanartUrl => $_getSZ(12);
  @$pb.TagNumber(13)
  set fanartUrl($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasFanartUrl() => $_has(12);
  @$pb.TagNumber(13)
  void clearFanartUrl() => $_clearField(13);

  @$pb.TagNumber(14)
  $pb.PbList<SeasonInfo> get seasons => $_getList(13);

  @$pb.TagNumber(15)
  $core.String get logoUrl => $_getSZ(14);
  @$pb.TagNumber(15)
  set logoUrl($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasLogoUrl() => $_has(14);
  @$pb.TagNumber(15)
  void clearLogoUrl() => $_clearField(15);

  @$pb.TagNumber(16)
  LogoMeta get logoMeta => $_getN(15);
  @$pb.TagNumber(16)
  set logoMeta(LogoMeta value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasLogoMeta() => $_has(15);
  @$pb.TagNumber(16)
  void clearLogoMeta() => $_clearField(16);
  @$pb.TagNumber(16)
  LogoMeta ensureLogoMeta() => $_ensure(15);
}

class EpisodeDetails extends $pb.GeneratedMessage {
  factory EpisodeDetails({
    $core.String? plot,
    $core.int? year,
    $core.String? thumbnailUrl,
    $core.String? airDate,
    $core.int? duration,
    $core.double? vote,
    $core.int? episodeNumber,
    $core.int? seasonNumber,
    $core.String? showId,
    $core.Iterable<$core.String>? guestStars,
    $core.Iterable<$core.String>? directors,
  }) {
    final result = EpisodeDetails._();
    if (plot != null) result.plot = plot;
    if (year != null) result.year = year;
    if (thumbnailUrl != null) result.thumbnailUrl = thumbnailUrl;
    if (airDate != null) result.airDate = airDate;
    if (duration != null) result.duration = duration;
    if (vote != null) result.vote = vote;
    if (episodeNumber != null) result.episodeNumber = episodeNumber;
    if (seasonNumber != null) result.seasonNumber = seasonNumber;
    if (showId != null) result.showId = showId;
    if (guestStars != null) result.guestStars.addAll(guestStars);
    if (directors != null) result.directors.addAll(directors);
    return result;
  }

  EpisodeDetails._();

  factory EpisodeDetails.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EpisodeDetails()..mergeFromBuffer(data, registry);
  factory EpisodeDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EpisodeDetails()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EpisodeDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: EpisodeDetails.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'plot')
    ..aI(2, _omitFieldNames ? '' : 'year')
    ..aOS(3, _omitFieldNames ? '' : 'thumbnailUrl')
    ..aOS(4, _omitFieldNames ? '' : 'airDate')
    ..aI(5, _omitFieldNames ? '' : 'duration')
    ..aD(6, _omitFieldNames ? '' : 'vote')
    ..aI(7, _omitFieldNames ? '' : 'episodeNumber')
    ..aI(8, _omitFieldNames ? '' : 'seasonNumber')
    ..aOS(9, _omitFieldNames ? '' : 'showId')
    ..pPS(10, _omitFieldNames ? '' : 'guestStars')
    ..pPS(11, _omitFieldNames ? '' : 'directors')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpisodeDetails clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpisodeDetails copyWith(void Function(EpisodeDetails) updates) =>
      super.copyWith((message) => updates(message as EpisodeDetails))
          as EpisodeDetails;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EpisodeDetails() / EpisodeDetails.new instead')
  static EpisodeDetails create() => EpisodeDetails._();
  static $pb.GeneratedMessage $_createMessage() => EpisodeDetails._();
  @$core.override
  EpisodeDetails createEmptyInstance() => EpisodeDetails._();
  @$core.pragma('dart2js:noInline')
  static EpisodeDetails getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EpisodeDetails>(
          EpisodeDetails.$_createMessage);
  static EpisodeDetails? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get plot => $_getSZ(0);
  @$pb.TagNumber(1)
  set plot($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlot() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlot() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get year => $_getIZ(1);
  @$pb.TagNumber(2)
  set year($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasYear() => $_has(1);
  @$pb.TagNumber(2)
  void clearYear() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get thumbnailUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set thumbnailUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasThumbnailUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearThumbnailUrl() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get airDate => $_getSZ(3);
  @$pb.TagNumber(4)
  set airDate($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAirDate() => $_has(3);
  @$pb.TagNumber(4)
  void clearAirDate() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get duration => $_getIZ(4);
  @$pb.TagNumber(5)
  set duration($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDuration() => $_has(4);
  @$pb.TagNumber(5)
  void clearDuration() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get vote => $_getN(5);
  @$pb.TagNumber(6)
  set vote($core.double value) => $_setDouble(5, value);
  @$pb.TagNumber(6)
  $core.bool hasVote() => $_has(5);
  @$pb.TagNumber(6)
  void clearVote() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get episodeNumber => $_getIZ(6);
  @$pb.TagNumber(7)
  set episodeNumber($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEpisodeNumber() => $_has(6);
  @$pb.TagNumber(7)
  void clearEpisodeNumber() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get seasonNumber => $_getIZ(7);
  @$pb.TagNumber(8)
  set seasonNumber($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSeasonNumber() => $_has(7);
  @$pb.TagNumber(8)
  void clearSeasonNumber() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get showId => $_getSZ(8);
  @$pb.TagNumber(9)
  set showId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasShowId() => $_has(8);
  @$pb.TagNumber(9)
  void clearShowId() => $_clearField(9);

  @$pb.TagNumber(10)
  $pb.PbList<$core.String> get guestStars => $_getList(9);

  @$pb.TagNumber(11)
  $pb.PbList<$core.String> get directors => $_getList(10);
}

class LiveDetails extends $pb.GeneratedMessage {
  factory LiveDetails({
    $core.String? channelName,
    $core.String? channelLogo,
    $core.String? streamStart,
    $core.String? streamEnd,
    $core.String? sportCategory,
    $core.Iterable<$core.String>? teams,
    $core.String? competition,
    $core.bool? isReplay,
  }) {
    final result = LiveDetails._();
    if (channelName != null) result.channelName = channelName;
    if (channelLogo != null) result.channelLogo = channelLogo;
    if (streamStart != null) result.streamStart = streamStart;
    if (streamEnd != null) result.streamEnd = streamEnd;
    if (sportCategory != null) result.sportCategory = sportCategory;
    if (teams != null) result.teams.addAll(teams);
    if (competition != null) result.competition = competition;
    if (isReplay != null) result.isReplay = isReplay;
    return result;
  }

  LiveDetails._();

  factory LiveDetails.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LiveDetails()..mergeFromBuffer(data, registry);
  factory LiveDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LiveDetails()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LiveDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: LiveDetails.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'channelName')
    ..aOS(2, _omitFieldNames ? '' : 'channelLogo')
    ..aOS(3, _omitFieldNames ? '' : 'streamStart')
    ..aOS(4, _omitFieldNames ? '' : 'streamEnd')
    ..aOS(5, _omitFieldNames ? '' : 'sportCategory')
    ..pPS(6, _omitFieldNames ? '' : 'teams')
    ..aOS(7, _omitFieldNames ? '' : 'competition')
    ..aOB(8, _omitFieldNames ? '' : 'isReplay')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LiveDetails clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LiveDetails copyWith(void Function(LiveDetails) updates) =>
      super.copyWith((message) => updates(message as LiveDetails))
          as LiveDetails;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LiveDetails() / LiveDetails.new instead')
  static LiveDetails create() => LiveDetails._();
  static $pb.GeneratedMessage $_createMessage() => LiveDetails._();
  @$core.override
  LiveDetails createEmptyInstance() => LiveDetails._();
  @$core.pragma('dart2js:noInline')
  static LiveDetails getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LiveDetails>(
          LiveDetails.$_createMessage);
  static LiveDetails? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get channelName => $_getSZ(0);
  @$pb.TagNumber(1)
  set channelName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChannelName() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannelName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get channelLogo => $_getSZ(1);
  @$pb.TagNumber(2)
  set channelLogo($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChannelLogo() => $_has(1);
  @$pb.TagNumber(2)
  void clearChannelLogo() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get streamStart => $_getSZ(2);
  @$pb.TagNumber(3)
  set streamStart($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStreamStart() => $_has(2);
  @$pb.TagNumber(3)
  void clearStreamStart() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get streamEnd => $_getSZ(3);
  @$pb.TagNumber(4)
  set streamEnd($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStreamEnd() => $_has(3);
  @$pb.TagNumber(4)
  void clearStreamEnd() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get sportCategory => $_getSZ(4);
  @$pb.TagNumber(5)
  set sportCategory($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSportCategory() => $_has(4);
  @$pb.TagNumber(5)
  void clearSportCategory() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get teams => $_getList(5);

  @$pb.TagNumber(7)
  $core.String get competition => $_getSZ(6);
  @$pb.TagNumber(7)
  set competition($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCompetition() => $_has(6);
  @$pb.TagNumber(7)
  void clearCompetition() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get isReplay => $_getBF(7);
  @$pb.TagNumber(8)
  set isReplay($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIsReplay() => $_has(7);
  @$pb.TagNumber(8)
  void clearIsReplay() => $_clearField(8);
}

class VideoDetails extends $pb.GeneratedMessage {
  factory VideoDetails({
    $core.String? channelName,
    $core.String? channelUrl,
    $core.String? publishedAt,
    $fixnum.Int64? viewCount,
    $fixnum.Int64? likeCount,
    $core.String? duration,
    $core.Iterable<$core.String>? tags,
  }) {
    final result = VideoDetails._();
    if (channelName != null) result.channelName = channelName;
    if (channelUrl != null) result.channelUrl = channelUrl;
    if (publishedAt != null) result.publishedAt = publishedAt;
    if (viewCount != null) result.viewCount = viewCount;
    if (likeCount != null) result.likeCount = likeCount;
    if (duration != null) result.duration = duration;
    if (tags != null) result.tags.addAll(tags);
    return result;
  }

  VideoDetails._();

  factory VideoDetails.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VideoDetails()..mergeFromBuffer(data, registry);
  factory VideoDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VideoDetails()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VideoDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: VideoDetails.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'channelName')
    ..aOS(2, _omitFieldNames ? '' : 'channelUrl')
    ..aOS(3, _omitFieldNames ? '' : 'publishedAt')
    ..aInt64(4, _omitFieldNames ? '' : 'viewCount')
    ..aInt64(5, _omitFieldNames ? '' : 'likeCount')
    ..aOS(6, _omitFieldNames ? '' : 'duration')
    ..pPS(7, _omitFieldNames ? '' : 'tags')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VideoDetails clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VideoDetails copyWith(void Function(VideoDetails) updates) =>
      super.copyWith((message) => updates(message as VideoDetails))
          as VideoDetails;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use VideoDetails() / VideoDetails.new instead')
  static VideoDetails create() => VideoDetails._();
  static $pb.GeneratedMessage $_createMessage() => VideoDetails._();
  @$core.override
  VideoDetails createEmptyInstance() => VideoDetails._();
  @$core.pragma('dart2js:noInline')
  static VideoDetails getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<VideoDetails>(
          VideoDetails.$_createMessage);
  static VideoDetails? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get channelName => $_getSZ(0);
  @$pb.TagNumber(1)
  set channelName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChannelName() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannelName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get channelUrl => $_getSZ(1);
  @$pb.TagNumber(2)
  set channelUrl($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChannelUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearChannelUrl() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get publishedAt => $_getSZ(2);
  @$pb.TagNumber(3)
  set publishedAt($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPublishedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearPublishedAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get viewCount => $_getI64(3);
  @$pb.TagNumber(4)
  set viewCount($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasViewCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearViewCount() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get likeCount => $_getI64(4);
  @$pb.TagNumber(5)
  set likeCount($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLikeCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearLikeCount() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get duration => $_getSZ(5);
  @$pb.TagNumber(6)
  set duration($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDuration() => $_has(5);
  @$pb.TagNumber(6)
  void clearDuration() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get tags => $_getList(6);
}

class MusicDetails extends $pb.GeneratedMessage {
  factory MusicDetails({
    $core.String? artist,
    $core.String? album,
    $core.String? albumArtUrl,
    $core.String? duration,
    $core.int? trackNumber,
    $core.int? discNumber,
    $core.String? released,
    $core.Iterable<$core.String>? composers,
    $core.Iterable<$core.String>? genres,
    $core.String? lyricsUrl,
  }) {
    final result = MusicDetails._();
    if (artist != null) result.artist = artist;
    if (album != null) result.album = album;
    if (albumArtUrl != null) result.albumArtUrl = albumArtUrl;
    if (duration != null) result.duration = duration;
    if (trackNumber != null) result.trackNumber = trackNumber;
    if (discNumber != null) result.discNumber = discNumber;
    if (released != null) result.released = released;
    if (composers != null) result.composers.addAll(composers);
    if (genres != null) result.genres.addAll(genres);
    if (lyricsUrl != null) result.lyricsUrl = lyricsUrl;
    return result;
  }

  MusicDetails._();

  factory MusicDetails.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MusicDetails()..mergeFromBuffer(data, registry);
  factory MusicDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MusicDetails()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MusicDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: MusicDetails.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'artist')
    ..aOS(2, _omitFieldNames ? '' : 'album')
    ..aOS(3, _omitFieldNames ? '' : 'albumArtUrl')
    ..aOS(4, _omitFieldNames ? '' : 'duration')
    ..aI(5, _omitFieldNames ? '' : 'trackNumber')
    ..aI(6, _omitFieldNames ? '' : 'discNumber')
    ..aOS(7, _omitFieldNames ? '' : 'released')
    ..pPS(8, _omitFieldNames ? '' : 'composers')
    ..pPS(9, _omitFieldNames ? '' : 'genres')
    ..aOS(10, _omitFieldNames ? '' : 'lyricsUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MusicDetails clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MusicDetails copyWith(void Function(MusicDetails) updates) =>
      super.copyWith((message) => updates(message as MusicDetails))
          as MusicDetails;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MusicDetails() / MusicDetails.new instead')
  static MusicDetails create() => MusicDetails._();
  static $pb.GeneratedMessage $_createMessage() => MusicDetails._();
  @$core.override
  MusicDetails createEmptyInstance() => MusicDetails._();
  @$core.pragma('dart2js:noInline')
  static MusicDetails getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MusicDetails>(
          MusicDetails.$_createMessage);
  static MusicDetails? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get artist => $_getSZ(0);
  @$pb.TagNumber(1)
  set artist($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasArtist() => $_has(0);
  @$pb.TagNumber(1)
  void clearArtist() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get album => $_getSZ(1);
  @$pb.TagNumber(2)
  set album($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAlbum() => $_has(1);
  @$pb.TagNumber(2)
  void clearAlbum() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get albumArtUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set albumArtUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAlbumArtUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearAlbumArtUrl() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get duration => $_getSZ(3);
  @$pb.TagNumber(4)
  set duration($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDuration() => $_has(3);
  @$pb.TagNumber(4)
  void clearDuration() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get trackNumber => $_getIZ(4);
  @$pb.TagNumber(5)
  set trackNumber($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTrackNumber() => $_has(4);
  @$pb.TagNumber(5)
  void clearTrackNumber() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get discNumber => $_getIZ(5);
  @$pb.TagNumber(6)
  set discNumber($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDiscNumber() => $_has(5);
  @$pb.TagNumber(6)
  void clearDiscNumber() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get released => $_getSZ(6);
  @$pb.TagNumber(7)
  set released($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasReleased() => $_has(6);
  @$pb.TagNumber(7)
  void clearReleased() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get composers => $_getList(7);

  @$pb.TagNumber(9)
  $pb.PbList<$core.String> get genres => $_getList(8);

  @$pb.TagNumber(10)
  $core.String get lyricsUrl => $_getSZ(9);
  @$pb.TagNumber(10)
  set lyricsUrl($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLyricsUrl() => $_has(9);
  @$pb.TagNumber(10)
  void clearLyricsUrl() => $_clearField(10);
}

class PodcastDetails extends $pb.GeneratedMessage {
  factory PodcastDetails({
    $core.String? showName,
    $core.String? author,
    $core.String? publishedAt,
    $core.String? duration,
    $core.int? episodeNumber,
    $core.int? seasonNumber,
    $core.String? audioUrl,
    $core.Iterable<$core.String>? tags,
  }) {
    final result = PodcastDetails._();
    if (showName != null) result.showName = showName;
    if (author != null) result.author = author;
    if (publishedAt != null) result.publishedAt = publishedAt;
    if (duration != null) result.duration = duration;
    if (episodeNumber != null) result.episodeNumber = episodeNumber;
    if (seasonNumber != null) result.seasonNumber = seasonNumber;
    if (audioUrl != null) result.audioUrl = audioUrl;
    if (tags != null) result.tags.addAll(tags);
    return result;
  }

  PodcastDetails._();

  factory PodcastDetails.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PodcastDetails()..mergeFromBuffer(data, registry);
  factory PodcastDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PodcastDetails()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PodcastDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: PodcastDetails.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'showName')
    ..aOS(2, _omitFieldNames ? '' : 'author')
    ..aOS(3, _omitFieldNames ? '' : 'publishedAt')
    ..aOS(4, _omitFieldNames ? '' : 'duration')
    ..aI(5, _omitFieldNames ? '' : 'episodeNumber')
    ..aI(6, _omitFieldNames ? '' : 'seasonNumber')
    ..aOS(7, _omitFieldNames ? '' : 'audioUrl')
    ..pPS(8, _omitFieldNames ? '' : 'tags')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PodcastDetails clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PodcastDetails copyWith(void Function(PodcastDetails) updates) =>
      super.copyWith((message) => updates(message as PodcastDetails))
          as PodcastDetails;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PodcastDetails() / PodcastDetails.new instead')
  static PodcastDetails create() => PodcastDetails._();
  static $pb.GeneratedMessage $_createMessage() => PodcastDetails._();
  @$core.override
  PodcastDetails createEmptyInstance() => PodcastDetails._();
  @$core.pragma('dart2js:noInline')
  static PodcastDetails getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PodcastDetails>(
          PodcastDetails.$_createMessage);
  static PodcastDetails? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get showName => $_getSZ(0);
  @$pb.TagNumber(1)
  set showName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasShowName() => $_has(0);
  @$pb.TagNumber(1)
  void clearShowName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get author => $_getSZ(1);
  @$pb.TagNumber(2)
  set author($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAuthor() => $_has(1);
  @$pb.TagNumber(2)
  void clearAuthor() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get publishedAt => $_getSZ(2);
  @$pb.TagNumber(3)
  set publishedAt($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPublishedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearPublishedAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get duration => $_getSZ(3);
  @$pb.TagNumber(4)
  set duration($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDuration() => $_has(3);
  @$pb.TagNumber(4)
  void clearDuration() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get episodeNumber => $_getIZ(4);
  @$pb.TagNumber(5)
  set episodeNumber($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEpisodeNumber() => $_has(4);
  @$pb.TagNumber(5)
  void clearEpisodeNumber() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get seasonNumber => $_getIZ(5);
  @$pb.TagNumber(6)
  set seasonNumber($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSeasonNumber() => $_has(5);
  @$pb.TagNumber(6)
  void clearSeasonNumber() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get audioUrl => $_getSZ(6);
  @$pb.TagNumber(7)
  set audioUrl($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAudioUrl() => $_has(6);
  @$pb.TagNumber(7)
  void clearAudioUrl() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get tags => $_getList(7);
}

enum DetailsResponse_Details {
  movie,
  series,
  episode,
  live,
  video,
  music,
  podcast,
  notSet
}

class DetailsResponse extends $pb.GeneratedMessage {
  factory DetailsResponse({
    CatalogItem? item,
    MovieDetails? movie,
    SeriesDetails? series,
    EpisodeDetails? episode,
    LiveDetails? live,
    VideoDetails? video,
    MusicDetails? music,
    PodcastDetails? podcast,
  }) {
    final result = DetailsResponse._();
    if (item != null) result.item = item;
    if (movie != null) result.movie = movie;
    if (series != null) result.series = series;
    if (episode != null) result.episode = episode;
    if (live != null) result.live = live;
    if (video != null) result.video = video;
    if (music != null) result.music = music;
    if (podcast != null) result.podcast = podcast;
    return result;
  }

  DetailsResponse._();

  factory DetailsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DetailsResponse()..mergeFromBuffer(data, registry);
  factory DetailsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DetailsResponse()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, DetailsResponse_Details>
      _DetailsResponse_DetailsByTag = {
    2: DetailsResponse_Details.movie,
    3: DetailsResponse_Details.series,
    4: DetailsResponse_Details.episode,
    5: DetailsResponse_Details.live,
    6: DetailsResponse_Details.video,
    7: DetailsResponse_Details.music,
    8: DetailsResponse_Details.podcast,
    0: DetailsResponse_Details.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DetailsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: DetailsResponse.$_createMessage)
    ..oo(0, [2, 3, 4, 5, 6, 7, 8])
    ..aOM<CatalogItem>(1, _omitFieldNames ? '' : 'item',
        subBuilder: CatalogItem.$_createMessage)
    ..aOM<MovieDetails>(2, _omitFieldNames ? '' : 'movie',
        subBuilder: MovieDetails.$_createMessage)
    ..aOM<SeriesDetails>(3, _omitFieldNames ? '' : 'series',
        subBuilder: SeriesDetails.$_createMessage)
    ..aOM<EpisodeDetails>(4, _omitFieldNames ? '' : 'episode',
        subBuilder: EpisodeDetails.$_createMessage)
    ..aOM<LiveDetails>(5, _omitFieldNames ? '' : 'live',
        subBuilder: LiveDetails.$_createMessage)
    ..aOM<VideoDetails>(6, _omitFieldNames ? '' : 'video',
        subBuilder: VideoDetails.$_createMessage)
    ..aOM<MusicDetails>(7, _omitFieldNames ? '' : 'music',
        subBuilder: MusicDetails.$_createMessage)
    ..aOM<PodcastDetails>(8, _omitFieldNames ? '' : 'podcast',
        subBuilder: PodcastDetails.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DetailsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DetailsResponse copyWith(void Function(DetailsResponse) updates) =>
      super.copyWith((message) => updates(message as DetailsResponse))
          as DetailsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DetailsResponse() / DetailsResponse.new instead')
  static DetailsResponse create() => DetailsResponse._();
  static $pb.GeneratedMessage $_createMessage() => DetailsResponse._();
  @$core.override
  DetailsResponse createEmptyInstance() => DetailsResponse._();
  @$core.pragma('dart2js:noInline')
  static DetailsResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DetailsResponse>(
          DetailsResponse.$_createMessage);
  static DetailsResponse? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  DetailsResponse_Details whichDetails() =>
      _DetailsResponse_DetailsByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  void clearDetails() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  CatalogItem get item => $_getN(0);
  @$pb.TagNumber(1)
  set item(CatalogItem value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasItem() => $_has(0);
  @$pb.TagNumber(1)
  void clearItem() => $_clearField(1);
  @$pb.TagNumber(1)
  CatalogItem ensureItem() => $_ensure(0);

  @$pb.TagNumber(2)
  MovieDetails get movie => $_getN(1);
  @$pb.TagNumber(2)
  set movie(MovieDetails value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasMovie() => $_has(1);
  @$pb.TagNumber(2)
  void clearMovie() => $_clearField(2);
  @$pb.TagNumber(2)
  MovieDetails ensureMovie() => $_ensure(1);

  @$pb.TagNumber(3)
  SeriesDetails get series => $_getN(2);
  @$pb.TagNumber(3)
  set series(SeriesDetails value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSeries() => $_has(2);
  @$pb.TagNumber(3)
  void clearSeries() => $_clearField(3);
  @$pb.TagNumber(3)
  SeriesDetails ensureSeries() => $_ensure(2);

  @$pb.TagNumber(4)
  EpisodeDetails get episode => $_getN(3);
  @$pb.TagNumber(4)
  set episode(EpisodeDetails value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasEpisode() => $_has(3);
  @$pb.TagNumber(4)
  void clearEpisode() => $_clearField(4);
  @$pb.TagNumber(4)
  EpisodeDetails ensureEpisode() => $_ensure(3);

  @$pb.TagNumber(5)
  LiveDetails get live => $_getN(4);
  @$pb.TagNumber(5)
  set live(LiveDetails value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasLive() => $_has(4);
  @$pb.TagNumber(5)
  void clearLive() => $_clearField(5);
  @$pb.TagNumber(5)
  LiveDetails ensureLive() => $_ensure(4);

  @$pb.TagNumber(6)
  VideoDetails get video => $_getN(5);
  @$pb.TagNumber(6)
  set video(VideoDetails value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasVideo() => $_has(5);
  @$pb.TagNumber(6)
  void clearVideo() => $_clearField(6);
  @$pb.TagNumber(6)
  VideoDetails ensureVideo() => $_ensure(5);

  @$pb.TagNumber(7)
  MusicDetails get music => $_getN(6);
  @$pb.TagNumber(7)
  set music(MusicDetails value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasMusic() => $_has(6);
  @$pb.TagNumber(7)
  void clearMusic() => $_clearField(7);
  @$pb.TagNumber(7)
  MusicDetails ensureMusic() => $_ensure(6);

  @$pb.TagNumber(8)
  PodcastDetails get podcast => $_getN(7);
  @$pb.TagNumber(8)
  set podcast(PodcastDetails value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasPodcast() => $_has(7);
  @$pb.TagNumber(8)
  void clearPodcast() => $_clearField(8);
  @$pb.TagNumber(8)
  PodcastDetails ensurePodcast() => $_ensure(7);
}

class BrowseRequest extends $pb.GeneratedMessage {
  factory BrowseRequest({
    $core.String? pluginId,
    $core.String? parentId,
    $core.String? childId,
    $core.int? page,
  }) {
    final result = BrowseRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    if (parentId != null) result.parentId = parentId;
    if (childId != null) result.childId = childId;
    if (page != null) result.page = page;
    return result;
  }

  BrowseRequest._();

  factory BrowseRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BrowseRequest()..mergeFromBuffer(data, registry);
  factory BrowseRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BrowseRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BrowseRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: BrowseRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'parentId')
    ..aOS(3, _omitFieldNames ? '' : 'childId')
    ..aI(4, _omitFieldNames ? '' : 'page')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BrowseRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BrowseRequest copyWith(void Function(BrowseRequest) updates) =>
      super.copyWith((message) => updates(message as BrowseRequest))
          as BrowseRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BrowseRequest() / BrowseRequest.new instead')
  static BrowseRequest create() => BrowseRequest._();
  static $pb.GeneratedMessage $_createMessage() => BrowseRequest._();
  @$core.override
  BrowseRequest createEmptyInstance() => BrowseRequest._();
  @$core.pragma('dart2js:noInline')
  static BrowseRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BrowseRequest>(
          BrowseRequest.$_createMessage);
  static BrowseRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get parentId => $_getSZ(1);
  @$pb.TagNumber(2)
  set parentId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasParentId() => $_has(1);
  @$pb.TagNumber(2)
  void clearParentId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get childId => $_getSZ(2);
  @$pb.TagNumber(3)
  set childId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChildId() => $_has(2);
  @$pb.TagNumber(3)
  void clearChildId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get page => $_getIZ(3);
  @$pb.TagNumber(4)
  set page($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPage() => $_has(3);
  @$pb.TagNumber(4)
  void clearPage() => $_clearField(4);
}

class BrowseResponse extends $pb.GeneratedMessage {
  factory BrowseResponse({
    $core.Iterable<CatalogItem>? items,
    $core.bool? hasMore,
    $core.Iterable<EpisodeInfo>? episodes,
  }) {
    final result = BrowseResponse._();
    if (items != null) result.items.addAll(items);
    if (hasMore != null) result.hasMore = hasMore;
    if (episodes != null) result.episodes.addAll(episodes);
    return result;
  }

  BrowseResponse._();

  factory BrowseResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BrowseResponse()..mergeFromBuffer(data, registry);
  factory BrowseResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BrowseResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BrowseResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: BrowseResponse.$_createMessage)
    ..pPM<CatalogItem>(1, _omitFieldNames ? '' : 'items',
        subBuilder: CatalogItem.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'hasMore')
    ..pPM<EpisodeInfo>(3, _omitFieldNames ? '' : 'episodes',
        subBuilder: EpisodeInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BrowseResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BrowseResponse copyWith(void Function(BrowseResponse) updates) =>
      super.copyWith((message) => updates(message as BrowseResponse))
          as BrowseResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BrowseResponse() / BrowseResponse.new instead')
  static BrowseResponse create() => BrowseResponse._();
  static $pb.GeneratedMessage $_createMessage() => BrowseResponse._();
  @$core.override
  BrowseResponse createEmptyInstance() => BrowseResponse._();
  @$core.pragma('dart2js:noInline')
  static BrowseResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BrowseResponse>(
          BrowseResponse.$_createMessage);
  static BrowseResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<CatalogItem> get items => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get hasMore => $_getBF(1);
  @$pb.TagNumber(2)
  set hasMore($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHasMore() => $_has(1);
  @$pb.TagNumber(2)
  void clearHasMore() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<EpisodeInfo> get episodes => $_getList(2);
}

class StreamSource extends $pb.GeneratedMessage {
  factory StreamSource({
    $core.String? id,
    $core.String? label,
    $core.String? quality,
    $core.bool? isLive,
  }) {
    final result = StreamSource._();
    if (id != null) result.id = id;
    if (label != null) result.label = label;
    if (quality != null) result.quality = quality;
    if (isLive != null) result.isLive = isLive;
    return result;
  }

  StreamSource._();

  factory StreamSource.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StreamSource()..mergeFromBuffer(data, registry);
  factory StreamSource.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StreamSource()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamSource',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: StreamSource.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOS(3, _omitFieldNames ? '' : 'quality')
    ..aOB(4, _omitFieldNames ? '' : 'isLive')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamSource clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamSource copyWith(void Function(StreamSource) updates) =>
      super.copyWith((message) => updates(message as StreamSource))
          as StreamSource;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StreamSource() / StreamSource.new instead')
  static StreamSource create() => StreamSource._();
  static $pb.GeneratedMessage $_createMessage() => StreamSource._();
  @$core.override
  StreamSource createEmptyInstance() => StreamSource._();
  @$core.pragma('dart2js:noInline')
  static StreamSource getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StreamSource>(
          StreamSource.$_createMessage);
  static StreamSource? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get quality => $_getSZ(2);
  @$pb.TagNumber(3)
  set quality($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasQuality() => $_has(2);
  @$pb.TagNumber(3)
  void clearQuality() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isLive => $_getBF(3);
  @$pb.TagNumber(4)
  set isLive($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsLive() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsLive() => $_clearField(4);
}

class StreamsRequest extends $pb.GeneratedMessage {
  factory StreamsRequest({
    $core.String? pluginId,
    $core.String? mediaId,
  }) {
    final result = StreamsRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    if (mediaId != null) result.mediaId = mediaId;
    return result;
  }

  StreamsRequest._();

  factory StreamsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StreamsRequest()..mergeFromBuffer(data, registry);
  factory StreamsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StreamsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: StreamsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'mediaId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamsRequest copyWith(void Function(StreamsRequest) updates) =>
      super.copyWith((message) => updates(message as StreamsRequest))
          as StreamsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StreamsRequest() / StreamsRequest.new instead')
  static StreamsRequest create() => StreamsRequest._();
  static $pb.GeneratedMessage $_createMessage() => StreamsRequest._();
  @$core.override
  StreamsRequest createEmptyInstance() => StreamsRequest._();
  @$core.pragma('dart2js:noInline')
  static StreamsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StreamsRequest>(
          StreamsRequest.$_createMessage);
  static StreamsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mediaId => $_getSZ(1);
  @$pb.TagNumber(2)
  set mediaId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaId() => $_clearField(2);
}

class StreamsResponse extends $pb.GeneratedMessage {
  factory StreamsResponse({
    $core.Iterable<StreamSource>? sources,
  }) {
    final result = StreamsResponse._();
    if (sources != null) result.sources.addAll(sources);
    return result;
  }

  StreamsResponse._();

  factory StreamsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StreamsResponse()..mergeFromBuffer(data, registry);
  factory StreamsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StreamsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: StreamsResponse.$_createMessage)
    ..pPM<StreamSource>(1, _omitFieldNames ? '' : 'sources',
        subBuilder: StreamSource.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamsResponse copyWith(void Function(StreamsResponse) updates) =>
      super.copyWith((message) => updates(message as StreamsResponse))
          as StreamsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StreamsResponse() / StreamsResponse.new instead')
  static StreamsResponse create() => StreamsResponse._();
  static $pb.GeneratedMessage $_createMessage() => StreamsResponse._();
  @$core.override
  StreamsResponse createEmptyInstance() => StreamsResponse._();
  @$core.pragma('dart2js:noInline')
  static StreamsResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StreamsResponse>(
          StreamsResponse.$_createMessage);
  static StreamsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<StreamSource> get sources => $_getList(0);
}

class ResolveRequest extends $pb.GeneratedMessage {
  factory ResolveRequest({
    $core.String? pluginId,
    $core.String? streamId,
    $core.double? startPositionSec,
    $core.bool? takeOver,
  }) {
    final result = ResolveRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    if (streamId != null) result.streamId = streamId;
    if (startPositionSec != null) result.startPositionSec = startPositionSec;
    if (takeOver != null) result.takeOver = takeOver;
    return result;
  }

  ResolveRequest._();

  factory ResolveRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResolveRequest()..mergeFromBuffer(data, registry);
  factory ResolveRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResolveRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResolveRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: ResolveRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'streamId')
    ..aD(3, _omitFieldNames ? '' : 'startPositionSec')
    ..aOB(4, _omitFieldNames ? '' : 'takeOver')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveRequest copyWith(void Function(ResolveRequest) updates) =>
      super.copyWith((message) => updates(message as ResolveRequest))
          as ResolveRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ResolveRequest() / ResolveRequest.new instead')
  static ResolveRequest create() => ResolveRequest._();
  static $pb.GeneratedMessage $_createMessage() => ResolveRequest._();
  @$core.override
  ResolveRequest createEmptyInstance() => ResolveRequest._();
  @$core.pragma('dart2js:noInline')
  static ResolveRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ResolveRequest>(
          ResolveRequest.$_createMessage);
  static ResolveRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get streamId => $_getSZ(1);
  @$pb.TagNumber(2)
  set streamId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStreamId() => $_has(1);
  @$pb.TagNumber(2)
  void clearStreamId() => $_clearField(2);

  /// Where playback will start (seconds), e.g. the Continue Watching resume
  /// point; 0 = from the beginning. The server warms the segments around that
  /// point instead of the first ones, so a resumed video starts from cache.
  /// The client still opens the player at that position itself.
  @$pb.TagNumber(3)
  $core.double get startPositionSec => $_getN(2);
  @$pb.TagNumber(3)
  set startPositionSec($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStartPositionSec() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartPositionSec() => $_clearField(3);

  /// A profile plays on one device at a time. When it's already playing on
  /// another device ResolveStream fails with ABORTED ("in riproduzione su
  /// «TV salotto»…"): the client can ask "watch here?" and resolve again with
  /// take_over = true — playback moves to this device and the other one is
  /// told (its next /proxy fetch answers 409, its next UpdateProgress
  /// returns playback_elsewhere).
  @$pb.TagNumber(4)
  $core.bool get takeOver => $_getBF(3);
  @$pb.TagNumber(4)
  set takeOver($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTakeOver() => $_has(3);
  @$pb.TagNumber(4)
  void clearTakeOver() => $_clearField(4);
}

class ResolveResponse extends $pb.GeneratedMessage {
  factory ResolveResponse({
    $core.String? resolvedUrl,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? httpHeaders,
    $core.bool? isLive,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? extra,
  }) {
    final result = ResolveResponse._();
    if (resolvedUrl != null) result.resolvedUrl = resolvedUrl;
    if (httpHeaders != null) result.httpHeaders.addEntries(httpHeaders);
    if (isLive != null) result.isLive = isLive;
    if (extra != null) result.extra.addEntries(extra);
    return result;
  }

  ResolveResponse._();

  factory ResolveResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResolveResponse()..mergeFromBuffer(data, registry);
  factory ResolveResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResolveResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResolveResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: ResolveResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'resolvedUrl')
    ..m<$core.String, $core.String>(2, _omitFieldNames ? '' : 'httpHeaders',
        entryClassName: 'ResolveResponse.HttpHeadersEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('mycelium'))
    ..aOB(3, _omitFieldNames ? '' : 'isLive')
    ..m<$core.String, $core.String>(5, _omitFieldNames ? '' : 'extra',
        entryClassName: 'ResolveResponse.ExtraEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('mycelium'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveResponse copyWith(void Function(ResolveResponse) updates) =>
      super.copyWith((message) => updates(message as ResolveResponse))
          as ResolveResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ResolveResponse() / ResolveResponse.new instead')
  static ResolveResponse create() => ResolveResponse._();
  static $pb.GeneratedMessage $_createMessage() => ResolveResponse._();
  @$core.override
  ResolveResponse createEmptyInstance() => ResolveResponse._();
  @$core.pragma('dart2js:noInline')
  static ResolveResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ResolveResponse>(
          ResolveResponse.$_createMessage);
  static ResolveResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get resolvedUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set resolvedUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasResolvedUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearResolvedUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, $core.String> get httpHeaders => $_getMap(1);

  @$pb.TagNumber(3)
  $core.bool get isLive => $_getBF(2);
  @$pb.TagNumber(3)
  set isLive($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsLive() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsLive() => $_clearField(3);

  @$pb.TagNumber(5)
  $pb.PbMap<$core.String, $core.String> get extra => $_getMap(3);
}

/// ResolveProgress is an informational update emitted while ResolveStream is
/// still working (e.g. a resolve stage failed but the plugin is falling back
/// to another source). It never ends the RPC by itself.
class ResolveProgress extends $pb.GeneratedMessage {
  factory ResolveProgress({
    $core.String? message,
    $core.String? status,
  }) {
    final result = ResolveProgress._();
    if (message != null) result.message = message;
    if (status != null) result.status = status;
    return result;
  }

  ResolveProgress._();

  factory ResolveProgress.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResolveProgress()..mergeFromBuffer(data, registry);
  factory ResolveProgress.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResolveProgress()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResolveProgress',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: ResolveProgress.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'message')
    ..aOS(2, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveProgress clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveProgress copyWith(void Function(ResolveProgress) updates) =>
      super.copyWith((message) => updates(message as ResolveProgress))
          as ResolveProgress;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ResolveProgress() / ResolveProgress.new instead')
  static ResolveProgress create() => ResolveProgress._();
  static $pb.GeneratedMessage $_createMessage() => ResolveProgress._();
  @$core.override
  ResolveProgress createEmptyInstance() => ResolveProgress._();
  @$core.pragma('dart2js:noInline')
  static ResolveProgress getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ResolveProgress>(
          ResolveProgress.$_createMessage);
  static ResolveProgress? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get status => $_getSZ(1);
  @$pb.TagNumber(2)
  set status($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);
}

enum ResolveStreamEvent_Payload { progress, result, notSet }

/// ResolveStreamEvent is the payload of the ResolveStream server-streaming
/// RPC: zero or more {progress} updates followed by exactly one {result}
/// that ends the stream. If the resolve fails outright the RPC returns an
/// error instead of a {result} event.
class ResolveStreamEvent extends $pb.GeneratedMessage {
  factory ResolveStreamEvent({
    ResolveProgress? progress,
    ResolveResponse? result,
  }) {
    final result$ = ResolveStreamEvent._();
    if (progress != null) result$.progress = progress;
    if (result != null) result$.result = result;
    return result$;
  }

  ResolveStreamEvent._();

  factory ResolveStreamEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResolveStreamEvent()..mergeFromBuffer(data, registry);
  factory ResolveStreamEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResolveStreamEvent()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ResolveStreamEvent_Payload>
      _ResolveStreamEvent_PayloadByTag = {
    1: ResolveStreamEvent_Payload.progress,
    2: ResolveStreamEvent_Payload.result,
    0: ResolveStreamEvent_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResolveStreamEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: ResolveStreamEvent.$_createMessage)
    ..oo(0, [1, 2])
    ..aOM<ResolveProgress>(1, _omitFieldNames ? '' : 'progress',
        subBuilder: ResolveProgress.$_createMessage)
    ..aOM<ResolveResponse>(2, _omitFieldNames ? '' : 'result',
        subBuilder: ResolveResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveStreamEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveStreamEvent copyWith(void Function(ResolveStreamEvent) updates) =>
      super.copyWith((message) => updates(message as ResolveStreamEvent))
          as ResolveStreamEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ResolveStreamEvent() / ResolveStreamEvent.new instead')
  static ResolveStreamEvent create() => ResolveStreamEvent._();
  static $pb.GeneratedMessage $_createMessage() => ResolveStreamEvent._();
  @$core.override
  ResolveStreamEvent createEmptyInstance() => ResolveStreamEvent._();
  @$core.pragma('dart2js:noInline')
  static ResolveStreamEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResolveStreamEvent>(
          ResolveStreamEvent.$_createMessage);
  static ResolveStreamEvent? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  ResolveStreamEvent_Payload whichPayload() =>
      _ResolveStreamEvent_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  ResolveProgress get progress => $_getN(0);
  @$pb.TagNumber(1)
  set progress(ResolveProgress value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasProgress() => $_has(0);
  @$pb.TagNumber(1)
  void clearProgress() => $_clearField(1);
  @$pb.TagNumber(1)
  ResolveProgress ensureProgress() => $_ensure(0);

  @$pb.TagNumber(2)
  ResolveResponse get result => $_getN(1);
  @$pb.TagNumber(2)
  set result(ResolveResponse value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasResult() => $_has(1);
  @$pb.TagNumber(2)
  void clearResult() => $_clearField(2);
  @$pb.TagNumber(2)
  ResolveResponse ensureResult() => $_ensure(1);
}

class ProgressRequest extends $pb.GeneratedMessage {
  factory ProgressRequest({
    $core.String? pluginId,
    $core.String? mediaId,
    $core.String? parentId,
    $fixnum.Int64? currentPosition,
    $fixnum.Int64? totalDuration,
    $core.String? navigationContext,
    $core.String? title,
    $core.String? poster,
    $core.double? rating,
    $core.Iterable<$core.String>? genres,
    $core.String? plot,
    $core.int? year,
    $core.int? seasonNumber,
    $core.int? episodeNumber,
  }) {
    final result = ProgressRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    if (mediaId != null) result.mediaId = mediaId;
    if (parentId != null) result.parentId = parentId;
    if (currentPosition != null) result.currentPosition = currentPosition;
    if (totalDuration != null) result.totalDuration = totalDuration;
    if (navigationContext != null) result.navigationContext = navigationContext;
    if (title != null) result.title = title;
    if (poster != null) result.poster = poster;
    if (rating != null) result.rating = rating;
    if (genres != null) result.genres.addAll(genres);
    if (plot != null) result.plot = plot;
    if (year != null) result.year = year;
    if (seasonNumber != null) result.seasonNumber = seasonNumber;
    if (episodeNumber != null) result.episodeNumber = episodeNumber;
    return result;
  }

  ProgressRequest._();

  factory ProgressRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProgressRequest()..mergeFromBuffer(data, registry);
  factory ProgressRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProgressRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProgressRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: ProgressRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'mediaId')
    ..aOS(3, _omitFieldNames ? '' : 'parentId')
    ..aInt64(4, _omitFieldNames ? '' : 'currentPosition')
    ..aInt64(5, _omitFieldNames ? '' : 'totalDuration')
    ..aOS(6, _omitFieldNames ? '' : 'navigationContext')
    ..aOS(7, _omitFieldNames ? '' : 'title')
    ..aOS(8, _omitFieldNames ? '' : 'poster')
    ..aD(9, _omitFieldNames ? '' : 'rating')
    ..pPS(10, _omitFieldNames ? '' : 'genres')
    ..aOS(11, _omitFieldNames ? '' : 'plot')
    ..aI(12, _omitFieldNames ? '' : 'year')
    ..aI(13, _omitFieldNames ? '' : 'seasonNumber')
    ..aI(14, _omitFieldNames ? '' : 'episodeNumber')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgressRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgressRequest copyWith(void Function(ProgressRequest) updates) =>
      super.copyWith((message) => updates(message as ProgressRequest))
          as ProgressRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ProgressRequest() / ProgressRequest.new instead')
  static ProgressRequest create() => ProgressRequest._();
  static $pb.GeneratedMessage $_createMessage() => ProgressRequest._();
  @$core.override
  ProgressRequest createEmptyInstance() => ProgressRequest._();
  @$core.pragma('dart2js:noInline')
  static ProgressRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProgressRequest>(
          ProgressRequest.$_createMessage);
  static ProgressRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mediaId => $_getSZ(1);
  @$pb.TagNumber(2)
  set mediaId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get parentId => $_getSZ(2);
  @$pb.TagNumber(3)
  set parentId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasParentId() => $_has(2);
  @$pb.TagNumber(3)
  void clearParentId() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get currentPosition => $_getI64(3);
  @$pb.TagNumber(4)
  set currentPosition($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCurrentPosition() => $_has(3);
  @$pb.TagNumber(4)
  void clearCurrentPosition() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get totalDuration => $_getI64(4);
  @$pb.TagNumber(5)
  set totalDuration($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTotalDuration() => $_has(4);
  @$pb.TagNumber(5)
  void clearTotalDuration() => $_clearField(5);

  /// navigation_context/title/poster: populate the continue-watching card.
  /// Empty string leaves the existing stored value untouched (see
  /// UpsertProgress's merge-on-conflict) rather than clearing it — a plain
  /// position-only heartbeat doesn't need to resend metadata every tick.
  @$pb.TagNumber(6)
  $core.String get navigationContext => $_getSZ(5);
  @$pb.TagNumber(6)
  set navigationContext($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNavigationContext() => $_has(5);
  @$pb.TagNumber(6)
  void clearNavigationContext() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get title => $_getSZ(6);
  @$pb.TagNumber(7)
  set title($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTitle() => $_has(6);
  @$pb.TagNumber(7)
  void clearTitle() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get poster => $_getSZ(7);
  @$pb.TagNumber(8)
  set poster($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPoster() => $_has(7);
  @$pb.TagNumber(8)
  void clearPoster() => $_clearField(8);

  /// rating/genres/plot/year: same merge-on-conflict rule as above — 0/empty
  /// leaves the stored value untouched. Sourced from GetDetails at play time
  /// (PlaybackArgs on the Flutter side), not re-fetched here server-side.
  @$pb.TagNumber(9)
  $core.double get rating => $_getN(8);
  @$pb.TagNumber(9)
  set rating($core.double value) => $_setDouble(8, value);
  @$pb.TagNumber(9)
  $core.bool hasRating() => $_has(8);
  @$pb.TagNumber(9)
  void clearRating() => $_clearField(9);

  @$pb.TagNumber(10)
  $pb.PbList<$core.String> get genres => $_getList(9);

  @$pb.TagNumber(11)
  $core.String get plot => $_getSZ(10);
  @$pb.TagNumber(11)
  set plot($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasPlot() => $_has(10);
  @$pb.TagNumber(11)
  void clearPlot() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get year => $_getIZ(11);
  @$pb.TagNumber(12)
  set year($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasYear() => $_has(11);
  @$pb.TagNumber(12)
  void clearYear() => $_clearField(12);

  /// season_number/episode_number: same merge-on-conflict rule as above - 0
  /// leaves the stored value untouched. 0 for a movie/non-episodic item (no
  /// column ever gets a real value for those, so GetContinueWatching's 0
  /// means "not an episode" unambiguously on the read side too).
  @$pb.TagNumber(13)
  $core.int get seasonNumber => $_getIZ(12);
  @$pb.TagNumber(13)
  set seasonNumber($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasSeasonNumber() => $_has(12);
  @$pb.TagNumber(13)
  void clearSeasonNumber() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get episodeNumber => $_getIZ(13);
  @$pb.TagNumber(14)
  set episodeNumber($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasEpisodeNumber() => $_has(13);
  @$pb.TagNumber(14)
  void clearEpisodeNumber() => $_clearField(14);
}

class ProgressResponse extends $pb.GeneratedMessage {
  factory ProgressResponse({
    $core.bool? ok,
    $core.bool? playbackElsewhere,
    $core.String? playingOn,
  }) {
    final result = ProgressResponse._();
    if (ok != null) result.ok = ok;
    if (playbackElsewhere != null) result.playbackElsewhere = playbackElsewhere;
    if (playingOn != null) result.playingOn = playingOn;
    return result;
  }

  ProgressResponse._();

  factory ProgressResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProgressResponse()..mergeFromBuffer(data, registry);
  factory ProgressResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProgressResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProgressResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: ProgressResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..aOB(2, _omitFieldNames ? '' : 'playbackElsewhere')
    ..aOS(3, _omitFieldNames ? '' : 'playingOn')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgressResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgressResponse copyWith(void Function(ProgressResponse) updates) =>
      super.copyWith((message) => updates(message as ProgressResponse))
          as ProgressResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ProgressResponse() / ProgressResponse.new instead')
  static ProgressResponse create() => ProgressResponse._();
  static $pb.GeneratedMessage $_createMessage() => ProgressResponse._();
  @$core.override
  ProgressResponse createEmptyInstance() => ProgressResponse._();
  @$core.pragma('dart2js:noInline')
  static ProgressResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProgressResponse>(
          ProgressResponse.$_createMessage);
  static ProgressResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);

  /// This device no longer holds the profile's playback: it was taken over
  /// by playing_on (a device label). The player should stop and say so.
  @$pb.TagNumber(2)
  $core.bool get playbackElsewhere => $_getBF(1);
  @$pb.TagNumber(2)
  set playbackElsewhere($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlaybackElsewhere() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlaybackElsewhere() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get playingOn => $_getSZ(2);
  @$pb.TagNumber(3)
  set playingOn($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPlayingOn() => $_has(2);
  @$pb.TagNumber(3)
  void clearPlayingOn() => $_clearField(3);
}

/// ReleasePlayback frees the calling device's hold on the active profile's
/// playback right away — call it when the player closes, so switching to
/// another device needs no waiting (otherwise the hold lapses by itself
/// ~90 s after the last activity).
class ReleasePlaybackRequest extends $pb.GeneratedMessage {
  factory ReleasePlaybackRequest() => ReleasePlaybackRequest._();

  ReleasePlaybackRequest._();

  factory ReleasePlaybackRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReleasePlaybackRequest()..mergeFromBuffer(data, registry);
  factory ReleasePlaybackRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReleasePlaybackRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReleasePlaybackRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: ReleasePlaybackRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReleasePlaybackRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReleasePlaybackRequest copyWith(
          void Function(ReleasePlaybackRequest) updates) =>
      super.copyWith((message) => updates(message as ReleasePlaybackRequest))
          as ReleasePlaybackRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ReleasePlaybackRequest() / ReleasePlaybackRequest.new instead')
  static ReleasePlaybackRequest create() => ReleasePlaybackRequest._();
  static $pb.GeneratedMessage $_createMessage() => ReleasePlaybackRequest._();
  @$core.override
  ReleasePlaybackRequest createEmptyInstance() => ReleasePlaybackRequest._();
  @$core.pragma('dart2js:noInline')
  static ReleasePlaybackRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReleasePlaybackRequest>(
          ReleasePlaybackRequest.$_createMessage);
  static ReleasePlaybackRequest? _defaultInstance;
}

class ReleasePlaybackResponse extends $pb.GeneratedMessage {
  factory ReleasePlaybackResponse({
    $core.bool? ok,
  }) {
    final result = ReleasePlaybackResponse._();
    if (ok != null) result.ok = ok;
    return result;
  }

  ReleasePlaybackResponse._();

  factory ReleasePlaybackResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReleasePlaybackResponse()..mergeFromBuffer(data, registry);
  factory ReleasePlaybackResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReleasePlaybackResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReleasePlaybackResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: ReleasePlaybackResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReleasePlaybackResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReleasePlaybackResponse copyWith(
          void Function(ReleasePlaybackResponse) updates) =>
      super.copyWith((message) => updates(message as ReleasePlaybackResponse))
          as ReleasePlaybackResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ReleasePlaybackResponse() / ReleasePlaybackResponse.new instead')
  static ReleasePlaybackResponse create() => ReleasePlaybackResponse._();
  static $pb.GeneratedMessage $_createMessage() => ReleasePlaybackResponse._();
  @$core.override
  ReleasePlaybackResponse createEmptyInstance() => ReleasePlaybackResponse._();
  @$core.pragma('dart2js:noInline')
  static ReleasePlaybackResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReleasePlaybackResponse>(
          ReleasePlaybackResponse.$_createMessage);
  static ReleasePlaybackResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);
}

/// WarmStream: best-effort, resolve a stream ahead of Play so the plugin's
/// resolve cache is warm when ResolveStream comes. No playback lease, no
/// session, no segments. Returns at once; the work goes on in the background.
/// A server without it answers UNIMPLEMENTED: the client stops warming.
class WarmStreamRequest extends $pb.GeneratedMessage {
  factory WarmStreamRequest({
    $core.String? pluginId,
    $core.String? streamId,
  }) {
    final result = WarmStreamRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    if (streamId != null) result.streamId = streamId;
    return result;
  }

  WarmStreamRequest._();

  factory WarmStreamRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WarmStreamRequest()..mergeFromBuffer(data, registry);
  factory WarmStreamRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WarmStreamRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WarmStreamRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: WarmStreamRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'streamId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WarmStreamRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WarmStreamRequest copyWith(void Function(WarmStreamRequest) updates) =>
      super.copyWith((message) => updates(message as WarmStreamRequest))
          as WarmStreamRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WarmStreamRequest() / WarmStreamRequest.new instead')
  static WarmStreamRequest create() => WarmStreamRequest._();
  static $pb.GeneratedMessage $_createMessage() => WarmStreamRequest._();
  @$core.override
  WarmStreamRequest createEmptyInstance() => WarmStreamRequest._();
  @$core.pragma('dart2js:noInline')
  static WarmStreamRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WarmStreamRequest>(
          WarmStreamRequest.$_createMessage);
  static WarmStreamRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get streamId => $_getSZ(1);
  @$pb.TagNumber(2)
  set streamId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStreamId() => $_has(1);
  @$pb.TagNumber(2)
  void clearStreamId() => $_clearField(2);
}

class WarmStreamResponse extends $pb.GeneratedMessage {
  factory WarmStreamResponse({
    $core.String? outcome,
    $core.String? reason,
  }) {
    final result = WarmStreamResponse._();
    if (outcome != null) result.outcome = outcome;
    if (reason != null) result.reason = reason;
    return result;
  }

  WarmStreamResponse._();

  factory WarmStreamResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WarmStreamResponse()..mergeFromBuffer(data, registry);
  factory WarmStreamResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WarmStreamResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WarmStreamResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: WarmStreamResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'outcome')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WarmStreamResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WarmStreamResponse copyWith(void Function(WarmStreamResponse) updates) =>
      super.copyWith((message) => updates(message as WarmStreamResponse))
          as WarmStreamResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WarmStreamResponse() / WarmStreamResponse.new instead')
  static WarmStreamResponse create() => WarmStreamResponse._();
  static $pb.GeneratedMessage $_createMessage() => WarmStreamResponse._();
  @$core.override
  WarmStreamResponse createEmptyInstance() => WarmStreamResponse._();
  @$core.pragma('dart2js:noInline')
  static WarmStreamResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WarmStreamResponse>(
          WarmStreamResponse.$_createMessage);
  static WarmStreamResponse? _defaultInstance;

  /// "started" | "joined" (already in flight) | "skipped"
  @$pb.TagNumber(1)
  $core.String get outcome => $_getSZ(0);
  @$pb.TagNumber(1)
  set outcome($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOutcome() => $_has(0);
  @$pb.TagNumber(1)
  void clearOutcome() => $_clearField(1);

  /// When skipped: "disabled", "busy", "budget", "browser_busy", "recent".
  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);
}

class DeleteProgressRequest extends $pb.GeneratedMessage {
  factory DeleteProgressRequest({
    $core.String? pluginId,
    $core.String? mediaId,
  }) {
    final result = DeleteProgressRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    if (mediaId != null) result.mediaId = mediaId;
    return result;
  }

  DeleteProgressRequest._();

  factory DeleteProgressRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteProgressRequest()..mergeFromBuffer(data, registry);
  factory DeleteProgressRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteProgressRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteProgressRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: DeleteProgressRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'mediaId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProgressRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProgressRequest copyWith(
          void Function(DeleteProgressRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteProgressRequest))
          as DeleteProgressRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DeleteProgressRequest() / DeleteProgressRequest.new instead')
  static DeleteProgressRequest create() => DeleteProgressRequest._();
  static $pb.GeneratedMessage $_createMessage() => DeleteProgressRequest._();
  @$core.override
  DeleteProgressRequest createEmptyInstance() => DeleteProgressRequest._();
  @$core.pragma('dart2js:noInline')
  static DeleteProgressRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteProgressRequest>(
          DeleteProgressRequest.$_createMessage);
  static DeleteProgressRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mediaId => $_getSZ(1);
  @$pb.TagNumber(2)
  set mediaId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaId() => $_clearField(2);
}

class DeleteProgressResponse extends $pb.GeneratedMessage {
  factory DeleteProgressResponse({
    $core.bool? ok,
  }) {
    final result = DeleteProgressResponse._();
    if (ok != null) result.ok = ok;
    return result;
  }

  DeleteProgressResponse._();

  factory DeleteProgressResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteProgressResponse()..mergeFromBuffer(data, registry);
  factory DeleteProgressResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteProgressResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteProgressResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: DeleteProgressResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProgressResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProgressResponse copyWith(
          void Function(DeleteProgressResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteProgressResponse))
          as DeleteProgressResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DeleteProgressResponse() / DeleteProgressResponse.new instead')
  static DeleteProgressResponse create() => DeleteProgressResponse._();
  static $pb.GeneratedMessage $_createMessage() => DeleteProgressResponse._();
  @$core.override
  DeleteProgressResponse createEmptyInstance() => DeleteProgressResponse._();
  @$core.pragma('dart2js:noInline')
  static DeleteProgressResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteProgressResponse>(
          DeleteProgressResponse.$_createMessage);
  static DeleteProgressResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);
}

class ContinueWatchingItem extends $pb.GeneratedMessage {
  factory ContinueWatchingItem({
    $core.String? pluginId,
    $core.String? mediaId,
    $core.String? parentId,
    $core.String? navigationContext,
    $core.String? title,
    $core.String? poster,
    $core.double? progressTime,
    $core.double? totalTime,
    $core.String? lastUpdated,
    $core.double? rating,
    $core.Iterable<$core.String>? genres,
    $core.String? plot,
    $core.int? year,
    $core.int? seasonNumber,
    $core.int? episodeNumber,
  }) {
    final result = ContinueWatchingItem._();
    if (pluginId != null) result.pluginId = pluginId;
    if (mediaId != null) result.mediaId = mediaId;
    if (parentId != null) result.parentId = parentId;
    if (navigationContext != null) result.navigationContext = navigationContext;
    if (title != null) result.title = title;
    if (poster != null) result.poster = poster;
    if (progressTime != null) result.progressTime = progressTime;
    if (totalTime != null) result.totalTime = totalTime;
    if (lastUpdated != null) result.lastUpdated = lastUpdated;
    if (rating != null) result.rating = rating;
    if (genres != null) result.genres.addAll(genres);
    if (plot != null) result.plot = plot;
    if (year != null) result.year = year;
    if (seasonNumber != null) result.seasonNumber = seasonNumber;
    if (episodeNumber != null) result.episodeNumber = episodeNumber;
    return result;
  }

  ContinueWatchingItem._();

  factory ContinueWatchingItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContinueWatchingItem()..mergeFromBuffer(data, registry);
  factory ContinueWatchingItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContinueWatchingItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContinueWatchingItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: ContinueWatchingItem.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'mediaId')
    ..aOS(3, _omitFieldNames ? '' : 'parentId')
    ..aOS(4, _omitFieldNames ? '' : 'navigationContext')
    ..aOS(5, _omitFieldNames ? '' : 'title')
    ..aOS(6, _omitFieldNames ? '' : 'poster')
    ..aD(7, _omitFieldNames ? '' : 'progressTime')
    ..aD(8, _omitFieldNames ? '' : 'totalTime')
    ..aOS(9, _omitFieldNames ? '' : 'lastUpdated')
    ..aD(10, _omitFieldNames ? '' : 'rating')
    ..pPS(11, _omitFieldNames ? '' : 'genres')
    ..aOS(12, _omitFieldNames ? '' : 'plot')
    ..aI(13, _omitFieldNames ? '' : 'year')
    ..aI(14, _omitFieldNames ? '' : 'seasonNumber')
    ..aI(15, _omitFieldNames ? '' : 'episodeNumber')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContinueWatchingItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContinueWatchingItem copyWith(void Function(ContinueWatchingItem) updates) =>
      super.copyWith((message) => updates(message as ContinueWatchingItem))
          as ContinueWatchingItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ContinueWatchingItem() / ContinueWatchingItem.new instead')
  static ContinueWatchingItem create() => ContinueWatchingItem._();
  static $pb.GeneratedMessage $_createMessage() => ContinueWatchingItem._();
  @$core.override
  ContinueWatchingItem createEmptyInstance() => ContinueWatchingItem._();
  @$core.pragma('dart2js:noInline')
  static ContinueWatchingItem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContinueWatchingItem>(
          ContinueWatchingItem.$_createMessage);
  static ContinueWatchingItem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mediaId => $_getSZ(1);
  @$pb.TagNumber(2)
  set mediaId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get parentId => $_getSZ(2);
  @$pb.TagNumber(3)
  set parentId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasParentId() => $_has(2);
  @$pb.TagNumber(3)
  void clearParentId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get navigationContext => $_getSZ(3);
  @$pb.TagNumber(4)
  set navigationContext($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNavigationContext() => $_has(3);
  @$pb.TagNumber(4)
  void clearNavigationContext() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get title => $_getSZ(4);
  @$pb.TagNumber(5)
  set title($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTitle() => $_has(4);
  @$pb.TagNumber(5)
  void clearTitle() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get poster => $_getSZ(5);
  @$pb.TagNumber(6)
  set poster($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPoster() => $_has(5);
  @$pb.TagNumber(6)
  void clearPoster() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.double get progressTime => $_getN(6);
  @$pb.TagNumber(7)
  set progressTime($core.double value) => $_setDouble(6, value);
  @$pb.TagNumber(7)
  $core.bool hasProgressTime() => $_has(6);
  @$pb.TagNumber(7)
  void clearProgressTime() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get totalTime => $_getN(7);
  @$pb.TagNumber(8)
  set totalTime($core.double value) => $_setDouble(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTotalTime() => $_has(7);
  @$pb.TagNumber(8)
  void clearTotalTime() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get lastUpdated => $_getSZ(8);
  @$pb.TagNumber(9)
  set lastUpdated($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLastUpdated() => $_has(8);
  @$pb.TagNumber(9)
  void clearLastUpdated() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.double get rating => $_getN(9);
  @$pb.TagNumber(10)
  set rating($core.double value) => $_setDouble(9, value);
  @$pb.TagNumber(10)
  $core.bool hasRating() => $_has(9);
  @$pb.TagNumber(10)
  void clearRating() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<$core.String> get genres => $_getList(10);

  @$pb.TagNumber(12)
  $core.String get plot => $_getSZ(11);
  @$pb.TagNumber(12)
  set plot($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasPlot() => $_has(11);
  @$pb.TagNumber(12)
  void clearPlot() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get year => $_getIZ(12);
  @$pb.TagNumber(13)
  set year($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasYear() => $_has(12);
  @$pb.TagNumber(13)
  void clearYear() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get seasonNumber => $_getIZ(13);
  @$pb.TagNumber(14)
  set seasonNumber($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasSeasonNumber() => $_has(13);
  @$pb.TagNumber(14)
  void clearSeasonNumber() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get episodeNumber => $_getIZ(14);
  @$pb.TagNumber(15)
  set episodeNumber($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasEpisodeNumber() => $_has(14);
  @$pb.TagNumber(15)
  void clearEpisodeNumber() => $_clearField(15);
}

class ContinueWatchingRequest extends $pb.GeneratedMessage {
  factory ContinueWatchingRequest({
    $core.int? limit,
    $core.String? parentId,
    $core.String? pluginId,
  }) {
    final result = ContinueWatchingRequest._();
    if (limit != null) result.limit = limit;
    if (parentId != null) result.parentId = parentId;
    if (pluginId != null) result.pluginId = pluginId;
    return result;
  }

  ContinueWatchingRequest._();

  factory ContinueWatchingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContinueWatchingRequest()..mergeFromBuffer(data, registry);
  factory ContinueWatchingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContinueWatchingRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContinueWatchingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: ContinueWatchingRequest.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'limit')
    ..aOS(2, _omitFieldNames ? '' : 'parentId')
    ..aOS(3, _omitFieldNames ? '' : 'pluginId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContinueWatchingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContinueWatchingRequest copyWith(
          void Function(ContinueWatchingRequest) updates) =>
      super.copyWith((message) => updates(message as ContinueWatchingRequest))
          as ContinueWatchingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ContinueWatchingRequest() / ContinueWatchingRequest.new instead')
  static ContinueWatchingRequest create() => ContinueWatchingRequest._();
  static $pb.GeneratedMessage $_createMessage() => ContinueWatchingRequest._();
  @$core.override
  ContinueWatchingRequest createEmptyInstance() => ContinueWatchingRequest._();
  @$core.pragma('dart2js:noInline')
  static ContinueWatchingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContinueWatchingRequest>(
          ContinueWatchingRequest.$_createMessage);
  static ContinueWatchingRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get limit => $_getIZ(0);
  @$pb.TagNumber(1)
  set limit($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLimit() => $_has(0);
  @$pb.TagNumber(1)
  void clearLimit() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get parentId => $_getSZ(1);
  @$pb.TagNumber(2)
  set parentId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasParentId() => $_has(1);
  @$pb.TagNumber(2)
  void clearParentId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get pluginId => $_getSZ(2);
  @$pb.TagNumber(3)
  set pluginId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPluginId() => $_has(2);
  @$pb.TagNumber(3)
  void clearPluginId() => $_clearField(3);
}

class ContinueWatchingResponse extends $pb.GeneratedMessage {
  factory ContinueWatchingResponse({
    $core.Iterable<ContinueWatchingItem>? items,
  }) {
    final result = ContinueWatchingResponse._();
    if (items != null) result.items.addAll(items);
    return result;
  }

  ContinueWatchingResponse._();

  factory ContinueWatchingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContinueWatchingResponse()..mergeFromBuffer(data, registry);
  factory ContinueWatchingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContinueWatchingResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContinueWatchingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: ContinueWatchingResponse.$_createMessage)
    ..pPM<ContinueWatchingItem>(1, _omitFieldNames ? '' : 'items',
        subBuilder: ContinueWatchingItem.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContinueWatchingResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContinueWatchingResponse copyWith(
          void Function(ContinueWatchingResponse) updates) =>
      super.copyWith((message) => updates(message as ContinueWatchingResponse))
          as ContinueWatchingResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ContinueWatchingResponse() / ContinueWatchingResponse.new instead')
  static ContinueWatchingResponse create() => ContinueWatchingResponse._();
  static $pb.GeneratedMessage $_createMessage() => ContinueWatchingResponse._();
  @$core.override
  ContinueWatchingResponse createEmptyInstance() =>
      ContinueWatchingResponse._();
  @$core.pragma('dart2js:noInline')
  static ContinueWatchingResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContinueWatchingResponse>(
          ContinueWatchingResponse.$_createMessage);
  static ContinueWatchingResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ContinueWatchingItem> get items => $_getList(0);
}

class PluginListRequest extends $pb.GeneratedMessage {
  factory PluginListRequest() => PluginListRequest._();

  PluginListRequest._();

  factory PluginListRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PluginListRequest()..mergeFromBuffer(data, registry);
  factory PluginListRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PluginListRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PluginListRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: PluginListRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PluginListRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PluginListRequest copyWith(void Function(PluginListRequest) updates) =>
      super.copyWith((message) => updates(message as PluginListRequest))
          as PluginListRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PluginListRequest() / PluginListRequest.new instead')
  static PluginListRequest create() => PluginListRequest._();
  static $pb.GeneratedMessage $_createMessage() => PluginListRequest._();
  @$core.override
  PluginListRequest createEmptyInstance() => PluginListRequest._();
  @$core.pragma('dart2js:noInline')
  static PluginListRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PluginListRequest>(
          PluginListRequest.$_createMessage);
  static PluginListRequest? _defaultInstance;
}

class PluginInfo extends $pb.GeneratedMessage {
  factory PluginInfo({
    $core.String? pluginId,
    $core.String? name,
    $core.String? version,
    $core.bool? isReady,
    $core.Iterable<$core.String>? capabilities,
    $core.Iterable<CatalogDef>? catalogs,
    $core.String? statusLabel,
    $core.String? statusDetail,
    $core.bool? needsConfig,
    $core.bool? reachable,
    $fixnum.Int64? lastOkUnix,
  }) {
    final result = PluginInfo._();
    if (pluginId != null) result.pluginId = pluginId;
    if (name != null) result.name = name;
    if (version != null) result.version = version;
    if (isReady != null) result.isReady = isReady;
    if (capabilities != null) result.capabilities.addAll(capabilities);
    if (catalogs != null) result.catalogs.addAll(catalogs);
    if (statusLabel != null) result.statusLabel = statusLabel;
    if (statusDetail != null) result.statusDetail = statusDetail;
    if (needsConfig != null) result.needsConfig = needsConfig;
    if (reachable != null) result.reachable = reachable;
    if (lastOkUnix != null) result.lastOkUnix = lastOkUnix;
    return result;
  }

  PluginInfo._();

  factory PluginInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PluginInfo()..mergeFromBuffer(data, registry);
  factory PluginInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PluginInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PluginInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: PluginInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'version')
    ..aOB(4, _omitFieldNames ? '' : 'isReady')
    ..pPS(5, _omitFieldNames ? '' : 'capabilities')
    ..pPM<CatalogDef>(6, _omitFieldNames ? '' : 'catalogs',
        subBuilder: CatalogDef.$_createMessage)
    ..aOS(7, _omitFieldNames ? '' : 'statusLabel')
    ..aOS(8, _omitFieldNames ? '' : 'statusDetail')
    ..aOB(9, _omitFieldNames ? '' : 'needsConfig')
    ..aOB(10, _omitFieldNames ? '' : 'reachable')
    ..aInt64(11, _omitFieldNames ? '' : 'lastOkUnix')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PluginInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PluginInfo copyWith(void Function(PluginInfo) updates) =>
      super.copyWith((message) => updates(message as PluginInfo)) as PluginInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PluginInfo() / PluginInfo.new instead')
  static PluginInfo create() => PluginInfo._();
  static $pb.GeneratedMessage $_createMessage() => PluginInfo._();
  @$core.override
  PluginInfo createEmptyInstance() => PluginInfo._();
  @$core.pragma('dart2js:noInline')
  static PluginInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PluginInfo>(PluginInfo.$_createMessage);
  static PluginInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get version => $_getSZ(2);
  @$pb.TagNumber(3)
  set version($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearVersion() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isReady => $_getBF(3);
  @$pb.TagNumber(4)
  set isReady($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsReady() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsReady() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get capabilities => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<CatalogDef> get catalogs => $_getList(5);

  /// Runtime status set by the plugin itself via mycelium.context.set_plugin_status()
  @$pb.TagNumber(7)
  $core.String get statusLabel => $_getSZ(6);
  @$pb.TagNumber(7)
  set statusLabel($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStatusLabel() => $_has(6);
  @$pb.TagNumber(7)
  void clearStatusLabel() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get statusDetail => $_getSZ(7);
  @$pb.TagNumber(8)
  set statusDetail($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStatusDetail() => $_has(7);
  @$pb.TagNumber(8)
  void clearStatusDetail() => $_clearField(8);

  /// True when one or more required core-scoped settings are missing
  @$pb.TagNumber(9)
  $core.bool get needsConfig => $_getBF(8);
  @$pb.TagNumber(9)
  set needsConfig($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasNeedsConfig() => $_has(8);
  @$pb.TagNumber(9)
  void clearNeedsConfig() => $_clearField(9);

  /// True when the plugin actually answered a liveness check recently — NOT
  /// the same as is_ready (which only means "configured", independent of
  /// whether the process/connection currently responds). A gRPC plugin whose
  /// process is alive but whose channel is broken, or a Lua plugin whose last
  /// N task runs all errored, reports reachable=false here so the client can
  /// surface a real "backend unreachable" signal instead of the user having
  /// to infer it from a stale catalog or dig through logs.
  @$pb.TagNumber(10)
  $core.bool get reachable => $_getBF(9);
  @$pb.TagNumber(10)
  set reachable($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasReachable() => $_has(9);
  @$pb.TagNumber(10)
  void clearReachable() => $_clearField(10);

  /// Unix timestamp (seconds) of the last time this plugin was confirmed
  /// reachable. 0 if never. Lets the client show "last seen Xm ago" instead
  /// of a bare boolean.
  @$pb.TagNumber(11)
  $fixnum.Int64 get lastOkUnix => $_getI64(10);
  @$pb.TagNumber(11)
  set lastOkUnix($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasLastOkUnix() => $_has(10);
  @$pb.TagNumber(11)
  void clearLastOkUnix() => $_clearField(11);
}

class CatalogDef extends $pb.GeneratedMessage {
  factory CatalogDef({
    $core.String? id,
    $core.String? name,
    $core.String? type,
    $core.int? cacheTtlSeconds,
    $core.String? sectionKind,
    $core.String? styleHint,
    $core.bool? liveRefreshable,
    $core.String? cardLayout,
    $core.bool? disableHeroBackground,
  }) {
    final result = CatalogDef._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (type != null) result.type = type;
    if (cacheTtlSeconds != null) result.cacheTtlSeconds = cacheTtlSeconds;
    if (sectionKind != null) result.sectionKind = sectionKind;
    if (styleHint != null) result.styleHint = styleHint;
    if (liveRefreshable != null) result.liveRefreshable = liveRefreshable;
    if (cardLayout != null) result.cardLayout = cardLayout;
    if (disableHeroBackground != null)
      result.disableHeroBackground = disableHeroBackground;
    return result;
  }

  CatalogDef._();

  factory CatalogDef.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CatalogDef()..mergeFromBuffer(data, registry);
  factory CatalogDef.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CatalogDef()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CatalogDef',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: CatalogDef.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'type')
    ..aI(4, _omitFieldNames ? '' : 'cacheTtlSeconds')
    ..aOS(5, _omitFieldNames ? '' : 'sectionKind')
    ..aOS(6, _omitFieldNames ? '' : 'styleHint')
    ..aOB(7, _omitFieldNames ? '' : 'liveRefreshable')
    ..aOS(8, _omitFieldNames ? '' : 'cardLayout')
    ..aOB(9, _omitFieldNames ? '' : 'disableHeroBackground')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CatalogDef clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CatalogDef copyWith(void Function(CatalogDef) updates) =>
      super.copyWith((message) => updates(message as CatalogDef)) as CatalogDef;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CatalogDef() / CatalogDef.new instead')
  static CatalogDef create() => CatalogDef._();
  static $pb.GeneratedMessage $_createMessage() => CatalogDef._();
  @$core.override
  CatalogDef createEmptyInstance() => CatalogDef._();
  @$core.pragma('dart2js:noInline')
  static CatalogDef getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CatalogDef>(CatalogDef.$_createMessage);
  static CatalogDef? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get type => $_getSZ(2);
  @$pb.TagNumber(3)
  set type($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get cacheTtlSeconds => $_getIZ(3);
  @$pb.TagNumber(4)
  set cacheTtlSeconds($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCacheTtlSeconds() => $_has(3);
  @$pb.TagNumber(4)
  void clearCacheTtlSeconds() => $_clearField(4);

  /// section_kind: row layout, orthogonal to content type.
  ///   ""|"carousel" — horizontal scroll (today's default, always safe).
  ///   "grid"        — tile grid. Reserved: no client renders it yet as of
  ///                   this writing: treat as unset until a client opts in.
  /// Forward-compat contract: a client that doesn't recognize a value here
  /// must skip/ignore it gracefully (treat as unset), never crash or render
  /// garbage — this field will grow new values over time without a proto bump.
  @$pb.TagNumber(5)
  $core.String get sectionKind => $_getSZ(4);
  @$pb.TagNumber(5)
  set sectionKind($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSectionKind() => $_has(4);
  @$pb.TagNumber(5)
  void clearSectionKind() => $_clearField(5);

  /// style_hint: presentation weight within section_kind.
  ///   ""         — default card size (today's behavior).
  ///   "featured" — larger cards, visual emphasis.
  ///   "compact"  — smaller/denser cards.
  /// Same forward-compat contract as section_kind.
  @$pb.TagNumber(6)
  $core.String get styleHint => $_getSZ(5);
  @$pb.TagNumber(6)
  set styleHint($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStyleHint() => $_has(5);
  @$pb.TagNumber(6)
  void clearStyleHint() => $_clearField(6);

  /// True when this catalog backs a task the plugin author marked as
  /// user-triggerable (manifest.yaml task: live_refresh: true) — e.g. sport's
  /// "Live Ora" behind refresh_matches. Lets the client show a manual
  /// "aggiorna ora" action instead of waiting for the next cron tick.
  @$pb.TagNumber(7)
  $core.bool get liveRefreshable => $_getBF(6);
  @$pb.TagNumber(7)
  set liveRefreshable($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLiveRefreshable() => $_has(6);
  @$pb.TagNumber(7)
  void clearLiveRefreshable() => $_clearField(7);

  /// card_layout: card aspect ratio for this catalog's row — deliberately
  /// independent of `type`. Before this field existed, the only way to get
  /// 16:9 cards was `type = "live"`, which also forces the live-TV row
  /// styling (home_screen.dart's big centered fonts) and disables
  /// continue-watching plugin-wide — wrong for e.g. a YouTube-style plugin
  /// that wants landscape thumbnails for perfectly ordinary on-demand video
  /// (`CatalogItem.media_type` stays whatever it already was — "video", not
  /// "live" — and continues to drive live-vs-VOD *player* behavior on its
  /// own, unaffected by this field).
  ///   ""           — poster/vertical, 2:3 (today's default, unchanged).
  ///   "landscape"  — wide/horizontal, 16:9.
  /// Same forward-compat contract as section_kind: unrecognized values must
  /// be treated as unset, never crash or render garbage.
  @$pb.TagNumber(8)
  $core.String get cardLayout => $_getSZ(7);
  @$pb.TagNumber(8)
  set cardLayout($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCardLayout() => $_has(7);
  @$pb.TagNumber(8)
  void clearCardLayout() => $_clearField(8);

  /// disable_hero_background: when true, the home screen's full-bleed hero
  /// background never shows this catalog's fanart/poster imagery — it always
  /// falls back to the neutral/anonymous background (a flat dark fill, or a
  /// themed gradient for sport) that already renders today whenever no image
  /// is available. Content this is useful for tends to look bad or feels
  /// over-personal blown up full-screen (a specific match's low-res team
  /// logos, a random video's thumbnail) — better to stay anonymous than
  /// adapt to whatever's focused. False (default) preserves today's behavior
  /// unchanged for every catalog that doesn't set this.
  @$pb.TagNumber(9)
  $core.bool get disableHeroBackground => $_getBF(8);
  @$pb.TagNumber(9)
  set disableHeroBackground($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDisableHeroBackground() => $_has(8);
  @$pb.TagNumber(9)
  void clearDisableHeroBackground() => $_clearField(9);
}

class PluginListResponse extends $pb.GeneratedMessage {
  factory PluginListResponse({
    $core.Iterable<PluginInfo>? plugins,
  }) {
    final result = PluginListResponse._();
    if (plugins != null) result.plugins.addAll(plugins);
    return result;
  }

  PluginListResponse._();

  factory PluginListResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PluginListResponse()..mergeFromBuffer(data, registry);
  factory PluginListResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PluginListResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PluginListResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: PluginListResponse.$_createMessage)
    ..pPM<PluginInfo>(1, _omitFieldNames ? '' : 'plugins',
        subBuilder: PluginInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PluginListResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PluginListResponse copyWith(void Function(PluginListResponse) updates) =>
      super.copyWith((message) => updates(message as PluginListResponse))
          as PluginListResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PluginListResponse() / PluginListResponse.new instead')
  static PluginListResponse create() => PluginListResponse._();
  static $pb.GeneratedMessage $_createMessage() => PluginListResponse._();
  @$core.override
  PluginListResponse createEmptyInstance() => PluginListResponse._();
  @$core.pragma('dart2js:noInline')
  static PluginListResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PluginListResponse>(
          PluginListResponse.$_createMessage);
  static PluginListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PluginInfo> get plugins => $_getList(0);
}

class PluginSettingField extends $pb.GeneratedMessage {
  factory PluginSettingField({
    $core.String? id,
    $core.String? label,
    $core.String? type,
    $core.bool? required,
    $core.String? currentValue,
    $core.bool? isSet,
  }) {
    final result = PluginSettingField._();
    if (id != null) result.id = id;
    if (label != null) result.label = label;
    if (type != null) result.type = type;
    if (required != null) result.required = required;
    if (currentValue != null) result.currentValue = currentValue;
    if (isSet != null) result.isSet = isSet;
    return result;
  }

  PluginSettingField._();

  factory PluginSettingField.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PluginSettingField()..mergeFromBuffer(data, registry);
  factory PluginSettingField.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PluginSettingField()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PluginSettingField',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: PluginSettingField.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOS(3, _omitFieldNames ? '' : 'type')
    ..aOB(4, _omitFieldNames ? '' : 'required')
    ..aOS(5, _omitFieldNames ? '' : 'currentValue')
    ..aOB(6, _omitFieldNames ? '' : 'isSet')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PluginSettingField clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PluginSettingField copyWith(void Function(PluginSettingField) updates) =>
      super.copyWith((message) => updates(message as PluginSettingField))
          as PluginSettingField;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PluginSettingField() / PluginSettingField.new instead')
  static PluginSettingField create() => PluginSettingField._();
  static $pb.GeneratedMessage $_createMessage() => PluginSettingField._();
  @$core.override
  PluginSettingField createEmptyInstance() => PluginSettingField._();
  @$core.pragma('dart2js:noInline')
  static PluginSettingField getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PluginSettingField>(
          PluginSettingField.$_createMessage);
  static PluginSettingField? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  /// type: "string"|"password"|"number"|"bool"
  @$pb.TagNumber(3)
  $core.String get type => $_getSZ(2);
  @$pb.TagNumber(3)
  set type($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get required => $_getBF(3);
  @$pb.TagNumber(4)
  set required($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRequired() => $_has(3);
  @$pb.TagNumber(4)
  void clearRequired() => $_clearField(4);

  /// current_value is empty for password fields; use is_set instead
  @$pb.TagNumber(5)
  $core.String get currentValue => $_getSZ(4);
  @$pb.TagNumber(5)
  set currentValue($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCurrentValue() => $_has(4);
  @$pb.TagNumber(5)
  void clearCurrentValue() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isSet => $_getBF(5);
  @$pb.TagNumber(6)
  set isSet($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsSet() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsSet() => $_clearField(6);
}

class GetPluginSettingsRequest extends $pb.GeneratedMessage {
  factory GetPluginSettingsRequest({
    $core.String? pluginId,
    $core.String? profileId,
  }) {
    final result = GetPluginSettingsRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    if (profileId != null) result.profileId = profileId;
    return result;
  }

  GetPluginSettingsRequest._();

  factory GetPluginSettingsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetPluginSettingsRequest()..mergeFromBuffer(data, registry);
  factory GetPluginSettingsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetPluginSettingsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPluginSettingsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: GetPluginSettingsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'profileId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPluginSettingsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPluginSettingsRequest copyWith(
          void Function(GetPluginSettingsRequest) updates) =>
      super.copyWith((message) => updates(message as GetPluginSettingsRequest))
          as GetPluginSettingsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetPluginSettingsRequest() / GetPluginSettingsRequest.new instead')
  static GetPluginSettingsRequest create() => GetPluginSettingsRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetPluginSettingsRequest._();
  @$core.override
  GetPluginSettingsRequest createEmptyInstance() =>
      GetPluginSettingsRequest._();
  @$core.pragma('dart2js:noInline')
  static GetPluginSettingsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPluginSettingsRequest>(
          GetPluginSettingsRequest.$_createMessage);
  static GetPluginSettingsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get profileId => $_getSZ(1);
  @$pb.TagNumber(2)
  set profileId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProfileId() => $_has(1);
  @$pb.TagNumber(2)
  void clearProfileId() => $_clearField(2);
}

class GetPluginSettingsResponse extends $pb.GeneratedMessage {
  factory GetPluginSettingsResponse({
    $core.Iterable<PluginSettingField>? fields,
  }) {
    final result = GetPluginSettingsResponse._();
    if (fields != null) result.fields.addAll(fields);
    return result;
  }

  GetPluginSettingsResponse._();

  factory GetPluginSettingsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetPluginSettingsResponse()..mergeFromBuffer(data, registry);
  factory GetPluginSettingsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetPluginSettingsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPluginSettingsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: GetPluginSettingsResponse.$_createMessage)
    ..pPM<PluginSettingField>(1, _omitFieldNames ? '' : 'fields',
        subBuilder: PluginSettingField.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPluginSettingsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPluginSettingsResponse copyWith(
          void Function(GetPluginSettingsResponse) updates) =>
      super.copyWith((message) => updates(message as GetPluginSettingsResponse))
          as GetPluginSettingsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetPluginSettingsResponse() / GetPluginSettingsResponse.new instead')
  static GetPluginSettingsResponse create() => GetPluginSettingsResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      GetPluginSettingsResponse._();
  @$core.override
  GetPluginSettingsResponse createEmptyInstance() =>
      GetPluginSettingsResponse._();
  @$core.pragma('dart2js:noInline')
  static GetPluginSettingsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPluginSettingsResponse>(
          GetPluginSettingsResponse.$_createMessage);
  static GetPluginSettingsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PluginSettingField> get fields => $_getList(0);
}

class SavePluginSettingRequest extends $pb.GeneratedMessage {
  factory SavePluginSettingRequest({
    $core.String? pluginId,
    $core.String? profileId,
    $core.String? key,
    $core.String? value,
  }) {
    final result = SavePluginSettingRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    if (profileId != null) result.profileId = profileId;
    if (key != null) result.key = key;
    if (value != null) result.value = value;
    return result;
  }

  SavePluginSettingRequest._();

  factory SavePluginSettingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SavePluginSettingRequest()..mergeFromBuffer(data, registry);
  factory SavePluginSettingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SavePluginSettingRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SavePluginSettingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: SavePluginSettingRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'profileId')
    ..aOS(3, _omitFieldNames ? '' : 'key')
    ..aOS(4, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SavePluginSettingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SavePluginSettingRequest copyWith(
          void Function(SavePluginSettingRequest) updates) =>
      super.copyWith((message) => updates(message as SavePluginSettingRequest))
          as SavePluginSettingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SavePluginSettingRequest() / SavePluginSettingRequest.new instead')
  static SavePluginSettingRequest create() => SavePluginSettingRequest._();
  static $pb.GeneratedMessage $_createMessage() => SavePluginSettingRequest._();
  @$core.override
  SavePluginSettingRequest createEmptyInstance() =>
      SavePluginSettingRequest._();
  @$core.pragma('dart2js:noInline')
  static SavePluginSettingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SavePluginSettingRequest>(
          SavePluginSettingRequest.$_createMessage);
  static SavePluginSettingRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get profileId => $_getSZ(1);
  @$pb.TagNumber(2)
  set profileId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProfileId() => $_has(1);
  @$pb.TagNumber(2)
  void clearProfileId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get key => $_getSZ(2);
  @$pb.TagNumber(3)
  set key($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearKey() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get value => $_getSZ(3);
  @$pb.TagNumber(4)
  set value($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasValue() => $_has(3);
  @$pb.TagNumber(4)
  void clearValue() => $_clearField(4);
}

class SavePluginSettingResponse extends $pb.GeneratedMessage {
  factory SavePluginSettingResponse({
    $core.bool? ok,
  }) {
    final result = SavePluginSettingResponse._();
    if (ok != null) result.ok = ok;
    return result;
  }

  SavePluginSettingResponse._();

  factory SavePluginSettingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SavePluginSettingResponse()..mergeFromBuffer(data, registry);
  factory SavePluginSettingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SavePluginSettingResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SavePluginSettingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: SavePluginSettingResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SavePluginSettingResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SavePluginSettingResponse copyWith(
          void Function(SavePluginSettingResponse) updates) =>
      super.copyWith((message) => updates(message as SavePluginSettingResponse))
          as SavePluginSettingResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SavePluginSettingResponse() / SavePluginSettingResponse.new instead')
  static SavePluginSettingResponse create() => SavePluginSettingResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      SavePluginSettingResponse._();
  @$core.override
  SavePluginSettingResponse createEmptyInstance() =>
      SavePluginSettingResponse._();
  @$core.pragma('dart2js:noInline')
  static SavePluginSettingResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SavePluginSettingResponse>(
          SavePluginSettingResponse.$_createMessage);
  static SavePluginSettingResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);
}

/// TriggerRefresh asks the core to run a plugin's live_refresh-marked task(s)
/// right now, instead of waiting for its cron schedule. Non-blocking on the
/// core side: if a task for this plugin is already running, ok=false with an
/// explanatory message rather than queueing or blocking the call.
class TriggerRefreshRequest extends $pb.GeneratedMessage {
  factory TriggerRefreshRequest({
    $core.String? pluginId,
  }) {
    final result = TriggerRefreshRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    return result;
  }

  TriggerRefreshRequest._();

  factory TriggerRefreshRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TriggerRefreshRequest()..mergeFromBuffer(data, registry);
  factory TriggerRefreshRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TriggerRefreshRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TriggerRefreshRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: TriggerRefreshRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TriggerRefreshRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TriggerRefreshRequest copyWith(
          void Function(TriggerRefreshRequest) updates) =>
      super.copyWith((message) => updates(message as TriggerRefreshRequest))
          as TriggerRefreshRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use TriggerRefreshRequest() / TriggerRefreshRequest.new instead')
  static TriggerRefreshRequest create() => TriggerRefreshRequest._();
  static $pb.GeneratedMessage $_createMessage() => TriggerRefreshRequest._();
  @$core.override
  TriggerRefreshRequest createEmptyInstance() => TriggerRefreshRequest._();
  @$core.pragma('dart2js:noInline')
  static TriggerRefreshRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TriggerRefreshRequest>(
          TriggerRefreshRequest.$_createMessage);
  static TriggerRefreshRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);
}

class TriggerRefreshResponse extends $pb.GeneratedMessage {
  factory TriggerRefreshResponse({
    $core.bool? ok,
    $core.String? message,
  }) {
    final result = TriggerRefreshResponse._();
    if (ok != null) result.ok = ok;
    if (message != null) result.message = message;
    return result;
  }

  TriggerRefreshResponse._();

  factory TriggerRefreshResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TriggerRefreshResponse()..mergeFromBuffer(data, registry);
  factory TriggerRefreshResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TriggerRefreshResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TriggerRefreshResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: TriggerRefreshResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TriggerRefreshResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TriggerRefreshResponse copyWith(
          void Function(TriggerRefreshResponse) updates) =>
      super.copyWith((message) => updates(message as TriggerRefreshResponse))
          as TriggerRefreshResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use TriggerRefreshResponse() / TriggerRefreshResponse.new instead')
  static TriggerRefreshResponse create() => TriggerRefreshResponse._();
  static $pb.GeneratedMessage $_createMessage() => TriggerRefreshResponse._();
  @$core.override
  TriggerRefreshResponse createEmptyInstance() => TriggerRefreshResponse._();
  @$core.pragma('dart2js:noInline')
  static TriggerRefreshResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TriggerRefreshResponse>(
          TriggerRefreshResponse.$_createMessage);
  static TriggerRefreshResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class DownloadOptionsRequest extends $pb.GeneratedMessage {
  factory DownloadOptionsRequest({
    $core.String? pluginId,
    $core.String? streamId,
  }) {
    final result = DownloadOptionsRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    if (streamId != null) result.streamId = streamId;
    return result;
  }

  DownloadOptionsRequest._();

  factory DownloadOptionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadOptionsRequest()..mergeFromBuffer(data, registry);
  factory DownloadOptionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadOptionsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DownloadOptionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: DownloadOptionsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'streamId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadOptionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadOptionsRequest copyWith(
          void Function(DownloadOptionsRequest) updates) =>
      super.copyWith((message) => updates(message as DownloadOptionsRequest))
          as DownloadOptionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DownloadOptionsRequest() / DownloadOptionsRequest.new instead')
  static DownloadOptionsRequest create() => DownloadOptionsRequest._();
  static $pb.GeneratedMessage $_createMessage() => DownloadOptionsRequest._();
  @$core.override
  DownloadOptionsRequest createEmptyInstance() => DownloadOptionsRequest._();
  @$core.pragma('dart2js:noInline')
  static DownloadOptionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DownloadOptionsRequest>(
          DownloadOptionsRequest.$_createMessage);
  static DownloadOptionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get streamId => $_getSZ(1);
  @$pb.TagNumber(2)
  set streamId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStreamId() => $_has(1);
  @$pb.TagNumber(2)
  void clearStreamId() => $_clearField(2);
}

class DownloadVariant extends $pb.GeneratedMessage {
  factory DownloadVariant({
    $core.String? id,
    $core.int? width,
    $core.int? height,
    $fixnum.Int64? bandwidth,
    $core.bool? bandwidthIsPeak,
    $core.String? codecs,
    $fixnum.Int64? estimatedBytes,
    $core.String? label,
  }) {
    final result = DownloadVariant._();
    if (id != null) result.id = id;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (bandwidth != null) result.bandwidth = bandwidth;
    if (bandwidthIsPeak != null) result.bandwidthIsPeak = bandwidthIsPeak;
    if (codecs != null) result.codecs = codecs;
    if (estimatedBytes != null) result.estimatedBytes = estimatedBytes;
    if (label != null) result.label = label;
    return result;
  }

  DownloadVariant._();

  factory DownloadVariant.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadVariant()..mergeFromBuffer(data, registry);
  factory DownloadVariant.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadVariant()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DownloadVariant',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: DownloadVariant.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aI(2, _omitFieldNames ? '' : 'width')
    ..aI(3, _omitFieldNames ? '' : 'height')
    ..aInt64(4, _omitFieldNames ? '' : 'bandwidth')
    ..aOB(5, _omitFieldNames ? '' : 'bandwidthIsPeak')
    ..aOS(6, _omitFieldNames ? '' : 'codecs')
    ..aInt64(7, _omitFieldNames ? '' : 'estimatedBytes')
    ..aOS(8, _omitFieldNames ? '' : 'label')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadVariant clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadVariant copyWith(void Function(DownloadVariant) updates) =>
      super.copyWith((message) => updates(message as DownloadVariant))
          as DownloadVariant;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DownloadVariant() / DownloadVariant.new instead')
  static DownloadVariant create() => DownloadVariant._();
  static $pb.GeneratedMessage $_createMessage() => DownloadVariant._();
  @$core.override
  DownloadVariant createEmptyInstance() => DownloadVariant._();
  @$core.pragma('dart2js:noInline')
  static DownloadVariant getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DownloadVariant>(
          DownloadVariant.$_createMessage);
  static DownloadVariant? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get width => $_getIZ(1);
  @$pb.TagNumber(2)
  set width($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWidth() => $_has(1);
  @$pb.TagNumber(2)
  void clearWidth() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get height => $_getIZ(2);
  @$pb.TagNumber(3)
  set height($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeight() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeight() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get bandwidth => $_getI64(3);
  @$pb.TagNumber(4)
  set bandwidth($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBandwidth() => $_has(3);
  @$pb.TagNumber(4)
  void clearBandwidth() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get bandwidthIsPeak => $_getBF(4);
  @$pb.TagNumber(5)
  set bandwidthIsPeak($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBandwidthIsPeak() => $_has(4);
  @$pb.TagNumber(5)
  void clearBandwidthIsPeak() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get codecs => $_getSZ(5);
  @$pb.TagNumber(6)
  set codecs($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCodecs() => $_has(5);
  @$pb.TagNumber(6)
  void clearCodecs() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get estimatedBytes => $_getI64(6);
  @$pb.TagNumber(7)
  set estimatedBytes($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEstimatedBytes() => $_has(6);
  @$pb.TagNumber(7)
  void clearEstimatedBytes() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get label => $_getSZ(7);
  @$pb.TagNumber(8)
  set label($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLabel() => $_has(7);
  @$pb.TagNumber(8)
  void clearLabel() => $_clearField(8);
}

class DownloadTrack extends $pb.GeneratedMessage {
  factory DownloadTrack({
    $core.String? id,
    $core.String? language,
    $core.String? name,
    $core.bool? isDefault,
    $fixnum.Int64? estimatedBytes,
  }) {
    final result = DownloadTrack._();
    if (id != null) result.id = id;
    if (language != null) result.language = language;
    if (name != null) result.name = name;
    if (isDefault != null) result.isDefault = isDefault;
    if (estimatedBytes != null) result.estimatedBytes = estimatedBytes;
    return result;
  }

  DownloadTrack._();

  factory DownloadTrack.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadTrack()..mergeFromBuffer(data, registry);
  factory DownloadTrack.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadTrack()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DownloadTrack',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: DownloadTrack.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'language')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOB(4, _omitFieldNames ? '' : 'isDefault')
    ..aInt64(5, _omitFieldNames ? '' : 'estimatedBytes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadTrack clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadTrack copyWith(void Function(DownloadTrack) updates) =>
      super.copyWith((message) => updates(message as DownloadTrack))
          as DownloadTrack;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DownloadTrack() / DownloadTrack.new instead')
  static DownloadTrack create() => DownloadTrack._();
  static $pb.GeneratedMessage $_createMessage() => DownloadTrack._();
  @$core.override
  DownloadTrack createEmptyInstance() => DownloadTrack._();
  @$core.pragma('dart2js:noInline')
  static DownloadTrack getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DownloadTrack>(
          DownloadTrack.$_createMessage);
  static DownloadTrack? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get language => $_getSZ(1);
  @$pb.TagNumber(2)
  set language($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLanguage() => $_has(1);
  @$pb.TagNumber(2)
  void clearLanguage() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isDefault => $_getBF(3);
  @$pb.TagNumber(4)
  set isDefault($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsDefault() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsDefault() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get estimatedBytes => $_getI64(4);
  @$pb.TagNumber(5)
  set estimatedBytes($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEstimatedBytes() => $_has(4);
  @$pb.TagNumber(5)
  void clearEstimatedBytes() => $_clearField(5);
}

class DownloadOptionsResponse extends $pb.GeneratedMessage {
  factory DownloadOptionsResponse({
    $core.bool? available,
    $core.String? unavailableReason,
    $core.double? durationSec,
    $core.Iterable<DownloadVariant>? variants,
    $core.Iterable<DownloadTrack>? audio,
    $core.Iterable<DownloadTrack>? subtitles,
    $core.String? pluginNote,
    $core.String? pluginNotice,
    $core.String? preferredHours,
    $core.bool? qualityBelowUsual,
    $core.int? usualMaxHeight,
    $fixnum.Int64? serverFreeBytes,
    $fixnum.Int64? bytesPerSec,
    $core.int? retentionDays,
    $core.String? preferredHoursSource,
  }) {
    final result = DownloadOptionsResponse._();
    if (available != null) result.available = available;
    if (unavailableReason != null) result.unavailableReason = unavailableReason;
    if (durationSec != null) result.durationSec = durationSec;
    if (variants != null) result.variants.addAll(variants);
    if (audio != null) result.audio.addAll(audio);
    if (subtitles != null) result.subtitles.addAll(subtitles);
    if (pluginNote != null) result.pluginNote = pluginNote;
    if (pluginNotice != null) result.pluginNotice = pluginNotice;
    if (preferredHours != null) result.preferredHours = preferredHours;
    if (qualityBelowUsual != null) result.qualityBelowUsual = qualityBelowUsual;
    if (usualMaxHeight != null) result.usualMaxHeight = usualMaxHeight;
    if (serverFreeBytes != null) result.serverFreeBytes = serverFreeBytes;
    if (bytesPerSec != null) result.bytesPerSec = bytesPerSec;
    if (retentionDays != null) result.retentionDays = retentionDays;
    if (preferredHoursSource != null)
      result.preferredHoursSource = preferredHoursSource;
    return result;
  }

  DownloadOptionsResponse._();

  factory DownloadOptionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadOptionsResponse()..mergeFromBuffer(data, registry);
  factory DownloadOptionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadOptionsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DownloadOptionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: DownloadOptionsResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'available')
    ..aOS(2, _omitFieldNames ? '' : 'unavailableReason')
    ..aD(3, _omitFieldNames ? '' : 'durationSec')
    ..pPM<DownloadVariant>(4, _omitFieldNames ? '' : 'variants',
        subBuilder: DownloadVariant.$_createMessage)
    ..pPM<DownloadTrack>(5, _omitFieldNames ? '' : 'audio',
        subBuilder: DownloadTrack.$_createMessage)
    ..pPM<DownloadTrack>(6, _omitFieldNames ? '' : 'subtitles',
        subBuilder: DownloadTrack.$_createMessage)
    ..aOS(7, _omitFieldNames ? '' : 'pluginNote')
    ..aOS(8, _omitFieldNames ? '' : 'pluginNotice')
    ..aOS(9, _omitFieldNames ? '' : 'preferredHours')
    ..aOB(10, _omitFieldNames ? '' : 'qualityBelowUsual')
    ..aI(11, _omitFieldNames ? '' : 'usualMaxHeight')
    ..aInt64(12, _omitFieldNames ? '' : 'serverFreeBytes')
    ..aInt64(13, _omitFieldNames ? '' : 'bytesPerSec')
    ..aI(14, _omitFieldNames ? '' : 'retentionDays')
    ..aOS(15, _omitFieldNames ? '' : 'preferredHoursSource')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadOptionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadOptionsResponse copyWith(
          void Function(DownloadOptionsResponse) updates) =>
      super.copyWith((message) => updates(message as DownloadOptionsResponse))
          as DownloadOptionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DownloadOptionsResponse() / DownloadOptionsResponse.new instead')
  static DownloadOptionsResponse create() => DownloadOptionsResponse._();
  static $pb.GeneratedMessage $_createMessage() => DownloadOptionsResponse._();
  @$core.override
  DownloadOptionsResponse createEmptyInstance() => DownloadOptionsResponse._();
  @$core.pragma('dart2js:noInline')
  static DownloadOptionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DownloadOptionsResponse>(
          DownloadOptionsResponse.$_createMessage);
  static DownloadOptionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get available => $_getBF(0);
  @$pb.TagNumber(1)
  set available($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAvailable() => $_has(0);
  @$pb.TagNumber(1)
  void clearAvailable() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get unavailableReason => $_getSZ(1);
  @$pb.TagNumber(2)
  set unavailableReason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUnavailableReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearUnavailableReason() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get durationSec => $_getN(2);
  @$pb.TagNumber(3)
  set durationSec($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDurationSec() => $_has(2);
  @$pb.TagNumber(3)
  void clearDurationSec() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<DownloadVariant> get variants => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<DownloadTrack> get audio => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<DownloadTrack> get subtitles => $_getList(5);

  @$pb.TagNumber(7)
  $core.String get pluginNote => $_getSZ(6);
  @$pb.TagNumber(7)
  set pluginNote($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPluginNote() => $_has(6);
  @$pb.TagNumber(7)
  void clearPluginNote() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get pluginNotice => $_getSZ(7);
  @$pb.TagNumber(8)
  set pluginNotice($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPluginNotice() => $_has(7);
  @$pb.TagNumber(8)
  void clearPluginNotice() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get preferredHours => $_getSZ(8);
  @$pb.TagNumber(9)
  set preferredHours($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPreferredHours() => $_has(8);
  @$pb.TagNumber(9)
  void clearPreferredHours() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get qualityBelowUsual => $_getBF(9);
  @$pb.TagNumber(10)
  set qualityBelowUsual($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasQualityBelowUsual() => $_has(9);
  @$pb.TagNumber(10)
  void clearQualityBelowUsual() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get usualMaxHeight => $_getIZ(10);
  @$pb.TagNumber(11)
  set usualMaxHeight($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasUsualMaxHeight() => $_has(10);
  @$pb.TagNumber(11)
  void clearUsualMaxHeight() => $_clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get serverFreeBytes => $_getI64(11);
  @$pb.TagNumber(12)
  set serverFreeBytes($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasServerFreeBytes() => $_has(11);
  @$pb.TagNumber(12)
  void clearServerFreeBytes() => $_clearField(12);

  @$pb.TagNumber(13)
  $fixnum.Int64 get bytesPerSec => $_getI64(12);
  @$pb.TagNumber(13)
  set bytesPerSec($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(13)
  $core.bool hasBytesPerSec() => $_has(12);
  @$pb.TagNumber(13)
  void clearBytesPerSec() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get retentionDays => $_getIZ(13);
  @$pb.TagNumber(14)
  set retentionDays($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasRetentionDays() => $_has(13);
  @$pb.TagNumber(14)
  void clearRetentionDays() => $_clearField(14);

  /// Where preferred_hours comes from: "plugin" (manifest), "learned" (the
  /// server noticed this source serves its best quality in those hours), or
  /// "" when there is no suggestion.
  @$pb.TagNumber(15)
  $core.String get preferredHoursSource => $_getSZ(14);
  @$pb.TagNumber(15)
  set preferredHoursSource($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasPreferredHoursSource() => $_has(14);
  @$pb.TagNumber(15)
  void clearPreferredHoursSource() => $_clearField(15);
}

class CreateDownloadRequest extends $pb.GeneratedMessage {
  factory CreateDownloadRequest({
    $core.String? pluginId,
    $core.String? streamId,
    $core.String? variantId,
    $core.Iterable<$core.String>? audioIds,
    $core.Iterable<$core.String>? subtitleIds,
    $fixnum.Int64? notBefore,
    $core.bool? usePreferredHours,
    $core.String? mediaId,
    $core.String? parentId,
    $core.String? title,
    $core.String? seriesTitle,
    $core.String? poster,
    $core.int? seasonNumber,
    $core.int? episodeNumber,
    $core.bool? upgradeIfBetter,
  }) {
    final result = CreateDownloadRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    if (streamId != null) result.streamId = streamId;
    if (variantId != null) result.variantId = variantId;
    if (audioIds != null) result.audioIds.addAll(audioIds);
    if (subtitleIds != null) result.subtitleIds.addAll(subtitleIds);
    if (notBefore != null) result.notBefore = notBefore;
    if (usePreferredHours != null) result.usePreferredHours = usePreferredHours;
    if (mediaId != null) result.mediaId = mediaId;
    if (parentId != null) result.parentId = parentId;
    if (title != null) result.title = title;
    if (seriesTitle != null) result.seriesTitle = seriesTitle;
    if (poster != null) result.poster = poster;
    if (seasonNumber != null) result.seasonNumber = seasonNumber;
    if (episodeNumber != null) result.episodeNumber = episodeNumber;
    if (upgradeIfBetter != null) result.upgradeIfBetter = upgradeIfBetter;
    return result;
  }

  CreateDownloadRequest._();

  factory CreateDownloadRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateDownloadRequest()..mergeFromBuffer(data, registry);
  factory CreateDownloadRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateDownloadRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateDownloadRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: CreateDownloadRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'streamId')
    ..aOS(3, _omitFieldNames ? '' : 'variantId')
    ..pPS(4, _omitFieldNames ? '' : 'audioIds')
    ..pPS(5, _omitFieldNames ? '' : 'subtitleIds')
    ..aInt64(6, _omitFieldNames ? '' : 'notBefore')
    ..aOB(7, _omitFieldNames ? '' : 'usePreferredHours')
    ..aOS(8, _omitFieldNames ? '' : 'mediaId')
    ..aOS(9, _omitFieldNames ? '' : 'parentId')
    ..aOS(10, _omitFieldNames ? '' : 'title')
    ..aOS(11, _omitFieldNames ? '' : 'seriesTitle')
    ..aOS(12, _omitFieldNames ? '' : 'poster')
    ..aI(13, _omitFieldNames ? '' : 'seasonNumber')
    ..aI(14, _omitFieldNames ? '' : 'episodeNumber')
    ..aOB(15, _omitFieldNames ? '' : 'upgradeIfBetter')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateDownloadRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateDownloadRequest copyWith(
          void Function(CreateDownloadRequest) updates) =>
      super.copyWith((message) => updates(message as CreateDownloadRequest))
          as CreateDownloadRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CreateDownloadRequest() / CreateDownloadRequest.new instead')
  static CreateDownloadRequest create() => CreateDownloadRequest._();
  static $pb.GeneratedMessage $_createMessage() => CreateDownloadRequest._();
  @$core.override
  CreateDownloadRequest createEmptyInstance() => CreateDownloadRequest._();
  @$core.pragma('dart2js:noInline')
  static CreateDownloadRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateDownloadRequest>(
          CreateDownloadRequest.$_createMessage);
  static CreateDownloadRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get streamId => $_getSZ(1);
  @$pb.TagNumber(2)
  set streamId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStreamId() => $_has(1);
  @$pb.TagNumber(2)
  void clearStreamId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get variantId => $_getSZ(2);
  @$pb.TagNumber(3)
  set variantId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVariantId() => $_has(2);
  @$pb.TagNumber(3)
  void clearVariantId() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get audioIds => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get subtitleIds => $_getList(4);

  /// Schedule: not_before (unix seconds, 0 = now) and/or wait for the
  /// plugin's preferred_hours window.
  @$pb.TagNumber(6)
  $fixnum.Int64 get notBefore => $_getI64(5);
  @$pb.TagNumber(6)
  set notBefore($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNotBefore() => $_has(5);
  @$pb.TagNumber(6)
  void clearNotBefore() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get usePreferredHours => $_getBF(6);
  @$pb.TagNumber(7)
  set usePreferredHours($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUsePreferredHours() => $_has(6);
  @$pb.TagNumber(7)
  void clearUsePreferredHours() => $_clearField(7);

  /// Display metadata, so the download list works offline on its own.
  @$pb.TagNumber(8)
  $core.String get mediaId => $_getSZ(7);
  @$pb.TagNumber(8)
  set mediaId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMediaId() => $_has(7);
  @$pb.TagNumber(8)
  void clearMediaId() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get parentId => $_getSZ(8);
  @$pb.TagNumber(9)
  set parentId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasParentId() => $_has(8);
  @$pb.TagNumber(9)
  void clearParentId() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get title => $_getSZ(9);
  @$pb.TagNumber(10)
  set title($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTitle() => $_has(9);
  @$pb.TagNumber(10)
  void clearTitle() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get seriesTitle => $_getSZ(10);
  @$pb.TagNumber(11)
  set seriesTitle($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasSeriesTitle() => $_has(10);
  @$pb.TagNumber(11)
  void clearSeriesTitle() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get poster => $_getSZ(11);
  @$pb.TagNumber(12)
  set poster($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasPoster() => $_has(11);
  @$pb.TagNumber(12)
  void clearPoster() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get seasonNumber => $_getIZ(12);
  @$pb.TagNumber(13)
  set seasonNumber($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasSeasonNumber() => $_has(12);
  @$pb.TagNumber(13)
  void clearSeasonNumber() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get episodeNumber => $_getIZ(13);
  @$pb.TagNumber(14)
  set episodeNumber($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasEpisodeNumber() => $_has(13);
  @$pb.TagNumber(14)
  void clearEpisodeNumber() => $_clearField(14);

  /// If the file comes out below the quality this source usually reaches,
  /// try again in the recommended hours (up to 3 times) and replace it only
  /// with a better one.
  @$pb.TagNumber(15)
  $core.bool get upgradeIfBetter => $_getBF(14);
  @$pb.TagNumber(15)
  set upgradeIfBetter($core.bool value) => $_setBool(14, value);
  @$pb.TagNumber(15)
  $core.bool hasUpgradeIfBetter() => $_has(14);
  @$pb.TagNumber(15)
  void clearUpgradeIfBetter() => $_clearField(15);
}

/// CreateDownloads queues several streams of one plugin with the same
/// choices — e.g. a whole season. Ids are criteria (see CreateDownloadRequest),
/// so the variant/audio/subtitle ids taken from one episode's options apply
/// to every item. Each item still becomes its own download.
class CreateDownloadItem extends $pb.GeneratedMessage {
  factory CreateDownloadItem({
    $core.String? streamId,
    $core.String? mediaId,
    $core.String? parentId,
    $core.String? title,
    $core.String? seriesTitle,
    $core.String? poster,
    $core.int? seasonNumber,
    $core.int? episodeNumber,
  }) {
    final result = CreateDownloadItem._();
    if (streamId != null) result.streamId = streamId;
    if (mediaId != null) result.mediaId = mediaId;
    if (parentId != null) result.parentId = parentId;
    if (title != null) result.title = title;
    if (seriesTitle != null) result.seriesTitle = seriesTitle;
    if (poster != null) result.poster = poster;
    if (seasonNumber != null) result.seasonNumber = seasonNumber;
    if (episodeNumber != null) result.episodeNumber = episodeNumber;
    return result;
  }

  CreateDownloadItem._();

  factory CreateDownloadItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateDownloadItem()..mergeFromBuffer(data, registry);
  factory CreateDownloadItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateDownloadItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateDownloadItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: CreateDownloadItem.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'streamId')
    ..aOS(2, _omitFieldNames ? '' : 'mediaId')
    ..aOS(3, _omitFieldNames ? '' : 'parentId')
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aOS(5, _omitFieldNames ? '' : 'seriesTitle')
    ..aOS(6, _omitFieldNames ? '' : 'poster')
    ..aI(7, _omitFieldNames ? '' : 'seasonNumber')
    ..aI(8, _omitFieldNames ? '' : 'episodeNumber')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateDownloadItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateDownloadItem copyWith(void Function(CreateDownloadItem) updates) =>
      super.copyWith((message) => updates(message as CreateDownloadItem))
          as CreateDownloadItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CreateDownloadItem() / CreateDownloadItem.new instead')
  static CreateDownloadItem create() => CreateDownloadItem._();
  static $pb.GeneratedMessage $_createMessage() => CreateDownloadItem._();
  @$core.override
  CreateDownloadItem createEmptyInstance() => CreateDownloadItem._();
  @$core.pragma('dart2js:noInline')
  static CreateDownloadItem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateDownloadItem>(
          CreateDownloadItem.$_createMessage);
  static CreateDownloadItem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get streamId => $_getSZ(0);
  @$pb.TagNumber(1)
  set streamId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStreamId() => $_has(0);
  @$pb.TagNumber(1)
  void clearStreamId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mediaId => $_getSZ(1);
  @$pb.TagNumber(2)
  set mediaId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get parentId => $_getSZ(2);
  @$pb.TagNumber(3)
  set parentId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasParentId() => $_has(2);
  @$pb.TagNumber(3)
  void clearParentId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get seriesTitle => $_getSZ(4);
  @$pb.TagNumber(5)
  set seriesTitle($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSeriesTitle() => $_has(4);
  @$pb.TagNumber(5)
  void clearSeriesTitle() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get poster => $_getSZ(5);
  @$pb.TagNumber(6)
  set poster($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPoster() => $_has(5);
  @$pb.TagNumber(6)
  void clearPoster() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get seasonNumber => $_getIZ(6);
  @$pb.TagNumber(7)
  set seasonNumber($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSeasonNumber() => $_has(6);
  @$pb.TagNumber(7)
  void clearSeasonNumber() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get episodeNumber => $_getIZ(7);
  @$pb.TagNumber(8)
  set episodeNumber($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasEpisodeNumber() => $_has(7);
  @$pb.TagNumber(8)
  void clearEpisodeNumber() => $_clearField(8);
}

class CreateDownloadsRequest extends $pb.GeneratedMessage {
  factory CreateDownloadsRequest({
    $core.String? pluginId,
    $core.Iterable<CreateDownloadItem>? items,
    $core.String? variantId,
    $core.Iterable<$core.String>? audioIds,
    $core.Iterable<$core.String>? subtitleIds,
    $fixnum.Int64? notBefore,
    $core.bool? usePreferredHours,
    $core.bool? upgradeIfBetter,
  }) {
    final result = CreateDownloadsRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    if (items != null) result.items.addAll(items);
    if (variantId != null) result.variantId = variantId;
    if (audioIds != null) result.audioIds.addAll(audioIds);
    if (subtitleIds != null) result.subtitleIds.addAll(subtitleIds);
    if (notBefore != null) result.notBefore = notBefore;
    if (usePreferredHours != null) result.usePreferredHours = usePreferredHours;
    if (upgradeIfBetter != null) result.upgradeIfBetter = upgradeIfBetter;
    return result;
  }

  CreateDownloadsRequest._();

  factory CreateDownloadsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateDownloadsRequest()..mergeFromBuffer(data, registry);
  factory CreateDownloadsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateDownloadsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateDownloadsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: CreateDownloadsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..pPM<CreateDownloadItem>(2, _omitFieldNames ? '' : 'items',
        subBuilder: CreateDownloadItem.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'variantId')
    ..pPS(4, _omitFieldNames ? '' : 'audioIds')
    ..pPS(5, _omitFieldNames ? '' : 'subtitleIds')
    ..aInt64(6, _omitFieldNames ? '' : 'notBefore')
    ..aOB(7, _omitFieldNames ? '' : 'usePreferredHours')
    ..aOB(8, _omitFieldNames ? '' : 'upgradeIfBetter')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateDownloadsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateDownloadsRequest copyWith(
          void Function(CreateDownloadsRequest) updates) =>
      super.copyWith((message) => updates(message as CreateDownloadsRequest))
          as CreateDownloadsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CreateDownloadsRequest() / CreateDownloadsRequest.new instead')
  static CreateDownloadsRequest create() => CreateDownloadsRequest._();
  static $pb.GeneratedMessage $_createMessage() => CreateDownloadsRequest._();
  @$core.override
  CreateDownloadsRequest createEmptyInstance() => CreateDownloadsRequest._();
  @$core.pragma('dart2js:noInline')
  static CreateDownloadsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateDownloadsRequest>(
          CreateDownloadsRequest.$_createMessage);
  static CreateDownloadsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<CreateDownloadItem> get items => $_getList(1);

  @$pb.TagNumber(3)
  $core.String get variantId => $_getSZ(2);
  @$pb.TagNumber(3)
  set variantId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVariantId() => $_has(2);
  @$pb.TagNumber(3)
  void clearVariantId() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get audioIds => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get subtitleIds => $_getList(4);

  @$pb.TagNumber(6)
  $fixnum.Int64 get notBefore => $_getI64(5);
  @$pb.TagNumber(6)
  set notBefore($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNotBefore() => $_has(5);
  @$pb.TagNumber(6)
  void clearNotBefore() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get usePreferredHours => $_getBF(6);
  @$pb.TagNumber(7)
  set usePreferredHours($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUsePreferredHours() => $_has(6);
  @$pb.TagNumber(7)
  void clearUsePreferredHours() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get upgradeIfBetter => $_getBF(7);
  @$pb.TagNumber(8)
  set upgradeIfBetter($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasUpgradeIfBetter() => $_has(7);
  @$pb.TagNumber(8)
  void clearUpgradeIfBetter() => $_clearField(8);
}

class CreateDownloadsResponse extends $pb.GeneratedMessage {
  factory CreateDownloadsResponse({
    $core.Iterable<DownloadInfo>? downloads,
    $fixnum.Int64? estimatedTotalBytes,
  }) {
    final result = CreateDownloadsResponse._();
    if (downloads != null) result.downloads.addAll(downloads);
    if (estimatedTotalBytes != null)
      result.estimatedTotalBytes = estimatedTotalBytes;
    return result;
  }

  CreateDownloadsResponse._();

  factory CreateDownloadsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateDownloadsResponse()..mergeFromBuffer(data, registry);
  factory CreateDownloadsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateDownloadsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateDownloadsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: CreateDownloadsResponse.$_createMessage)
    ..pPM<DownloadInfo>(1, _omitFieldNames ? '' : 'downloads',
        subBuilder: DownloadInfo.$_createMessage)
    ..aInt64(2, _omitFieldNames ? '' : 'estimatedTotalBytes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateDownloadsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateDownloadsResponse copyWith(
          void Function(CreateDownloadsResponse) updates) =>
      super.copyWith((message) => updates(message as CreateDownloadsResponse))
          as CreateDownloadsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CreateDownloadsResponse() / CreateDownloadsResponse.new instead')
  static CreateDownloadsResponse create() => CreateDownloadsResponse._();
  static $pb.GeneratedMessage $_createMessage() => CreateDownloadsResponse._();
  @$core.override
  CreateDownloadsResponse createEmptyInstance() => CreateDownloadsResponse._();
  @$core.pragma('dart2js:noInline')
  static CreateDownloadsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateDownloadsResponse>(
          CreateDownloadsResponse.$_createMessage);
  static CreateDownloadsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DownloadInfo> get downloads => $_getList(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get estimatedTotalBytes => $_getI64(1);
  @$pb.TagNumber(2)
  set estimatedTotalBytes($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEstimatedTotalBytes() => $_has(1);
  @$pb.TagNumber(2)
  void clearEstimatedTotalBytes() => $_clearField(2);
}

class DownloadInfo extends $pb.GeneratedMessage {
  factory DownloadInfo({
    $core.String? downloadId,
    $core.String? pluginId,
    $core.String? streamId,
    $core.String? mediaId,
    $core.String? parentId,
    $core.String? title,
    $core.String? seriesTitle,
    $core.String? poster,
    $core.int? seasonNumber,
    $core.int? episodeNumber,
    $core.String? status,
    $core.String? error,
    $core.double? progress,
    $fixnum.Int64? estimatedBytes,
    $fixnum.Int64? fileBytes,
    $core.String? qualityLabel,
    $core.Iterable<$core.String>? audioLanguages,
    $core.Iterable<$core.String>? subtitleLanguages,
    $fixnum.Int64? createdAt,
    $fixnum.Int64? scheduledFor,
    $fixnum.Int64? completedAt,
    $fixnum.Int64? expiresAt,
    $core.String? fileUrl,
    $core.double? durationSec,
    $core.String? container,
    $core.bool? upgradePending,
    $core.bool? shared,
    $core.bool? fetched,
  }) {
    final result = DownloadInfo._();
    if (downloadId != null) result.downloadId = downloadId;
    if (pluginId != null) result.pluginId = pluginId;
    if (streamId != null) result.streamId = streamId;
    if (mediaId != null) result.mediaId = mediaId;
    if (parentId != null) result.parentId = parentId;
    if (title != null) result.title = title;
    if (seriesTitle != null) result.seriesTitle = seriesTitle;
    if (poster != null) result.poster = poster;
    if (seasonNumber != null) result.seasonNumber = seasonNumber;
    if (episodeNumber != null) result.episodeNumber = episodeNumber;
    if (status != null) result.status = status;
    if (error != null) result.error = error;
    if (progress != null) result.progress = progress;
    if (estimatedBytes != null) result.estimatedBytes = estimatedBytes;
    if (fileBytes != null) result.fileBytes = fileBytes;
    if (qualityLabel != null) result.qualityLabel = qualityLabel;
    if (audioLanguages != null) result.audioLanguages.addAll(audioLanguages);
    if (subtitleLanguages != null)
      result.subtitleLanguages.addAll(subtitleLanguages);
    if (createdAt != null) result.createdAt = createdAt;
    if (scheduledFor != null) result.scheduledFor = scheduledFor;
    if (completedAt != null) result.completedAt = completedAt;
    if (expiresAt != null) result.expiresAt = expiresAt;
    if (fileUrl != null) result.fileUrl = fileUrl;
    if (durationSec != null) result.durationSec = durationSec;
    if (container != null) result.container = container;
    if (upgradePending != null) result.upgradePending = upgradePending;
    if (shared != null) result.shared = shared;
    if (fetched != null) result.fetched = fetched;
    return result;
  }

  DownloadInfo._();

  factory DownloadInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadInfo()..mergeFromBuffer(data, registry);
  factory DownloadInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DownloadInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: DownloadInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'downloadId')
    ..aOS(2, _omitFieldNames ? '' : 'pluginId')
    ..aOS(3, _omitFieldNames ? '' : 'streamId')
    ..aOS(4, _omitFieldNames ? '' : 'mediaId')
    ..aOS(5, _omitFieldNames ? '' : 'parentId')
    ..aOS(6, _omitFieldNames ? '' : 'title')
    ..aOS(7, _omitFieldNames ? '' : 'seriesTitle')
    ..aOS(8, _omitFieldNames ? '' : 'poster')
    ..aI(9, _omitFieldNames ? '' : 'seasonNumber')
    ..aI(10, _omitFieldNames ? '' : 'episodeNumber')
    ..aOS(11, _omitFieldNames ? '' : 'status')
    ..aOS(12, _omitFieldNames ? '' : 'error')
    ..aD(13, _omitFieldNames ? '' : 'progress')
    ..aInt64(14, _omitFieldNames ? '' : 'estimatedBytes')
    ..aInt64(15, _omitFieldNames ? '' : 'fileBytes')
    ..aOS(16, _omitFieldNames ? '' : 'qualityLabel')
    ..pPS(17, _omitFieldNames ? '' : 'audioLanguages')
    ..pPS(18, _omitFieldNames ? '' : 'subtitleLanguages')
    ..aInt64(19, _omitFieldNames ? '' : 'createdAt')
    ..aInt64(20, _omitFieldNames ? '' : 'scheduledFor')
    ..aInt64(21, _omitFieldNames ? '' : 'completedAt')
    ..aInt64(22, _omitFieldNames ? '' : 'expiresAt')
    ..aOS(23, _omitFieldNames ? '' : 'fileUrl')
    ..aD(24, _omitFieldNames ? '' : 'durationSec')
    ..aOS(25, _omitFieldNames ? '' : 'container')
    ..aOB(26, _omitFieldNames ? '' : 'upgradePending')
    ..aOB(27, _omitFieldNames ? '' : 'shared')
    ..aOB(28, _omitFieldNames ? '' : 'fetched')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadInfo copyWith(void Function(DownloadInfo) updates) =>
      super.copyWith((message) => updates(message as DownloadInfo))
          as DownloadInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DownloadInfo() / DownloadInfo.new instead')
  static DownloadInfo create() => DownloadInfo._();
  static $pb.GeneratedMessage $_createMessage() => DownloadInfo._();
  @$core.override
  DownloadInfo createEmptyInstance() => DownloadInfo._();
  @$core.pragma('dart2js:noInline')
  static DownloadInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DownloadInfo>(
          DownloadInfo.$_createMessage);
  static DownloadInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get downloadId => $_getSZ(0);
  @$pb.TagNumber(1)
  set downloadId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDownloadId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDownloadId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get pluginId => $_getSZ(1);
  @$pb.TagNumber(2)
  set pluginId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPluginId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPluginId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get streamId => $_getSZ(2);
  @$pb.TagNumber(3)
  set streamId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStreamId() => $_has(2);
  @$pb.TagNumber(3)
  void clearStreamId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get mediaId => $_getSZ(3);
  @$pb.TagNumber(4)
  set mediaId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMediaId() => $_has(3);
  @$pb.TagNumber(4)
  void clearMediaId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get parentId => $_getSZ(4);
  @$pb.TagNumber(5)
  set parentId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasParentId() => $_has(4);
  @$pb.TagNumber(5)
  void clearParentId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get title => $_getSZ(5);
  @$pb.TagNumber(6)
  set title($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTitle() => $_has(5);
  @$pb.TagNumber(6)
  void clearTitle() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get seriesTitle => $_getSZ(6);
  @$pb.TagNumber(7)
  set seriesTitle($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSeriesTitle() => $_has(6);
  @$pb.TagNumber(7)
  void clearSeriesTitle() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get poster => $_getSZ(7);
  @$pb.TagNumber(8)
  set poster($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPoster() => $_has(7);
  @$pb.TagNumber(8)
  void clearPoster() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get seasonNumber => $_getIZ(8);
  @$pb.TagNumber(9)
  set seasonNumber($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSeasonNumber() => $_has(8);
  @$pb.TagNumber(9)
  void clearSeasonNumber() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get episodeNumber => $_getIZ(9);
  @$pb.TagNumber(10)
  set episodeNumber($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasEpisodeNumber() => $_has(9);
  @$pb.TagNumber(10)
  void clearEpisodeNumber() => $_clearField(10);

  /// queued | scheduled | running | paused | completed | failed | canceled
  /// (paused: waiting while someone is watching something, see the server's
  /// "pause downloads while streaming" setting — it resumes by itself)
  @$pb.TagNumber(11)
  $core.String get status => $_getSZ(10);
  @$pb.TagNumber(11)
  set status($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasStatus() => $_has(10);
  @$pb.TagNumber(11)
  void clearStatus() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get error => $_getSZ(11);
  @$pb.TagNumber(12)
  set error($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasError() => $_has(11);
  @$pb.TagNumber(12)
  void clearError() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.double get progress => $_getN(12);
  @$pb.TagNumber(13)
  set progress($core.double value) => $_setDouble(12, value);
  @$pb.TagNumber(13)
  $core.bool hasProgress() => $_has(12);
  @$pb.TagNumber(13)
  void clearProgress() => $_clearField(13);

  @$pb.TagNumber(14)
  $fixnum.Int64 get estimatedBytes => $_getI64(13);
  @$pb.TagNumber(14)
  set estimatedBytes($fixnum.Int64 value) => $_setInt64(13, value);
  @$pb.TagNumber(14)
  $core.bool hasEstimatedBytes() => $_has(13);
  @$pb.TagNumber(14)
  void clearEstimatedBytes() => $_clearField(14);

  @$pb.TagNumber(15)
  $fixnum.Int64 get fileBytes => $_getI64(14);
  @$pb.TagNumber(15)
  set fileBytes($fixnum.Int64 value) => $_setInt64(14, value);
  @$pb.TagNumber(15)
  $core.bool hasFileBytes() => $_has(14);
  @$pb.TagNumber(15)
  void clearFileBytes() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get qualityLabel => $_getSZ(15);
  @$pb.TagNumber(16)
  set qualityLabel($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasQualityLabel() => $_has(15);
  @$pb.TagNumber(16)
  void clearQualityLabel() => $_clearField(16);

  @$pb.TagNumber(17)
  $pb.PbList<$core.String> get audioLanguages => $_getList(16);

  @$pb.TagNumber(18)
  $pb.PbList<$core.String> get subtitleLanguages => $_getList(17);

  @$pb.TagNumber(19)
  $fixnum.Int64 get createdAt => $_getI64(18);
  @$pb.TagNumber(19)
  set createdAt($fixnum.Int64 value) => $_setInt64(18, value);
  @$pb.TagNumber(19)
  $core.bool hasCreatedAt() => $_has(18);
  @$pb.TagNumber(19)
  void clearCreatedAt() => $_clearField(19);

  @$pb.TagNumber(20)
  $fixnum.Int64 get scheduledFor => $_getI64(19);
  @$pb.TagNumber(20)
  set scheduledFor($fixnum.Int64 value) => $_setInt64(19, value);
  @$pb.TagNumber(20)
  $core.bool hasScheduledFor() => $_has(19);
  @$pb.TagNumber(20)
  void clearScheduledFor() => $_clearField(20);

  @$pb.TagNumber(21)
  $fixnum.Int64 get completedAt => $_getI64(20);
  @$pb.TagNumber(21)
  set completedAt($fixnum.Int64 value) => $_setInt64(20, value);
  @$pb.TagNumber(21)
  $core.bool hasCompletedAt() => $_has(20);
  @$pb.TagNumber(21)
  void clearCompletedAt() => $_clearField(21);

  @$pb.TagNumber(22)
  $fixnum.Int64 get expiresAt => $_getI64(21);
  @$pb.TagNumber(22)
  set expiresAt($fixnum.Int64 value) => $_setInt64(21, value);
  @$pb.TagNumber(22)
  $core.bool hasExpiresAt() => $_has(21);
  @$pb.TagNumber(22)
  void clearExpiresAt() => $_clearField(22);

  @$pb.TagNumber(23)
  $core.String get fileUrl => $_getSZ(22);
  @$pb.TagNumber(23)
  set fileUrl($core.String value) => $_setString(22, value);
  @$pb.TagNumber(23)
  $core.bool hasFileUrl() => $_has(22);
  @$pb.TagNumber(23)
  void clearFileUrl() => $_clearField(23);

  @$pb.TagNumber(24)
  $core.double get durationSec => $_getN(23);
  @$pb.TagNumber(24)
  set durationSec($core.double value) => $_setDouble(23, value);
  @$pb.TagNumber(24)
  $core.bool hasDurationSec() => $_has(23);
  @$pb.TagNumber(24)
  void clearDurationSec() => $_clearField(24);

  @$pb.TagNumber(25)
  $core.String get container => $_getSZ(24);
  @$pb.TagNumber(25)
  set container($core.String value) => $_setString(24, value);
  @$pb.TagNumber(25)
  $core.bool hasContainer() => $_has(24);
  @$pb.TagNumber(25)
  void clearContainer() => $_clearField(25);

  @$pb.TagNumber(26)
  $core.bool get upgradePending => $_getBF(25);
  @$pb.TagNumber(26)
  set upgradePending($core.bool value) => $_setBool(25, value);
  @$pb.TagNumber(26)
  $core.bool hasUpgradePending() => $_has(25);
  @$pb.TagNumber(26)
  void clearUpgradePending() => $_clearField(26);

  @$pb.TagNumber(27)
  $core.bool get shared => $_getBF(26);
  @$pb.TagNumber(27)
  set shared($core.bool value) => $_setBool(26, value);
  @$pb.TagNumber(27)
  $core.bool hasShared() => $_has(26);
  @$pb.TagNumber(27)
  void clearShared() => $_clearField(27);

  @$pb.TagNumber(28)
  $core.bool get fetched => $_getBF(27);
  @$pb.TagNumber(28)
  set fetched($core.bool value) => $_setBool(27, value);
  @$pb.TagNumber(28)
  $core.bool hasFetched() => $_has(27);
  @$pb.TagNumber(28)
  void clearFetched() => $_clearField(28);
}

class ListDownloadsRequest extends $pb.GeneratedMessage {
  factory ListDownloadsRequest() => ListDownloadsRequest._();

  ListDownloadsRequest._();

  factory ListDownloadsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListDownloadsRequest()..mergeFromBuffer(data, registry);
  factory ListDownloadsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListDownloadsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListDownloadsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: ListDownloadsRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDownloadsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDownloadsRequest copyWith(void Function(ListDownloadsRequest) updates) =>
      super.copyWith((message) => updates(message as ListDownloadsRequest))
          as ListDownloadsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListDownloadsRequest() / ListDownloadsRequest.new instead')
  static ListDownloadsRequest create() => ListDownloadsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListDownloadsRequest._();
  @$core.override
  ListDownloadsRequest createEmptyInstance() => ListDownloadsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListDownloadsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListDownloadsRequest>(
          ListDownloadsRequest.$_createMessage);
  static ListDownloadsRequest? _defaultInstance;
}

class ListDownloadsResponse extends $pb.GeneratedMessage {
  factory ListDownloadsResponse({
    $core.Iterable<DownloadInfo>? downloads,
    $fixnum.Int64? serverFreeBytes,
    $fixnum.Int64? quotaBytes,
    $fixnum.Int64? usedBytes,
  }) {
    final result = ListDownloadsResponse._();
    if (downloads != null) result.downloads.addAll(downloads);
    if (serverFreeBytes != null) result.serverFreeBytes = serverFreeBytes;
    if (quotaBytes != null) result.quotaBytes = quotaBytes;
    if (usedBytes != null) result.usedBytes = usedBytes;
    return result;
  }

  ListDownloadsResponse._();

  factory ListDownloadsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListDownloadsResponse()..mergeFromBuffer(data, registry);
  factory ListDownloadsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListDownloadsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListDownloadsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: ListDownloadsResponse.$_createMessage)
    ..pPM<DownloadInfo>(1, _omitFieldNames ? '' : 'downloads',
        subBuilder: DownloadInfo.$_createMessage)
    ..aInt64(2, _omitFieldNames ? '' : 'serverFreeBytes')
    ..aInt64(3, _omitFieldNames ? '' : 'quotaBytes')
    ..aInt64(4, _omitFieldNames ? '' : 'usedBytes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDownloadsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDownloadsResponse copyWith(
          void Function(ListDownloadsResponse) updates) =>
      super.copyWith((message) => updates(message as ListDownloadsResponse))
          as ListDownloadsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListDownloadsResponse() / ListDownloadsResponse.new instead')
  static ListDownloadsResponse create() => ListDownloadsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListDownloadsResponse._();
  @$core.override
  ListDownloadsResponse createEmptyInstance() => ListDownloadsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListDownloadsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListDownloadsResponse>(
          ListDownloadsResponse.$_createMessage);
  static ListDownloadsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DownloadInfo> get downloads => $_getList(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get serverFreeBytes => $_getI64(1);
  @$pb.TagNumber(2)
  set serverFreeBytes($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasServerFreeBytes() => $_has(1);
  @$pb.TagNumber(2)
  void clearServerFreeBytes() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get quotaBytes => $_getI64(2);
  @$pb.TagNumber(3)
  set quotaBytes($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasQuotaBytes() => $_has(2);
  @$pb.TagNumber(3)
  void clearQuotaBytes() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get usedBytes => $_getI64(3);
  @$pb.TagNumber(4)
  set usedBytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUsedBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearUsedBytes() => $_clearField(4);
}

class DownloadIdRequest extends $pb.GeneratedMessage {
  factory DownloadIdRequest({
    $core.String? downloadId,
  }) {
    final result = DownloadIdRequest._();
    if (downloadId != null) result.downloadId = downloadId;
    return result;
  }

  DownloadIdRequest._();

  factory DownloadIdRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadIdRequest()..mergeFromBuffer(data, registry);
  factory DownloadIdRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadIdRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DownloadIdRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: DownloadIdRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'downloadId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadIdRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadIdRequest copyWith(void Function(DownloadIdRequest) updates) =>
      super.copyWith((message) => updates(message as DownloadIdRequest))
          as DownloadIdRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DownloadIdRequest() / DownloadIdRequest.new instead')
  static DownloadIdRequest create() => DownloadIdRequest._();
  static $pb.GeneratedMessage $_createMessage() => DownloadIdRequest._();
  @$core.override
  DownloadIdRequest createEmptyInstance() => DownloadIdRequest._();
  @$core.pragma('dart2js:noInline')
  static DownloadIdRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DownloadIdRequest>(
          DownloadIdRequest.$_createMessage);
  static DownloadIdRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get downloadId => $_getSZ(0);
  @$pb.TagNumber(1)
  set downloadId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDownloadId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDownloadId() => $_clearField(1);
}

class DownloadActionResponse extends $pb.GeneratedMessage {
  factory DownloadActionResponse({
    $core.bool? ok,
  }) {
    final result = DownloadActionResponse._();
    if (ok != null) result.ok = ok;
    return result;
  }

  DownloadActionResponse._();

  factory DownloadActionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadActionResponse()..mergeFromBuffer(data, registry);
  factory DownloadActionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownloadActionResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DownloadActionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: DownloadActionResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadActionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadActionResponse copyWith(
          void Function(DownloadActionResponse) updates) =>
      super.copyWith((message) => updates(message as DownloadActionResponse))
          as DownloadActionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DownloadActionResponse() / DownloadActionResponse.new instead')
  static DownloadActionResponse create() => DownloadActionResponse._();
  static $pb.GeneratedMessage $_createMessage() => DownloadActionResponse._();
  @$core.override
  DownloadActionResponse createEmptyInstance() => DownloadActionResponse._();
  @$core.pragma('dart2js:noInline')
  static DownloadActionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DownloadActionResponse>(
          DownloadActionResponse.$_createMessage);
  static DownloadActionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);
}

/// ─── My List ("La mia lista") ─────────────────────────────────────────────────
/// Titles a profile saved to watch later, kept per profile on the server so the
/// list follows the profile across devices. The client sends the card fields it
/// already has (from a catalog item or a details page): the server stores them
/// as-is and never asks the plugin again.
class MyListItem extends $pb.GeneratedMessage {
  factory MyListItem({
    $core.String? pluginId,
    $core.String? mediaId,
    $core.String? title,
    $core.String? posterUrl,
    $core.String? mediaType,
    $core.int? year,
    $core.double? rating,
    $core.String? fanartUrl,
    $core.String? logoUrl,
    $fixnum.Int64? addedAt,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? extra,
    LogoMeta? logoMeta,
  }) {
    final result = MyListItem._();
    if (pluginId != null) result.pluginId = pluginId;
    if (mediaId != null) result.mediaId = mediaId;
    if (title != null) result.title = title;
    if (posterUrl != null) result.posterUrl = posterUrl;
    if (mediaType != null) result.mediaType = mediaType;
    if (year != null) result.year = year;
    if (rating != null) result.rating = rating;
    if (fanartUrl != null) result.fanartUrl = fanartUrl;
    if (logoUrl != null) result.logoUrl = logoUrl;
    if (addedAt != null) result.addedAt = addedAt;
    if (extra != null) result.extra.addEntries(extra);
    if (logoMeta != null) result.logoMeta = logoMeta;
    return result;
  }

  MyListItem._();

  factory MyListItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MyListItem()..mergeFromBuffer(data, registry);
  factory MyListItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MyListItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MyListItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: MyListItem.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'mediaId')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOS(4, _omitFieldNames ? '' : 'posterUrl')
    ..aOS(5, _omitFieldNames ? '' : 'mediaType')
    ..aI(6, _omitFieldNames ? '' : 'year')
    ..aD(7, _omitFieldNames ? '' : 'rating')
    ..aOS(8, _omitFieldNames ? '' : 'fanartUrl')
    ..aOS(9, _omitFieldNames ? '' : 'logoUrl')
    ..aInt64(10, _omitFieldNames ? '' : 'addedAt')
    ..m<$core.String, $core.String>(11, _omitFieldNames ? '' : 'extra',
        entryClassName: 'MyListItem.ExtraEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('mycelium'))
    ..aOM<LogoMeta>(12, _omitFieldNames ? '' : 'logoMeta',
        subBuilder: LogoMeta.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MyListItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MyListItem copyWith(void Function(MyListItem) updates) =>
      super.copyWith((message) => updates(message as MyListItem)) as MyListItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MyListItem() / MyListItem.new instead')
  static MyListItem create() => MyListItem._();
  static $pb.GeneratedMessage $_createMessage() => MyListItem._();
  @$core.override
  MyListItem createEmptyInstance() => MyListItem._();
  @$core.pragma('dart2js:noInline')
  static MyListItem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MyListItem>(MyListItem.$_createMessage);
  static MyListItem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mediaId => $_getSZ(1);
  @$pb.TagNumber(2)
  set mediaId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get posterUrl => $_getSZ(3);
  @$pb.TagNumber(4)
  set posterUrl($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPosterUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearPosterUrl() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get mediaType => $_getSZ(4);
  @$pb.TagNumber(5)
  set mediaType($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMediaType() => $_has(4);
  @$pb.TagNumber(5)
  void clearMediaType() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get year => $_getIZ(5);
  @$pb.TagNumber(6)
  set year($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasYear() => $_has(5);
  @$pb.TagNumber(6)
  void clearYear() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.double get rating => $_getN(6);
  @$pb.TagNumber(7)
  set rating($core.double value) => $_setDouble(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRating() => $_has(6);
  @$pb.TagNumber(7)
  void clearRating() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get fanartUrl => $_getSZ(7);
  @$pb.TagNumber(8)
  set fanartUrl($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasFanartUrl() => $_has(7);
  @$pb.TagNumber(8)
  void clearFanartUrl() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get logoUrl => $_getSZ(8);
  @$pb.TagNumber(9)
  set logoUrl($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLogoUrl() => $_has(8);
  @$pb.TagNumber(9)
  void clearLogoUrl() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get addedAt => $_getI64(9);
  @$pb.TagNumber(10)
  set addedAt($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasAddedAt() => $_has(9);
  @$pb.TagNumber(10)
  void clearAddedAt() => $_clearField(10);

  /// Same keys as CatalogItem.extra (plot, genres, cover_url, anilist_id…):
  /// what a card needs when it is shown again, with no call to the plugin.
  @$pb.TagNumber(11)
  $pb.PbMap<$core.String, $core.String> get extra => $_getMap(10);

  @$pb.TagNumber(12)
  LogoMeta get logoMeta => $_getN(11);
  @$pb.TagNumber(12)
  set logoMeta(LogoMeta value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasLogoMeta() => $_has(11);
  @$pb.TagNumber(12)
  void clearLogoMeta() => $_clearField(12);
  @$pb.TagNumber(12)
  LogoMeta ensureLogoMeta() => $_ensure(11);
}

/// Empty plugin_id = every plugin, most recently added first.
class MyListRequest extends $pb.GeneratedMessage {
  factory MyListRequest({
    $core.String? pluginId,
  }) {
    final result = MyListRequest._();
    if (pluginId != null) result.pluginId = pluginId;
    return result;
  }

  MyListRequest._();

  factory MyListRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MyListRequest()..mergeFromBuffer(data, registry);
  factory MyListRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MyListRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MyListRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: MyListRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MyListRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MyListRequest copyWith(void Function(MyListRequest) updates) =>
      super.copyWith((message) => updates(message as MyListRequest))
          as MyListRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MyListRequest() / MyListRequest.new instead')
  static MyListRequest create() => MyListRequest._();
  static $pb.GeneratedMessage $_createMessage() => MyListRequest._();
  @$core.override
  MyListRequest createEmptyInstance() => MyListRequest._();
  @$core.pragma('dart2js:noInline')
  static MyListRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MyListRequest>(
          MyListRequest.$_createMessage);
  static MyListRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pluginId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pluginId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPluginId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPluginId() => $_clearField(1);
}

class MyListResponse extends $pb.GeneratedMessage {
  factory MyListResponse({
    $core.Iterable<MyListItem>? items,
  }) {
    final result = MyListResponse._();
    if (items != null) result.items.addAll(items);
    return result;
  }

  MyListResponse._();

  factory MyListResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MyListResponse()..mergeFromBuffer(data, registry);
  factory MyListResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MyListResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MyListResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: MyListResponse.$_createMessage)
    ..pPM<MyListItem>(1, _omitFieldNames ? '' : 'items',
        subBuilder: MyListItem.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MyListResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MyListResponse copyWith(void Function(MyListResponse) updates) =>
      super.copyWith((message) => updates(message as MyListResponse))
          as MyListResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MyListResponse() / MyListResponse.new instead')
  static MyListResponse create() => MyListResponse._();
  static $pb.GeneratedMessage $_createMessage() => MyListResponse._();
  @$core.override
  MyListResponse createEmptyInstance() => MyListResponse._();
  @$core.pragma('dart2js:noInline')
  static MyListResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MyListResponse>(
          MyListResponse.$_createMessage);
  static MyListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<MyListItem> get items => $_getList(0);
}

/// in_list = true adds (or refreshes) item, false removes it — only
/// item.plugin_id/media_id matter then. Idempotent both ways.
class SetMyListItemRequest extends $pb.GeneratedMessage {
  factory SetMyListItemRequest({
    MyListItem? item,
    $core.bool? inList,
  }) {
    final result = SetMyListItemRequest._();
    if (item != null) result.item = item;
    if (inList != null) result.inList = inList;
    return result;
  }

  SetMyListItemRequest._();

  factory SetMyListItemRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetMyListItemRequest()..mergeFromBuffer(data, registry);
  factory SetMyListItemRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetMyListItemRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetMyListItemRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: SetMyListItemRequest.$_createMessage)
    ..aOM<MyListItem>(1, _omitFieldNames ? '' : 'item',
        subBuilder: MyListItem.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'inList')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMyListItemRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMyListItemRequest copyWith(void Function(SetMyListItemRequest) updates) =>
      super.copyWith((message) => updates(message as SetMyListItemRequest))
          as SetMyListItemRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetMyListItemRequest() / SetMyListItemRequest.new instead')
  static SetMyListItemRequest create() => SetMyListItemRequest._();
  static $pb.GeneratedMessage $_createMessage() => SetMyListItemRequest._();
  @$core.override
  SetMyListItemRequest createEmptyInstance() => SetMyListItemRequest._();
  @$core.pragma('dart2js:noInline')
  static SetMyListItemRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetMyListItemRequest>(
          SetMyListItemRequest.$_createMessage);
  static SetMyListItemRequest? _defaultInstance;

  @$pb.TagNumber(1)
  MyListItem get item => $_getN(0);
  @$pb.TagNumber(1)
  set item(MyListItem value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasItem() => $_has(0);
  @$pb.TagNumber(1)
  void clearItem() => $_clearField(1);
  @$pb.TagNumber(1)
  MyListItem ensureItem() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get inList => $_getBF(1);
  @$pb.TagNumber(2)
  set inList($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasInList() => $_has(1);
  @$pb.TagNumber(2)
  void clearInList() => $_clearField(2);
}

class SetMyListItemResponse extends $pb.GeneratedMessage {
  factory SetMyListItemResponse({
    $core.bool? ok,
  }) {
    final result = SetMyListItemResponse._();
    if (ok != null) result.ok = ok;
    return result;
  }

  SetMyListItemResponse._();

  factory SetMyListItemResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetMyListItemResponse()..mergeFromBuffer(data, registry);
  factory SetMyListItemResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetMyListItemResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetMyListItemResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: SetMyListItemResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMyListItemResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMyListItemResponse copyWith(
          void Function(SetMyListItemResponse) updates) =>
      super.copyWith((message) => updates(message as SetMyListItemResponse))
          as SetMyListItemResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetMyListItemResponse() / SetMyListItemResponse.new instead')
  static SetMyListItemResponse create() => SetMyListItemResponse._();
  static $pb.GeneratedMessage $_createMessage() => SetMyListItemResponse._();
  @$core.override
  SetMyListItemResponse createEmptyInstance() => SetMyListItemResponse._();
  @$core.pragma('dart2js:noInline')
  static SetMyListItemResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetMyListItemResponse>(
          SetMyListItemResponse.$_createMessage);
  static SetMyListItemResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
