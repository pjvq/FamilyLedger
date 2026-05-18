/// Domain layer contracts — abstract repository interfaces.
///
/// These define WHAT the app can do, not HOW it's done.
/// Concrete implementations live in `data/` layer.
///
/// M3: Establishes the missing domain layer boundary.
/// Providers should depend on these interfaces (via Riverpod),
/// enabling clean testing without real DB or network.
library;

export 'i_transaction_repository.dart';
export 'i_account_repository.dart';
export 'i_category_repository.dart';
