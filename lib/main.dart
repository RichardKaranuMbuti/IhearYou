import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IHearYou',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isSpeaking = false;

  String _lastWords = '';
  String _statusMessage = 'Press mic to start';
  Color _backgroundColor = Colors.white;
  String _selectedLocaleId = '';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  // Initialize speech and TTS services
  Future<void> _initializeServices() async {
    try {
      // Request microphone permission
      var status = await Permission.microphone.request();
      developer.log('Microphone permission status: $status');
      if (status != PermissionStatus.granted) {
        setState(() {
          _statusMessage = 'Microphone permission denied';
        });
        return;
      }

      // Initialize speech recognition
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          developer.log('Speech status: $status');
          setState(() {
            if (status == 'done' || status == 'notListening') {
              _isListening = false;
              _statusMessage = 'Stopped listening. Press mic to start again.';
            }
          });
        },
        onError: (error) {
          developer.log('Speech error: ${error.errorMsg}');
          setState(() {
            _isListening = false;
            _statusMessage = 'Error: ${error.errorMsg}. Press mic to try again.';
          });
        },
        debugLogging: true,
      );

      if (_speechEnabled) {
        // Get available locales
        final locales = await _speechToText.locales();

        // Find English locale
        var englishLocale = locales.where((locale) =>
            locale.localeId.startsWith('en_')).toList();

        if (englishLocale.isNotEmpty) {
          _selectedLocaleId = englishLocale.first.localeId;
        } else if (locales.isNotEmpty) {
          _selectedLocaleId = locales.first.localeId;
        }

        developer.log('Selected locale: $_selectedLocaleId');
      }

      // Initialize text-to-speech
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);

      // Set completion callback for TTS
      _flutterTts.setCompletionHandler(() {
        setState(() {
          _isSpeaking = false;
          _statusMessage = 'Press mic to start listening again';
        });
      });

      // Initialize error callback for TTS
      _flutterTts.setErrorHandler((error) {
        developer.log('TTS error: $error');
        setState(() {
          _isSpeaking = false;
          _statusMessage = 'TTS error: $error. Press mic to start listening.';
        });
      });

      setState(() {
        _statusMessage = _speechEnabled
            ? 'Ready. Press mic to start listening.'
            : 'Speech recognition not available';
      });

    } catch (e) {
      developer.log('Initialization error: $e');
      setState(() {
        _statusMessage = 'Error during setup: $e';
        _speechEnabled = false;
      });
    }
  }

  // Start listening for speech
  void _startListening() async {
    if (!_speechEnabled || _isListening || _isSpeaking) {
      developer.log('Cannot start listening: speech=${_speechEnabled}, listening=${_isListening}, speaking=${_isSpeaking}');
      return;
    }

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        localeId: _selectedLocaleId.isNotEmpty ? _selectedLocaleId : null,
        listenFor: Duration(seconds: 30), // Max listening time
        pauseFor: Duration(seconds: 5), // Auto-stop if silence
        partialResults: true, // Get results as they come
        listenMode: ListenMode.confirmation, // Better for single words
      );

      setState(() {
        _isListening = true;
        _lastWords = '';
        _statusMessage = 'Listening... Say "Blue" or "Red"';
      });
    } catch (e) {
      developer.log('Error starting listening: $e');
      setState(() {
        _isListening = false;
        _statusMessage = 'Error starting listening: $e';
      });
    }
  }

  // Stop listening for speech
  void _stopListening() async {
    if (!_isListening) return;

    try {
      await _speechToText.stop();
      setState(() {
        _isListening = false;
        _statusMessage = 'Stopped listening. Press mic to start again.';
      });
    } catch (e) {
      developer.log('Error stopping listening: $e');
      setState(() {
        _isListening = false;
        _statusMessage = 'Error stopping listening: $e';
      });
    }
  }

  // Process speech recognition results
  void _onSpeechResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.toLowerCase();
    developer.log('Recognized: $words (${result.finalResult ? 'final' : 'partial'})');

    setState(() {
      _lastWords = words;

      // Check for color keywords
      bool colorDetected = false;

      if (words.contains('blue')) {
        // Stop listening to avoid conflicts
        _stopListening();

        // Update UI
        _backgroundColor = Colors.blue;
        colorDetected = true;

        // Speak response
        _speakResponse("Here is the blue screen");
      } else if (words.contains('red')) {
        // Stop listening to avoid conflicts
        _stopListening();

        // Update UI
        _backgroundColor = Colors.red;
        colorDetected = true;

        // Speak response
        _speakResponse("Here is the red screen");
      }

      if (colorDetected) {
        _statusMessage = 'Color detected! Press mic to listen again.';
      } else if (result.finalResult) {
        _statusMessage = 'No color detected. Keep speaking or press mic to restart.';
      }
    });
  }

  // Speak the response using TTS
  void _speakResponse(String text) async {
    setState(() {
      _isSpeaking = true;
    });

    try {
      await _flutterTts.speak(text);
    } catch (e) {
      developer.log('TTS error: $e');
      setState(() {
        _isSpeaking = false;
        _statusMessage = 'TTS error: $e';
      });
    }
  }

  // Toggle listening state when mic button is pressed
  void _toggleListening() {
    if (_isSpeaking) {
      // If speaking, just stop the speech
      _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
        _statusMessage = 'Speech stopped. Press mic to start listening.';
      });
      return;
    }

    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  @override
  void dispose() {
    _stopListening();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('IHearYou'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Say "Blue" or "Red"\nto change the screen color',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 50),
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _isListening
                    ? 'Listening...'
                    : (_isSpeaking
                    ? 'Speaking...'
                    : 'Press mic to start'),
                style: TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _statusMessage,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                textAlign: TextAlign.center,
              ),
            ),
            if (_lastWords.isNotEmpty) ...[
              const SizedBox(height: 40),
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.7),
                ),
                child: Text(
                  'Heard: "$_lastWords"',
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _speechEnabled ? _toggleListening : null,
        tooltip: _isListening ? 'Stop Listening' : 'Start Listening',
        backgroundColor: _isListening
            ? Colors.red
            : (_speechEnabled ? Theme.of(context).colorScheme.primary : Colors.grey),
        child: Icon(_isListening ? Icons.mic_off : Icons.mic),
      ),
    );
  }
}