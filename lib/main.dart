import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/storage.dart';
import 'state/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Zen Maru Gothic',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  final store = AppStore(PrefsStorage());
  await store.load();
  runApp(KajiApp(store: store));
}
