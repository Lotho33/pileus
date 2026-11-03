import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

/// Binding for the web entry points that keeps a decoded image reusable
/// when the browser can't decode it a second time.
///
/// CanvasKit decodes with WebCodecs' `ImageDecoder` only on Chromium in a
/// secure context. Anywhere else (the web app over plain http from a LAN
/// address like `http://10.0.0.204:8000/app`, Firefox, Safari, a packaged
/// TV app) the codec is backed by a hidden `<img>` whose `src` the engine
/// clears once the first frame's image is released.
///
/// cached_network_image's MultiImageStreamCompleter asks its codec for a
/// fresh frame every time an image regains a listener, e.g. when a plugin
/// page is shown again. From an emptied `<img>` that frame is blank
/// (`texImage2D: no image` in the console), and it replaces the good one:
/// posters, heroes and logos went empty after switching plugin page and
/// back (found with remote DevTools on a phone). For a still image the
/// first frame is the only frame, so later requests get a clone of it.
class PileusWebBinding extends WidgetsFlutterBinding {
  static bool _created = false;

  static void ensureInitialized() {
    if (_created) return;
    _created = true;
    PileusWebBinding();
  }

  static final bool _usesImgElementCodecs =
      ui_web.browser.browserEngine != ui_web.BrowserEngine.blink ||
          !globalContext.has('ImageDecoder');

  @override
  Future<ui.Codec> instantiateImageCodecWithSize(
    ui.ImmutableBuffer buffer, {
    ui.TargetImageSizeCallback? getTargetSize,
  }) async {
    final codec = await super
        .instantiateImageCodecWithSize(buffer, getTargetSize: getTargetSize);
    if (!_usesImgElementCodecs || codec.frameCount != 1) return codec;
    return _StillImageCodec(codec);
  }
}

/// A single-frame codec that decodes once and hands out clones afterwards.
/// The kept image is released on [dispose], or by the engine's finalizer
/// when the codec is dropped without one (the completer never disposes it).
class _StillImageCodec implements ui.Codec {
  _StillImageCodec(this._inner);

  final ui.Codec _inner;
  ui.FrameInfo? _first;

  @override
  int get frameCount => 1;

  @override
  int get repetitionCount => _inner.repetitionCount;

  @override
  Future<ui.FrameInfo> getNextFrame() async {
    final first = _first ??= await _inner.getNextFrame();
    return _Frame(first.duration, first.image.clone());
  }

  @override
  void dispose() {
    _first?.image.dispose();
    _first = null;
    _inner.dispose();
  }
}

class _Frame implements ui.FrameInfo {
  _Frame(this.duration, this.image);

  @override
  final Duration duration;

  @override
  final ui.Image image;
}
