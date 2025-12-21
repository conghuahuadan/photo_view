import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photo_view_example/screens/examples/photo_example.dart';

class ImageViewerExample extends StatefulWidget {
  final List<Pic> images;
  final int index;
  final String hero;

  ImageViewerExample({
    required this.images,
    required this.index,
    required this.hero,
  });

  @override
  State<ImageViewerExample> createState() => _ImageViewerExampleState();
}

class _ImageViewerExampleState extends State<ImageViewerExample> {
  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: PhotoViewGallery.builder(
        builder: (context, index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(widget.images[index].url),
            heroAttributes: PhotoViewHeroAttributes(tag: widget.hero),
            onTapUp: (context, details, value) {
              Navigator.pop(context);
            },
            enablePanAlways: true,
            onCloseCallback: () {
              Navigator.pop(context);
            },
          );
        },
        itemCount: widget.images.length,
        pageController: PageController(initialPage: widget.index),
      ),
    );
  }
}
