
# 📸 Ragalahari Image Gallery Downloader - Flutter App

This Flutter-based Android app allows users to download image galleries from [Ragalahari.com](https://www.ragalahari.com). It offers gallery previews, individual/bulk image downloads, favorite celebrity tracking, a smart download manager, history viewer, theme customization, and more — all with a mobile-first design approach!

---

## 🚀 Features

- 🔥 **Latest Celebrity Albums** with preview
- 👩‍🎤 **Celebrity Explorer** – Browse by actress/model
- 📥 **Gallery Downloader** – Paste a gallery URL and download all images
- ✅ Select individual images before downloading (If Wanted)
- 📊 **Download Manager** – Pause, resume, cancel downloads
- 🕘 **History Page** – View, sort, delete, and share downloaded albums
- ❤️ **Favorites Tab** – Save your favorite celebrities and albums
- 🎨 **Themes & Display Settings** – Light/Dark mode with color themes
- 💾 **Storage Settings** – Set your custom download folder
- 📁 **Database Updater** – Update celebrity CSV data
- 📎 **CSV-based Celebrity Management**

---

## 📸 Screenshots

| Home Page | Celebrity Page | Downloader | History Page |
|----------|----------------|------------|---------------|
| ![Home](screenshots/home.jpg) | ![Celebrity](screenshots/celebrity.jpg) | ![Downloader](screenshots/downloader.jpg) | ![History](screenshots/history.jpg) |

---

## 🛠️ Setup & Installation

### 1. Clone the repository
```bash
git clone https://github.com/DevSon1024/ragalahari_downloader_2025.git
cd ragalahari_downloader_2025
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Run the app
```bash
flutter run
```

> ✅ Ensure that your emulator or Android device is connected.

---

## 🧩 Dependencies

Key Flutter packages used:
- `http`
- `html`
- `permission_handler`
- `path_provider`
- `dio`
- `provider`
- `url_launcher`
- `file_picker`
- `csv`

*(You can check full list in `pubspec.yaml`)*

---

## 📁 Folder Structure (Important Screens & Pages)

```text
/lib
│
├── main.dart                          # Entry point/# Latest albums and social links
├──settings_sidebar.dart
├──models/
│   ├──image_data.dart
├──pages/
│   ├──celebrity_list_page.dart        # All celebrity listing
│   ├──download_mangager_page.dart     # Shows download status (pause/resume)
│   ├──history_page.dart               # Downloaded image history
│   ├──latest_celebrity.dart
│   ├──ragalahari_downloader.dart      # Input gallery URL + download
├──screens/
│   ├──ragalahari_downloader_screen.dart    
├──widgets/
│   ├──navbar.dart
│   ├──theme_config.dart         
├── settings/
│   ├── display_settings_page.dart
│   ├── storage_settings.dart
│   ├── favourite_page.dart
│   └── privacy_policy_page.dart
│   ├──update_database_page.dart
```


---

## 🧠 Author

**Devson** – Flutter & Python Developer  
📧 *dpsonawane789@gmail.com*  
🌐 [Ragalahari.com (reference site)](https://www.ragalahari.com)

---

## 📝 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## 🌟 Show Some Love!

If you like this app, don’t forget to ⭐ the repo and share it!
