import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TrackingView extends StatelessWidget {
  const TrackingView({
    Key key,
    this.tuuid,
    this.onMessage,
    this.onComplete,
  }) : super(key: key);

  final String tuuid;
  final VoidCallback onComplete;
  final MessageCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final bloc = context.bloc<TrackingBloc>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildTrackingInfo(context, bloc),
        _buildEffortInfo(context, bloc.trackings[tuuid]),
      ],
    );
  }

  Row _buildTrackingInfo(BuildContext context, TrackingBloc bloc) {
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Apparater",
            icon: Icon(MdiIcons.cellphoneBasic),
            value: _toDeviceNumbers(bloc.devices(tuuid)),
            onMessage: onMessage,
            onComplete: onComplete,
          ),
        ),
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Avstand sporet",
            icon: Icon(MdiIcons.tapeMeasure),
            value: formatDistance(bloc.trackings[tuuid]?.distance),
            onMessage: onMessage,
            onComplete: onComplete,
          ),
        ),
      ],
    );
  }

  String _toDeviceNumbers(Iterable<Device> devices) {
    final numbers = devices?.map((device) => device.number);
    return numbers?.isNotEmpty == true ? numbers.join(', ') : 'Ingen';
  }

  Row _buildEffortInfo(BuildContext context, Tracking tracking) {
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Innsatstid",
            icon: Icon(Icons.timer),
            value: "${formatDuration(tracking?.effort)}",
            onMessage: onMessage,
            onComplete: onComplete,
          ),
        ),
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Gj.snitthastiget",
            icon: Icon(MdiIcons.speedometer),
            value: "${(tracking?.speed ?? 0.0 * 3.6).toStringAsFixed(1)} km/t",
            onMessage: onMessage,
            onComplete: onComplete,
          ),
        ),
      ],
    );
  }
}
