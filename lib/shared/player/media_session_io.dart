// Native builds: the players' engines own the system media controls.
void update({
  required String title,
  String subtitle = '',
  String artworkUrl = '',
  void Function()? onPlay,
  void Function()? onPause,
  void Function(int seconds)? onSeekBy,
  void Function()? onNext,
  void Function()? onPrevious,
}) {}

void setPlaying(bool playing) {}

void clear() {}
