// Import necessary packages
import 'dart:developer' as developer; // For logging

import 'package:flutter/material.dart'; // Core Flutter UI package
import 'package:flutter_tts/flutter_tts.dart'; // For text-to-speech
import 'package:permission_handler/permission_handler.dart'; // For handling permissions
import 'package:speech_to_text/speech_recognition_result.dart'; // For handling speech results
import 'package:speech_to_text/speech_to_text.dart'; // For speech recognition

// Main entry point of the application
void main() {
  runApp(const MyApp());
}

// Root widget of the application
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IHearYou', // App title
      theme: ThemeData(
        // Material 3 theme with deep purple as the seed color
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(), // Sets the home screen
    );
  }
}

// Main page of the app
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// State class for the HomePage
class _HomePageState extends State<HomePage> {
  // Initialize speech recognition and text-to-speech engines
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  // State variables to track app status
  bool _speechEnabled = false; // Whether speech recognition is available
  bool _isListening = false; // Whether actively listening for commands
  bool _isSpeaking = false; // Whether TTS is currently speaking

  String _lastWords = ''; // Last recognized speech
  String _statusMessage =
      'Press mic to start'; // Status message displayed to user
  Color _backgroundColor = Colors.white; // Current background color
  String _selectedLocaleId = ''; // Selected language for speech recognition

  @override
  void initState() {
    super.initState();
    // Initialize speech and TTS services when the app starts
    _initializeServices();
  }

  // Initialize speech recognition and text-to-speech services
  Future<void> _initializeServices() async {
    try {
      // Request microphone permission - essential for speech recognition
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
          // Log and update UI when speech recognition status changes
          developer.log('Speech status: $status');
          setState(() {
            if (status == 'done' || status == 'notListening') {
              _isListening = false;
              _statusMessage = 'Stopped listening. Press mic to start again.';
            }
          });
        },
        onError: (error) {
          // Handle speech recognition errors
          developer.log('Speech error: ${error.errorMsg}');
          setState(() {
            _isListening = false;
            _statusMessage =
                'Error: ${error.errorMsg}. Press mic to try again.';
          });
        },
        debugLogging: true, // Enable debug logging
      );

      if (_speechEnabled) {
        // Get available language locales for speech recognition
        final locales = await _speechToText.locales();

        // Find an English locale preferably
        var englishLocale = locales
            .where((locale) => locale.localeId.startsWith('en_'))
            .toList();

        if (englishLocale.isNotEmpty) {
          _selectedLocaleId = englishLocale.first.localeId;
        } else if (locales.isNotEmpty) {
          // Fall back to first available locale if no English locale
          _selectedLocaleId = locales.first.localeId;
        }

        developer.log('Selected locale: $_selectedLocaleId');
      }

