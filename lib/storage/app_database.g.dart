// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $EntriesTable extends Entries with TableInfo<$EntriesTable, EntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<int> mood = GeneratedColumn<int>(
    'mood',
    aliasedName,
    false,
    check: () => ComparableExpr(mood).isBetweenValues(1, 5),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _utcOffsetMinutesMeta = const VerificationMeta(
    'utcOffsetMinutes',
  );
  @override
  late final GeneratedColumn<int> utcOffsetMinutes = GeneratedColumn<int>(
    'utc_offset_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AnalysisStatus, String>
  analysisStatus = GeneratedColumn<String>(
    'analysis_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<AnalysisStatus>($EntriesTable.$converteranalysisStatus);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mood,
    body,
    createdAt,
    utcOffsetMinutes,
    analysisStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    } else if (isInserting) {
      context.missing(_moodMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('utc_offset_minutes')) {
      context.handle(
        _utcOffsetMinutesMeta,
        utcOffsetMinutes.isAcceptableOrUnknown(
          data['utc_offset_minutes']!,
          _utcOffsetMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_utcOffsetMinutesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mood'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      utcOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}utc_offset_minutes'],
      )!,
      analysisStatus: $EntriesTable.$converteranalysisStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}analysis_status'],
        )!,
      ),
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AnalysisStatus, String, String>
  $converteranalysisStatus = const EnumNameConverter<AnalysisStatus>(
    AnalysisStatus.values,
  );
}

class EntryRow extends DataClass implements Insertable<EntryRow> {
  final int id;
  final int mood;
  final String? body;

  /// Instant de la saisie, en UTC.
  final DateTime createdAt;

