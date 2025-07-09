import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/firebase_service.dart';
import '../../providers/app_provider.dart';
import 'package:provider/provider.dart';

class ReplyWidget extends StatefulWidget {
  final String reviewId;
  final List<Reply> initialReplies;

  const ReplyWidget({
    super.key,
    required this.reviewId,
    required this.initialReplies,
  });

  @override
  State<ReplyWidget> createState() => _ReplyWidgetState();
}

class _ReplyWidgetState extends State<ReplyWidget> {
  final TextEditingController _replyController = TextEditingController();
  List<Reply> _replies = [];
  bool _showReplyField = false;
  bool _isSubmitting = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _replies = widget.initialReplies;
    _loadReplies();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadReplies() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Iniciando carga de respuestas para reseña: ${widget.reviewId}');
      final replies = await FirebaseService.getRepliesForReview(widget.reviewId);
      print('Respuestas cargadas exitosamente: ${replies.length}');
      setState(() {
        _replies = replies;
      });
    } catch (e) {
      print('Error en _loadReplies: $e');
      String errorMessage = 'Error al cargar respuestas';
      
      if (e.toString().contains('index')) {
        errorMessage = 'Error de configuración de base de datos (índice faltante)';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Error de permisos de base de datos';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Error de conexión a internet';
      } else {
        errorMessage = 'Error al cargar respuestas: ${e.toString()}';
      }
      
      _showSnackBar(errorMessage, Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitReply() async {
    if (_replyController.text.trim().isEmpty) {
      _showSnackBar('Por favor escribe una respuesta', Colors.orange);
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    if (provider.currentUser == null) {
      _showSnackBar('Debes iniciar sesión para responder', Colors.red);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final reply = Reply(
        id: '',
        reviewId: widget.reviewId,
        authorId: provider.currentUser!.id,
        authorName: provider.currentUser!.displayName,
        content: _replyController.text.trim(),
        createdAt: DateTime.now(),
      );

      await FirebaseService.createReply(reply);
      _replyController.clear();
      setState(() {
        _showReplyField = false;
      });
      await _loadReplies();
      _showSnackBar('Respuesta publicada exitosamente', Colors.green);
    } catch (e) {
      _showSnackBar('Error al publicar respuesta: $e', Colors.red);
    } finally {
      setState(() {
        _isSubmitting = false;
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

  Widget _buildReplyItem(Reply reply) {
    return Container(
      margin: const EdgeInsets.only(left: 20, top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.blue.shade600,
                child: Text(
                  reply.authorName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                reply.authorName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '${reply.createdAt.day}/${reply.createdAt.month}/${reply.createdAt.year}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reply.content,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Respuestas existentes
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_replies.isNotEmpty) ...[
          ..._replies.map((reply) => _buildReplyItem(reply)).toList(),
        ],

        // Botón para mostrar campo de respuesta
        if (!_showReplyField && provider.currentUser != null)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 8),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showReplyField = true;
                });
              },
              icon: const Icon(Icons.reply, size: 16),
              label: const Text(
                'Responder',
                style: TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),

        // Campo de respuesta
        if (_showReplyField)
          Container(
            margin: const EdgeInsets.only(left: 20, top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _replyController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Escribe una respuesta...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(8),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showReplyField = false;
                          _replyController.clear();
                        });
                      },
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Responder',
                              style: TextStyle(fontSize: 12),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
