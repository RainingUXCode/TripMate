import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../models/trip.dart';
import '../services/trips_service.dart';
import '../widgets/trip_card.dart';
import '../widgets/tripmate_back_button.dart';
import 'trip_details_screen.dart';

class AllTripsScreen extends StatefulWidget {
  final TripsService? tripsService;
  final Future<void> Function()? onTripsRefresh;
  final Future<void> Function()? onNotificationsRefresh;

  const AllTripsScreen({
    super.key,
    this.tripsService,
    this.onTripsRefresh,
    this.onNotificationsRefresh,
  });

  @override
  State<AllTripsScreen> createState() => _AllTripsScreenState();
}

class _AllTripsScreenState extends State<AllTripsScreen> {
  late final TripsService _tripsService = widget.tripsService ?? TripsService();
  late final bool _ownsService = widget.tripsService == null;
  List<Trip> _trips = const [];
  String? _error;
  bool _loading = true;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  @override
  void dispose() {
    if (_ownsService) _tripsService.close();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    final generation = ++_requestGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final trips = await _tripsService.getTrips();
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _trips = trips;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _error = error is TripsServiceException
            ? error.message
            : 'Não foi possível carregar as viagens.';
        _loading = false;
      });
    }
  }

  TextStyle _style(double size, {FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        color: AppTheme.ink,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    'Todas as viagens',
                    style: _style(17, weight: FontWeight.w700),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: TripMateBackButton(
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE4E3EE)),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: _loadTrips,
                child: _content(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading && _trips.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 260,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          ),
        ],
      );
    }

    if (_error != null && _trips.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        children: [
          const SizedBox(height: 180),
          const Icon(Icons.cloud_off_outlined, size: 38, color: AppTheme.muted),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: _style(14)),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _loadTrips,
            child: Text(
              'Tentar novamente',
              style: _style(
                14,
                weight: FontWeight.w700,
              ).copyWith(color: AppTheme.primary),
            ),
          ),
        ],
      );
    }

    if (_trips.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        children: [
          const SizedBox(height: 170),
          const Icon(Icons.luggage_outlined, size: 42, color: AppTheme.primary),
          const SizedBox(height: 14),
          Text(
            'Você ainda não criou nenhuma viagem.',
            textAlign: TextAlign.center,
            style: _style(15, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Quando criar uma viagem, ela aparecerá aqui.',
            textAlign: TextAlign.center,
            style: _style(13).copyWith(color: AppTheme.muted),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      itemCount: _trips.length + (_error == null ? 1 : 2),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Suas viagens', style: _style(22, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                '${_trips.length} ${_trips.length == 1 ? 'viagem disponível' : 'viagens disponíveis'}',
                style: _style(13).copyWith(color: AppTheme.muted),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: _style(12).copyWith(color: AppTheme.muted),
                ),
              ],
            ],
          );
        }

        final tripIndex = index - 1;
        if (tripIndex >= _trips.length) {
          return TextButton.icon(
            onPressed: _loadTrips,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar atualizar'),
          );
        }
        final trip = _trips[tripIndex];
        return TripCard(trip: trip, onTap: () => _openTrip(trip));
      },
    );
  }

  Future<void> _openTrip(Trip trip) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TripDetailsScreen(
          tripId: trip.id,
          tripsService: _tripsService,
          onTripChanged: _onTripChanged,
        ),
      ),
    );
  }

  Future<void> _onTripChanged() async {
    await _loadTrips();
    await widget.onTripsRefresh?.call();
    await widget.onNotificationsRefresh?.call();
  }
}
