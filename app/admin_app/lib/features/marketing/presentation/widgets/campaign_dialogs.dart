import 'package:material_ui/material_ui.dart';

import 'package:admin_app/features/marketing/domain/entities/marketing_entities.dart';
import 'package:admin_app/features/marketing/presentation/manager/marketing_cubit.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

Future<void> showCampaignCreateDialog(
  BuildContext context,
  MarketingCubit cubit,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CampaignCreateDialog(cubit: cubit),
  );
}

class _CampaignCreateDialog extends StatelessWidget {
  const _CampaignCreateDialog({required this.cubit});
  final MarketingCubit cubit;

  @override
  Widget build(BuildContext context) {
    final name = TextEditingController();
    String channel = 'push';
    String purpose = 'promotions';
    return AlertDialog(
      title: const Text('New campaign'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTextFormField(hint: 'Campaign name', controller: name),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: channel,
            items: const [
              DropdownMenuItem(value: 'push', child: Text('Push')),
              DropdownMenuItem(value: 'email', child: Text('Email')),
            ],
            onChanged: (v) => channel = v ?? 'push',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: purpose,
            items: const [
              DropdownMenuItem(value: 'promotions', child: Text('Promotions')),
              DropdownMenuItem(value: 'offers', child: Text('Offers')),
              DropdownMenuItem(
                value: 'loyalty_marketing',
                child: Text('Loyalty marketing'),
              ),
            ],
            onChanged: (v) => purpose = v ?? 'promotions',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        CustomBtn(
          text: 'Create draft',
          onPressed: () async {
            final n = name.text.trim();
            if (n.isEmpty) return;
            await cubit.createCampaign(
              name: n,
              channel: channel,
              purpose: purpose,
            );
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

Future<void> showCampaignDetailSheet(
  BuildContext context,
  MarketingCubit cubit,
  MarketingCampaign campaign,
  dynamic permissions,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CampaignDetailSheet(cubit: cubit, campaign: campaign),
  );
}

class _CampaignDetailSheet extends StatelessWidget {
  const _CampaignDetailSheet({required this.cubit, required this.campaign});
  final MarketingCubit cubit;
  final MarketingCampaign campaign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(campaign.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '${campaign.channel} • ${campaign.purpose} • ${campaign.status.name}',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CustomBtn(
                text: 'Add version',
                onPressed: () => _showVersionForm(context),
              ),
              CustomBtn(
                text: 'Submit for review',
                onPressed: () => cubit.submitForReview(campaign.id),
              ),
              CustomBtn(
                text: 'Approve',
                onPressed: () => cubit.approve(campaign.id),
              ),
              CustomBtn(
                text: 'Return to draft',
                onPressed: () => cubit.returnToDraft(campaign.id),
              ),
              CustomBtn(
                text: 'Schedule',
                onPressed: () => _showScheduleForm(context),
              ),
              CustomBtn(
                text: 'Cancel campaign',
                onPressed: () => cubit.cancel(campaign.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showVersionForm(BuildContext context) {
    final titleAr = TextEditingController();
    final titleEn = TextEditingController();
    final bodyAr = TextEditingController();
    final bodyEn = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New campaign version'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextFormField(hint: 'Title AR', controller: titleAr),
            CustomTextFormField(hint: 'Title EN', controller: titleEn),
            CustomTextFormField(
              hint: 'Body AR',
              controller: bodyAr,
              maxLines: 3,
            ),
            CustomTextFormField(
              hint: 'Body EN',
              controller: bodyEn,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CustomBtn(
            text: 'Save draft version',
            onPressed: () async {
              await cubit.createVersion(
                campaignId: campaign.id,
                titleAr: titleAr.text.trim(),
                titleEn: titleEn.text.trim(),
                bodyAr: bodyAr.text.trim(),
                bodyEn: bodyEn.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showScheduleForm(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        DateTime when = DateTime.now().add(const Duration(hours: 1));
        return AlertDialog(
          title: const Text('Schedule campaign'),
          content: Text(
            'Sends at ${when.toLocal()} (changeable in a later revision). '
            'Audience will be frozen at schedule time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            CustomBtn(
              text: 'Schedule',
              onPressed: () async {
                await cubit.schedule(campaign.id, when);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        );
      },
    );
  }
}
