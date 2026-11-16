import 'dart:math' as math;
import 'dart:typed_data';

/// A reader for Garmin `.fit` activity files. It needs no package: the format
/// is a plain binary list of definition and data messages.
///
/// It only pulls out what the stats use: heart rate samples, the sets of a
/// strength activity and the session totals. It never throws; a file it cannot
/// read gives null, and a file with unknown parts gives what could be read.
class FitSet {
  const FitSet({required this.startMs, required this.durMs, required this.reps, this.kg, this.active = true});

  final int startMs;
  final int durMs;
  final int reps;
  final double? kg;

  /// False for the rest periods the watch records between sets.
  final bool active;

  int get endMs => startMs + durMs;
}

class FitFile {
  int? startMs;
  int? endMs;
  int? kcal;
  int? hrAvg;
  int? hrMax;

  /// [time in ms since the epoch, beats per minute], oldest first.
  final List<List<double>> samples = [];
  final List<FitSet> sets = [];

  /// The sets that were lifted, leaving out the rests.
  List<FitSet> get lifted => [for (final s in sets) if (s.active) s];
}

const _fitEpochMs = 631065600000;

const _msgSession = 18;
const _msgRecord = 20;
const _msgSet = 225;

const _sizes = <int, int>{0: 1, 1: 1, 2: 1, 3: 2, 4: 2, 5: 4, 6: 4, 7: 1, 8: 4, 9: 8, 10: 1, 11: 2, 12: 4, 13: 1, 14: 8, 15: 8, 16: 8};

class _Field {
  const _Field(this.num, this.size, this.type);
  final int num;
  final int size;
  final int type;
}

class _Def {
  const _Def(this.global, this.big, this.fields, this.devBytes);
  final int global;
  final bool big;
  final List<_Field> fields;
  final int devBytes;

  int get size => fields.fold(0, (a, f) => a + f.size) + devBytes;
}

/// Reads [bytes] as a FIT file. Null when it is not one.
FitFile? parseFit(Uint8List bytes) {
  try {
    return _parse(bytes);
  } catch (_) {
    return null;
  }
}

bool looksLikeFit(Uint8List b) =>
    b.length > 14 && (b[0] == 12 || b[0] == 14) && b[8] == 0x2E && b[9] == 0x46 && b[10] == 0x49 && b[11] == 0x54;

FitFile? _parse(Uint8List b) {
  if (!looksLikeFit(b)) return null;
  final data = ByteData.sublistView(b);
  final header = b[0];
  final end = math.min(b.length, header + data.getUint32(4, Endian.little));
  final out = FitFile();
  final defs = <int, _Def>{};
  var pos = header;
  var lastTs = 0;
  while (pos < end) {
    final h = b[pos++];
    final int local;
    int? compressedTs;
    if (h & 0x80 != 0) {
      local = (h >> 5) & 3;
      var ts = (lastTs & ~0x1F) + (h & 0x1F);
      if (ts < lastTs) ts += 0x20;
      compressedTs = ts;
    } else if (h & 0x40 != 0) {
      final hasDev = h & 0x20 != 0;
      final slot = h & 0x0F;
      pos++;
      final big = b[pos++] == 1;
      final global = data.getUint16(pos, big ? Endian.big : Endian.little);
      pos += 2;
      final n = b[pos++];
      final fields = <_Field>[];
      for (var i = 0; i < n; i++) {
        fields.add(_Field(b[pos], b[pos + 1], b[pos + 2] & 0x1F));
        pos += 3;
      }
      var dev = 0;
      if (hasDev) {
        final m = b[pos++];
        for (var i = 0; i < m; i++) {
          dev += b[pos + 1];
          pos += 3;
        }
      }
      defs[slot] = _Def(global, big, fields, dev);
      continue;
    } else {
      local = h & 0x0F;
    }
    final def = defs[local];
    if (def == null || pos + def.size > b.length) break;
    final endian = def.big ? Endian.big : Endian.little;
    final values = <int, num>{};
    var p = pos;
    for (final f in def.fields) {
      final v = _read(data, p, f, endian);
      if (v != null) values[f.num] = v;
      p += f.size;
    }
    pos += def.size;
    final stamp = values[253]?.toInt() ?? compressedTs;
    if (stamp != null) lastTs = stamp;
    switch (def.global) {
      case _msgRecord:
        _addRecord(out, stamp, values);
      case _msgSession:
        _addSession(out, values);
      case _msgSet:
        _addSet(out, stamp, values);
    }
  }
  if (out.samples.isNotEmpty) {
    out.samples.sort((a, b) => a[0].compareTo(b[0]));
    out.startMs ??= out.samples.first[0].round();
    out.endMs = out.samples.last[0].round();
  }
  if (out.sets.isNotEmpty) {
    out.startMs ??= out.sets.first.startMs;
    final last = out.sets.map((s) => s.endMs).reduce(math.max);
    out.endMs = math.max(out.endMs ?? 0, last);
  }
  if (out.samples.isEmpty && out.sets.isEmpty && out.kcal == null) return null;
  return out;
}

