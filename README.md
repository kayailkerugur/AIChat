# AI Chat — Native macOS AI Sohbet Uygulaması

SwiftUI ile geliştirilmiş, OAuth 2.0 (PKCE) girişli, streaming yanıtlı ve Core Data kalıcılıklı native macOS sohbet istemcisi. 30 günlük staj projesi kapsamında geliştirilmiştir.

## Özellikler

- Google hesabıyla OAuth 2.0 Authorization Code + PKCE girişi (`ASWebAuthenticationSession`)
- Gemini ile gerçek zamanlı streaming yanıtlar (SSE); devam eden yanıtı durdurma ve yeniden üretme
- Çoklu konuşma: sidebar, arama (başlık + mesaj içeriği), yeniden adlandırma, cascade silme
- Markdown ve kod bloğu render'ı (yatay kaydırma + kopyalama)
- Core Data kalıcılığı — konuşmalar uygulama yeniden açıldığında geri yüklenir
- Değiştirilebilir AI katmanı: Gemini ve Mock sağlayıcı bir registry arkasında, Settings'ten seçilebilir
- Token ve API anahtarları yalnızca Keychain'de; oturum yenileme ve güvenli logout

## Gereksinimler

- macOS 14 (Sonoma) veya üzeri
- Xcode 15 veya üzeri
- Bir Google hesabı (OAuth girişi ve Gemini API anahtarı için)

## Kurulum

### 1. Projeyi açın

```
git clone <repo-url>
open AIChat.xcodeproj
```

### 2. App Sandbox ağ izni

Proje entitlements dosyasında **Outgoing Connections (Client)** izni açık gelir (`com.apple.security.network.client`). Temiz bir kopyada bu izin kapalıysa: Target → Signing & Capabilities → App Sandbox → Network → **Outgoing Connections (Client)** kutusunu işaretleyin.

> Bu izin olmadan tüm ağ istekleri DNS aşamasında `-1003 (hostname could not be found)` hatasıyla düşer — hata mesajı yanıltıcıdır, sorun DNS değil sandbox iznidir. Hem Gemini istekleri hem `ASWebAuthenticationSession` bu izne muhtaçtır.

### 3. Google OAuth yapılandırması (zorunlu)

Uygulama, Google Cloud Console'da **iOS** tipinde bir OAuth client kaydı bekler (macOS native uygulamaları için de bu tip kullanılır; public client + PKCE destekler, client secret gerektirmez).

