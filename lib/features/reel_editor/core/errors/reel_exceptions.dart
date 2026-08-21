/// Typed domain errors md:850-871
abstract class ReelException implements Exception {
  final String code;
  final String message;
  final Object? cause;
  const ReelException(this.code, this.message, [this.cause]);
  @override
  String toString() => '$runtimeType($code): $message';
}

class MediaImportException extends ReelException {
  const MediaImportException(super.code, super.message, [super.cause]);
}

class MediaDecodeException extends ReelException {
  const MediaDecodeException(super.code, super.message, [super.cause]);
}

class TimelineException extends ReelException {
  const TimelineException(super.code, super.message, [super.cause]);
}

class ExportException extends ReelException {
  const ExportException(super.code, super.message, [super.cause]);
}

class StorageException extends ReelException {
  const StorageException(super.code, super.message, [super.cause]);
}

class ProjectException extends ReelException {
  const ProjectException(super.code, super.message, [super.cause]);
}

class PermissionException extends ReelException {
  const PermissionException(super.code, super.message, [super.cause]);
}
