// This is a generated file - do not edit.
//
// Generated from transaction.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $1;

import 'transaction.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'transaction.pbenum.dart';

class Transaction extends $pb.GeneratedMessage {
  factory Transaction({
    $core.String? id,
    $core.String? userId,
    $core.String? accountId,
    $core.String? categoryId,
    $fixnum.Int64? amount,
    $core.String? currency,
    $fixnum.Int64? amountCny,
    $core.double? exchangeRate,
    TransactionType? type,
    $core.String? note,
    $1.Timestamp? txnDate,
    $1.Timestamp? createdAt,
    $1.Timestamp? updatedAt,
    $core.Iterable<$core.String>? tags,
    $core.Iterable<$core.String>? imageUrls,
    $1.Timestamp? deletedAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (userId != null) result.userId = userId;
    if (accountId != null) result.accountId = accountId;
    if (categoryId != null) result.categoryId = categoryId;
    if (amount != null) result.amount = amount;
    if (currency != null) result.currency = currency;
    if (amountCny != null) result.amountCny = amountCny;
    if (exchangeRate != null) result.exchangeRate = exchangeRate;
    if (type != null) result.type = type;
    if (note != null) result.note = note;
    if (txnDate != null) result.txnDate = txnDate;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    if (tags != null) result.tags.addAll(tags);
    if (imageUrls != null) result.imageUrls.addAll(imageUrls);
    if (deletedAt != null) result.deletedAt = deletedAt;
    return result;
  }

  Transaction._();

  factory Transaction.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Transaction.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Transaction',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'accountId')
    ..aOS(4, _omitFieldNames ? '' : 'categoryId')
    ..aInt64(5, _omitFieldNames ? '' : 'amount')
    ..aOS(6, _omitFieldNames ? '' : 'currency')
    ..aInt64(7, _omitFieldNames ? '' : 'amountCny')
    ..aD(8, _omitFieldNames ? '' : 'exchangeRate')
    ..aE<TransactionType>(9, _omitFieldNames ? '' : 'type',
        enumValues: TransactionType.values)
    ..aOS(10, _omitFieldNames ? '' : 'note')
    ..aOM<$1.Timestamp>(11, _omitFieldNames ? '' : 'txnDate',
        subBuilder: $1.Timestamp.create)
    ..aOM<$1.Timestamp>(12, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $1.Timestamp.create)
    ..aOM<$1.Timestamp>(13, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $1.Timestamp.create)
    ..pPS(14, _omitFieldNames ? '' : 'tags')
    ..pPS(15, _omitFieldNames ? '' : 'imageUrls')
    ..aOM<$1.Timestamp>(16, _omitFieldNames ? '' : 'deletedAt',
        subBuilder: $1.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Transaction clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Transaction copyWith(void Function(Transaction) updates) =>
      super.copyWith((message) => updates(message as Transaction))
          as Transaction;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Transaction create() => Transaction._();
  @$core.override
  Transaction createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Transaction getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Transaction>(create);
  static Transaction? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get accountId => $_getSZ(2);
  @$pb.TagNumber(3)
  set accountId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAccountId() => $_has(2);
  @$pb.TagNumber(3)
  void clearAccountId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get categoryId => $_getSZ(3);
  @$pb.TagNumber(4)
  set categoryId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCategoryId() => $_has(3);
  @$pb.TagNumber(4)
  void clearCategoryId() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get amount => $_getI64(4);
  @$pb.TagNumber(5)
  set amount($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAmount() => $_has(4);
  @$pb.TagNumber(5)
  void clearAmount() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get currency => $_getSZ(5);
  @$pb.TagNumber(6)
  set currency($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCurrency() => $_has(5);
  @$pb.TagNumber(6)
  void clearCurrency() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get amountCny => $_getI64(6);
  @$pb.TagNumber(7)
  set amountCny($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAmountCny() => $_has(6);
  @$pb.TagNumber(7)
  void clearAmountCny() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get exchangeRate => $_getN(7);
  @$pb.TagNumber(8)
  set exchangeRate($core.double value) => $_setDouble(7, value);
  @$pb.TagNumber(8)
  $core.bool hasExchangeRate() => $_has(7);
  @$pb.TagNumber(8)
  void clearExchangeRate() => $_clearField(8);

  @$pb.TagNumber(9)
  TransactionType get type => $_getN(8);
  @$pb.TagNumber(9)
  set type(TransactionType value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasType() => $_has(8);
  @$pb.TagNumber(9)
  void clearType() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get note => $_getSZ(9);
  @$pb.TagNumber(10)
  set note($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasNote() => $_has(9);
  @$pb.TagNumber(10)
  void clearNote() => $_clearField(10);

  @$pb.TagNumber(11)
  $1.Timestamp get txnDate => $_getN(10);
  @$pb.TagNumber(11)
  set txnDate($1.Timestamp value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasTxnDate() => $_has(10);
  @$pb.TagNumber(11)
  void clearTxnDate() => $_clearField(11);
  @$pb.TagNumber(11)
  $1.Timestamp ensureTxnDate() => $_ensure(10);

  @$pb.TagNumber(12)
  $1.Timestamp get createdAt => $_getN(11);
  @$pb.TagNumber(12)
  set createdAt($1.Timestamp value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasCreatedAt() => $_has(11);
  @$pb.TagNumber(12)
  void clearCreatedAt() => $_clearField(12);
  @$pb.TagNumber(12)
  $1.Timestamp ensureCreatedAt() => $_ensure(11);

  @$pb.TagNumber(13)
  $1.Timestamp get updatedAt => $_getN(12);
  @$pb.TagNumber(13)
  set updatedAt($1.Timestamp value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasUpdatedAt() => $_has(12);
  @$pb.TagNumber(13)
  void clearUpdatedAt() => $_clearField(13);
  @$pb.TagNumber(13)
  $1.Timestamp ensureUpdatedAt() => $_ensure(12);

  @$pb.TagNumber(14)
  $pb.PbList<$core.String> get tags => $_getList(13);

  @$pb.TagNumber(15)
  $pb.PbList<$core.String> get imageUrls => $_getList(14);

  @$pb.TagNumber(16)
  $1.Timestamp get deletedAt => $_getN(15);
  @$pb.TagNumber(16)
  set deletedAt($1.Timestamp value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasDeletedAt() => $_has(15);
  @$pb.TagNumber(16)
  void clearDeletedAt() => $_clearField(16);
  @$pb.TagNumber(16)
  $1.Timestamp ensureDeletedAt() => $_ensure(15);
}

class Category extends $pb.GeneratedMessage {
  factory Category({
    $core.String? id,
    $core.String? name,
    $core.String? icon,
    TransactionType? type,
    $core.bool? isPreset,
    $core.int? sortOrder,
    $core.String? parentId,
    $core.String? iconKey,
    $core.Iterable<Category>? children,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (icon != null) result.icon = icon;
    if (type != null) result.type = type;
    if (isPreset != null) result.isPreset = isPreset;
    if (sortOrder != null) result.sortOrder = sortOrder;
    if (parentId != null) result.parentId = parentId;
    if (iconKey != null) result.iconKey = iconKey;
    if (children != null) result.children.addAll(children);
    return result;
  }

  Category._();

  factory Category.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Category.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Category',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'icon')
    ..aE<TransactionType>(4, _omitFieldNames ? '' : 'type',
        enumValues: TransactionType.values)
    ..aOB(5, _omitFieldNames ? '' : 'isPreset')
    ..aI(6, _omitFieldNames ? '' : 'sortOrder')
    ..aOS(7, _omitFieldNames ? '' : 'parentId')
    ..aOS(8, _omitFieldNames ? '' : 'iconKey')
    ..pPM<Category>(9, _omitFieldNames ? '' : 'children',
        subBuilder: Category.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Category clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Category copyWith(void Function(Category) updates) =>
      super.copyWith((message) => updates(message as Category)) as Category;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Category create() => Category._();
  @$core.override
  Category createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Category getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Category>(create);
  static Category? _defaultInstance;

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
  $core.String get icon => $_getSZ(2);
  @$pb.TagNumber(3)
  set icon($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearIcon() => $_clearField(3);

  @$pb.TagNumber(4)
  TransactionType get type => $_getN(3);
  @$pb.TagNumber(4)
  set type(TransactionType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get isPreset => $_getBF(4);
  @$pb.TagNumber(5)
  set isPreset($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIsPreset() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsPreset() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get sortOrder => $_getIZ(5);
  @$pb.TagNumber(6)
  set sortOrder($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSortOrder() => $_has(5);
  @$pb.TagNumber(6)
  void clearSortOrder() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get parentId => $_getSZ(6);
  @$pb.TagNumber(7)
  set parentId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasParentId() => $_has(6);
  @$pb.TagNumber(7)
  void clearParentId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get iconKey => $_getSZ(7);
  @$pb.TagNumber(8)
  set iconKey($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIconKey() => $_has(7);
  @$pb.TagNumber(8)
  void clearIconKey() => $_clearField(8);

  @$pb.TagNumber(9)
  $pb.PbList<Category> get children => $_getList(8);
}

class CreateTransactionRequest extends $pb.GeneratedMessage {
  factory CreateTransactionRequest({
    $core.String? accountId,
    $core.String? categoryId,
    $fixnum.Int64? amount,
    $core.String? currency,
    $fixnum.Int64? amountCny,
    $core.double? exchangeRate,
    TransactionType? type,
    $core.String? note,
    $1.Timestamp? txnDate,
    $core.Iterable<$core.String>? tags,
    $core.Iterable<$core.String>? imageUrls,
  }) {
    final result = create();
    if (accountId != null) result.accountId = accountId;
    if (categoryId != null) result.categoryId = categoryId;
    if (amount != null) result.amount = amount;
    if (currency != null) result.currency = currency;
    if (amountCny != null) result.amountCny = amountCny;
    if (exchangeRate != null) result.exchangeRate = exchangeRate;
    if (type != null) result.type = type;
    if (note != null) result.note = note;
    if (txnDate != null) result.txnDate = txnDate;
    if (tags != null) result.tags.addAll(tags);
    if (imageUrls != null) result.imageUrls.addAll(imageUrls);
    return result;
  }

  CreateTransactionRequest._();

  factory CreateTransactionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateTransactionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateTransactionRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accountId')
    ..aOS(2, _omitFieldNames ? '' : 'categoryId')
    ..aInt64(3, _omitFieldNames ? '' : 'amount')
    ..aOS(4, _omitFieldNames ? '' : 'currency')
    ..aInt64(5, _omitFieldNames ? '' : 'amountCny')
    ..aD(6, _omitFieldNames ? '' : 'exchangeRate')
    ..aE<TransactionType>(7, _omitFieldNames ? '' : 'type',
        enumValues: TransactionType.values)
    ..aOS(8, _omitFieldNames ? '' : 'note')
    ..aOM<$1.Timestamp>(9, _omitFieldNames ? '' : 'txnDate',
        subBuilder: $1.Timestamp.create)
    ..pPS(10, _omitFieldNames ? '' : 'tags')
    ..pPS(11, _omitFieldNames ? '' : 'imageUrls')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTransactionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTransactionRequest copyWith(
          void Function(CreateTransactionRequest) updates) =>
      super.copyWith((message) => updates(message as CreateTransactionRequest))
          as CreateTransactionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateTransactionRequest create() => CreateTransactionRequest._();
  @$core.override
  CreateTransactionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateTransactionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateTransactionRequest>(create);
  static CreateTransactionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accountId => $_getSZ(0);
  @$pb.TagNumber(1)
  set accountId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccountId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccountId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get categoryId => $_getSZ(1);
  @$pb.TagNumber(2)
  set categoryId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCategoryId() => $_has(1);
  @$pb.TagNumber(2)
  void clearCategoryId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get amount => $_getI64(2);
  @$pb.TagNumber(3)
  set amount($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get currency => $_getSZ(3);
  @$pb.TagNumber(4)
  set currency($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCurrency() => $_has(3);
  @$pb.TagNumber(4)
  void clearCurrency() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get amountCny => $_getI64(4);
  @$pb.TagNumber(5)
  set amountCny($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAmountCny() => $_has(4);
  @$pb.TagNumber(5)
  void clearAmountCny() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get exchangeRate => $_getN(5);
  @$pb.TagNumber(6)
  set exchangeRate($core.double value) => $_setDouble(5, value);
  @$pb.TagNumber(6)
  $core.bool hasExchangeRate() => $_has(5);
  @$pb.TagNumber(6)
  void clearExchangeRate() => $_clearField(6);

  @$pb.TagNumber(7)
  TransactionType get type => $_getN(6);
  @$pb.TagNumber(7)
  set type(TransactionType value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasType() => $_has(6);
  @$pb.TagNumber(7)
  void clearType() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get note => $_getSZ(7);
  @$pb.TagNumber(8)
  set note($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasNote() => $_has(7);
  @$pb.TagNumber(8)
  void clearNote() => $_clearField(8);

  @$pb.TagNumber(9)
  $1.Timestamp get txnDate => $_getN(8);
  @$pb.TagNumber(9)
  set txnDate($1.Timestamp value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasTxnDate() => $_has(8);
  @$pb.TagNumber(9)
  void clearTxnDate() => $_clearField(9);
  @$pb.TagNumber(9)
  $1.Timestamp ensureTxnDate() => $_ensure(8);

  @$pb.TagNumber(10)
  $pb.PbList<$core.String> get tags => $_getList(9);

  @$pb.TagNumber(11)
  $pb.PbList<$core.String> get imageUrls => $_getList(10);
}

class CreateTransactionResponse extends $pb.GeneratedMessage {
  factory CreateTransactionResponse({
    Transaction? transaction,
  }) {
    final result = create();
    if (transaction != null) result.transaction = transaction;
    return result;
  }

  CreateTransactionResponse._();

  factory CreateTransactionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateTransactionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateTransactionResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOM<Transaction>(1, _omitFieldNames ? '' : 'transaction',
        subBuilder: Transaction.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTransactionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTransactionResponse copyWith(
          void Function(CreateTransactionResponse) updates) =>
      super.copyWith((message) => updates(message as CreateTransactionResponse))
          as CreateTransactionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateTransactionResponse create() => CreateTransactionResponse._();
  @$core.override
  CreateTransactionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateTransactionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateTransactionResponse>(create);
  static CreateTransactionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Transaction get transaction => $_getN(0);
  @$pb.TagNumber(1)
  set transaction(Transaction value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTransaction() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransaction() => $_clearField(1);
  @$pb.TagNumber(1)
  Transaction ensureTransaction() => $_ensure(0);
}

class ListTransactionsRequest extends $pb.GeneratedMessage {
  factory ListTransactionsRequest({
    $core.String? accountId,
    $1.Timestamp? startDate,
    $1.Timestamp? endDate,
    $core.int? pageSize,
    $core.String? pageToken,
    $core.String? familyId,
    $1.Timestamp? updatedSince,
    $core.bool? includeDeleted,
  }) {
    final result = create();
    if (accountId != null) result.accountId = accountId;
    if (startDate != null) result.startDate = startDate;
    if (endDate != null) result.endDate = endDate;
    if (pageSize != null) result.pageSize = pageSize;
    if (pageToken != null) result.pageToken = pageToken;
    if (familyId != null) result.familyId = familyId;
    if (updatedSince != null) result.updatedSince = updatedSince;
    if (includeDeleted != null) result.includeDeleted = includeDeleted;
    return result;
  }

  ListTransactionsRequest._();

  factory ListTransactionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListTransactionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTransactionsRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accountId')
    ..aOM<$1.Timestamp>(2, _omitFieldNames ? '' : 'startDate',
        subBuilder: $1.Timestamp.create)
    ..aOM<$1.Timestamp>(3, _omitFieldNames ? '' : 'endDate',
        subBuilder: $1.Timestamp.create)
    ..aI(4, _omitFieldNames ? '' : 'pageSize')
    ..aOS(5, _omitFieldNames ? '' : 'pageToken')
    ..aOS(6, _omitFieldNames ? '' : 'familyId')
    ..aOM<$1.Timestamp>(7, _omitFieldNames ? '' : 'updatedSince',
        subBuilder: $1.Timestamp.create)
    ..aOB(8, _omitFieldNames ? '' : 'includeDeleted')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTransactionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTransactionsRequest copyWith(
          void Function(ListTransactionsRequest) updates) =>
      super.copyWith((message) => updates(message as ListTransactionsRequest))
          as ListTransactionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListTransactionsRequest create() => ListTransactionsRequest._();
  @$core.override
  ListTransactionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListTransactionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListTransactionsRequest>(create);
  static ListTransactionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accountId => $_getSZ(0);
  @$pb.TagNumber(1)
  set accountId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccountId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccountId() => $_clearField(1);

  @$pb.TagNumber(2)
  $1.Timestamp get startDate => $_getN(1);
  @$pb.TagNumber(2)
  set startDate($1.Timestamp value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStartDate() => $_has(1);
  @$pb.TagNumber(2)
  void clearStartDate() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.Timestamp ensureStartDate() => $_ensure(1);

  @$pb.TagNumber(3)
  $1.Timestamp get endDate => $_getN(2);
  @$pb.TagNumber(3)
  set endDate($1.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasEndDate() => $_has(2);
  @$pb.TagNumber(3)
  void clearEndDate() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.Timestamp ensureEndDate() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.int get pageSize => $_getIZ(3);
  @$pb.TagNumber(4)
  set pageSize($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPageSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearPageSize() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get pageToken => $_getSZ(4);
  @$pb.TagNumber(5)
  set pageToken($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPageToken() => $_has(4);
  @$pb.TagNumber(5)
  void clearPageToken() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get familyId => $_getSZ(5);
  @$pb.TagNumber(6)
  set familyId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFamilyId() => $_has(5);
  @$pb.TagNumber(6)
  void clearFamilyId() => $_clearField(6);

  @$pb.TagNumber(7)
  $1.Timestamp get updatedSince => $_getN(6);
  @$pb.TagNumber(7)
  set updatedSince($1.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasUpdatedSince() => $_has(6);
  @$pb.TagNumber(7)
  void clearUpdatedSince() => $_clearField(7);
  @$pb.TagNumber(7)
  $1.Timestamp ensureUpdatedSince() => $_ensure(6);

  @$pb.TagNumber(8)
  $core.bool get includeDeleted => $_getBF(7);
  @$pb.TagNumber(8)
  set includeDeleted($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIncludeDeleted() => $_has(7);
  @$pb.TagNumber(8)
  void clearIncludeDeleted() => $_clearField(8);
}

class ListTransactionsResponse extends $pb.GeneratedMessage {
  factory ListTransactionsResponse({
    $core.Iterable<Transaction>? transactions,
    $core.String? nextPageToken,
    $core.int? totalCount,
  }) {
    final result = create();
    if (transactions != null) result.transactions.addAll(transactions);
    if (nextPageToken != null) result.nextPageToken = nextPageToken;
    if (totalCount != null) result.totalCount = totalCount;
    return result;
  }

  ListTransactionsResponse._();

  factory ListTransactionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListTransactionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTransactionsResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..pPM<Transaction>(1, _omitFieldNames ? '' : 'transactions',
        subBuilder: Transaction.create)
    ..aOS(2, _omitFieldNames ? '' : 'nextPageToken')
    ..aI(3, _omitFieldNames ? '' : 'totalCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTransactionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTransactionsResponse copyWith(
          void Function(ListTransactionsResponse) updates) =>
      super.copyWith((message) => updates(message as ListTransactionsResponse))
          as ListTransactionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListTransactionsResponse create() => ListTransactionsResponse._();
  @$core.override
  ListTransactionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListTransactionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListTransactionsResponse>(create);
  static ListTransactionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Transaction> get transactions => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get nextPageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set nextPageToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNextPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextPageToken() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get totalCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set totalCount($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalCount() => $_clearField(3);
}

class UpdateTransactionRequest extends $pb.GeneratedMessage {
  factory UpdateTransactionRequest({
    $core.String? transactionId,
    $fixnum.Int64? amount,
    $core.String? categoryId,
    $core.String? note,
    $core.String? tags,
    TransactionType? type,
    $core.String? currency,
    $1.Timestamp? txnDate,
  }) {
    final result = create();
    if (transactionId != null) result.transactionId = transactionId;
    if (amount != null) result.amount = amount;
    if (categoryId != null) result.categoryId = categoryId;
    if (note != null) result.note = note;
    if (tags != null) result.tags = tags;
    if (type != null) result.type = type;
    if (currency != null) result.currency = currency;
    if (txnDate != null) result.txnDate = txnDate;
    return result;
  }

  UpdateTransactionRequest._();

  factory UpdateTransactionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateTransactionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateTransactionRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'transactionId')
    ..aInt64(2, _omitFieldNames ? '' : 'amount')
    ..aOS(3, _omitFieldNames ? '' : 'categoryId')
    ..aOS(4, _omitFieldNames ? '' : 'note')
    ..aOS(5, _omitFieldNames ? '' : 'tags')
    ..aE<TransactionType>(6, _omitFieldNames ? '' : 'type',
        enumValues: TransactionType.values)
    ..aOS(7, _omitFieldNames ? '' : 'currency')
    ..aOM<$1.Timestamp>(8, _omitFieldNames ? '' : 'txnDate',
        subBuilder: $1.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTransactionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTransactionRequest copyWith(
          void Function(UpdateTransactionRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateTransactionRequest))
          as UpdateTransactionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateTransactionRequest create() => UpdateTransactionRequest._();
  @$core.override
  UpdateTransactionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateTransactionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateTransactionRequest>(create);
  static UpdateTransactionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transactionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transactionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransactionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransactionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get amount => $_getI64(1);
  @$pb.TagNumber(2)
  set amount($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAmount() => $_has(1);
  @$pb.TagNumber(2)
  void clearAmount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get categoryId => $_getSZ(2);
  @$pb.TagNumber(3)
  set categoryId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCategoryId() => $_has(2);
  @$pb.TagNumber(3)
  void clearCategoryId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get note => $_getSZ(3);
  @$pb.TagNumber(4)
  set note($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNote() => $_has(3);
  @$pb.TagNumber(4)
  void clearNote() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get tags => $_getSZ(4);
  @$pb.TagNumber(5)
  set tags($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTags() => $_has(4);
  @$pb.TagNumber(5)
  void clearTags() => $_clearField(5);

  @$pb.TagNumber(6)
  TransactionType get type => $_getN(5);
  @$pb.TagNumber(6)
  set type(TransactionType value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasType() => $_has(5);
  @$pb.TagNumber(6)
  void clearType() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get currency => $_getSZ(6);
  @$pb.TagNumber(7)
  set currency($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCurrency() => $_has(6);
  @$pb.TagNumber(7)
  void clearCurrency() => $_clearField(7);

  @$pb.TagNumber(8)
  $1.Timestamp get txnDate => $_getN(7);
  @$pb.TagNumber(8)
  set txnDate($1.Timestamp value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasTxnDate() => $_has(7);
  @$pb.TagNumber(8)
  void clearTxnDate() => $_clearField(8);
  @$pb.TagNumber(8)
  $1.Timestamp ensureTxnDate() => $_ensure(7);
}

class UpdateTransactionResponse extends $pb.GeneratedMessage {
  factory UpdateTransactionResponse({
    Transaction? transaction,
  }) {
    final result = create();
    if (transaction != null) result.transaction = transaction;
    return result;
  }

  UpdateTransactionResponse._();

  factory UpdateTransactionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateTransactionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateTransactionResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOM<Transaction>(1, _omitFieldNames ? '' : 'transaction',
        subBuilder: Transaction.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTransactionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTransactionResponse copyWith(
          void Function(UpdateTransactionResponse) updates) =>
      super.copyWith((message) => updates(message as UpdateTransactionResponse))
          as UpdateTransactionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateTransactionResponse create() => UpdateTransactionResponse._();
  @$core.override
  UpdateTransactionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateTransactionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateTransactionResponse>(create);
  static UpdateTransactionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Transaction get transaction => $_getN(0);
  @$pb.TagNumber(1)
  set transaction(Transaction value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTransaction() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransaction() => $_clearField(1);
  @$pb.TagNumber(1)
  Transaction ensureTransaction() => $_ensure(0);
}

class DeleteTransactionRequest extends $pb.GeneratedMessage {
  factory DeleteTransactionRequest({
    $core.String? transactionId,
  }) {
    final result = create();
    if (transactionId != null) result.transactionId = transactionId;
    return result;
  }

  DeleteTransactionRequest._();

  factory DeleteTransactionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteTransactionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteTransactionRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'transactionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTransactionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTransactionRequest copyWith(
          void Function(DeleteTransactionRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteTransactionRequest))
          as DeleteTransactionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteTransactionRequest create() => DeleteTransactionRequest._();
  @$core.override
  DeleteTransactionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteTransactionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteTransactionRequest>(create);
  static DeleteTransactionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transactionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transactionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransactionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransactionId() => $_clearField(1);
}

class DeleteTransactionResponse extends $pb.GeneratedMessage {
  factory DeleteTransactionResponse() => create();

  DeleteTransactionResponse._();

  factory DeleteTransactionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteTransactionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteTransactionResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTransactionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTransactionResponse copyWith(
          void Function(DeleteTransactionResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteTransactionResponse))
          as DeleteTransactionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteTransactionResponse create() => DeleteTransactionResponse._();
  @$core.override
  DeleteTransactionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteTransactionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteTransactionResponse>(create);
  static DeleteTransactionResponse? _defaultInstance;
}

class BatchCreateTransactionsRequest extends $pb.GeneratedMessage {
  factory BatchCreateTransactionsRequest({
    $core.Iterable<CreateTransactionRequest>? transactions,
    $core.String? accountId,
  }) {
    final result = create();
    if (transactions != null) result.transactions.addAll(transactions);
    if (accountId != null) result.accountId = accountId;
    return result;
  }

  BatchCreateTransactionsRequest._();

  factory BatchCreateTransactionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BatchCreateTransactionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BatchCreateTransactionsRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..pPM<CreateTransactionRequest>(1, _omitFieldNames ? '' : 'transactions',
        subBuilder: CreateTransactionRequest.create)
    ..aOS(2, _omitFieldNames ? '' : 'accountId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchCreateTransactionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchCreateTransactionsRequest copyWith(
          void Function(BatchCreateTransactionsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as BatchCreateTransactionsRequest))
          as BatchCreateTransactionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BatchCreateTransactionsRequest create() =>
      BatchCreateTransactionsRequest._();
  @$core.override
  BatchCreateTransactionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BatchCreateTransactionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BatchCreateTransactionsRequest>(create);
  static BatchCreateTransactionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<CreateTransactionRequest> get transactions => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get accountId => $_getSZ(1);
  @$pb.TagNumber(2)
  set accountId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAccountId() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccountId() => $_clearField(2);
}

class BatchCreateTransactionsResponse extends $pb.GeneratedMessage {
  factory BatchCreateTransactionsResponse({
    $core.int? createdCount,
    $core.Iterable<Transaction>? transactions,
    $core.Iterable<$core.String>? errors,
    $core.Iterable<$core.String>? warnings,
  }) {
    final result = create();
    if (createdCount != null) result.createdCount = createdCount;
    if (transactions != null) result.transactions.addAll(transactions);
    if (errors != null) result.errors.addAll(errors);
    if (warnings != null) result.warnings.addAll(warnings);
    return result;
  }

  BatchCreateTransactionsResponse._();

  factory BatchCreateTransactionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BatchCreateTransactionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BatchCreateTransactionsResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'createdCount')
    ..pPM<Transaction>(2, _omitFieldNames ? '' : 'transactions',
        subBuilder: Transaction.create)
    ..pPS(3, _omitFieldNames ? '' : 'errors')
    ..pPS(4, _omitFieldNames ? '' : 'warnings')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchCreateTransactionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchCreateTransactionsResponse copyWith(
          void Function(BatchCreateTransactionsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as BatchCreateTransactionsResponse))
          as BatchCreateTransactionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BatchCreateTransactionsResponse create() =>
      BatchCreateTransactionsResponse._();
  @$core.override
  BatchCreateTransactionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BatchCreateTransactionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BatchCreateTransactionsResponse>(
          create);
  static BatchCreateTransactionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get createdCount => $_getIZ(0);
  @$pb.TagNumber(1)
  set createdCount($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCreatedCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearCreatedCount() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<Transaction> get transactions => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get errors => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get warnings => $_getList(3);
}

class BatchDeleteTransactionsRequest extends $pb.GeneratedMessage {
  factory BatchDeleteTransactionsRequest({
    $core.Iterable<$core.String>? transactionIds,
  }) {
    final result = create();
    if (transactionIds != null) result.transactionIds.addAll(transactionIds);
    return result;
  }

  BatchDeleteTransactionsRequest._();

  factory BatchDeleteTransactionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BatchDeleteTransactionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BatchDeleteTransactionsRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'transactionIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchDeleteTransactionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchDeleteTransactionsRequest copyWith(
          void Function(BatchDeleteTransactionsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as BatchDeleteTransactionsRequest))
          as BatchDeleteTransactionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BatchDeleteTransactionsRequest create() =>
      BatchDeleteTransactionsRequest._();
  @$core.override
  BatchDeleteTransactionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BatchDeleteTransactionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BatchDeleteTransactionsRequest>(create);
  static BatchDeleteTransactionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get transactionIds => $_getList(0);
}

class BatchDeleteTransactionsResponse extends $pb.GeneratedMessage {
  factory BatchDeleteTransactionsResponse({
    $core.int? deletedCount,
  }) {
    final result = create();
    if (deletedCount != null) result.deletedCount = deletedCount;
    return result;
  }

  BatchDeleteTransactionsResponse._();

  factory BatchDeleteTransactionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BatchDeleteTransactionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BatchDeleteTransactionsResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'deletedCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchDeleteTransactionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchDeleteTransactionsResponse copyWith(
          void Function(BatchDeleteTransactionsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as BatchDeleteTransactionsResponse))
          as BatchDeleteTransactionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BatchDeleteTransactionsResponse create() =>
      BatchDeleteTransactionsResponse._();
  @$core.override
  BatchDeleteTransactionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BatchDeleteTransactionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BatchDeleteTransactionsResponse>(
          create);
  static BatchDeleteTransactionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get deletedCount => $_getIZ(0);
  @$pb.TagNumber(1)
  set deletedCount($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeletedCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeletedCount() => $_clearField(1);
}

class UploadTransactionImageRequest extends $pb.GeneratedMessage {
  factory UploadTransactionImageRequest({
    $core.String? transactionId,
    $core.String? filename,
    $core.List<$core.int>? data,
    $core.String? contentType,
  }) {
    final result = create();
    if (transactionId != null) result.transactionId = transactionId;
    if (filename != null) result.filename = filename;
    if (data != null) result.data = data;
    if (contentType != null) result.contentType = contentType;
    return result;
  }

  UploadTransactionImageRequest._();

  factory UploadTransactionImageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UploadTransactionImageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UploadTransactionImageRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'transactionId')
    ..aOS(2, _omitFieldNames ? '' : 'filename')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aOS(4, _omitFieldNames ? '' : 'contentType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadTransactionImageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadTransactionImageRequest copyWith(
          void Function(UploadTransactionImageRequest) updates) =>
      super.copyWith(
              (message) => updates(message as UploadTransactionImageRequest))
          as UploadTransactionImageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UploadTransactionImageRequest create() =>
      UploadTransactionImageRequest._();
  @$core.override
  UploadTransactionImageRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UploadTransactionImageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UploadTransactionImageRequest>(create);
  static UploadTransactionImageRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transactionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transactionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransactionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransactionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get filename => $_getSZ(1);
  @$pb.TagNumber(2)
  set filename($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFilename() => $_has(1);
  @$pb.TagNumber(2)
  void clearFilename() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get data => $_getN(2);
  @$pb.TagNumber(3)
  set data($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasData() => $_has(2);
  @$pb.TagNumber(3)
  void clearData() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get contentType => $_getSZ(3);
  @$pb.TagNumber(4)
  set contentType($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasContentType() => $_has(3);
  @$pb.TagNumber(4)
  void clearContentType() => $_clearField(4);
}

class UploadTransactionImageResponse extends $pb.GeneratedMessage {
  factory UploadTransactionImageResponse({
    $core.String? imageUrl,
  }) {
    final result = create();
    if (imageUrl != null) result.imageUrl = imageUrl;
    return result;
  }

  UploadTransactionImageResponse._();

  factory UploadTransactionImageResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UploadTransactionImageResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UploadTransactionImageResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'imageUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadTransactionImageResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadTransactionImageResponse copyWith(
          void Function(UploadTransactionImageResponse) updates) =>
      super.copyWith(
              (message) => updates(message as UploadTransactionImageResponse))
          as UploadTransactionImageResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UploadTransactionImageResponse create() =>
      UploadTransactionImageResponse._();
  @$core.override
  UploadTransactionImageResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UploadTransactionImageResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UploadTransactionImageResponse>(create);
  static UploadTransactionImageResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get imageUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set imageUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasImageUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearImageUrl() => $_clearField(1);
}

class GetCategoriesRequest extends $pb.GeneratedMessage {
  factory GetCategoriesRequest({
    TransactionType? type,
  }) {
    final result = create();
    if (type != null) result.type = type;
    return result;
  }

  GetCategoriesRequest._();

  factory GetCategoriesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetCategoriesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetCategoriesRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aE<TransactionType>(1, _omitFieldNames ? '' : 'type',
        enumValues: TransactionType.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCategoriesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCategoriesRequest copyWith(void Function(GetCategoriesRequest) updates) =>
      super.copyWith((message) => updates(message as GetCategoriesRequest))
          as GetCategoriesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetCategoriesRequest create() => GetCategoriesRequest._();
  @$core.override
  GetCategoriesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetCategoriesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetCategoriesRequest>(create);
  static GetCategoriesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  TransactionType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(TransactionType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);
}

class GetCategoriesResponse extends $pb.GeneratedMessage {
  factory GetCategoriesResponse({
    $core.Iterable<Category>? categories,
  }) {
    final result = create();
    if (categories != null) result.categories.addAll(categories);
    return result;
  }

  GetCategoriesResponse._();

  factory GetCategoriesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetCategoriesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetCategoriesResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..pPM<Category>(1, _omitFieldNames ? '' : 'categories',
        subBuilder: Category.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCategoriesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCategoriesResponse copyWith(
          void Function(GetCategoriesResponse) updates) =>
      super.copyWith((message) => updates(message as GetCategoriesResponse))
          as GetCategoriesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetCategoriesResponse create() => GetCategoriesResponse._();
  @$core.override
  GetCategoriesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetCategoriesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetCategoriesResponse>(create);
  static GetCategoriesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Category> get categories => $_getList(0);
}

class CreateCategoryRequest extends $pb.GeneratedMessage {
  factory CreateCategoryRequest({
    $core.String? name,
    $core.String? iconKey,
    TransactionType? type,
    $core.String? parentId,
    $core.String? familyId,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (iconKey != null) result.iconKey = iconKey;
    if (type != null) result.type = type;
    if (parentId != null) result.parentId = parentId;
    if (familyId != null) result.familyId = familyId;
    return result;
  }

  CreateCategoryRequest._();

  factory CreateCategoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateCategoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateCategoryRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'iconKey')
    ..aE<TransactionType>(3, _omitFieldNames ? '' : 'type',
        enumValues: TransactionType.values)
    ..aOS(4, _omitFieldNames ? '' : 'parentId')
    ..aOS(5, _omitFieldNames ? '' : 'familyId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateCategoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateCategoryRequest copyWith(
          void Function(CreateCategoryRequest) updates) =>
      super.copyWith((message) => updates(message as CreateCategoryRequest))
          as CreateCategoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateCategoryRequest create() => CreateCategoryRequest._();
  @$core.override
  CreateCategoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateCategoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateCategoryRequest>(create);
  static CreateCategoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get iconKey => $_getSZ(1);
  @$pb.TagNumber(2)
  set iconKey($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIconKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearIconKey() => $_clearField(2);

  @$pb.TagNumber(3)
  TransactionType get type => $_getN(2);
  @$pb.TagNumber(3)
  set type(TransactionType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get parentId => $_getSZ(3);
  @$pb.TagNumber(4)
  set parentId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasParentId() => $_has(3);
  @$pb.TagNumber(4)
  void clearParentId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get familyId => $_getSZ(4);
  @$pb.TagNumber(5)
  set familyId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFamilyId() => $_has(4);
  @$pb.TagNumber(5)
  void clearFamilyId() => $_clearField(5);
}

class CreateCategoryResponse extends $pb.GeneratedMessage {
  factory CreateCategoryResponse({
    Category? category,
  }) {
    final result = create();
    if (category != null) result.category = category;
    return result;
  }

  CreateCategoryResponse._();

  factory CreateCategoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateCategoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateCategoryResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOM<Category>(1, _omitFieldNames ? '' : 'category',
        subBuilder: Category.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateCategoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateCategoryResponse copyWith(
          void Function(CreateCategoryResponse) updates) =>
      super.copyWith((message) => updates(message as CreateCategoryResponse))
          as CreateCategoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateCategoryResponse create() => CreateCategoryResponse._();
  @$core.override
  CreateCategoryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateCategoryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateCategoryResponse>(create);
  static CreateCategoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Category get category => $_getN(0);
  @$pb.TagNumber(1)
  set category(Category value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCategory() => $_has(0);
  @$pb.TagNumber(1)
  void clearCategory() => $_clearField(1);
  @$pb.TagNumber(1)
  Category ensureCategory() => $_ensure(0);
}

class UpdateCategoryRequest extends $pb.GeneratedMessage {
  factory UpdateCategoryRequest({
    $core.String? categoryId,
    $core.String? name,
    $core.String? iconKey,
  }) {
    final result = create();
    if (categoryId != null) result.categoryId = categoryId;
    if (name != null) result.name = name;
    if (iconKey != null) result.iconKey = iconKey;
    return result;
  }

  UpdateCategoryRequest._();

  factory UpdateCategoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateCategoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateCategoryRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'categoryId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'iconKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateCategoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateCategoryRequest copyWith(
          void Function(UpdateCategoryRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateCategoryRequest))
          as UpdateCategoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateCategoryRequest create() => UpdateCategoryRequest._();
  @$core.override
  UpdateCategoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateCategoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateCategoryRequest>(create);
  static UpdateCategoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get categoryId => $_getSZ(0);
  @$pb.TagNumber(1)
  set categoryId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCategoryId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCategoryId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get iconKey => $_getSZ(2);
  @$pb.TagNumber(3)
  set iconKey($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIconKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearIconKey() => $_clearField(3);
}

class UpdateCategoryResponse extends $pb.GeneratedMessage {
  factory UpdateCategoryResponse({
    Category? category,
  }) {
    final result = create();
    if (category != null) result.category = category;
    return result;
  }

  UpdateCategoryResponse._();

  factory UpdateCategoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateCategoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateCategoryResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOM<Category>(1, _omitFieldNames ? '' : 'category',
        subBuilder: Category.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateCategoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateCategoryResponse copyWith(
          void Function(UpdateCategoryResponse) updates) =>
      super.copyWith((message) => updates(message as UpdateCategoryResponse))
          as UpdateCategoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateCategoryResponse create() => UpdateCategoryResponse._();
  @$core.override
  UpdateCategoryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateCategoryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateCategoryResponse>(create);
  static UpdateCategoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Category get category => $_getN(0);
  @$pb.TagNumber(1)
  set category(Category value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCategory() => $_has(0);
  @$pb.TagNumber(1)
  void clearCategory() => $_clearField(1);
  @$pb.TagNumber(1)
  Category ensureCategory() => $_ensure(0);
}

class DeleteCategoryRequest extends $pb.GeneratedMessage {
  factory DeleteCategoryRequest({
    $core.String? categoryId,
  }) {
    final result = create();
    if (categoryId != null) result.categoryId = categoryId;
    return result;
  }

  DeleteCategoryRequest._();

  factory DeleteCategoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteCategoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteCategoryRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'categoryId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteCategoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteCategoryRequest copyWith(
          void Function(DeleteCategoryRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteCategoryRequest))
          as DeleteCategoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteCategoryRequest create() => DeleteCategoryRequest._();
  @$core.override
  DeleteCategoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteCategoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteCategoryRequest>(create);
  static DeleteCategoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get categoryId => $_getSZ(0);
  @$pb.TagNumber(1)
  set categoryId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCategoryId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCategoryId() => $_clearField(1);
}

class DeleteCategoryResponse extends $pb.GeneratedMessage {
  factory DeleteCategoryResponse() => create();

  DeleteCategoryResponse._();

  factory DeleteCategoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteCategoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteCategoryResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteCategoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteCategoryResponse copyWith(
          void Function(DeleteCategoryResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteCategoryResponse))
          as DeleteCategoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteCategoryResponse create() => DeleteCategoryResponse._();
  @$core.override
  DeleteCategoryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteCategoryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteCategoryResponse>(create);
  static DeleteCategoryResponse? _defaultInstance;
}

class ReorderCategoriesRequest extends $pb.GeneratedMessage {
  factory ReorderCategoriesRequest({
    $core.Iterable<CategoryOrder>? orders,
  }) {
    final result = create();
    if (orders != null) result.orders.addAll(orders);
    return result;
  }

  ReorderCategoriesRequest._();

  factory ReorderCategoriesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReorderCategoriesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReorderCategoriesRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..pPM<CategoryOrder>(1, _omitFieldNames ? '' : 'orders',
        subBuilder: CategoryOrder.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderCategoriesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderCategoriesRequest copyWith(
          void Function(ReorderCategoriesRequest) updates) =>
      super.copyWith((message) => updates(message as ReorderCategoriesRequest))
          as ReorderCategoriesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReorderCategoriesRequest create() => ReorderCategoriesRequest._();
  @$core.override
  ReorderCategoriesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReorderCategoriesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReorderCategoriesRequest>(create);
  static ReorderCategoriesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<CategoryOrder> get orders => $_getList(0);
}

class CategoryOrder extends $pb.GeneratedMessage {
  factory CategoryOrder({
    $core.String? categoryId,
    $core.int? sortOrder,
  }) {
    final result = create();
    if (categoryId != null) result.categoryId = categoryId;
    if (sortOrder != null) result.sortOrder = sortOrder;
    return result;
  }

  CategoryOrder._();

  factory CategoryOrder.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CategoryOrder.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CategoryOrder',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'categoryId')
    ..aI(2, _omitFieldNames ? '' : 'sortOrder')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CategoryOrder clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CategoryOrder copyWith(void Function(CategoryOrder) updates) =>
      super.copyWith((message) => updates(message as CategoryOrder))
          as CategoryOrder;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CategoryOrder create() => CategoryOrder._();
  @$core.override
  CategoryOrder createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CategoryOrder getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CategoryOrder>(create);
  static CategoryOrder? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get categoryId => $_getSZ(0);
  @$pb.TagNumber(1)
  set categoryId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCategoryId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCategoryId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get sortOrder => $_getIZ(1);
  @$pb.TagNumber(2)
  set sortOrder($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSortOrder() => $_has(1);
  @$pb.TagNumber(2)
  void clearSortOrder() => $_clearField(2);
}

class ReorderCategoriesResponse extends $pb.GeneratedMessage {
  factory ReorderCategoriesResponse() => create();

  ReorderCategoriesResponse._();

  factory ReorderCategoriesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReorderCategoriesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReorderCategoriesResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderCategoriesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderCategoriesResponse copyWith(
          void Function(ReorderCategoriesResponse) updates) =>
      super.copyWith((message) => updates(message as ReorderCategoriesResponse))
          as ReorderCategoriesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReorderCategoriesResponse create() => ReorderCategoriesResponse._();
  @$core.override
  ReorderCategoriesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReorderCategoriesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReorderCategoriesResponse>(create);
  static ReorderCategoriesResponse? _defaultInstance;
}

class MergeCategoriesRequest extends $pb.GeneratedMessage {
  factory MergeCategoriesRequest({
    $core.String? sourceCategoryId,
    $core.String? targetCategoryId,
  }) {
    final result = create();
    if (sourceCategoryId != null) result.sourceCategoryId = sourceCategoryId;
    if (targetCategoryId != null) result.targetCategoryId = targetCategoryId;
    return result;
  }

  MergeCategoriesRequest._();

  factory MergeCategoriesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MergeCategoriesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MergeCategoriesRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sourceCategoryId')
    ..aOS(2, _omitFieldNames ? '' : 'targetCategoryId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MergeCategoriesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MergeCategoriesRequest copyWith(
          void Function(MergeCategoriesRequest) updates) =>
      super.copyWith((message) => updates(message as MergeCategoriesRequest))
          as MergeCategoriesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MergeCategoriesRequest create() => MergeCategoriesRequest._();
  @$core.override
  MergeCategoriesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MergeCategoriesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MergeCategoriesRequest>(create);
  static MergeCategoriesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sourceCategoryId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sourceCategoryId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSourceCategoryId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSourceCategoryId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get targetCategoryId => $_getSZ(1);
  @$pb.TagNumber(2)
  set targetCategoryId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTargetCategoryId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetCategoryId() => $_clearField(2);
}

class MergeCategoriesResponse extends $pb.GeneratedMessage {
  factory MergeCategoriesResponse({
    $core.int? affectedTransactions,
  }) {
    final result = create();
    if (affectedTransactions != null)
      result.affectedTransactions = affectedTransactions;
    return result;
  }

  MergeCategoriesResponse._();

  factory MergeCategoriesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MergeCategoriesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MergeCategoriesResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'familyledger.transaction.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'affectedTransactions')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MergeCategoriesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MergeCategoriesResponse copyWith(
          void Function(MergeCategoriesResponse) updates) =>
      super.copyWith((message) => updates(message as MergeCategoriesResponse))
          as MergeCategoriesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MergeCategoriesResponse create() => MergeCategoriesResponse._();
  @$core.override
  MergeCategoriesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MergeCategoriesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MergeCategoriesResponse>(create);
  static MergeCategoriesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get affectedTransactions => $_getIZ(0);
  @$pb.TagNumber(1)
  set affectedTransactions($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAffectedTransactions() => $_has(0);
  @$pb.TagNumber(1)
  void clearAffectedTransactions() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
