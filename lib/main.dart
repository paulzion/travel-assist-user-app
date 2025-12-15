import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'firebase_options.dart';

// ==========================================
// 1. CONFIGURATION & THEME
// ==========================================
const Color kPrimaryColor = Colors.indigo;
const Color kScaffoldBg = Color(0xFFF8F9FA);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runZonedGuarded(
    () => runApp(const UserApp()),
    (error, stack) => debugPrint("CRASH CAUGHT: $error"),
  );
}

class UserApp extends StatelessWidget {
  const UserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel Assist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: kScaffoldBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      home: const AuthGatekeeper(),
    );
  }
}

// ==========================================
// 2. AUTH GATEKEEPER
// ==========================================
class AuthGatekeeper extends StatelessWidget {
  const AuthGatekeeper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.hasData
            ? const DashboardScreen()
            : const LoginSignUpScreen();
      },
    );
  }
}

// ==========================================
// 3. LOGIN / SIGNUP
// ==========================================
class LoginSignUpScreen extends StatefulWidget {
  const LoginSignUpScreen({super.key});
  @override
  State<LoginSignUpScreen> createState() => _LoginSignUpScreenState();
}

class _LoginSignUpScreenState extends State<LoginSignUpScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _gender = "Male";
  bool _isLogin = true;
  bool _isLoading = false;

  void _submit() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email and Password are required")),
      );
      return;
    }

    if (!_isLogin) {
      if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All fields are required")),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
      } else {
        UserCredential userCred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailCtrl.text.trim(),
              password: _passCtrl.text.trim(),
            );

        await userCred.user!.updateDisplayName(_nameCtrl.text.trim());

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCred.user!.uid)
            .set({
              'name': _nameCtrl.text.trim(),
              'phone': _phoneCtrl.text.trim(),
              'email': _emailCtrl.text.trim(),
              'gender': _gender,
              'createdAt': FieldValue.serverTimestamp(),
              'role': 'user',
            });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.luggage, size: 80, color: kPrimaryColor),
              const SizedBox(height: 20),
              Text(
                _isLogin ? "Welcome Back" : "Create Account",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor,
                ),
              ),
              const SizedBox(height: 30),

              if (!_isLogin) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Phone Number",
                    prefixIcon: Icon(Icons.phone),
                    hintText: "For Partner contact",
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Gender (For Safety Matching)",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile(
                              title: const Text("Male"),
                              value: "Male",
                              groupValue: _gender,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) =>
                                  setState(() => _gender = val.toString()),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile(
                              title: const Text("Female"),
                              value: "Female",
                              groupValue: _gender,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) =>
                                  setState(() => _gender = val.toString()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isLogin ? "LOGIN" : "SIGN UP"),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin
                      ? "New user? Create Account"
                      : "Already have an account? Login",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. DASHBOARD (The Menu)
