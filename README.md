# Suno AI Şarkı İndirici (Android APK) 📱

Suno AI üzerinde oluşturulan şarkıları doğrudan Android telefonunuza indiren, şık ve modern bir **Flutter** mobil uygulaması.

---

## ✨ Özellikler

- **Kotaya Takılmaz:** Suno indirme kotasından bağımsız olarak, doğrudan CDN üzerinden şarkıları deşifre ederek indirir.
- **Desteklenen Formatlar:** MP3 (320 kbps), M4A (Orijinal Ses), WAV (Kayıpsız) ve MP4 (Video Klip).
- **Otomatik Depolama & Paylaşım:** İndirilen dosyalar doğrudan telefonun `İndirilenler` (`Downloads/Suno_Downloads`) klasörüne kaydedilir ve tek tıkla müzik çalarlarda açılabilir veya WhatsApp ile paylaşılabilir.
- **Kanal Bağlantıları:** Aykırı Mısra ve Kürşat Alper ALKAÇIR YouTube ve Spotify kanallarına doğrudan erişim butonları.
- **Telif & İmzalar:** Sol altta "Yapımcı: Kürşat Alper ALKAÇIR", sağ altta "Aykırı Mısra Production".

---

## 🚀 Hazır `.apk` Dosyasını Nasıl Alabilirsiniz? (En Kolay Yol)

Bilgisayarınıza onlarca gigabaytlık Android Studio veya SDK kurmanıza **gerek yoktur**. Projenin içine otomatik bulut derleyicisi (**GitHub Actions**) entegre edilmiştir.

### Adım 1: GitHub'a Yükleyin
1. [github.com](https://github.com) üzerinde ücretsiz yeni bir repository (depo) oluşturun (örn: `suno-android`).
2. Bu klasörün (`suno_downloader_android`) içindeki dosyaları GitHub deponuza yükleyin (Git push veya web üzerinden sürükle-bırak).

### Adım 2: APK'nın Otomatik Derlenmesi
1. GitHub deponuzdaki **"Actions"** sekmesine tıklayın.
2. **"Build Android APK"** iş akışının otomatik olarak başladığını göreceksiniz.
3. Yaklaşık 2-3 dakika içinde derleme yeşil tik (`Success`) ile tamamlanır.

### Adım 3: İndirin ve Telefonunuza Yükleyin
1. Biten iş akışına tıklayın ve sayfanın altındaki **Artifacts (Yapı Parçaları)** bölümünden **`SunoDownloader-APK`** dosyasını indirin.
2. İçerisindeki **`SunoDownloader-release.apk`** dosyasını Android telefonunuza aktarıp dokunarak yükleyin.

---

## 💻 Kendi Bilgisayarınızda Derleme (Yerel Yöntem)

Eğer bilgisayarınızda Flutter ve Android SDK kurulu ise:

```bash
# Bağımlılıkları yükleyin
flutter pub get

# APK'yı derleyin
flutter build apk --release
```

Oluşan APK dosyası şu konumda olacaktır:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 👥 İletişim & Kanallar

- **Yapımcı:** Kürşat Alper ALKAÇIR (Tüm Hakları Saklıdır)
- **Yapım:** Aykırı Mısra Production
- **Aykırı Mısra:** [YouTube](https://www.youtube.com/channel/UCZH31WrVekNeldKMAD2fB7A) | [Spotify](https://open.spotify.com/intl-tr/artist/3GSbp9n7nO5OSAgyFJ7yfJ?si=R0NmYqubS1eCSPLubqFVpw)
- **Kürşat Alper ALKAÇIR:** [YouTube](https://www.youtube.com/channel/UCkpqBdHDBlerYE9TngEqSsQ) | [Spotify](https://open.spotify.com/intl-tr/artist/7eG4xDmU08SeMrkwrqAVJ7?si=qSMNn7kLQeG3wt4FhEgaHg)
