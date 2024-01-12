import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikacja Pogodowa',
      theme: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: MyHomePage(title: '', toggleTheme: _toggleTheme),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  const MyHomePage({Key? key, required this.title, required this.toggleTheme}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> cities = [];
  List<Future<Weather>> futureWeathers = [];
  final myController = TextEditingController();
  final pageController = PageController();

  String appBarTitle = '';

  @override
  void initState() {
    super.initState();
    _loadCities();
    _getCurrentLocation();
    pageController.addListener(() {
      int currentIndex = pageController.page!.round();
      setState(() {
        if (currentIndex == cities.length) {
          appBarTitle = 'Dodaj miasto';
        } else {
          appBarTitle = cities[currentIndex];
        }
      });
    });
  }

  _loadCities() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    cities = prefs.getStringList('cities') ?? [];
    futureWeathers = cities.map((city) => fetchWeather(city)).toList();
    setState(() {});
  }

  _addCity(String city) async {
    city = city[0].toUpperCase() + city.substring(1);
    try {
      Weather weather = await fetchWeather(city);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      cities.add(city);
      prefs.setStringList('cities', cities);
      futureWeathers.add(Future.value(weather));
      setState(() {});
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Błąd'),
            content: Text('Wprowadzono błędne dane'),
            actions: <Widget>[
              TextButton(
                child: Text('Zamknij'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  _removeCity(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    cities.removeAt(index);
    futureWeathers.removeAt(index);
    prefs.setStringList('cities', cities);
    setState(() {});
  }

  Future<Weather> fetchWeather(String city) async {
    final response = await http.get(Uri.parse(
        'http://api.openweathermap.org/data/2.5/weather?q=$city&appid=6b0aa89007a27e2c05ee4c512e412c4b&units=metric&lang=pl'));

    if (response.statusCode == 200) {
      return Weather.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Nie udało się załadować pogody dla miasta $city');
    }
  }

  _getCurrentLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstRun = prefs.getBool('first_run') ?? true;
    if (isFirstRun) {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);
      String? locality = placemarks[0].locality;
      if (locality != null) {
        _addCity(locality);
      } else {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Błąd'),
              content: Text('Nie udało się pobrać lokalizacji'),
              actions: <Widget>[
                TextButton(
                  child: Text('Zamknij'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
      await prefs.setBool('first_run', false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
        title: Text(
          appBarTitle,
          style: TextStyle(fontSize: 36),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.brightness_6),
            onPressed: widget.toggleTheme,
          ),
          IconButton(
            icon: Icon(Icons.list),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text('Lista miast'),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                    content: Container(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: cities.length,
                        itemBuilder: (BuildContext context, int index) {
                          return Card(
                            child: ListTile(
                              title: Text(cities[index]),
                              onTap: () {
                                Navigator.of(context).pop();
                                pageController.jumpToPage(index);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: pageController,
        itemCount: cities.length + 1,
        itemBuilder: (context, index) {
          if (index == cities.length) {
            return Center(
              child: IconButton(
                icon: Icon(Icons.add, size: 48),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        backgroundColor: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text('Dodaj miasto'),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                        content: TextField(
                          onSubmitted: (value) {
                            Navigator.of(context).pop();
                            _addCity(value);
                          },
                          decoration: InputDecoration(
                            hintText: "Wpisz nazwę miasta",
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          }
          return SingleChildScrollView(
            child: FutureBuilder<Weather>(
              future: futureWeathers[index],
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  IconData weatherIcon = weatherIcons[snapshot.data!
                      .description] ?? Icons.error;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          // Text(
                          //   // '${cities[index]}',
                          //   // style: TextStyle(fontSize: 38),
                          // ),
                          // if (index == 0) Icon(Icons.location_on),
                        ],
                      ),
                      Text(
                        '${snapshot.data!.temp.round()}°C',
                        style: TextStyle(fontSize: 42),
                      ),
                      Text(
                        'Od ${snapshot.data!.temp_min.round()}°C Do ${snapshot
                            .data!.temp_max.round()}°C',
                        style: TextStyle(fontSize: 16),
                      ),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(weatherIcon, size: 30), // Ikona
                            Flexible(
                              child: Text(
                                snapshot.data!.description,
                                style: TextStyle(fontSize: 30),
                                textAlign: TextAlign.center, // Wyśrodkowanie tekstu
                              ),
                            ),
                          ],
                        ),
                      ),
                      Card(
                        color: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
                        child: ListTile(
                          leading: Icon(Icons.opacity),
                          title: Text('Wilgotność ${snapshot.data!.humidity}%'),
                        ),
                      ),
                      Card(
                        color: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
                        child: ListTile(
                          leading: Icon(Icons.air),
                          title: Text('Prędkość wiatru ${snapshot.data!.windSpeed} m/s'),
                        ),
                      ),
                      Card(
                        color: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
                        child: ListTile(
                          leading: Icon(Icons.navigation),
                          title: Text('Kierunek wiatru ${snapshot.data!.windDirection}°'),
                        ),
                      ),
                      Card(
                        color: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
                        child: ListTile(
                          leading: Icon(Icons.thermostat_outlined),
                          title: Text('Temperatura odczuwalna ${snapshot.data!.feelsLike.round()}°C'),
                        ),
                      ),
                      Card(
                        color: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
                        child: ListTile(
                          leading: Icon(Icons.speed),
                          title: Text('Ciśnienie atmosferyczne ${snapshot.data!.pressure} hPa'),
                        ),
                      ),
                      Card(
                        color: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
                        child: ListTile(
                          leading: Icon(Icons.visibility),
                          title: Text('Widoczność ${snapshot.data!.visibility} m'),
                        ),
                      ),
                      Card(
                        color: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
                        child: ListTile(
                          leading: Icon(Icons.water_drop),
                          title: Text('Opady ${snapshot.data!.precipitation} mm'),
                        ),
                      ),
                      Card(
                        color: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
                        child: ListTile(
                          leading: Icon(Icons.arrow_upward),
                          title: Text('Wschód słońca ${snapshot.data!.sunrise}'),
                        ),
                      ),
                      Card(
                        color: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
                        child: ListTile(
                          leading: Icon(Icons.arrow_downward),
                          title: Text('Zachód słońca ${snapshot.data!.sunset}'),
                        ),
                      ),
                      if (index != 0)
                        ElevatedButton(
                          child: Text('Usuń miasto'),
                          onPressed: () {
                            _removeCity(index);
                          },
                        ),
                    ],
                  );
                } else if (snapshot.hasError) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text('${snapshot.error}'),
                      ElevatedButton(
                        child: Text('Usuń stronę'),
                        onPressed: () {
                          _removeCity(index);
                        },
                      ),
                    ],
                  );
                }
                return CircularProgressIndicator();
              },
            ),
          );
        },
      ),
    );
  }
}


Map<String, IconData> weatherIcons = {
  'słonecznie': Icons.wb_sunny,
  'zachmurzenie': Icons.cloud,
  'zachmurzenie małe': Icons.cloud,
  'bezchmurnie': Icons.cloud_queue_rounded,
  'deszczowo': Icons.umbrella,
  'śnieg': Icons.ac_unit,
  'burza': Icons.flash_on,
  'mgła': Icons.cloud_off,
  'pochmurnie': Icons.cloud_off,
  'zachmurzenie duże': Icons.cloud_circle,
  'słabe przelotne opady deszczu': Icons.umbrella,
  'zachmurzenie umiarkowane': Icons.cloud_rounded,
  'silne opady': Icons.grain,
  'śnieżyca': Icons.snowshoeing,
  'grad': Icons.ice_skating,
  'tęcza': Icons.emoji_nature,
  'zamieć śnieżna': Icons.snowboarding,
  'zamglenia': Icons.cloud_off,
  'słabe zamglenie': Icons.cloud_off,
};


class Weather {
  final String description;
  final double temp;
  final int humidity;
  final double temp_min;
  final double temp_max;
  final double windSpeed;
  final int windDirection;
  final double feelsLike; // Temperatura odczuwalna
  final int pressure; // Ciśnienie atmosferyczne
  final int uvIndex; // Wskaźnik UV
  final int visibility; // Widoczność
  final double precipitation; // Opady
  final int cloudiness; // Zachmurzenie
  final String sunrise; // Wschód słońca
  final String sunset; // Zachód słońca

  Weather({
    required this.description,
    required this.temp,
    required this.humidity,
    required this.temp_min,
    required this.temp_max,
    required this.windSpeed,
    required this.windDirection,
    required this.feelsLike,
    required this.pressure,
    required this.uvIndex,
    required this.visibility,
    required this.precipitation,
    required this.cloudiness,
    required this.sunrise,
    required this.sunset,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      description: json['weather'][0]['description'],
      temp: json['main']['temp'].toDouble(),
      humidity: json['main']['humidity'] as int,
      temp_min: json['main']['temp_min'].toDouble(),
      temp_max: json['main']['temp_max'].toDouble(),
      windSpeed: json['wind']['speed'].toDouble(),
      windDirection: json['wind']['deg'] as int,
      feelsLike: json['main']['feels_like']?.toDouble() ?? 0.0,
      pressure: json['main']['pressure'] as int? ?? 0,
      uvIndex: json['uv_index'] as int? ?? 0,
      visibility: json['visibility'] as int? ?? 0,
      precipitation: json['precipitation']?.toDouble() ?? 0.0,
      cloudiness: json['clouds']['all'] as int? ?? 0,
      sunrise: DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(json['sys']['sunrise'] * 1000).toLocal()),
      sunset: DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(json['sys']['sunset'] * 1000).toLocal()),
    );
  }
}