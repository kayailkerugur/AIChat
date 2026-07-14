# AI Chat — Native macOS AI Sohbet Uygulaması

SwiftUI ile geliştirilmiş, OAuth 2.0 (PKCE) girişli, streaming yanıtlı ve Core Data kalıcılıklı native macOS sohbet istemcisi. 30 günlük staj projesi kapsamında geliştirilmiştir.

## Özellikler

- Google hesabıyla OAuth 2.0 Authorization Code + PKCE girişi (`ASWebAuthenticationSession`)
- OpenAI-compatible sağlayıcılarla gerçek zamanlı streaming yanıtlar; devam eden yanıtı durdurma ve yeniden üretme
- Çoklu konuşma: sidebar, arama (başlık + mesaj içeriği), yeniden adlandırma, cascade silme
- Markdown ve kod bloğu render'ı (yatay kaydırma + kopyalama)
- Görsel ve doküman ekleri: image dosyaları multimodal sağlayıcılara, PDF/text dokümanları çıkarılan metin olarak gönderilir
- Core Data kalıcılığı — konuşmalar uygulama yeniden açıldığında geri yüklenir
- Kullanıcı tarafından yönetilen AI sağlayıcıları: Gemini, OpenAI, Ollama, LM Studio veya özel OpenAI-compatible endpoint
- Token ve API anahtarları yalnızca Keychain'de; oturum yenileme ve güvenli logout

## Gereksinimler

- macOS 14 (Sonoma) veya üzeri
- Xcode 15 veya üzeri
- Bir Google hesabı (OAuth girişi için)
- En az bir AI sağlayıcı: Gemini/OpenAI API anahtarı veya yerel Ollama/LM Studio endpoint'i

## Kurulum

### 1. Projeyi açın

```
git clone <repo-url>
open AIChat.xcodeproj
```

### 2. App Sandbox ağ izni

Proje entitlements dosyasında **Outgoing Connections (Client)** izni açık gelir (`com.apple.security.network.client`). Temiz bir kopyada bu izin kapalıysa: Target → Signing & Capabilities → App Sandbox → Network → **Outgoing Connections (Client)** kutusunu işaretleyin.

> Bu izin olmadan tüm ağ istekleri DNS aşamasında `-1003 (hostname could not be found)` hatasıyla düşer — hata mesajı yanıltıcıdır, sorun DNS değil sandbox iznidir. Hem AI sağlayıcı istekleri hem `ASWebAuthenticationSession` bu izne muhtaçtır.

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

### 4. AI sağlayıcı ekleme

AI sağlayıcılar koddan değil, uygulama içindeki **Ayarlar** ekranından yönetilir. Her sağlayıcı için ad, base URL, API key gereksinimi ve model listesi kaydedilir. API anahtarları kaynak kodda veya UserDefaults'ta tutulmaz; her sağlayıcıya özel Keychain hesabına yazılır.

1. Uygulamayı çalıştırın, giriş yapın ve **Ayarlar**'ı açın.
2. Sol alttan **Ekle** ile yeni sağlayıcı oluşturun.
3. Sağlayıcı adı, base URL ve gerekirse API anahtarını girin.
4. **Modelleri Çek** ile `GET {baseURL}/models` çağrısından model listesini doldurun veya modelleri satır satır elle yazın.
5. **Varsayılan Model** bölümünden yeni sohbetlerde kullanılacak modeli seçin.

Örnek sağlayıcı ayarları:

| Sağlayıcı | Base URL | API anahtarı | Örnek modeller |
|---|---|---|---|
| Google Gemini | `https://generativelanguage.googleapis.com/v1beta/openai` | Gerekli | `gemini-2.5-flash-lite`, `gemini-2.5-flash` |
| OpenAI | `https://api.openai.com/v1` | Gerekli | `gpt-4o-mini`, `gpt-4o` |
| Ollama | `http://localhost:11434/v1` | Gerekmez | `llama3.2`, `llama3` |
| LM Studio | `http://localhost:1234/v1` | Gerekmez | LM Studio'da yüklediğiniz model id'si |

Not: ChatGPT Plus aboneliği OpenAI API kredisi yerine geçmez; OpenAI API için platform hesabında kredi/billing gerekir. Yerel ve ücretsiz deneme için Ollama + `llama3.2` en pratik seçenektir.

## Çalıştırma

Şemayı seçip **⌘R**. İlk açılışta Login ekranı gelir; "Giriş Yap" sistem tarayıcı oturumu açar (parola uygulamaya asla girmez). Girişten sonra oturum Keychain üzerinden korunur — sonraki açılışlarda login ekranı atlanır. Ayarlar → Çıkış Yap tüm yerel kimlik bilgilerini temizler.

## Ek Dosyalar

Composer'daki ataç butonu ile görsel, PDF ve metin tabanlı doküman eklenebilir. Görseller, uygulamanın görsel destekli olarak tanıdığı sağlayıcılarda OpenAI-compatible `image_url` content part olarak data URL biçiminde gönderilir. PDF ve text/json/csv dosyaları uygulama içinde metne çevrilir ve istek bağlamına text part olarak eklenir.

Ekler Core Data geçmişine mesajla birlikte kaydedilir. Sohbet yeniden açıldığında ek adları ve içerikleri geri yüklenir. Yerel LLM sağlayıcılarında görsel desteği kapalıysa görsel ekli mesaj gönderimi engellenir.

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

Dört katman, tek yönlü bağımlılık: **Presentation → Domain ← Data / Infrastructure**. View katmanı `URLSession`, Keychain veya `NSManagedObjectContext`'e asla doğrudan dokunmaz; tüm somut tipler yalnızca `AppDependencies` (composition root) içinde oluşturulur. AI katmanında production akış, `ProviderConfigStore` kayıtlarından `GenericAIProvider` örnekleri üretir; böylece yeni OpenAI-compatible sağlayıcı eklemek için kod değişikliği gerekmez.

## Bilinen eksikler ve sonraki geliştirmeler

- Kod bloklarında syntax highlighting yok (bilinçli kapsam sınırı)
- Token kullanım bilgisi (`usage` event'i) üretiliyor ancak arayüzde gösterilmiyor
- Sidebar yenilemesi callback tabanlı; store-driven güncellemeye taşınabilir
- Word/Excel gibi zengin dokümanlardan metin çıkarımı henüz desteklenmiyor
