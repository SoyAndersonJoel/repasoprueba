import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'dart:convert';
import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/reply_widget.dart';
import '../../widgets/image_widget.dart';

class SpotDetailPage extends StatefulWidget {
  final TouristSpot spot;

  const SpotDetailPage({super.key, required this.spot});

  @override
  State<SpotDetailPage> createState() => _SpotDetailPageState();
}

class _SpotDetailPageState extends State<SpotDetailPage> {
  final PageController _pageController = PageController();
  final TextEditingController _reviewController = TextEditingController();
  List<Review> _reviews = [];
  bool _isLoadingReviews = false;
  bool _isSubmittingReview = false;
  double _rating = 5.0;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _checkFavoriteStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  // Función auxiliar para obtener el ImageProvider correcto según el tipo de imagen
  ImageProvider _getImageProvider(String imageUrl) {
    if (imageUrl.startsWith('data:image/')) {
      // Es una imagen Base64
      try {
        final base64Data = imageUrl.split(',')[1];
        final bytes = base64Decode(base64Data);
        return MemoryImage(bytes);
      } catch (e) {
        print('Error decoding Base64 image: $e');
        return const AssetImage('assets/images/placeholder.png'); // Fallback
      }
    } else {
      // Es una URL normal
      return NetworkImage(imageUrl);
    }
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoadingReviews = true;
    });

    try {
      print('Iniciando carga de reseñas para sitio: ${widget.spot.id}');
      final reviews = await FirebaseService.getReviewsForSpot(widget.spot.id);
      print('Reseñas cargadas exitosamente: ${reviews.length}');
      setState(() {
        _reviews = reviews;
      });
    } catch (e) {
      print('Error en _loadReviews: $e');
      String errorMessage = 'Error al cargar reseñas';
      
      if (e.toString().contains('index')) {
        errorMessage = 'Error de configuración de base de datos (índice faltante)';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Error de permisos de base de datos';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Error de conexión a internet';
      } else {
        errorMessage = 'Error al cargar reseñas: ${e.toString()}';
      }
      
      _showSnackBar(errorMessage, Colors.red);
    } finally {
      setState(() {
        _isLoadingReviews = false;
      });
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (provider.currentUser != null) {
      final isFav = await provider.isFavorite(widget.spot.id);
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.toggleFavorite(widget.spot.id);
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  Future<void> _submitReview() async {
    if (_reviewController.text.trim().isEmpty) {
      _showSnackBar('Por favor escribe una reseña', Colors.orange);
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    if (provider.currentUser == null) {
      _showSnackBar('Debes iniciar sesión para escribir una reseña', Colors.red);
      return;
    }

    setState(() {
      _isSubmittingReview = true;
    });

    try {
      final review = Review(
        id: '',
        touristSpotId: widget.spot.id,
        authorId: provider.currentUser!.id,
        authorName: provider.currentUser!.displayName,
        content: _reviewController.text.trim(),
        rating: _rating,
        createdAt: DateTime.now(),
        imageUrls: [],
      );

      await FirebaseService.createReview(review);
      _reviewController.clear();
      _rating = 5.0;
      await _loadReviews();
      _showSnackBar('¡Reseña publicada exitosamente!', Colors.green);
    } catch (e) {
      _showSnackBar('Error al publicar reseña: $e', Colors.red);
    } finally {
      setState(() {
        _isSubmittingReview = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showImageGallery(int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, _) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  PhotoViewGallery.builder(
                    itemCount: widget.spot.imageUrls.length,
                    builder: (context, index) {
                      return PhotoViewGalleryPageOptions(
                        imageProvider: _getImageProvider(widget.spot.imageUrls[index]),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 2,
                      );
                    },
                    scrollPhysics: const BouncingScrollPhysics(),
                    backgroundDecoration: const BoxDecoration(color: Colors.black),
                    pageController: PageController(initialPage: initialIndex),
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageCarousel() {
    if (widget.spot.imageUrls.isEmpty) {
      return Container(
        height: 250,
        color: Colors.grey.shade200,
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: 80,
            color: Colors.grey.shade400,
          ),
        ),
      );
    }

    return Container(
      height: 250,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.spot.imageUrls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _showImageGallery(index),
            child: AppImageWidget(
              imageUrl: widget.spot.imageUrls[index],
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }

  Widget _buildRatingStars(double rating, {bool interactive = false, Function(double)? onRatingChanged}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: interactive && onRatingChanged != null
              ? () => onRatingChanged((index + 1).toDouble())
              : null,
          child: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: interactive ? 32 : 16,
          ),
        );
      }),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.shade600,
                  child: Text(
                    review.authorName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.authorName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          _buildRatingStars(review.rating),
                          const SizedBox(width: 8),
                          Text(
                            '${review.rating.toStringAsFixed(1)}/5.0',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              review.content,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            
            // Widget de respuestas
            ReplyWidget(
              reviewId: review.id,
              initialReplies: const [],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection() {
    final provider = Provider.of<AppProvider>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Reseñas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Add Review Section
        if (provider.currentUser != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Escribe una reseña',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Calificación: '),
                        _buildRatingStars(
                          _rating,
                          interactive: true,
                          onRatingChanged: (rating) {
                            setState(() {
                              _rating = rating;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Text('($_rating/5.0)'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reviewController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Comparte tu experiencia en este sitio...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmittingReview ? null : _submitReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                        ),
                        child: _isSubmittingReview
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Publicar Reseña'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Reviews List
        if (_isLoadingReviews)
          const Center(child: CircularProgressIndicator())
        else if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.comment_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No hay reseñas aún',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sé el primero en compartir tu experiencia',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _reviews.map((review) => _buildReviewCard(review)).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildImageCarousel(),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : Colors.white,
                  ),
                  onPressed: _toggleFavorite,
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Spot Info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.spot.title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Coordenadas
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.orange.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Coordenadas: ${widget.spot.latitude.toStringAsFixed(6)}, ${widget.spot.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.spot.location,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Fecha de publicación
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.blue.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Publicado: ${widget.spot.createdAt.day}/${widget.spot.createdAt.month}/${widget.spot.createdAt.year} a las ${widget.spot.createdAt.hour.toString().padLeft(2, '0')}:${widget.spot.createdAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.spot.description,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.orange.shade600,
                              child: Text(
                                widget.spot.authorName[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Publicado por',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  widget.spot.authorName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.favorite, size: 16, color: Colors.red.shade400),
                                    const SizedBox(width: 4),
                                    Text('${widget.spot.likesCount}'),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.comment, size: 16, color: Colors.blue.shade400),
                                    const SizedBox(width: 4),
                                    Text('${widget.spot.reviewsCount}'),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Reviews Section
                _buildReviewSection(),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
