import 'package:angular/src/compiler/identifiers.dart';
import 'package:angular/src/compiler/output/output_ast.dart' as o;
import 'package:angular/src/core/linker/view_type.dart';
import 'package:angular/src/core/metadata.dart';

import 'compile_view.dart';

void initStyleEncapsulation(CompileView view, o.ClassStmt viewClass) {
  // Host views never have styles to initializes.
  if (view.viewType != ViewType.host) {
    _ViewStyleLinker(view, viewClass).initStyleEncapsulation();
  }
}

class _ViewStyleLinker {
  static const _initComponentStyles = 'initComponentStyles';
  static const _debugComponentUrl = '_debugComponentUrl';
  static const _componentStylesStatic = '_componentStyles';
  static const _componentStylesMember = 'componentStyles';

  final CompileView _view;
  final o.ClassStmt _class;

  const _ViewStyleLinker(this._view, this._class)
      : assert(_view != null),
        assert(_class != null);

  bool get _isComponentView => _view.viewType == ViewType.component;

  bool get _hasScopedStyles =>
      _view.component.template.encapsulation == ViewEncapsulation.Emulated;

  o.ExternalExpr get _styleType => o.importExpr(_hasScopedStyles
      ? StyleEncapsulation.componentStylesScoped
      : StyleEncapsulation.componentStylesUnscoped);

  void initStyleEncapsulation() {
    // We need to call initComponentStyles() before we handle any constant
    // bindings, which may attempt to update styles in the constructor body.
    // As an easy hack to ensure this, we just insert this call at the beginning
    // of the constructor body.
    _class.constructorMethod.body.insert(
      0,
      o.InvokeMemberMethodExpr(_initComponentStyles, const []).toStmt(),
    );
    if (_isComponentView) {
      _initStyleEncapsulationForComponentViews();
    }
  }

  void _initStyleEncapsulationForComponentViews() {
    _addStaticDebugUrlGetter();
    _addStaticComponentStylesField();
    _overrideInitComponentStyles();
  }

  void _addStaticDebugUrlGetter() {
    _class.getters.add(
      o.ClassGetter(
        _debugComponentUrl,
        [
          o.ReturnStatement(
            o.ConditionalExpr(
              o.importExpr(Identifiers.isDevMode),
              o.literal(_view.component.type.moduleUrl),
              o.NULL_EXPR,
            ),
          ),
        ],
        o.BuiltinType(o.BuiltinTypeName.String),
        [
          o.StmtModifier.Static,
        ],
      ),
    );
  }

  static final _componentStyles = o.ClassField(
    _componentStylesStatic,
    outputType: o.importType(StyleEncapsulation.componentStyles),
    modifiers: const [o.StmtModifier.Static],
  );

  void _addStaticComponentStylesField() {
    _class.fields.add(_componentStyles);
  }

  void _overrideInitComponentStyles() {
    final staticCacheField = o.ReadStaticMemberExpr(_componentStylesStatic);

    // **NOTE**: It might tempting to try and minimize a lot of this by using
    // "static final", but Dart2JS emits much more defensive code in that case
    // in order to avoid eager instantiation.
    const localStylesVar = 'styles';

    // var styles = Static._componentStyles;
    final defineStyles = o.DeclareVarStmt(localStylesVar, staticCacheField);
    final readStyles = o.ReadVarExpr(localStylesVar);

    // if (styles == null) {
    //   Static._componentStyles = styles = ComponentStyles(...);
    // }
    final ifStylesNullInit = o.IfStmt(
      readStyles.identical(o.NULL_EXPR),
      [
        o.WriteStaticMemberExpr(
          _componentStylesStatic,
          o.WriteVarExpr(
            localStylesVar,
            o.WriteStaticMemberExpr(
              _componentStylesStatic,
              _styleType.instantiate([
                _view.styles,
                o.ReadVarExpr(_debugComponentUrl),
              ]),
            ),
          ),
        ).toStmt(),
      ],
    );

    // this.componentStyles = styles;
    final assignMember = o.WriteClassMemberExpr(
      _componentStylesMember,
      readStyles,
    ).toStmt();

    _class.methods.add(
      o.ClassMethod(
        _initComponentStyles,
        const [],
        [
          defineStyles,
          ifStylesNullInit,
          assignMember,
        ],
        o.BuiltinType(o.BuiltinTypeName.Void),
        const [],
        [
          o.importExpr(Identifiers.dartCoreOverride),
        ],
      ),
    );
  }
}
