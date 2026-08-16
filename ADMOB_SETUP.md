# AdMob kurulum (Play Store)

## 1) AdMob konsolu
1. https://admob.google.com → Uygulama ekle (Android, paket: `com.hakpay.hakpay`)
2. **Uygulama kimliği** kopyala → `ca-app-pub-XXXX~YYYY`
3. **Ödüllü birim** oluştur → `ca-app-pub-XXXX/ZZZZ`

## 2) GitHub Secrets
Repo → Settings → Secrets and variables → Actions → New repository secret:

| Secret | Değer |
|--------|--------|
| `ADMOB_APP_ID` | ca-app-pub-xxx~yyy |
| `ADMOB_REWARDED_ID` | ca-app-pub-xxx/zzz |
| `ADMOB_INTERSTITIAL_ID` | (isteğe bağlı) |
| `ADMOB_BANNER_ID` | (isteğe bağlı) |
| `HAKPAY_API_BASE` | (backend varsa) |

Secret yoksa Google **test** ID’leri kullanılır (gerçek gelir yok).

## 3) Build
Actions → Run workflow → APK + AAB.

## 4) Önemli
- Production’da ödül **sunucu tarafı SSV / backend verify** ile verilmeli.
- Test cihazında gerçek birim kullanırken AdMob “test device” ekle.
- Play Data safety formunda reklam / reklam kimliği beyan et.
