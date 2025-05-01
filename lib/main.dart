import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:math' as math;

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
      title: 'CosmicVoice',
      debugShowCheckedModeBanner: false, // Remove debug banner
      theme: ThemeData(
        // Dark space theme with teal accents
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: Colors.teal,
          secondary: Colors.amber,
          surface: Color(0xFF1A1A2E),
          background: Color(0xFF0F0F1A),
        ),
        fontFamily: 'Orbitron', // Futuristic font
        useMaterial3: true,
      ),
      home: const CosmicHomePage(),
    );
  }
}

// Main page of the app
class CosmicHomePage extends StatefulWidget {
  const CosmicHomePage({super.key});

  @override
  State<CosmicHomePage> createState() => _CosmicHomePageState();
}

// State class for the CosmicHomePage
class _CosmicHomePageState extends State<CosmicHomePage> with SingleTickerProviderStateMixin {
  // Initialize speech recognition and text-to-speech engines
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  // Animation controller for visual effects
  late AnimationController _animationController;

  // State variables to track app status
  bool _speechEnabled = false; // Whether speech recognition is available
  bool _isListening = false;   // Whether actively listening for commands
  bool _isSpeaking = false;    // Whether TTS is currently speaking

  String _lastWords = '';      // Last recognized speech
  String _statusMessage = 'Tap portal to activate voice gateway'; // Status message displayed to user
  Color _backgroundColor = Color(0xFF0F0F1A); // Default background color - deep space
  String _selectedLocaleId = ''; // Selected language for speech recognition

  // Track stars for background animation
  List<Star> _stars = [];

  // Currently detected dimension (color)
  String _currentDimension = "home";

  @override
  void initState() {
    super.initState();
    // Initialize speech and TTS services when the app starts
    _initializeServices();

    // Create stars for background animation
    _generateStars();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    )..repeat();

