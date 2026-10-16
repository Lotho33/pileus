import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void exitApp() {
  if (globalContext.has('pileusExitApp')) {
    globalContext.callMethod('pileusExitApp'.toJS);
  }
}
