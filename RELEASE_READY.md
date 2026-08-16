# HakPay — Yayın Hazırlık Kontrol Listesi

**Sürüm:** 1.0.0+1 (MVP · Kapalı Test)  
**Son gözden geçirme:** 16 Ağustos 2026

---

## A) Kod / pakette tamamlanan

- [x] HakPay branding ve logo (`assets/hakpay_logo.png`)
- [x] Cyber-Manga dark UI (Ana Sayfa, Görevler, Kazan, Bakiye, Profil)
- [x] Splash + Cemalcan / Paradox Manga prestij metni
- [x] Demo / remote service locator (`HAKPAY_API_BASE`)
- [x] Wallet, auth, withdrawal, ad, catalog, streak, referral, VIP sınırları
- [x] Ekonomi: 1000 puan ≈ 1 TL; üçlü reklam = 60 puan; offerwall %35 kullanıcı payı
- [x] Mağaza: 30 UC (30.000 puan), 60 UC (55.000 puan); nakit çekim UI’da kapalı / “YAKINDA”
- [x] Anket + “Oyun Oyna · Para Kazan” (offerwall) giriş noktaları
- [x] Secret’ların APK’ya gömülmemesi
- [x] GitHub Actions ile release APK üretimi (klasör düzeltme adımı dahil)
- [x] Gizlilik Politikası ve Kullanım Koşulları metinleri (`docs/PRIVACY_POLICY.md`, `docs/TERMS.md`)

## B) Kapalı test için yeterli kabul edilenler

- [x] Demo giriş ile uçtan uca akış (görev, reklam simülasyonu, mağaza talebi)
- [x] Nakit çekimin bilerek kapalı tutulması
- [x] Native AdMob / Play Billing’in build için opsiyonel / demo tutulması (Gradle riski azaltıldı)

## C) Production / açık yayın öncesi dışarıdan zorunlular

| Madde | Durum | Not |
|--------|--------|-----|
| Backend URL + production DB | Eksik | `HAKPAY_API_BASE` |
| AdMob production ID’leri | Eksik | Uygulama kimliği + rewarded |
| Anket / offerwall sağlayıcı + sunucu postback secret | Eksik | İstemciye secret yok |
| Play Console ürün ID’leri (VIP / abonelik) | Eksik | |
| Google Play App Signing / keystore | Eksik | |
| Mağaza listesi: Gizlilik + Şartlar URL’leri | Hazır metin / URL yok | Metinler `docs/` altında; HTTPS sayfaya konmalı |
| Hesap silme akışı (mağaza zorunluluğu) | Kısmi | Destek e-postası tanımlı; uygulama içi silme butonu production’da netleştirilmeli |
| Gerçek para çekim / ödeme kuruluşu | Eksik | |
| Rate limit, fraud, KYC | Eksik | Sunucu tarafı |
| FCM / bildirimler | İsteğe bağlı | |

## D) Mağaza metinleri (Play Console)

- [ ] Kısa açıklama / uzun açıklama  
- [ ] Gizlilik politikası URL’si  
- [ ] Hesap silme talimatı  
- [ ] İçerik derecelendirmesi anketi  
- [ ] Veri güvenliği formu (Data safety)  

## E) Karar özeti

| Hedef | Durum |
|--------|--------|
| Kapalı test APK (demo ekonomi + UI) | **Hazır** |
| “Canlı kazanç + nakit çekim” iddiası | **Hazır değil** — dış servisler şart |
| Play Store açık yayın | **Hazır değil** — B + C + D tamamlanmalı |

Kaynak paket, harici servisler bağlanana kadar **tam canlı kazanç/çekim sistemi** olarak nitelendirilemez.
