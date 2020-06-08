import 'package:flutter/material.dart';

class FilterSheet<T> extends StatefulWidget {
  final String title;
  final bool allowNone;
  final Iterable<T> initial;
  final T Function(dynamic value) onRead;
  final dynamic Function(T value) onWrite;
  final void Function(Set<T> selected) onChanged;
  final Iterable<FilterData<T>> Function() onBuild;

  final String identifier;
  final PageStorageBucket bucket;

  const FilterSheet({
    Key key,
    @required this.initial,
    @required this.onBuild,
    @required this.onChanged,
    this.title = "Vis",
    this.allowNone = false,
    this.bucket,
    this.identifier,
    this.onRead,
    this.onWrite,
  }) : super(key: key);

  @override
  _FilterSheetState<T> createState() => _FilterSheetState<T>();

  static Set<T> read<T>(BuildContext context, String identifier, {Set<T> defaultValue, T onRead(e)}) =>
      (PageStorage.of(context)?.readState(
        context,
        identifier: identifier,
      ) as List)
          ?.map((e) => onRead != null ? onRead(e) : e as T)
          ?.toSet() ??
      defaultValue;
}

class _FilterSheetState<T> extends State<FilterSheet<T>> {
  final Set<T> _selected = <T>{};

  @override
  void initState() {
    super.initState();
    _selected.addAll(_read());
  }

  @override
  Widget build(BuildContext context) {
    final title = Theme.of(context).textTheme.headline6;
    final filter = Theme.of(context).textTheme.subtitle2;
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
    setState(() {
      if (value) {
        _selected.add(name);
      } else if (widget.allowNone || _selected.length > 1) {
        _selected.remove(name);
      }
      widget.onChanged(_write());
    });
  }

  Set<T> _read() {
    return widget.bucket == null
        ? widget.initial
        : (widget.bucket.readState(
              context,
              identifier: widget.identifier,
            ) as List)
                ?.map((e) => widget.onRead != null ? widget.onRead(e) : e as T)
                ?.toSet() ??
            widget.initial;
  }

  Set<T> _write() {
    if (widget.bucket != null) {
      widget.bucket.writeState(
        context,
        _selected.map((e) => widget.onWrite != null ? widget.onWrite(e) : e).toList(),
        identifier: widget.identifier,
      );
    }
    return Set<T>.from(_selected);
  }
}

class FilterData<T> {
  final T key;
  final String title;
  final bool selected;

  FilterData({
    @required this.key,
    @required this.title,
    this.selected = false,
  });
}
