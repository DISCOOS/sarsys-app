import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

enum ActionGroupType { buttonBar, popupMenuButton }

class ActionMenuItem {
  const ActionMenuItem({
    this.child,
    this.onPressed,
  });

  final Widget child;
  final VoidCallback onPressed;
}

/// Signature used by [ActionGroupBuilder] to lazily
/// construct the items when items are about to be drawn.
///
typedef ActionItemBuilder = List<ActionMenuItem> Function(BuildContext context);

class ActionGroupBuilder extends StatelessWidget {
  ActionGroupBuilder({
    @required this.type,
    @required this.builder,
  });
  final ActionGroupType type;
  final ActionItemBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: _buildActionType(context),
    );
  }

  Widget _buildActionType(BuildContext context) {
    switch (type) {
      case ActionGroupType.buttonBar:
        return _buildButtonBar(context);
      case ActionGroupType.popupMenuButton:
        return _buildButtonMenu(context);
    }
    return _buildButtonBar(context);
  }

  Widget _buildButtonBar(BuildContext context) {
    final actions = builder(context);
    return ButtonBarTheme(
      // make buttons use the appropriate styles for cards
      child: ButtonBar(
        children: actions.map((item) => item.child).toList(),
      ),
      data: ButtonBarThemeData(
        alignment: MainAxisAlignment.end,
        layoutBehavior: ButtonBarLayoutBehavior.constrained,
        buttonPadding: EdgeInsets.all(0.0),
      ),
    );
  }

  Widget _buildButtonMenu(BuildContext context) {
    final actions = builder(context);
    return PopupMenuButton<ActionMenuItem>(
      onSelected: (action) => action.onPressed(),
      itemBuilder: (BuildContext context) {
        return actions.map((ActionMenuItem item) {
          return PopupMenuItem<ActionMenuItem>(
            value: item,
            child: item.child,
          );
        }).toList();
      },
    );
  }
}
