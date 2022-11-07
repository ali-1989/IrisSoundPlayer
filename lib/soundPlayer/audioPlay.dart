import 'dart:async';
//import 'package:iris_tools/api/logger.dart';
import 'package:iris_sound_player/soundPlayer/format.dart';
import 'package:iris_sound_player/soundPlayer/playback_disposition.dart';
import 'package:iris_sound_player/soundPlayer/track.dart';

import 'package:iris_sound_player/soundPlayer/grayedOut.dart';
import 'package:iris_sound_player/soundPlayer/slider.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

enum PlayState {
  init,
  playing,
  paused,
}

enum SourceType {
  file,
  assets,
  network,
  buffer
}

typedef LazyLoadTrack = Future<Track> Function(BuildContext context);
typedef BeforePlay = FutureOr Function(BuildContext context, AudioPlayer player);
typedef AfterStop = void Function(BuildContext context, AudioPlayer player);
///=======================================================================================================
class SoundPlayerUI extends StatefulWidget {
  final AudioPlayer? player;
  final SourceType sourceType;
  final int barHeight;
  final Duration? audioDuration;
  final Track? track;
  final LazyLoadTrack? _lazyLoadTrack;
  final BeforePlay? beforePlay;
  final AfterStop? afterStop;
  final bool getStateFromPlayer;
  final bool enabled;
  final bool _showTitle;
  final bool _autoFocus;
  final bool oneLine;
  final bool useOfReplaceWidget;
  final Widget? replacePlayWidget;
  final Color? backgroundColor;
  final Color itemColor;

  SoundPlayerUI({
    Key? key,
    required this.sourceType,
    this.track,
    this.player,
    this.audioDuration,
    this.beforePlay,
    this.afterStop,
    this.barHeight = 60,
    bool showTitle = false,
    this.enabled = true,
    this.oneLine = true,
    this.useOfReplaceWidget = false,
    this.getStateFromPlayer = false,
    bool autoFocus = true,
    this.replacePlayWidget,
    this.backgroundColor,
    this.itemColor = Colors.black,
  })
      : _autoFocus = autoFocus,
        _showTitle = showTitle,
        _lazyLoadTrack = null, super(key: key);

  SoundPlayerUI.lazyLoader({
    Key? key,
    required this.sourceType,
    required LazyLoadTrack lazyLoadTrack,
    this.player,
    this.audioDuration,
    this.beforePlay,
    this.afterStop,
    this.barHeight = 60,
    bool showTitle = false,
    this.enabled = true,
    this.oneLine = true,
    this.useOfReplaceWidget = false,
    this.getStateFromPlayer = false,
    bool autoFocus = true,
    this.replacePlayWidget,
    this.backgroundColor,
    this.itemColor = Colors.black,
  })
      : _lazyLoadTrack = lazyLoadTrack,
        _autoFocus = autoFocus,
        _showTitle = showTitle,
        track = null, super(key: key);

  @override
  State<StatefulWidget> createState() {
    return SoundPlayerUIState();
  }
}
///=======================================================================================================
class SoundPlayerUIState extends State<SoundPlayerUI> {
  late AudioPlayer _player;
  Track? _track;
  late StreamController<PlaybackDisposition> _durationStreamCtr;
  List<StreamSubscription> _subscriptionList = [];
  PlayState _playState = PlayState.init;
  bool _isBusy = false;
  bool _isLoading = false;
  late bool _oneLine;
  late Duration _currentPos;

  SoundPlayerUIState();

