//
//  Generated code. Do not modify.
//  source: import.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ParseCSVRequest extends $pb.GeneratedMessage {
  factory ParseCSVRequest({
    $core.List<$core.int>? csvData,
    $core.String? encoding,
  }) {
    final $result = create();
    if (csvData != null) {
      $result.csvData = csvData;
    }
    if (encoding != null) {
      $result.encoding = encoding;
    }
    return $result;
  }
  ParseCSVRequest._() : super();
  factory ParseCSVRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ParseCSVRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ParseCSVRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.import.v1'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'csvData', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'encoding')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ParseCSVRequest clone() => ParseCSVRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ParseCSVRequest copyWith(void Function(ParseCSVRequest) updates) => super.copyWith((message) => updates(message as ParseCSVRequest)) as ParseCSVRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ParseCSVRequest create() => ParseCSVRequest._();
  ParseCSVRequest createEmptyInstance() => create();
  static $pb.PbList<ParseCSVRequest> createRepeated() => $pb.PbList<ParseCSVRequest>();
  @$core.pragma('dart2js:noInline')
  static ParseCSVRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ParseCSVRequest>(create);
  static ParseCSVRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get csvData => $_getN(0);
  @$pb.TagNumber(1)
  set csvData($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCsvData() => $_has(0);
  @$pb.TagNumber(1)
  void clearCsvData() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get encoding => $_getSZ(1);
  @$pb.TagNumber(2)
  set encoding($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasEncoding() => $_has(1);
  @$pb.TagNumber(2)
  void clearEncoding() => clearField(2);
}

class ParseCSVResponse extends $pb.GeneratedMessage {
  factory ParseCSVResponse({
    $core.Iterable<$core.String>? headers,
    $core.Iterable<CSVRow>? previewRows,
    $core.int? totalRows,
    $core.String? sessionId,
  }) {
    final $result = create();
    if (headers != null) {
      $result.headers.addAll(headers);
    }
    if (previewRows != null) {
      $result.previewRows.addAll(previewRows);
    }
    if (totalRows != null) {
      $result.totalRows = totalRows;
    }
    if (sessionId != null) {
      $result.sessionId = sessionId;
    }
    return $result;
  }
  ParseCSVResponse._() : super();
  factory ParseCSVResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ParseCSVResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ParseCSVResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.import.v1'), createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'headers')
    ..pc<CSVRow>(2, _omitFieldNames ? '' : 'previewRows', $pb.PbFieldType.PM, subBuilder: CSVRow.create)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'totalRows', $pb.PbFieldType.O3)
    ..aOS(4, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ParseCSVResponse clone() => ParseCSVResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ParseCSVResponse copyWith(void Function(ParseCSVResponse) updates) => super.copyWith((message) => updates(message as ParseCSVResponse)) as ParseCSVResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ParseCSVResponse create() => ParseCSVResponse._();
  ParseCSVResponse createEmptyInstance() => create();
  static $pb.PbList<ParseCSVResponse> createRepeated() => $pb.PbList<ParseCSVResponse>();
  @$core.pragma('dart2js:noInline')
  static ParseCSVResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ParseCSVResponse>(create);
  static ParseCSVResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.String> get headers => $_getList(0);

  @$pb.TagNumber(2)
  $core.List<CSVRow> get previewRows => $_getList(1);

  @$pb.TagNumber(3)
  $core.int get totalRows => $_getIZ(2);
  @$pb.TagNumber(3)
  set totalRows($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTotalRows() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalRows() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get sessionId => $_getSZ(3);
  @$pb.TagNumber(4)
  set sessionId($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSessionId() => $_has(3);
  @$pb.TagNumber(4)
  void clearSessionId() => clearField(4);
}

class CSVRow extends $pb.GeneratedMessage {
  factory CSVRow({
    $core.Iterable<$core.String>? values,
  }) {
    final $result = create();
    if (values != null) {
      $result.values.addAll(values);
    }
    return $result;
  }
  CSVRow._() : super();
  factory CSVRow.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CSVRow.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CSVRow', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.import.v1'), createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'values')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CSVRow clone() => CSVRow()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CSVRow copyWith(void Function(CSVRow) updates) => super.copyWith((message) => updates(message as CSVRow)) as CSVRow;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CSVRow create() => CSVRow._();
  CSVRow createEmptyInstance() => create();
  static $pb.PbList<CSVRow> createRepeated() => $pb.PbList<CSVRow>();
  @$core.pragma('dart2js:noInline')
  static CSVRow getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CSVRow>(create);
  static CSVRow? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.String> get values => $_getList(0);
}

class FieldMapping extends $pb.GeneratedMessage {
  factory FieldMapping({
    $core.String? csvColumn,
    $core.String? targetField,
  }) {
    final $result = create();
    if (csvColumn != null) {
      $result.csvColumn = csvColumn;
    }
    if (targetField != null) {
      $result.targetField = targetField;
    }
    return $result;
  }
  FieldMapping._() : super();
  factory FieldMapping.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FieldMapping.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FieldMapping', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.import.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'csvColumn')
    ..aOS(2, _omitFieldNames ? '' : 'targetField')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FieldMapping clone() => FieldMapping()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FieldMapping copyWith(void Function(FieldMapping) updates) => super.copyWith((message) => updates(message as FieldMapping)) as FieldMapping;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FieldMapping create() => FieldMapping._();
  FieldMapping createEmptyInstance() => create();
  static $pb.PbList<FieldMapping> createRepeated() => $pb.PbList<FieldMapping>();
  @$core.pragma('dart2js:noInline')
  static FieldMapping getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FieldMapping>(create);
  static FieldMapping? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get csvColumn => $_getSZ(0);
  @$pb.TagNumber(1)
  set csvColumn($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCsvColumn() => $_has(0);
  @$pb.TagNumber(1)
  void clearCsvColumn() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get targetField => $_getSZ(1);
  @$pb.TagNumber(2)
  set targetField($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTargetField() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetField() => clearField(2);
}

class ConfirmImportRequest extends $pb.GeneratedMessage {
  factory ConfirmImportRequest({
    $core.String? sessionId,
    $core.Iterable<FieldMapping>? mappings,
    $core.String? defaultAccountId,
    $core.String? userId,
  }) {
    final $result = create();
    if (sessionId != null) {
      $result.sessionId = sessionId;
    }
    if (mappings != null) {
      $result.mappings.addAll(mappings);
    }
    if (defaultAccountId != null) {
      $result.defaultAccountId = defaultAccountId;
    }
    if (userId != null) {
      $result.userId = userId;
    }
    return $result;
  }
  ConfirmImportRequest._() : super();
  factory ConfirmImportRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ConfirmImportRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ConfirmImportRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.import.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..pc<FieldMapping>(2, _omitFieldNames ? '' : 'mappings', $pb.PbFieldType.PM, subBuilder: FieldMapping.create)
    ..aOS(3, _omitFieldNames ? '' : 'defaultAccountId')
    ..aOS(4, _omitFieldNames ? '' : 'userId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ConfirmImportRequest clone() => ConfirmImportRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ConfirmImportRequest copyWith(void Function(ConfirmImportRequest) updates) => super.copyWith((message) => updates(message as ConfirmImportRequest)) as ConfirmImportRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConfirmImportRequest create() => ConfirmImportRequest._();
  ConfirmImportRequest createEmptyInstance() => create();
  static $pb.PbList<ConfirmImportRequest> createRepeated() => $pb.PbList<ConfirmImportRequest>();
  @$core.pragma('dart2js:noInline')
  static ConfirmImportRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ConfirmImportRequest>(create);
  static ConfirmImportRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<FieldMapping> get mappings => $_getList(1);

  @$pb.TagNumber(3)
  $core.String get defaultAccountId => $_getSZ(2);
  @$pb.TagNumber(3)
  set defaultAccountId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDefaultAccountId() => $_has(2);
  @$pb.TagNumber(3)
  void clearDefaultAccountId() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get userId => $_getSZ(3);
  @$pb.TagNumber(4)
  set userId($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasUserId() => $_has(3);
  @$pb.TagNumber(4)
  void clearUserId() => clearField(4);
}

class ConfirmImportResponse extends $pb.GeneratedMessage {
  factory ConfirmImportResponse({
    $core.int? importedCount,
    $core.int? skippedCount,
    $core.Iterable<$core.String>? errors,
  }) {
    final $result = create();
    if (importedCount != null) {
      $result.importedCount = importedCount;
    }
    if (skippedCount != null) {
      $result.skippedCount = skippedCount;
    }
    if (errors != null) {
      $result.errors.addAll(errors);
    }
    return $result;
  }
  ConfirmImportResponse._() : super();
  factory ConfirmImportResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ConfirmImportResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ConfirmImportResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.import.v1'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'importedCount', $pb.PbFieldType.O3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'skippedCount', $pb.PbFieldType.O3)
    ..pPS(3, _omitFieldNames ? '' : 'errors')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ConfirmImportResponse clone() => ConfirmImportResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ConfirmImportResponse copyWith(void Function(ConfirmImportResponse) updates) => super.copyWith((message) => updates(message as ConfirmImportResponse)) as ConfirmImportResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConfirmImportResponse create() => ConfirmImportResponse._();
  ConfirmImportResponse createEmptyInstance() => create();
  static $pb.PbList<ConfirmImportResponse> createRepeated() => $pb.PbList<ConfirmImportResponse>();
  @$core.pragma('dart2js:noInline')
  static ConfirmImportResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ConfirmImportResponse>(create);
  static ConfirmImportResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get importedCount => $_getIZ(0);
  @$pb.TagNumber(1)
  set importedCount($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasImportedCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearImportedCount() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get skippedCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set skippedCount($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSkippedCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearSkippedCount() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.String> get errors => $_getList(2);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
