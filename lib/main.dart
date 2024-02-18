import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:file_manager/file_manager.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}
class MyHttpOverrides extends HttpOverrides{
  @override
  HttpClient createHttpClient(SecurityContext? context){
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port)=> true;
  }
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final zipFile = "https://sample-videos.com/zip/10mb.zip"; //zip file path
  var dio = Dio();//dio library for download zip file

  String fullPath="";
  final FileManagerController controller = FileManagerController();//file manager

  bool showFiles=false;//show or hide file manager
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(onPressed: extractFile, child: const Text("Extract File")),
          ElevatedButton(onPressed: () async {
            // FileManager.requestFilesAccessPermission();
            var tempDir = await getApplicationDocumentsDirectory();
            controller.setCurrentPath = tempDir.path;
            showFiles=true;
            setState(() {

            });
          }, child: Text("Fetch Files")),
           Expanded(child:
           showFiles?ControlBackButton(
             controller: controller,
             child: FileManager(
               controller: controller,
               builder: (context, snapshot) {
                 final List<FileSystemEntity> entities = snapshot;
                 return ListView.builder(
                   padding: EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                   itemCount: entities.length,
                   itemBuilder: (context, index) {
                     FileSystemEntity entity = entities[index];
                     return Card(
                       child: ListTile(
                         leading: FileManager.isFile(entity)
                             ? Icon(Icons.feed_outlined)
                             : Icon(Icons.folder),
                         title: Text(FileManager.basename(
                           entity,
                           showFileExtension: true,
                         )),
                         subtitle: subtitle(entity),
                         onTap: () async {
                           if (FileManager.isDirectory(entity)) {
                             // open the folder
                             controller.openDirectory(entity);

                            } else {
                            }
                         },
                       ),
                     );
                   },
                 );
               },
             ),
           ):Container(),)

            ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Permission.storage.request();
          var tempDir = await getApplicationDocumentsDirectory();
          fullPath = "${tempDir.path}/${DateTime.now().microsecondsSinceEpoch}.zip'";
          print('full path $fullPath');
            setState(() {

            });
          download2(dio, zipFile, fullPath);
        },
        tooltip: 'Increment',
        child: const Icon(Icons.download),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
  Widget subtitle(FileSystemEntity entity) {
    return FutureBuilder<FileStat>(
      future: entity.stat(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          if (entity is File) {
            int size = snapshot.data!.size;

            return Text(
              "${FileManager.formatBytes(size)}",
            );
          }
          return Text(
            "${snapshot.data!.modified}".substring(0, 10),
          );
        } else {
          return Text("");
        }
      },
    );
  }

  Future download2(Dio dio, String url, String savePath) async {
    try {
      Response response = await dio.get(
        url,
        onReceiveProgress: showDownloadProgress,
        //Received data with List<int>
        options: Options(
            responseType: ResponseType.bytes,
            followRedirects: false,
            validateStatus: (status) { return status! < 500; }
        ),
      );
      print(response.headers);
      File file = File(savePath);
      var raf = file.openSync(mode: FileMode.write);
      // response.data is List<int> type
      raf.writeFromSync(response.data);
      await raf.close();
    } catch (e) {
      print(e);
    }
  }

  void showDownloadProgress(received, total) {
    if (total != -1) {
      print((received / total * 100).toStringAsFixed(0) + "%");
    }
  }

  void extractFile() async{
    var die=await getApplicationDocumentsDirectory();
    //create out directory for extract zip file
    Directory d=await Directory("${die.path}/out/").create(recursive: true);
    final bytes = File('$fullPath').readAsBytesSync();

    // Decode the Zip file
    final archive = ZipDecoder().decodeBytes(bytes);
// Extract the contents of the Zip archive to disk.
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        File('${d.path}$filename')
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        Directory('${d.path}$filename').create(recursive: true);
      }
    }
  }
}
