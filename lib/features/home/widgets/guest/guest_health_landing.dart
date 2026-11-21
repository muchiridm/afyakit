// lib/features/home/widgets/guest/guest_health_landing.dart

import 'package:flutter/material.dart';

class GuestHealthLanding extends StatelessWidget {
  const GuestHealthLanding({
    super.key,
    required this.appName,
    required this.occupationalHealthEnabled,
    required this.onGetStarted,
  });

  final String appName;
  final bool occupationalHealthEnabled;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final occupational = occupationalHealthEnabled;

    final primary = occupational
        ? const Color(0xFF173B4D)
        : const Color(0xFF102F34);

    final accent = occupational
        ? const Color(0xFFD1EDF5)
        : const Color(0xFFC8F3DA);

    final headline = occupational
        ? 'Healthy people.\nSafer workplaces.'
        : 'Your health.\nYour story.\nIn your hands.';

    final subtitle = occupational
        ? 'A connected health experience for occupational '
              'screening, health surveillance and follow-up.'
        : 'Bring your health records, results and everyday '
              'health measurements together in one place.';

    final benefits = occupational
        ? const [
            _Benefit(
              Icons.health_and_safety_outlined,
              'Occupational screening',
              'Follow medical assessments and screening outcomes.',
            ),
            _Benefit(
              Icons.monitor_heart_outlined,
              'Health surveillance',
              'Understand changes in health over time.',
            ),
            _Benefit(
              Icons.event_available_outlined,
              'Meaningful follow-up',
              'Keep track of reviews and recommendations.',
            ),
          ]
        : const [
            _Benefit(
              Icons.folder_shared_outlined,
              'Your health timeline',
              'Keep important health records together.',
            ),
            _Benefit(
              Icons.monitor_heart_outlined,
              'See your progress',
              'Follow your health measurements and trends.',
            ),
            _Benefit(
              Icons.shield_outlined,
              'Choose what to share',
              'Control access to your health information.',
            ),
          ];

    final cta = occupational
        ? 'Access your health journey'
        : 'Start your health journey';

    return Scaffold(
      backgroundColor: primary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                occupational
                                    ? Icons.health_and_safety_rounded
                                    : Icons.favorite_rounded,
                                color: accent,
                                size: 30,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  appName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 56),
                          Text(
                            occupational
                                ? 'OCCUPATIONAL HEALTH'
                                : 'PERSONAL HEALTH TRACKING',
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            headline,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 46,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Color(0xFFD6E8E5),
                              fontSize: 17,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 36),
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              for (final benefit in benefits)
                                _BenefitCard(benefit: benefit, accent: accent),
                            ],
                          ),
                          const SizedBox(height: 36),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: onGetStarted,
                              icon: const Icon(Icons.arrow_forward_rounded),
                              iconAlignment: IconAlignment.end,
                              label: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Text(cta),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: primary,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Center(
                            child: Text(
                              'Your health information deserves privacy.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFBCD5D5),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Benefit {
  const _Benefit(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.benefit, required this.accent});

  final _Benefit benefit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 285,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(benefit.icon, size: 30, color: accent),
          const SizedBox(height: 16),
          Text(
            benefit.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            benefit.description,
            style: const TextStyle(
              color: Color(0xFFD6E8E5),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
