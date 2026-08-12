final class EntryNotFoundException implements Exception {
  const EntryNotFoundException(this.id);

  final int id;

  @override
  String toString() => 'Entry $id was not found.';
}
