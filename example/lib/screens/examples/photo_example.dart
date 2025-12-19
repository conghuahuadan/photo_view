import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photo_view_example/screens/examples/gallery/gallery_example.dart';

class PhotoExample extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return PhotoExampleState();
  }
}

class PhotoExampleState extends State<PhotoExample> {
  List<Pic> images = [
    Pic(
        cover:
            "https://flash-scdn.jin10.com/flash_dli/jin_fanti/img/e3ba67a6-5f5d-ba78-3be8-1718784640728.jpg",
        url:
            "https://flash-scdn.jin10.com/flash_dli/jin_fanti/img/e3ba67a6-5f5d-ba78-3be8-1718784640728.jpg"),
    Pic(
        cover:
            "https://flash-scdn.jin10.com/8a22a6c8-f9f9-49c4-93bc-fa2d7c3a5747.png",
        url:
            "https://flash-scdn.jin10.com/8a22a6c8-f9f9-49c4-93bc-fa2d7c3a5747.png"),
    Pic(
        cover:
            "https://gd-hbimg.huaban.com/5af8c69096f047d7aa2c7366086e8a866c7f436d15248-fJQCru_fw1200",
        url:
            "https://gd-hbimg.huaban.com/5af8c69096f047d7aa2c7366086e8a866c7f436d15248-fJQCru_fw1200"),
    Pic(
        cover: "http://www.missyuan.net/uploads/allimg/190221/1121313Z5-0.gif",
        url: "http://www.missyuan.net/uploads/allimg/190221/1121313Z5-0.gif"),
    Pic(
        cover:
            "https://cdn-files.jin10.com/jtk/202312/e2bcd685-5008-4223-b45e-e25053ab078f.jpg/lite",
        url:
            "https://cdn-files.jin10.com/jtk/202312/e2bcd685-5008-4223-b45e-e25053ab078f.jpg/lite"),
    Pic(
        cover:
            "https://flash-scdn.jin10.com/975427b4-37c2-415a-b029-1fe2d7f86bdc.png",
        url:
            "https://flash-scdn.jin10.com/975427b4-37c2-415a-b029-1fe2d7f86bdc.png"),
    Pic(
        cover:
            "https://images.pexels.com/photos/2049422/pexels-photo-2049422.jpeg",
        url:
            "https://images.pexels.com/photos/2049422/pexels-photo-2049422.jpeg"),
    Pic(
        cover: "https://img.jin10.com/event/25/09/NLnK5Ic_K_fnDX6kSfVmZ.webp",
        url: "https://img.jin10.com/event/25/09/NLnK5Ic_K_fnDX6kSfVmZ.webp"),
    Pic(
        cover:
            "http://p8.itc.cn/q_70/images03/20201017/7b03acea8eaa4371a084c5bbc3bbee44.gif",
        url:
            "http://p8.itc.cn/q_70/images03/20201017/7b03acea8eaa4371a084c5bbc3bbee44.gif"),
  ];

  Future<void> clearAllImageCache() async {
    // 1. 删磁盘
    await DefaultCacheManager().emptyCache();

    // 2. 删内存
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () async {
            await clearAllImageCache();
            Navigator.pop(context);
          },
          child: const Text("Photo Example"),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.white,
        child: MasonryGridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          itemCount: images.length,
          itemBuilder: (context, index) {
            return AspectRatio(
              aspectRatio: 1,
              child: GestureDetector(
                onTap: () {
                  _onTap(index);
                },
                behavior: HitTestBehavior.opaque,
                child: Hero(
                    tag: images[index].cover,
                    child: CachedNetworkImage(
                      imageUrl: images[index].cover,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    )),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onTap(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewGallery.builder(
          scrollPhysics: const BouncingScrollPhysics(),
          builder: (context, index) {
            return PhotoViewGalleryPageOptions(
              imageProvider: CachedNetworkImageProvider(images[index].url),
              heroAttributes: PhotoViewHeroAttributes(tag: images[index].url),
            );
          },
          itemCount: images.length,
          pageController: PageController(initialPage: index),
        ),
      ),
    );
  }
}

class Pic {
  final String cover;
  final String url;
  Pic({this.cover = "", this.url = ""});
}
