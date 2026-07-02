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
/// Plugins must return JSON with these exact field names.
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
  }) {
    final result = create();
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
    return result;
  }

  CatalogItem._();

  factory CatalogItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CatalogItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CatalogItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static CatalogItem create() => CatalogItem._();
  @$core.override
  CatalogItem createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CatalogItem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CatalogItem>(create);
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

  /// logo_url: transparent PNG/SVG wordmark
  @$pb.TagNumber(16)
  $core.String get logoUrl => $_getSZ(15);
  @$pb.TagNumber(16)
  set logoUrl($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasLogoUrl() => $_has(15);
  @$pb.TagNumber(16)
  void clearLogoUrl() => $_clearField(16);

  /// banner_url: wide landscape image
  @$pb.TagNumber(17)
  $core.String get bannerUrl => $_getSZ(16);
  @$pb.TagNumber(17)
  set bannerUrl($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasBannerUrl() => $_has(16);
  @$pb.TagNumber(17)
  void clearBannerUrl() => $_clearField(17);
}

/// EpisodeInfo is the rich episode object returned when browsing a season.
/// Rich episode metadata.
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
  }) {
    final result = create();
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
    return result;
  }

  EpisodeInfo._();

  factory EpisodeInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EpisodeInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EpisodeInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static EpisodeInfo create() => EpisodeInfo._();
  @$core.override
  EpisodeInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EpisodeInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EpisodeInfo>(create);
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
    final result = create();
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
      create()..mergeFromBuffer(data, registry);
  factory SeasonInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SeasonInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static SeasonInfo create() => SeasonInfo._();
  @$core.override
  SeasonInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SeasonInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SeasonInfo>(create);
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
    final result = create();
    if (pluginId != null) result.pluginId = pluginId;
    if (catalogId != null) result.catalogId = catalogId;
    if (page != null) result.page = page;
    return result;
  }

  CatalogRequest._();

  factory CatalogRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CatalogRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CatalogRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static CatalogRequest create() => CatalogRequest._();
  @$core.override
  CatalogRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CatalogRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CatalogRequest>(create);
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
    final result = create();
    if (items != null) result.items.addAll(items);
    if (hasMore != null) result.hasMore = hasMore;
    return result;
  }

  CatalogResponse._();

  factory CatalogResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CatalogResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CatalogResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..pPM<CatalogItem>(1, _omitFieldNames ? '' : 'items',
        subBuilder: CatalogItem.create)
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
  static CatalogResponse create() => CatalogResponse._();
  @$core.override
  CatalogResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CatalogResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CatalogResponse>(create);
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
    final result = create();
    if (id != null) result.id = id;
    if (label != null) result.label = label;
    if (type != null) result.type = type;
    if (options != null) result.options.addAll(options);
    return result;
  }

  SearchFilter._();

  factory SearchFilter.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchFilter.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchFilter',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOS(3, _omitFieldNames ? '' : 'type')
    ..pPM<FilterOption>(4, _omitFieldNames ? '' : 'options',
        subBuilder: FilterOption.create)
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
  static SearchFilter create() => SearchFilter._();
  @$core.override
  SearchFilter createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SearchFilter getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchFilter>(create);
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

  /// type: "select"|"bool"|"number"
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
    final result = create();
    if (id != null) result.id = id;
    if (label != null) result.label = label;
    return result;
  }

  FilterOption._();

  factory FilterOption.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FilterOption.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FilterOption',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static FilterOption create() => FilterOption._();
  @$core.override
  FilterOption createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FilterOption getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FilterOption>(create);
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
    final result = create();
    if (pluginId != null) result.pluginId = pluginId;
    return result;
  }

  SearchFiltersRequest._();

  factory SearchFiltersRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchFiltersRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchFiltersRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static SearchFiltersRequest create() => SearchFiltersRequest._();
  @$core.override
  SearchFiltersRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SearchFiltersRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchFiltersRequest>(create);
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
    final result = create();
    if (filters != null) result.filters.addAll(filters);
    return result;
  }

  SearchFiltersResponse._();

  factory SearchFiltersResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchFiltersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchFiltersResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..pPM<SearchFilter>(1, _omitFieldNames ? '' : 'filters',
        subBuilder: SearchFilter.create)
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
  static SearchFiltersResponse create() => SearchFiltersResponse._();
  @$core.override
  SearchFiltersResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SearchFiltersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchFiltersResponse>(create);
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
    final result = create();
    if (pluginId != null) result.pluginId = pluginId;
    if (query != null) result.query = query;
    if (page != null) result.page = page;
    if (filters != null) result.filters.addEntries(filters);
    return result;
  }

  SearchRequest._();

  factory SearchRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static SearchRequest create() => SearchRequest._();
  @$core.override
  SearchRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SearchRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchRequest>(create);
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
    final result = create();
    if (items != null) result.items.addAll(items);
    if (hasMore != null) result.hasMore = hasMore;
    return result;
  }

  SearchResponse._();

  factory SearchResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..pPM<CatalogItem>(1, _omitFieldNames ? '' : 'items',
        subBuilder: CatalogItem.create)
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
  static SearchResponse create() => SearchResponse._();
  @$core.override
  SearchResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SearchResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchResponse>(create);
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
    final result = create();
    if (pluginId != null) result.pluginId = pluginId;
    if (mediaId != null) result.mediaId = mediaId;
    return result;
  }

  DetailsRequest._();

  factory DetailsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DetailsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DetailsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static DetailsRequest create() => DetailsRequest._();
  @$core.override
  DetailsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DetailsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DetailsRequest>(create);
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
  }) {
    final result = create();
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
    return result;
  }

  MovieDetails._();

  factory MovieDetails.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MovieDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MovieDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static MovieDetails create() => MovieDetails._();
  @$core.override
  MovieDetails createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MovieDetails getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MovieDetails>(create);
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
  }) {
    final result = create();
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
    return result;
  }

  SeriesDetails._();

  factory SeriesDetails.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SeriesDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SeriesDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
        subBuilder: SeasonInfo.create)
    ..aOS(15, _omitFieldNames ? '' : 'logoUrl')
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
  static SeriesDetails create() => SeriesDetails._();
  @$core.override
  SeriesDetails createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SeriesDetails getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SeriesDetails>(create);
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
    final result = create();
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
      create()..mergeFromBuffer(data, registry);
  factory EpisodeDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EpisodeDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static EpisodeDetails create() => EpisodeDetails._();
  @$core.override
  EpisodeDetails createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EpisodeDetails getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EpisodeDetails>(create);
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
    final result = create();
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
      create()..mergeFromBuffer(data, registry);
  factory LiveDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LiveDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static LiveDetails create() => LiveDetails._();
  @$core.override
  LiveDetails createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LiveDetails getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LiveDetails>(create);
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
    final result = create();
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
      create()..mergeFromBuffer(data, registry);
  factory VideoDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VideoDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static VideoDetails create() => VideoDetails._();
  @$core.override
  VideoDetails createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static VideoDetails getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VideoDetails>(create);
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
    final result = create();
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
      create()..mergeFromBuffer(data, registry);
  factory MusicDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MusicDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static MusicDetails create() => MusicDetails._();
  @$core.override
  MusicDetails createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MusicDetails getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MusicDetails>(create);
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
    final result = create();
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
      create()..mergeFromBuffer(data, registry);
  factory PodcastDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PodcastDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static PodcastDetails create() => PodcastDetails._();
  @$core.override
  PodcastDetails createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PodcastDetails getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PodcastDetails>(create);
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
    final result = create();
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
      create()..mergeFromBuffer(data, registry);
  factory DetailsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

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
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5, 6, 7, 8])
    ..aOM<CatalogItem>(1, _omitFieldNames ? '' : 'item',
        subBuilder: CatalogItem.create)
    ..aOM<MovieDetails>(2, _omitFieldNames ? '' : 'movie',
        subBuilder: MovieDetails.create)
    ..aOM<SeriesDetails>(3, _omitFieldNames ? '' : 'series',
        subBuilder: SeriesDetails.create)
    ..aOM<EpisodeDetails>(4, _omitFieldNames ? '' : 'episode',
        subBuilder: EpisodeDetails.create)
    ..aOM<LiveDetails>(5, _omitFieldNames ? '' : 'live',
        subBuilder: LiveDetails.create)
    ..aOM<VideoDetails>(6, _omitFieldNames ? '' : 'video',
        subBuilder: VideoDetails.create)
    ..aOM<MusicDetails>(7, _omitFieldNames ? '' : 'music',
        subBuilder: MusicDetails.create)
    ..aOM<PodcastDetails>(8, _omitFieldNames ? '' : 'podcast',
        subBuilder: PodcastDetails.create)
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
  static DetailsResponse create() => DetailsResponse._();
  @$core.override
  DetailsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DetailsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DetailsResponse>(create);
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
    final result = create();
    if (pluginId != null) result.pluginId = pluginId;
    if (parentId != null) result.parentId = parentId;
    if (childId != null) result.childId = childId;
    if (page != null) result.page = page;
    return result;
  }

  BrowseRequest._();

  factory BrowseRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BrowseRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BrowseRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static BrowseRequest create() => BrowseRequest._();
  @$core.override
  BrowseRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BrowseRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BrowseRequest>(create);
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
    final result = create();
    if (items != null) result.items.addAll(items);
    if (hasMore != null) result.hasMore = hasMore;
    if (episodes != null) result.episodes.addAll(episodes);
    return result;
  }

  BrowseResponse._();

  factory BrowseResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BrowseResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BrowseResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..pPM<CatalogItem>(1, _omitFieldNames ? '' : 'items',
        subBuilder: CatalogItem.create)
    ..aOB(2, _omitFieldNames ? '' : 'hasMore')
    ..pPM<EpisodeInfo>(3, _omitFieldNames ? '' : 'episodes',
        subBuilder: EpisodeInfo.create)
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
  static BrowseResponse create() => BrowseResponse._();
  @$core.override
  BrowseResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BrowseResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BrowseResponse>(create);
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
    final result = create();
    if (id != null) result.id = id;
    if (label != null) result.label = label;
    if (quality != null) result.quality = quality;
    if (isLive != null) result.isLive = isLive;
    return result;
  }

  StreamSource._();

  factory StreamSource.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamSource.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamSource',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static StreamSource create() => StreamSource._();
  @$core.override
  StreamSource createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamSource getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamSource>(create);
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
    final result = create();
    if (pluginId != null) result.pluginId = pluginId;
    if (mediaId != null) result.mediaId = mediaId;
    return result;
  }

  StreamsRequest._();

  factory StreamsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static StreamsRequest create() => StreamsRequest._();
  @$core.override
  StreamsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamsRequest>(create);
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
    final result = create();
    if (sources != null) result.sources.addAll(sources);
    return result;
  }

  StreamsResponse._();

  factory StreamsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..pPM<StreamSource>(1, _omitFieldNames ? '' : 'sources',
        subBuilder: StreamSource.create)
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
  static StreamsResponse create() => StreamsResponse._();
  @$core.override
  StreamsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamsResponse>(create);
  static StreamsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<StreamSource> get sources => $_getList(0);
}

