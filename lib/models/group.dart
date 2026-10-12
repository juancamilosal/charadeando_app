/// Un equipo de jugadores que participa en la partida.
class Group {
  const Group(this.name, {this.teamId});

  final String name;

  /// Id del equipo guardado en "Equipos", o null si es un equipo solo de
  /// esta partida (por ejemplo, de la configuración aleatoria).
  final String? teamId;
}
