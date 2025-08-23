part of 'search_view.dart';

class _SearchContent extends StatelessWidget {
  const _SearchContent(this.viewModel);

  final SearchViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Search'), surfaceTintColor: Colors.transparent),
    body: const Center(child: Column(children: [Text('Search')])),
  );
}
