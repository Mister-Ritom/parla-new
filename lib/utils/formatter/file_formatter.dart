import 'dart:math';

import 'package:heroicons/heroicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parla/models/message_model.dart';

class FileFormatter {
  static String fileTypeName(String mime) {
    mime = mime.toLowerCase();

    if (mime.startsWith("image/")) return "Image";
    if (mime.startsWith("video/")) return "Video";
    if (mime.startsWith("audio/")) return "Audio";

    if (mime == "application/pdf") return "PDF";

    if (mime.contains("word") || mime.contains("msword")) {
      return "Word Document";
    }
    if (mime.contains("excel")) return "Excel Sheet";
    if (mime.contains("presentation") || mime.contains("ppt")) {
      return "PowerPoint";
    }

    if (mime.contains("zip") ||
        mime.contains("rar") ||
        mime.contains("7z") ||
        mime.contains("tar")) {
      return "Archive";
    }

    if (mime.startsWith("text/") || mime.contains("json")) return "Text File";

    return "Document";
  }

  static String mimeTypeFromFilePath(String filePath) {
    final ext = filePath.toLowerCase().split('.').last;

    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';

      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'mkv':
        return 'video/x-matroska';
      case 'avi':
        return 'video/x-msvideo';
      case 'webm':
        return 'video/webm';

      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';

      case 'pdf':
        return 'application/pdf';

      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';

      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/vnd.rar';
      case '7z':
        return 'application/x-7z-compressed';
      case 'tar':
        return 'application/x-tar';

      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      case 'csv':
        return 'text/csv';
      case 'xml':
        return 'application/xml';
      case 'html':
      case 'htm':
        return 'text/html';

      default:
        return 'application/octet-stream';
    }
  }

  static HeroIcons heroIconForMime(String mime) {
    mime = mime.toLowerCase();

    if (mime.startsWith("image/")) {
      return HeroIcons.photo;
    }

    if (mime.startsWith("video/")) {
      return HeroIcons.videoCamera;
    }

    if (mime.startsWith("audio/")) {
      return HeroIcons.musicalNote;
    }

    if (mime == "application/pdf") {
      return HeroIcons.documentText;
    }

    if (mime.contains("word") || mime.contains("msword")) {
      return HeroIcons.document;
    }

    if (mime.contains("excel")) {
      return HeroIcons.tableCells;
    }

    if (mime.contains("presentation") || mime.contains("ppt")) {
      return HeroIcons.presentationChartBar;
    }

    if (mime.contains("zip") ||
        mime.contains("rar") ||
        mime.contains("7z") ||
        mime.contains("tar")) {
      return HeroIcons.archiveBox;
    }

    if (mime.startsWith("text/") || mime.contains("json")) {
      return HeroIcons.documentText;
    }

    return HeroIcons.document;
  }

  static String formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];

    int i = (log(bytes) / log(1024)).floor();
    double size = bytes / pow(1024, i);

    return "${size.toStringAsFixed(decimals)} ${suffixes[i]}";
  }

  // Without length to avoid async in formatter
  static FileAttachment attachmentFromXFile(XFile file) {
    return FileAttachment(
      path: file.path,
      name: file.name,
      size: 0,
      mimeType: file.mimeType ?? mimeTypeFromFilePath(file.path),
    );
  }
}
