

import 'dart:async';
import 'dart:math';

class SensorService {
  // Simule le flux de données du brassard (BPM)
  Stream<int> get heartRateStream async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 1));
      yield 60 + Random().nextInt(40); // Génère entre 60 et 100 BPM
    }
  }
}