  /// Décalage horaire local au moment de la saisie, en minutes.
  final int utcOffsetMinutes;
  final AnalysisStatus analysisStatus;
  const EntryRow({
    required this.id,
    required this.mood,
    this.body,
    required this.createdAt,
    required this.utcOffsetMinutes,
    required this.analysisStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['mood'] = Variable<int>(mood);
    if (!nullToAbsent || body != null) {
      map['text'] = Variable<String>(body);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['utc_offset_minutes'] = Variable<int>(utcOffsetMinutes);
    {
      map['analysis_status'] = Variable<String>(
        $EntriesTable.$converteranalysisStatus.toSql(analysisStatus),
      );
    }
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      mood: Value(mood),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      createdAt: Value(createdAt),
      utcOffsetMinutes: Value(utcOffsetMinutes),
      analysisStatus: Value(analysisStatus),
    );
  }

  factory EntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryRow(
      id: serializer.fromJson<int>(json['id']),
      mood: serializer.fromJson<int>(json['mood']),
      body: serializer.fromJson<String?>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      utcOffsetMinutes: serializer.fromJson<int>(json['utcOffsetMinutes']),
      analysisStatus: $EntriesTable.$converteranalysisStatus.fromJson(
        serializer.fromJson<String>(json['analysisStatus']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mood': serializer.toJson<int>(mood),
      'body': serializer.toJson<String?>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'utcOffsetMinutes': serializer.toJson<int>(utcOffsetMinutes),
      'analysisStatus': serializer.toJson<String>(
        $EntriesTable.$converteranalysisStatus.toJson(analysisStatus),
      ),
    };
  }

  EntryRow copyWith({
    int? id,
    int? mood,
    Value<String?> body = const Value.absent(),
    DateTime? createdAt,
    int? utcOffsetMinutes,
    AnalysisStatus? analysisStatus,
  }) => EntryRow(
    id: id ?? this.id,
    mood: mood ?? this.mood,
    body: body.present ? body.value : this.body,
    createdAt: createdAt ?? this.createdAt,
    utcOffsetMinutes: utcOffsetMinutes ?? this.utcOffsetMinutes,
    analysisStatus: analysisStatus ?? this.analysisStatus,
  );
  EntryRow copyWithCompanion(EntriesCompanion data) {
    return EntryRow(
      id: data.id.present ? data.id.value : this.id,
      mood: data.mood.present ? data.mood.value : this.mood,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      utcOffsetMinutes: data.utcOffsetMinutes.present
          ? data.utcOffsetMinutes.value
          : this.utcOffsetMinutes,
      analysisStatus: data.analysisStatus.present
          ? data.analysisStatus.value
          : this.analysisStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryRow(')
          ..write('id: $id, ')
          ..write('mood: $mood, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('utcOffsetMinutes: $utcOffsetMinutes, ')
          ..write('analysisStatus: $analysisStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, mood, body, createdAt, utcOffsetMinutes, analysisStatus);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryRow &&
          other.id == this.id &&
          other.mood == this.mood &&
          other.body == this.body &&
          other.createdAt == this.createdAt &&
          other.utcOffsetMinutes == this.utcOffsetMinutes &&
          other.analysisStatus == this.analysisStatus);
}

class EntriesCompanion extends UpdateCompanion<EntryRow> {
  final Value<int> id;
  final Value<int> mood;
  final Value<String?> body;
  final Value<DateTime> createdAt;
  final Value<int> utcOffsetMinutes;
  final Value<AnalysisStatus> analysisStatus;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.mood = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.utcOffsetMinutes = const Value.absent(),
    this.analysisStatus = const Value.absent(),
  });
  EntriesCompanion.insert({
    this.id = const Value.absent(),
    required int mood,
    this.body = const Value.absent(),
    required DateTime createdAt,
    required int utcOffsetMinutes,
    required AnalysisStatus analysisStatus,
  }) : mood = Value(mood),
       createdAt = Value(createdAt),
       utcOffsetMinutes = Value(utcOffsetMinutes),
       analysisStatus = Value(analysisStatus);
  static Insertable<EntryRow> custom({
    Expression<int>? id,
    Expression<int>? mood,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
    Expression<int>? utcOffsetMinutes,
    Expression<String>? analysisStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mood != null) 'mood': mood,
      if (body != null) 'text': body,
      if (createdAt != null) 'created_at': createdAt,
      if (utcOffsetMinutes != null) 'utc_offset_minutes': utcOffsetMinutes,
      if (analysisStatus != null) 'analysis_status': analysisStatus,
    });
  }

  EntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? mood,
    Value<String?>? body,
    Value<DateTime>? createdAt,
    Value<int>? utcOffsetMinutes,
    Value<AnalysisStatus>? analysisStatus,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      mood: mood ?? this.mood,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      utcOffsetMinutes: utcOffsetMinutes ?? this.utcOffsetMinutes,
      analysisStatus: analysisStatus ?? this.analysisStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mood.present) {
      map['mood'] = Variable<int>(mood.value);
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (utcOffsetMinutes.present) {
      map['utc_offset_minutes'] = Variable<int>(utcOffsetMinutes.value);
    }
    if (analysisStatus.present) {
      map['analysis_status'] = Variable<String>(
        $EntriesTable.$converteranalysisStatus.toSql(analysisStatus.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('mood: $mood, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('utcOffsetMinutes: $utcOffsetMinutes, ')
          ..write('analysisStatus: $analysisStatus')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => id.equals(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lowMoodSensitivityMeta =
      const VerificationMeta('lowMoodSensitivity');
  @override
  late final GeneratedColumn<String> lowMoodSensitivity =
      GeneratedColumn<String>(
        'low_mood_sensitivity',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [id, lowMoodSensitivity];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('low_mood_sensitivity')) {
      context.handle(
        _lowMoodSensitivityMeta,
        lowMoodSensitivity.isAcceptableOrUnknown(
          data['low_mood_sensitivity']!,
          _lowMoodSensitivityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lowMoodSensitivityMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lowMoodSensitivity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}low_mood_sensitivity'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingsRow extends DataClass implements Insertable<SettingsRow> {
  final int id;

  /// Degré de sensibilité aux humeurs basses, par son nom (`LowMoodSensitivity`).
  final String lowMoodSensitivity;
  const SettingsRow({required this.id, required this.lowMoodSensitivity});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['low_mood_sensitivity'] = Variable<String>(lowMoodSensitivity);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      lowMoodSensitivity: Value(lowMoodSensitivity),
    );
  }

  factory SettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsRow(
      id: serializer.fromJson<int>(json['id']),
      lowMoodSensitivity: serializer.fromJson<String>(
        json['lowMoodSensitivity'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lowMoodSensitivity': serializer.toJson<String>(lowMoodSensitivity),
    };
  }

  SettingsRow copyWith({int? id, String? lowMoodSensitivity}) => SettingsRow(
    id: id ?? this.id,
    lowMoodSensitivity: lowMoodSensitivity ?? this.lowMoodSensitivity,
  );
  SettingsRow copyWithCompanion(SettingsCompanion data) {
    return SettingsRow(
      id: data.id.present ? data.id.value : this.id,
      lowMoodSensitivity: data.lowMoodSensitivity.present
          ? data.lowMoodSensitivity.value
          : this.lowMoodSensitivity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRow(')
          ..write('id: $id, ')
          ..write('lowMoodSensitivity: $lowMoodSensitivity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, lowMoodSensitivity);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRow &&
          other.id == this.id &&
          other.lowMoodSensitivity == this.lowMoodSensitivity);
}

class SettingsCompanion extends UpdateCompanion<SettingsRow> {
  final Value<int> id;
  final Value<String> lowMoodSensitivity;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.lowMoodSensitivity = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    required String lowMoodSensitivity,
  }) : lowMoodSensitivity = Value(lowMoodSensitivity);
  static Insertable<SettingsRow> custom({
    Expression<int>? id,
    Expression<String>? lowMoodSensitivity,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lowMoodSensitivity != null)
        'low_mood_sensitivity': lowMoodSensitivity,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? lowMoodSensitivity,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      lowMoodSensitivity: lowMoodSensitivity ?? this.lowMoodSensitivity,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lowMoodSensitivity.present) {
      map['low_mood_sensitivity'] = Variable<String>(lowMoodSensitivity.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('lowMoodSensitivity: $lowMoodSensitivity')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [entries, settings];
}

typedef $$EntriesTableCreateCompanionBuilder = EntriesCompanion Function({
  Value<int> id,
  required int mood,
  Value<String?> body,
  required DateTime createdAt,
  required int utcOffsetMinutes,
  required AnalysisStatus analysisStatus,
});
typedef $$EntriesTableUpdateCompanionBuilder = EntriesCompanion Function({
  Value<int> id,
  Value<int> mood,
  Value<String?> body,
  Value<DateTime> createdAt,
  Value<int> utcOffsetMinutes,
  Value<AnalysisStatus> analysisStatus,
});

class $$EntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get utcOffsetMinutes => $composableBuilder(
    column: $table.utcOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AnalysisStatus, AnalysisStatus, String>
  get analysisStatus => $composableBuilder(
    column: $table.analysisStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$EntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get utcOffsetMinutes => $composableBuilder(
    column: $table.utcOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisStatus => $composableBuilder(
    column: $table.analysisStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get utcOffsetMinutes => $composableBuilder(
    column: $table.utcOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<AnalysisStatus, String> get analysisStatus =>
      $composableBuilder(
        column: $table.analysisStatus,
        builder: (column) => column,
      );
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntriesTable,
          EntryRow,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (EntryRow, BaseReferences<_$AppDatabase, $EntriesTable, EntryRow>),
          EntryRow,
          PrefetchHooks Function()
        > {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> mood = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> utcOffsetMinutes = const Value.absent(),
                Value<AnalysisStatus> analysisStatus = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                mood: mood,
                body: body,
                createdAt: createdAt,
                utcOffsetMinutes: utcOffsetMinutes,
                analysisStatus: analysisStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int mood,
                Value<String?> body = const Value.absent(),
                required DateTime createdAt,
                required int utcOffsetMinutes,
                required AnalysisStatus analysisStatus,
              }) => EntriesCompanion.insert(
                id: id,
                mood: mood,
                body: body,
                createdAt: createdAt,
                utcOffsetMinutes: utcOffsetMinutes,
                analysisStatus: analysisStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntriesTable, EntryRow>(table),
                  BaseReferences<_$AppDatabase, $EntriesTable, EntryRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntriesTable,
      EntryRow,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (EntryRow, BaseReferences<_$AppDatabase, $EntriesTable, EntryRow>),
      EntryRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  Value<int> id,
  required String lowMoodSensitivity,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<int> id,
  Value<String> lowMoodSensitivity,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lowMoodSensitivity => $composableBuilder(
    column: $table.lowMoodSensitivity,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lowMoodSensitivity => $composableBuilder(
    column: $table.lowMoodSensitivity,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get lowMoodSensitivity => $composableBuilder(
    column: $table.lowMoodSensitivity,
    builder: (column) => column,
  );
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingsRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingsRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingsRow>,
          ),
          SettingsRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> lowMoodSensitivity = const Value.absent(),
              }) => SettingsCompanion(
                id: id,
                lowMoodSensitivity: lowMoodSensitivity,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String lowMoodSensitivity,
              }) => SettingsCompanion.insert(
                id: id,
                lowMoodSensitivity: lowMoodSensitivity,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingsRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingsRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingsRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingsRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingsRow>),
      SettingsRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