class ResolveRequest extends $pb.GeneratedMessage {
  factory ResolveRequest({
    $core.String? pluginId,
    $core.String? streamId,
  }) {
    final result = create();
    if (pluginId != null) result.pluginId = pluginId;
    if (streamId != null) result.streamId = streamId;
    return result;
  }

  ResolveRequest._();

  factory ResolveRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResolveRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResolveRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'streamId')
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
  static ResolveRequest create() => ResolveRequest._();
  @$core.override
  ResolveRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResolveRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResolveRequest>(create);
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
}

class ResolveResponse extends $pb.GeneratedMessage {
  factory ResolveResponse({
    $core.String? resolvedUrl,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? httpHeaders,
    $core.bool? isLive,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? extra,
  }) {
    final result = create();
    if (resolvedUrl != null) result.resolvedUrl = resolvedUrl;
    if (httpHeaders != null) result.httpHeaders.addEntries(httpHeaders);
    if (isLive != null) result.isLive = isLive;
    if (extra != null) result.extra.addEntries(extra);
    return result;
  }

  ResolveResponse._();

  factory ResolveResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResolveResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResolveResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static ResolveResponse create() => ResolveResponse._();
  @$core.override
  ResolveResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResolveResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResolveResponse>(create);
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
    final result = create();
    if (message != null) result.message = message;
    if (status != null) result.status = status;
    return result;
  }

  ResolveProgress._();

  factory ResolveProgress.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResolveProgress.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResolveProgress',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static ResolveProgress create() => ResolveProgress._();
  @$core.override
  ResolveProgress createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResolveProgress getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResolveProgress>(create);
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
    final result$ = create();
    if (progress != null) result$.progress = progress;
    if (result != null) result$.result = result;
    return result$;
  }

  ResolveStreamEvent._();

  factory ResolveStreamEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResolveStreamEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ResolveStreamEvent_Payload>
      _ResolveStreamEvent_PayloadByTag = {
    1: ResolveStreamEvent_Payload.progress,
    2: ResolveStreamEvent_Payload.result,
    0: ResolveStreamEvent_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResolveStreamEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<ResolveProgress>(1, _omitFieldNames ? '' : 'progress',
        subBuilder: ResolveProgress.create)
    ..aOM<ResolveResponse>(2, _omitFieldNames ? '' : 'result',
        subBuilder: ResolveResponse.create)
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
  static ResolveStreamEvent create() => ResolveStreamEvent._();
  @$core.override
  ResolveStreamEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResolveStreamEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResolveStreamEvent>(create);
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
  }) {
    final result = create();
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
    return result;
  }

  ProgressRequest._();

  factory ProgressRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProgressRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProgressRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static ProgressRequest create() => ProgressRequest._();
  @$core.override
  ProgressRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProgressRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProgressRequest>(create);
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
}

