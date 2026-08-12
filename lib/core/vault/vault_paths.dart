import 'dart:io';

final class VaultPaths {
  const VaultPaths(this.directory);

  final Directory directory;

  File get database => File('${directory.path}/nyxd.db');
  File get metadata => File('${directory.path}/nyxd.meta.json');
}
