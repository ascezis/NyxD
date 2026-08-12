sealed class VaultException implements Exception {
  const VaultException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class VaultAlreadyExistsException extends VaultException {
  const VaultAlreadyExistsException()
    : super('A NyxD vault already exists on this device.');
}

final class VaultNotFoundException extends VaultException {
  const VaultNotFoundException()
    : super('No NyxD vault exists on this device.');
}

final class WrongPasswordException extends VaultException {
  const WrongPasswordException() : super('Wrong master password.');
}

final class VaultStateException extends VaultException {
  const VaultStateException(super.message);
}
