import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iris_sound_player/soundPlayer/playback_disposition.dart';

typedef void SeekCallable(Duration position);

class PlayBarSlider extends StatefulWidget {
  final SeekCallable _seekCallBack;
  final Stream<PlaybackDisposition> _durationStream;
  final bool isEnable;

  PlayBarSlider(
      this._durationStream,
      this._seekCallBack, {
        this.isEnable = true,
        Key? key,
      }): super(key: key);

  @override
  State<StatefulWidget> createState() {
    return PlayBarSliderState();
  }
}
///========================================================================================================
class PlayBarSliderState extends State<PlayBarSlider> {
  void Function(double val)? _onChangeSeek;

  PlayBarSliderState();

  @override
  void initState(){
    super.initState();

    _onChangeSeek = (value){
      widget._seekCallBack.call(Duration(milliseconds: value.toInt()));
    };
  }

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
        data: SliderTheme.of(context).copyWith(
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
            //inactiveTrackColor: Colors.blueGrey
        ),
        child: StreamBuilder<PlaybackDisposition>(
            stream: widget._durationStream,
            initialData: PlaybackDisposition.zero(),
            builder: (context, snapshot) {
              PlaybackDisposition? disposition = snapshot.data;
              double max = disposition?.duration.inMilliseconds.toDouble()?? 0;
              double value = disposition?.position.inMilliseconds.toDouble()?? 0;

              if(value > max)
                value = max;

              return Slider(
                max: max,
                value: value,
                onChanged: widget.isEnable? _onChangeSeek: null,
              );
            }
        )
    );
  }
}
///========================================================================================================
/*
class SliderPositionNotifier extends ChangeNotifier {
  Duration _position = Duration.zero;
  Duration maxPosition = Duration.zero;
  bool _disposed = false;

  void setPosition(Duration position) {
    _position = position;

    if (!_disposed)
      notifyListeners();
  }

  Duration getPosition() {
    return _position;
  }

  void dispose() {
    _disposed = true;
    super.dispose();
  }
}*/