    // Set up periodic timer to regenerate stars
    Timer.periodic(Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _generateStars();
        });
      }
    });
  }

  // Generate random stars for background
  void _generateStars() {
    _stars = List.generate(
        100,
            (index) => Star(
          x: math.Random().nextDouble() * 1.0,
          y: math.Random().nextDouble() * 1.0,
          size: math.Random().nextDouble() * 3 + 1,
          opacity: math.Random().nextDouble(),
        )
    );
  }

  // Initialize speech recognition and text-to-speech services
  Future<void> _initializeServices() async {
    try {
      // Request microphone permission - essential for speech recognition
      var status = await Permission.microphone.request();
      developer.log('Microphone permission status: $status');
      if (status != PermissionStatus.granted) {
        setState(() {
          _statusMessage = 'Voice gateway access denied';
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
              _statusMessage = 'Voice gateway deactivated. Tap portal to resume.';
            }
          });
        },
        onError: (error) {
          // Handle speech recognition errors
          developer.log('Speech error: ${error.errorMsg}');
          setState(() {
            _isListening = false;
            _statusMessage = 'Dimensional interference detected. Tap portal to retry.';
          });
        },
        debugLogging: true, // Enable debug logging
      );

      if (_speechEnabled) {
        // Get available language locales for speech recognition
        final locales = await _speechToText.locales();

        // Find an English locale preferably
        var englishLocale = locales.where((locale) =>
            locale.localeId.startsWith('en_')).toList();

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
      await _flutterTts.setPitch(1.2);      // Slightly higher pitch for computerized feel
      await _flutterTts.setSpeechRate(0.5); // Slower speech rate for clarity
      await _flutterTts.setVolume(1.0);     // Full volume

      // Set callback when TTS finishes speaking
      _flutterTts.setCompletionHandler(() {
        setState(() {
          _isSpeaking = false;
          _statusMessage = 'Dimensional shift complete. Tap portal to continue exploration.';
        });
      });

      // Set callback for TTS errors
      _flutterTts.setErrorHandler((error) {
        developer.log('TTS error: $error');
        setState(() {
          _isSpeaking = false;
          _statusMessage = 'Voice synthesis failure. Tap portal to recalibrate.';
        });
      });

      // Update UI with initial status message
      setState(() {
        _statusMessage = _speechEnabled
            ? 'Dimensional portal ready. Tap to activate voice gateway.'
            : 'Voice recognition protocols unavailable in this sector';
      });

    } catch (e) {
      // Handle any initialization errors
      developer.log('Initialization error: $e');
      setState(() {
        _statusMessage = 'System initialization error: $e';
        _speechEnabled = false;
      });
    }
  }

  // Start listening for speech commands
  void _startListening() async {
    // Check if we can start listening
    if (!_speechEnabled || _isListening || _isSpeaking) {
      developer.log('Cannot start listening: speech=${_speechEnabled}, listening=${_isListening}, speaking=${_isSpeaking}');
      return;
    }

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult, // Callback for speech results
        localeId: _selectedLocaleId.isNotEmpty ? _selectedLocaleId : null,
        listenFor: Duration(seconds: 30), // Max listening time
        pauseFor: Duration(seconds: 5),   // Auto-stop after 5 seconds of silence
        partialResults: true,             // Get real-time partial results
        listenMode: ListenMode.confirmation, // Better for single words/commands
      );

      // Update UI to show we're listening
      setState(() {
        _isListening = true;
        _lastWords = '';
        _statusMessage = 'Voice gateway active... Say "Azure" or "Crimson" to shift dimensions';
      });
    } catch (e) {
      // Handle errors when starting listening
      developer.log('Error starting listening: $e');
      setState(() {
        _isListening = false;
        _statusMessage = 'Voice gateway malfunction: $e';
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
        _statusMessage = 'Voice gateway closed. Tap portal to reactivate.';
      });
    } catch (e) {
      // Handle errors when stopping listening
      developer.log('Error stopping listening: $e');
      setState(() {
        _isListening = false;
        _statusMessage = 'Error sealing voice gateway: $e';
      });
    }
  }

  // Process speech recognition results
  void _onSpeechResult(SpeechRecognitionResult result) {
    // Convert recognized words to lowercase for case-insensitive comparison
    final words = result.recognizedWords.toLowerCase();
    developer.log('Recognized: $words (${result.finalResult ? 'final' : 'partial'})');

    setState(() {
      _lastWords = words;

      // Check for color keywords in the recognized speech
      bool dimensionShift = false;

      // Check for "blue" or alternative "azure" command
      if (words.contains('blue') || words.contains('azure')) {
        // Stop listening to avoid conflicts with TTS
        _stopListening();

        // Change background color to blue
        _backgroundColor = Color(0xFF0A2463); // Deep blue space
        dimensionShift = true;
        _currentDimension = "azure";

        // Provide audio feedback
        _speakResponse("Azure dimension shift complete. Welcome to the oceanic cosmos.");
      }
      // Check for "red" or alternative "crimson" command
      else if (words.contains('red') || words.contains('crimson')) {
        // Stop listening to avoid conflicts with TTS
        _stopListening();

        // Change background color to red
        _backgroundColor = Color(0xFF650D1B); // Deep crimson space
        dimensionShift = true;
        _currentDimension = "crimson";

        // Provide audio feedback
        _speakResponse("Crimson dimension shift complete. Welcome to the fiery nebula.");
      }

      // Update status message based on whether a dimension shift was detected
      if (dimensionShift) {
        _statusMessage = 'Dimensional shift detected! Tap portal to continue exploration.';
      } else if (result.finalResult) {
        _statusMessage = 'No dimensional keyword detected. Try "Azure" or "Crimson".';
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
        _statusMessage = 'Voice synthesis error: $e';
      });
    }
  }

  // Toggle listening state when portal is tapped
  void _toggleListening() {
    if (_isSpeaking) {
      // If currently speaking, stop the speech
      _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
        _statusMessage = 'Voice synthesis halted. Tap portal to activate voice gateway.';
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
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build the UI
    return Scaffold(
      // Background color changes based on voice commands
      backgroundColor: _backgroundColor,
      // No app bar for more immersive experience
      body: Stack(
        children: [
          // Animated star background
          CustomPaint(
            painter: StarPainter(_stars, _animationController),
            size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
          ),
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // App title with cosmic theme
                Text(
                  'COSMIC VOICE',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3.0,
                    color: _currentDimension == "azure"
                        ? Colors.lightBlue[200]
                        : (_currentDimension == "crimson" ? Colors.red[300] : Colors.white),
                    shadows: [
                      Shadow(
                        color: _currentDimension == "azure"
                            ? Colors.blue
                            : (_currentDimension == "crimson" ? Colors.red : Colors.teal),
                        offset: Offset(0, 0),
                        blurRadius: 15,
                      )
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Instructions for the user with cosmic theme
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    'Speak "AZURE" or "CRIMSON"\nto shift dimensional planes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1.5,
                      color: Colors.grey[300],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: 60),

                // Interactive portal for voice activation
                GestureDetector(
                  onTap: _speechEnabled ? _toggleListening : null,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 500),
                    width: _isListening ? 160 : 130,
                    height: _isListening ? 160 : 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: _isListening
                            ? [Colors.teal[400]!, Colors.blue[900]!]
                            : (_isSpeaking
                            ? [Colors.amber[400]!, Colors.deepOrange[900]!]
                            : [Colors.purple[400]!, Colors.indigo[900]!]),
                        stops: [0.2, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isListening
                              ? Colors.teal.withOpacity(0.6)
                              : (_isSpeaking
                              ? Colors.amber.withOpacity(0.6)
                              : Colors.purple.withOpacity(0.6)),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        child: _isListening
                            ? Icon(Icons.mic, color: Colors.white, size: 70)
                            : (_isSpeaking
                            ? Icon(Icons.volume_up, color: Colors.white, size: 60)
                            : Icon(Icons.touch_app, color: Colors.white, size: 60)),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 40),

                // Status message with cosmic theme
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  margin: EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isListening
                          ? Colors.teal.withOpacity(0.6)
                          : (_isSpeaking
                          ? Colors.amber.withOpacity(0.6)
                          : Colors.purple.withOpacity(0.6)),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[300],
                      fontWeight: FontWeight.w300,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Display recognized words if available
                if (_lastWords.isNotEmpty) ...[
                  SizedBox(height: 40),
                  Container(
                    padding: EdgeInsets.all(16),
                    margin: EdgeInsets.symmetric(horizontal: 30),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _currentDimension == "azure"
                            ? Colors.blue.withOpacity(0.6)
                            : (_currentDimension == "crimson"
                            ? Colors.red.withOpacity(0.6)
                            : Colors.white24),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'TRANSMISSION RECEIVED:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '"$_lastWords"',
                          style: TextStyle(
                            fontSize: 18,
                            color: _currentDimension == "azure"
                                ? Colors.lightBlue[200]
                                : (_currentDimension == "crimson"
                                ? Colors.red[300]
                                : Colors.white),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],

                // Dimension indicator
                SizedBox(height: 40),
                Text(
                  'CURRENT DIMENSION: ${_currentDimension.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 2,
                    color: _currentDimension == "azure"
                        ? Colors.lightBlue[200]
                        : (_currentDimension == "crimson"
                        ? Colors.red[300]
                        : Colors.grey[400]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Star class for background animation
class Star {
  final double x;
  final double y;
  final double size;
  final double opacity;

  Star({required this.x, required this.y, required this.size, required this.opacity});
}

// Star background painter
class StarPainter extends CustomPainter {
  final List<Star> stars;
  final AnimationController animation;

  StarPainter(this.stars, this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (var star in stars) {
      // Calculate twinkling effect
      final twinkle = 0.4 + 0.6 * math.sin((animation.value * 2 * math.pi) + star.x * 10);

      // Set star color and opacity
      paint.color = Colors.white.withOpacity(star.opacity * twinkle);

      // Draw the star
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}