/// Backwards-compatible exports for the shared place catalogue.
///
/// This file previously duplicated `Place` and `PlacesStore`, which could
/// create ambiguous declarations if both files were imported. The canonical
/// implementation lives in `places_store.dart`.
export 'places_store.dart';
