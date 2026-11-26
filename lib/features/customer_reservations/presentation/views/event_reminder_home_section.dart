import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/customer_reservations/data/model/customer_event_request.dart';
import 'package:new_coffee/features/customer_reservations/presentation/views/my_reservations_page.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

class EventReminderHomeSection extends StatelessWidget {
  const EventReminderHomeSection({super.key, required this.reminders});

  final List<CustomerEventRequest> reminders;

  @override
  Widget build(BuildContext context) {
    final event = reminders.first;
    final start = (event.quotedStartAt ?? event.preferredStartAt).toLocal();
    final date =
        '${start.year}/${start.month.toString().padLeft(2, '0')}/${start.day.toString().padLeft(2, '0')} · ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final imageUrl = event.quotedSpaceImageUrl?.trim() ?? '';
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: .34),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r18),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .22),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context).pushNamed(MyReservationsPage.routeName),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.px14),
          child: Row(
            children: [
              Container(
                width: AppSizes.px46,
                height: AppSizes.px46,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.r14),
                ),
                child: Icon(
                  AppIcons.calendar,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: AppSizes.px12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.occasionName?.trim().isNotEmpty == true
                          ? 'تذكير: ${event.occasionName}'
                          : 'تذكير بمناسبتك القادمة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: AppFontWeights.bold),
                    ),
                    const SizedBox(height: AppSizes.px5),
                    Text(
                      '${event.branchName} · $date',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (imageUrl.isNotEmpty) ...[
                const SizedBox(width: AppSizes.px10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                  child: DbImage(
                    image: imageUrl,
                    width: AppSizes.px62,
                    height: AppSizes.px62,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