// ==========================================
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? "Guest";
    final userName = user?.displayName ?? "Traveler";
    final String initial = userEmail.isNotEmpty
        ? userEmail[0].toUpperCase()
        : "T";

    return Scaffold(
      appBar: AppBar(title: const Text("Travel Assist")),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: kPrimaryColor),
              accountName: Text(
                userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              accountEmail: Text(userEmail),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 30,
                    color: kPrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text("My Profile"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("My Bookings"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BookingHistoryScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: () async => await FirebaseAuth.instance.signOut(),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "How can we assist you?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _card(
                  "Train Porter",
                  Icons.train,
                  Colors.blue,
                  context,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TrainBookingScreen(),
                    ),
                  ),
                ),
                _card(
                  "Long Bus",
                  Icons.directions_bus,
                  Colors.orange,
                  context,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LongBusBookingScreen(),
                    ),
                  ),
                ),
                _card(
                  "Metro / Bus",
                  Icons.directions_transit,
                  Colors.purple,
                  context,
                  () {
                    showDialog(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: const Text("Select Transport Type"),
                        children: [
                          SimpleDialogOption(
                            padding: const EdgeInsets.all(20),
                            child: const Row(
                              children: [
                                Icon(Icons.subway, color: Colors.purple),
                                SizedBox(width: 10),
                                Text("Metro / Local / MRTS"),
                              ],
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const MetroMrtsBookingScreen(),
                                ),
                              );
                            },
                          ),
                          SimpleDialogOption(
                            padding: const EdgeInsets.all(20),
                            child: const Row(
                              children: [
                                Icon(Icons.directions_bus, color: Colors.red),
                                SizedBox(width: 10),
                                Text("MTC City Bus"),
                              ],
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MtcBookingScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                _card(
                  "Butler / Driver",
                  Icons.person_pin_circle,
                  Colors.black87,
                  context,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PersonalAssistantScreen(),
                    ),
                  ),
                ),
                _card(
                  "City Guide",
                  Icons.camera_alt,
                  Colors.teal,
                  context,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TouristGuideScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        child: const Icon(Icons.sos, color: Colors.white),
        onPressed: () => launchUrl(Uri(scheme: 'tel', path: '100')),
      ),
    );
  }

  Widget _card(
    String title,
    IconData icon,
    Color color,
    BuildContext context,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. TRAIN BOOKING (Fixed Self Data & Coords)
// ==========================================
class TrainBookingScreen extends StatefulWidget {
  const TrainBookingScreen({super.key});
  @override
  State<TrainBookingScreen> createState() => _TrainBookingScreenState();
}

class _TrainBookingScreenState extends State<TrainBookingScreen> {
  final _pnrCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _foodDetailsCtrl = TextEditingController();
  final _foodBudgetCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _guestNameCtrl = TextEditingController();
  final _guestPhoneCtrl = TextEditingController();

  bool _isGoingToStation = true;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _isUnreserved = false;
  String _generalCoachPos = "Front General";

  String _selectedStation = "Chennai Central";
  final Map<String, LatLng> _stations = {
    "Chennai Central": LatLng(13.0827, 80.2707),
    "Chennai Egmore": LatLng(13.0732, 80.2609),
    "Tambaram": LatLng(12.9249, 80.1000),
    "Perambur": LatLng(13.1084, 80.2483),
  };

  String _assistType = "Half";
  bool _luggageEscort = false;
  bool _sitInsideCab = false;
  bool _preferFemale = false;
  bool _needWheelchair = false;
  bool _isBookingForSelf = true;
  bool _wantsFood = false;

  int _partnerCount = 1;
  int _passengerCount = 1;
  int _bagCount = 2;
  int _kitCount = 0;
  int _waterCount = 0;
  int _padCount = 0;
  int _babyDiaperCount = 0;
  int _adultDiaperCount = 0;

  bool _isLoading = false;
  double? _selectedLat;
  double? _selectedLng;

  // 🟢 FIX: PROFILE DATA
  String _userGender = "Male";
  String _userName = "User";
  String _userPhone = "";
  String _guestGender = "Female";
  bool _hasFemaleCompanion = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _userGender = doc.data()?['gender'] ?? "Male";
          _userName = doc.data()?['name'] ?? "User";
          _userPhone = doc.data()?['phone'] ?? "";
        });
      }
    }
  }

  bool _canRequestFemalePartner() {
    bool isNight = _selectedTime.hour >= 20 || _selectedTime.hour < 6;
    String passengerGender = _isBookingForSelf ? _userGender : _guestGender;
    bool isFemalePassenger = passengerGender.toLowerCase() == "female";
    if (!isNight) return isFemalePassenger || _hasFemaleCompanion;
    return isFemalePassenger || _hasFemaleCompanion;
  }

  void _updatePassengerCount(int newCount) {
    if (newCount < 1) return;
    setState(() {
      _passengerCount = newCount;
      int minPartners = (_passengerCount / 5).ceil();
      if (_partnerCount < minPartners) _partnerCount = minPartners;
    });
  }

  void _updatePartnerCount(int newCount) {
    int minPartners = (_passengerCount / 5).ceil();
    if (newCount < minPartners) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Safety Rule: Need at least $minPartners partner(s)."),
        ),
      );
      return;
    }
    setState(() => _partnerCount = newCount);
  }

  Future<void> _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (pickedTime == null) return;
    setState(() {
      _selectedDate = pickedDate;
      _selectedTime = pickedTime;
    });
  }

  Future<void> _openMapPicker() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const OsmMapPicker()),
    );
    if (result != null) {
      setState(() {
        _selectedLat = result.latitude;
        _selectedLng = result.longitude;
        _addrCtrl.text =
            "Lat: ${result.latitude.toStringAsFixed(4)}, Lng: ${result.longitude.toStringAsFixed(4)}";
      });
    }
  }

  Future<void> _launchSwiggy() async {
    final Uri url = Uri.parse("https://www.swiggy.com");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch Swiggy")),
        );
    }
  }

  int _calculateFairPrice() {
    int singlePartnerCost = 0;
    if (_assistType == 'Half') {
      singlePartnerCost = 350;
    } else {
      if (_selectedLat == null || _selectedLng == null) {
        singlePartnerCost = 850;
      } else {
        LatLng dest = _stations[_selectedStation]!;
        double distKm =
            Geolocator.distanceBetween(
              _selectedLat!,
              _selectedLng!,
              dest.latitude,
              dest.longitude,
            ) /
            1000;
        singlePartnerCost = 300 + (distKm * 25).round();
      }
    }
    if (_isUnreserved && _assistType == 'Full') singlePartnerCost += 50;
    if (singlePartnerCost < 500 && _assistType == 'Full')
      singlePartnerCost = 500;

    int totalBase = singlePartnerCost * _partnerCount;
    if (_bagCount > (3 * _partnerCount))
      totalBase += (_bagCount - (3 * _partnerCount)) * 80;

    totalBase += (_kitCount * 150);
    totalBase += (_waterCount * 20);
    totalBase += (_padCount * 100);
    totalBase += (_babyDiaperCount * 200);
    totalBase += (_adultDiaperCount * 300);
    return totalBase;
  }

  // 🟢 FIXED: ADDRESS SWAP & REAL DATA
  void _book() async {
    if (!_isUnreserved && _pnrCtrl.text.length != 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid PNR (10 digits required)")),
      );
      return;
    }
    if (_assistType == 'Full' && _addrCtrl.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select Address")));
      return;
    }

    // 2. Fetch Profile Data (Silent Sender Fix)
    String currentUserName = "Guest";
    String currentUserPhone = "";
    String currentUserGender = "Male";

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        currentUserName = doc.data()?['name'] ?? "Guest";
        currentUserPhone = doc.data()?['phone'] ?? "";
        currentUserGender = doc.data()?['gender'] ?? "Male";
      }
    }

    if (_isBookingForSelf && currentUserPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please update your Phone Number in Profile!"),
        ),
      );
      return;
    }
    if (!_isBookingForSelf &&
        (_guestNameCtrl.text.isEmpty || _guestPhoneCtrl.text.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter Passenger Contact Details")),
      );
      return;
    }

    setState(() => _isLoading = true);
    int cost = _calculateFairPrice();
    String finalTravelMode = 'Standard';
    if (_luggageEscort) finalTravelMode = 'Luggage_Bike_Follows';
    if (_sitInsideCab) finalTravelMode = 'In_Cab_Companion';

    final DateTime scheduleTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // 🟢 2. DETERMINE ADDRESSES & COORDINATES
    String finalPickupAddr;
    String finalDropAddr;
    double? finalPickupLat;
    double? finalPickupLng;
    double? finalDropLat;
    double? finalDropLng;

    // Get Station Coordinates
    LatLng stationCoords =
        _stations[_selectedStation] ?? const LatLng(13.0827, 80.2707);

    if (_isGoingToStation) {
      // 🏠 HOME -> 🚆 STATION
      finalPickupAddr = _assistType == 'Full'
          ? _addrCtrl.text
          : "My Current Location";
      finalDropAddr = "$_selectedStation (Railway Stn)";
      finalPickupLat = _selectedLat;
      finalPickupLng = _selectedLng;
      finalDropLat = stationCoords.latitude;
      finalDropLng = stationCoords.longitude;
    } else {
      // 🚆 STATION -> 🏠 HOME
      finalPickupAddr = "$_selectedStation (Railway Stn)";
      finalDropAddr = _assistType == 'Full' ? _addrCtrl.text : "My Destination";
      finalPickupLat = stationCoords.latitude;
      finalPickupLng = stationCoords.longitude;
      finalDropLat = _selectedLat;
      finalDropLng = _selectedLng;
    }

    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'userId': user!.uid,
        'service': 'Train',
        'ticket_type': _isUnreserved ? "Unreserved" : "Reserved",
        'pnr': _isUnreserved ? "N/A" : _pnrCtrl.text,
        'general_coach_pos': _isUnreserved ? _generalCoachPos : "N/A",
        'partners_required': _partnerCount,
        'passenger_count': _passengerCount,
        'trip_direction': _isGoingToStation ? "To Station" : "From Station",
        'scheduled_time': scheduleTime,
        'type': _assistType,
        'station': _selectedStation,
        'travel_mode': finalTravelMode,
        'need_wheelchair': _needWheelchair,
        'bags': _bagCount,
        'booking_for_self': _isBookingForSelf,
        'guest_name': _isBookingForSelf ? currentUserName : _guestNameCtrl.text,
        'guest_phone': _isBookingForSelf
            ? currentUserPhone
            : _guestPhoneCtrl.text,
        'guest_gender': _isBookingForSelf ? currentUserGender : _guestGender,
        'has_female_companion': _hasFemaleCompanion,
        'prefer_female_partner': _canRequestFemalePartner()
            ? _preferFemale
            : false,
        'notes': _noteCtrl.text,
        'address_pickup': finalPickupAddr,
        'address_drop': finalDropAddr,
        'pickup_lat': finalPickupLat,
        'pickup_lng': finalPickupLng,
        'drop_lat': finalDropLat,
        'drop_lng': finalDropLng,
        'pantry': {
          'has_food': _wantsFood,
          'food_note': _wantsFood ? _foodDetailsCtrl.text : "No Food Needed",
          'food_budget': _wantsFood ? _foodBudgetCtrl.text : "0",
          'qty_water': _waterCount,
          'qty_kit': _kitCount,
          'qty_pads': _padCount,
          'qty_baby_diapers': _babyDiaperCount,
          'qty_adult_diapers': _adultDiaperCount,
        },
        'status': 'pending',
        'cost': cost,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Train Booking Sent!")));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCounterRow(
    String label,
    String price,
    int count,
    VoidCallback onRemove,
    VoidCallback onAdd,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              if (price.isNotEmpty)
                Text(
                  price,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed:
                      count >
                          (label.contains("Porters") ||
                                  label.contains("Passengers")
                              ? 1
                              : 0)
                      ? onRemove
                      : null,
                  color: Colors.red,
                ),
                Text(
                  "$count",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: onAdd,
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showFemalePref = _canRequestFemalePartner();
    bool isSoloMale = !_canRequestFemalePartner();

    return Scaffold(
      appBar: AppBar(title: const Text("Book Train Porter")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isGoingToStation = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isGoingToStation
                            ? kPrimaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          "To Station",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isGoingToStation
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isGoingToStation = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isGoingToStation
                            ? kPrimaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          "From Station",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_isGoingToStation
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: kPrimaryColor),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Schedule Date & Time",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        "${DateFormat('EEE, dd MMM').format(_selectedDate)} at ${_selectedTime.format(context)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    "Change",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.groups, color: Colors.indigo),
                    SizedBox(width: 10),
                    Text(
                      "Group / Bulk Booking",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                _buildCounterRow(
                  "Total Passengers",
                  "1 Partner per 5 people",
                  _passengerCount,
                  () => _updatePassengerCount(_passengerCount - 1),
                  () => _updatePassengerCount(_passengerCount + 1),
                ),
                const SizedBox(height: 5),
                _buildCounterRow(
                  "Porters Required",
                  "Multiplies total cost",
                  _partnerCount,
                  () => _updatePartnerCount(_partnerCount - 1),
                  () => _updatePartnerCount(_partnerCount + 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            color: _isUnreserved ? Colors.orange.shade50 : Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _isUnreserved ? Colors.orange : Colors.blue,
              ),
            ),
            child: SwitchListTile(
              title: Text(
                _isUnreserved
                    ? "Unreserved (General Coach)"
                    : "Reserved (Confirmed/RAC)",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _isUnreserved
                    ? "Porter will load bags at General Coach Door"
                    : "Porter will guide to exact Seat",
              ),
              value: _isUnreserved,
              activeColor: Colors.orange,
              secondary: Icon(
                _isUnreserved ? Icons.groups_3 : Icons.confirmation_number,
                color: _isUnreserved ? Colors.orange : Colors.blue,
              ),
              onChanged: (val) => setState(() => _isUnreserved = val),
            ),
          ),
          const SizedBox(height: 15),
          if (_isUnreserved) ...[
            DropdownButtonFormField<String>(
              value: _generalCoachPos,
              decoration: const InputDecoration(
                labelText: "Preferred General Coach",
                prefixIcon: Icon(Icons.train),
                border: OutlineInputBorder(),
              ),
              items: [
                "Front General",
                "Rear General",
                "Ladies General",
                "Any / Don't Know",
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _generalCoachPos = val!),
            ),
            const SizedBox(height: 10),
            const Text(
              "⚠️ Note: Partner cannot enter the Unreserved compartment due to overcrowding. Service is limited to loading luggage at the coach entrance.",
              style: TextStyle(
                color: Colors.deepOrange,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else ...[
            TextField(
              controller: _pnrCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                LengthLimitingTextInputFormatter(10),
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: "10-digit PNR",
                prefixIcon: Icon(Icons.confirmation_number),
              ),
            ),
          ],
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _selectedStation,
            decoration: const InputDecoration(
              labelText: "Station",
              prefixIcon: Icon(Icons.train),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _stations.keys
                .map(
                  (String station) => DropdownMenuItem(
                    value: station,
                    child: Text(station, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedStation = val!),
          ),
          const SizedBox(height: 20),
          _buildCounterRow(
            "Luggage Count",
            "3 bags free per partner",
            _bagCount,
            () => setState(() {
              if (_bagCount > 1) _bagCount--;
            }),
            () => setState(() => _bagCount++),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                RadioListTile(
                  title: const Text("Full Assistance"),
                  subtitle: Text(
                    _isUnreserved
                        ? "Pickup Home -> Drop at Coach Door"
                        : (_isGoingToStation
                              ? "Pickup Home -> Drop at Seat"
                              : "Meet at Coach -> Drop Home"),
                  ),
                  value: "Full",
                  groupValue: _assistType,
                  onChanged: (v) => setState(() => _assistType = v.toString()),
                ),
                RadioListTile(
                  title: const Text("Station Only"),
                  subtitle: const Text("Entrance <-> Platform"),
                  value: "Half",
                  groupValue: _assistType,
                  onChanged: (v) => setState(() => _assistType = v.toString()),
                ),
              ],
            ),
          ),
          if (_assistType == "Full") ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Note: Partner enters the coach ONLY if this is the Source Station. For intermediate stops, assistance is provided at the carriage door only.",
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addrCtrl,
                    readOnly: false,
                    decoration: InputDecoration(
                      labelText: _isGoingToStation
                          ? "Pickup Address (Home)"
                          : "Drop Address (Home)",
                      prefixIcon: const Icon(Icons.home),
                      hintText: "Use Map or Type ->",
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _openMapPicker,
                  backgroundColor: kPrimaryColor,
                  child: const Icon(Icons.map, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (showFemalePref)
              SwitchListTile(
                title: const Text("Prefer Female Partner"),
                subtitle: const Text("Prioritizes female partners."),
                value: _preferFemale,
                activeColor: Colors.pink,
                secondary: const Icon(Icons.face_3, color: Colors.pink),
                onChanged: (val) => setState(() => _preferFemale = val),
              ),
            if (isSoloMale)
              CheckboxListTile(
                title: const Text("Travelling with Female Companion?"),
                subtitle: const Text("Allows Female Partner Booking."),
                value: _hasFemaleCompanion,
                activeColor: Colors.pink,
                onChanged: (val) => setState(() => _hasFemaleCompanion = val!),
              ),
            SwitchListTile(
              title: const Text("Luggage Escort"),
              subtitle: const Text("Partner follows cab on bike."),
              value: _luggageEscort,
              activeColor: Colors.deepOrange,
              onChanged: (val) => setState(() {
                _luggageEscort = val;
                if (val) _sitInsideCab = false;
              }),
            ),
            SwitchListTile(
              title: const Text("In-Cab Companion"),
              subtitle: const Text("Partner sits inside cab."),
              value: _sitInsideCab,
              activeColor: Colors.blue,
              onChanged: (val) => setState(() {
                _sitInsideCab = val;
                if (val) _luggageEscort = false;
              }),
            ),
            SwitchListTile(
              title: const Text("Need Wheelchair?"),
              subtitle: const Text("At Station (Subject to availability)"),
              value: _needWheelchair,
              activeColor: Colors.purple,
              secondary: const Icon(Icons.accessible, color: Colors.purple),
              onChanged: (val) => setState(() => _needWheelchair = val),
            ),
          ],
          const Divider(height: 30),
          const Text(
            "Essentials & Add-ons",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          _buildCounterRow(
            "Travel Kit",
            "₹150 each",
            _kitCount,
            () => setState(() => _kitCount--),
            () => setState(() => _kitCount++),
          ),
          _buildCounterRow(
            "Water Bottle (1L)",
            "₹20 / bottle",
            _waterCount,
            () => setState(() => _waterCount--),
            () => setState(() => _waterCount++),
          ),
          ExpansionTile(
            title: const Text("Hygiene & Care (Sanitary)"),
            leading: const Icon(
              Icons.medical_services_outlined,
              color: Colors.pink,
            ),
            children: [
              _buildCounterRow(
                "Sanitary Pads",
                "Approx ₹100",
                _padCount,
                () => setState(() => _padCount--),
                () => setState(() => _padCount++),
              ),
              _buildCounterRow(
                "Baby Diapers",
                "Approx ₹200",
                _babyDiaperCount,
                () => setState(() => _babyDiaperCount--),
                () => setState(() => _babyDiaperCount++),
              ),
              _buildCounterRow(
                "Adult Diapers",
                "Approx ₹300",
                _adultDiaperCount,
                () => setState(() => _adultDiaperCount--),
                () => setState(() => _adultDiaperCount++),
              ),
            ],
          ),
          CheckboxListTile(
            title: const Text("Partner buys Food"),
            value: _wantsFood,
            onChanged: (val) => setState(() => _wantsFood = val!),
          ),
          if (_wantsFood) ...[
            TextField(
              controller: _foodDetailsCtrl,
              decoration: const InputDecoration(labelText: "Food Details"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _foodBudgetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Max Budget (₹)",
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _launchSwiggy,
                child: const Text("Check Swiggy Menu"),
              ),
            ),
          ],
          const Divider(height: 30),
          const Text(
            "Contact Details",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SwitchListTile(
            title: const Text("I am the Passenger"),
            value: _isBookingForSelf,
            onChanged: (val) => setState(() => _isBookingForSelf = val),
          ),
          if (!_isBookingForSelf) ...[
            TextField(
              controller: _guestNameCtrl,
              decoration: const InputDecoration(
                labelText: "Passenger Name",
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _guestPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Passenger Phone",
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _guestGender,
              decoration: const InputDecoration(
                labelText: "Passenger Gender",
                prefixIcon: Icon(Icons.wc),
                border: OutlineInputBorder(),
              ),
              items: [
                "Male",
                "Female",
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _guestGender = val!),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Note to Partner (Optional)",
              hintText: "e.g. Meet at Platform 4",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              "Payment Mode: Cash / UPI to Partner after service",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _book,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("CONFIRM BOOKING"),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 6. LONG BUS BOOKING (Fixed Self Data & Coords)
// ==========================================
class LongBusBookingScreen extends StatefulWidget {
  const LongBusBookingScreen({super.key});
  @override
  State<LongBusBookingScreen> createState() => _LongBusBookingScreenState();
}

class _LongBusBookingScreenState extends State<LongBusBookingScreen> {
  final _operatorCtrl = TextEditingController();
  final _ticketIdCtrl = TextEditingController();
  final _busNumberCtrl = TextEditingController();
  final _foodDetailsCtrl = TextEditingController();
  final _foodBudgetCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _guestNameCtrl = TextEditingController();
  final _guestPhoneCtrl = TextEditingController();
  final _homeAddrCtrl = TextEditingController();
  final _busStandAddrCtrl = TextEditingController();

  double? _homeLat, _homeLng;
  double? _busStandLat, _busStandLng;
  bool _isGoingToStand = true;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _assistType = "Full";
  bool _luggageEscort = false;
  bool _sitInsideCab = false;
  bool _preferFemale = false;
  bool _isBookingForSelf = true;
  bool _wantsFood = false;
  int _partnerCount = 1;
  int _passengerCount = 1;
  int _bagCount = 2;
  int _kitCount = 0;
  int _waterCount = 0;
  int _padCount = 0;
  int _babyDiaperCount = 0;
  int _adultDiaperCount = 0;
  bool _isLoading = false;

  // 🟢 FIX: PROFILE DATA
  String _userGender = "Male";
  String _userName = "User";
  String _userPhone = "";
  String _guestGender = "Female";
  bool _hasFemaleCompanion = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _userGender = doc.data()?['gender'] ?? "Male";
          _userName = doc.data()?['name'] ?? "User";
          _userPhone = doc.data()?['phone'] ?? "";
        });
      }
    }
  }

  bool _canRequestFemalePartner() {
    bool isNight = _selectedTime.hour >= 20 || _selectedTime.hour < 6;
    String passengerGender = _isBookingForSelf ? _userGender : _guestGender;
    bool isFemalePassenger = passengerGender.toLowerCase() == "female";
    if (!isNight) return isFemalePassenger || _hasFemaleCompanion;
    return isFemalePassenger || _hasFemaleCompanion;
  }

  void _updatePassengerCount(int newCount) {
    if (newCount < 1) return;
    setState(() {
      _passengerCount = newCount;
      int minPartners = (_passengerCount / 5).ceil();
      if (_partnerCount < minPartners) _partnerCount = minPartners;
    });
  }

  void _updatePartnerCount(int newCount) {
    int minPartners = (_passengerCount / 5).ceil();
    if (newCount < minPartners) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Safety Rule: Need at least $minPartners partner(s)."),
        ),
      );
      return;
    }
    setState(() => _partnerCount = newCount);
  }

  Future<void> _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (pickedTime == null) return;
    setState(() {
      _selectedDate = pickedDate;
      _selectedTime = pickedTime;
    });
  }

  Future<void> _pickLocation(bool isHome) async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const OsmMapPicker()),
    );
    if (result != null) {
      setState(() {
        String locStr =
            "Lat: ${result.latitude.toStringAsFixed(4)}, Lng: ${result.longitude.toStringAsFixed(4)}";
        if (isHome) {
          _homeLat = result.latitude;
          _homeLng = result.longitude;
          _homeAddrCtrl.text = locStr;
        } else {
          _busStandLat = result.latitude;
          _busStandLng = result.longitude;
          _busStandAddrCtrl.text = locStr;
        }
      });
    }
  }

  Future<void> _launchSwiggy() async {
    final Uri url = Uri.parse("https://www.swiggy.com");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch Swiggy")),
        );
    }
  }

  int _calculatePrice() {
    int singlePartnerCost = 0;
    if (_assistType == 'Half') {
      singlePartnerCost = 350;
    } else {
      if (_homeLat == null || _busStandLat == null) {
        singlePartnerCost = 600;
      } else {
        double distKm =
            Geolocator.distanceBetween(
              _homeLat!,
              _homeLng!,
              _busStandLat!,
              _busStandLng!,
            ) /
            1000;
        singlePartnerCost = 250 + (distKm * 25).round();
      }
    }
    if (singlePartnerCost < 500 && _assistType == 'Full')
      singlePartnerCost = 500;
    int totalBase = singlePartnerCost * _partnerCount;
    if (_bagCount > (3 * _partnerCount))
      totalBase += (_bagCount - (3 * _partnerCount)) * 80;
    totalBase += (_kitCount * 150);
    totalBase += (_waterCount * 20);
    totalBase += (_padCount * 100);
    totalBase += (_babyDiaperCount * 200);
    totalBase += (_adultDiaperCount * 300);
    return totalBase;
  }

  // 🟢 FIXED: BUS BOOKING LOGIC
  void _book() async {
    if (_operatorCtrl.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter Bus Operator Name")));
      return;
    }
    if (_assistType == 'Full' &&
        (_homeAddrCtrl.text.isEmpty || _busStandAddrCtrl.text.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select Both Locations")));
      return;
    }
    // 🟢 FIX: Validate Self Phone
    if (_isBookingForSelf && _userPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please update Phone in Profile!")),
      );
      return;
    }
    if (!_isBookingForSelf &&
        (_guestNameCtrl.text.isEmpty || _guestPhoneCtrl.text.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter Passenger Contact Details")),
      );
      return;
    }

    setState(() => _isLoading = true);
    int cost = _calculatePrice();
    String finalTravelMode = 'Standard';
    if (_luggageEscort) finalTravelMode = 'Luggage_Bike_Follows';
    if (_sitInsideCab) finalTravelMode = 'In_Cab_Companion';
    final DateTime scheduleTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // 🟢 2. DETERMINE ADDRESSES & COORDINATES FOR BUS
    String finalPickupAddr;
    String finalDropAddr;
    double? finalPickupLat;
    double? finalPickupLng;
    double? finalDropLat;
    double? finalDropLng;

    if (_isGoingToStand) {
      // 🏠 HOME -> 🚌 BUS STAND
      finalPickupAddr = _assistType == 'Full'
          ? _homeAddrCtrl.text
          : "My Current Location";
      finalDropAddr = _busStandAddrCtrl.text.isEmpty
          ? "Bus Stand"
          : _busStandAddrCtrl.text;

      finalPickupLat = _homeLat;
      finalPickupLng = _homeLng;
      finalDropLat = _busStandLat;
      finalDropLng = _busStandLng;
    } else {
      // 🚌 BUS STAND -> 🏠 HOME
      finalPickupAddr = _busStandAddrCtrl.text.isEmpty
          ? "Bus Stand"
          : _busStandAddrCtrl.text;
      finalDropAddr = _assistType == 'Full'
          ? _homeAddrCtrl.text
          : "My Destination";

      finalPickupLat = _busStandLat;
      finalPickupLng = _busStandLng;
      finalDropLat = _homeLat;
      finalDropLng = _homeLng;
    }

    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'service': 'Long Bus',
        'operator_name': _operatorCtrl.text,
        'ticket_id': _ticketIdCtrl.text,
        'bus_number': _busNumberCtrl.text.isEmpty
            ? "Pending"
            : _busNumberCtrl.text,
        'partners_required': _partnerCount,
        'passenger_count': _passengerCount,
        'bags': _bagCount,
        'trip_direction': _isGoingToStand ? "To Bus Point" : "From Bus Point",
        'scheduled_time': scheduleTime,
        'type': _assistType,
        'travel_mode': finalTravelMode,
        'booking_for_self': _isBookingForSelf,
        // 🟢 FIX: SEND REAL NAME/PHONE
        'guest_name': _isBookingForSelf ? _userName : _guestNameCtrl.text,
        'guest_phone': _isBookingForSelf ? _userPhone : _guestPhoneCtrl.text,
        'guest_gender': _isBookingForSelf ? _userGender : _guestGender,
        'has_female_companion': _hasFemaleCompanion,
        'prefer_female_partner': _canRequestFemalePartner()
            ? _preferFemale
            : false,
        'address_pickup': finalPickupAddr,
        'address_drop': finalDropAddr,
        'pickup_lat': finalPickupLat, 'pickup_lng': finalPickupLng,
        'drop_lat': finalDropLat, 'drop_lng': finalDropLng,
        'pantry': {
          'has_food': _wantsFood,
          'food_note': _wantsFood ? _foodDetailsCtrl.text : "No Food Needed",
          'food_budget': _wantsFood ? _foodBudgetCtrl.text : "0",
          'qty_water': _waterCount,
          'qty_kit': _kitCount,
          'qty_pads': _padCount,
          'qty_baby_diapers': _babyDiaperCount,
          'qty_adult_diapers': _adultDiaperCount,
        },
        'notes': _noteCtrl.text,
        'status': 'pending',
        'cost': cost,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Booking Confirmed!"),
            content: Text("Operator: ${_operatorCtrl.text}\nEst. Pay: ₹$cost"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCounterRow(
    String label,
    String price,
    int count,
    VoidCallback onRemove,
    VoidCallback onAdd,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              if (price.isNotEmpty)
                Text(
                  price,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed:
                      count >
                          (label.contains("Porters") ||
                                  label.contains("Passengers")
                              ? 1
                              : 0)
                      ? onRemove
                      : null,
                  color: Colors.red,
                ),
                Text(
                  "$count",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: onAdd,
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showFemalePref = _canRequestFemalePartner();
    bool isSoloMale = !_canRequestFemalePartner();

    return Scaffold(
      appBar: AppBar(title: const Text("Book Bus Porter")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isGoingToStand = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isGoingToStand
                            ? Colors.orange
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          "To Bus Point",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isGoingToStand
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isGoingToStand = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isGoingToStand
                            ? Colors.orange
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          "From Bus Point",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_isGoingToStand
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.orange),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Bus Schedule",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        "${DateFormat('EEE, dd MMM').format(_selectedDate)} at ${_selectedTime.format(context)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    "Change",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.groups, color: Colors.indigo),
                    SizedBox(width: 10),
                    Text(
                      "Group / Bulk Booking",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                _buildCounterRow(
                  "Total Passengers",
                  "1 Partner per 5 people",
                  _passengerCount,
                  () => _updatePassengerCount(_passengerCount - 1),
                  () => _updatePassengerCount(_passengerCount + 1),
                ),
                const SizedBox(height: 5),
                _buildCounterRow(
                  "Porters Required",
                  "Multiplies total cost",
                  _partnerCount,
                  () => _updatePartnerCount(_partnerCount - 1),
                  () => _updatePartnerCount(_partnerCount + 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _operatorCtrl,
            decoration: const InputDecoration(
              labelText: "Bus Operator",
              hintText: "e.g. SRM, Parveen",
              prefixIcon: Icon(Icons.directions_bus),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ticketIdCtrl,
            decoration: const InputDecoration(
              labelText: "Booking ID (Optional)",
              hintText: "e.g. RedBus Ticket ID",
              prefixIcon: Icon(Icons.receipt),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _busNumberCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: "Bus Number (If known)",
              hintText: "Enter if you have SMS",
              prefixIcon: Icon(Icons.confirmation_number),
            ),
          ),
          const SizedBox(height: 20),
          _buildCounterRow(
            "Luggage Count",
            "3 bags free per partner",
            _bagCount,
            () => setState(() {
              if (_bagCount > 1) _bagCount--;
            }),
            () => setState(() => _bagCount++),
          ),
          const SizedBox(height: 10),
          if (_assistType == "Full") ...[
            TextField(
              controller: _homeAddrCtrl,
              readOnly: false,
              decoration: InputDecoration(
                labelText: _isGoingToStand ? "Pickup (Home)" : "Drop (Home)",
                prefixIcon: const Icon(Icons.home),
                hintText: "Use Map ->",
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _pickLocation(true),
                icon: const Icon(Icons.map),
                label: const Text("Pick Home"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _busStandAddrCtrl,
              readOnly: false,
              decoration: InputDecoration(
                labelText: _isGoingToStand
                    ? "Drop (Bus Point)"
                    : "Pickup (Bus Point)",
                prefixIcon: const Icon(Icons.location_city),
                hintText: "Which Point? (Map) ->",
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _pickLocation(false),
                icon: const Icon(Icons.map),
                label: const Text("Pick Bus Point"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (showFemalePref)
            SwitchListTile(
              title: const Text("Prefer Female Partner"),
              subtitle: const Text("Subject to availability."),
              value: _preferFemale,
              activeColor: Colors.pink,
              secondary: const Icon(Icons.face_3, color: Colors.pink),
              onChanged: (val) => setState(() => _preferFemale = val),
            ),
          if (isSoloMale)
            CheckboxListTile(
              title: const Text("Travelling with Female Companion?"),
              subtitle: const Text("Allows Female Partner Booking."),
              value: _hasFemaleCompanion,
              activeColor: Colors.pink,
              onChanged: (val) => setState(() => _hasFemaleCompanion = val!),
            ),
          SwitchListTile(
            title: const Text("Luggage Escort"),
            subtitle: const Text("Partner follows on bike."),
            value: _luggageEscort,
            activeColor: Colors.deepOrange,
            onChanged: (val) => setState(() {
              _luggageEscort = val;
              if (val) _sitInsideCab = false;
            }),
          ),
          SwitchListTile(
            title: const Text("In-Cab Companion"),
            subtitle: const Text("Partner sits inside."),
            value: _sitInsideCab,
            activeColor: Colors.blue,
            onChanged: (val) => setState(() {
              _sitInsideCab = val;
              if (val) _luggageEscort = false;
            }),
          ),
          const Divider(height: 30),
          const Text(
            "Essentials & Add-ons",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          _buildCounterRow(
            "Travel Kit",
            "₹150 each",
            _kitCount,
            () => setState(() => _kitCount--),
            () => setState(() => _kitCount++),
          ),
          _buildCounterRow(
            "Water Bottle (1L)",
            "₹20 / bottle",
            _waterCount,
            () => setState(() => _waterCount--),
            () => setState(() => _waterCount++),
          ),
          ExpansionTile(
            title: const Text("Hygiene & Care (Sanitary)"),
            leading: const Icon(
              Icons.medical_services_outlined,
              color: Colors.pink,
            ),
            children: [
              _buildCounterRow(
                "Sanitary Pads",
                "Approx ₹100",
                _padCount,
                () => setState(() => _padCount--),
                () => setState(() => _padCount++),
              ),
              _buildCounterRow(
                "Baby Diapers",
                "Approx ₹200",
                _babyDiaperCount,
                () => setState(() => _babyDiaperCount--),
                () => setState(() => _babyDiaperCount++),
              ),
              _buildCounterRow(
                "Adult Diapers",
                "Approx ₹300",
                _adultDiaperCount,
                () => setState(() => _adultDiaperCount--),
                () => setState(() => _adultDiaperCount++),
              ),
            ],
          ),
          CheckboxListTile(
            title: const Text("Partner buys Food"),
            value: _wantsFood,
            onChanged: (val) => setState(() => _wantsFood = val!),
          ),
          if (_wantsFood) ...[
            TextField(
              controller: _foodDetailsCtrl,
              decoration: const InputDecoration(labelText: "Food Details"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _foodBudgetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Max Budget (₹)",
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _launchSwiggy,
                child: const Text("Check Swiggy Menu"),
              ),
            ),
          ],
          const Divider(height: 30),
          const Text(
            "Contact Details",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SwitchListTile(
            title: const Text("I am the Passenger"),
            value: _isBookingForSelf,
            onChanged: (val) => setState(() => _isBookingForSelf = val),
          ),
          if (!_isBookingForSelf) ...[
            TextField(
              controller: _guestNameCtrl,
              decoration: const InputDecoration(
                labelText: "Passenger Name",
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _guestPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Passenger Phone",
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _guestGender,
              decoration: const InputDecoration(
                labelText: "Passenger Gender",
                prefixIcon: Icon(Icons.wc),
                border: OutlineInputBorder(),
              ),
              items: [
                "Male",
                "Female",
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _guestGender = val!),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Note to Partner (Optional)",
              hintText: "e.g. Meet near the ticket counter",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              "Payment Mode: Cash / UPI to Partner after service",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _book,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("CONFIRM BOOKING"),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 7. METRO, MRTS & SUBURBAN (Fixed Self Data & Coords)
// ==========================================
class MetroMrtsBookingScreen extends StatefulWidget {
  const MetroMrtsBookingScreen({super.key});
  @override
  State<MetroMrtsBookingScreen> createState() => _MetroMrtsBookingScreenState();
}

class _MetroMrtsBookingScreenState extends State<MetroMrtsBookingScreen> {
  final _pickupAddrCtrl = TextEditingController();
  final _dropAddrCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _guestNameCtrl = TextEditingController();
  final _guestPhoneCtrl = TextEditingController();

  String _serviceMode = "Station Drop/Pickup";
  bool _isGoingToStation = true;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;

  String _startLine = "Blue Line (Metro)";
  String _endLine = "Blue Line (Metro)";
  String? _startStation;
  String? _endStation;

  // 🟢 HUGE MAP PRESERVED
  final Map<String, List<String>> _chennaiRailNetwork = {
    "Blue Line (Metro)": [
      "Wimco Nagar Depot",
      "Wimco Nagar",
      "Tiruvottriyur Theradi",
      "Tiruvottriyur",
      "Kaladipet",
      "Tollgate",
      "New Washermanpet",
      "Tondiarpet",
      "Sir Theagaraya College",
      "Washermanpet",
      "Mannadi",
      "High Court",
      "Puratchi Thalaivar Dr. M.G.R. Central",
      "Government Estate",
      "LIC",
      "Thousand Lights",
      "AG-DMS",
      "Teynampet",
      "Nandanam",
      "Saidapet",
      "Little Mount",
      "Guindy",
      "Alandur",
      "Nanganallur Road",
      "Meenambakkam",
      "Chennai International Airport",
    ],
    "Green Line (Metro)": [
      "Puratchi Thalaivar Dr. M.G.R. Central",
      "Egmore",
      "Nehru Park",
      "Kilpauk",
      "Pachaiyappa's College",
      "Shenoy Nagar",
      "Anna Nagar East",
      "Anna Nagar Tower",
      "Thirumangalam",
      "Koyambedu",
      "CMBT",
      "Arumbakkam",
      "Vadapalani",
      "Ashok Nagar",
      "Ekkattuthangal",
      "Alandur",
      "St. Thomas Mount",
    ],
    "Purple Line (Ph2 - Corridor 3)": [
      "Madhavaram Milk Colony",
      "Thapalpetti",
      "Murari Hospital",
      "Moolakadai",
      "Sembiyam",
      "Perambur Market",
      "Perambur Metro",
      "Ayanavaram",
      "Otteri",
      "Pattalam",
      "Perambur Barracks Road",
      "Purasaiwakkam",
      "Kellys",
      "KMC",
      "Chetpet Metro",
      "Sterling Road Jn",
      "Nungambakkam",
      "Gemini",
      "Thousand Lights",
      "Royapettah Govt Hospital",
      "Dr. Radhakrishnan Salai",
      "Thirumayilai",
      "Mandaiveli",
      "Greenways Road",
      "Adyar Jn",
      "Adyar Depot",
      "Indira Nagar",
      "Thiruvanmiyur",
      "Taramani",
      "Nehru Nagar",
      "Kandanchavadi",
      "Perungudi",
      "Thoraipakkam",
      "Mettukuppam",
      "PTC Colony",
      "Okkiyampet",
      "Karapakkam",
      "Okkiyam Thoraipakkam",
      "Sholinganallur",
      "Sholinganallur Lake I",
      "Sholinganallur Lake II",
      "Semmancheri I",
      "Semmancheri II",
      "Gandhi Nagar",
      "Navallur",
      "Siruseri",
      "SIPCOT 1",
      "SIPCOT 2",
    ],
    "Yellow Line (Ph2 - Corridor 4)": [
      "Light House",
      "Kutchery Road",
      "Thirumayilai",
      "Alwarpet",
      "Bharathidasan Road",
      "Boat Club",
      "Nandanam",
      "Panagal Park",
      "Kodambakkam",
      "Power House",
      "Vadapalani",
      "Saligramam",
      "Saligramam Warehouse",
      "Alwarthiru Nagar",
      "Valasaravakkam",
      "Karambakkam",
      "Alapakkam",
      "Porur Junction",
      "Porur Bypass",
      "Thelliyaragaram",
      "Iyyappanthangal",
      "Kattupakkam",
      "Kumananchavadi",
      "Karayanchavadi",
      "Mullai Thottam",
      "Poonamallee",
      "Poonamallee Bypass",
    ],
    "Red Line (Ph2 - Corridor 5)": [
      "Madhavaram Milk Colony",
      "Assisi Nagar",
      "Manjambakkam",
      "Velmurugan Nagar",
      "MMBT",
      "Shastri Nagar",
      "Retteri Junction",
      "Kolathur",
      "Srinivasa Nagar",
      "Villivakkam",
      "Villivakkam Bus Terminus",
      "Nadhamuni",
      "Anna Nagar Depot",
      "Thirumangalam",
      "Kendriya Vidyalaya",
      "Grain Market",
      "Sai Nagar",
      "Elango Nagar",
      "Mugalivakkam",
      "DLF IT SEZ",
      "Sathya Nagar",
      "CTC",
      "Butt Road",
      "Alandur",
      "St Thomas Mount",
      "Adambakkam",
      "Vanuvampet",
      "Puzhuthivakkam",
      "Madipakkam",
      "Kilkattalai",
      "Echangadu",
      "Kovilambakkam",
      "Vellakkal",
      "Medavakkam Koot Road",
      "Kamraj Garden St",
      "Medavakkam Jn",
      "Perumbakkam",
      "Global Hospital",
      "Elcot",
      "Sholinganallur",
    ],
    "South Line (Local)": [
      "Chennai Beach",
      "Chennai Fort",
      "Park",
      "Egmore",
      "Chetpet",
      "Nungambakkam",
      "Kodambakkam",
      "Mambalam",
      "Saidapet",
      "Guindy",
      "St. Thomas Mount",
      "Pazhavanthangal",
      "Meenambakkam",
      "Tirusulam (Airport)",
      "Pallavaram",
      "Chromepet",
      "Tambaram Sanatorium",
      "Tambaram",
      "Perungalathur",
      "Vandalur",
      "Guduvancheri",
      "Potheri (SRM)",
      "Maraimalai Nagar",
      "Chengalpattu",
    ],
    "West Line (Local)": [
      "Chennai Central (MMC)",
      "Basin Bridge",
      "Perambur",
      "Villivakkam",
      "Ambattur",
      "Avadi",
      "Hindu College",
      "Pattabiram",
      "Tiruninravur",
      "Tiruvallur",
      "Arakkonam",
    ],
    "North Line (Local)": [
      "Chennai Central (MMC)",
      "Basin Bridge",
      "Korukkupet",
      "Tondiarpet",
      "V.O.C. Nagar",
      "Tiruvottiyur",
      "Wimco Nagar",
      "Kathivakkam",
      "Ennore",
      "Athipattu Pudunagar",
      "Athipattu",
      "Nandiambakkam",
      "Minjur",
      "Anuppampattu",
      "Ponneri",
      "Kavaraipettai",
      "Gummidipoondi",
    ],
    "MRTS (Mass Rapid)": [
      "Chennai Beach",
      "Fort",
      "Park Town",
      "Chintadripet",
      "Triplicane",
      "Light House",
      "Mylapore",
      "Mandaveli",
      "Greenways Rd",
      "Kotturpuram",
      "Kasturba Nagar",
      "Indira Nagar",
      "Tiruvanmiyur",
      "Taramani",
      "Perungudi",
      "Velachery",
      "Puzhuthivakkam (Upcoming)",
      "Adambakkam (Upcoming)",
      "St. Thomas Mount (Link)",
    ],
  };

  // 🟢 FIX: PROFILE DATA
  String _userGender = "Male";
  String _userName = "User";
  String _userPhone = "";
  String _guestGender = "Female";
  bool _hasFemaleCompanion = false;
  bool _preferFemale = false;
  bool _needWheelchair = false;
  bool _isBookingForSelf = true;
  int _partnerCount = 1;
  int _passengerCount = 1;
  int _bagCount = 1;

  double? _pickupLat, _pickupLng;
  double? _dropLat, _dropLng;

  @override
  void initState() {
    super.initState();
    _startStation = _chennaiRailNetwork[_startLine]!.first;
    _endStation = _chennaiRailNetwork[_endLine]!.last;
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _userGender = doc.data()?['gender'] ?? "Male";
          _userName = doc.data()?['name'] ?? "User";
          _userPhone = doc.data()?['phone'] ?? "";
        });
      }
    }
  }

  bool _canRequestFemalePartner() {
    bool isNight = _selectedTime.hour >= 20 || _selectedTime.hour < 6;
    String passengerGender = _isBookingForSelf ? _userGender : _guestGender;
    bool isFemalePassenger = passengerGender.toLowerCase() == "female";
    if (!isNight) return isFemalePassenger || _hasFemaleCompanion;
    return isFemalePassenger || _hasFemaleCompanion;
  }

  void _updatePassengerCount(int newCount) {
    if (newCount < 1) return;
    setState(() {
      _passengerCount = newCount;
      int minPartners = (_passengerCount / 5).ceil();
      if (_partnerCount < minPartners) _partnerCount = minPartners;
    });
  }

  void _updatePartnerCount(int newCount) {
    int minPartners = (_passengerCount / 5).ceil();
    if (newCount < minPartners) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Safety Rule: Need at least $minPartners partner(s)."),
        ),
      );
      return;
    }
    setState(() => _partnerCount = newCount);
  }

  Future<void> _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (pickedTime == null) return;
    setState(() {
      _selectedDate = pickedDate;
      _selectedTime = pickedTime;
    });
  }

  Future<void> _pickLocation(bool isPickup) async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const OsmMapPicker()),
    );
    if (result != null) {
      setState(() {
        String locStr =
            "Lat: ${result.latitude.toStringAsFixed(4)}, Lng: ${result.longitude.toStringAsFixed(4)}";
        if (isPickup) {
          _pickupLat = result.latitude;
          _pickupLng = result.longitude;
          _pickupAddrCtrl.text = locStr;
        } else {
          _dropLat = result.latitude;
          _dropLng = result.longitude;
          _dropAddrCtrl.text = locStr;
        }
      });
    }
  }

  int _calculatePrice() {
    int base = _serviceMode == "Full Companion" ? 500 : 250;
    int distanceCharge = (_pickupLat != null) ? 100 : 0;
    int singleCost = base + distanceCharge;
    int total = singleCost * _partnerCount;
    if (_bagCount > (2 * _partnerCount))
      total += (_bagCount - (2 * _partnerCount)) * 50;
    return total;
  }

  // 🟢 FIXED: METRO BOOKING LOGIC
  void _book() async {
    if (_pickupAddrCtrl.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select Pickup Address")));
      return;
    }
    if (_serviceMode == "Full Companion" && _dropAddrCtrl.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select Destination Address")),
      );
      return;
    }
    // 🟢 FIX: SELF PHONE CHECK
    if (_isBookingForSelf && _userPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please update your Phone Number in Profile!"),
        ),
      );
      return;
    }
    if (!_isBookingForSelf &&
        (_guestNameCtrl.text.isEmpty || _guestPhoneCtrl.text.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter Passenger Contact Details")),
      );
      return;
    }

    setState(() => _isLoading = true);
    int cost = _calculatePrice();
    final DateTime scheduleTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // 🟢 2. DETERMINE ADDRESSES & COORDINATES FOR METRO
    String finalPickupAddr;
    String finalDropAddr;
    double? finalPickupLat;
    double? finalPickupLng;
    double? finalDropLat;
    double? finalDropLng;

    if (_serviceMode == "Full Companion") {
      finalPickupAddr = _pickupAddrCtrl.text;
      finalDropAddr = _dropAddrCtrl.text;
      finalPickupLat = _pickupLat;
      finalPickupLng = _pickupLng;
      finalDropLat = _dropLat;
      finalDropLng = _dropLng;
    } else {
      if (_isGoingToStation) {
        // HOME -> STATION
        finalPickupAddr = _pickupAddrCtrl.text;
        finalDropAddr = "$_startStation ($_startLine)";
        finalPickupLat = _pickupLat;
        finalPickupLng = _pickupLng;
      } else {
        // STATION -> HOME
        finalPickupAddr = "$_startStation ($_startLine)";
        finalDropAddr =
            _pickupAddrCtrl.text; // "Pickup" field holds destination visually
        finalPickupLat = null;
        finalPickupLng = null;
        finalDropLat = _pickupLat;
        finalDropLng = _pickupLng;
      }
    }

    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'service': 'Metro/Local',
        'service_mode': _serviceMode,
        'line_start': _startLine,
        'station_start': _startStation,
        'line_end': _serviceMode == "Full Companion" ? _endLine : "N/A",
        'station_end': _serviceMode == "Full Companion" ? _endStation : "N/A",
        'has_interchange':
            (_serviceMode == "Full Companion" && _startLine != _endLine),
        'trip_direction': _serviceMode == "Full Companion"
            ? "Full Journey"
            : (_isGoingToStation ? "To Station" : "From Station"),
        'partners_required': _partnerCount,
        'passenger_count': _passengerCount,
        'scheduled_time': scheduleTime,
        'prefer_female_partner': _canRequestFemalePartner()
            ? _preferFemale
            : false,
        'need_wheelchair': _needWheelchair,
        'bags': _bagCount,
        'booking_for_self': _isBookingForSelf,
        'guest_name': _isBookingForSelf ? _userName : _guestNameCtrl.text,
        'guest_phone': _isBookingForSelf ? _userPhone : _guestPhoneCtrl.text,
        'guest_gender': _isBookingForSelf ? _userGender : _guestGender,
        'has_female_companion': _hasFemaleCompanion,
        'address_pickup': finalPickupAddr,
        'address_drop': finalDropAddr,
        'pickup_lat': finalPickupLat,
        'pickup_lng': finalPickupLng,
        'drop_lat': finalDropLat,
        'drop_lng': finalDropLng,
        'notes': _noteCtrl.text,
        'status': 'pending',
        'cost': cost,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Booking Confirmed!"),
            content: Text(
              "Line: $_startLine\nMode: $_serviceMode\nEst. Pay: ₹$cost",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCounterRow(
    String label,
    String price,
    int count,
    VoidCallback onRemove,
    VoidCallback onAdd,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              if (price.isNotEmpty)
                Text(
                  price,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed:
                      count >
                          (label.contains("Porters") ||
                                  label.contains("Passengers")
                              ? 1
                              : 0)
                      ? onRemove
                      : null,
                  color: Colors.red,
                ),
                Text(
                  "$count",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: onAdd,
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showFemalePref = _canRequestFemalePartner();
    bool isSoloMale = !_canRequestFemalePartner();
    bool interchange =
        _serviceMode == "Full Companion" && (_startLine != _endLine);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Metro, Local & MRTS"),
        backgroundColor: Colors.purple,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade100),
            ),
            child: Column(
              children: [
                RadioListTile(
                  title: const Text(
                    "Station Drop/Pickup",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text("Help entering/leaving station only."),
                  value: "Station Drop/Pickup",
                  groupValue: _serviceMode,
                  activeColor: Colors.purple,
                  onChanged: (val) =>
                      setState(() => _serviceMode = val.toString()),
                ),
                RadioListTile(
                  title: const Text(
                    "Full Companion (Butler)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    "Travels WITH you from Home to Destination.",
                  ),
                  value: "Full Companion",
                  groupValue: _serviceMode,
                  activeColor: Colors.purple,
                  onChanged: (val) =>
                      setState(() => _serviceMode = val.toString()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_serviceMode == "Station Drop/Pickup") ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _startLine,
              decoration: const InputDecoration(
                labelText: "Select Rail Line",
                prefixIcon: Icon(Icons.linear_scale),
                border: OutlineInputBorder(),
              ),
              items: _chennaiRailNetwork.keys
                  .map(
                    (l) => DropdownMenuItem(
                      value: l,
                      child: Text(l, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _startLine = val!;
                  _startStation = _chennaiRailNetwork[val]!.first;
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _startStation,
              decoration: const InputDecoration(
                labelText: "Which Station?",
                prefixIcon: Icon(Icons.subway),
                border: OutlineInputBorder(),
              ),
              items: _chennaiRailNetwork[_startLine]!
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _startStation = val!),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isGoingToStation = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isGoingToStation
                              ? Colors.purple
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "To Station",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isGoingToStation
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isGoingToStation = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isGoingToStation
                              ? Colors.purple
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "From Station",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !_isGoingToStation
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text(
              "Start Journey",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _startLine,
              decoration: const InputDecoration(
                labelText: "Start Line",
                prefixIcon: Icon(Icons.linear_scale),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
              items: _chennaiRailNetwork.keys
                  .map(
                    (l) => DropdownMenuItem(
                      value: l,
                      child: Text(
                        l,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() {
                _startLine = val!;
                _startStation = _chennaiRailNetwork[val]!.first;
              }),
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _startStation,
              decoration: const InputDecoration(
                labelText: "Start Station",
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: _chennaiRailNetwork[_startLine]!
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _startStation = val!),
            ),
            const SizedBox(height: 15),
            const Center(child: Icon(Icons.arrow_downward, color: Colors.grey)),
            const SizedBox(height: 10),
            const Text(
              "End Journey",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _endLine,
              decoration: const InputDecoration(
                labelText: "End Line",
                prefixIcon: Icon(Icons.linear_scale),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
              items: _chennaiRailNetwork.keys
                  .map(
                    (l) => DropdownMenuItem(
                      value: l,
                      child: Text(
                        l,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() {
                _endLine = val!;
                _endStation = _chennaiRailNetwork[val]!.first;
              }),
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _endStation,
              decoration: const InputDecoration(
                labelText: "End Station",
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: _chennaiRailNetwork[_endLine]!
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _endStation = val!),
            ),
            if (interchange)
              Container(
                margin: const EdgeInsets.only(top: 15),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.transfer_within_a_station, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Interchange Required. Partner will guide you.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.purple),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Schedule Time",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        "${DateFormat('EEE, dd MMM').format(_selectedDate)} at ${_selectedTime.format(context)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    "Change",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildCounterRow(
            "Total Passengers",
            "1 Partner per 5 people",
            _passengerCount,
            () => _updatePassengerCount(_passengerCount - 1),
            () => _updatePassengerCount(_passengerCount + 1),
          ),
          _buildCounterRow(
            "Porters Required",
            "Multiplies cost",
            _partnerCount,
            () => _updatePartnerCount(_partnerCount - 1),
            () => _updatePartnerCount(_partnerCount + 1),
          ),
          const SizedBox(height: 10),
          if (_serviceMode == "Station Drop/Pickup") ...[
            TextField(
              controller: _pickupAddrCtrl,
              readOnly: false,
              decoration: InputDecoration(
                labelText: _isGoingToStation
                    ? "Pickup Address (Home)"
                    : "Drop Address (Home)",
                prefixIcon: const Icon(Icons.home),
                hintText: "Use Map ->",
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _pickLocation(true),
                icon: const Icon(Icons.map),
                label: const Text("Pick Location"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ] else ...[
            TextField(
              controller: _pickupAddrCtrl,
              readOnly: false,
              decoration: const InputDecoration(
                labelText: "Pickup Address (Start)",
                prefixIcon: Icon(Icons.home),
                hintText: "Use Map ->",
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _pickLocation(true),
                icon: const Icon(Icons.map),
                label: const Text("Pick Start"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _dropAddrCtrl,
              readOnly: false,
              decoration: const InputDecoration(
                labelText: "Drop Address (Dest)",
                prefixIcon: Icon(Icons.flag),
                hintText: "Use Map ->",
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _pickLocation(false),
                icon: const Icon(Icons.map),
                label: const Text("Pick Dest"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (showFemalePref)
            SwitchListTile(
              title: const Text("Prefer Female Partner"),
              subtitle: const Text("Prioritizes female partners."),
              value: _preferFemale,
              activeColor: Colors.pink,
              secondary: const Icon(Icons.face_3, color: Colors.pink),
              onChanged: (val) => setState(() => _preferFemale = val),
            ),
          if (isSoloMale)
            CheckboxListTile(
              title: const Text("Travelling with Female Companion?"),
              subtitle: const Text("Allows Female Partner Booking."),
              value: _hasFemaleCompanion,
              activeColor: Colors.pink,
              onChanged: (val) => setState(() => _hasFemaleCompanion = val!),
            ),
          SwitchListTile(
            title: const Text("Need Wheelchair"),
            subtitle: const Text("At Station Entrance."),
            value: _needWheelchair,
            activeColor: Colors.purple,
            secondary: const Icon(Icons.accessible, color: Colors.purple),
            onChanged: (val) => setState(() => _needWheelchair = val),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text("I am the Passenger"),
            value: _isBookingForSelf,
            onChanged: (val) => setState(() => _isBookingForSelf = val),
          ),
          if (!_isBookingForSelf) ...[
            TextField(
              controller: _guestNameCtrl,
              decoration: const InputDecoration(
                labelText: "Passenger Name",
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _guestPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Passenger Phone",
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _guestGender,
              decoration: const InputDecoration(
                labelText: "Passenger Gender",
                prefixIcon: Icon(Icons.wc),
                border: OutlineInputBorder(),
              ),
              items: [
                "Male",
                "Female",
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _guestGender = val!),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Note to Partner",
              hintText: "e.g. Meet at Platform 1",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              "Payment Mode: Cash / UPI to Partner after service",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _book,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("CONFIRM BOOKING"),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 8. MTC BUS BOOKING (Fixed Self Data & Coords)
// ==========================================
class MtcBookingScreen extends StatefulWidget {
  const MtcBookingScreen({super.key});
  @override
  State<MtcBookingScreen> createState() => _MtcBookingScreenState();
}

class _MtcBookingScreenState extends State<MtcBookingScreen> {
  final _busRouteCtrl = TextEditingController();
  final _pickupAddrCtrl = TextEditingController();
  final _dropAddrCtrl = TextEditingController();
  final _boardingPointCtrl = TextEditingController();
  final _droppingPointCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _guestNameCtrl = TextEditingController();
  final _guestPhoneCtrl = TextEditingController();

  String _serviceMode = "Bus Stop Drop/Pickup";
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;
  bool _preferFemale = false;
  bool _needWheelchair = false;
  bool _isBookingForSelf = true;
  int _partnerCount = 1;
  int _passengerCount = 1;
  int _bagCount = 1;
  double? _pickupLat, _pickupLng;
  double? _dropLat, _dropLng;
  double? _boardLat, _boardLng;
  double? _alightLat, _alightLng;

  // 🟢 FIX: PROFILE DATA
  String _userGender = "Male";
  String _userName = "User";
  String _userPhone = "";
  String _guestGender = "Female";
  bool _hasFemaleCompanion = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _userGender = doc.data()?['gender'] ?? "Male";
          _userName = doc.data()?['name'] ?? "User";
          _userPhone = doc.data()?['phone'] ?? "";
        });
      }
    }
  }

  bool _canRequestFemalePartner() {
    bool isNight = _selectedTime.hour >= 20 || _selectedTime.hour < 6;
    String passengerGender = _isBookingForSelf ? _userGender : _guestGender;
    bool isFemalePassenger = passengerGender.toLowerCase() == "female";
    if (!isNight) return isFemalePassenger || _hasFemaleCompanion;
    return isFemalePassenger || _hasFemaleCompanion;
  }

  void _updatePassengerCount(int newCount) {
    if (newCount < 1) return;
    setState(() {
      _passengerCount = newCount;
      int minPartners = (_passengerCount / 5).ceil();
      if (_partnerCount < minPartners) _partnerCount = minPartners;
    });
  }

  void _updatePartnerCount(int newCount) {
    int minPartners = (_passengerCount / 5).ceil();
    if (newCount < minPartners) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Safety Rule: Need at least $minPartners partner(s)."),
        ),
      );
      return;
    }
    setState(() => _partnerCount = newCount);
  }

  Future<void> _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (pickedTime == null) return;
    setState(() {
      _selectedDate = pickedDate;
      _selectedTime = pickedTime;
    });
  }

  Future<void> _pickLocation(String type) async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const OsmMapPicker()),
    );
    if (result != null) {
      setState(() {
        String locStr =
            "Lat: ${result.latitude.toStringAsFixed(4)}, Lng: ${result.longitude.toStringAsFixed(4)}";
        if (type == 'pickup') {
          _pickupLat = result.latitude;
          _pickupLng = result.longitude;
          _pickupAddrCtrl.text = locStr;
        } else if (type == 'drop') {
          _dropLat = result.latitude;
          _dropLng = result.longitude;
          _dropAddrCtrl.text = locStr;
        } else if (type == 'board') {
          _boardLat = result.latitude;
          _boardLng = result.longitude;
          _boardingPointCtrl.text = locStr;
        } else if (type == 'alight') {
          _alightLat = result.latitude;
          _alightLng = result.longitude;
          _droppingPointCtrl.text = locStr;
        }
      });
    }
  }

  int _calculatePrice() {
    int base = _serviceMode == "Full Companion" ? 550 : 250;
    int singleCost = base;
    int total = singleCost * _partnerCount;
    if (_bagCount > (2 * _partnerCount))
      total += (_bagCount - (2 * _partnerCount)) * 60;
    return total;
  }

  // 🟢 FIXED: MTC BOOKING LOGIC
  void _book() async {
    if (_pickupAddrCtrl.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select Pickup Address")));
      return;
    }
    if (_serviceMode == "Full Companion" && _dropAddrCtrl.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select Destination Address")),
      );
      return;
    }
    // 🟢 FIX: SELF PHONE
    if (_isBookingForSelf && _userPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please update Phone in Profile!")),
      );
      return;
    }
    if (!_isBookingForSelf &&
        (_guestNameCtrl.text.isEmpty || _guestPhoneCtrl.text.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter Passenger Contact Details")),
      );
      return;
    }

    setState(() => _isLoading = true);
    int cost = _calculatePrice();
    final DateTime scheduleTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'service': 'MTC Bus',
        'service_mode': _serviceMode,
        'bus_route_no': _busRouteCtrl.text.isEmpty ? "Any" : _busRouteCtrl.text,
        'partners_required': _partnerCount,
        'passenger_count': _passengerCount,
        'scheduled_time': scheduleTime,
        'prefer_female_partner': _canRequestFemalePartner()
            ? _preferFemale
            : false,
        'need_wheelchair': _needWheelchair, 'bags': _bagCount,
        'booking_for_self': _isBookingForSelf,
        // 🟢 FIX: SEND REAL NAME/PHONE
        'guest_name': _isBookingForSelf ? _userName : _guestNameCtrl.text,
        'guest_phone': _isBookingForSelf ? _userPhone : _guestPhoneCtrl.text,
        'guest_gender': _isBookingForSelf ? _userGender : _guestGender,
        'has_female_companion': _hasFemaleCompanion,
        'address_pickup': _pickupAddrCtrl.text,
        'address_board': _boardingPointCtrl.text,
        'address_alight': _serviceMode == "Full Companion"
            ? _droppingPointCtrl.text
            : "N/A",
        'address_final': _serviceMode == "Full Companion"
            ? _dropAddrCtrl.text
            : "N/A",
        'notes': _noteCtrl.text,
        'status': 'pending',
        'cost': cost,
        'timestamp': FieldValue.serverTimestamp(),
        // 🟢 FIX: SEND COORDS
        'pickup_lat': _pickupLat,
        'pickup_lng': _pickupLng,
      });
      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Booking Confirmed!"),
            content: Text(
              "Bus: ${_busRouteCtrl.text}\nMode: $_serviceMode\nEst. Pay: ₹$cost",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCounterRow(
    String label,
    String price,
    int count,
    VoidCallback onRemove,
    VoidCallback onAdd,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              if (price.isNotEmpty)
                Text(
                  price,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed:
                      count >
                          (label.contains("Porters") ||
                                  label.contains("Passengers")
                              ? 1
                              : 0)
                      ? onRemove
                      : null,
                  color: Colors.red,
                ),
                Text(
                  "$count",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: onAdd,
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showFemalePref = _canRequestFemalePartner();
    bool isSoloMale = !_canRequestFemalePartner();

    return Scaffold(
      appBar: AppBar(
        title: const Text("MTC City Bus Assist"),
        backgroundColor: Colors.redAccent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Column(
              children: [
                RadioListTile(
                  title: const Text(
                    "Bus Stop Drop/Pickup",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text("Help carrying bags to/from Bus Stop."),
                  value: "Bus Stop Drop/Pickup",
                  groupValue: _serviceMode,
                  activeColor: Colors.red,
                  onChanged: (val) =>
                      setState(() => _serviceMode = val.toString()),
                ),
                RadioListTile(
                  title: const Text(
                    "Full Companion (Butler)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text("Travels inside MTC Bus with you."),
                  value: "Full Companion",
                  groupValue: _serviceMode,
                  activeColor: Colors.red,
                  onChanged: (val) =>
                      setState(() => _serviceMode = val.toString()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _busRouteCtrl,
            decoration: const InputDecoration(
              labelText: "Bus Route No (Optional)",
              hintText: "e.g. 21G, 570, 29C",
              prefixIcon: Icon(Icons.directions_bus),
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.redAccent),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Schedule Time",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        "${DateFormat('EEE, dd MMM').format(_selectedDate)} at ${_selectedTime.format(context)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    "Change",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildCounterRow(
            "Total Passengers",
            "1 Partner per 5 people",
            _passengerCount,
            () => _updatePassengerCount(_passengerCount - 1),
            () => _updatePassengerCount(_passengerCount + 1),
          ),
          _buildCounterRow(
            "Porters Required",
            "Multiplies cost",
            _partnerCount,
            () => _updatePartnerCount(_partnerCount - 1),
            () => _updatePartnerCount(_partnerCount + 1),
          ),
          _buildCounterRow(
            "Luggage Count",
            "Heavy Crowd Surcharge > 2 bags",
            _bagCount,
            () => setState(() {
              if (_bagCount > 1) _bagCount--;
            }),
            () => setState(() => _bagCount++),
          ),
          const SizedBox(height: 20),
          const Text(
            "Trip Details",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (_serviceMode == "Bus Stop Drop/Pickup") ...[
            TextField(
              controller: _pickupAddrCtrl,
              readOnly: false,
              decoration: const InputDecoration(
                labelText: "Home Address (Start)",
                prefixIcon: Icon(Icons.home),
                hintText: "Use Map ->",
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _pickLocation('pickup'),
                icon: const Icon(Icons.map),
                label: const Text("Pick Home"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _boardingPointCtrl,
              readOnly: false,
              decoration: const InputDecoration(
                labelText: "Bus Stop (Boarding Point)",
                prefixIcon: Icon(Icons.signpost),
                hintText: "Use Map ->",
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _pickLocation('board'),
                icon: const Icon(Icons.map),
                label: const Text("Pick Bus Stop"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ] else ...[
            TextField(
              controller: _pickupAddrCtrl,
              readOnly: false,
              decoration: const InputDecoration(
                labelText: "Start Address (Home)",
                prefixIcon: Icon(Icons.home),
                hintText: "Use Map ->",
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _pickLocation('pickup'),
                icon: const Icon(Icons.map),
                label: const Text("Pick Start"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _boardingPointCtrl,
              readOnly: false,
              decoration: const InputDecoration(
                labelText: "Boarding Bus Stop",
                prefixIcon: Icon(Icons.login),
                hintText: "Which Stop?",
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _pickLocation('board'),
                icon: const Icon(Icons.map),
                label: const Text("Pick Boarding"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _droppingPointCtrl,
              readOnly: false,
              decoration: const InputDecoration(
                labelText: "Dropping Bus Stop",
                prefixIcon: Icon(Icons.logout),
                hintText: "Which Stop?",
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _pickLocation('alight'),
                icon: const Icon(Icons.map),
                label: const Text("Pick Dropping"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _dropAddrCtrl,
              readOnly: false,
              decoration: const InputDecoration(
                labelText: "Final Destination",
                prefixIcon: Icon(Icons.flag),
                hintText: "Use Map ->",
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _pickLocation('drop'),
                icon: const Icon(Icons.map),
                label: const Text("Pick Final"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (showFemalePref)
            SwitchListTile(
              title: const Text("Prefer Female Partner"),
              subtitle: const Text("For safety/comfort."),
              value: _preferFemale,
              activeColor: Colors.pink,
              secondary: const Icon(Icons.face_3, color: Colors.pink),
              onChanged: (val) => setState(() => _preferFemale = val),
            ),
          if (isSoloMale)
            CheckboxListTile(
              title: const Text("Travelling with Female Companion?"),
              subtitle: const Text("Allows Female Partner Booking."),
              value: _hasFemaleCompanion,
              activeColor: Colors.pink,
              onChanged: (val) => setState(() => _hasFemaleCompanion = val!),
            ),
          SwitchListTile(
            title: const Text("Need Wheelchair Access"),
            subtitle: const Text("Request Low-floor Bus support."),
            value: _needWheelchair,
            activeColor: Colors.red,
            secondary: const Icon(Icons.accessible, color: Colors.red),
            onChanged: (val) => setState(() => _needWheelchair = val),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text("I am the Passenger"),
            value: _isBookingForSelf,
            onChanged: (val) => setState(() => _isBookingForSelf = val),
          ),
          if (!_isBookingForSelf) ...[
            TextField(
              controller: _guestNameCtrl,
              decoration: const InputDecoration(
                labelText: "Passenger Name",
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _guestPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Passenger Phone",
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Note to Partner",
              hintText: "e.g. Meet near the ticket counter",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              "Payment Mode: Cash / UPI to Partner after service",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _book,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("CONFIRM BOOKING"),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 9. TOURIST GUIDE BOOKING (Fixed)
// ==========================================
class TouristGuideScreen extends StatefulWidget {
  const TouristGuideScreen({super.key});
  @override
  State<TouristGuideScreen> createState() => _TouristGuideScreenState();
}

class _TouristGuideScreenState extends State<TouristGuideScreen> {
  final _pickupCtrl = TextEditingController();
  final List<String> _citySpots = [
    "Marina Beach",
    "Kapaleeshwarar Temple",
    "Santhome Church",
    "Valluvar Kottam",
    "Guindy National Park",
    "Express Avenue",
    "Govt Museum",
  ];
  final List<String> _ecrSpots = [
    "VGP Marine Kingdom",
    "Muttukadu Boat House",
    "DakshinaChitra",
    "Mahabalipuram",
    "Wonderla",
    "Queens Land",
  ];
  final List<String> _selected = [];
  int _hours = 4;
  double? _lat, _lng;

  // 🟢 FIX: PROFILE DATA
  String _userName = "User";
  String _userPhone = "";
  String _userGender = "Male";

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _userName = doc.data()?['name'] ?? "User";
          _userPhone = doc.data()?['phone'] ?? "";
          _userGender = doc.data()?['gender'] ?? "Male";
        });
      }
    }
  }

  Future<void> _pickLocation() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const OsmMapPicker()),
    );
    if (result != null) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
        _pickupCtrl.text =
            "Lat: ${result.latitude.toStringAsFixed(4)}, Lng: ${result.longitude.toStringAsFixed(4)}";
      });
    }
  }

  int _calculateCost() {
    int total = _hours * 200;
    if (_selected.any((s) => _ecrSpots.contains(s))) total += 800;
    return total;
  }

  void _book() async {
    if (_selected.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select at least 1 place")));
      return;
    }
    if (_pickupCtrl.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select Pickup Location")));
      return;
    }
    // 🟢 FIX: SELF PHONE CHECK
    if (_userPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please update Phone in Profile!")),
      );
      return;
    }

    int cost = _calculateCost();
    await FirebaseFirestore.instance.collection('bookings').add({
      'userId': FirebaseAuth.instance.currentUser!.uid,
      'service': 'City Guide',
      // 🟢 FIX: SEND REAL NAME/PHONE
      'guest_name': _userName,
      'guest_phone': _userPhone,
      'guest_gender': _userGender,
      'address_pickup': _pickupCtrl.text,
      'duration': "$_hours Hours",
      'places': _selected,
      'status': 'pending',
      'cost': cost,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'Guide',
      // 🟢 FIX: SEND COORDS
      'pickup_lat': _lat,
      'pickup_lng': _lng,
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Guide Requested! Est: ₹$cost")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("City Guide"),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Column(
              children: [
                const Text(
                  "Pickup Point (Hotel/Home)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pickupCtrl,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.hotel),
                          hintText: "Tap Map ->",
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton(
                      heroTag: "guide_map",
                      onPressed: _pickLocation,
                      backgroundColor: Colors.teal,
                      child: const Icon(Icons.map, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Duration:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "$_hours Hours",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _hours.toDouble(),
                  min: 4,
                  max: 12,
                  divisions: 8,
                  activeColor: Colors.teal,
                  onChanged: (val) => setState(() => _hours = val.toInt()),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  "City Spots (Standard)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                ..._citySpots.map(
                  (spot) => CheckboxListTile(
                    title: Text(spot),
                    value: _selected.contains(spot),
                    dense: true,
                    onChanged: (v) => setState(
                      () => v! ? _selected.add(spot) : _selected.remove(spot),
                    ),
                  ),
                ),
                const Divider(),
                const Text(
                  "Outstation / ECR (+₹800)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                ..._ecrSpots.map(
                  (spot) => CheckboxListTile(
                    title: Text(spot),
                    value: _selected.contains(spot),
                    activeColor: Colors.deepOrange,
                    dense: true,
                    onChanged: (v) => setState(
                      () => v! ? _selected.add(spot) : _selected.remove(spot),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _book,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: Text("BOOK GUIDE (Est: ₹${_calculateCost()})"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 10. BOOKING HISTORY SCREEN
// ==========================================
class BookingHistoryScreen extends StatelessWidget {
  const BookingHistoryScreen({super.key});

  Future<void> _cancelBooking(BuildContext context, String docId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Booking?"),
        content: const Text("Are you sure you want to cancel this request?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Yes, Cancel",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('bookings').doc(docId).update(
        {'status': 'cancelled'},
      );
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Booking Cancelled.")));
    }
  }

  void _showBookingDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${data['service']} Details"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.entries.map((e) {
              if ([
                'userId',
                'timestamp',
                'cost',
                'status',
                'pickup_lat',
                'pickup_lng',
              ].contains(e.key))
                return const SizedBox.shrink();
              String key = e.key.replaceAll('_', ' ').toUpperCase();
              String val = e.value.toString();
              if (e.value is Map)
                val = (e.value as Map).entries
                    .map((sub) => "${sub.key}: ${sub.value}")
                    .join("\n");
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(val, style: const TextStyle(fontSize: 14)),
                    const Divider(),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final currency = NumberFormat.simpleCurrency(locale: 'en_IN');

    return Scaffold(
      appBar: AppBar(title: const Text("My Bookings")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No trips yet."));

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'pending';
              Color statusColor;
              IconData statusIcon;
              switch (status) {
                case 'completed':
                  statusColor = Colors.green;
                  statusIcon = Icons.check_circle;
                  break;
                case 'cancelled':
                  statusColor = Colors.red;
                  statusIcon = Icons.cancel;
                  break;
                case 'in_progress':
                  statusColor = Colors.blue;
                  statusIcon = Icons.directions_run;
                  break;
                default:
                  statusColor = Colors.orange;
                  statusIcon = Icons.schedule;
              }
              String dateStr = "Recently";
              if (data['scheduled_time'] != null) {
                Timestamp ts = data['scheduled_time'];
                dateStr = DateFormat('dd MMM, hh:mm a').format(ts.toDate());
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () => _showBookingDetails(context, data),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.1),
                            child: Icon(statusIcon, color: statusColor),
                          ),
                          title: Text(
                            "${data['service']} Trip",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "$dateStr\nStatus: ${status.toUpperCase()}",
                          ),
                          trailing: Text(
                            currency.format(data['cost'] ?? 0),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (status == 'pending') ...[
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _cancelBooking(context, doc.id),
                                icon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  "Cancel Booking",
                                  style: TextStyle(color: Colors.red),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// 11. PROFILE SCREEN
// ==========================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameCtrl.text = user.displayName ?? "";
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('phone')) {
        _phoneCtrl.text = doc.data()!['phone'];
      }
    }
  }

  void _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await user.updateDisplayName(_nameCtrl.text);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameCtrl.text,
        'phone': _phoneCtrl.text,
        'email': user.email,
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Profile Saved!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.account_circle, size: 100, color: Colors.grey),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: "Full Name",
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: "Phone Number",
              prefixIcon: Icon(Icons.phone),
              hintText: "+91 9876543210",
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("SAVE PROFILE"),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 12. PERSONAL ASSISTANT (Fixed Self Data & Coords)
// ==========================================
class PersonalAssistantScreen extends StatefulWidget {
  const PersonalAssistantScreen({super.key});
  @override
  State<PersonalAssistantScreen> createState() =>
      _PersonalAssistantScreenState();
}

class _PersonalAssistantScreenState extends State<PersonalAssistantScreen> {
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _guestNameCtrl = TextEditingController();
  final _guestPhoneCtrl = TextEditingController();

  String _serviceType = "Butler Only";
  int _hours = 4;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  String _transmission = "Automatic";
  String _carType = "Sedan";

  bool _isBookingForSelf = true;
  bool _isLoading = false;
  double? _lat, _lng;

  // 🟢 FIX: PROFILE DATA
  String _userGender = "Male";
  String _userName = "User";
  String _userPhone = "";
  String _guestGender = "Female";
  bool _preferFemale = false;
  bool _hasFemaleCompanion = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _userGender = doc.data()?['gender'] ?? "Male";
          _userName = doc.data()?['name'] ?? "User";
          _userPhone = doc.data()?['phone'] ?? "";
        });
      }
    }
  }

  bool _canRequestFemalePartner() {
    bool isNight = _selectedTime.hour >= 20 || _selectedTime.hour < 6;
    String primaryPassengerGender = _isBookingForSelf
        ? _userGender
        : _guestGender;
    bool isFemalePassenger = primaryPassengerGender.toLowerCase() == "female";
    if (!isNight) {
      return isFemalePassenger || _hasFemaleCompanion;
    } else {
      if (isFemalePassenger) return true;
      if (_hasFemaleCompanion) return true;
      return false;
    }
  }

  Future<void> _pickLocation() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const OsmMapPicker()),
    );
    if (result != null) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
        _addressCtrl.text =
            "Lat: ${result.latitude.toStringAsFixed(4)}, Lng: ${result.longitude.toStringAsFixed(4)}";
      });
    }
  }

  Future<void> _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (pickedTime == null) return;
    setState(() {
      _selectedDate = pickedDate;
      _selectedTime = pickedTime;
      if (!_canRequestFemalePartner()) _preferFemale = false;
    });
  }

  int _calculateCost() {
    int hourlyRate = 0;
    switch (_serviceType) {
      case "Butler Only":
        hourlyRate = 300;
        break;
      case "Driver Only":
        hourlyRate = 250;
        break;
      case "Ultimate Alfred":
        hourlyRate = 500;
        break;
    }
    int total = hourlyRate * _hours;
    if (total < 500) total = 500;
    return total;
  }

  void _book() async {
    if (_addressCtrl.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select Reporting Address")));
      return;
    }
    // 🟢 FIX: SELF PHONE
    if (_isBookingForSelf && _userPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please update Phone in Profile!")),
      );
      return;
    }
    if (!_isBookingForSelf &&
        (_guestNameCtrl.text.isEmpty || _guestPhoneCtrl.text.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter Contact Details")));
      return;
    }

    setState(() => _isLoading = true);
    int cost = _calculateCost();
    final DateTime scheduleTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'service': 'Personal Assistant',
        'service_type': _serviceType,
        'duration_hours': _hours,
        'scheduled_time': scheduleTime,
        'car_transmission': (_serviceType != "Butler Only")
            ? _transmission
            : "N/A",
        'car_type': (_serviceType != "Butler Only") ? _carType : "N/A",
        'booking_for_self': _isBookingForSelf,
        // 🟢 FIX: SEND REAL NAME/PHONE
        'guest_name': _isBookingForSelf ? _userName : _guestNameCtrl.text,
        'guest_phone': _isBookingForSelf ? _userPhone : _guestPhoneCtrl.text,
        'guest_gender': _isBookingForSelf ? _userGender : _guestGender,
        'has_female_companion': _hasFemaleCompanion,
        'prefer_female_partner': _preferFemale,
        'address': _addressCtrl.text,
        'notes': _noteCtrl.text,
        'status': 'pending',
        'cost': cost,
        'timestamp': FieldValue.serverTimestamp(),
        // 🟢 FIX: SEND COORDS
        'pickup_lat': _lat,
        'pickup_lng': _lng,
      });

      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Booking Confirmed!"),
            content: Text(
              "Service: $_serviceType\nDuration: $_hours Hours\nEst. Pay: ₹$cost (Min ₹500 applies)",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDriving = _serviceType != "Butler Only";
    bool showFemalePref = _canRequestFemalePartner();
    bool isNight = _selectedTime.hour >= 20 || _selectedTime.hour < 6;
    bool isSoloMale = !_canRequestFemalePartner();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hire Personal Assistant"),
        backgroundColor: Colors.black87,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                RadioListTile(
                  title: const Text(
                    "Butler Only",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text("Companion/Helper (₹300/hr)"),
                  secondary: const Icon(
                    Icons.person_outline,
                    color: Colors.blue,
                  ),
                  value: "Butler Only",
                  groupValue: _serviceType,
                  onChanged: (val) =>
                      setState(() => _serviceType = val.toString()),
                ),
                RadioListTile(
                  title: const Text(
                    "Driver Only",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text("Chauffeur for your car (₹250/hr)"),
                  secondary: const Icon(Icons.drive_eta, color: Colors.orange),
                  value: "Driver Only",
                  groupValue: _serviceType,
                  onChanged: (val) =>
                      setState(() => _serviceType = val.toString()),
                ),
                RadioListTile(
                  title: const Text(
                    "Ultimate Alfred",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  subtitle: const Text("Driver + Butler (₹500/hr)"),
                  secondary: const Icon(Icons.star, color: Colors.purple),
                  value: "Ultimate Alfred",
                  groupValue: _serviceType,
                  onChanged: (val) =>
                      setState(() => _serviceType = val.toString()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Duration:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                "$_hours Hours",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          Slider(
            value: _hours.toDouble(),
            min: 1,
            max: 12,
            divisions: 11,
            activeColor: Colors.black87,
            label: "$_hours hrs",
            onChanged: (val) => setState(() => _hours = val.toInt()),
          ),
          const SizedBox(height: 20),
          if (isDriving) ...[
            const Text(
              "Car Details",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _transmission,
                    decoration: const InputDecoration(
                      labelText: "Transmission",
                      border: OutlineInputBorder(),
                    ),
                    items: ["Automatic", "Manual"]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) => setState(() => _transmission = val!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _carType,
                    decoration: const InputDecoration(
                      labelText: "Car Type",
                      border: OutlineInputBorder(),
                    ),
                    items: ["Hatchback", "Sedan", "SUV", "Luxury"]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) => setState(() => _carType = val!),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.black87),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Reporting Time",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        "${DateFormat('EEE, dd MMM').format(_selectedDate)} at ${_selectedTime.format(context)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    "Change",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _addressCtrl,
            readOnly: false,
            decoration: const InputDecoration(
              labelText: "Reporting Address",
              prefixIcon: Icon(Icons.home),
              hintText: "Use Map ->",
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map),
              label: const Text("Pick Location"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const Divider(height: 30),
          SwitchListTile(
            title: const Text("I am the Client"),
            value: _isBookingForSelf,
            activeColor: Colors.black87,
            onChanged: (val) => setState(() => _isBookingForSelf = val),
          ),
          if (!_isBookingForSelf) ...[
            TextField(
              controller: _guestNameCtrl,
              decoration: const InputDecoration(
                labelText: "Client Name",
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _guestPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Client Phone",
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _guestGender,
              decoration: const InputDecoration(
                labelText: "Client Gender",
                prefixIcon: Icon(Icons.wc),
                border: OutlineInputBorder(),
              ),
              items: [
                "Male",
                "Female",
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _guestGender = val!),
            ),
            const SizedBox(height: 10),
          ],
          if (isSoloMale)
            CheckboxListTile(
              title: const Text(
                "I am travelling with a Female Companion",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                "Required for Female Partner booking at Night.",
              ),
              value: _hasFemaleCompanion,
              activeColor: Colors.pink,
              onChanged: (val) => setState(() {
                _hasFemaleCompanion = val!;
                if (!val && isNight) _preferFemale = false;
              }),
            ),
          const SizedBox(height: 10),
          if (showFemalePref)
            SwitchListTile(
              title: const Text("Prefer Female Partner"),
              subtitle: const Text("Prioritizes female partners."),
              value: _preferFemale,
              activeColor: Colors.pink,
              secondary: const Icon(Icons.face_3, color: Colors.pink),
              onChanged: (val) => setState(() => _preferFemale = val),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.red.shade50,
              child: Row(
                children: const [
                  Icon(Icons.shield, color: Colors.red, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "For safety reasons, Female Partners are only available for Female passengers or Mixed Groups after 8 PM.",
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Instructions",
              hintText: "e.g. Wear formal attire",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green),
              ),
              child: Text(
                "Estimated Pay: ₹${_calculateCost()}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _book,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black87),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("CONFIRM BOOKING"),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 13. MAP PICKER UTILITY
// ==========================================
class OsmMapPicker extends StatefulWidget {
  const OsmMapPicker({super.key});
  @override
  State<OsmMapPicker> createState() => _OsmMapPickerState();
}

class _OsmMapPickerState extends State<OsmMapPicker> {
  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  LatLng _center = const LatLng(13.0827, 80.2707);
  bool _gettingLocation = false;
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  Future<void> _searchLocation() async {
    String query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&addressdetails=1",
    );
    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.example.travel_assist'},
      );
      if (response.statusCode == 200) {
        setState(() => _searchResults = json.decode(response.body));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Search Error. Check Internet.")),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _getMyLocation() async {
    setState(() => _gettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable Location Services")),
        );
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _moveToLocation(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint("GPS Error: $e");
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  void _moveToLocation(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 15.0);
    setState(() {
      _center = LatLng(lat, lng);
      _searchResults = [];
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13.0,
              onPositionChanged: (pos, hasGesture) {
                if (pos.center != null) _center = pos.center!;
              },
              onTap: (_, __) => FocusScope.of(context).unfocus(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.travel_assist',
              ),
            ],
          ),
          const Center(
            child: Icon(Icons.location_on, color: Colors.red, size: 40),
          ),
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(blurRadius: 10, color: Colors.black12),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchLocation(),
                    decoration: InputDecoration(
                      hintText: "Search (e.g. Camp Road, Selaiyur)",
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      suffixIcon: IconButton(
                        icon: _isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search),
                        onPressed: _searchLocation,
                      ),
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(blurRadius: 10, color: Colors.black12),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final place = _searchResults[i];
                        return ListTile(
                          title: Text(
                            place['display_name'] ?? "Unknown",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: const Icon(
                            Icons.location_on,
                            color: Colors.grey,
                            size: 20,
                          ),
                          dense: true,
                          onTap: () {
                            double lat = double.parse(place['lat']);
                            double lng = double.parse(place['lon']);
                            _moveToLocation(lat, lng);
                            FocusScope.of(context).unfocus();
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: 100,
            right: 20,
            child: FloatingActionButton(
              heroTag: "gps_btn",
              backgroundColor: Colors.white,
              onPressed: _getMyLocation,
              child: _gettingLocation
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.my_location, color: Colors.indigo),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _center),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text("CONFIRM LOCATION"),
            ),
          ),
        ],
      ),
    );
  }
}
