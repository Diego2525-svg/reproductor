import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

void main() => runApp(const AppDeDiego());

class AppDeDiego extends StatelessWidget {
  const AppDeDiego({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0D0D12)),
      home: const MusicMasterScreen(),
    );
  }
}

class MusicMasterScreen extends StatefulWidget {
  const MusicMasterScreen({super.key});
  @override
  State<MusicMasterScreen> createState() => _MusicMasterScreenState();
}

class _MusicMasterScreenState extends State<MusicMasterScreen> {
  final AudioPlayer _player = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery(); // El buscador de canciones
  final Color neonBlue = const Color(0xFF00E5FF);
  bool isShuffle = false;

  List<SongModel> allSongsInDevice = []; // Aquí se guardarán las canciones reales

  @override
  void initState() {
    super.initState();
    requestStoragePermission();
  }

  // PASO 1: Pedir permiso para leer archivos
  void requestStoragePermission() async {
    PermissionStatus status = await Permission.storage.request();
    if (status.isPermanentlyDenied) openAppSettings();
    setState(() {});
  }

  // PASO 2: Configurar la cola de reproducción con canciones reales
  void _playSong(List<SongModel> songs, int index) async {
    try {
      final playlist = ConcatenatingAudioSource(
        children: songs.map((s) => AudioSource.uri(Uri.parse(s.uri!))).toList(),
      );
      await _player.setAudioSource(playlist, initialIndex: index);
      _player.play();
    } catch (e) {
      debugPrint("Error al reproducir: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("MY LIBRARY", style: GoogleFonts.orbitron(color: neonBlue, fontSize: 14, letterSpacing: 2)),
        actions: [
          IconButton(
            icon: Icon(Icons.shuffle, color: isShuffle ? neonBlue : Colors.white38),
            onPressed: () {
              setState(() => isShuffle = !isShuffle);
              _player.setShuffleModeEnabled(isShuffle);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // SCANNER DE CANCIONES
          FutureBuilder<List<SongModel>>(
            future: _audioQuery.querySongs(
              sortType: null,
              orderType: OrderType.ASC_OR_SMALLER,
              uriType: UriType.EXTERNAL,
              ignoreCase: true,
            ),
            builder: (context, item) {
              if (item.data == null) return const Center(child: CircularProgressIndicator());
              if (item.data!.isEmpty) return const Center(child: Text("No se encontró música"));

              allSongsInDevice = item.data!;

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: item.data!.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: QueryArtworkWidget(
                      id: item.data![index].id,
                      type: ArtworkType.AUDIO,
                      nullArtworkWidget: Icon(Icons.music_note, color: neonBlue),
                    ),
                    title: Text(item.data![index].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(item.data![index].artist ?? "Artista desconocido"),
                    onTap: () => _playSong(item.data!, index),
                  );
                },
              );
            },
          ),
          // REPRODUCTOR FLOTANTE
          Positioned(bottom: 0, left: 0, right: 0, child: _buildPersistentPlayer()),
        ],
      ),
    );
  }

  Widget _buildPersistentPlayer() {
    return StreamBuilder<SequenceState?>(
      stream: _player.sequenceStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) return const SizedBox();
        final currentSong = allSongsInDevice[state.currentIndex];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF16161E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [BoxShadow(color: neonBlue.withOpacity(0.2), blurRadius: 15)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  QueryArtworkWidget(id: currentSong.id, type: ArtworkType.AUDIO, artworkWidth: 45, artworkHeight: 45),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(currentSong.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1),
                      Text(currentSong.artist ?? "Unknown", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ]),
                  ),
                  IconButton(icon: const Icon(Icons.skip_previous), onPressed: () => _player.seekToPrevious()),
                  _playButton(),
                  IconButton(icon: const Icon(Icons.skip_next), onPressed: () => _player.seekToNext()),
                ],
              ),
              _buildProgress(),
            ],
          ),
        );
      },
    );
  }

  Widget _playButton() {
    return StreamBuilder<bool>(
      stream: _player.playingStream,
      builder: (context, snapshot) => IconButton(
        iconSize: 45,
        icon: Icon((snapshot.data ?? false) ? Icons.pause_circle_filled : Icons.play_circle_filled, color: neonBlue),
        onPressed: () => (snapshot.data ?? false) ? _player.pause() : _player.play(),
      ),
    );
  }

  Widget _buildProgress() {
    return StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (context, snapshot) => ProgressBar(
        progress: snapshot.data ?? Duration.zero,
        total: _player.duration ?? Duration.zero,
        progressBarColor: neonBlue,
        thumbColor: Colors.white,
        barHeight: 3,
        onSeek: (d) => _player.seek(d),
      ),
    );
  }
}