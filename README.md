<div align="center">

<img src="assets/logo.png" width="160" height="160" />

# 📸 Ragalahari Image Gallery Downloader

### Flutter App to Download Celeb Albums from Ragalahari.com

[![GitHub release](https://img.shields.io/github/v/release/DevSon1024/ragalahari_downloader_2025?label=Release&logo=github)](https://github.com/DevSon1024/ragalahari_downloader_2025/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/DevSon1024/ragalahari_downloader_2025/total?logo=github)](https://github.com/DevSon1024/ragalahari_downloader_2025/releases)
[![License: MIT](https://img.shields.io/github/license/DevSon1024/ragalahari_downloader_2025)](LICENSE)

</div>

---

## 📱 Screenshots

<div align="center">
<img src="screenshots/homePage.jpg" width="30%" />
<img src="screenshots/celebritiesPage.jpg" width="30%" />
<img src="screenshots/celebrityGalleriesPage.jpg" width="30%" />
<img src="screenshots/downloaderPage.jpg" width="30%" />
<img src="screenshots/downloadsPage.jpg" width="30%" />
<img src="screenshots/historyPage.jpg" width="30%" />
<img src="screenshots/latestActresses.jpg" width="30%" />
<img src="screenshots/linkHistoryPage.jpg" width="30%" />

</div>

---

## ✨ Overview

**Ragalahari Gallery Downloader** is a Flutter-based Android app that lets you explore and download image galleries of your favorite celebrities from [Ragalahari.com](https://www.ragalahari.com).

This app supports gallery previews, celebrity management via CSV and JSON, bulk downloads, and download history — all built with a **mobile-first approach** and sleek UI.

---

## 🌟 Features

- **Latest Celebrity Albums** with preview
- **Celebrity Explorer** – Browse by actress/model
- **Gallery Downloader** – Paste a gallery URL and download all images
- ✅ Select individual images before downloading (optional)
- **Download Manager** – Pause, resume, cancel downloads
- **History Viewer** – Sort, delete, and share past downloads
- **Favorites Tab** – Save your favorite celebrities and albums
- **Display Settings** – Light/Dark mode
- **Storage Settings** – Set your download folder
- **CSV-JSON based Celebrity Management**

---

## 🧪 How It Works

1. Paste a gallery URL from Ragalahari into the downloader.
2. The app fetches all image previews.
3. Select individual or all images and hit download.
4. Manage, view, or share downloads from the History tab.

---

## 🛠 Tech Stack

- **Flutter & Dart**
- **Dio, Http, HTML Parsing**
- **Provider for State Management**
- **Permission Handler & Path Provider**
- **Mobile-First Responsive UI**

---

## 📁 Folder Structure

```text
ragalahari_downloader_2025/
├── android/
├── assets/
│   ├── data/
│   │   ├── Fetched_Albums_StarZone.json
│   │   └── Fetched_StarZone_Data.csv
│   └── images/
│       ├── logo.png
│       └── logo2.png
├── ios/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── permissions/
│   │   │   └── permissions.dart
│   │   └── utils/
│   ├── features/
│   │   ├── celebrity/
│   │   │   ├── data/
│   │   │   │   └── celebrity_repository.dart
│   │   │   ├── ui/
│   │   │   │   ├── celebrity_list_page.dart
│   │   │   │   ├── gallery_links_page.dart
│   │   │   │   ├── latest_actor_and_actress.dart
│   │   │   │   └── latest_celebrity.dart
│   │   │   └── utils/
│   │   │       ├── celebrity_image_cache.dart
│   │   │       └── celebrity_utils.dart
│   │   ├── downloader/
│   │   │   └── ui/
│   │   │       ├── download_manager_page.dart
│   │   │       ├── link_history_page.dart
│   │   │       └── ragalahari_downloader.dart
│   │   ├── history/
│   │   │   └── ui/
│   │   │       ├── history_full_image_viewer.dart
│   │   │       ├── history_page.dart
│   │   │       └── recycle_page.dart
│   │   ├── home/
│   │   │   └── ui/
│   │   │       └── home_page.dart
│   │   └── settings/
│   │       └── ui/
│   │           ├── contact_us_page.dart
│   │           ├── display_settings_page.dart
│   │           ├── favourite_page.dart
│   │           ├── history_settings.dart
│   │           ├── notification_settings_page.dart
│   │           ├── privacy_policy_page.dart
│   │           ├── settings_page.dart
│   │           ├── storage_settings.dart
│   │           └── update_database_page.dart
│   └── shared/
│       └── widgets/
│           ├── grid_utils.dart
│           ├── theme_config.dart
│           └── theme_notifier.dart
├── linux/
├── macos/
├── screenshots/
│   ├── celebrities.jpg
│   ├── celebrity_galleries.jpg
│   ├── display_setting.jpg
│   ├── downloader.jpg
│   ├── favourites.jpg
│   ├── history.jpg
│   ├── home.jpg
│   └── link_history.jpg
├── test/
│   └── widget_test.dart
├── web/
└── windows/
```

---

## ⬇️ Download

- [GitHub Releases](https://github.com/DevSon1024/ragalahari_downloader_2025/releases)
- F-Droid / Play Store (Coming soon)

---

## 💬 Feedback & Contributions

Found a bug or have a feature request?  
Open an [issue](https://github.com/DevSon1024/ragalahari_downloader_2025/issues) on GitHub.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

---

<div align="right">

[↑ Back to Top](#📸-ragalahari-image-gallery-downloader)

</div>
