import 'package:flutter_riverpod/flutter_riverpod.dart';

class BarberNavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) => state = index;
}

final barberNavigationProvider =
    NotifierProvider<BarberNavigationNotifier, int>(
  BarberNavigationNotifier.new,
);
