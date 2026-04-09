import 'package:flutter/material.dart';
import '../../core/controllers/latest_controller.dart';
import '../widgets/latest_carousel.dart';
import '../widgets/latest_grid.dart';
import '../widgets/shimmer_view.dart';

class LatestPage extends StatefulWidget {
  final String title;
  final String endpointUrl;
  final String sectionTitle;
  final String actionLabel;
  final bool showActionButton;

  const LatestPage({
    super.key,
    required this.title,
    required this.endpointUrl,
    required this.sectionTitle,
    this.actionLabel = 'Show Galleries',
    this.showActionButton = true,
  });

  @override
  State<LatestPage> createState() => _LatestPageState();
}

class _LatestPageState extends State<LatestPage> {
  final LatestController _controller = LatestController();

  @override
  void initState() {
    super.initState();
    _controller.initialize(widget.endpointUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return Scaffold(body: ShimmerView(title: widget.title));
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(
                  widget.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                floating: true,
                snap: true,
              ),
              
              if (_controller.items.isNotEmpty)
                SliverToBoxAdapter(
                  child: LatestCarousel(
                    items: _controller.items,
                    onTap: (index) => _controller.fetchCelebrityName(context, index),
                  ),
                ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    widget.sectionTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              LatestGrid(
                items: _controller.items,
                loadingProfileLinks: _controller.loadingProfileLinks,
                favoriteUrls: _controller.favoriteUrls,
                onTap: (index) => _controller.fetchCelebrityName(context, index),
                onActionPressed: (index) => _controller.fetchAndNavigateToProfile(context, index),
                onFavoriteTap: (index) => _controller.toggleFavorite(context, index),
                actionLabel: widget.actionLabel,
                showActionButton: widget.showActionButton,
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        );
      }
    );
  }
}
