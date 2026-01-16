import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parla/utils/formatter/file_formatter.dart';
import 'package:uuid/uuid.dart';

class UploadStatus {
  final String id;
  final String fileName;
  final double progress;
  final String? downloadUrl;
  final bool isCompleted;
  final String? error;

  UploadStatus({
    required this.id,
    required this.fileName,
    this.progress = 0.0,
    this.downloadUrl,
    this.isCompleted = false,
    this.error,
  });

  UploadStatus copyWith({
    double? progress,
    String? downloadUrl,
    bool? isCompleted,
    String? error,
  }) {
    return UploadStatus(
      id: id,
      fileName: fileName,
      progress: progress ?? this.progress,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error ?? this.error,
    );
  }
}

final fileUploadProvider =
    StateNotifierProvider<FileUploadNotifier, Map<String, UploadStatus>>((ref) {
      return FileUploadNotifier();
    });

class FileUploadNotifier extends StateNotifier<Map<String, UploadStatus>> {
  FileUploadNotifier() : super({});

  final _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  /// Uploads multiple files (File or XFile) asynchronously
  Future<void> uploadMultiple({
    required List<dynamic> files, // Supports File or XFile
    required String path,
    List<String?>? customFileNames,
    Function(List<Map<String, dynamic>> urls)? onAllUploadsComplete,
  }) async {
    List<Future<Map<String, dynamic>?>> uploadTasks = [];

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final customFileName = customFileNames?[i];
      final id = _uuid.v4();
      uploadTasks.add(_startUpload(id, file, path, customFileName));
    }

    // Wait for all to finish and trigger the session callback
    final results = await Future.wait(uploadTasks);
    final successfulUrls = results.whereType<Map<String, dynamic>>().toList();

    if (onAllUploadsComplete != null) {
      onAllUploadsComplete(successfulUrls);
    }
  }

  Future<Map<String, dynamic>?> _startUpload(
    String id,
    dynamic file,
    String path,
    String? customFileName,
  ) async {
    try {
      File uploadFile;
      String fileName;

      // Handle XFile vs File conversion
      if (file is XFile) {
        uploadFile = File(file.path);
      } else if (file is File) {
        uploadFile = file;
      } else {
        throw Exception("Unsupported file type");
      }

      // Generate filename if not provided
      if (customFileName != null) {
        fileName = customFileName;
      } else {
        final mimeType = FileFormatter.mimeTypeFromFilePath(uploadFile.path);
        final extension = mimeType.split('/').last;
        fileName = '${_uuid.v4()}.$extension';
      }

      // Initialize state for this file
      state = {...state, id: UploadStatus(id: id, fileName: fileName)};

      final ref = _storage.ref().child(path).child(fileName);

      // Use putFile for the fastest upload method on mobile
      final uploadTask = ref.putFile(
        uploadFile,
        SettableMetadata(
          contentType: FileFormatter.mimeTypeFromFilePath(uploadFile.path),
        ),
      );

      // Listen to progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        state = {...state, id: state[id]!.copyWith(progress: progress)};
      });

      // Await completion
      final snapshot = await uploadTask;

      final downloadUrl = await snapshot.ref.getDownloadURL();
      final metadata = await snapshot.ref.getMetadata();

      // Update final state
      state = {
        ...state,
        id: state[id]!.copyWith(
          progress: 1.0,
          downloadUrl: downloadUrl,
          isCompleted: true,
        ),
      };

      return {
        "downloadUrl": downloadUrl,
        "name": metadata.name,
        "size": metadata.size ?? 0,
      };
    } catch (e) {
      state = {
        ...state,
        id:
            state[id]?.copyWith(error: e.toString()) ??
            UploadStatus(id: id, fileName: "Error", error: e.toString()),
      };
      return null;
    }
  }
}
