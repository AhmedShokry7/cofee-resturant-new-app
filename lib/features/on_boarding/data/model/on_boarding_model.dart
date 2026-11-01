/// One slide of the first-launch intro: art, headline and explanation.
///
/// The slides are written in [S] like every other label, so nothing here is
/// read from the backend.
class OnBoardingModel {
  const OnBoardingModel({
    required this.image,
    required this.title,
    required this.body,
  });

  final String image;
  final String title;
  final String body;
}
