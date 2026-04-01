
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

class _BranchSelectionScreenState extends State<BranchSelectionScreen> {
  List<Location> _locations = [];
  Location? _selected;
  bool _loading = true;
  bool _locating = false;
  bool _locationUsed = false;
  String? _gpsError;

  @override
  void initState() {
    super.initState();
    // Load plain list without GPS on start  GPS only on user tap
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _loading = true;
      _locationUsed = false;
    });
    try {
      debugPrint('Loading locations...');
      final locs = await ApiService.getLocations();
      debugPrint('Locations loaded: ${locs.length}');
      if (mounted) {
        setState(() {
          _locations = locs;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading locations: $e');
      if (mounted) setState(() => _loading = false);

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load branches: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // GPS sort  only called when user taps "Use my location"
  Future<void> _detectLocation() async {
    setState(() {
      _locating = true;
      _gpsError = null;
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _locating = false;
          _gpsError = 'Location permission denied. Select a branch manually.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);

      final locs =
          await ApiService.getLocations(lat: pos.latitude, lng: pos.longitude);

      if (!mounted) return;
      setState(() {
        _locations = locs;
        _selected = locs.isNotEmpty ? locs.first : _selected;
        _locationUsed = true;
        _locating = false;
        _gpsError = null;
      });

      AppToast.info(context, 'Branches sorted by distance');
    } catch (_) {
      if (mounted) {
        setState(() {
          _locating = false;
          _gpsError = 'Could not get location. Select a branch manually.';
        });
      }
    }
  }

  void _clearGps() => _loadLocations();

  void _confirmBranch() {
    if (_selected == null) {
      AppToast.error(context, 'Please select a branch to continue');
      return;
    }
    context.read<CartProvider>().setLocation(_selected!.id, _selected!.name);
    context.read<MenuProvider>().setSelectedLocation(_selected!.id);
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.background),
      floatingActionButton: const CartFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(AppColors.primaryDark),
                    Color(AppColors.primary)
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose Your Branch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick a location manually or tap below to sort by distance',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── GPS toggle button ────────────────────────────
                  GestureDetector(
                    onTap: _locating
                        ? null
                        : (_locationUsed ? _clearGps : _detectLocation),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _locationUsed
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_locating)
                            const SizedBox(
                              width: 15,
                              height: 15,
                              child: PizzaSpinner(size: 20, color: Colors.white),
                            )
                          else
                            Icon(
                              _locationUsed
                                  ? Icons.my_location
                                  : Icons.location_searching,
                              size: 17,
                              color: _locationUsed
                                  ? const Color(AppColors.primary)
                                  : Colors.white,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _locating
                                ? 'Detecting location...'
                                : _locationUsed
                                    ? 'Sorted by distance'
                                    : 'Use my location',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _locationUsed
                                  ? const Color(AppColors.primary)
                                  : Colors.white,
                            ),
                          ),
                          if (_locationUsed) ...[
                            const SizedBox(width: 10),
                            Icon(
                              Icons.close,
                              size: 14,
                              color: const Color(AppColors.primary)
                                  .withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(AppColors.primary)
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // GPS error message
                  if (_gpsError != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.orangeAccent, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _gpsError!,
                            style: const TextStyle(
                                color: Colors.orangeAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Branch list ──────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: PizzaSpinner(size: 40))
                  : _locations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sentiment_dissatisfied_rounded,
                                  size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                'No branches found',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          itemCount: _locations.length,
                          itemBuilder: (context, index) {
                            final loc = _locations[index];
                            final isSelected = _selected?.id == loc.id;
                            final isNearest = _locationUsed && index == 0;

                            return GestureDetector(
                              onTap: () => setState(() => _selected = loc),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(AppColors.primary)
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? const Color(AppColors.primary)
                                              .withValues(alpha: 0.12)
                                          : Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      // Store icon
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(AppColors.primary)
                                                  .withValues(alpha: 0.1)
                                              : Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.store_rounded,
                                          color: isSelected
                                              ? const Color(AppColors.primary)
                                              : Colors.grey.shade400,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Name / address / meta
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Expanded(
                                                child: Text(
                                                  loc.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    color: isSelected
                                                        ? const Color(
                                                            AppColors.primary)
                                                        : const Color(AppColors
                                                            .textPrimary),
                                                  ),
                                                ),
                                              ),
                                              if (isNearest)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 7,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                            AppColors.success)
                                                        .withValues(alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: const Text(
                                                    'Nearest',
                                                    style: TextStyle(
                                                      color: Color(
                                                          AppColors.success),
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                            ]),
                                            const SizedBox(height: 3),
                                            Text(
                                              loc.address,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade500,
                                                height: 1.4,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (loc.phone != null ||
                                                loc.distanceKm != null) ...[
                                              const SizedBox(height: 5),
                                              Row(children: [
                                                if (loc.phone != null) ...[
                                                  Icon(Icons.phone_outlined,
                                                      size: 11,
                                                      color:
                                                          Colors.grey.shade400),
                                                  const SizedBox(width: 3),
                                                  Text(loc.phone!,
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .grey.shade500)),
                                                ],
                                                if (loc.phone != null &&
                                                    loc.distanceKm != null)
                                                  const SizedBox(width: 10),
                                                if (loc.distanceKm != null) ...[
                                                  Icon(Icons.near_me_outlined,
                                                      size: 11,
                                                      color:
                                                          Colors.grey.shade400),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '${loc.distanceKm!.toStringAsFixed(1)} km away',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey.shade500),
                                                  ),
                                                ],
                                              ]),
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Selected check
                                      if (isSelected)
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: const BoxDecoration(
                                            color: Color(AppColors.primary),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check,
                                              color: Colors.white, size: 13),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // ── Confirm bar ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selected != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        const Icon(Icons.location_on,
                            color: Color(AppColors.primary), size: 15),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Selected: ${_selected!.name}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(AppColors.primary),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _selected == null ? null : _confirmBranch,
                      child: Text(
                        _selected == null
                            ? 'Select a Branch'
                            : 'Continue with ${_selected!.name}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
