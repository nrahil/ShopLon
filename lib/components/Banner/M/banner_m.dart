import 'package:flutter/material.dart';

import '../../network_image_with_loader.dart';

class BannerM extends StatelessWidget {
  const BannerM(
      {super.key,
      required this.image,
      required this.press,
      required this.children});

  final String image;
  final VoidCallback press;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => AspectRatio(
        // Wider and shorter on large screens so the banner doesn't fill the view.
        aspectRatio: constraints.maxWidth >= 700 ? 3.2 : 1.87,
        child: GestureDetector(
          onTap: press,
          child: Stack(
            children: [
              NetworkImageWithLoader(image, radius: 0),
              Container(color: Colors.black45),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
