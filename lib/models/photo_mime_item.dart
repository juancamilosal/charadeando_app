/// Un objeto de Fotomímica en Directus (colección `fotomimica`): su nombre
/// y el id de su foto en los archivos de Directus.
class PhotoMimeItem {
  const PhotoMimeItem({
    required this.id,
    required this.nombre,
    required this.imageId,
    required this.baseUrl,
    this.premium = false,
  });

  /// Lee un objeto de la respuesta de `/juego/fotomimica`
  /// (`{ id, nombre, imagen, premium }`). [baseUrl] es el servidor del que
  /// se descarga la foto.
  factory PhotoMimeItem.fromJson(
    Map<String, dynamic> json, {
    required String baseUrl,
  }) => PhotoMimeItem(
    id: '${json['id'] ?? ''}',
    nombre: '${json['nombre'] ?? ''}'.trim(),
    imageId: '${json['imagen'] ?? ''}',
    premium: json['premium'] == true,
    baseUrl: baseUrl,
  );

  final String id;
  final String nombre;

  /// Id del archivo de la foto en Directus.
  final String imageId;

  /// Solo sale con Todo Charadeando.
  final bool premium;
  final String baseUrl;

  /// La foto, achicada por Directus a 720 px de ancho, en WebP: pesa poco
  /// y se ve bien a pantalla completa.
  String get imageUrl =>
      '$baseUrl/assets/$imageId?width=720&quality=80&format=webp';

  bool get valid => id.isNotEmpty && nombre.isNotEmpty && imageId.isNotEmpty;

  @override
  String toString() => 'PhotoMimeItem($id, $nombre)';
}