1. [console.cloud.google.com](https://console.cloud.google.com) → yeni proje oluşturun.
2. **OAuth consent screen**: External seçin; scope olarak yalnızca `openid`, `email`, `profile` yeterlidir.
3. **Test users** bölümüne giriş yapacağınız Gmail adres(ler)ini ekleyin. Uygulama "verified" olmadığı için yalnızca test kullanıcıları giriş yapabilir; login sırasında görülen **"Google hasn't verified this app"** uyarısı bu modda normaldir — *Continue* ile devam edilir.
4. **Credentials → Create Credentials → OAuth client ID → iOS**: Bundle ID olarak Xcode'daki bundle identifier'ı girin (birebir aynı olmalı; uyuşmazlık `redirect_uri_mismatch` hatası üretir).
5. Oluşan **Client ID** değerini (`XXXX.apps.googleusercontent.com`) kopyalayın.

#### Client ID'yi projeye tanıtma

`Infrastructure/Configuration/AppEnvironment.swift` içindeki `googleOAuth` yapılandırmasında `clientID` alanına kendi değerinizi yazın:

```swift
clientID: "XXXX.apps.googleusercontent.com",
```

> Client ID, public client mimarisinde **secret değildir** — binary içinde taşınması tasarım gereğidir; akışı koruyan şey PKCE'dir. Buna karşın access/refresh token'lar ve API anahtarları hiçbir zaman kaynak kodda, plist'te veya UserDefaults'ta bulunmaz; yalnızca Keychain'de saklanır.

#### Redirect URI ve URL scheme kaydı

Google, iOS/macOS client'larında geri dönüş adresi olarak **reversed client ID** formatını kullanır:

| Değer | Format | Örnek |
|---|---|---|
| Client ID | `XXXX.apps.googleusercontent.com` | `1234-abc.apps.googleusercontent.com` |
| URL scheme (reversed) | `com.googleusercontent.apps.XXXX` | `com.googleusercontent.apps.1234-abc` |
| Redirect URI | `{reversed}:/oauth2redirect` | `com.googleusercontent.apps.1234-abc:/oauth2redirect` |

Kod tarafında redirect URI, `AppEnvironment` içinde client ID'den **otomatik türetilir** — elle girilmez, böylece iki değer birbirinden kopamaz.

### 4. Gemini API anahtarı

Anahtar **kod içinde değil, uygulama içinde** yapılandırılır:

1. [aistudio.google.com/apikey](https://aistudio.google.com/apikey) adresinden ücretsiz bir API anahtarı oluşturun.
2. Uygulamayı çalıştırın, giriş yapın, Ayarlar'ı açın.
3. Anahtarı ilgili alana yapıştırıp **Kaydet**'e basın — anahtar Keychain'e yazılır ve bir daha ekranda gösterilmez ("Kayıtlı (Keychain)" durumu görünür).

Anahtar girilmeden mesaj gönderilirse uygulama sizi Ayarlar'a yönlendiren bir hata gösterir. Anahtarsız denemek için Ayarlar'dan **Mock (Test)** modellerinden biri seçilebilir — mock sağlayıcı ağ olmadan sahte streaming yanıtlar üretir.

## Çalıştırma

Şemayı seçip **⌘R**. İlk açılışta Login ekranı gelir; "Giriş Yap" sistem tarayıcı oturumu açar (parola uygulamaya asla girmez). Girişten sonra oturum Keychain üzerinden korunur — sonraki açılışlarda login ekranı atlanır. Ayarlar → Çıkış Yap tüm yerel kimlik bilgilerini temizler.

## Testler

**⌘U** ile çalıştırılır (ya da `xcodebuild test -scheme AIChat`). ~44 unit test şu alanları kapsar:

| Alan | İçerik |
|---|---|
| Markdown parser | Fence ayrıştırma, streaming sırasında kapanmamış fence |
| Core Data repository | CRUD, sıralama, arama, **cascade delete**, açılışta yarım stream onarımı (in-memory persistent store ile) |
| ChatViewModel | Streaming yaşam döngüsü, iptal, hata, çakışan istek engelleme, auto-title |
| SSE parser | Event sınırları, çok satırlı data, yorum satırları |
| PKCE | RFC 7636 Appendix B resmi test vektörü, karakter seti, benzersizlik |
| OAuth callback | Kod çıkarımı, **state mismatch reddi (güvenlik testi)**, kullanıcı iptali |
| RootViewModel | Session'a göre yönlendirme, oturum süresi dolması senaryosu |

## Mimari

Dört katman, tek yönlü bağımlılık: **Presentation → Domain ← Data / Infrastructure**. View katmanı `URLSession`, Keychain veya `NSManagedObjectContext`'e asla doğrudan dokunmaz; tüm somut tipler yalnızca `AppDependencies` (composition root) içinde oluşturulur. Ayrıntılar, karar gerekçeleri ve ekran akış şeması için: [`docs/teknik-tasarim-notu.md`](docs/teknik-tasarim-notu.md). OAuth akışının adım adım diyagramı: [`docs/oauth-akis-diyagrami.md`](docs/oauth-akis-diyagrami.md).

## Bilinen eksikler ve sonraki geliştirmeler

- Kod bloklarında syntax highlighting yok (bilinçli kapsam sınırı)
- Ayarlar'daki API anahtarı bölümü Gemini'ye özel; üçüncü bir gerçek sağlayıcıda sağlayıcı başına alan gerekir
- Token kullanım bilgisi (`usage` event'i) üretiliyor ancak arayüzde gösterilmiyor
- Sidebar yenilemesi callback tabanlı; store-driven güncellemeye taşınabilir
