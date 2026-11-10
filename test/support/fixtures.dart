import 'dart:io';

String fixturePath(String relative) => 'test/fixtures/data-source/$relative';

Directory fixtureDir(String relative) => Directory(fixturePath(relative));
