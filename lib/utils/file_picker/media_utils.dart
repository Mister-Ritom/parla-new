import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parla/utils/logger/app_logger.dart';
// mime is useful for checking file types if extensions are missing,
// but for this utility, we will rely on extensions/XFile properties to keep it simple.

class MediaUtils {
  MediaUtils._();

  static final ImagePicker _picker = ImagePicker();

  // ==========================================
  // TYPE GROUPS (For File Selector)
  // ==========================================

  static const XTypeGroup _imageTypeGroup = XTypeGroup(
    label: 'Images',
    extensions: <String>['jpg', 'jpeg', 'png', 'heic', 'webp', 'gif'],
    uniformTypeIdentifiers: <String>['public.image'],
  );

  static const XTypeGroup _videoTypeGroup = XTypeGroup(
    label: 'Videos',
    extensions: <String>['mp4', 'mov', 'avi', 'mkv', 'webm'],
    uniformTypeIdentifiers: <String>['public.movie'],
  );

  static const XTypeGroup _documentTypeGroup = XTypeGroup(
    label: 'Documents',
    extensions: <String>[
      'pdf',
      'doc',
      'docx',
      'xls',
      'xlsx',
      'txt',
      'csv',
      'ppt',
      'pptx',
      "zip",
      "rar",
      "7z",
      "tar",
    ],
    uniformTypeIdentifiers: <String>[
      'public.data',
      'public.text',
      'public.composite-content',
      'com.adobe.pdf',
      'org.openxmlformats.wordprocessingml.document',
      'com.microsoft.word.doc',
      'org.openxmlformats.spreadsheetml.sheet',
      'com.microsoft.excel.xls',
      'org.openxmlformats.presentationml.presentation',
      'com.microsoft.powerpoint.ppt',
      'public.zip-archive',
      'public.archive',
    ],
  );

  // ==========================================
  // 1. IMAGES (Single & Multi)
  // ==========================================

  /// SINGLE: Camera
  static Future<XFile?> pickImageFromCamera() async {
    return _safePick(() => _picker.pickImage(source: ImageSource.camera));
  }

  /// SINGLE: Gallery
  static Future<XFile?> pickImageFromGallery() async {
    return _safePick(() => _picker.pickImage(source: ImageSource.gallery));
  }

  /// SINGLE: Files
  static Future<XFile?> pickImageFromFileSystem() async {
    return _safePick(() => openFile(acceptedTypeGroups: [_imageTypeGroup]));
  }

  /// MULTI: Gallery
  static Future<List<XFile>> pickMultiImagesFromGallery({int? limit}) async {
    return _safePickMulti(() => _picker.pickMultiImage(limit: limit));
  }

  /// MULTI: Files
  static Future<List<XFile>> pickMultiImagesFromFileSystem() async {
    return _safePickMulti(
      () => openFiles(acceptedTypeGroups: [_imageTypeGroup]),
    );
  }

  // ==========================================
  // 2. VIDEOS (Single & Multi)
  // ==========================================

  /// SINGLE: Camera
  static Future<XFile?> pickVideoFromCamera() async {
    return _safePick(() => _picker.pickVideo(source: ImageSource.camera));
  }

  /// SINGLE: Gallery
  static Future<XFile?> pickVideoFromGallery() async {
    return _safePick(() => _picker.pickVideo(source: ImageSource.gallery));
  }

  /// SINGLE: Files
  static Future<XFile?> pickVideoFromFileSystem() async {
    return _safePick(() => openFile(acceptedTypeGroups: [_videoTypeGroup]));
  }

  /// MULTI: Gallery
  /// Note: image_picker does not have `pickMultiVideo`.
  /// We use `pickMultipleMedia` and filter out non-video files.
  static Future<List<XFile>> pickMultiVideosFromGallery({int? limit}) async {
    try {
      final List<XFile> media = await _picker.pickMultipleMedia(limit: limit);

      // Filter logic: Check extension or MIME type.
      // This is a basic filter based on common video extensions.
      final videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm'];

      return media.where((file) {
        final ext = file.path.split('.').last.toLowerCase();
        return videoExtensions.contains(ext);
      }).toList();
    } catch (e, st) {
      AppLogger.error(
        name: "MediaUtils",
        message: 'Error picking multi videos from gallery',
        exception: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// MULTI: Files
  static Future<List<XFile>> pickMultiVideosFromFileSystem() async {
    return _safePickMulti(
      () => openFiles(acceptedTypeGroups: [_videoTypeGroup]),
    );
  }

  // ==========================================
  // 3. DOCUMENTS (Single & Multi)
  // ==========================================

  /// SINGLE: Files
  static Future<XFile?> pickDocument() async {
    return _safePick(() => openFile(acceptedTypeGroups: [_documentTypeGroup]));
  }

  /// MULTI: Files
  static Future<List<XFile>> pickMultiDocuments() async {
    return _safePickMulti(
      () => openFiles(acceptedTypeGroups: [_documentTypeGroup]),
    );
  }

  // ==========================================
  // 4. MEDIA (IMAGE and VIDEO)
  static Future<XFile?> pickSingleMediaFromGallery() async {
    return _safePick(() => _picker.pickMedia());
  }

  static Future<List<XFile>> pickMultiMediaFromGallery({int? limit}) async {
    return _safePickMulti(() => _picker.pickMultipleMedia(limit: limit));
  }

  static Future<XFile?> pickSingleMediaFromCamera() async {
    return _safePick(() => _picker.pickMedia());
  }

  static Future<List<XFile>> pickMultiMediaFromCamera({int? limit}) async {
    return _safePickMulti(() => _picker.pickMultipleMedia(limit: limit));
  }

  static Future<XFile?> pickSingleMediaFromFileSystem() async {
    return _safePick(
      () => openFile(
        acceptedTypeGroups: [
          _imageTypeGroup,
          _videoTypeGroup,
          _documentTypeGroup,
        ],
      ),
    );
  }

  static Future<List<XFile>> pickMultiMediaFromFileSystem() async {
    return _safePickMulti(
      () => openFiles(
        acceptedTypeGroups: [
          _imageTypeGroup,
          _videoTypeGroup,
          _documentTypeGroup,
        ],
      ),
    );
  }

  // ==========================================
  // INTERNAL HELPERS (Error Handling)
  // ==========================================

  static Future<XFile?> _safePick(Future<XFile?> Function() picker) async {
    try {
      return await picker();
    } catch (e, st) {
      AppLogger.error(
        name: "MediaUtils",
        message: 'MediaUtils Single Pick Error',
        exception: e,
        stackTrace: st,
      );
      return null;
    }
  }

  static Future<List<XFile>> _safePickMulti(
    Future<List<XFile>> Function() picker,
  ) async {
    try {
      return await picker();
    } catch (e, st) {
      AppLogger.error(
        name: "MediaUtils",
        message: 'MediaUtils Multi Pick Error',
        exception: e,
        stackTrace: st,
      );
      return [];
    }
  }
}
