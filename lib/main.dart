import 'package:flutter/foundation.dart'; // Factory için gerekli
import 'package:flutter/gestures.dart'; // GestureRecognizer için gerekli
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

// Hedef web siteleri ve arama URL yapıları
final List<Map<String, String>> targetSites = [
  {
    'name': 'Mavi',
    'searchUrl':
        'https://www.mavi.com/search/?text={query}', // {query} yerine arama terimi gelecek
  },
  {
    'name': 'Koton',
    'searchUrl': 'https://www.koton.com/list/?search_text={query}',
  },
  {'name': 'LC Waikiki', 'searchUrl': 'https://www.lcw.com/arama?q={query}'},
  {
    'name': 'LTB Jeans',
    'searchUrl': 'https://www.ltbjeans.com/tr-TR/search?text={query}',
  },
  {
    'name': 'Trendyol',
    'searchUrl':
        'https://www.trendyol-milla.com/sr?q={query}&qt={query}&st={query}&os=1',
  },
  {
    'name': 'Hepsiburada',
    'searchUrl': 'https://www.hepsiburada.com/ara?q={query}',
  },
  {
    'name': 'Mango',
    'searchUrl': 'https://shop.mango.com/tr/tr/search/kadin/new?q={query}',
  },
];

void main() {
  // Flutter motorunun başlatıldığından emin olur (WebView için gerekli)
  WidgetsFlutterBinding.ensureInitialized();

  // WebView platformunu başlat - güncel yöntem
  // Bu platforma özel başlatmalar genellikle artık gerekli değildir,
  // paketler bunu otomatik halleder, ancak bırakmak zarar vermez.
  // if (Platform.isAndroid) {
  //   AndroidWebViewPlatform.registerWith();
  // } else if (Platform.isIOS) {
  //   WebKitWebViewPlatform.registerWith();
  // }
  // Not: Eğer webview_flutter'ın çok eski bir sürümünü kullanmıyorsanız,
  // yukarıdaki platforma özel registerWith çağrıları genellikle gereksizdir.

  runApp(const MyApp()); // Uygulamayı başlatır
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi Web Search',
      theme: ThemeData(
        primarySwatch: Colors.teal, // Daha modern bir renk paleti
        visualDensity:
            VisualDensity
                .adaptivePlatformDensity, // Platforma uyum sağlayan yoğunluk
        useMaterial3: true, // Material 3 tasarımını kullan
      ),
      home:
          const MultiSearchView(), // Ana sayfa olarak yeni arama ekranını gösterir
      debugShowCheckedModeBanner: false, // Debug banner'ı kaldırır
    );
  }
}

// Çoklu WebView Arama Ekranı
class MultiSearchView extends StatefulWidget {
  const MultiSearchView({super.key});

  @override
  State<MultiSearchView> createState() => _MultiSearchViewState();
}

class _MultiSearchViewState extends State<MultiSearchView> {
  final TextEditingController _searchController = TextEditingController();
  // Her site için bir WebView Controller listesi
  late List<WebViewController> _webControllers;
  // Her WebView için yüklenme durumu listesi
  late List<bool> _isLoading;
  // Arama yapılıp yapılmadığını tutan state
  bool _isSearchPerformed = false;
  // Seçili site indeksi
  int _selectedSiteIndex = 0;

