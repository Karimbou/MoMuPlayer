import 'dart:async';
import 'package:logging/logging.dart';
import 'audio_effect_definitions.dart'; // Import the definitions file where AudioEffectType is defined

/// Voice effect mapping data structure
class VoiceEffectMapping {
  /// Constructor for VoiceEffectMapping
  VoiceEffectMapping({
    required this.voiceId,
    required this.appliedEffects,
    required this.createdAt,
    required this.audioSourceHash,
  });

  /// Unique identifier for the voice effect
  final int voiceId;

  /// Set of applied audio effects for the voice effect
  final Set<AudioEffectType> appliedEffects;

  /// Timestamp when the voice effect was created
  final DateTime createdAt;

  /// Hash of the audio source associated with this voice effect
  final int audioSourceHash;

  /// Method to check if the voice effect is expired based
  bool get isExpired {
    // Voice mappings expire after 10 seconds (longer than typical sound duration)
    return DateTime.now().difference(createdAt) > const Duration(seconds: 10);
  }

  @override
  /// String representation of the voice effect mapping
  String toString() {
    return 'VoiceEffectMapping(voiceId: $voiceId, effects: $appliedEffects, age: ${DateTime.now().difference(createdAt).inSeconds}s)';
  }
}

/// Enhanced voice effect cache with automatic cleanup
class VoiceEffectCache {
  /// Start a periodic cleanup task to remove expired mappings
  VoiceEffectCache() {
    // Start periodic cleanup
    _startCleanupTimer();
  }

  static final Logger _log = Logger('VoiceEffectCache');
  final Map<int, VoiceEffectMapping> _cache = {};
  Timer? _cleanupTimer;

  /// Add a voice-to-effect mapping
  void add(int voiceId, Set<AudioEffectType> effects, int sourceHash) {
    _cache[voiceId] = VoiceEffectMapping(
      voiceId: voiceId,
      appliedEffects: Set.from(effects),
      createdAt: DateTime.now(),
      audioSourceHash: sourceHash,
    );
    _log.fine('[Cache] Added mapping for voice $voiceId: $effects');
  }

  /// Get effects for a voice
  Set<AudioEffectType>? get(int voiceId) {
    final mapping = _cache[voiceId];
    if (mapping == null) {
      _log.fine('[Cache] No mapping found for voice $voiceId');
      return null;
    }

    if (mapping.isExpired) {
      _log.fine('[Cache] Mapping expired for voice $voiceId');
      _cache.remove(voiceId);
      return null;
    }

    _log.fine('[Cache] Retrieved mapping for voice $voiceId: ${mapping.appliedEffects}');
    return mapping.appliedEffects;
  }

  /// Remove expired mappings
  void removeExpired() {
    final before = _cache.length;
    _cache.removeWhere((_, mapping) => mapping.isExpired);
    final removed = before - _cache.length;
    if (removed > 0) {
      _log.fine('[Cache] Removed $removed expired mappings');
    }
  }

  /// Clear all mappings
  void clear() {
    final count = _cache.length;
    _cache.clear();
    _log.info('[Cache] Cleared $count mappings');
  }

  /// Get cache size
  int get size => _cache.length;

  /// Start periodic cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      removeExpired();
    });
  }

  /// Dispose and cleanup
  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
    _log.info('[Cache] Disposed');
  }
}