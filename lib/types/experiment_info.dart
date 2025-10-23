class HashDetails {
  final Map<String, dynamic> _data;

  HashDetails.fromMap(Map<String, dynamic> map) : _data = map;

  /// User hash bucket (1-100) - used for consistent allocation
  int? get hashedUserIdBucket1To100 => _data['hashedUserIdBucket1To100'];

  /// User ID that was hashed for allocation
  String? get hashedUserId => _data['hashedUserId'];

  /// Hash method used (e.g., "HASH_USER_ID", "HASH_HELIUM_PERSISTENT_ID")
  String? get hashMethod => _data['hashMethod'];
}

class VariantDetails {
  final Map<String, dynamic> _data;

  VariantDetails.fromMap(Map<String, dynamic> map) : _data = map;

  /// Name or identifier of the allocation/variant (e.g., paywall template name)
  String? get allocationName => _data['allocationName'];

  /// Unique identifier for this allocation (paywall UUID)
  String? get allocationId => _data['allocationId'];

  /// Index of chosen variant (1 to len(variants))
  int? get allocationIndex => _data['allocationIndex'];

  /// Additional allocation metadata
  Map<String, dynamic>? get allocationMetadata {
    final metadata = _data['allocationMetadata'];
    if (metadata is Map) {
      return Map<String, dynamic>.from(metadata);
    }
    return null;
  }
}

class ExperimentInfo {
  final Map<String, dynamic> _data;

  ExperimentInfo.fromMap(Map<String, dynamic> map) : _data = map;

  /// Trigger name at which user was enrolled
  String get trigger => _data['trigger'] ?? '';

  /// Experiment name
  String? get experimentName => _data['experimentName'];

  /// Experiment ID
  String? get experimentId => _data['experimentId'];

  /// Experiment type (e.g., "A/B/n test")
  String? get experimentType => _data['experimentType'];

  /// Additional experiment metadata
  dynamic get experimentMetadata => _data['experimentMetadata'];

  /// When the experiment started (ISO8601 string)
  String? get startDate => _data['startDate'];

  /// When the experiment ends (ISO8601 string)
  String? get endDate => _data['endDate'];

  /// Audience ID that user matched
  String? get audienceId => _data['audienceId'];

  /// Audience data (can be String or Map)
  dynamic get audienceData => _data['audienceData'];

  /// Details about the chosen variant
  VariantDetails? get chosenVariantDetails {
    final details = _data['chosenVariantDetails'];
    if (details is Map) {
      return VariantDetails.fromMap(Map<String, dynamic>.from(details));
    }
    return null;
  }

  /// Hash bucketing details
  HashDetails? get hashDetails {
    final details = _data['hashDetails'];
    if (details is Map) {
      return HashDetails.fromMap(Map<String, dynamic>.from(details));
    }
    return null;
  }
}