      // Initialize text-to-speech with English language
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0); // Normal pitch
      await _flutterTts.setSpeechRate(0.5); // Slower speech rate for clarity
      await _flutterTts.setVolume(1.0); // Full volume

      // Set callback when TTS finishes speaking
      _flutterTts.setCompletionHandler(() {
        setState(() {
          _isSpeaking = false;
          _statusMessage = 'Press mic to start listening again';
        });
      });

      // Set callback for TTS errors
      _flutterTts.setErrorHandler((error) {
        developer.log('TTS error: $error');
        setState(() {
          _isSpeaking = false;
          _statusMessage = 'TTS error: $error. Press mic to start listening.';
        });
      });

      // Update UI with initial status message
      setState(() {
        _statusMessage = _speechEnabled
            ? 'Ready. Press mic to start listening.'
            : 'Speech recognition not available';
      });
    } catch (e) {
      // Handle any initialization errors
      developer.log('Initialization error: $e');
      setState(() {
        _statusMessage = 'Error during setup: $e';
        _speechEnabled = false;
      });
    }
  }

  // Start listening for speech commands
  void _startListening() async {
    // Check if we can start listening
    if (!_speechEnabled || _isListening || _isSpeaking) {
      developer.log(
          'Cannot start listening: speech=${_speechEnabled}, listening=${_isListening}, speaking=${_isSpeaking}');
      return;
    }

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult, // Callback for speech results
        localeId: _selectedLocaleId.isNotEmpty ? _selectedLocaleId : null,
        listenFor: Duration(seconds: 30), // Max listening time
        pauseFor: Duration(seconds: 5), // Auto-stop after 5 seconds of silence
        partialResults: true, // Get real-time partial results
        listenMode: ListenMode.confirmation, // Better for single words/commands
      );

      // Update UI to show we're listening
      setState(() {
        _isListening = true;
        _lastWords = '';
        _statusMessage = 'Listening... Say "Blue" or "Red"';
      });
    } catch (e) {
      // Handle errors when starting listening
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
      // Handle errors when stopping listening
      developer.log('Error stopping listening: $e');
      setState(() {
        _isListening = false;
        _statusMessage = 'Error stopping listening: $e';
      });
    }
  }

  // Process speech recognition results
  void _onSpeechResult(SpeechRecognitionResult result) {
    // Convert recognized words to lowercase for case-insensitive comparison
    final words = result.recognizedWords.toLowerCase();
    developer.log(
        'Recognized: $words (${result.finalResult ? 'final' : 'partial'})');

    setState(() {
      _lastWords = words;

      // Check for color keywords in the recognized speech
      bool colorDetected = false;

      if (words.contains('blue')) {
        // Stop listening to avoid conflicts with TTS
        _stopListening();

        // Change background color to blue
        _backgroundColor = Colors.blue;
        colorDetected = true;

        // Provide audio feedback
        _speakResponse("Here is the blue screen");
      } else if (words.contains('red')) {
        // Stop listening to avoid conflicts with TTS
        _stopListening();

        // Change background color to red
        _backgroundColor = Colors.red;
        colorDetected = true;

        // Provide audio feedback
        _speakResponse("Here is the red screen");
      }

      // Update status message based on whether a color was detected
      if (colorDetected) {
        _statusMessage = 'Color detected! Press mic to listen again.';
      } else if (result.finalResult) {
        _statusMessage =
            'No color detected. Keep speaking or press mic to restart.';
      }
    });
  }

  // Speak the response using text-to-speech
  void _speakResponse(String text) async {
    setState(() {
      _isSpeaking = true;
    });

    try {
      await _flutterTts.speak(text);
    } catch (e) {
      // Handle TTS errors
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
      // If currently speaking, stop the speech
      _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
        _statusMessage = 'Speech stopped. Press mic to start listening.';
      });
      return;
    }

    // Toggle between listening and not listening
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  @override
  void dispose() {
    // Clean up resources when widget is removed
    _stopListening();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build the UI
    return Scaffold(
      // Background color changes based on voice commands
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('IHearYou'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Instructions for the user
            const Text(
              'Say "Blue" or "Red"\nto change the screen color',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 50),
            // Status container showing if listening or speaking
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
                    : (_isSpeaking ? 'Speaking...' : 'Press mic to start'),
                style: TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            // Detailed status message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _statusMessage,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                textAlign: TextAlign.center,
              ),
            ),
            // Display recognized words if available
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
      // Floating action button to start/stop listening
      floatingActionButton: FloatingActionButton(
        onPressed: _speechEnabled
            ? _toggleListening
            : null, // Disabled if speech not available
        tooltip: _isListening ? 'Stop Listening' : 'Start Listening',
        backgroundColor: _isListening
            ? Colors.red // Red when listening
            : (_speechEnabled
                ? Theme.of(context).colorScheme.primary
                : Colors.grey), // Grey when disabled
        child: Icon(_isListening
            ? Icons.mic_off
            : Icons.mic), // Change icon based on state
      ),
    );
  }
}