class ProgressResponse extends $pb.GeneratedMessage {
  factory ProgressResponse({
    $core.bool? ok,
  }) {
    final result = create();
    if (ok != null) result.ok = ok;
    return result;
  }

  ProgressResponse._();

  factory ProgressResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProgressResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProgressResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
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
  static ProgressResponse create() => ProgressResponse._();
  @$core.override
  ProgressResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProgressResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProgressResponse>(create);
  static ProgressResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);
}

class DeleteProgressRequest extends $pb.GeneratedMessage {
  factory DeleteProgressRequest({
    $core.String? pluginId,
    $core.String? mediaId,
  }) {
    final result = create();
    if (pluginId != null) result.pluginId = pluginId;
    if (mediaId != null) result.mediaId = mediaId;
    return result;
  }

  DeleteProgressRequest._();

  factory DeleteProgressRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteProgressRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteProgressRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static DeleteProgressRequest create() => DeleteProgressRequest._();
  @$core.override
  DeleteProgressRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteProgressRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteProgressRequest>(create);
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
    final result = create();
    if (ok != null) result.ok = ok;
    return result;
  }

  DeleteProgressResponse._();

  factory DeleteProgressResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteProgressResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteProgressResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static DeleteProgressResponse create() => DeleteProgressResponse._();
  @$core.override
  DeleteProgressResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteProgressResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteProgressResponse>(create);
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
  }) {
    final result = create();
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
    return result;
  }

  ContinueWatchingItem._();

  factory ContinueWatchingItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ContinueWatchingItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContinueWatchingItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static ContinueWatchingItem create() => ContinueWatchingItem._();
  @$core.override
  ContinueWatchingItem createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ContinueWatchingItem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContinueWatchingItem>(create);
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
}

