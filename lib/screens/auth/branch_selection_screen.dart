
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import '../../config/app_config.dart';
import '../../widgets/widgets.dart';

class BranchSelectionScreen extends StatefulWidget {
  const BranchSelectionScreen({super.key});
  @override
  State<BranchSelectionScreen> createState() => _BranchSelectionScreenState();
}

class _BranchSelectionScreenState extends State<BranchSelectionScreen>
    with SingleTickerProviderStateMixin {
  // States: detecting, inside_geofence, outside_geofence, gps_off, permission_denied, error
  String _state = 'detecting';
  String? _errorMessage;
  Location? _detectedLocation;

  List<Location> _locations = [];
  Location? _selectedManualLocation;
  bool _loadingLocations = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _detectLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    if (_locations.isNotEmpty || _loadingLocations) return;
    setState(() => _loadingLocations = true);
    try {
      _locations = await ApiService.getLocations();
    } catch (_) {}
    if (mounted) setState(() => _loadingLocations = false);
  }

  void _confirmManualSelection() {
    if (_selectedManualLocation == null) return;
    final loc = _selectedManualLocation!;
    context.read<CartProvider>().setLocation(loc.id, loc.name);
    context.read<MenuProvider>().setSelectedLocation(loc.id);
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _detectLocation() async {
    setState(() {
      _state = 'detecting';
      _errorMessage = null;
    });

    try {
      // Step 1: Check GPS service
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _state = 'gps_off';
          _errorMessage = 'Please enable GPS/Location services to continue.';
        });
        _loadLocations();
        return;
      }

      // Step 2: Check & request permission
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        setState(() {
          _state = 'permission_denied';
          _errorMessage = 'Location permission is needed to find your nearest branch.';
        });
        _loadLocations();
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _state = 'permission_denied_forever';
          _errorMessage =
              'Location permission is permanently denied. Please enable it from your phone Settings.';
        });
        _loadLocations();
        return;
      }

      // Step 3: Get position
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Location detection timed out'),
      );

      // Step 4: Check geofence
      final geofenceData = await ApiService.checkGeofence(
        lat: pos.latitude,
        lng: pos.longitude,
      );

      if (!mounted) return;

      if (geofenceData['inside'] == true && geofenceData['location'] != null) {
        // Inside a geofence — set location and navigate
        final locData = geofenceData['location'];
        final loc = Location.fromJson(locData);
        setState(() {
          _state = 'inside_geofence';
          _detectedLocation = loc;
        });

        // Small delay to show success state before navigating
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;

        context.read<CartProvider>().setLocation(loc.id, loc.name);
        context.read<MenuProvider>().setSelectedLocation(loc.id);
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // NOT inside any geofence
        setState(() {
          _state = 'outside_geofence';
        });
        _loadLocations();
      }
    } catch (e) {
      debugPrint('Location detection error: $e');
      if (mounted) {
        setState(() {
          _state = 'error';
          _errorMessage = 'Something went wrong while detecting your location. Please try again.';
        });
        _loadLocations();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.background),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom - 80,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIcon(),
                const SizedBox(height: 32),
                _buildMessage(),
                const SizedBox(height: 40),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (_state) {
      case 'detecting':
        return ScaleTransition(
          scale: _pulseAnim,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(AppColors.primary).withValues(alpha: 0.15),
                  const Color(AppColors.accent).withValues(alpha: 0.12),
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(AppColors.primary).withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  size: 36,
                  color: Color(AppColors.primary),
                ),
              ),
            ),
          ),
        );

      case 'inside_geofence':
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(AppColors.success).withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 60,
            color: Color(AppColors.success),
          ),
        );

      case 'outside_geofence':
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(AppColors.warning).withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.location_off_rounded,
            size: 56,
            color: Color(AppColors.warning),
          ),
        );

      case 'gps_off':
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange.withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.gps_off_rounded,
            size: 56,
            color: Colors.orange,
          ),
        );

      case 'permission_denied':
      case 'permission_denied_forever':
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange.withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.location_disabled_rounded,
            size: 56,
            color: Colors.orange,
          ),
        );

      default: // error
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(AppColors.error).withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            size: 56,
            color: Color(AppColors.error),
          ),
        );
    }
  }

  Widget _buildMessage() {
    switch (_state) {
      case 'detecting':
        return Column(
          children: [
            const Text(
              'Detecting Your Location',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Hang tight! We\'re checking if PizzaHap delivers to your area...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        );

      case 'inside_geofence':
        return Column(
          children: [
            const Text(
              'You\'re In Our Zone! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(AppColors.success),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _detectedLocation != null
                  ? 'Connected to ${_detectedLocation!.name}. Taking you to the menu...'
                  : 'We deliver to your area! Setting up your experience...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        );

      case 'outside_geofence':
        return Column(
          children: [
            const Text(
              'We\'re Not Here Yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Unfortunately, PizzaHap doesn\'t deliver to your area yet. But we\'re expanding fast — stay tuned! 🍕',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(AppColors.primary).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(AppColors.primary).withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    size: 20,
                    color: const Color(AppColors.primary).withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'We\'ll notify you when we arrive in your city!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(AppColors.primary).withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case 'gps_off':
        return Column(
          children: [
            const Text(
              'GPS Is Turned Off',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We need your location to check if PizzaHap delivers to your area. Please turn on GPS and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        );

      case 'permission_denied':
      case 'permission_denied_forever':
        return Column(
          children: [
            const Text(
              'Location Permission Required',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? 'We need location access to find your nearest PizzaHap branch.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        );

      default: // error
        return Column(
          children: [
            const Text(
              'Something Went Wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? 'We couldn\'t detect your location. Please check your internet and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildManualPicker() {
    if (_loadingLocations) {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Center(child: PizzaSpinner(size: 24)),
      );
    }
    if (_locations.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or choose manually',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: _selectedManualLocation?.id,
              hint: const Text('Select a branch', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: _locations.map((loc) => DropdownMenuItem<int>(
                value: loc.id,
                child: Row(children: [
                  const Icon(Icons.storefront_rounded, size: 18, color: Color(AppColors.primary)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(loc.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                ]),
              )).toList(),
              onChanged: (id) {
                setState(() {
                  _selectedManualLocation = _locations.firstWhere((l) => l.id == id);
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _selectedManualLocation != null ? _confirmManualSelection : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.primary),
              disabledBackgroundColor: const Color(AppColors.primary).withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    switch (_state) {
      case 'detecting':
      case 'inside_geofence':
        // Show a subtle loading indicator
        return const SizedBox(
          height: 52,
          child: Center(
            child: PizzaSpinner(size: 28),
          ),
        );

      case 'outside_geofence':
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _detectLocation,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Retry Location',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            _buildManualPicker(),
          ],
        );

      case 'gps_off':
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                  await Future.delayed(const Duration(milliseconds: 500));
                  _detectLocation();
                },
                icon: const Icon(Icons.settings_rounded, size: 20),
                label: const Text(
                  'Open Location Settings',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            _buildManualPicker(),
          ],
        );

      case 'permission_denied':
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _detectLocation,
                icon: const Icon(Icons.location_on_rounded, size: 20),
                label: const Text(
                  'Grant Permission',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            _buildManualPicker(),
          ],
        );

      case 'permission_denied_forever':
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Geolocator.openAppSettings();
                  await Future.delayed(const Duration(milliseconds: 500));
                  _detectLocation();
                },
                icon: const Icon(Icons.settings_rounded, size: 20),
                label: const Text(
                  'Open App Settings',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            _buildManualPicker(),
          ],
        );

      default: // error
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _detectLocation,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            _buildManualPicker(),
          ],
        );
    }
  }
}
