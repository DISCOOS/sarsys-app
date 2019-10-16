import 'package:flutter/material.dart';

class FilterSheet<T> extends StatefulWidget {
  final String title;
  final bool allowNone;
  final Iterable<T> initial;
  final void Function(Set<T> selected) onChanged;
  final Iterable<FilterData<T>> Function() onBuild;

  const FilterSheet({
    Key key,
    @required this.initial,
    @required this.onBuild,
    @required this.onChanged,
    this.title = "Vis",
    this.allowNone = false,
  }) : super(key: key);

  @override
  _FilterSheetState<T> createState() => _FilterSheetState<T>();
}

class _FilterSheetState<T> extends State<FilterSheet<T>> {
  final Set<T> _selected = <T>{};

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    final title = Theme.of(context).textTheme.title;
    final filter = Theme.of(context).textTheme.subtitle;
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, controller) {
        return ListView(
          padding: EdgeInsets.only(bottom: 56.0),
          children: <Widget>[
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.only(left: 16.0, right: 0),
              title: Text(widget.title, style: title),
              trailing: FlatButton(
                child: Text('LUKK', textAlign: TextAlign.center, style: TextStyle(fontSize: 14.0)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Divider(),
            ...widget.onBuild().map((data) => _build(data, filter)).toList(),
          ],
        );
      },
    );
  }

  ListTile _build(FilterData data, TextStyle filter) {
    return ListTile(
      dense: true,
      title: Text(data.title, style: filter),
      trailing: Switch(
        value: _selected.contains(data.key),
        onChanged: (value) => _onFilterChanged(data.key, value),
      ),
    );
  }

  void _onFilterChanged(T name, bool value) {
    if (value) {
      _selected.add(name);
    } else if (widget.allowNone || _selected.length > 1) {
      _selected.remove(name);
    }
    widget.onChanged(Set<T>.from(_selected));
  }
}

class FilterData<T> {
  final T key;
  final String title;
  final bool selected;

  FilterData({
    @required this.key,
    @required this.title,
    @required this.selected,
  });
}