class ContinueWatchingRequest extends $pb.GeneratedMessage {
  factory ContinueWatchingRequest({
    $core.int? limit,
    $core.String? parentId,
    $core.String? pluginId,
  }) {
    final result = create();
    if (limit != null) result.limit = limit;
    if (parentId != null) result.parentId = parentId;
    if (pluginId != null) result.pluginId = pluginId;
    return result;
  }

  ContinueWatchingRequest._();

  factory ContinueWatchingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ContinueWatchingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContinueWatchingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static ContinueWatchingRequest create() => ContinueWatchingRequest._();
  @$core.override
  ContinueWatchingRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ContinueWatchingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContinueWatchingRequest>(create);
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
    final result = create();
    if (items != null) result.items.addAll(items);
    return result;
  }

  ContinueWatchingResponse._();

  factory ContinueWatchingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ContinueWatchingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContinueWatchingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..pPM<ContinueWatchingItem>(1, _omitFieldNames ? '' : 'items',
        subBuilder: ContinueWatchingItem.create)
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
  static ContinueWatchingResponse create() => ContinueWatchingResponse._();
  @$core.override
  ContinueWatchingResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ContinueWatchingResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContinueWatchingResponse>(create);
  static ContinueWatchingResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ContinueWatchingItem> get items => $_getList(0);
}

class PluginListRequest extends $pb.GeneratedMessage {
  factory PluginListRequest() => create();

  PluginListRequest._();

  factory PluginListRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PluginListRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PluginListRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static PluginListRequest create() => PluginListRequest._();
  @$core.override
  PluginListRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PluginListRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PluginListRequest>(create);
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
    final result = create();
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
      create()..mergeFromBuffer(data, registry);
  factory PluginInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PluginInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'pluginId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'version')
    ..aOB(4, _omitFieldNames ? '' : 'isReady')
    ..pPS(5, _omitFieldNames ? '' : 'capabilities')
    ..pPM<CatalogDef>(6, _omitFieldNames ? '' : 'catalogs',
        subBuilder: CatalogDef.create)
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
  static PluginInfo create() => PluginInfo._();
  @$core.override
  PluginInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PluginInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PluginInfo>(create);
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