  @override
  void initState() {
    super.initState();

    _oneLine = widget.oneLine;
    _durationStreamCtr = StreamController<PlaybackDisposition>.broadcast();
    _subscriptionList = [];
    _player = widget.player?? AudioPlayer();
    _track = widget.track;

    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) async {
      if(widget.getStateFromPlayer){
        _init();
      }
      else {
        _currentPos = Duration.zero;
        /// for work seek before start play
        if (widget.audioDuration != null && !_player.playing) {
          _durationStreamCtr.add( //=> sink
              PlaybackDisposition(
                  PlaybackDispositionState.init,
                  duration: widget.audioDuration!,
                  position: Duration.zero)
          );
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant SoundPlayerUI oldWidget){
    super.didUpdateWidget(oldWidget);

    _player = widget.player?? _player;
    _track = widget.track;

    if(widget.sourceType != oldWidget.sourceType) {
      _goStopPlayer(update: false);
    }

    if(widget.getStateFromPlayer && _track != null && _subscriptionList.isEmpty){
      _init().then((value) {
        if(_playState != PlayState.playing)
          _durationStreamCtr.add(
            PlaybackDisposition(
                PlaybackDispositionState.init, duration: _player.duration!, position: _player.position));
      });
    }
  }

  /// Called whenever the application is reassembled during debugging
  @override
  void reassemble() async {
    super.reassemble();

    if (getTrack() != null) {
      if (_playState != PlayState.init) {
        await _goStopPlayer(update: false);
      }

      trackRelease(getTrack()!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildPlayBar();
  }

  @override
  void dispose() {
    _unListen();

    /// has Internal player
    if(widget.player == null) {
      _goStopPlayer(update: false);
      _player.dispose();
    }

    if(_track != null) {
      trackRelease(_track!);
    }

    super.dispose();
  }

  void updateView(){
    if(mounted) {
      setState(() {});
    }
  }

  Future<void> _init() async {
    if(getTrack() == null) {
      return;
    }

    _setListeners();

    if(_player.playing) {
      return;
    }

    switch(widget.sourceType){
      case SourceType.assets:
        await _player.setAsset(getTrack()!.path!);
        break;
      case SourceType.file:
        await _player.setFilePath(getTrack()!.path!);
        break;
      case SourceType.network:
        await _player.setUrl(getTrack()!.url!);
        break;
      case SourceType.buffer:
        break;
    }
  }

  void _setListeners() {
    _unListen();

    var lis1 = _player.playbackEventStream.listen((PlaybackEvent event) {
      if(_player.playing) {
        // playing, pause
      }
      else {
        if (_playState == PlayState.playing) {
          if(_player.processingState == ProcessingState.idle){
            _onStoppedPlayer();
          }
          else {
            _onPausedPlayer();
          }
        }
      }
    });

    var lis2 = _player.processingStateStream.listen((ProcessingState st) {
      if(st == ProcessingState.loading) {
        _setStateAndUpdate(busy: true, loading: true);
      }
      else if(st == ProcessingState.buffering) {
        _setStateAndUpdate(busy: true, loading: true);
      }
      else if(st == ProcessingState.ready) {
        _setStateAndUpdate(busy: false, loading: false);
      }
      else if(st == ProcessingState.idle) {
        if(_playState != PlayState.init && !_player.playing) {
          _onStoppedPlayer();
        }
      }
      else if(st == ProcessingState.completed) {
        if(_player.playing) {
          _goStopPlayer();
        }
      }
    });

    var lis3 = _player.positionStream.listen((Duration dur) {
      // is dif with _player.playerState.playing
      if(_player.playing) {
        if(_playState != PlayState.playing) {
          _onStartedPlayer();
        }
      }

      if(_player.processingState == ProcessingState.ready){
        _durationStreamCtr.add(
            PlaybackDisposition(
              PlaybackDispositionState.playing,
              position: dur, //or _player.position
              duration: _player.duration?? dur,
            )
        );
      }
    });

    _subscriptionList.add(lis1);
    _subscriptionList.add(lis2);
    _subscriptionList.add(lis3);
  }

  void _unListen(){
    for(var sc in _subscriptionList){
      sc.cancel();
    }

    _subscriptionList.clear();
  }

  Track? getTrack() {
    return _track;
  }

  AudioPlayer getPlayer(){
    return _player;
  }

  bool get hasTrack {
    return _track != null || widget._lazyLoadTrack != null;
  }

  bool get _isDisable {
    return !widget.enabled || !hasTrack;
  }

  void _setStateAndUpdate({required bool busy, required bool loading}) {
    _isBusy = busy;//add isBusy getter by time
    _isLoading = loading;

    updateView();
  }

  Future<void> _onPlayBtnPressed(BuildContext mContext) async {
    switch (_playState) {
      case PlayState.init:
        await _goPlay();
        break;

      case PlayState.playing:
        await _goPause();
        break;

      case PlayState.paused:
        await _goResume();
        break;
    }
  }

  void _onStartedPlayer() {
    _playState = PlayState.playing;
    _setStateAndUpdate(busy: false, loading: false);
  }

  void _onPausedPlayer() {
    _playState = PlayState.paused;

    _unListen();
    _currentPos = _player.position;

    updateView();
  }

  void _onStoppedPlayer() {
    /*if (widget._autoFocus) {
      _player.audioFocus(AudioFocus.abandonFocus);
    }*/
    _unListen();
    _playState = PlayState.init;
    _isLoading = false;
    _isBusy = false;
    _currentPos = _player.position;

    updateView();
    widget.afterStop?.call(context, _player);
  }
  
  Future<void> _goPause() async {
    try {
      await _player.pause();
    }
    catch (e) {
      _playState = PlayState.init;
      //Logger.L.logToScreen('Error calling pause ${e.toString()}', type: 'Error');
    }
  }

  Future<void> _goResume() async {
    _setStateAndUpdate(busy: true, loading: false);

    if(_subscriptionList.isEmpty){
      _setListeners();
    }

    try {
      await _player.play();
    }
    catch (e) {
      _playState = PlayState.init;
    }
    finally {
      _setStateAndUpdate(busy: false, loading: false);
    }
  }

  Future<void> _goPlay() async {
    if(_playState == PlayState.playing) {
      return;
    }

    try {
      await widget.beforePlay?.call(context, _player);
      _setStateAndUpdate(busy: true, loading: false);

      if (_track == null && widget._lazyLoadTrack != null) {
        _track = await widget._lazyLoadTrack!.call(context);
      }

      var mustInit = _subscriptionList.isEmpty;
      //mustInit = mustInit || _player.processingState == ProcessingState.completed;
      //mustInit = mustInit || _playState == PlayState.init;

      if(mustInit) {
        await _init();
        await _player.seek(_currentPos);
      }

      /*if (widget._autoFocus == true) {
        await _player.audioFocus(AudioFocus.hushOthersWithResume);
      }*/

      if(_player.duration != null && _player.position.compareTo(_player.duration!) >= 0) {
        await _player.seek(Duration.zero);
      }

      _player.play();//if use await: waiting to end playing
    }
    catch (e) {
      _playState = PlayState.init;
    }
    finally {
      _setStateAndUpdate(busy: false, loading: false);
    }
  }

  Future<void> _goStopPlayer({bool update = true}) async {
    if (_playState == PlayState.playing || _player.playing) {
      await _player.stop();
    }
    else {
      _onStoppedPlayer();
    }

    if (update) {
      updateView();
    }
  }

  Widget _buildPlayBar() {
    var lines = <Widget>[];

    lines.add(Row(
        children: [
          _buildPlayButton(),

          if(_oneLine)
            _buildDuration(),

          Expanded(child: _buildSlider())
        ])
    );

    if(!_oneLine) {
      lines.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildDuration(),
      ));
    }

    if (widget._showTitle && getTrack() != null) {
      lines.add(_buildTitle());
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: DecoratedBox(
          decoration: BoxDecoration(
              color: widget.backgroundColor?? Colors.blueGrey[300],
              borderRadius: BorderRadius.circular(widget.barHeight / 3)
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4.0, 0, 4.0, 6.0),
            child: Row(
                children: [
                  Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                          children: lines
                      )
                  )
                ]
            ),
          )
      ),
    );
  }

  Widget _buildSlider() {
    return PlayBarSlider(_durationStreamCtr.stream, (position) async{
      var dur = _player.duration?? (widget.audioDuration?? position);
      _currentPos = position;

      _durationStreamCtr.add(
          PlaybackDisposition(PlaybackDispositionState.loaded, duration: dur, position: position)
      );

      if(_subscriptionList.isNotEmpty) {
        await _player.seek(position);
      }
    }, isEnable: getTrack() != null,);
  }

  Widget _buildPlayButton() {
    if(widget.useOfReplaceWidget){
      return widget.replacePlayWidget!;
    }

    bool _canPlay = hasTrack && !_isLoading && !_isBusy;

    return SizedBox(
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: _canPlay? () => _onPlayBtnPressed(context) : (){},
          child: _isLoading? _buildLoadingIcon(): _buildPlayIcon(),
        )
      );
  }

  Widget _buildPlayIcon() {
    Widget mWidget;

    switch (_playState) {
      case PlayState.playing:
        mWidget = Icon(Icons.pause, color: widget.itemColor);
        break;
      case PlayState.init:
      case PlayState.paused:
      mWidget = GrayedOut(
          grayedOut: _isDisable,
          child: Icon(Icons.play_arrow, color: _isDisable ? Colors.grey[600]: widget.itemColor)
        );
        break;
    }

    return mWidget;
  }

  Widget _buildLoadingIcon() {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: CircularProgressIndicator(
        //backgroundColor: widget.itemColor,
        valueColor: AlwaysStoppedAnimation<Color>(widget.itemColor),
        strokeWidth: 3,
        value: null,
      ),
    );
  }

  Widget _buildDuration() {
    return StreamBuilder<PlaybackDisposition>(
        stream: _durationStreamCtr.stream,
        initialData: PlaybackDisposition.zero(),
        builder: (context, snapshot) {
          if(snapshot.data == null){
            return SizedBox();
          }

          PlaybackDisposition disposition = snapshot.data!;
          var text = '${Format.duration(disposition.position, showSuffix: false)}'
              ' / ${Format.duration(disposition.duration,)}';

          return Text(text, style: TextStyle(color: widget.itemColor));
        });
  }

  Widget _buildTitle() {
    var columns = <Widget>[];

    columns.add(Text(_track!.title));
    columns.add(Text(' / '));
    columns.add(Text(_track!.artist));

    return Container(
      margin: EdgeInsets.only(bottom: 5),
      child: Row(children: columns),
    );
  }

/*void _connectRecorderStream(Stream<PlaybackDisposition> recorderStream) {
    if (recorderStream != null)
      recorderStream.listen(_durationController.add);
     else
      _player.dispositionStream().listen(_localController.add);
  }*/
}