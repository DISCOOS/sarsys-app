import 'package:flutter/material.dart';

typedef SelectedCallback<T> = void Function(BuildContext context, T item);
typedef ItemWidgetBuilder<T> = Widget Function(BuildContext context, T item);

class SelectorWidget<T> extends StatelessWidget {
  final Size size;
  final String title;
  final IconData icon;
  final List<T> items;
  final TextStyle style;
  final SelectedCallback<T> onSelected;
  final ItemWidgetBuilder<T> itemBuilder;

  const SelectorWidget({
    Key key,
    @required this.style,
    @required this.size,
    @required this.icon,
    @required this.title,
    @required this.items,
    @required this.itemBuilder,
    @required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(left: 16, top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(title, style: style),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
        ),
        Divider(),
        ...items.map((item) => ListTile(
              leading: Icon(icon),
              title: itemBuilder(context, item),
              onTap: () {
                Navigator.of(context).pop();
                onSelected(context, item);
              },
            )),
//        SizedBox(
//          height: min(size.height - 150, 380),
//          width: MediaQuery.of(context).size.width - 96,
//          child: ListView.builder(
//            itemCount: items.length,
//            itemBuilder: (BuildContext context, int index) {
//              return ListTile(
//                leading: Icon(icon),
//                title: itemBuilder(context, items[index]),
//                onTap: () {
//                  Navigator.of(context).pop();
//                  onSelected(context, items[index]);
//                },
//              );
//            },
//          ),
//        ),
      ],
    );
  }
}
