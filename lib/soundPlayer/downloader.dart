import 'dart:async';
import 'dart:io';

import 'package:iris_sound_player/soundPlayer/playback_disposition.dart';

class Downloader {

  static Future<void> download(String url, String saveToPath, {LoadingProgress progress = noProgress}) async {

    var completer = Completer<void>();
    _showProgress(progress, PlaybackDisposition.preload());

    var client = HttpClient();
    unawaited(client.getUrl(Uri.parse(url)).then((request) {

      return request.close();
    }).then((response) async {
      _showProgress(progress, PlaybackDisposition.loading(progress: 0.0));

      var lengthReceived = 0;
      var contentLength = response.contentLength;

      var saveFile = File(saveToPath);
      var raf = await saveFile.open(mode: FileMode.append);
      await raf.truncate(0);

      late StreamSubscription<List<int>> subscription;

      subscription = response.listen((newBytes) async {
          subscription.pause();

          await raf.writeFrom(newBytes);
          subscription.resume();
          lengthReceived += newBytes.length;

          var percent = 0.0;
          if (contentLength != 0) percent = lengthReceived / contentLength;
          _showProgress(progress, PlaybackDisposition.loading(progress: percent));

        },

        onDone: () async {
          await raf.close();
          _showProgress(progress, PlaybackDisposition.loaded());
          completer.complete();
        },

        // ignore: avoid_types_on_closure_parameters
        onError: (Object e, StackTrace st) async {
          _showProgress(progress, PlaybackDisposition.error());
          await raf.close();
          completer.completeError(e, st);
        },
        cancelOnError: true,
      );
    }));

    return completer.future;
  }

  static void _showProgress(
      LoadingProgress progress, PlaybackDisposition disposition) {
    progress(disposition);
  }
}
