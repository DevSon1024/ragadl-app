import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:ragadl/features/downloader/ui/download_manager_page.dart';

class NotificationController {
  static const int batchNotificationId = 1001;
  static const int completeNotificationId = 1002;
  static const String channelKey = 'download_channel';

  static Future<void> showBatchProgress({
    required int completed,
    required int total,
    required String galleryName,
    bool isPaused = false,
  }) async {
    final label = isPaused ? 'Paused' : 'Downloading';
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: batchNotificationId,
        channelKey: channelKey,
        title: '$label · $galleryName',
        body: '$completed of $total completed',
        notificationLayout: NotificationLayout.ProgressBar,
        progress: total > 0 ? ((completed / total) * 100).toDouble() : 0,
        locked: true,
        autoDismissible: false,
        category: NotificationCategory.Progress,
      ),
      actionButtons: [
        NotificationActionButton(
          key: isPaused ? 'resume_all' : 'pause_all',
          label: isPaused ? 'Resume' : 'Pause',
          actionType: ActionType.KeepOnTop,
        ),
        NotificationActionButton(
          key: 'cancel_all',
          label: 'Cancel',
          actionType: ActionType.KeepOnTop,
        ),
      ],
    );
  }

  static Future<void> showBatchComplete({
    required String galleryName,
    required int completed,
    required int failed,
    required String folderPath,
  }) async {
    await AwesomeNotifications().cancel(batchNotificationId);
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: completeNotificationId,
        channelKey: channelKey,
        title: '$galleryName Downloaded',
        body: '$completed saved to $folderPath'
            '${failed > 0 ? " ($failed failed)" : ""}',
        notificationLayout: NotificationLayout.Default,
        autoDismissible: true,
        locked: false,
        payload: {'action': 'open_folder', 'path': folderPath},
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'dismiss',
          label: 'Dismiss',
          actionType: ActionType.DismissAction,
        ),
      ],
    );
  }

  static Future<void> cancelBatchNotification() async {
    await AwesomeNotifications().cancel(batchNotificationId);
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    final key = receivedAction.buttonKeyPressed;
    final manager = DownloadManager();
    if (key == 'pause_all') {
      manager.pauseAll();
    } else if (key == 'resume_all') {
      manager.resumeAll();
    } else if (key == 'cancel_all') {
      manager.cancelAll();
      await cancelBatchNotification();
    }
  }
}