  @override
  void initState() {
    super.initState();

    // Controller ve isLoading listelerinin başlatılması
    _webControllers = List.generate(targetSites.length, (index) {
      late final PlatformWebViewControllerCreationParams params;
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }
      final controller = WebViewController.fromPlatformCreationParams(params);

      // Android'e özel ayarlar (Platform kontrolüyle daha güvenli)
      if (controller.platform is AndroidWebViewController) {
        // AndroidWebViewController.enableDebugging(kDebugMode); // Sadece debug modunda etkinleştir
        (controller.platform as AndroidWebViewController)
          ..setMediaPlaybackRequiresUserGesture(false)
          ..setGeolocationEnabled(
            false,
          ); // Gizlilik için coğrafi konumu devre dışı bırak
      }

      // Genel Controller ayarları
      controller
        ..setJavaScriptMode(
          JavaScriptMode.unrestricted,
        ) // JavaScript'i etkinleştir
        ..setBackgroundColor(
          const Color(0xFFF5F5F5),
        ) // Arka plan rengi - scaffold arka planıyla eşleşecek şekilde
        ..enableZoom(true) // Yakınlaştırmayı etkinleştir
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              // İlgili WebView için yükleme durumunu güncelle
              if (mounted && _isSearchPerformed) {
                // Sadece arama yapıldıysa ve widget ağaçtaysa güncelle
                setState(() {
                  // İndeksin geçerli olduğundan emin ol
                  if (index < _isLoading.length) {
                    _isLoading[index] = true;
                  }
                });
              }
            },
            onPageFinished: (String url) {
              if (mounted && _isSearchPerformed) {
                setState(() {
                  // İndeksin geçerli olduğundan emin ol
                  if (index < _isLoading.length) {
                    _isLoading[index] = false;
                  }
                });

                // Sayfanın kaydırılabilir olmasını sağlayan JavaScript kodu (Hala faydalı olabilir)
                controller
                    .runJavaScript('''
                  document.body.style.overflowX = 'auto';
                  document.body.style.overflowY = 'auto';
                  document.documentElement.style.overscrollBehavior = 'auto';
                ''')
                    .catchError((e) {
                      // JS çalıştırma hatalarını yakala (opsiyonel)
                      print(
                        "JavaScript execution error on ${targetSites[index]['name']}: $e",
                      );
                    });
              }
            },
            onProgress: (int progress) {
              // İsteğe bağlı: Her WebView için ayrı progress gösterilebilir
              // print('WebView ${targetSites[index]['name']} loading: $progress%');
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted && _isSearchPerformed) {
                setState(() {
                  // İndeksin geçerli olduğundan emin ol
                  if (index < _isLoading.length) {
                    _isLoading[index] = false;
                  }
                });
                // Kullanıcıya hata mesajı gösterilebilir (isteğe bağlı)
                print(
                  "WebView Error (${targetSites[index]['name']}): ${error.description}, URL: ${error.url}, ErrorCode: ${error.errorCode}, Type: ${error.errorType}, Failing URL: ${error.url}",
                );
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text("${targetSites[index]['name']} yüklenirken hata: ${error.description}")),
                // );
              }
            },
            // İsteğe bağlı: Belirli URL'lere gitmeyi engelleyebilirsiniz
            // onNavigationRequest: (NavigationRequest request) {
            //   print('Allowing navigation to ${request.url}');
            //   return NavigationDecision.navigate; // Varsayılan olarak gezinmeye izin ver
            // },
          ),
        );
      return controller;
    });

    // Başlangıçta tüm WebView'lar yüklenmiyor durumda
    _isLoading = List.generate(targetSites.length, (_) => false);

    // İzinleri build tamamlandıktan sonra iste
    WidgetsBinding.instance.addPostFrameCallback((_) {
      //    _requestPermissions();
    });
  }

  // İzinleri isteyen fonksiyon
  /*Future<void> _requestPermissions() async {
    // WebView'un kendisi genellikle doğrudan kamera/mikrofon izni istemez.
    // Bunlar daha çok WebRTC gibi özellikler için gereklidir ve web sayfasının
    // kendisi tarafından tetiklenir. Eğer gerekiyorsa:
    Map<Permission, PermissionStatus> statuses = await [
      // Permission.camera, // Gerekmiyorsa yorum satırı yapın
      // Permission.microphone, // Gerekmiyorsa yorum satırı yapın
      // Konum izni gerekebilir (bazı siteler isteyebilir)
      // Permission.locationWhenInUse,
    ].request();

    // Reddedilen izinler için geri bildirim (isteğe bağlı)
    statuses.forEach((permission, status) {
      if (!status.isGranted && mounted) { // `mounted` kontrolü eklendi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${permission.toString()} izni reddedildi. Bazı özellikler çalışmayabilir.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }
*/
  // Arama işlemini gerçekleştiren fonksiyon
  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      // Boş arama yapılmasını engelle
      if (mounted) {
        // mounted kontrolü eklendi
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lütfen bir arama terimi girin.")),
        );
      }
      return;
    }

    // Klavyeyi kapat
    FocusScope.of(context).unfocus();

    // URL uyumlu hale getir (boşlukları '+' veya '%20' ile değiştir)
    final encodedQuery = Uri.encodeComponent(query.trim());

    setState(() {
      _isSearchPerformed = true; // Arama yapıldığını işaretle
      // Her bir WebView için ilgili arama URL'sini yükle
      for (int i = 0; i < targetSites.length; i++) {
        // Önceki yüklemeyi durdurabilir (opsiyonel ama iyi pratik)
        // _webControllers[i].stopLoading(); // Gerekirse
        final site = targetSites[i];
        final searchUrl = site['searchUrl']!.replaceAll(
          '{query}',
          encodedQuery,
        );
        _isLoading[i] = true; // Yükleme başlıyor
        try {
          _webControllers[i].loadRequest(Uri.parse(searchUrl));
        } catch (e) {
          print("Error loading URL $searchUrl for ${site['name']}: $e");
          if (mounted) {
            // mounted kontrolü
            setState(() {
              _isLoading[i] = false; // Hata olursa yükleniyor durumunu kapat
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("${site['name']} için URL yüklenemedi.")),
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    // WebView controller'ları dispose etmeye genellikle gerek yok,
    // WebViewWidget ağaçtan kaldırıldığında bunu kendi halleder.
    // Ancak emin olmak isterseniz veya özel temizleme gerekiyorsa yapılabilir:
    // for (var controller in _webControllers) {
    //   // Özel temizleme işlemleri...
    // }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ekran genişliğine göre grid sütun sayısını belirle
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount =
        screenWidth < 600
            ? 1
            : (screenWidth < 900 ? 2 : 3); // Küçük, orta, büyük ekranlar için

    return Scaffold(
      backgroundColor: const Color(
        0xFFF5F5F5,
      ), // Arka plan rengini WebView arka planıyla eşleştir
      appBar: AppBar(
        title: const Text('Multi Web Search'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(
            kToolbarHeight + 10,
          ), // Arama çubuğu için biraz daha boşluk
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              12.0,
              0,
              12.0,
              12.0,
            ), // Alt boşluğu artır
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Aranacak ürünü girin...',
                filled: true, // Arka plan rengi için
                fillColor: Colors.white.withOpacity(0.95), // Biraz daha opak
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    30.0,
                  ), // Yuvarlak kenarlar
                  borderSide: BorderSide.none, // Kenar çizgisi olmasın
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 14.0,
                ), // Dikey padding ayarlandı
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.search,
                    color: Colors.teal,
                  ), // İkon rengi
                  onPressed: () => _performSearch(_searchController.text),
                  tooltip: 'Ara',
                ),
                prefixIcon: const Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.grey,
                ), // Başlangıç ikonu (isteğe bağlı)
              ),
              onSubmitted: _performSearch, // Enter tuşu ile arama
              textInputAction: TextInputAction.search, // Klavye action butonu
            ),
          ),
        ),
        elevation: 2.0, // AppBar'a hafif bir gölge
      ),
      body: _buildBody(crossAxisCount), // Body'yi ayrı bir fonksiyona taşıdık
    );
  }

  Widget _buildBody(int crossAxisCount) {
    return Column(
      children: [
        // Yatay butonlar satırı - kaydırılabilir olarak güncellendi
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: List.generate(targetSites.length, (index) {
                final siteName = targetSites[index]['name'] ?? 'Site';
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // Prevent unnecessary state updates if already on this site
                      if (_selectedSiteIndex == index) return;

                      // Set loading state to true for the target site if not already loaded
                      if (_isSearchPerformed && !_isLoading[index]) {
                        setState(() {
                          _isLoading[index] = true;
                        });
                      }

                      // Update the selected index with setState for UI update
                      setState(() {
                        _selectedSiteIndex = index;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _selectedSiteIndex == index
                              ? Colors.teal
                              : Colors.white,
                      foregroundColor:
                          _selectedSiteIndex == index
                              ? Colors.white
                              : Colors.teal,
                      elevation: _selectedSiteIndex == index ? 2 : 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        side: BorderSide(color: Colors.teal.shade300),
                      ),
                    ),
                    child: Text(siteName, style: TextStyle(fontSize: 13)),
                  ),
                );
              }),
            ),
          ),
        ),

        // WebView veya karşılama mesajı
        Expanded(
          child:
              !_isSearchPerformed
                  ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_outlined,
                            size: 80,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Sonuçları görmek için yukarıdan bir ürün arayın.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                  : Stack(
                    alignment: Alignment.center,
                    children: [
                      // Tüm WebView'ları yükle ama sadece seçili olanı göster
                      ...List.generate(targetSites.length, (index) {
                        return Offstage(
                          offstage:
                              _selectedSiteIndex !=
                              index, // Seçili değilse gizle
                          child: AnimatedOpacity(
                            opacity: _selectedSiteIndex == index ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: WebViewWidget(
                              controller: _webControllers[index],
                              gestureRecognizers:
                                  <Factory<OneSequenceGestureRecognizer>>{
                                    Factory<VerticalDragGestureRecognizer>(
                                      () => VerticalDragGestureRecognizer(),
                                    ),
                                    Factory<HorizontalDragGestureRecognizer>(
                                      () => HorizontalDragGestureRecognizer(),
                                    ),
                                    Factory<ScaleGestureRecognizer>(
                                      () => ScaleGestureRecognizer(),
                                    ),
                                  },
                            ),
                          ),
                        );
                      }),
                      // Yükleniyor göstergesi
                      if (_selectedSiteIndex < _isLoading.length &&
                          _isLoading[_selectedSiteIndex])
                        const CircularProgressIndicator(),
                    ],
                  ),
        ),
      ],
    );
  }
}
