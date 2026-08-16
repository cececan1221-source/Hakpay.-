# HakPay — Release Review (İnceleme Paketi)

**Tarih:** 16 Ağustos 2026  
**İncelenen sürüm:** MVP Kapalı Test + Premium UI  
**Geliştirici:** Cemalcan · Paradox Manga stratejik destek

---

## 1. Paket özeti

Bu paket Flutter istemci iskeletini, demo servis katmanını, premium Cyber-Manga arayüzünü ve yayın öncesi yasal metin taslaklarını içerir.

| Bileşen | Durum |
|---------|--------|
| `lib/` kaynak kod | Var |
| `assets/hakpay_logo.png` | Var |
| `docs/PRIVACY_POLICY.md` / `TERMS.md` | Son kullanıcı metni hazır |
| GitHub Actions APK pipeline | Çalışır durumda doğrulandı |
| `android/` klasörü (kaynakta) | Yok — CI `flutter create` ile üretir |
| Production backend | Yok |
| Canlı AdMob / offerwall / çekim | Yok (demo) |

## 2. Bu inceleme turunda doğrulananlar

1. **Branding:** HakPay logosu ve marka metinleri tutarlı.  
2. **UI:** Ana Sayfa, Görevler, Kazan, Bakiye, Profil; glass / neon dark tema.  
3. **Ekonomi kuralları (istemci demo):**  
   - 1000 puan ≈ 1 TL  
   - Üçlü reklam döngüsü = 60 puan  
   - Offerwall / anket kullanıcı payı %35 (gösterim)  
   - Mağaza: 30 UC / 30.000 puan, 60 UC / 55.000 puan  
4. **Nakit çekim:** UI’da bilinçli olarak kısıtlı / “YAKINDA”.  
5. **Güvenlik ilkesi:** API secret istemciye gömülmez; ödül referans kimliği ile tekrar koruması hedeflenir.  
6. **CI:** Actions ile `app-release.apk` artifact üretimi başarı ile alınmıştır.  
7. **Yasal:** `PRIVACY_POLICY.md` ve `TERMS.md` kapalı test ve mağaza URL’si için doldurulmuş metinlerdir (avukat onayı hâlâ önerilir).

## 3. Bilinen sınırlar / riskler

- Demo modda puanlar **cihaz / bellek içi** mantığa bağlıdır; production’da sunucu otoritedir.  
- Klasör yapısı telefonda kökte dağınık yüklenmişse CI “Fix folder structure” adımı düzeltir; kalıcı çözüm doğru `lib/` düzenidir.  
- Native `google_mobile_ads` / `in_app_purchase` kapalı test build’inde bilinçli sadeleştirilmiştir; production’da yeniden eklenip test edilmelidir.  
- Play Data safety ve hesap silme UX’i mağaza formunda ayrıca doldurulmalıdır.

## 4. İnceleme adımları (tekrarlanabilir)

1. `flutter pub get`  
2. `flutter analyze`  
3. `flutter test` (ekonomi testleri)  
4. Demo giriş: `demo@hakpay.app` / `demo1234`  
5. Görev tamamla → bakiye / işlem listesi  
6. Üçlü reklam simülasyonu → +60 puan  
7. Mağaza UC talebi (reklam şartı ile)  
8. Profil → Hakkında / çıkış  
9. Release: GitHub Actions → **hakpay-apk** artifact  

## 5. Onay matrisi

| Rol | Soru | Sonuç |
|-----|------|--------|
| Ürün | Kapalı test için UI ve ekonomi anlatımı yeterli mi? | Evet (demo) |
| Teknik | APK üretilebiliyor mu? | Evet (CI) |
| Hukuk | Metinler mağaza URL’sine konmaya hazır mı? | Metin hazır; avukat + URL hosting şart |
| Operasyon | Canlı ödeme / çekim var mı? | Hayır |

## 6. Sonraki sprint önerisi

1. Backend + `HAKPAY_API_BASE`  
2. AdMob / offerwall production + postback  
3. Uygulama içi hesap silme  
4. Gizlilik / şartlar için sabit HTTPS sayfaları  
5. Play Console Data safety + imzalama  
6. Kapalı test grubu (internal testing)  

---

**İnceleme notu:** Bu paket “yatırımcıya gösterilebilir MVP istemci + süreç” seviyesindedir; “canlı para çeken fintech” seviyesinde değildir.