  /// Runtime status reported by the plugin itself.
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
  /// whether the process/connection currently responds). A plugin whose
  /// process is alive but whose channel is broken, or whose last N task runs
  /// all errored, reports reachable=false here so the client can
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
    final result = create();
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
      create()..mergeFromBuffer(data, registry);
  factory CatalogDef.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CatalogDef',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static CatalogDef create() => CatalogDef._();
  @$core.override
  CatalogDef createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CatalogDef getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CatalogDef>(create);
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

  /// True when this catalog backs a background task the plugin author marked
  /// as user-triggerable — e.g. a live catalog's manual "refresh now". Lets
  /// the client show an "aggiorna ora" action instead of waiting for the
  /// next scheduled run.
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
  /// continue-watching plugin-wide — wrong for e.g. a landscape-thumbnail
  /// video plugin serving perfectly ordinary on-demand video
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
    final result = create();
    if (plugins != null) result.plugins.addAll(plugins);
    return result;
  }

  PluginListResponse._();

  factory PluginListResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PluginListResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PluginListResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..pPM<PluginInfo>(1, _omitFieldNames ? '' : 'plugins',
        subBuilder: PluginInfo.create)
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
  static PluginListResponse create() => PluginListResponse._();
  @$core.override
  PluginListResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PluginListResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PluginListResponse>(create);
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
    final result = create();
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
      create()..mergeFromBuffer(data, registry);
  factory PluginSettingField.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PluginSettingField',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static PluginSettingField create() => PluginSettingField._();
  @$core.override
  PluginSettingField createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PluginSettingField getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PluginSettingField>(create);
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
    final result = create();
    if (pluginId != null) result.pluginId = pluginId;
    if (profileId != null) result.profileId = profileId;
    return result;
  }

  GetPluginSettingsRequest._();

  factory GetPluginSettingsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPluginSettingsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPluginSettingsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static GetPluginSettingsRequest create() => GetPluginSettingsRequest._();
  @$core.override
  GetPluginSettingsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPluginSettingsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPluginSettingsRequest>(create);
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
    final result = create();
    if (fields != null) result.fields.addAll(fields);
    return result;
  }

  GetPluginSettingsResponse._();

  factory GetPluginSettingsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPluginSettingsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPluginSettingsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
    ..pPM<PluginSettingField>(1, _omitFieldNames ? '' : 'fields',
        subBuilder: PluginSettingField.create)
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
  static GetPluginSettingsResponse create() => GetPluginSettingsResponse._();
  @$core.override
  GetPluginSettingsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPluginSettingsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPluginSettingsResponse>(create);
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
    final result = create();
    if (pluginId != null) result.pluginId = pluginId;
    if (profileId != null) result.profileId = profileId;
    if (key != null) result.key = key;
    if (value != null) result.value = value;
    return result;
  }

  SavePluginSettingRequest._();

  factory SavePluginSettingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SavePluginSettingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SavePluginSettingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static SavePluginSettingRequest create() => SavePluginSettingRequest._();
  @$core.override
  SavePluginSettingRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SavePluginSettingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SavePluginSettingRequest>(create);
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
    final result = create();
    if (ok != null) result.ok = ok;
    return result;
  }

  SavePluginSettingResponse._();

  factory SavePluginSettingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SavePluginSettingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SavePluginSettingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static SavePluginSettingResponse create() => SavePluginSettingResponse._();
  @$core.override
  SavePluginSettingResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SavePluginSettingResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SavePluginSettingResponse>(create);
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
    final result = create();
    if (pluginId != null) result.pluginId = pluginId;
    return result;
  }

  TriggerRefreshRequest._();

  factory TriggerRefreshRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TriggerRefreshRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TriggerRefreshRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static TriggerRefreshRequest create() => TriggerRefreshRequest._();
  @$core.override
  TriggerRefreshRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TriggerRefreshRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TriggerRefreshRequest>(create);
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
    final result = create();
    if (ok != null) result.ok = ok;
    if (message != null) result.message = message;
    return result;
  }

  TriggerRefreshResponse._();

  factory TriggerRefreshResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TriggerRefreshResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TriggerRefreshResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mycelium'),
      createEmptyInstance: create)
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
  static TriggerRefreshResponse create() => TriggerRefreshResponse._();
  @$core.override
  TriggerRefreshResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TriggerRefreshResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TriggerRefreshResponse>(create);
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

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