void _addRecord(FitFile out, int? stamp, Map<int, num> values) {
  final bpm = values[3];
  if (stamp == null || bpm == null || bpm <= 30 || bpm >= 250) return;
  out.samples.add([(stamp * 1000 + _fitEpochMs).toDouble(), bpm.toDouble()]);
}

void _addSession(FitFile out, Map<int, num> values) {
  final start = values[2]?.toInt();
  if (start != null && out.startMs == null) out.startMs = start * 1000 + _fitEpochMs;
  final kcal = values[11]?.toInt();
  if (kcal != null) out.kcal = (out.kcal ?? 0) + kcal;
  out.hrAvg ??= values[16]?.toInt();
  final top = values[17]?.toInt();
  if (top != null) out.hrMax = math.max(out.hrMax ?? 0, top);
}

/// A set message. The start comes from field 6; some files only carry the
/// timestamp (field 253, or 254 in some profiles), which is used instead.
void _addSet(FitFile out, int? stamp, Map<int, num> values) {
  final startSet = values[6]?.toInt();
  final stampSet = stamp ?? values[254]?.toInt();
  final base = startSet ?? stampSet;
  if (base == null) return;
  final w = values[4];
  out.sets.add(FitSet(
    startMs: base * 1000 + _fitEpochMs,
    durMs: values[0]?.toInt() ?? 0,
    reps: values[3]?.toInt() ?? 0,
    kg: w == null || w <= 0 ? null : w / 16,
    active: (values[5]?.toInt() ?? 1) == 1,
  ));
}

num? _read(ByteData d, int p, _Field f, Endian e) {
  final size = _sizes[f.type];
  if (size == null || f.size < size || p + size > d.lengthInBytes) return null;
  num? raw;
  num? invalid;
  switch (f.type) {
    case 0 || 2 || 13:
      raw = d.getUint8(p);
      invalid = 0xFF;
    case 10:
      raw = d.getUint8(p);
      invalid = 0;
    case 1:
      raw = d.getInt8(p);
      invalid = 0x7F;
    case 3:
      raw = d.getInt16(p, e);
      invalid = 0x7FFF;
    case 4:
      raw = d.getUint16(p, e);
      invalid = 0xFFFF;
    case 11:
      raw = d.getUint16(p, e);
      invalid = 0;
    case 5:
      raw = d.getInt32(p, e);
      invalid = 0x7FFFFFFF;
    case 6:
      raw = d.getUint32(p, e);
      invalid = 0xFFFFFFFF;
    case 12:
      raw = d.getUint32(p, e);
      invalid = 0;
    case 8:
      raw = d.getFloat32(p, e);
    case 9:
      raw = d.getFloat64(p, e);
  }
  if (raw == null || (invalid != null && raw == invalid)) return null;
  if (raw is double && !raw.isFinite) return null;
  return raw;
}
