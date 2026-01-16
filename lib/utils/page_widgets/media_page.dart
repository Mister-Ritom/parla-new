import 'dart:io';

import 'package:flutter/material.dart';
import 'package:parla/models/message_model.dart';
import 'package:parla/utils/page_widgets/video_page.dart';
import 'package:parla/utils/enums/source_type.dart';

class MediaPage extends StatelessWidget {
  final List<FileAttachment> files;
  MediaPage({super.key, required this.files});
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: files.length,
        itemBuilder: (context, index) {
          final MediaSourceType? sourceType = files[index].path != null
              ? MediaSourceType.file
              : files[index].url != null
              ? MediaSourceType.network
              : null;
          if (sourceType == null) {
            throw Exception('Invalid media source, Both path and url are null');
          }
          final String path = files[index].path ?? files[index].url!;
          final isVideo = files[index].mimeType.startsWith('video/');
          final String title =
              "${isVideo ? "Video" : "Image"} ${index + 1}/${files.length}";
          final Widget mediaWidget = isVideo
              ? _buildVideo(path, sourceType, title)
              : _buildImage(path, sourceType, title, context);
          return mediaWidget;
        },
      ),
    );
  }

  VideoPage _buildVideo(String path, MediaSourceType sourceType, String title) {
    return VideoPage(
      dataSource: path,
      sourceType: sourceType,
      videoTitle: title,
    );
  }

  Widget _buildImage(
    String path,
    MediaSourceType sourceType,
    String title,
    BuildContext context,
  ) {
    return Stack(
      children: [
        InteractiveViewer(
          child: Center(child: _buildImageWidget(path, sourceType)),
        ),
        AppBar(
          backgroundColor: Colors.black26,
          elevation: 0,
          title: Text(title, style: const TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      ],
    );
  }

  Image _buildImageWidget(String path, MediaSourceType sourceType) {
    switch (sourceType) {
      case MediaSourceType.file:
        return Image.file(File(path), fit: BoxFit.contain);
      case MediaSourceType.network:
        return Image.network(path, fit: BoxFit.contain);
      case MediaSourceType.asset:
        return Image.asset(path, fit: BoxFit.contain);
    }
  }
}
