import 'package:angular/src/compiler/compile_metadata.dart';
import 'package:angular/src/compiler/output/output_ast.dart' as o;

/// Provider interface passed to view compiler backends to generate code
/// to instantiate a provider and consume.
///
/// This allows us to hide the hierarchical nature of provider lookups and
/// the actual resolution from view compiler backend.
abstract class ProviderSource {
  final CompileTokenMetadata token;

  ProviderSource(this.token);

  o.Expression build();

  /// Whether a dynamic `injectorGet(...)` is required to resolve this provider.
  ///
  /// For example:
  /// ```dart
  ///   // DependencyService is dynamically required to resolve MyService.
  ///   _MyService = MyService(injectorGet(DependencyService));
  /// ```
  bool get hasDynamicDependencies;
}
